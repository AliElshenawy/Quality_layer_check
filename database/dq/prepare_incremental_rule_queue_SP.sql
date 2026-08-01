/* ============================================================================
   Author: Mohey
   Origin: Added to the database after the base structure (DQ watermark framework).
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/* ============================================================================
    2) PREPARE QUEUE (register rules, resolve watermark column, flag core changes)
   ============================================================================ */

CREATE OR ALTER PROCEDURE dq.prepare_incremental_rule_queue
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    CREATE TABLE #MergeAudit
    (
        merge_action NVARCHAR(10) NOT NULL,
        rule_id INT NOT NULL,
        old_signature VARBINARY(32) NULL,
        new_signature VARBINARY(32) NULL,
        old_core_signature VARBINARY(32) NULL,
        new_core_signature VARBINARY(32) NULL,
        watermark_column SYSNAME NULL
    );

    ;WITH RuleSource AS
    (
        SELECT
            r.rule_id,
            /* Full signature: any field change (used only to stamp last_changed_at). */
            HASHBYTES
            (
                'SHA2_256',
                CONCAT_WS
                (
                    N'|',
                    CONVERT(NVARCHAR(20), r.rule_id),
                    ISNULL(r.object_name, N''),
                    ISNULL(r.source_view, N''),
                    ISNULL(r.check_name, N''),
                    ISNULL(r.check_type, N''),
                    ISNULL(r.target_column, N''),
                    ISNULL(r.severity, N''),
                    ISNULL(r.description, N''),
                    ISNULL(r.rule_definition, N''),
                    CONVERT(NVARCHAR(1), r.is_active)
                )
            ) AS rule_signature,
            /* Core signature: ONLY fields that change which rows pass/fail. */
            HASHBYTES
            (
                'SHA2_256',
                CONCAT_WS
                (
                    N'|',
                    ISNULL(r.object_name, N''),
                    ISNULL(r.source_view, N''),
                    ISNULL(r.check_type, N''),
                    ISNULL(r.target_column, N''),
                    ISNULL(r.rule_definition, N''),
                    CONVERT(NVARCHAR(1), r.is_active)
                )
            ) AS rule_core_signature,
            /* Resolve the source watermark column (NULL => rule is not batchable). */
            (
                SELECT TOP (1) c.name
                FROM sys.columns AS c
                WHERE c.object_id = OBJECT_ID(r.source_view)
                  AND c.name IN (N'SystemModstamp', N'LastModifiedDate', N'_etl_loaded_at_utc')
                ORDER BY CASE c.name
                            WHEN N'SystemModstamp' THEN 1
                            WHEN N'LastModifiedDate' THEN 2
                            ELSE 3
                         END
            ) AS watermark_column
        FROM dq.dq_rule_catalog AS r
        LEFT JOIN dq.vw_rule_readiness AS v
            ON v.rule_id = r.rule_id
        WHERE r.is_active = 1
          AND r.check_type IN
          (
              N'NOT_NULL',
              N'VALID_DATETIME',
              N'VALID_SALESFORCE_ID',
              N'VALID_BOOLEAN',
              N'CUSTOM_SQL'
          )
          AND
          (
              r.check_type = N'CUSTOM_SQL'
              OR
              (
                  v.is_active = 1
                  AND v.readiness_status = N'ACTIVE'
                  AND v.check_type IN
                  (
                      N'NOT_NULL',
                      N'VALID_DATETIME',
                      N'VALID_SALESFORCE_ID',
                      N'VALID_BOOLEAN'
                  )
              )
          )
    )
    MERGE dq.rule_execution_state AS tgt
    USING RuleSource AS src
        ON tgt.rule_id = src.rule_id

    WHEN MATCHED
    THEN
        UPDATE SET
            tgt.rule_signature = src.rule_signature,
            tgt.rule_core_signature = src.rule_core_signature,
            tgt.source_watermark_column = src.watermark_column,
            /* Core change => flag for operator review. Never auto-rescan. */
            tgt.reprocess_review_pending =
                CASE
                    WHEN tgt.rule_core_signature <> src.rule_core_signature THEN 1
                    ELSE tgt.reprocess_review_pending
                END,
            tgt.last_changed_at =
                CASE
                    WHEN tgt.rule_signature <> src.rule_signature THEN SYSUTCDATETIME()
                    ELSE tgt.last_changed_at
                END,
            tgt.last_prepared_at = SYSUTCDATETIME()

    WHEN NOT MATCHED BY TARGET
    THEN
        INSERT
        (
            rule_id,
            rule_signature,
            rule_core_signature,
            last_applied_core_signature,
            source_watermark_column,
            last_source_watermark_value,
            reprocess_review_pending,
            first_seen_at,
            last_prepared_at,
            last_changed_at
        )
        VALUES
        (
            src.rule_id,
            src.rule_signature,
            src.rule_core_signature,
            NULL,
            src.watermark_column,
            NULL,          -- never processed yet: scan from the beginning
            0,
            SYSUTCDATETIME(),
            SYSUTCDATETIME(),
            SYSUTCDATETIME()
        )

    OUTPUT
        $action,
        inserted.rule_id,
        deleted.rule_signature,
        inserted.rule_signature,
        deleted.rule_core_signature,
        inserted.rule_core_signature,
        inserted.source_watermark_column
    INTO #MergeAudit;

    INSERT INTO dq.rule_execution_audit
    (
        rule_id,
        action_name,
        old_signature,
        new_signature,
        note
    )
    SELECT
        m.rule_id,
        CASE
            WHEN m.watermark_column IS NULL THEN N'RULE_REJECTED_NO_WATERMARK'
            WHEN m.merge_action = N'INSERT' THEN N'RULE_DISCOVERED'
            WHEN m.old_core_signature <> m.new_core_signature THEN N'RULE_CORE_CHANGED_REVIEW'
            WHEN m.old_signature <> m.new_signature THEN N'RULE_METADATA_UPDATED'
            ELSE N'RULE_PREPARED'
        END,
        m.old_signature,
        m.new_signature,
        CASE
            WHEN m.watermark_column IS NULL
                THEN N'Source has no watermark column (SystemModstamp/LastModifiedDate/_etl_loaded_at_utc); rule cannot run incrementally.'
            WHEN m.merge_action = N'UPDATE' AND m.old_core_signature <> m.new_core_signature
                THEN N'Rule core logic changed. reprocess_review_pending=1. ASK operator: REPROCESS (reset watermark) vs JUST UPDATE.'
            ELSE N'Queue preparation completed.'
        END
    FROM #MergeAudit AS m;

    /* Summary: what the operator needs to decide on. */
    SELECT
        SUM(CASE WHEN s.reprocess_review_pending = 1 THEN 1 ELSE 0 END) AS rules_awaiting_reprocess_review,
        SUM(CASE WHEN s.source_watermark_column IS NULL THEN 1 ELSE 0 END) AS rules_missing_watermark,
        COUNT(*) AS total_active_rules
    FROM dq.rule_execution_state AS s
    INNER JOIN dq.dq_rule_catalog AS r
        ON r.rule_id = s.rule_id
    WHERE r.is_active = 1;
END;
GO
