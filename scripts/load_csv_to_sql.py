"""
Load Salesforce CSV exports into SQL Server using BULK INSERT.
Reads CSV files from the exports folder and loads them into the raw schema.
No Salesforce connection needed — works entirely from local CSV files.

Usage:
    python load_csv_to_sql.py
    python load_csv_to_sql.py --input C:/MyData/exports
    python load_csv_to_sql.py --objects Contact,Opportunity
"""

from __future__ import annotations

import csv
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote_plus

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from sqlalchemy.pool import NullPool


# ---------- Configuration ----------

CONFIG_PATH = Path(__file__).parent / "config.json"
DEFAULT_EXPORT_DIR = Path(__file__).parent / "exports"

RAW_SCHEMA = "raw"
CONTROL_SCHEMA = "ctl"

# CSV filename prefix -> SQL table name + Salesforce object name + expected rows from download
CSV_MAPPINGS: dict[str, dict[str, str | int]] = {
    "salesforce_contact": {
        "table": "salesforce_contact",
        "object": "Contact",
        "expected_rows": 1_901_058,
    },
    "salesforce_payment": {
        "table": "salesforce_payment",
        "object": "npe01__OppPayment__c",
        "expected_rows": 10_905_053,
    },
    "salesforce_opportunity": {
        "table": "salesforce_opportunity",
        "object": "Opportunity",
        "expected_rows": 10_439_340,
    },
    "salesforce_recurring_donation": {
        "table": "salesforce_recurring_donation",
        "object": "npe03__Recurring_Donation__c",
        "expected_rows": 258_368,
    },
    "salesforce_item_allocation": {
        "table": "salesforce_item_allocation",
        "object": "npsp__Allocation__c",
        "expected_rows": 16_622_689,
    },
    "salesforce_campaign": {
        "table": "salesforce_campaign",
        "object": "Campaign",
        "expected_rows": 40_753,
    },
    "salesforce_sponsorship": {
        "table": "salesforce_sponsorship",
        "object": "Sponsorship__c",
        "expected_rows": 226_975,
    },
    "salesforce_sponsorship_unit": {
        "table": "salesforce_sponsorship_unit",
        "object": "Sponsorship_Unit__c",
        "expected_rows": 1_291_058,
    },
    "salesforce_item": {
        "table": "salesforce_item",
        "object": "npsp__General_Accounting_Unit__c",
        "expected_rows": 30_804,
    },
}


# ---------- Helpers ----------

def utc_now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def load_config() -> dict[str, Any]:
    if not CONFIG_PATH.exists():
        raise FileNotFoundError(f"Config not found: {CONFIG_PATH}")
    with CONFIG_PATH.open("r", encoding="utf-8") as f:
        return json.load(f)


def build_engine(sql_config: dict[str, Any]) -> Engine:
    odbc = (
        f"DRIVER={{{sql_config['driver']}}};"
        f"SERVER={sql_config['server']};"
        f"DATABASE={sql_config['database']};"
        "Trusted_Connection=yes;"
        "Encrypt=yes;"
        "TrustServerCertificate=yes;"
    )
    return create_engine(
        "mssql+pyodbc:///?odbc_connect=" + quote_plus(odbc),
        fast_executemany=True,
        poolclass=NullPool,
        future=True,
    )


