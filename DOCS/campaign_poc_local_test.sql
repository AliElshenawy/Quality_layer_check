/* ============================================================================
   Campaign POC — LOCAL test harness (run before Azure)
   ----------------------------------------------------------------------------
   Purpose: test locally, on the existing localhost SalesforceDW, the two POC
   pieces that were added but not yet run:
       TEST 1 — the FIX  : the Stage 4 "campaign_clean" build (auto-fixes + skips)
       TEST 2 — the LOGS : writing a run + watermark into the ctl schema
   Everything here runs on your PC against the local DB. Nothing is pushed to
   Salesforce. The ctl test uses a throwaway object name ('Campaign_LOCALTEST')
   and cleans up after itself, so the real Campaign control rows are untouched.

   Connect (SSMS or sqlcmd, Windows auth):
     sqlcmd -S localhost -E -d SalesforceDW -C -N -i campaign_poc_local_test.sql

   What can NOT be tested locally (Azure-only, prove them in the POC):
     - ADF Monitor run history / activity logs
     - Azure Monitor / Log Analytics (KQL) and Diagnostic settings
     - Container App Job execution of python.py
   ============================================================================ */
USE SalesforceDW;
GO
SET NOCOUNT ON;
GO

PRINT '================ TEST 1 - THE FIX (staging.campaign_clean build) ================';
GO

-- Build a *_localtest copy of the clean table so nothing real is clobbered.
DROP TABLE IF EXISTS staging.campaign_clean_localtest;
GO

SELECT
    s.Id,
    s.SystemModstamp,
    -- CLEANED #1: currency normalized (CAM-006)
    UPPER(LTRIM(RTRIM(s.CurrencyIsoCode)))          AS CurrencyIsoCode,
    s.CurrencyIsoCode                               AS CurrencyIsoCode_original,
    -- CLEANED #2: status case/whitespace (CAM-004)
    LOWER(LTRIM(RTRIM(s.Status)))                   AS Status,
    s.Status                                        AS Status_original,
    -- CLEANED #3: IsActive boolean -> 0/1
    CASE WHEN LOWER(LTRIM(RTRIM(COALESCE(s.IsActive,'')))) IN ('true','1','yes','y')  THEN 1
         WHEN LOWER(LTRIM(RTRIM(COALESCE(s.IsActive,'')))) IN ('false','0','no','n') THEN 0
         ELSE NULL END                              AS IsActive,
    s.IsActive                                      AS IsActive_original,
    -- CLEANED #4: Year derived from StartDate when blank/invalid (CAM-015) -- business-confirm
    COALESCE(
      CASE WHEN TRY_CONVERT(int,s.Year__c) BETWEEN 2000 AND YEAR(GETDATE())+1
           THEN TRY_CONVERT(int,s.Year__c) END,
      YEAR(TRY_CONVERT(date,s.StartDate)))          AS Year__c,
    s.Year__c                                       AS Year__c_original,
    -- carried unchanged (skipped fields keep raw value)
    s.Name, s.StartDate, s.EndDate, s.ParentId,
    -- per-row clean audit (binary collation so case/whitespace-only changes are detected)
    CASE WHEN s.CurrencyIsoCode COLLATE Latin1_General_BIN2 <> UPPER(LTRIM(RTRIM(s.CurrencyIsoCode))) COLLATE Latin1_General_BIN2 THEN 'CLEANED' ELSE 'OK' END AS clean_currency,
    CASE WHEN s.Status COLLATE Latin1_General_BIN2 <> LOWER(LTRIM(RTRIM(s.Status))) COLLATE Latin1_General_BIN2 THEN 'CLEANED' ELSE 'OK' END AS clean_status,
    CASE
      WHEN s.Name IS NULL OR LTRIM(RTRIM(s.Name))=''                        THEN 'SKIPPED: blank name (CAM-003)'
      WHEN TRY_CONVERT(date,s.StartDate) > TRY_CONVERT(date,s.EndDate)      THEN 'SKIPPED: start>end (CAM-005)'
      WHEN LOWER(LTRIM(RTRIM(s.Status))) NOT IN
           ('active','planned','inactive','completed','aborted','in progress') THEN 'SKIPPED: status value needs business rule (CAM-004)'
      ELSE 'NONE'
    END AS review_reason
INTO staging.campaign_clean_localtest
FROM staging.campaign_latest s;
GO

