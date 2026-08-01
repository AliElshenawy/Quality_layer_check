/*
Drop the legacy dq.technical_run table (optional cleanup).

WHY:
- dq.technical_run is a run-level log written ONLY by the older DQ engine
  procedures (see SalesforceDW_Structure_Only.sql). The watermark framework
  procedure dq.run_incremental_catalog_rules does NOT write to it.
- It is inert for the incremental framework. Drop it only if you are retiring
  the legacy engine.

SAFETY:
- This script is a DRAFT. It does nothing destructive unless you set
  @Confirm = 1 below.
- With @Confirm = 0 it only REPORTS: row count, latest run, and any procedures
  that still reference the table (which would break if it is dropped).

Target: SQL Server (SalesforceDW)
*/

USE SalesforceDW;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Confirm BIT = 0;   -- set to 1 to actually drop the table

IF OBJECT_ID(N'dq.technical_run', N'U') IS NULL
BEGIN
    PRINT 'dq.technical_run does not exist. Nothing to do.';
    RETURN;
END;

/* --- Report: how much history is stored --- */
DECLARE @rows BIGINT = (SELECT COUNT_BIG(*) FROM dq.technical_run);
PRINT CONCAT(N'dq.technical_run row count: ', @rows);

SELECT TOP (5)
    dq_run_id,
    started_at,
    completed_at,
    run_status
FROM dq.technical_run
ORDER BY started_at DESC;

/* --- Report: objects that still reference the table (would break on drop) --- */
PRINT 'Objects still referencing dq.technical_run:';
SELECT DISTINCT
    OBJECT_SCHEMA_NAME(d.referencing_id) + N'.' + OBJECT_NAME(d.referencing_id) AS referencing_object,
    o.type_desc
FROM sys.sql_expression_dependencies AS d
JOIN sys.objects AS o
    ON o.object_id = d.referencing_id
WHERE d.referenced_id = OBJECT_ID(N'dq.technical_run')
ORDER BY referencing_object;

/* --- Guarded drop --- */
IF @Confirm = 1
BEGIN
    /* Optional: keep a backup copy instead of losing history.
       Uncomment to snapshot before dropping.
    SELECT * INTO dq.technical_run_archive FROM dq.technical_run;
    */
    DROP TABLE dq.technical_run;
    PRINT 'dq.technical_run dropped.';
END
ELSE
BEGIN
    PRINT 'DRY RUN: set @Confirm = 1 to drop dq.technical_run.';
END;
GO
