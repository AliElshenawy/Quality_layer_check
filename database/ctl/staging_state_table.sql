/* ============================================================================
   Author: Mohey
   Origin: Incremental staging — watermark for the raw -> staging step.
   ----------------------------------------------------------------------------
   ctl.staging_state holds, per object, the last SystemModstamp the staging build
   has processed. The incremental staging proc reads this to MERGE only raw rows
   changed since the last run (dedup to latest per Id), then advances it.

   Mirrors ctl.clean_state (staging is now incremental like clean, not a full
   rebuild). SystemModstamp is the incremental key across raw -> staging -> clean.
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[ctl].[staging_state]', N'U') IS NULL
BEGIN
    CREATE TABLE [ctl].[staging_state]
    (
        [object_name]            NVARCHAR(150) NOT NULL,
        [last_staging_watermark] DATETIME2(7)  NULL,     -- max SystemModstamp merged so far
        [last_run_at]            DATETIME2(7)  NOT NULL
            CONSTRAINT [DF_staging_state_run_at] DEFAULT (SYSUTCDATETIME()),
        [last_rows_merged]       INT           NULL,
        [last_rows_deleted]      INT           NULL,
        CONSTRAINT [PK_staging_state] PRIMARY KEY CLUSTERED ([object_name])
    );
END;
GO
