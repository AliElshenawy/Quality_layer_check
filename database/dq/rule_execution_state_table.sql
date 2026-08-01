/* ============================================================================
   Author: Mohey
   Origin: Added to the database after the base structure (DQ watermark framework).
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [dq].[rule_execution_state]
(
    rule_id INT NOT NULL
        CONSTRAINT PK_rule_execution_state PRIMARY KEY,
    rule_signature VARBINARY(32) NOT NULL,
    rule_core_signature VARBINARY(32) NOT NULL,
    last_applied_core_signature VARBINARY(32) NULL,
    source_watermark_column SYSNAME NULL,
    last_source_watermark_value DATETIME2(7) NULL,
    reprocess_review_pending BIT NOT NULL
        CONSTRAINT DF_rule_execution_state_reprocess DEFAULT (0),
    first_seen_at DATETIME2(7) NOT NULL
        CONSTRAINT DF_rule_execution_state_first_seen DEFAULT (SYSUTCDATETIME()),
    last_prepared_at DATETIME2(7) NOT NULL
        CONSTRAINT DF_rule_execution_state_last_prepared DEFAULT (SYSUTCDATETIME()),
    last_changed_at DATETIME2(7) NULL,
    last_run_started_at DATETIME2(7) NULL,
    last_run_completed_at DATETIME2(7) NULL,
    last_run_status VARCHAR(20) NULL,
    last_error_message NVARCHAR(4000) NULL,
    last_run_rows_checked BIGINT NULL,
    last_run_failed_count BIGINT NULL,
    run_count INT NOT NULL
        CONSTRAINT DF_rule_execution_state_run_count DEFAULT (0)
);
GO
CREATE INDEX IX_rule_execution_state_watermark
ON [dq].[rule_execution_state](last_source_watermark_value, rule_id)
INCLUDE (reprocess_review_pending, last_run_status);
GO
