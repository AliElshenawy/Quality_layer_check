/* ============================================================================
   Author: Mohey
   Origin: Added to the database after the base structure (DQ watermark framework).
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [dq].[rule_execution_audit]
(
    audit_id BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_rule_execution_audit PRIMARY KEY,
    audit_at DATETIME2(7) NOT NULL
        CONSTRAINT DF_rule_execution_audit_at DEFAULT (SYSUTCDATETIME()),
    rule_id INT NULL,
    action_name NVARCHAR(120) NOT NULL,
    old_state VARCHAR(30) NULL,
    new_state VARCHAR(30) NULL,
    old_signature VARBINARY(32) NULL,
    new_signature VARBINARY(32) NULL,
    exceptions_deleted BIGINT NULL,
    note NVARCHAR(1000) NULL
);
GO