def ensure_schemas(engine: Engine) -> None:
    """Create raw and ctl schemas if they don't exist."""
    sql = """
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw')
        EXEC('CREATE SCHEMA raw');
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ctl')
        EXEC('CREATE SCHEMA ctl');
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
        EXEC('CREATE SCHEMA staging');

    IF OBJECT_ID('ctl.etl_run_control', 'U') IS NULL
    BEGIN
        CREATE TABLE ctl.etl_run_control (
            run_id BIGINT IDENTITY(1,1) PRIMARY KEY,
            object_name NVARCHAR(100) NOT NULL,
            load_type NVARCHAR(20) NOT NULL,
            start_time DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
            end_time DATETIME2 NULL,
            status NVARCHAR(20) NOT NULL DEFAULT 'Running',
            rows_extracted BIGINT NULL,
            rows_loaded BIGINT NULL,
            error_message NVARCHAR(MAX) NULL
        );
    END;

    IF OBJECT_ID('ctl.watermark_control', 'U') IS NULL
    BEGIN
        CREATE TABLE ctl.watermark_control (
            object_name NVARCHAR(100) PRIMARY KEY,
            watermark_column NVARCHAR(100) NOT NULL,
            last_watermark_value DATETIME2 NULL,
            last_success_run_id BIGINT NULL,
            updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME()
        );
    END;
    """
    with engine.begin() as conn:
        conn.exec_driver_sql(sql)


def find_csv_file(export_dir: Path, prefix: str) -> Path | None:
    """Find the most recent CSV file matching the prefix exactly (not a longer prefix)."""
    matches = []
    for p in export_dir.glob(f"{prefix}_*.csv"):
        # Ensure we don't match longer prefixes
        # e.g. 'salesforce_item_' should NOT match 'salesforce_item_allocation_'
        remainder = p.stem[len(prefix):]
        # After the prefix, next char should be _ followed by digits (timestamp)
        if remainder and remainder[0] == '_' and any(c.isdigit() for c in remainder[1:6]):
            matches.append(p)
    if matches:
        return sorted(matches, reverse=True)[0]
    # Also try exact name without timestamp
    exact = export_dir / f"{prefix}.csv"
    if exact.exists():
        return exact
    return None


def count_csv_rows(csv_path: Path) -> int:
    """Fast line count (subtract 1 for header)."""
    count = -1  # exclude header
    with open(csv_path, "r", encoding="utf-8-sig") as f:
        for _ in f:
            count += 1
    return count


def pre_insert_check(csv_path: Path, expected_rows: int | None) -> tuple[int, list[str]]:
    """Count CSV rows and compare to expected. Returns (csv_count, warnings)."""
    warnings: list[str] = []
    print(f"  Pre-check: counting CSV rows...", end="", flush=True)
    csv_count = count_csv_rows(csv_path)
    print(f" {csv_count:,} rows")

    if expected_rows:
        diff = csv_count - expected_rows
        pct = abs(diff) / expected_rows * 100 if expected_rows else 0
        if pct > 5:
            warnings.append(
                f"CSV has {csv_count:,} rows but expected ~{expected_rows:,} "
                f"(diff: {diff:+,}, {pct:.1f}%)"
            )
        elif diff != 0:
            print(f"  Pre-check: CSV {csv_count:,} vs expected ~{expected_rows:,} "
                  f"(diff: {diff:+,}, {pct:.1f}%) -- OK")

    return csv_count, warnings


def start_run(engine: Engine, object_name: str) -> int:
    sql = text("""
        INSERT INTO ctl.etl_run_control (object_name, load_type, status, start_time)
        OUTPUT INSERTED.run_id
        VALUES (:object_name, 'CSV_Load', 'Running', SYSDATETIME());
    """)
    with engine.begin() as conn:
        return int(conn.execute(sql, {"object_name": object_name}).scalar_one())


def finish_run(engine: Engine, run_id: int, status: str, rows: int, error: str | None = None) -> None:
    sql = text("""
        UPDATE ctl.etl_run_control
        SET end_time = SYSDATETIME(),
            status = :status,
            rows_extracted = :rows,
            rows_loaded = :rows,
            error_message = :error
        WHERE run_id = :run_id;
    """)
    with engine.begin() as conn:
        conn.execute(sql, {"run_id": run_id, "status": status, "rows": rows, "error": error})


