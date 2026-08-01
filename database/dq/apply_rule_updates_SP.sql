/* ============================================================================
   Author: Mohey
   Origin: Added to the database after the base structure (DQ watermark framework).
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/* ============================================================================
   4) OPTIONAL FUTURE EXTENSION: APPLY UPDATES (AUTO-FIX)
   ============================================================================ */

CREATE OR ALTER PROCEDURE dq.apply_rule_updates
(
    @RuleId INT = NULL,
    @DryRun BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @CurrentRuleId INT,
        @UpdateSql NVARCHAR(MAX),
        @RowsAffected INT;

    CREATE TABLE #UpdateAudit
    (
        rule_id INT NOT NULL,
        dry_run BIT NOT NULL,
        rows_affected INT NULL,
        message NVARCHAR(1000) NULL,
        executed_at DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()
    );

    DECLARE update_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        c.rule_id,
        c.update_sql
    FROM dq.rule_action_config AS c
    INNER JOIN dq.rule_execution_state AS s
        ON s.rule_id = c.rule_id
    WHERE c.is_active = 1
      AND c.action_mode = 'AUTO_FIX'
      AND c.update_sql IS NOT NULL
      AND LEN(LTRIM(RTRIM(c.update_sql))) > 0
      AND (@RuleId IS NULL OR c.rule_id = @RuleId)
      AND s.last_run_completed_at IS NOT NULL;

    OPEN update_cursor;
    FETCH NEXT FROM update_cursor INTO @CurrentRuleId, @UpdateSql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            IF @DryRun = 1
            BEGIN
                INSERT INTO #UpdateAudit(rule_id, dry_run, rows_affected, message)
                VALUES (@CurrentRuleId, 1, NULL, N'Dry run only. SQL not executed.');
            END;
            ELSE
            BEGIN
                BEGIN TRANSACTION;
                    EXEC sys.sp_executesql @UpdateSql;
                    SET @RowsAffected = @@ROWCOUNT;
                COMMIT TRANSACTION;

                INSERT INTO #UpdateAudit(rule_id, dry_run, rows_affected, message)
                VALUES (@CurrentRuleId, 0, @RowsAffected, N'Auto-fix update executed.');
            END;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            INSERT INTO #UpdateAudit(rule_id, dry_run, rows_affected, message)
            VALUES (@CurrentRuleId, @DryRun, NULL, ERROR_MESSAGE());
        END CATCH;

        FETCH NEXT FROM update_cursor INTO @CurrentRuleId, @UpdateSql;
    END;

    CLOSE update_cursor;
    DEALLOCATE update_cursor;

    SELECT *
    FROM #UpdateAudit
    ORDER BY executed_at DESC, rule_id ASC;
END;
GO
