/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [ctl].[refresh_latest_views]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF SCHEMA_ID(N'staging') IS NULL
    BEGIN
        EXEC(N'CREATE SCHEMA staging AUTHORIZATION dbo;');
    END;

    DECLARE
        @SourceSchema SYSNAME,
        @SourceTable SYSNAME,
        @StagingSchema SYSNAME,
        @LatestViewName SYSNAME,
        @IdColumn SYSNAME,
        @WatermarkColumn SYSNAME,
        @DeletedFlagColumn SYSNAME,
        @EtlRunColumn SYSNAME,

        @QualifiedSource NVARCHAR(600),
        @QualifiedView NVARCHAR(600),

        @ColumnList NVARCHAR(MAX),
        @OrderExpression NVARCHAR(MAX),
        @DeletedExpression NVARCHAR(MAX),
        @SQL NVARCHAR(MAX);

    DECLARE object_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        source_schema,
        source_table,
        staging_schema,
        latest_view_name,
        id_column,
        watermark_column,
        deleted_flag_column,
        etl_run_column
    FROM ctl.object_registry
    WHERE is_active = 1
      AND id_column IS NOT NULL
      AND latest_view_name IS NOT NULL
    ORDER BY source_table;

    OPEN object_cursor;

    FETCH NEXT FROM object_cursor
    INTO
        @SourceSchema,
        @SourceTable,
        @StagingSchema,
        @LatestViewName,
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

        SET @QualifiedView =
            QUOTENAME(@StagingSchema)
            + N'.'
            + QUOTENAME(@LatestViewName);

        /* Build complete source-column list dynamically */

        SELECT
            @ColumnList =
                STRING_AGG
                (
                    CONVERT
                    (
                        NVARCHAR(MAX),
                        QUOTENAME(c.name)
                    ),
                    N','
                )
                WITHIN GROUP
                (
                    ORDER BY c.column_id
                )
        FROM sys.columns AS c
        WHERE c.object_id =
              OBJECT_ID
              (
                  @SourceSchema
                  + N'.'
                  + @SourceTable
              );

        /* Build latest-row ordering dynamically */

        SET @OrderExpression = N'';

        IF @WatermarkColumn IS NOT NULL
        BEGIN
            SET @OrderExpression =
                N'COALESCE
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
                ) DESC';
        END;

        IF @EtlRunColumn IS NOT NULL
        BEGIN
            SET @OrderExpression =
                @OrderExpression
                + CASE
                    WHEN @OrderExpression = N''
                        THEN N''
                    ELSE N','
                  END
                + N'TRY_CONVERT
                   (
                       BIGINT,
                       '
                       + QUOTENAME(@EtlRunColumn)
                       + N'
                   ) DESC';
        END;

        IF @OrderExpression = N''
        BEGIN
            SET @OrderExpression =
                N'CONVERT
                  (
                      NVARCHAR(4000),
                      '
                      + QUOTENAME(@IdColumn)
                      + N'
                  ) DESC';
        END;

        /* Remove a record only when its latest version is deleted */

        SET @DeletedExpression = N'';

        IF @DeletedFlagColumn IS NOT NULL
        BEGIN
            SET @DeletedExpression =
                N'
                AND COALESCE
                (
                    LOWER
                    (
                        LTRIM
                        (
                            RTRIM
                            (
                                CONVERT
                                (
                                    NVARCHAR(20),
                                    '
                                    + QUOTENAME(@DeletedFlagColumn)
                                    + N'
                                )
                            )
                        )
                    ),
                    N''false''
                ) NOT IN
                (
                    N''true'',
                    N''1'',
                    N''yes'',
                    N''y''
                )';
        END;

        SET @SQL = N'
CREATE OR ALTER VIEW '
            + @QualifiedView
            + N'
AS

WITH ranked_source AS
(
    SELECT
        '
        + @ColumnList
        + N',

        ROW_NUMBER() OVER
        (
            PARTITION BY
                CONVERT
                (
                    VARCHAR(18),
                    '
                    + QUOTENAME(@IdColumn)
                    + N'
                )

            ORDER BY
                '
                + @OrderExpression
                + N'
        ) AS _latest_row_number

    FROM '
    + @QualifiedSource
    + N'

    WHERE '
    + QUOTENAME(@IdColumn)
    + N' IS NOT NULL
)

SELECT
    '
    + @ColumnList
    + N'

FROM ranked_source

WHERE _latest_row_number = 1'
    + @DeletedExpression
    + N';
';

        EXEC sys.sp_executesql @SQL;

        RAISERROR
        (
            'Created or updated %s.',
            0,
            1,
            @QualifiedView
        ) WITH NOWAIT;

        FETCH NEXT FROM object_cursor
        INTO
            @SourceSchema,
            @SourceTable,
            @StagingSchema,
            @LatestViewName,
            @IdColumn,
            @WatermarkColumn,
            @DeletedFlagColumn,
            @EtlRunColumn;
    END;

    CLOSE object_cursor;
    DEALLOCATE object_cursor;

    SELECT
        registry.source_table,
        registry.latest_view_name,
        CASE
            WHEN views.object_id IS NOT NULL
                THEN N'Created'
            ELSE N'Missing'
        END AS view_status
    FROM ctl.object_registry AS registry

    LEFT JOIN sys.views AS views
        ON views.name = registry.latest_view_name
       AND SCHEMA_NAME(views.schema_id) =
           registry.staging_schema

    WHERE registry.is_active = 1
    ORDER BY registry.source_table;
END;
GO
