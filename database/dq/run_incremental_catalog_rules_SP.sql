/* ============================================================================
   Author: Mohey
   Origin: Added to the database after the base structure (DQ watermark framework).
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/* ============================================================================
   3) INCREMENTAL RUNNER (watermark-driven)

   Parameters:
     @MaxRowsPerRule      Batch size of NEW rows (watermark > cursor) per rule.
                          0 = no cap (process every new row this run).
     @MaxExceptionsPerRule Cap on exception rows persisted per rule per batch.
     @RunOnlyPending      LEGACY / no-op. There are no pending/done states; every
                          eligible rule is checked and caught-up rules return 0 rows.
     @ObjectNameFilter    Restrict to one object.
     @ForceRuleId         Run a single rule (still watermark-driven).
     @ResolveWhenFull     When 1, auto-resolve exceptions for records re-checked
                          this run that no longer fail.
     @IncludeCustomSql    Include CUSTOM_SQL rules.
   ============================================================================ */

CREATE OR ALTER PROCEDURE dq.run_incremental_catalog_rules
(
    @MaxRowsPerRule BIGINT = 100000,
    @MaxExceptionsPerRule INT = 500,
    @RunOnlyPending BIT = 1,
    @ObjectNameFilter NVARCHAR(150) = NULL,
    @ForceRuleId INT = NULL,
    @ResolveWhenFull BIT = 1,
    @IncludeCustomSql BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF @MaxRowsPerRule < 0
    BEGIN
        THROW 53101,
              'MaxRowsPerRule must be zero or positive.',
              1;
    END;

    IF @MaxExceptionsPerRule < 0
    BEGIN
        THROW 53102,
              'MaxExceptionsPerRule must be zero or positive.',
              1;
    END;

    IF @ObjectNameFilter IS NOT NULL
       AND LEN(LTRIM(RTRIM(@ObjectNameFilter))) = 0
    BEGIN
        SET @ObjectNameFilter = NULL;
    END;

    EXEC dq.prepare_incremental_rule_queue;

    CREATE TABLE #RuleResults
    (
        rule_result_sequence INT IDENTITY(1,1) NOT NULL,
        rule_id INT NOT NULL,
        etl_run_id BIGINT NULL,
        object_name NVARCHAR(300) NOT NULL,
        check_name NVARCHAR(400) NOT NULL,
        severity NVARCHAR(40) NOT NULL,
        rows_checked BIGINT NULL,
        failed_count BIGINT NULL,
        check_status NVARCHAR(40) NOT NULL,
        details NVARCHAR(MAX) NULL,
        result_persisted BIT NOT NULL DEFAULT (0)
    );

    CREATE TABLE #CurrentFailures
    (
        rule_id INT NOT NULL,
        etl_run_id BIGINT NULL,
        object_name NVARCHAR(300) NOT NULL,
        record_id VARCHAR(18) NULL,
        exception_value NVARCHAR(4000) NULL,
        exception_details NVARCHAR(MAX) NULL
    );

    CREATE TABLE #ExecutedRules
    (
        rule_id INT NOT NULL
            CONSTRAINT PK_ExecutedRules_Incremental PRIMARY KEY
    );

    /* Record grain actually re-checked this run (drives incremental resolution). */
    CREATE TABLE #CheckedRecords
    (
        rule_id INT NOT NULL,
        record_id VARCHAR(18) NULL
    );

    CREATE TABLE #Queue
    (
        rule_id INT NOT NULL,
        object_name NVARCHAR(300) NOT NULL,
        source_view SYSNAME NOT NULL,
        check_name NVARCHAR(400) NOT NULL,
        check_type NVARCHAR(100) NOT NULL,
        resolved_column SYSNAME NULL,
        severity NVARCHAR(40) NOT NULL,
        rule_definition NVARCHAR(MAX) NULL,
        rule_core_signature VARBINARY(32) NULL,
        watermark_column SYSNAME NULL,
        last_watermark_value DATETIME2(7) NULL
    );

    INSERT INTO #Queue
    (
        rule_id,
        object_name,
        source_view,
        check_name,
        check_type,
        resolved_column,
        severity,
        rule_definition,
        rule_core_signature,
        watermark_column,
        last_watermark_value
    )
    SELECT
        r.rule_id,
        r.object_name,
        r.source_view,
        r.check_name,
        r.check_type,
        CASE
            WHEN r.check_type = N'CUSTOM_SQL' THEN NULL
            ELSE COALESCE(v.resolved_column, r.target_column)
        END AS resolved_column,
        r.severity,
        r.rule_definition,
        s.rule_core_signature,
        s.source_watermark_column,
        s.last_source_watermark_value
    FROM dq.dq_rule_catalog AS r
    INNER JOIN dq.rule_execution_state AS s
        ON s.rule_id = r.rule_id
    LEFT JOIN dq.vw_rule_readiness AS v
        ON v.rule_id = r.rule_id
    WHERE r.is_active = 1
      AND
      (
          r.check_type IN
          (
              N'NOT_NULL',
              N'VALID_DATETIME',
              N'VALID_SALESFORCE_ID',
              N'VALID_BOOLEAN'
          )
          OR (@IncludeCustomSql = 1 AND r.check_type = N'CUSTOM_SQL')
      )
      AND
      (
          (r.check_type = N'CUSTOM_SQL' AND @IncludeCustomSql = 1)
          OR
          (
              v.is_active = 1
              AND v.readiness_status = N'ACTIVE'
          )
      )
      /* Watermark model: every eligible rule is queued. Rules already caught up
         simply return zero new rows in the batch fetch (a cheap indexed range on
         the watermark). A rule must have a resolved watermark column to be
         batchable; rules without one were rejected at prepare time. */
      AND s.source_watermark_column IS NOT NULL
      AND
      (
          @ForceRuleId IS NULL
          OR r.rule_id = @ForceRuleId
      );

    IF @ObjectNameFilter IS NOT NULL
    BEGIN
        DELETE q
        FROM #Queue AS q
        WHERE UPPER(q.object_name) <> UPPER(@ObjectNameFilter);
    END;

    IF NOT EXISTS (SELECT 1 FROM #Queue)
    BEGIN
        SELECT
            CAST(0 AS INT) AS rules_selected,
            N'No rules selected. Queue is up to date.' AS message;
        RETURN;
    END;

    DECLARE
        @RuleId INT,
        @ObjectName NVARCHAR(300),
        @SourceView SYSNAME,
        @CheckName NVARCHAR(400),
        @CheckType NVARCHAR(100),
        @ResolvedColumn SYSNAME,
        @Severity NVARCHAR(40),
        @RuleDefinition NVARCHAR(MAX),
        @CoreSignature VARBINARY(32),
        @WatermarkColumn SYSNAME,
        @LastWatermark DATETIME2(7),

        @SourceObjectId INT,
        @QualifiedSource NVARCHAR(600),
        @IdExpression NVARCHAR(MAX),
        @EtlRunExpression NVARCHAR(MAX),
        @FailurePredicate NVARCHAR(MAX),
        @WatermarkExpr NVARCHAR(MAX),
        @EffectiveTop BIGINT,
        @RowsInBatch BIGINT,
        @NewWatermark DATETIME2(7),
        @RemainingAfter BIGINT,
        @LatestRuleResultSequence INT,

        @SQL NVARCHAR(MAX),
        @ErrorMessage NVARCHAR(4000),
        @RuleStatus NVARCHAR(40),
        @RuleFailedCount BIGINT,
        @RunStartTime DATETIME2(7);

    SET @RunStartTime = SYSDATETIME();

    DECLARE rule_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        rule_id,
        object_name,
        source_view,
        check_name,
        check_type,
        resolved_column,
        severity,
        rule_definition,
        rule_core_signature,
        watermark_column,
        last_watermark_value
    FROM #Queue
    ORDER BY rule_id;

    OPEN rule_cursor;

    FETCH NEXT FROM rule_cursor
    INTO
        @RuleId,
        @ObjectName,
        @SourceView,
        @CheckName,
        @CheckType,
        @ResolvedColumn,
        @Severity,
        @RuleDefinition,
        @CoreSignature,
        @WatermarkColumn,
        @LastWatermark;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            UPDATE dq.rule_execution_state
            SET
                last_run_started_at = SYSUTCDATETIME(),
                last_run_status = 'RUNNING',
                last_error_message = NULL
            WHERE rule_id = @RuleId;

            SET @SourceObjectId = OBJECT_ID(@SourceView);

            IF @SourceObjectId IS NULL
            BEGIN
                THROW 53103,
                      'Configured source object does not exist.',
                      1;
            END;

            IF NOT EXISTS
            (
                SELECT 1
                FROM sys.columns
                WHERE object_id = @SourceObjectId
                  AND name = @ResolvedColumn
            )
                             AND @CheckType <> N'CUSTOM_SQL'
            BEGIN
                THROW 53104,
                      'Resolved target column does not exist.',
                      1;
            END;

            SET @QualifiedSource =
                QUOTENAME(PARSENAME(@SourceView, 2)) + N'.' + QUOTENAME(PARSENAME(@SourceView, 1));

            IF EXISTS
            (
                SELECT 1
                FROM sys.columns
                WHERE object_id = @SourceObjectId
                  AND name = N'Id'
            )
            BEGIN
                SET @IdExpression = N'COALESCE(TRY_CONVERT(VARCHAR(18), [Id]), ''[NULL_ID]'')';
            END;
            ELSE
            BEGIN
                SET @IdExpression = N'CAST(NULL AS VARCHAR(18))';
            END;

            IF EXISTS
            (
                SELECT 1
                FROM sys.columns
                WHERE object_id = @SourceObjectId
                  AND name = N'_etl_run_id'
            )
            BEGIN
                SET @EtlRunExpression = N'TRY_CONVERT(BIGINT, [_etl_run_id])';
            END;
            ELSE
            BEGIN
                SET @EtlRunExpression = N'CAST(NULL AS BIGINT)';
            END;

            /* The watermark column was resolved at prepare time; validate it. */
            IF @WatermarkColumn IS NULL
               OR NOT EXISTS
               (
                   SELECT 1 FROM sys.columns
                   WHERE object_id = @SourceObjectId AND name = @WatermarkColumn
               )
            BEGIN
                THROW 53106,
                      'Source watermark column is missing; rule is not batchable.',
                      1;
            END;

            /* Deterministic datetime watermark expression used for filter/order/value. */
            SET @WatermarkExpr = N'
                COALESCE
                (
                    TRY_CONVERT(DATETIME2(7), source_data.' + QUOTENAME(@WatermarkColumn) + N', 127),
                    TRY_CONVERT(DATETIME2(7), source_data.' + QUOTENAME(@WatermarkColumn) + N', 126),
                    TRY_CONVERT(DATETIME2(7), source_data.' + QUOTENAME(@WatermarkColumn) + N'),
                    CONVERT(DATETIME2(7), ''0001-01-01'')
                )';

            /* @MaxRowsPerRule = 0 means "no cap": process every new row this run. */
            SET @EffectiveTop =
                CASE WHEN @MaxRowsPerRule = 0 THEN 9223372036854775807 ELSE @MaxRowsPerRule END;

            IF @CheckType = N'NOT_NULL'
            BEGIN
                SET @FailurePredicate = N'NULLIF(LTRIM(RTRIM(value_text)), N'''') IS NULL';
            END;
            ELSE IF @CheckType = N'VALID_DATETIME'
            BEGIN
                SET @FailurePredicate = N'
                    NULLIF(LTRIM(RTRIM(value_text)), N'''') IS NOT NULL
                    AND COALESCE
                    (
                        TRY_CONVERT(DATETIME2(7), value_text, 127),
                        TRY_CONVERT(DATETIME2(7), value_text, 126),
                        TRY_CONVERT(DATETIME2(7), value_text)
                    ) IS NULL';
            END;
            ELSE IF @CheckType = N'VALID_SALESFORCE_ID'
            BEGIN
                SET @FailurePredicate = N'
                    NULLIF(LTRIM(RTRIM(value_text)), N'''') IS NOT NULL
                    AND
                    (
                        LEN(LTRIM(RTRIM(value_text))) NOT IN (15, 18)
                        OR LTRIM(RTRIM(value_text)) LIKE N''%[^0-9A-Za-z]%''
                    )';
            END;
            ELSE IF @CheckType = N'VALID_BOOLEAN'
            BEGIN
                SET @FailurePredicate = N'
                    NULLIF(LTRIM(RTRIM(value_text)), N'''') IS NOT NULL
                    AND LOWER(LTRIM(RTRIM(value_text))) NOT IN
                    (
                        N''true'', N''false'', N''1'', N''0'', N''yes'', N''no'', N''y'', N''n''
                    )';
            END;

            IF @CheckType = N'CUSTOM_SQL'
            BEGIN
                IF NULLIF(LTRIM(RTRIM(COALESCE(@RuleDefinition, N''))), N'') IS NULL
                BEGIN
                    THROW 53105,
                          'CUSTOM_SQL rule requires rule_definition SQL.',
                          1;
                END;

                SET @SQL = REPLACE(@RuleDefinition, N'{{SOURCE_VIEW}}', N'#RuleSourceBatch');

                SET @SQL = N'
                    DROP TABLE IF EXISTS #RuleSourceBatch;
                    DROP TABLE IF EXISTS #RuleCustomFailures;

                    SELECT TOP (@MaximumRows) source_data.*,
                        ' + @WatermarkExpr + N' AS dq_watermark_value
                    INTO #RuleSourceBatch
                    FROM ' + @QualifiedSource + N' AS source_data WITH (READUNCOMMITTED)
                    WHERE @LastWatermark IS NULL
                       OR ' + @WatermarkExpr + N' > @LastWatermark
                    ORDER BY ' + @WatermarkExpr + N';

                    SELECT
                        @RowsInBatch = COUNT_BIG(*),
                        @NewWatermark = MAX(dq_watermark_value)
                    FROM #RuleSourceBatch;

                    SELECT @RemainingAfter =
                        CASE WHEN @NewWatermark IS NULL THEN 0
                        ELSE
                        (
                            SELECT COUNT_BIG(*)
                            FROM ' + @QualifiedSource + N' AS source_data WITH (READUNCOMMITTED)
                            WHERE ' + @WatermarkExpr + N' > @NewWatermark
                        ) END;

                    INSERT INTO #CheckedRecords (rule_id, record_id)
                    SELECT @RuleId, ' + @IdExpression + N'
                    FROM #RuleSourceBatch
                    WHERE ' + @IdExpression + N' <> N''[NULL_ID]'';

                    SELECT
                        TRY_CONVERT(VARCHAR(18), record_id) AS record_id,
                        TRY_CONVERT(NVARCHAR(4000), exception_value) AS exception_value,
                        TRY_CONVERT(NVARCHAR(MAX), exception_details) AS exception_details,
                        TRY_CONVERT(BIGINT, etl_run_id) AS etl_run_id
                    INTO #RuleCustomFailures
                    FROM (
                        ' + @SQL + N'
                    ) AS src;

                    INSERT INTO #RuleResults
                    (
                        rule_id,
                        etl_run_id,
                        object_name,
                        check_name,
                        severity,
                        rows_checked,
                        failed_count,
                        check_status,
                        details
                    )
                    SELECT
                        @RuleId,
                        MAX(etl_run_id),
                        @ObjectName,
                        @CheckName,
                        @Severity,
                        @RowsInBatch,
                        COUNT_BIG(*),
                        CASE WHEN COUNT_BIG(*) = 0 THEN N''PASS'' ELSE N''FAIL'' END,
                        CONCAT
                        (
                            N''Rule type: CUSTOM_SQL. Source: '', @SourceView,
                            N''. New rows this batch: '', CONVERT(NVARCHAR(30), @RowsInBatch),
                            N''. Watermark advanced to: '', CONVERT(NVARCHAR(40), @NewWatermark, 121),
                            N''. Rows still behind: '', CONVERT(NVARCHAR(30), @RemainingAfter),
                            N''. Exception cap: '', CONVERT(NVARCHAR(30), @ExceptionLimit),
                            N''.''
                        )
                    FROM #RuleCustomFailures;

                    INSERT INTO #CurrentFailures
                    (
                        rule_id,
                        etl_run_id,
                        object_name,
                        record_id,
                        exception_value,
                        exception_details
                    )
                    SELECT TOP (@ExceptionLimit)
                        @RuleId,
                        etl_run_id,
                        @ObjectName,
                        record_id,
                        exception_value,
                        exception_details
                    FROM #RuleCustomFailures
                    ORDER BY record_id;

                    DROP TABLE #RuleCustomFailures;
                    DROP TABLE #RuleSourceBatch;';

                EXEC sys.sp_executesql
                    @SQL,
                    N'
                        @RuleId INT,
                        @ObjectName NVARCHAR(300),
                        @SourceView SYSNAME,
                        @CheckName NVARCHAR(400),
                        @Severity NVARCHAR(40),
                        @MaximumRows BIGINT,
                        @ExceptionLimit INT,
                        @LastWatermark DATETIME2(7),
                        @RowsInBatch BIGINT OUTPUT,
                        @NewWatermark DATETIME2(7) OUTPUT,
                        @RemainingAfter BIGINT OUTPUT
                    ',
                    @RuleId = @RuleId,
                    @ObjectName = @ObjectName,
                    @SourceView = @SourceView,
                    @CheckName = @CheckName,
                    @Severity = @Severity,
                    @MaximumRows = @EffectiveTop,
                    @ExceptionLimit = @MaxExceptionsPerRule,
                    @LastWatermark = @LastWatermark,
                    @RowsInBatch = @RowsInBatch OUTPUT,
                    @NewWatermark = @NewWatermark OUTPUT,
                    @RemainingAfter = @RemainingAfter OUTPUT;

                GOTO AfterRuleExecution;
            END;

            SET @SQL = N'
                DROP TABLE IF EXISTS #RuleSourceBatch;
                DROP TABLE IF EXISTS #RuleSample;

                SELECT TOP (@MaximumRows) source_data.*,
                    ' + @WatermarkExpr + N' AS dq_watermark_value
                INTO #RuleSourceBatch
                FROM ' + @QualifiedSource + N' AS source_data WITH (READUNCOMMITTED)
                WHERE @LastWatermark IS NULL
                   OR ' + @WatermarkExpr + N' > @LastWatermark
                ORDER BY ' + @WatermarkExpr + N';

                SELECT
                    @RowsInBatch = COUNT_BIG(*),
                    @NewWatermark = MAX(dq_watermark_value)
                FROM #RuleSourceBatch;

                SELECT @RemainingAfter =
                    CASE WHEN @NewWatermark IS NULL THEN 0
                    ELSE
                    (
                        SELECT COUNT_BIG(*)
                        FROM ' + @QualifiedSource + N' AS source_data WITH (READUNCOMMITTED)
                        WHERE ' + @WatermarkExpr + N' > @NewWatermark
                    ) END;

                SELECT
                    ' + @IdExpression + N' AS record_id,
                    TRY_CONVERT(NVARCHAR(4000), ' + QUOTENAME(@ResolvedColumn) + N') AS value_text,
                    ' + @EtlRunExpression + N' AS etl_run_id
                INTO #RuleSample
                FROM #RuleSourceBatch;

                INSERT INTO #CheckedRecords (rule_id, record_id)
                SELECT @RuleId, record_id
                FROM #RuleSample
                WHERE record_id IS NOT NULL
                  AND record_id <> N''[NULL_ID]'';

                INSERT INTO #RuleResults
                (
                    rule_id,
                    etl_run_id,
                    object_name,
                    check_name,
                    severity,
                    rows_checked,
                    failed_count,
                    check_status,
                    details
                )
                SELECT
                    @RuleId,
                    MAX(etl_run_id),
                    @ObjectName,
                    @CheckName,
                    @Severity,
                    COUNT_BIG(*),
                    ISNULL(SUM(CASE WHEN ' + @FailurePredicate + N' THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END), 0),
                    CASE
                        WHEN ISNULL(SUM(CASE WHEN ' + @FailurePredicate + N' THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END), 0) = 0
                        THEN N''PASS''
                        ELSE N''FAIL''
                    END,
                    CONCAT
                    (
                        N''Rule type: '', @CheckType,
                        N''. Source: '', @SourceView,
                        N''. Column: '', @ResolvedColumn,
                        N''. New rows this batch: '', CONVERT(NVARCHAR(30), @RowsInBatch),
                        N''. Watermark advanced to: '', CONVERT(NVARCHAR(40), @NewWatermark, 121),
                        N''. Rows still behind: '', CONVERT(NVARCHAR(30), @RemainingAfter),
                        N''.''
                    )
                FROM #RuleSample;

                INSERT INTO #CurrentFailures
                (
                    rule_id,
                    etl_run_id,
                    object_name,
                    record_id,
                    exception_value,
                    exception_details
                )
                SELECT TOP (@ExceptionLimit)
                    @RuleId,
                    MAX(etl_run_id),
                    @ObjectName,
                    record_id,
                    MAX(value_text),
                    CONCAT
                    (
                        N''Rule: '', @CheckName,
                        N''. Type: '', @CheckType,
                        N''. Source: '', @SourceView,
                        N''. Column: '', @ResolvedColumn,
                        N''.''
                    )
                FROM #RuleSample
                WHERE ' + @FailurePredicate + N'
                GROUP BY record_id
                ORDER BY record_id;

                DROP TABLE #RuleSample;
                DROP TABLE #RuleSourceBatch;';

            EXEC sys.sp_executesql
                @SQL,
                N'
                    @RuleId INT,
                    @ObjectName NVARCHAR(300),
                    @SourceView SYSNAME,
                    @CheckName NVARCHAR(400),
                    @CheckType NVARCHAR(100),
                    @ResolvedColumn SYSNAME,
                    @Severity NVARCHAR(40),
                    @MaximumRows BIGINT,
                    @ExceptionLimit INT,
                    @LastWatermark DATETIME2(7),
                    @RowsInBatch BIGINT OUTPUT,
                    @NewWatermark DATETIME2(7) OUTPUT,
                    @RemainingAfter BIGINT OUTPUT
                ',
                @RuleId = @RuleId,
                @ObjectName = @ObjectName,
                @SourceView = @SourceView,
                @CheckName = @CheckName,
                @CheckType = @CheckType,
                @ResolvedColumn = @ResolvedColumn,
                @Severity = @Severity,
                @MaximumRows = @EffectiveTop,
                @ExceptionLimit = @MaxExceptionsPerRule,
                @LastWatermark = @LastWatermark,
                @RowsInBatch = @RowsInBatch OUTPUT,
                @NewWatermark = @NewWatermark OUTPUT,
                @RemainingAfter = @RemainingAfter OUTPUT;

            AfterRuleExecution:

            SET @RowsInBatch = ISNULL(@RowsInBatch, 0);
            SET @RemainingAfter = ISNULL(@RemainingAfter, 0);

            INSERT INTO #ExecutedRules(rule_id)
            SELECT @RuleId
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM #ExecutedRules AS executed_rule
                WHERE executed_rule.rule_id = @RuleId
            );

            SELECT TOP (1)
                @LatestRuleResultSequence = rule_result_sequence,
                @RuleStatus = check_status,
                @RuleFailedCount = failed_count
            FROM #RuleResults
            WHERE rule_id = @RuleId
            ORDER BY rule_result_sequence DESC;

            SET @RuleFailedCount = ISNULL(@RuleFailedCount, 0);

            INSERT INTO dq.dq_results
            (
                etl_run_id,
                object_name,
                check_name,
                severity,
                rows_checked,
                failed_count,
                check_status,
                details
            )
            SELECT
                etl_run_id,
                object_name,
                check_name,
                severity,
                rows_checked,
                ISNULL(failed_count, 0),
                check_status,
                details
            FROM #RuleResults
            WHERE rule_result_sequence = @LatestRuleResultSequence;

            UPDATE #RuleResults
            SET result_persisted = 1
            WHERE rule_result_sequence = @LatestRuleResultSequence;

            UPDATE existing_exception
            SET
                existing_exception.etl_run_id = current_failure.etl_run_id,
                existing_exception.exception_value = current_failure.exception_value,
                existing_exception.exception_details = current_failure.exception_details,
                existing_exception.last_detected_at = SYSDATETIME(),
                existing_exception.resolution_status = N'Open',
                existing_exception.resolved_at = NULL,
                existing_exception.resolved_by = NULL
            FROM dq.dq_exceptions AS existing_exception
            INNER JOIN #CurrentFailures AS current_failure
                ON current_failure.rule_id = existing_exception.rule_id
               AND ISNULL(current_failure.record_id, N'') = ISNULL(existing_exception.record_id, N'')
            WHERE current_failure.rule_id = @RuleId
              AND existing_exception.resolution_status = N'Open';

            INSERT INTO dq.dq_exceptions
            (
                rule_id,
                etl_run_id,
                object_name,
                record_id,
                exception_value,
                exception_details
            )
            SELECT
                current_failure.rule_id,
                current_failure.etl_run_id,
                current_failure.object_name,
                current_failure.record_id,
                current_failure.exception_value,
                current_failure.exception_details
            FROM #CurrentFailures AS current_failure
            WHERE current_failure.rule_id = @RuleId
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM dq.dq_exceptions AS existing_exception
                  WHERE existing_exception.rule_id = current_failure.rule_id
                    AND ISNULL(existing_exception.record_id, N'') = ISNULL(current_failure.record_id, N'')
                    AND existing_exception.resolution_status = N'Open'
              );

            DELETE FROM #CurrentFailures
            WHERE rule_id = @RuleId;

            /* Incremental resolution: a record re-entered the watermark window
               (its source row changed) and no longer fails => resolve it. Only
               records actually re-checked this run qualify, so we never falsely
               resolve a record we did not look at. */
            IF @ResolveWhenFull = 1
            BEGIN
                UPDATE existing_exception
                SET
                    existing_exception.resolution_status = N'Resolved',
                    existing_exception.resolved_at = SYSDATETIME(),
                    existing_exception.resolved_by = N'Incremental DQ Engine'
                FROM dq.dq_exceptions AS existing_exception
                INNER JOIN #CheckedRecords AS checked_record
                    ON checked_record.rule_id = existing_exception.rule_id
                   AND ISNULL(checked_record.record_id, N'') = ISNULL(existing_exception.record_id, N'')
                WHERE existing_exception.rule_id = @RuleId
                  AND existing_exception.resolution_status = N'Open'
                  AND existing_exception.last_detected_at < @RunStartTime;
            END;

            DELETE FROM #CheckedRecords
            WHERE rule_id = @RuleId;

            /* Advance the watermark ONLY when new rows were processed.
               No new rows => CAUGHT_UP (waiting). Rows still behind => BATCHED. */
            UPDATE dq.rule_execution_state
            SET
                last_source_watermark_value = CASE
                                                  WHEN @RowsInBatch > 0 THEN @NewWatermark
                                                  ELSE last_source_watermark_value
                                              END,
                last_applied_core_signature = CASE
                                                  WHEN @RowsInBatch > 0 THEN @CoreSignature
                                                  ELSE last_applied_core_signature
                                              END,
                last_run_completed_at = SYSUTCDATETIME(),
                last_run_status = CASE
                                      WHEN @RowsInBatch = 0 THEN 'CAUGHT_UP'
                                      WHEN @RemainingAfter > 0 THEN 'BATCHED'
                                      WHEN @RuleFailedCount = 0 THEN 'CAUGHT_UP'
                                      ELSE 'FAIL'
                                  END,
                last_run_rows_checked = @RowsInBatch,
                last_run_failed_count = @RuleFailedCount,
                run_count = run_count + 1
            WHERE rule_id = @RuleId;

            RAISERROR('Rule %d (%s): checked %I64d new rows, %I64d failed, %I64d still behind.', 0, 1, @RuleId, @CheckName, @RowsInBatch, @RuleFailedCount, @RemainingAfter) WITH NOWAIT;
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();

            INSERT INTO #RuleResults
            (
                rule_id,
                etl_run_id,
                object_name,
                check_name,
                severity,
                rows_checked,
                failed_count,
                check_status,
                details
            )
            VALUES
            (
                @RuleId,
                NULL,
                @ObjectName,
                @CheckName,
                @Severity,
                NULL,
                0,
                N'ERROR',
                @ErrorMessage
            );

            UPDATE dq.rule_execution_state
            SET
                last_run_completed_at = SYSUTCDATETIME(),
                last_run_status = 'ERROR',
                last_error_message = @ErrorMessage,
                run_count = run_count + 1
            WHERE rule_id = @RuleId;

            RAISERROR('Incremental rule %d failed: %s.', 0, 1, @RuleId, @ErrorMessage) WITH NOWAIT;
        END CATCH;

        FETCH NEXT FROM rule_cursor
        INTO
            @RuleId,
            @ObjectName,
            @SourceView,
            @CheckName,
            @CheckType,
            @ResolvedColumn,
            @Severity,
            @RuleDefinition,
            @CoreSignature,
            @WatermarkColumn,
            @LastWatermark;
    END;

    CLOSE rule_cursor;
    DEALLOCATE rule_cursor;

    INSERT INTO dq.dq_results
    (
        etl_run_id,
        object_name,
        check_name,
        severity,
        rows_checked,
        failed_count,
        check_status,
        details
    )
    SELECT
        etl_run_id,
        object_name,
        check_name,
        severity,
        rows_checked,
        ISNULL(failed_count, 0),
        check_status,
        details
    FROM #RuleResults
    WHERE result_persisted = 0;

    UPDATE existing_exception
    SET
        existing_exception.etl_run_id = current_failure.etl_run_id,
        existing_exception.exception_value = current_failure.exception_value,
        existing_exception.exception_details = current_failure.exception_details,
        existing_exception.last_detected_at = SYSDATETIME(),
        existing_exception.resolution_status = N'Open',
        existing_exception.resolved_at = NULL,
        existing_exception.resolved_by = NULL
    FROM dq.dq_exceptions AS existing_exception
    INNER JOIN #CurrentFailures AS current_failure
        ON current_failure.rule_id = existing_exception.rule_id
       AND ISNULL(current_failure.record_id, N'') = ISNULL(existing_exception.record_id, N'')
    WHERE existing_exception.resolution_status = N'Open';

    INSERT INTO dq.dq_exceptions
    (
        rule_id,
        etl_run_id,
        object_name,
        record_id,
        exception_value,
        exception_details
    )
    SELECT
        current_failure.rule_id,
        current_failure.etl_run_id,
        current_failure.object_name,
        current_failure.record_id,
        current_failure.exception_value,
        current_failure.exception_details
    FROM #CurrentFailures AS current_failure
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dq.dq_exceptions AS existing_exception
        WHERE existing_exception.rule_id = current_failure.rule_id
          AND ISNULL(existing_exception.record_id, N'') = ISNULL(current_failure.record_id, N'')
          AND existing_exception.resolution_status = N'Open'
    );

    /* Incremental resolution is performed per-rule inside the loop (only records
       actually re-checked this run are eligible), so no full-table resolve pass
       is needed or safe here. To force a clean re-scan of a rule, reset its
       last_source_watermark_value to NULL and re-run. */

    SELECT
        COUNT(*) AS rules_selected,
        SUM(CASE WHEN check_status = N'PASS' THEN 1 ELSE 0 END) AS passed_rules,
        SUM(CASE WHEN check_status = N'FAIL' THEN 1 ELSE 0 END) AS failed_rules,
        SUM(CASE WHEN check_status = N'ERROR' THEN 1 ELSE 0 END) AS error_rules,
        ISNULL(SUM(rows_checked), 0) AS total_rows_checked,
        ISNULL(SUM(failed_count), 0) AS total_failed_rows
    FROM #RuleResults;

    SELECT
        rule_id,
        object_name,
        check_name,
        severity,
        rows_checked,
        failed_count,
        check_status,
        details
    FROM #RuleResults
    ORDER BY
        CASE
            WHEN check_status = N'ERROR' THEN 1
            WHEN check_status = N'FAIL' THEN 2
            ELSE 3
        END,
        failed_count DESC,
        rule_id ASC;
END;
GO
