/* ============================================================================
   Author: Mohey
   Origin: Campaign POC — business-facing data-quality alert list.
   ----------------------------------------------------------------------------
   dq.alert is the "what the business needs to look at" list. It is like
   dq.dq_exceptions, but simplified for stakeholders and carrying a [cleaned]
   flag so each issue shows whether the pipeline already auto-fixed it or whether
   a human still needs to act:

     - cleaned = 1  : the clean step corrected it automatically (informational)
     - cleaned = 0  : it could NOT be auto-fixed and needs a person (actionable)

   Populated by the clean procedure (clean.refresh_campaign). For now it only
   carries CAM-008 (AmountWonOpportunities > AmountAllOpportunities), which is a
   real data discrepancy that cannot be safely auto-corrected.
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[dq].[alert]', N'U') IS NULL
BEGIN
    CREATE TABLE [dq].[alert]
    (
        [alert_id]      BIGINT IDENTITY(1,1) NOT NULL,
        [object_name]   NVARCHAR(150) NOT NULL,
        [record_id]     VARCHAR(18)   NULL,          -- Salesforce Id in scope
        [check_name]    NVARCHAR(50)  NOT NULL,      -- e.g. CAM-008
        [severity]      NVARCHAR(20)  NOT NULL,      -- CRITICAL / HIGH / MEDIUM / LOW
        [issue]         NVARCHAR(500) NULL,          -- plain-English description
        [current_value] NVARCHAR(MAX) NULL,          -- the offending value(s)
        [cleaned]       BIT           NOT NULL       -- 1 auto-fixed, 0 needs a human
            CONSTRAINT [DF_dq_alert_cleaned] DEFAULT (0),
        [alert_status]  NVARCHAR(50)  NOT NULL       -- Open / Reviewed / Resolved
            CONSTRAINT [DF_dq_alert_status] DEFAULT (N'Open'),
        [created_at]    DATETIME2(7)  NOT NULL
            CONSTRAINT [DF_dq_alert_created_at] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_dq_alert] PRIMARY KEY CLUSTERED ([alert_id])
    );

    CREATE NONCLUSTERED INDEX [IX_dq_alert_open]
        ON [dq].[alert] ([object_name], [check_name], [cleaned], [alert_status])
        INCLUDE ([record_id]);
END;
GO
