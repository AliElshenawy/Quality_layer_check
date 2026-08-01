/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dq].[run_dynamic_technical_checks]
(
    @MaxRowsPerObject BIGINT = 100000
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE
        @DQRunId UNIQUEIDENTIFIER = NEWID(),
        @StartedAt DATETIME2(7) = SYSDATETIME(),

        @ObjectRegistryId INT,
        @ObjectName SYSNAME,

        @SourceSchema SYSNAME,
        @SourceTable SYSNAME,

        @IdColumn SYSNAME,
        @WatermarkColumn SYSNAME,
        @DeletedFlagColumn SYSNAME,
        @EtlRunColumn SYSNAME,

        @QualifiedSource NVARCHAR(600),
        @SourceObjectText NVARCHAR(600),

        @SelectColumns NVARCHAR(MAX),
        @TopClause NVARCHAR(100),
        @SQL NVARCHAR(MAX),

        @CheckedRows BIGINT,
        @IdNullRows BIGINT,
        @IdInvalidRows BIGINT,
        @WatermarkNullRows BIGINT,
        @WatermarkInvalidRows BIGINT,
        @EtlRunInvalidRows BIGINT,
        @DeletedFlagInvalidRows BIGINT,

        @WatermarkNullExpression NVARCHAR(MAX),
        @WatermarkInvalidExpression NVARCHAR(MAX),
        @EtlRunInvalidExpression NVARCHAR(MAX),
        @DeletedFlagInvalidExpression NVARCHAR(MAX);

    IF @MaxRowsPerObject < 0
    BEGIN
        THROW 51001,
              'MaxRowsPerObject must be zero or a positive number.',
              1;
    END;

    INSERT INTO dq.technical_run
    (
        dq_run_id,
        started_at,
        max_rows_per_object,
        run_status
    )
    VALUES
    (
        @DQRunId,
        @StartedAt,
        @MaxRowsPerObject,
        'Running'
    );

    BEGIN TRY

        DECLARE object_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            object_registry_id,
            object_name,
            source_schema,
            source_table,
            id_column,
            watermark_column,
            deleted_flag_column,
            etl_run_column

        FROM ctl.object_registry

        WHERE is_active = 1
          AND id_column IS NOT NULL

        ORDER BY object_registry_id;

        OPEN object_cursor;

        FETCH NEXT FROM object_cursor
        INTO
            @ObjectRegistryId,
            @ObjectName,
            @SourceSchema,
            @SourceTable,
            @IdColumn,
            @WatermarkColumn,
            @DeletedFlagColumn,
            @EtlRunColumn;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @QualifiedSource =
                QUOTENAME(@SourceSchema)
                + N'.'
                + QUOTENAME(@SourceTable);

            SET @SourceObjectText =
                @SourceSchema
                + N'.'
                + @SourceTable;

            /*
                Select only technical columns.
                Do not read all 526 Contact columns.
            */

            SET @SelectColumns =
                QUOTENAME(@IdColumn);

            IF @WatermarkColumn IS NOT NULL
               AND @WatermarkColumn <> @IdColumn
            BEGIN
                SET @SelectColumns +=
                    N', ' + QUOTENAME(@WatermarkColumn);
            END;

            IF @DeletedFlagColumn IS NOT NULL
               AND @DeletedFlagColumn <> @IdColumn
               AND ISNULL(@DeletedFlagColumn, N'')
                   <> ISNULL(@WatermarkColumn, N'')
            BEGIN
                SET @SelectColumns +=
                    N', ' + QUOTENAME(@DeletedFlagColumn);
            END;

            IF @EtlRunColumn IS NOT NULL
               AND @EtlRunColumn <> @IdColumn
               AND ISNULL(@EtlRunColumn, N'')
                   <> ISNULL(@WatermarkColumn, N'')
               AND ISNULL(@EtlRunColumn, N'')
                   <> ISNULL(@DeletedFlagColumn, N'')
            BEGIN
                SET @SelectColumns +=
                    N', ' + QUOTENAME(@EtlRunColumn);
            END;

            IF @MaxRowsPerObject = 0
            BEGIN
                SET @TopClause = N'';
            END;
            ELSE
            BEGIN
                SET @TopClause =
                    N'TOP ('
                    + CONVERT(NVARCHAR(30), @MaxRowsPerObject)
                    + N') ';
            END;

            /* Optional watermark checks */

            IF @WatermarkColumn IS NULL
            BEGIN
                SET @WatermarkNullExpression =
                    N'CONVERT(BIGINT, 0)';

                SET @WatermarkInvalidExpression =
                    N'CONVERT(BIGINT, 0)';
            END;
            ELSE
            BEGIN
                SET @WatermarkNullExpression = N'
                    ISNULL
                    (
                        SUM
                        (
                            CASE
                                WHEN NULLIF
                                     (
                                         LTRIM
                                         (
                                             RTRIM
                                             (
                                                 TRY_CONVERT
                                                 (
                                                     NVARCHAR(100),
                                                     '
                                                     + QUOTENAME(@WatermarkColumn)
                                                     + N'
                                                 )
                                             )
                                         ),
                                         N''''
                                     ) IS NULL
                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),
                        0
                    )';

                SET @WatermarkInvalidExpression = N'
                    ISNULL
                    (
                        SUM
                        (
                            CASE
                                WHEN NULLIF
                                     (
                                         LTRIM
                                         (
                                             RTRIM
                                             (
                                                 TRY_CONVERT
                                                 (
                                                     NVARCHAR(100),
                                                     '
                                                     + QUOTENAME(@WatermarkColumn)
                                                     + N'
                                                 )
                                             )
                                         ),
                                         N''''
                                     ) IS NOT NULL

                                 AND COALESCE
                                     (
                                         TRY_CONVERT
                                         (
                                             DATETIME2(7),
                                             '
                                             + QUOTENAME(@WatermarkColumn)
                                             + N',
                                             127
                                         ),
                                         TRY_CONVERT
                                         (
                                             DATETIME2(7),
                                             '
                                             + QUOTENAME(@WatermarkColumn)
                                             + N'
                                         )
                                     ) IS NULL

                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),
                        0
                    )';
            END;

            /* Optional ETL run checks */

            IF @EtlRunColumn IS NULL
            BEGIN
                SET @EtlRunInvalidExpression =
                    N'CONVERT(BIGINT, 0)';
            END;
            ELSE
            BEGIN
                SET @EtlRunInvalidExpression = N'
                    ISNULL
                    (
                        SUM
                        (
                            CASE
                                WHEN TRY_CONVERT
                                     (
                                         BIGINT,
                                         '
                                         + QUOTENAME(@EtlRunColumn)
                                         + N'
                                     ) IS NULL
                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),
                        0
                    )';
            END;

            /* Optional deletion-flag checks */

            IF @DeletedFlagColumn IS NULL
            BEGIN
                SET @DeletedFlagInvalidExpression =
                    N'CONVERT(BIGINT, 0)';
            END;
            ELSE
            BEGIN
                SET @DeletedFlagInvalidExpression = N'
                    ISNULL
                    (
                        SUM
                        (
                            CASE
                                WHEN NULLIF
                                     (
                                         LTRIM
                                         (
                                             RTRIM
                                             (
                                                 TRY_CONVERT
                                                 (
                                                     NVARCHAR(50),
                                                     '
                                                     + QUOTENAME(@DeletedFlagColumn)
                                                     + N'
                                                 )
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
                                                 TRY_CONVERT
                                                 (
                                                     NVARCHAR(50),
                                                     '
                                                     + QUOTENAME(@DeletedFlagColumn)
                                                     + N'
                                                 )
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
                                     )

                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),
                        0
                    )';
            END;

            /*
                One scan per object.
                All technical metrics are calculated together.
            */

            SET @SQL = N'
                ;WITH source_rows AS
                (
                    SELECT '
                    + @TopClause
                    + @SelectColumns
                    + N'
                    FROM '
                    + @QualifiedSource
                    + N' WITH (READUNCOMMITTED)
                )
                SELECT
                    @CheckedRowsOutput = COUNT_BIG(*),

                    @IdNullRowsOutput =
                        ISNULL
                        (
                            SUM
                            (
                                CASE
                                    WHEN NULLIF
                                         (
                                             LTRIM
                                             (
                                                 RTRIM
                                                 (
                                                     TRY_CONVERT
                                                     (
                                                         NVARCHAR(100),
                                                         '
                                                         + QUOTENAME(@IdColumn)
                                                         + N'
                                                     )
                                                 )
                                             ),
                                             N''''
                                         ) IS NULL
                                    THEN CONVERT(BIGINT, 1)
                                    ELSE CONVERT(BIGINT, 0)
                                END
                            ),
                            0
                        ),

                    @IdInvalidRowsOutput =
                        ISNULL
                        (
                            SUM
                            (
                                CASE
                                    WHEN NULLIF
                                         (
                                             LTRIM
                                             (
                                                 RTRIM
                                                 (
                                                     TRY_CONVERT
                                                     (
                                                         NVARCHAR(100),
                                                         '
                                                         + QUOTENAME(@IdColumn)
                                                         + N'
                                                     )
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
                                                     TRY_CONVERT
                                                     (
                                                         NVARCHAR(100),
                                                         '
                                                         + QUOTENAME(@IdColumn)
                                                         + N'
                                                     )
                                                 )
                                             )
                                         ) NOT IN (15, 18)

                                         OR LTRIM
                                            (
                                                RTRIM
                                                (
                                                    TRY_CONVERT
                                                    (
                                                        NVARCHAR(100),
                                                        '
                                                        + QUOTENAME(@IdColumn)
                                                        + N'
                                                    )
                                                )
                                            )
                                            LIKE N''%[^0-9A-Za-z]%''
                                     )

                                    THEN CONVERT(BIGINT, 1)
                                    ELSE CONVERT(BIGINT, 0)
                                END
                            ),
                            0
                        ),

                    @WatermarkNullRowsOutput =
                        '
                        + @WatermarkNullExpression
                        + N',

                    @WatermarkInvalidRowsOutput =
                        '
                        + @WatermarkInvalidExpression
                        + N',

                    @EtlRunInvalidRowsOutput =
                        '
                        + @EtlRunInvalidExpression
                        + N',

                    @DeletedFlagInvalidRowsOutput =
                        '
                        + @DeletedFlagInvalidExpression
                        + N'

                FROM source_rows
                OPTION (MAXDOP 1);
            ';

            SET @CheckedRows = 0;
            SET @IdNullRows = 0;
            SET @IdInvalidRows = 0;
            SET @WatermarkNullRows = 0;
            SET @WatermarkInvalidRows = 0;
            SET @EtlRunInvalidRows = 0;
            SET @DeletedFlagInvalidRows = 0;

            EXEC sys.sp_executesql
                @SQL,

                N'
                    @CheckedRowsOutput BIGINT OUTPUT,
                    @IdNullRowsOutput BIGINT OUTPUT,
                    @IdInvalidRowsOutput BIGINT OUTPUT,
                    @WatermarkNullRowsOutput BIGINT OUTPUT,
                    @WatermarkInvalidRowsOutput BIGINT OUTPUT,
                    @EtlRunInvalidRowsOutput BIGINT OUTPUT,
                    @DeletedFlagInvalidRowsOutput BIGINT OUTPUT
                ',

                @CheckedRowsOutput =
                    @CheckedRows OUTPUT,

                @IdNullRowsOutput =
                    @IdNullRows OUTPUT,

                @IdInvalidRowsOutput =
                    @IdInvalidRows OUTPUT,

                @WatermarkNullRowsOutput =
                    @WatermarkNullRows OUTPUT,

                @WatermarkInvalidRowsOutput =
                    @WatermarkInvalidRows OUTPUT,

                @EtlRunInvalidRowsOutput =
                    @EtlRunInvalidRows OUTPUT,

                @DeletedFlagInvalidRowsOutput =
                    @DeletedFlagInvalidRows OUTPUT;

            /* Insert applicable technical rules */

            INSERT INTO dq.technical_result
            (
                dq_run_id,
                object_registry_id,
                object_name,
                source_object,
                rule_code,
                rule_description,
                checked_rows,
                failed_rows,
                pass_percentage,
                result_status
            )
            SELECT
                @DQRunId,
                @ObjectRegistryId,
                @ObjectName,
                @SourceObjectText,

                rules.rule_code,
                rules.rule_description,

                @CheckedRows,
                rules.failed_rows,

                CONVERT
                (
                    DECIMAL(12,4),
                    100.0
                    * (@CheckedRows - rules.failed_rows)
                    / NULLIF(@CheckedRows, 0)
                ),

                CASE
                    WHEN @CheckedRows = 0
                        THEN 'WARNING'

                    WHEN rules.failed_rows = 0
                        THEN 'PASS'

                    ELSE 'FAIL'
                END

            FROM
            (
                VALUES
                (
                    N'ID_NOT_NULL',
                    N'Salesforce Id must not be null or blank.',
                    @IdNullRows,
                    CONVERT(BIT, 1)
                ),
                (
                    N'ID_VALID_FORMAT',
                    N'Salesforce Id must contain 15 or 18 alphanumeric characters.',
                    @IdInvalidRows,
                    CONVERT(BIT, 1)
                ),
                (
                    N'WATERMARK_NOT_NULL',
                    N'Watermark value must not be null.',
                    @WatermarkNullRows,
                    CONVERT
                    (
                        BIT,
                        CASE
                            WHEN @WatermarkColumn IS NULL THEN 0
                            ELSE 1
                        END
                    )
                ),
                (
                    N'WATERMARK_VALID',
                    N'Watermark value must contain a valid date and time.',
                    @WatermarkInvalidRows,
                    CONVERT
                    (
                        BIT,
                        CASE
                            WHEN @WatermarkColumn IS NULL THEN 0
                            ELSE 1
                        END
                    )
                ),
                (
                    N'ETL_RUN_VALID',
                    N'ETL run identifier must contain a valid number.',
                    @EtlRunInvalidRows,
                    CONVERT
                    (
                        BIT,
                        CASE
                            WHEN @EtlRunColumn IS NULL THEN 0
                            ELSE 1
                        END
                    )
                ),
                (
                    N'DELETED_FLAG_VALID',
                    N'Deleted flag must contain a recognized Boolean value.',
                    @DeletedFlagInvalidRows,
                    CONVERT
                    (
                        BIT,
                        CASE
                            WHEN @DeletedFlagColumn IS NULL THEN 0
                            ELSE 1
                        END
                    )
                )
            ) AS rules
            (
                rule_code,
                rule_description,
                failed_rows,
                is_applicable
            )

            WHERE rules.is_applicable = 1;

            RAISERROR
            (
                'Completed technical DQ checks for %s: %I64d rows checked.',
                0,
                1,
                @ObjectName,
                @CheckedRows
            ) WITH NOWAIT;

            FETCH NEXT FROM object_cursor
            INTO
                @ObjectRegistryId,
                @ObjectName,
                @SourceSchema,
                @SourceTable,
                @IdColumn,
                @WatermarkColumn,
                @DeletedFlagColumn,
                @EtlRunColumn;
        END;

        CLOSE object_cursor;
        DEALLOCATE object_cursor;

        UPDATE dq.technical_run
        SET
            completed_at = SYSDATETIME(),
            run_status = 'Succeeded'
        WHERE dq_run_id = @DQRunId;

    END TRY
    BEGIN CATCH

        IF CURSOR_STATUS('local', 'object_cursor') >= 0
        BEGIN
            CLOSE object_cursor;
        END;

        IF CURSOR_STATUS('local', 'object_cursor') > -3
        BEGIN
            DEALLOCATE object_cursor;
        END;

        UPDATE dq.technical_run
        SET
            completed_at = SYSDATETIME(),
            run_status = 'Failed',
            error_message = ERROR_MESSAGE()
        WHERE dq_run_id = @DQRunId;

        THROW;
    END CATCH;

    /* Summary */

    SELECT
        @DQRunId AS dq_run_id,
        COUNT(DISTINCT object_registry_id) AS objects_checked,
        COUNT(*) AS rules_executed,

        SUM
        (
            CASE
                WHEN result_status = 'PASS' THEN 1
                ELSE 0
            END
        ) AS passed_rules,

        SUM
        (
            CASE
                WHEN result_status = 'FAIL' THEN 1
                ELSE 0
            END
        ) AS failed_rules,

        SUM(checked_rows) AS total_rule_rows_checked,
        SUM(failed_rows) AS total_failed_rows

    FROM dq.technical_result
    WHERE dq_run_id = @DQRunId;

    /* Details */

    SELECT
        object_name,
        source_object,
        rule_code,
        checked_rows,
        failed_rows,
        pass_percentage,
        result_status,
        rule_description

    FROM dq.technical_result

    WHERE dq_run_id = @DQRunId

    ORDER BY
        CASE result_status
            WHEN 'FAIL' THEN 1
            WHEN 'WARNING' THEN 2
            ELSE 3
        END,
        object_name,
        rule_code;
END;
GO
