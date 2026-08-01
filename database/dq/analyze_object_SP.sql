/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dq].[analyze_object]
(
    @SchemaName SYSNAME,
    @ObjectName SYSNAME
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE
        @ObjectId INT,
        @QualifiedObject NVARCHAR(600),
        @ObjectType NVARCHAR(100),
        @TotalRows BIGINT = 0,
        @SQL NVARCHAR(MAX),
        @BatchNumber INT = 1,
        @MaximumBatch INT,
        @ColumnsPerBatch INT = 60,
        @ErrorMessage NVARCHAR(2048);

    /* Validate parameters */

    IF NULLIF(LTRIM(RTRIM(@SchemaName)), N'') IS NULL
    BEGIN
        THROW 50001, 'Schema name is required.', 1;
    END;

    IF NULLIF(LTRIM(RTRIM(@ObjectName)), N'') IS NULL
    BEGIN
        THROW 50002, 'Object name is required.', 1;
    END;

    SET @QualifiedObject =
        QUOTENAME(@SchemaName)
        + N'.'
        + QUOTENAME(@ObjectName);

    SET @ObjectId =
        OBJECT_ID(@SchemaName + N'.' + @ObjectName);

    IF @ObjectId IS NULL
    BEGIN
        SET @ErrorMessage =
            N'Object does not exist: ' + @QualifiedObject;

        THROW 50003, @ErrorMessage, 1;
    END;

    SELECT
        @ObjectType = type_desc
    FROM sys.objects
    WHERE object_id = @ObjectId
      AND type IN ('U', 'V');

    IF @ObjectType IS NULL
    BEGIN
        THROW 50004, 'Object must be a table or view.', 1;
    END;

    /* Store columns that can be analyzed */

    CREATE TABLE #Columns
    (
        batch_number INT NOT NULL,
        column_id INT NOT NULL,
        column_name SYSNAME NOT NULL,
        sql_data_type SYSNAME NOT NULL,
        inferred_type NVARCHAR(100) NOT NULL
    );

    INSERT INTO #Columns
    (
        batch_number,
        column_id,
        column_name,
        sql_data_type,
        inferred_type
    )
    SELECT
        (
            (
                ROW_NUMBER() OVER
                (
                    ORDER BY c.column_id
                ) - 1
            ) / @ColumnsPerBatch
        ) + 1 AS batch_number,

        c.column_id,
        c.name AS column_name,
        t.name AS sql_data_type,

        CASE
            WHEN c.name = N'Id'
              OR RIGHT(c.name, 2) = N'Id'
              OR c.name LIKE N'%_Id'
                THEN N'Salesforce ID'

            WHEN t.name IN
            (
                N'bigint',
                N'int',
                N'smallint',
                N'tinyint',
                N'decimal',
                N'numeric',
                N'money',
                N'smallmoney',
                N'float',
                N'real'
            )
                THEN N'Numeric'

            WHEN t.name IN
            (
                N'date',
                N'datetime',
                N'datetime2',
                N'smalldatetime',
                N'datetimeoffset',
                N'time'
            )
                THEN N'Date/time'

            WHEN t.name = N'bit'
                THEN N'Boolean'

            WHEN c.name LIKE N'%Date%'
              OR c.name LIKE N'%Time%'
              OR c.name LIKE N'%Stamp%'
              OR c.name LIKE N'%Created%'
              OR c.name LIKE N'%Modified%'
                THEN N'Date/time candidate'

            WHEN c.name LIKE N'%Amount%'
              OR c.name LIKE N'%Total%'
              OR c.name LIKE N'%Price%'
              OR c.name LIKE N'%Balance%'
              OR c.name LIKE N'%Quantity%'
              OR c.name LIKE N'%Percent%'
              OR c.name LIKE N'%Rate%'
              OR c.name LIKE N'%Number%'
              OR c.name LIKE N'%Count%'
                THEN N'Numeric candidate'

            WHEN c.name LIKE N'Is%'
              OR c.name LIKE N'%Flag%'
              OR c.name LIKE N'%Active%'
              OR c.name LIKE N'%Deleted%'
              OR c.name LIKE N'%Enabled%'
                THEN N'Boolean candidate'

            ELSE N'Text / categorical'
        END AS inferred_type

    FROM sys.columns AS c

    INNER JOIN sys.types AS t
        ON t.user_type_id = c.user_type_id

    WHERE c.object_id = @ObjectId

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
    FROM #Columns;

    IF @MaximumBatch IS NULL
    BEGIN
        THROW 50005, 'No supported columns were found.', 1;
    END;

    /* Final column profile results */

    CREATE TABLE #Profile
    (
        column_id INT NOT NULL,
        column_name SYSNAME NOT NULL,
        sql_data_type SYSNAME NOT NULL,
        inferred_type NVARCHAR(100) NOT NULL,

        total_rows BIGINT NOT NULL,

        null_count BIGINT NOT NULL,
        blank_count BIGINT NOT NULL,
        populated_count BIGINT NOT NULL,

        completeness_percentage DECIMAL(12,4) NULL,

        minimum_text_length INT NULL,
        maximum_text_length INT NULL,

        valid_type_count BIGINT NULL,
        invalid_type_count BIGINT NULL,

        zero_count BIGINT NULL,
        negative_count BIGINT NULL,

        minimum_value NVARCHAR(200) NULL,
        maximum_value NVARCHAR(200) NULL
    );

    /* Process columns in batches */

    WHILE @BatchNumber <= @MaximumBatch
    BEGIN
        DECLARE
            @AggregateColumns NVARCHAR(MAX) = N'',
            @InsertRows NVARCHAR(MAX) = N'',
            @Separator NVARCHAR(10) = N'',

            @ColumnId INT,
            @ColumnName SYSNAME,
            @DataType SYSNAME,
            @InferredType NVARCHAR(100),

            @QuotedColumn NVARCHAR(300),
            @ColumnSuffix NVARCHAR(20),

            @TextExpression NVARCHAR(MAX),
            @NumericExpression NVARCHAR(MAX),
            @DateExpression NVARCHAR(MAX),

            @ValidExpression NVARCHAR(MAX),
            @ZeroExpression NVARCHAR(MAX),
            @NegativeExpression NVARCHAR(MAX),
            @MinimumExpression NVARCHAR(MAX),
            @MaximumExpression NVARCHAR(MAX);

        DECLARE column_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            column_id,
            column_name,
            sql_data_type,
            inferred_type
        FROM #Columns
        WHERE batch_number = @BatchNumber
        ORDER BY column_id;

        OPEN column_cursor;

        FETCH NEXT FROM column_cursor
        INTO
            @ColumnId,
            @ColumnName,
            @DataType,
            @InferredType;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @QuotedColumn =
                QUOTENAME(@ColumnName);

            SET @ColumnSuffix =
                CONVERT(NVARCHAR(20), @ColumnId);

            /* Standard trimmed text representation */

            SET @TextExpression = N'
                NULLIF
                (
                    LTRIM
                    (
                        RTRIM
                        (
                            TRY_CONVERT
                            (
                                NVARCHAR(4000),
                                ' + @QuotedColumn + N'
                            )
                        )
                    ),
                    N''''
                )';

            SET @NumericExpression = N'
                TRY_CONVERT
                (
                    FLOAT,
                    ' + @TextExpression + N'
                )';

            SET @DateExpression = N'
                COALESCE
                (
                    TRY_CONVERT
                    (
                        DATETIME2(7),
                        ' + @TextExpression + N',
                        127
                    ),
                    TRY_CONVERT
                    (
                        DATETIME2(7),
                        ' + @TextExpression + N',
                        126
                    ),
                    TRY_CONVERT
                    (
                        DATETIME2(7),
                        ' + @TextExpression + N'
                    )
                )';

            /* Default validation for text fields */

            SET @ValidExpression = N'
                ISNULL
                (
                    SUM
                    (
                        CASE
                            WHEN ' + @TextExpression + N' IS NOT NULL
                            THEN CONVERT(BIGINT, 1)
                            ELSE CONVERT(BIGINT, 0)
                        END
                    ),
                    0
                )';

            SET @ZeroExpression =
                N'CAST(NULL AS BIGINT)';

            SET @NegativeExpression =
                N'CAST(NULL AS BIGINT)';

            SET @MinimumExpression =
                N'CAST(NULL AS NVARCHAR(200))';

            SET @MaximumExpression =
                N'CAST(NULL AS NVARCHAR(200))';

            /* Salesforce ID validation */

            IF @InferredType = N'Salesforce ID'
            BEGIN
                SET @ValidExpression = N'
                    ISNULL
                    (
                        SUM
                        (
                            CASE
                                WHEN ' + @TextExpression + N' IS NOT NULL

                                 AND LEN
                                     (
                                         ' + @TextExpression + N'
                                     ) IN (15, 18)

                                 AND ' + @TextExpression + N'
                                     NOT LIKE N''%[^0-9A-Za-z]%''

                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),
                        0
                    )';
            END;

            /* Boolean validation */

            IF @InferredType IN
            (
                N'Boolean',
                N'Boolean candidate'
            )
            BEGIN
                SET @ValidExpression = N'
                    ISNULL
                    (
                        SUM
                        (
                            CASE
                                WHEN LOWER
                                (
                                    ' + @TextExpression + N'
                                ) IN
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

            /* Date validation */

            IF @InferredType IN
            (
                N'Date/time',
                N'Date/time candidate'
            )
            BEGIN
                SET @ValidExpression = N'
                    ISNULL
                    (
                        SUM
                        (
                            CASE
                                WHEN ' + @TextExpression + N' IS NOT NULL
                                 AND ' + @DateExpression + N' IS NOT NULL
                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),
                        0
                    )';

                SET @MinimumExpression = N'
                    CONVERT
                    (
                        NVARCHAR(200),
                        MIN
                        (
                            ' + @DateExpression + N'
                        ),
                        126
                    )';

                SET @MaximumExpression = N'
                    CONVERT
                    (
                        NVARCHAR(200),
                        MAX
                        (
                            ' + @DateExpression + N'
                        ),
                        126
                    )';
            END;

            /* Numeric validation */

            IF @InferredType IN
            (
                N'Numeric',
                N'Numeric candidate'
            )
            BEGIN
                SET @ValidExpression = N'
                    ISNULL
                    (
                        SUM
                        (
                            CASE
                                WHEN ' + @TextExpression + N' IS NOT NULL
                                 AND ' + @NumericExpression + N' IS NOT NULL
                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),
                        0
                    )';

                SET @ZeroExpression = N'
                    ISNULL
                    (
                        SUM
                        (
                            CASE
                                WHEN ' + @NumericExpression + N' = 0
                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),
                        0
                    )';

                SET @NegativeExpression = N'
                    ISNULL
                    (
                        SUM
                        (
                            CASE
                                WHEN ' + @NumericExpression + N' < 0
                                THEN CONVERT(BIGINT, 1)
                                ELSE CONVERT(BIGINT, 0)
                            END
                        ),
                        0
                    )';

                SET @MinimumExpression = N'
                    CONVERT
                    (
                        NVARCHAR(200),
                        MIN
                        (
                            ' + @NumericExpression + N'
                        )
                    )';

                SET @MaximumExpression = N'
                    CONVERT
                    (
                        NVARCHAR(200),
                        MAX
                        (
                            ' + @NumericExpression + N'
                        )
                    )';
            END;

            /* Aggregate expressions for current column */

            SET @AggregateColumns =
                @AggregateColumns
                + @Separator
                + N'
                ISNULL
                (
                    SUM
                    (
                        CASE
                            WHEN ' + @QuotedColumn + N' IS NULL
                            THEN CONVERT(BIGINT, 1)
                            ELSE CONVERT(BIGINT, 0)
                        END
                    ),
                    0
                ) AS ' + QUOTENAME(N'null_' + @ColumnSuffix) + N',

                ISNULL
                (
                    SUM
                    (
                        CASE
                            WHEN ' + @QuotedColumn + N' IS NOT NULL
                             AND ' + @TextExpression + N' IS NULL
                            THEN CONVERT(BIGINT, 1)
                            ELSE CONVERT(BIGINT, 0)
                        END
                    ),
                    0
                ) AS ' + QUOTENAME(N'blank_' + @ColumnSuffix) + N',

                ISNULL
                (
                    SUM
                    (
                        CASE
                            WHEN ' + @TextExpression + N' IS NOT NULL
                            THEN CONVERT(BIGINT, 1)
                            ELSE CONVERT(BIGINT, 0)
                        END
                    ),
                    0
                ) AS ' + QUOTENAME(N'populated_' + @ColumnSuffix) + N',

                MIN
                (
                    CASE
                        WHEN ' + @TextExpression + N' IS NOT NULL
                        THEN CONVERT
                        (
                            INT,
                            DATALENGTH
                            (
                                ' + @TextExpression + N'
                            ) / 2
                        )
                    END
                ) AS ' + QUOTENAME(N'minlength_' + @ColumnSuffix) + N',

                MAX
                (
                    CASE
                        WHEN ' + @TextExpression + N' IS NOT NULL
                        THEN CONVERT
                        (
                            INT,
                            DATALENGTH
                            (
                                ' + @TextExpression + N'
                            ) / 2
                        )
                    END
                ) AS ' + QUOTENAME(N'maxlength_' + @ColumnSuffix) + N',

                ' + @ValidExpression
                    + N' AS '
                    + QUOTENAME(N'valid_' + @ColumnSuffix) + N',

                ' + @ZeroExpression
                    + N' AS '
                    + QUOTENAME(N'zero_' + @ColumnSuffix) + N',

                ' + @NegativeExpression
                    + N' AS '
                    + QUOTENAME(N'negative_' + @ColumnSuffix) + N',

                ' + @MinimumExpression
                    + N' AS '
                    + QUOTENAME(N'minimum_' + @ColumnSuffix) + N',

                ' + @MaximumExpression
                    + N' AS '
                    + QUOTENAME(N'maximum_' + @ColumnSuffix);

            /* Convert the one aggregate row into profile rows */

            SET @InsertRows =
                @InsertRows
                + CASE
                    WHEN @InsertRows = N''
                        THEN N''
                    ELSE N'
                    UNION ALL
                    '
                  END
                + N'
                SELECT
                    ' + CONVERT(NVARCHAR(20), @ColumnId) + N'
                        AS column_id,

                    N''' + REPLACE(@ColumnName, N'''', N'''''') + N'''
                        AS column_name,

                    N''' + REPLACE(@DataType, N'''', N'''''') + N'''
                        AS sql_data_type,

                    N''' + REPLACE(@InferredType, N'''', N'''''') + N'''
                        AS inferred_type,

                    aggregate_values.total_rows,

                    aggregate_values.'
                    + QUOTENAME(N'null_' + @ColumnSuffix)
                    + N' AS null_count,

                    aggregate_values.'
                    + QUOTENAME(N'blank_' + @ColumnSuffix)
                    + N' AS blank_count,

                    aggregate_values.'
                    + QUOTENAME(N'populated_' + @ColumnSuffix)
                    + N' AS populated_count,

                    CONVERT
                    (
                        DECIMAL(12,4),
                        100.0
                        * aggregate_values.'
                        + QUOTENAME(N'populated_' + @ColumnSuffix)
                        + N'
                        / NULLIF
                          (
                              aggregate_values.total_rows,
                              0
                          )
                    ) AS completeness_percentage,

                    aggregate_values.'
                    + QUOTENAME(N'minlength_' + @ColumnSuffix)
                    + N' AS minimum_text_length,

                    aggregate_values.'
                    + QUOTENAME(N'maxlength_' + @ColumnSuffix)
                    + N' AS maximum_text_length,

                    aggregate_values.'
                    + QUOTENAME(N'valid_' + @ColumnSuffix)
                    + N' AS valid_type_count,

                    aggregate_values.'
                    + QUOTENAME(N'populated_' + @ColumnSuffix)
                    + N'
                    - aggregate_values.'
                    + QUOTENAME(N'valid_' + @ColumnSuffix)
                    + N' AS invalid_type_count,

                    aggregate_values.'
                    + QUOTENAME(N'zero_' + @ColumnSuffix)
                    + N' AS zero_count,

                    aggregate_values.'
                    + QUOTENAME(N'negative_' + @ColumnSuffix)
                    + N' AS negative_count,

                    aggregate_values.'
                    + QUOTENAME(N'minimum_' + @ColumnSuffix)
                    + N' AS minimum_value,

                    aggregate_values.'
                    + QUOTENAME(N'maximum_' + @ColumnSuffix)
                    + N' AS maximum_value

                FROM #BatchAggregate AS aggregate_values';

            SET @Separator = N',';

            FETCH NEXT FROM column_cursor
            INTO
                @ColumnId,
                @ColumnName,
                @DataType,
                @InferredType;
        END;

        CLOSE column_cursor;
        DEALLOCATE column_cursor;

        /* Execute one full-table scan for this group of columns */

        SET @SQL = N'
            SET ANSI_WARNINGS OFF;

            SELECT
                COUNT_BIG(*) AS total_rows,
                ' + @AggregateColumns + N'
            INTO #BatchAggregate
            FROM ' + @QualifiedObject + N'
            OPTION
            (
                MAXDOP 1
            );

            INSERT INTO #Profile
            (
                column_id,
                column_name,
                sql_data_type,
                inferred_type,
                total_rows,
                null_count,
                blank_count,
                populated_count,
                completeness_percentage,
                minimum_text_length,
                maximum_text_length,
                valid_type_count,
                invalid_type_count,
                zero_count,
                negative_count,
                minimum_value,
                maximum_value
            )
            ' + @InsertRows + N';

            SELECT
                @RowsOutput = total_rows
            FROM #BatchAggregate;

            DROP TABLE #BatchAggregate;

            SET ANSI_WARNINGS ON;
        ';

        EXEC sys.sp_executesql
            @SQL,
            N'@RowsOutput BIGINT OUTPUT',
            @RowsOutput = @TotalRows OUTPUT;

        RAISERROR
        (
            'Completed analysis batch %d of %d.',
            0,
            1,
            @BatchNumber,
            @MaximumBatch
        ) WITH NOWAIT;

        SET @BatchNumber += 1;
    END;

    /* Result set 1: object summary */

    SELECT
        @SchemaName AS schema_name,
        @ObjectName AS object_name,
        @ObjectType AS object_type,
        @TotalRows AS total_rows_analyzed,
        COUNT_BIG(*) AS analyzed_columns,
        @MaximumBatch AS full_table_scans,
        SYSDATETIME() AS analyzed_at
    FROM #Profile;

    /* Result set 2: data-quality findings */

    SELECT
        CASE
            WHEN invalid_type_count > 0
                THEN N'High'

            WHEN completeness_percentage < 50
                THEN N'High'

            WHEN completeness_percentage < 90
                THEN N'Medium'

            WHEN ISNULL(negative_count, 0) > 0
                THEN N'Review'

            ELSE N'Information'
        END AS severity,

        column_name,
        sql_data_type,
        inferred_type,

        completeness_percentage,
        null_count,
        blank_count,
        populated_count,

        valid_type_count,
        invalid_type_count,

        zero_count,
        negative_count,

        minimum_value,
        maximum_value,

        CASE
            WHEN invalid_type_count > 0
                THEN N'Values do not match the inferred data type'

            WHEN completeness_percentage < 50
                THEN N'Field has very low completeness'

            WHEN completeness_percentage < 90
                THEN N'Field completeness requires review'

            WHEN ISNULL(negative_count, 0) > 0
                THEN N'Negative numeric values require review'

            ELSE N'No automatic issue detected'
        END AS finding

    FROM #Profile

    WHERE invalid_type_count > 0
       OR completeness_percentage < 90
       OR ISNULL(negative_count, 0) > 0

    ORDER BY
        CASE
            WHEN invalid_type_count > 0 THEN 1
            WHEN completeness_percentage < 50 THEN 2
            WHEN completeness_percentage < 90 THEN 3
            ELSE 4
        END,
        column_name;

    /* Result set 3: complete profile */

    SELECT
        column_id,
        column_name,
        sql_data_type,
        inferred_type,

        total_rows,

        null_count,
        blank_count,
        populated_count,
        completeness_percentage,

        minimum_text_length,
        maximum_text_length,

        valid_type_count,
        invalid_type_count,

        zero_count,
        negative_count,

        minimum_value,
        maximum_value

    FROM #Profile
    ORDER BY column_id;
END;
GO
