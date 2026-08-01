"""
Download Salesforce objects to CSV files.
No SQL Server required — just outputs CSV files you can use anywhere.

Usage:
    python download_to_csv.py
    python download_to_csv.py --output C:/MyData
"""

from __future__ import annotations

import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


CONFIG_PATH = Path(__file__).parent / "config.json"
DEFAULT_OUTPUT_DIR = Path(__file__).parent / "exports"

REQUEST_TIMEOUT = 300
JOB_POLL_SECONDS = 5

# Salesforce API name -> output CSV file name
OBJECTS: dict[str, str] = {
    "Contact": "salesforce_contact",
    "npe01__OppPayment__c": "salesforce_payment",
    "Opportunity": "salesforce_opportunity",
    "npe03__Recurring_Donation__c": "salesforce_recurring_donation",
    "npsp__Allocation__c": "salesforce_item_allocation",
    "Campaign": "salesforce_campaign",
    "Sponsorship__c": "salesforce_sponsorship",
    "Sponsorship_Unit__c": "salesforce_sponsorship_unit",
    "npsp__General_Accounting_Unit__c": "salesforce_item",
}


def load_config() -> dict[str, Any]:
    if not CONFIG_PATH.exists():
        raise FileNotFoundError(f"Config not found: {CONFIG_PATH}")
    with CONFIG_PATH.open("r", encoding="utf-8") as f:
        return json.load(f)


def build_session() -> requests.Session:
    retry = Retry(
        total=5,
        backoff_factor=2,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=frozenset({"GET", "POST"}),
    )
    session = requests.Session()
    session.mount("https://", HTTPAdapter(max_retries=retry))
    return session


def authenticate(session: requests.Session, sf: dict) -> tuple[str, str]:
    resp = session.post(
        sf["domain"].rstrip("/") + "/services/oauth2/token",
        data={
            "grant_type": "client_credentials",
            "client_id": sf["client_id"],
            "client_secret": sf["client_secret"],
        },
        timeout=REQUEST_TIMEOUT,
    )
    if not resp.ok:
        raise RuntimeError(f"Auth failed ({resp.status_code}): {resp.text}")
    data = resp.json()
    return data["access_token"], data["instance_url"].rstrip("/")


def get_fields(session: requests.Session, headers: dict, instance_url: str, api: str, obj: str) -> list[str]:
    resp = session.get(
        f"{instance_url}/services/data/{api}/sobjects/{obj}/describe",
        headers=headers,
        timeout=REQUEST_TIMEOUT,
    )
    if not resp.ok:
        raise RuntimeError(f"Describe {obj} failed ({resp.status_code}): {resp.text}")

    excluded = {"address", "location", "base64"}
    fields = [
        f["name"]
        for f in resp.json()["fields"]
        if not f.get("deprecatedAndHidden", False) and f.get("type") not in excluded
    ]
    if "Id" in fields:
        fields.remove("Id")
        fields.insert(0, "Id")
    return fields


def create_bulk_job(session: requests.Session, headers: dict, instance_url: str, api: str, soql: str) -> str:
    resp = session.post(
        f"{instance_url}/services/data/{api}/jobs/query",
        headers={**headers, "Content-Type": "application/json"},
        json={"operation": "queryAll", "query": soql, "contentType": "CSV", "columnDelimiter": "COMMA", "lineEnding": "LF"},
        timeout=REQUEST_TIMEOUT,
    )
    if not resp.ok:
        raise RuntimeError(f"Bulk job create failed ({resp.status_code}): {resp.text}")
    return resp.json()["id"]


def wait_for_job(session: requests.Session, headers: dict, instance_url: str, api: str, job_id: str) -> int:
    url = f"{instance_url}/services/data/{api}/jobs/query/{job_id}"
    while True:
        resp = session.get(url, headers=headers, timeout=REQUEST_TIMEOUT)
        if not resp.ok:
            raise RuntimeError(f"Job status failed ({resp.status_code}): {resp.text}")
        info = resp.json()
        state = info["state"]
        records = info.get("numberRecordsProcessed", 0)
        print(f"  Job {job_id}: {state} ({records:,} records)")

        if state == "JobComplete":
            return records
        if state in ("Failed", "Aborted"):
            raise RuntimeError(info.get("errorMessage") or f"Job ended: {state}")
        time.sleep(JOB_POLL_SECONDS)


def download_results(session: requests.Session, headers: dict, instance_url: str, api: str, job_id: str, output_path: Path) -> None:
    url = f"{instance_url}/services/data/{api}/jobs/query/{job_id}/results"
    locator = None
    first_chunk = True

    while True:
        params = {}
        if locator:
            params["locator"] = locator

        resp = session.get(url, headers=headers, params=params, timeout=REQUEST_TIMEOUT, stream=True)
        if not resp.ok:
            raise RuntimeError(f"Download failed ({resp.status_code}): {resp.text}")

        mode = "wb" if first_chunk else "ab"
        with output_path.open(mode) as f:
            for line_num, line in enumerate(resp.iter_lines()):
                # Skip CSV header on subsequent chunks
                if not first_chunk and line_num == 0:
                    continue
                f.write(line + b"\n")

        first_chunk = False
        locator = resp.headers.get("Sforce-Locator")
        if not locator or locator == "null":
            break


def download_object(session: requests.Session, headers: dict, instance_url: str, api: str, obj: str, filename: str, output_dir: Path) -> None:
    print(f"\n{'='*60}")
    print(f"Downloading: {obj}")
    print(f"{'='*60}")

    fields = get_fields(session, headers, instance_url, api, obj)
    print(f"  Fields: {len(fields)}")

    soql = f"SELECT {', '.join(fields)} FROM {obj}"
    job_id = create_bulk_job(session, headers, instance_url, api, soql)
    record_count = wait_for_job(session, headers, instance_url, api, job_id)

    if record_count == 0:
        print(f"  No records found. Skipping.")
        return

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = output_dir / f"{filename}_{timestamp}.csv"
    download_results(session, headers, instance_url, api, job_id, output_path)
    size_mb = output_path.stat().st_size / (1024 * 1024)
    print(f"  Saved: {output_path} ({size_mb:.1f} MB, {record_count:,} records)")


def main() -> None:
    # Parse optional --output argument
    output_dir = DEFAULT_OUTPUT_DIR
    if "--output" in sys.argv:
        idx = sys.argv.index("--output")
        if idx + 1 < len(sys.argv):
            output_dir = Path(sys.argv[idx + 1])

    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"Output directory: {output_dir}")

    config = load_config()
    sf = config["salesforce"]
    api = sf["api_version"]

    session = build_session()
    token, instance_url = authenticate(session, sf)
    headers = {"Authorization": f"Bearer {token}"}
    print(f"Authenticated to {instance_url}")

    succeeded = []
    failed = []

    for obj, filename in OBJECTS.items():
        try:
            download_object(session, headers, instance_url, api, obj, filename, output_dir)
            succeeded.append(obj)
        except Exception as e:
            print(f"  ERROR on {obj}: {e}")
            failed.append((obj, str(e)))

    print(f"\n{'='*60}")
    print(f"DONE — {len(succeeded)} succeeded, {len(failed)} failed")
    print(f"{'='*60}")
    for obj in succeeded:
        print(f"  OK: {obj}")
    for obj, err in failed:
        print(f"  FAIL: {obj} — {err}")
    print(f"\nFiles saved to: {output_dir}")


if __name__ == "__main__":
    main()