-- 1a. What got cleaned vs skipped (the demonstration output)
SELECT 'rows_total'       AS metric, COUNT(*) AS n FROM staging.campaign_clean_localtest
UNION ALL SELECT 'currency_cleaned', COUNT(*) FROM staging.campaign_clean_localtest WHERE clean_currency='CLEANED'
UNION ALL SELECT 'status_cleaned',   COUNT(*) FROM staging.campaign_clean_localtest WHERE clean_status='CLEANED'
UNION ALL SELECT 'year_derived',     COUNT(*) FROM staging.campaign_clean_localtest WHERE Year__c_original IS NULL AND Year__c IS NOT NULL
UNION ALL SELECT 'skipped_rows',     COUNT(*) FROM staging.campaign_clean_localtest WHERE review_reason LIKE 'SKIPPED%';
GO

-- 1b. See real before/after examples for the fixes (top 10 changed rows)
SELECT TOP 10 Id, CurrencyIsoCode_original, CurrencyIsoCode, Status_original, Status,
       IsActive_original, IsActive, Year__c_original, Year__c
FROM staging.campaign_clean_localtest
WHERE clean_currency='CLEANED' OR clean_status='CLEANED'
   OR (Year__c_original IS NULL AND Year__c IS NOT NULL)
   OR IsActive_original <> CAST(IsActive AS NVARCHAR(10));
GO

-- 1c. Gate check: clean must stay unique per Id (must return 0)
SELECT COUNT(*) AS dup_ids
FROM (SELECT Id FROM staging.campaign_clean_localtest GROUP BY Id HAVING COUNT(*) > 1) x;
GO

-- 1d. Breakdown of the skip reasons (which business rules would go to writeback)
SELECT review_reason, COUNT(*) AS n
FROM staging.campaign_clean_localtest
GROUP BY review_reason ORDER BY n DESC;
GO

PRINT '================ TEST 2 - THE LOGS (ctl run + watermark) ================';
GO

-- The proc ADF (or python.py) will call after each load. Safe to (re)create locally.
CREATE OR ALTER PROCEDURE ctl.save_campaign_run
    @object_name NVARCHAR(100),
    @load_type   NVARCHAR(50),
    @status      NVARCHAR(50),
    @rows        BIGINT,
    @new_wm      DATETIME2,
    @start       DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO ctl.etl_run_control
        (object_name, load_type, start_time, end_time, status, rows_extracted, rows_loaded)
    VALUES (@object_name, @load_type, @start, SYSUTCDATETIME(), @status, @rows, @rows);

    DECLARE @run_id BIGINT = SCOPE_IDENTITY();

    IF EXISTS (SELECT 1 FROM ctl.watermark_control WHERE object_name = @object_name)
        UPDATE ctl.watermark_control
           SET last_watermark_value = @new_wm,
               last_success_run_id  = @run_id,
               updated_at           = SYSUTCDATETIME()
         WHERE object_name = @object_name;
    ELSE
        INSERT INTO ctl.watermark_control
            (object_name, watermark_column, last_watermark_value, last_success_run_id, updated_at)
        VALUES (@object_name, N'SystemModstamp', @new_wm, @run_id, SYSUTCDATETIME());

    SELECT @run_id AS new_run_id;
END
GO

-- 2a. Call it with a throwaway object so real Campaign rows are NOT touched.
EXEC ctl.save_campaign_run
     @object_name = N'Campaign_LOCALTEST',
     @load_type   = N'Incremental',
     @status      = N'Succeeded',
     @rows        = 123,
     @new_wm      = '2026-07-29T04:42:15',
     @start       = '2026-07-29T04:40:00';
GO

-- 2b. Read the "logs" back (this is how you inspect a run locally)
SELECT run_id, object_name, load_type, status, rows_extracted, rows_loaded, start_time, end_time
FROM ctl.etl_run_control
WHERE object_name = N'Campaign_LOCALTEST'
ORDER BY run_id DESC;

SELECT object_name, watermark_column, last_watermark_value, last_success_run_id, updated_at
FROM ctl.watermark_control
WHERE object_name = N'Campaign_LOCALTEST';
GO

-- 2c. Clean up the throwaway test rows (leaves the real ctl data untouched)
DELETE FROM ctl.watermark_control WHERE object_name = N'Campaign_LOCALTEST';
DELETE FROM ctl.etl_run_control    WHERE object_name = N'Campaign_LOCALTEST';
PRINT 'Cleaned up Campaign_LOCALTEST ctl rows.';
GO

PRINT '================ DONE ================';
PRINT 'Inspect staging.campaign_clean_localtest, then drop it when finished:';
PRINT '   DROP TABLE IF EXISTS staging.campaign_clean_localtest;';
GO
