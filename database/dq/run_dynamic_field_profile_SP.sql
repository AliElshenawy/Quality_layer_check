/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dq].[run_dynamic_field_profile]
(
    @SampleRowsPerObject INT = 5000,
    @ColumnsPerBatch INT = 25
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF @SampleRowsPerObject <= 0
    BEGIN
        THROW 52001,
              'SampleRowsPerObject must be greater than zero.',
              1;
    END;

    IF @ColumnsPerBatch <= 0
    BEGIN
        THROW 52002,
              'ColumnsPerBatch must be greater than zero.',
              1;
    END;

    DECLARE
        @ProfileRunId UNIQUEIDENTIFIER = NEWID(),

        @ObjectRegistryId INT,
        @ObjectName SYSNAME,
        @SourceSchema SYSNAME,
        @SourceTable SYSNAME,

        @QualifiedSource NVARCHAR(600),
        @SourceObjectText NVARCHAR(600),

        @SourceObjectId INT,
        @ApproximateTotalRows BIGINT,

        @BatchNumber INT,
        @MaximumBatch INT,

        @ColumnId INT,
        @ColumnName SYSNAME,
        @SqlDataType SYSNAME,

        @SelectColumns NVARCHAR(MAX),
        @ValueRows NVARCHAR(MAX),
        @Separator NVARCHAR(20),

        @SQL NVARCHAR(MAX);

    INSERT INTO dq.profile_run
    (
        profile_run_id,
        started_at,
        sample_rows_per_object,
        columns_per_batch,
        run_status
    )
    VALUES
    (
        @ProfileRunId,
        SYSDATETIME(),
        @SampleRowsPerObject,
        @ColumnsPerBatch,
        'Running'
    );

    CREATE TABLE #ObjectColumns
    (
        batch_number INT NOT NULL,
        column_id INT NOT NULL,
        column_name SYSNAME NOT NULL,
        sql_data_type SYSNAME NOT NULL
    );

    BEGIN TRY

        DECLARE object_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            object_registry_id,
            object_name,
            source_schema,
            source_table
        FROM ctl.object_registry
        WHERE is_active = 1
        ORDER BY object_registry_id;

        OPEN object_cursor;

        FETCH NEXT FROM object_cursor
        INTO
            @ObjectRegistryId,
            @ObjectName,
            @SourceSchema,
            @SourceTable;

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

            SET @SourceObjectId =
                OBJECT_ID
                (
                    @SourceSchema
                    + N'.'
                    + @SourceTable,
                    N'U'
                );

            IF @SourceObjectId IS NULL
            BEGIN
                RAISERROR
                (
                    'Skipped missing object %s.',
                    0,
                    1,
                    @SourceObjectText
                ) WITH NOWAIT;

                FETCH NEXT FROM object_cursor
                INTO
                    @ObjectRegistryId,
                    @ObjectName,
                    @SourceSchema,
                    @SourceTable;

                CONTINUE;
            END;

            SELECT
                @ApproximateTotalRows =
                    ISNULL
                    (
                        SUM
                        (
                            CONVERT
                            (
                                BIGINT,
                                row_count
                            )
                        ),
                        0
                    )
            FROM sys.dm_db_partition_stats
            WHERE object_id = @SourceObjectId
              AND index_id IN (0, 1);

            TRUNCATE TABLE #ObjectColumns;

            INSERT INTO #ObjectColumns
            (
                batch_number,
                column_id,
                column_name,
                sql_data_type
            )
            SELECT
                (
                    (
                        ROW_NUMBER() OVER
                        (
                            ORDER BY c.column_id
                        ) - 1
                    ) / @ColumnsPerBatch
                ) + 1,

                c.column_id,
                c.name,
                t.name

            FROM sys.columns AS c

            INNER JOIN sys.types AS t
                ON t.user_type_id = c.user_type_id

            WHERE c.object_id = @SourceObjectId

              /* Technical fields already checked separately */
              AND c.name NOT LIKE N'[_]etl[_]%'

              AND t.name NOT IN
              (
                  N'image',
                  N'text',
                  N'ntext',
                  N'timestamp',
                  N'rowversion',
                  N'sql_variant',
                  N'geography',
                  N'geometry',
                  N'hierarchyid',
                  N'binary',
                  N'varbinary'
              );

            SELECT
                @MaximumBatch = MAX(batch_number)
            FROM #ObjectColumns;

            SET @BatchNumber = 1;

            WHILE @BatchNumber <= ISNULL(@MaximumBatch, 0)
            BEGIN
                SET @SelectColumns = N'';
                SET @ValueRows = N'';
                SET @Separator = N'';

                DECLARE column_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT
                    column_id,
                    column_name,
                    sql_data_type
                FROM #ObjectColumns
                WHERE batch_number = @BatchNumber
                ORDER BY column_id;

                OPEN column_cursor;

                FETCH NEXT FROM column_cursor
                INTO
                    @ColumnId,
                    @ColumnName,
                    @SqlDataType;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SET @SelectColumns =
                        @SelectColumns
                        + CASE
                            WHEN @SelectColumns = N''
                                THEN N''
                            ELSE N','
                          END
                        + QUOTENAME(@ColumnName);

                    SET @ValueRows =
                        @ValueRows
                        + @Separator
                        + N'
                        (
                            '
                            + CONVERT
                              (
                                  NVARCHAR(20),
                                  @ColumnId
                              )
                            + N',

                            N'''
                            + REPLACE
                              (
                                  @ColumnName,
                                  N'''',
                                  N''''''
                              )
                            + N''',

                            N'''
                            + REPLACE
                              (
                                  @SqlDataType,
                                  N'''',
                                  N''''''
                              )
                            + N''',

                            CASE
                                WHEN source_rows.'
                                + QUOTENAME(@ColumnName)
                                + N' IS NULL
                                THEN CONVERT(INT, 1)
                                ELSE CONVERT(INT, 0)
                            END,

                            TRY_CONVERT
                            (
                                NVARCHAR(4000),
                                source_rows.'
                                + QUOTENAME(@ColumnName)
                                + N'
                            )
                        )';

                    SET @Separator = N',';

                    FETCH NEXT FROM column_cursor
                    INTO
                        @ColumnId,
                        @ColumnName,
                        @SqlDataType;
                END;

                CLOSE column_cursor;
                DEALLOCATE column_cursor;

                SET @SQL = N'
                    ;WITH source_rows AS
                    (
                        SELECT TOP (@SampleRows)
                            '
                            + @SelectColumns
                            + N'
                        FROM '
                        + @QualifiedSource
                        + N' WITH (READUNCOMMITTED)
                    ),
                    long_values AS
                    (
                        SELECT
                            values_list.column_id,
                            values_list.column_name,
                            values_list.sql_data_type,
                            values_list.is_null,
                            values_list.value_text,

                            NULLIF
                            (
                                LTRIM
                                (
                                    RTRIM
                                    (
                                        values_list.value_text
                                    )
                                ),
                                N''''
                            ) AS trimmed_value

                        FROM source_rows

                        CROSS APPLY
                        (
                            VALUES
                                '
                                + @ValueRows
                                + N'
                        ) AS values_list
                        (
                            column_id,
                            column_name,
                            sql_data_type,
                            is_null,
                            value_text
                        )
                    )

                    INSERT INTO dq.field_profile
                    (
                        profile_run_id,
                        object_registry_id,
                        object_name,
                        source_object,

                        column_id,
                        column_name,
                        sql_data_type,

                        approximate_total_rows,
                        sampled_rows,
                        sample_is_partial,

                        null_count,
                        blank_count,
                        populated_count,

                        completeness_percentage,
                        approximate_distinct_count,

                        minimum_text_length,
                        maximum_text_length
                    )

                    SELECT
                        @ProfileRunId,
                        @ObjectRegistryId,
                        @ObjectName,
                        @SourceObjectText,

                        column_id,
                        column_name,
                        sql_data_type,

                        @ApproximateTotalRows,
                        COUNT_BIG(*),

                        CONVERT
                        (
                            BIT,
                            CASE
                                WHEN @ApproximateTotalRows > COUNT_BIG(*)
                                THEN 1
                                ELSE 0
                            END
                        ),

                        SUM
                        (
                            CONVERT
                            (
                                BIGINT,
                                is_null
                            )
                        ),

                        SUM
                        (
                            CASE
                                WHEN is_null = 0
                                 AND trimmed_value IS NULL
                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),

                        SUM
                        (
                            CASE
                                WHEN trimmed_value IS NOT NULL
                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),

                        CONVERT
                        (
                            DECIMAL(12,4),

                            100.0
                            * SUM
                              (
                                  CASE
                                      WHEN trimmed_value IS NOT NULL
                                      THEN CONVERT(BIGINT, 1)
                                      ELSE CONVERT(BIGINT, 0)
                                  END
                              )
                            / NULLIF
                              (
                                  COUNT_BIG(*),
                                  0
                              )
                        ),

                        APPROX_COUNT_DISTINCT
                        (
                            trimmed_value
                        ),

                        MIN
                        (
                            CASE
                                WHEN trimmed_value IS NOT NULL
                                THEN CONVERT
                                     (
                                         INT,
                                         DATALENGTH
                                         (
                                             trimmed_value
                                         ) / 2
                                     )
                            END
                        ),

                        MAX
                        (
                            CASE
                                WHEN trimmed_value IS NOT NULL
                                THEN CONVERT
                                     (
                                         INT,
                                         DATALENGTH
                                         (
                                             trimmed_value
                                         ) / 2
                                     )
                            END
                        )

                    FROM long_values

                    GROUP BY
                        column_id,
                        column_name,
                        sql_data_type

                    OPTION (MAXDOP 1);
                ';

                EXEC sys.sp_executesql
                    @SQL,

                    N'
                        @ProfileRunId UNIQUEIDENTIFIER,
                        @ObjectRegistryId INT,
                        @ObjectName SYSNAME,
                        @SourceObjectText NVARCHAR(600),
                        @ApproximateTotalRows BIGINT,
                        @SampleRows INT
                    ',

                    @ProfileRunId =
                        @ProfileRunId,

                    @ObjectRegistryId =
                        @ObjectRegistryId,

                    @ObjectName =
                        @ObjectName,

                    @SourceObjectText =
                        @SourceObjectText,

                    @ApproximateTotalRows =
                        @ApproximateTotalRows,

                    @SampleRows =
                        @SampleRowsPerObject;

                RAISERROR
                (
                    'Profiled %s: batch %d of %d.',
                    0,
                    1,
                    @ObjectName,
                    @BatchNumber,
                    @MaximumBatch
                ) WITH NOWAIT;

                SET @BatchNumber += 1;
            END;

            FETCH NEXT FROM object_cursor
            INTO
                @ObjectRegistryId,
                @ObjectName,
                @SourceSchema,
                @SourceTable;
        END;

        CLOSE object_cursor;
        DEALLOCATE object_cursor;

        UPDATE dq.profile_run
        SET
            completed_at = SYSDATETIME(),
            run_status = 'Succeeded'
        WHERE profile_run_id = @ProfileRunId;

    END TRY
    BEGIN CATCH

        IF CURSOR_STATUS('local', 'column_cursor') >= 0
            CLOSE column_cursor;

        IF CURSOR_STATUS('local', 'column_cursor') > -3
            DEALLOCATE column_cursor;

        IF CURSOR_STATUS('local', 'object_cursor') >= 0
            CLOSE object_cursor;

        IF CURSOR_STATUS('local', 'object_cursor') > -3
            DEALLOCATE object_cursor;

        UPDATE dq.profile_run
        SET
            completed_at = SYSDATETIME(),
            run_status = 'Failed',
            error_message = ERROR_MESSAGE()
        WHERE profile_run_id = @ProfileRunId;

        THROW;
    END CATCH;

    /* Run summary */

    SELECT
        @ProfileRunId AS profile_run_id,

        COUNT(DISTINCT object_registry_id)
            AS objects_profiled,

        COUNT(*) AS fields_profiled,

        SUM
        (
            CASE
                WHEN populated_count = 0
                THEN 1
                ELSE 0
            END
        ) AS completely_empty_fields,

        SUM
        (
            CASE
                WHEN completeness_percentage < 50
                 AND populated_count > 0
                THEN 1
                ELSE 0
            END
        ) AS low_completeness_fields

    FROM dq.field_profile
    WHERE profile_run_id = @ProfileRunId;

    /* Most important profile findings */

    SELECT
        object_name,
        column_name,
        sql_data_type,

        approximate_total_rows,
        sampled_rows,
        sample_is_partial,

        null_count,
        blank_count,
        populated_count,
        completeness_percentage,

        approximate_distinct_count,
        minimum_text_length,
        maximum_text_length,

        CASE
            WHEN populated_count = 0
                THEN N'EMPTY'

            WHEN completeness_percentage < 25
                THEN N'VERY_LOW_COMPLETENESS'

            WHEN completeness_percentage < 50
                THEN N'LOW_COMPLETENESS'

            WHEN completeness_percentage < 90
                THEN N'REVIEW_COMPLETENESS'

            WHEN approximate_distinct_count = 1
                THEN N'CONSTANT_VALUE'

            ELSE N'PROFILED'
        END AS profile_flag

    FROM dq.field_profile

    WHERE profile_run_id = @ProfileRunId

    ORDER BY
        CASE
            WHEN populated_count = 0 THEN 1
            WHEN completeness_percentage < 25 THEN 2
            WHEN completeness_percentage < 50 THEN 3
            WHEN completeness_percentage < 90 THEN 4
            WHEN approximate_distinct_count = 1 THEN 5
            ELSE 6
        END,
        object_name,
        completeness_percentage,
        column_name;
END;
GO