def update_watermark(engine: Engine, object_name: str, watermark_col: str, watermark_val: Any, run_id: int) -> None:
    sql = text("""
        MERGE ctl.watermark_control AS target
        USING (SELECT :obj AS object_name, :col AS watermark_column, 
                      :val AS last_watermark_value, :rid AS last_success_run_id) AS source
        ON target.object_name = source.object_name
        WHEN MATCHED THEN
            UPDATE SET watermark_column = source.watermark_column,
                       last_watermark_value = source.last_watermark_value,
                       last_success_run_id = source.last_success_run_id,
                       updated_at = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (object_name, watermark_column, last_watermark_value, last_success_run_id, updated_at)
            VALUES (source.object_name, source.watermark_column, source.last_watermark_value, 
                    source.last_success_run_id, SYSDATETIME());
    """)
    with engine.begin() as conn:
        conn.execute(sql, {"obj": object_name, "col": watermark_col, "val": watermark_val, "rid": run_id})


def drop_table_if_exists(engine: Engine, table_name: str) -> None:
    sql = f"DROP TABLE IF EXISTS [{RAW_SCHEMA}].[{table_name}];"
    with engine.begin() as conn:
        conn.exec_driver_sql(sql)


def create_table_from_csv_header(engine: Engine, csv_path: Path, table_name: str) -> list[str]:
    """Read CSV header and create an NVARCHAR(4000) table. Returns column names."""
    with open(csv_path, "r", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        columns = next(reader)

    # Clean column names (remove BOM, whitespace)
    columns = [c.strip() for c in columns]

    # Create table with ONLY CSV columns (metadata added after load)
    col_defs = ",\n        ".join(f"[{c}] NVARCHAR(MAX) NULL" for c in columns)

    ddl = f"""
    CREATE TABLE [{RAW_SCHEMA}].[{table_name}] (
        {col_defs}
    );
    """
    with engine.begin() as conn:
        conn.exec_driver_sql(ddl)

    return columns


def add_etl_metadata(engine: Engine, table_name: str, object_name: str) -> None:
    """Add and populate ETL metadata columns after load."""
    with engine.begin() as conn:
        conn.exec_driver_sql(f"""
            ALTER TABLE [{RAW_SCHEMA}].[{table_name}]
                ADD [_etl_loaded_at_utc] DATETIME2 NULL,
                    [_etl_source] NVARCHAR(50) NULL,
                    [_etl_source_object] NVARCHAR(100) NULL;
        """)
        conn.exec_driver_sql(f"""
            UPDATE [{RAW_SCHEMA}].[{table_name}]
            SET [_etl_loaded_at_utc] = SYSUTCDATETIME(),
                [_etl_source] = 'CSV_BulkInsert',
                [_etl_source_object] = '{object_name}';
        """)


FAST_BATCH_SIZE = 50_000  # Rows per executemany call


def load_csv_to_table(engine: Engine, csv_path: Path, table_name: str, object_name: str) -> int:
    """Load CSV using pyodbc fast_executemany (no pandas overhead)."""

    print(f"  Reading: {csv_path.name} ({csv_path.stat().st_size / (1024**3):.1f} GB)")

    # Drop and recreate table from CSV header
    drop_table_if_exists(engine, table_name)
    columns = create_table_from_csv_header(engine, csv_path, table_name)
    num_cols = len(columns)
    print(f"  Created table raw.{table_name} ({num_cols} columns)")

    # Build INSERT statement
    placeholders = ", ".join(["?"] * num_cols)
    col_list = ", ".join(f"[{c}]" for c in columns)
    insert_sql = f"INSERT INTO [{RAW_SCHEMA}].[{table_name}] ({col_list}) VALUES ({placeholders})"

    # Get raw pyodbc connection for fast_executemany
    raw_conn = engine.raw_connection()
    try:
        cursor = raw_conn.cursor()
        cursor.fast_executemany = True

        total_rows = 0
        batch: list[tuple] = []

        with open(csv_path, "r", encoding="utf-8-sig", newline="") as f:
            reader = csv.reader(f)
            next(reader)  # skip header

            for row in reader:
                # Replace empty strings with None
                cleaned = tuple(v if v != "" else None for v in row)
                # Pad or trim to match column count
                if len(cleaned) < num_cols:
                    cleaned = cleaned + (None,) * (num_cols - len(cleaned))
                elif len(cleaned) > num_cols:
                    cleaned = cleaned[:num_cols]
                batch.append(cleaned)

                if len(batch) >= FAST_BATCH_SIZE:
                    cursor.executemany(insert_sql, batch)
                    total_rows += len(batch)
                    batch.clear()
                    print(f"    Loaded: {total_rows:,} rows", end="\r", flush=True)

            # Final batch
            if batch:
                cursor.executemany(insert_sql, batch)
                total_rows += len(batch)

        raw_conn.commit()
    finally:
        raw_conn.close()

    # Add ETL metadata
    print(f"\n  Stamping ETL metadata...", flush=True)
    add_etl_metadata(engine, table_name, object_name)

    print(f"  Loaded: {total_rows:,} rows -- DONE")
    return total_rows


def verify_load(engine: Engine, csv_path: Path, table_name: str, loaded_rows: int) -> list[str]:
    """Post-load checks: row count match, NULL IDs, duplicate IDs."""
    issues: list[str] = []

    with engine.connect() as conn:
        # 1. Row count in SQL vs what we inserted
        sql_count = conn.execute(text(
            f"SELECT COUNT(*) FROM [{RAW_SCHEMA}].[{table_name}]"
        )).scalar()
        if sql_count != loaded_rows:
            issues.append(f"Row mismatch: loaded {loaded_rows:,} but SQL has {sql_count:,}")

        # 2. Check for NULL Id values
        has_id = conn.execute(text(
            f"SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS "
            f"WHERE TABLE_SCHEMA = '{RAW_SCHEMA}' AND TABLE_NAME = :tbl AND COLUMN_NAME = 'Id'"
        ), {"tbl": table_name}).first()
        if has_id:
            null_ids = conn.execute(text(
                f"SELECT COUNT(*) FROM [{RAW_SCHEMA}].[{table_name}] WHERE [Id] IS NULL"
            )).scalar()
            if null_ids > 0:
                issues.append(f"{null_ids:,} rows with NULL Id")

            # 3. Duplicate Ids
            dup_count = conn.execute(text(
                f"SELECT COUNT(*) FROM ("
                f"  SELECT [Id] FROM [{RAW_SCHEMA}].[{table_name}] "
                f"  GROUP BY [Id] HAVING COUNT(*) > 1"
                f") d"
            )).scalar()
            if dup_count > 0:
                issues.append(f"{dup_count:,} duplicate Id values")

    return issues


# ---------- Main ----------

def main() -> None:
    # Parse arguments
    export_dir = DEFAULT_EXPORT_DIR
    filter_objects: set[str] | None = None
    
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--input" and i + 1 < len(args):
            export_dir = Path(args[i + 1])
            i += 2
        elif args[i] == "--objects" and i + 1 < len(args):
            filter_objects = set(args[i + 1].split(","))
            i += 2
        else:
            i += 1
    
    if not export_dir.exists():
        print(f"ERROR: Export directory not found: {export_dir}")
        sys.exit(1)
    
    print(f"Source directory: {export_dir}")
    print(f"Config: {CONFIG_PATH}")
    
    # Load config and connect
    config = load_config()
    engine = build_engine(config["sql_server"])
    
    # Test connection
    with engine.connect() as conn:
        version = conn.execute(text("SELECT @@VERSION")).scalar()
        print(f"Connected to SQL Server: {version.split(chr(10))[0]}")
    
    # Ensure schemas and control tables exist
    ensure_schemas(engine)
    print("Schemas and control tables ready.")
    
    # Determine which CSVs to load
    to_load: list[tuple[str, Path, dict[str, str | int]]] = []
    
    for prefix, mapping in CSV_MAPPINGS.items():
        # Filter by --objects if specified
        if filter_objects and prefix not in filter_objects and mapping["table"] not in filter_objects:
            continue
        
        csv_path = find_csv_file(export_dir, prefix)
        if csv_path:
            to_load.append((prefix, csv_path, mapping))
        else:
            print(f"  SKIP: No CSV found for '{prefix}' in {export_dir}")
    
    if not to_load:
        print("Nothing to load. Check your --input path or --objects filter.")
        sys.exit(1)
    
    print(f"\nWill load {len(to_load)} objects into [{RAW_SCHEMA}] schema:")
    for prefix, path, mapping in to_load:
        size_gb = path.stat().st_size / (1024**3)
        print(f"  {mapping['table']:<35} <- {path.name} ({size_gb:.1f} GB)")
    
    print()
    
    # Load each CSV
    succeeded = []
    failed = []
    
    for prefix, csv_path, mapping in to_load:
        table_name = mapping["table"]
        object_name = mapping["object"]
        
        print(f"{'='*60}")
        print(f"Loading: {object_name} -> raw.{table_name}")
        print(f"{'='*60}")
        
        run_id = start_run(engine, object_name)
        start_time = time.time()
        
        try:
            # Pre-insert: count CSV rows and compare to expected
            expected = mapping.get("expected_rows")
            csv_count, pre_warnings = pre_insert_check(csv_path, int(expected) if expected else None)
            if pre_warnings:
                for w in pre_warnings:
                    print(f"  WARNING PRE-CHECK: {w}")

            rows = load_csv_to_table(engine, csv_path, table_name, object_name)
            elapsed = time.time() - start_time
            
            finish_run(engine, run_id, "Succeeded", rows)
            
            # Update watermark if SystemModstamp column exists
            with engine.connect() as conn:
                cols = [r[0] for r in conn.execute(text(
                    f"SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS "
                    f"WHERE TABLE_SCHEMA = '{RAW_SCHEMA}' AND TABLE_NAME = :tbl"
                ), {"tbl": table_name}).fetchall()]
            watermark_col = None
            if "SystemModstamp" in cols:
                watermark_col = "SystemModstamp"
            elif "LastModifiedDate" in cols:
                watermark_col = "LastModifiedDate"
            
            if watermark_col:
                # Get max watermark from loaded data
                with engine.connect() as conn:
                    max_val = conn.execute(text(
                        f"SELECT MAX(TRY_CONVERT(datetime2, [{watermark_col}])) "
                        f"FROM [{RAW_SCHEMA}].[{table_name}]"
                    )).scalar()
                if max_val:
                    update_watermark(engine, object_name, watermark_col, max_val, run_id)
            
            # Post-load verification
            issues = verify_load(engine, csv_path, table_name, rows)
            if issues:
                print(f"  WARNINGS:")
                for issue in issues:
                    print(f"    WARNING: {issue}")
            else:
                print(f"  VERIFIED: row count, no NULL Ids, no duplicates")

            print(f"  SUCCESS: {rows:,} rows in {elapsed:.0f}s ({rows/elapsed:.0f} rows/s)")
            succeeded.append((object_name, rows))
            
        except Exception as e:
            elapsed = time.time() - start_time
            finish_run(engine, run_id, "Failed", 0, str(e)[:4000])
            print(f"  FAILED after {elapsed:.0f}s: {e}")
            failed.append((object_name, str(e)))
    
    # Summary
    print(f"\n{'='*60}")
    print(f"DONE -- {len(succeeded)} succeeded, {len(failed)} failed")
    print(f"{'='*60}")
    
    total_rows = 0
    for obj, rows in succeeded:
        print(f"  OK: {obj} ({rows:,} rows)")
        total_rows += rows
    for obj, err in failed:
        print(f"  FAIL: {obj} -- {err[:80]}")
    
    print(f"\nTotal rows loaded: {total_rows:,}")


if __name__ == "__main__":
    main()
