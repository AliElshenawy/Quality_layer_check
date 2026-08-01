/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dq].[run_active_catalog_rules]
(
    @MaxRowsPerRule BIGINT = 100000,
    @MaxExceptionsPerRule INT = 500
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF @MaxRowsPerRule < 0
    BEGIN
        THROW 53001,
              'MaxRowsPerRule must be zero or positive.',
              1;
    END;

    IF @MaxExceptionsPerRule < 0
    BEGIN
        THROW 53002,
              'MaxExceptionsPerRule must be zero or positive.',
              1;
    END;

    CREATE TABLE #RuleResults
    (
        rule_id INT NOT NULL,
        etl_run_id BIGINT NULL,

        object_name NVARCHAR(300) NOT NULL,
        check_name NVARCHAR(400) NOT NULL,
        severity NVARCHAR(40) NOT NULL,

        rows_checked BIGINT NULL,
        failed_count BIGINT NULL,

        check_status NVARCHAR(40) NOT NULL,
        details NVARCHAR(MAX) NULL
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
            CONSTRAINT PK_ExecutedRules PRIMARY KEY
    );

    DECLARE
        @RuleId INT,
        @ObjectName NVARCHAR(300),
        @SourceView SYSNAME,
        @CheckName NVARCHAR(400),
        @CheckType NVARCHAR(100),
        @ResolvedColumn SYSNAME,
        @Severity NVARCHAR(40),

        @SourceObjectId INT,
        @QualifiedSource NVARCHAR(600),

        @TopClause NVARCHAR(100),
        @IdExpression NVARCHAR(MAX),
        @EtlRunExpression NVARCHAR(MAX),
        @FailurePredicate NVARCHAR(MAX),

        @SQL NVARCHAR(MAX),
        @ErrorMessage NVARCHAR(4000);

    DECLARE rule_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        rule_id,
        object_name,
        source_view,
        check_name,
        check_type,
        resolved_column,
        severity

    FROM dq.vw_rule_readiness

    WHERE is_active = 1
      AND readiness_status = N'ACTIVE'

      AND check_type IN
      (
          N'NOT_NULL',
          N'VALID_DATETIME',
          N'VALID_SALESFORCE_ID',
          N'VALID_BOOLEAN'
      )

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
        @Severity;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY

            SET @SourceObjectId = OBJECT_ID(@SourceView);

            IF @SourceObjectId IS NULL
            BEGIN
                THROW 53003,
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
            BEGIN
                THROW 53004,
                      'Resolved target column does not exist.',
                      1;
            END;

            SET @QualifiedSource =
                QUOTENAME
                (
                    PARSENAME(@SourceView, 2)
                )
                + N'.'
                + QUOTENAME
                (
                    PARSENAME(@SourceView, 1)
                );

            IF @MaxRowsPerRule = 0
            BEGIN
                SET @TopClause = N'';
            END;
            ELSE
            BEGIN
                SET @TopClause =
                    N'TOP (@MaximumRows) ';
            END;

            /* Dynamically detect the record identifier */

            IF EXISTS
            (
                SELECT 1
                FROM sys.columns
                WHERE object_id = @SourceObjectId
                  AND name = N'Id'
            )
            BEGIN
                SET @IdExpression = N'
                    COALESCE
                    (
                        TRY_CONVERT
                        (
                            VARCHAR(18),
                            [Id]
                        ),
                        ''[NULL_ID]''
                    )';
            END;
            ELSE
            BEGIN
                SET @IdExpression =
                    N'CAST(NULL AS VARCHAR(18))';
            END;

            /* Dynamically detect the ETL run identifier */

            IF EXISTS
            (
                SELECT 1
                FROM sys.columns
                WHERE object_id = @SourceObjectId
                  AND name = N'_etl_run_id'
            )
            BEGIN
                SET @EtlRunExpression = N'
                    TRY_CONVERT
                    (
                        BIGINT,
                        [_etl_run_id]
                    )';
            END;
            ELSE
            BEGIN
                SET @EtlRunExpression =
                    N'CAST(NULL AS BIGINT)';
            END;

            /* Generic rule templates */

            IF @CheckType = N'NOT_NULL'
            BEGIN
                SET @FailurePredicate = N'
                    NULLIF
                    (
                        LTRIM
                        (
                            RTRIM
                            (
                                value_text
                            )
                        ),
                        N''''
                    ) IS NULL';
            END;

            ELSE IF @CheckType = N'VALID_DATETIME'
            BEGIN
                SET @FailurePredicate = N'
                    NULLIF
                    (
                        LTRIM
                        (
                            RTRIM
                            (
                                value_text
                            )
                        ),
                        N''''
                    ) IS NOT NULL

                    AND COALESCE
                    (
                        TRY_CONVERT
                        (
                            DATETIME2(7),
                            value_text,
                            127
                        ),
                        TRY_CONVERT
                        (
                            DATETIME2(7),
                            value_text,
                            126
                        ),
                        TRY_CONVERT
                        (
                            DATETIME2(7),
                            value_text
                        )
                    ) IS NULL';
            END;

            ELSE IF @CheckType = N'VALID_SALESFORCE_ID'
            BEGIN
                SET @FailurePredicate = N'
                    NULLIF
                    (
                        LTRIM
                        (
                            RTRIM
                            (
                                value_text
                            )
                        ),
                        N''''
                    ) IS NOT NULL

                    AND
                    (
                        LEN
                        (
                            LTRIM
                            (
                                RTRIM
                                (
                                    value_text
                                )
                            )
                        ) NOT IN (15, 18)

                        OR LTRIM
                           (
                               RTRIM
                               (
                                   value_text
                               )
                           )
                           LIKE N''%[^0-9A-Za-z]%''
                    )';
            END;

            ELSE IF @CheckType = N'VALID_BOOLEAN'
            BEGIN
                SET @FailurePredicate = N'
                    NULLIF
                    (
                        LTRIM
                        (
                            RTRIM
                            (
                                value_text
                            )
                        ),
                        N''''
                    ) IS NOT NULL

                    AND LOWER
                    (
                        LTRIM
                        (
                            RTRIM
                            (
                                value_text
                            )
                        )
                    ) NOT IN
                    (
                        N''true'',
                        N''false'',
                        N''1'',
                        N''0'',
                        N''yes'',
                        N''no'',
                        N''y'',
                        N''n''
                    )';
            END;

            SET @SQL = N'
                DROP TABLE IF EXISTS #RuleSample;

                SELECT '
                    + @TopClause
                    + N'
                    '
                    + @IdExpression
                    + N' AS record_id,

                    TRY_CONVERT
                    (
                        NVARCHAR(4000),
                        '
                        + QUOTENAME(@ResolvedColumn)
                        + N'
                    ) AS value_text,

                    '
                    + @EtlRunExpression
                    + N' AS etl_run_id

                INTO #RuleSample

                FROM '
                + @QualifiedSource
                + N' WITH (READUNCOMMITTED);

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

                    ISNULL
                    (
                        SUM
                        (
                            CASE
                                WHEN '
                                + @FailurePredicate
                                + N'
                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),
                        0
                    ),

                    CASE
                        WHEN ISNULL
                             (
                                 SUM
                                 (
                                     CASE
                                         WHEN '
                                         + @FailurePredicate
                                         + N'
                                         THEN CONVERT(BIGINT, 1)
                                         ELSE CONVERT(BIGINT, 0)
                                     END
                                 ),
                                 0
                             ) = 0
                        THEN N''PASS''
                        ELSE N''FAIL''
                    END,

                    CONCAT
                    (
                        N''Rule type: '',
                        @CheckType,
                        N''. Source: '',
                        @SourceView,
                        N''. Column: '',
                        @ResolvedColumn,
                        N''. Execution mode: '',
                        CASE
                            WHEN @MaximumRows = 0
                            THEN N''FULL''
                            ELSE N''SAMPLE''
                        END,
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
                        N''Rule: '',
                        @CheckName,
                        N''. Type: '',
                        @CheckType,
                        N''. Source: '',
                        @SourceView,
                        N''. Column: '',
                        @ResolvedColumn,
                        N''.''
                    )

                FROM #RuleSample

                WHERE '
                + @FailurePredicate
                + N'

                GROUP BY record_id
                ORDER BY record_id;

                DROP TABLE #RuleSample;
            ';

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
                    @ExceptionLimit INT
                ',

                @RuleId = @RuleId,
                @ObjectName = @ObjectName,
                @SourceView = @SourceView,
                @CheckName = @CheckName,
                @CheckType = @CheckType,
                @ResolvedColumn = @ResolvedColumn,
                @Severity = @Severity,
                @MaximumRows = @MaxRowsPerRule,
                @ExceptionLimit = @MaxExceptionsPerRule;

            INSERT INTO #ExecutedRules
            (
                rule_id
            )
            VALUES
            (
                @RuleId
            );

            RAISERROR
            (
                'Executed rule %d: %s.',
                0,
                1,
                @RuleId,
                @CheckName
            ) WITH NOWAIT;

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
                NULL,
                N'ERROR',
                @ErrorMessage
            );

            RAISERROR
            (
                'Rule %d failed: %s.',
                0,
                1,
                @RuleId,
                @ErrorMessage
            ) WITH NOWAIT;

        END CATCH;

        FETCH NEXT FROM rule_cursor
        INTO
            @RuleId,
            @ObjectName,
            @SourceView,
            @CheckName,
            @CheckType,
            @ResolvedColumn,
            @Severity;
    END;

    CLOSE rule_cursor;
    DEALLOCATE rule_cursor;

    /* Store aggregate rule results */

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
        failed_count,
        check_status,
        details
    FROM #RuleResults;

    /* Refresh exceptions already open */

    UPDATE existing_exception
    SET
        existing_exception.etl_run_id =
            current_failure.etl_run_id,

        existing_exception.exception_value =
            current_failure.exception_value,

        existing_exception.exception_details =
            current_failure.exception_details,

        existing_exception.last_detected_at =
            SYSDATETIME(),

        existing_exception.resolution_status =
            N'Open',

        existing_exception.resolved_at = NULL,
        existing_exception.resolved_by = NULL

    FROM dq.dq_exceptions AS existing_exception

    INNER JOIN #CurrentFailures AS current_failure
        ON current_failure.rule_id =
           existing_exception.rule_id

       AND ISNULL(current_failure.record_id, N'') =
           ISNULL(existing_exception.record_id, N'')

    WHERE existing_exception.resolution_status = N'Open';

    /* Insert newly detected exceptions */

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

        WHERE existing_exception.rule_id =
              current_failure.rule_id

          AND ISNULL(existing_exception.record_id, N'') =
              ISNULL(current_failure.record_id, N'')

          AND existing_exception.resolution_status = N'Open'
    );

    /*
        Resolve old exceptions only during a full-data run.
        A sample run must not resolve records it did not inspect.
    */

    IF @MaxRowsPerRule = 0
    BEGIN
        UPDATE existing_exception
        SET
            existing_exception.resolution_status =
                N'Resolved',

            existing_exception.resolved_at =
                SYSDATETIME(),

            existing_exception.resolved_by =
                N'Dynamic DQ Engine'

        FROM dq.dq_exceptions AS existing_exception

        INNER JOIN #ExecutedRules AS executed_rule
            ON executed_rule.rule_id =
               existing_exception.rule_id

        WHERE existing_exception.resolution_status = N'Open'

          AND NOT EXISTS
          (
              SELECT 1
              FROM #CurrentFailures AS current_failure

              WHERE current_failure.rule_id =
                    existing_exception.rule_id

                AND ISNULL(current_failure.record_id, N'') =
                    ISNULL(existing_exception.record_id, N'')
          );
    END;

    /* Summary */

    SELECT
        COUNT(*) AS rules_executed,

        SUM
        (
            CASE
                WHEN check_status = N'PASS'
                THEN 1
                ELSE 0
            END
        ) AS passed_rules,

        SUM
        (
            CASE
                WHEN check_status = N'FAIL'
                THEN 1
                ELSE 0
            END
        ) AS failed_rules,

        SUM
        (
            CASE
                WHEN check_status = N'ERROR'
                THEN 1
                ELSE 0
            END
        ) AS error_rules,

        SUM(rows_checked) AS total_rows_checked,
        SUM(failed_count) AS total_failed_rows,

        COUNT
        (
            DISTINCT object_name
        ) AS objects_checked

    FROM #RuleResults;

    /* Details */

    SELECT
        rule_id,
        object_name,
        check_name,
        severity,
        rows_checked,
        failed_count,

        CONVERT
        (
            DECIMAL(12,4),
            100.0
            * (rows_checked - failed_count)
            / NULLIF(rows_checked, 0)
        ) AS pass_percentage,

        check_status,
        details

    FROM #RuleResults

    ORDER BY
        CASE check_status
            WHEN N'ERROR' THEN 1
            WHEN N'FAIL' THEN 2
            ELSE 3
        END,
        object_name,
        rule_id;
END;
GO
