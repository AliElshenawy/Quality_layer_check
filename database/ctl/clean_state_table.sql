/* ============================================================================
   Author: Mohey
   Origin: Campaign POC — incremental clean watermark.
   ----------------------------------------------------------------------------
   ctl.clean_state holds, per object, the last SystemModstamp the clean step has
   processed. The incremental clean proc reads this to only re-clean staging rows
   that changed since the last run, then advances it.
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[ctl].[clean_state]', N'U') IS NULL
BEGIN
    CREATE TABLE [ctl].[clean_state]
    (
        [object_name]          NVARCHAR(150) NOT NULL,
        [last_clean_watermark] DATETIME2(7)  NULL,     -- max SystemModstamp cleaned so far
        [last_run_at]          DATETIME2(7)  NOT NULL
            CONSTRAINT [DF_clean_state_run_at] DEFAULT (SYSUTCDATETIME()),
        [last_rows_merged]     INT           NULL,
        CONSTRAINT [PK_clean_state] PRIMARY KEY CLUSTERED ([object_name])
    );
END;
GO
