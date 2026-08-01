/* ============================================================================
   Author: Mohey
   Origin: Added to the database after the base structure (DQ watermark framework).
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [dq].[rule_action_config]
(
    rule_id INT NOT NULL
        CONSTRAINT PK_rule_action_config PRIMARY KEY,
    action_mode VARCHAR(20) NOT NULL
        CONSTRAINT DF_rule_action_config_mode DEFAULT ('DETECT_ONLY'),
    update_sql NVARCHAR(MAX) NULL,
    is_active BIT NOT NULL
        CONSTRAINT DF_rule_action_config_active DEFAULT (1),
    updated_at DATETIME2(7) NOT NULL
        CONSTRAINT DF_rule_action_config_updated DEFAULT (SYSUTCDATETIME())
);
GO
