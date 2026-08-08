/* ============================================================================
   Author: Mohey
   Origin: Scripted from live SalesforceDW (existing proc, added to repo 2026-08-06).
   ----------------------------------------------------------------------------
   dbo.usp_null_analysis — per-column null/blank profiling for any table.
   Used by DQ Frame work/Check_nulls_all.SQL. Returns one row per column with
   total rows, null/empty count, null %, distinct values, and a Flag bucket.

   Usage:  EXEC dbo.usp_null_analysis @schema='raw', @table='salesforce_campaign';
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_null_analysis
    @schema NVARCHAR(128) = N'raw',
    @table  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @full_table  NVARCHAR(256) = QUOTENAME(@schema) + N'.' + QUOTENAME(@table);
    DECLARE @col_sql     NVARCHAR(MAX) = N'';
    DECLARE @total_sql   NVARCHAR(MAX);
    DECLARE @col_name    NVARCHAR(128);
    DECLARE @col_type    NVARCHAR(128);
    DECLARE @ordinal     INT;
    DECLARE @total_rows  BIGINT;
    DECLARE @distinct_id BIGINT;
    DECLARE @has_id_col  BIT = 0;

    IF OBJECT_ID('tempdb..#null_analysis') IS NOT NULL DROP TABLE #null_analysis;
    CREATE TABLE #null_analysis (
        col_order       INT,
        column_name     NVARCHAR(128),
        data_type       NVARCHAR(128),
        total_rows      BIGINT,
        null_or_empty   BIGINT,
        null_pct        DECIMAL(7,2),
        distinct_values BIGINT
    );

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA=@schema AND TABLE_NAME=@table AND COLUMN_NAME='Id')
        SET @has_id_col = 1;

    SET @total_sql = N'SELECT @tr=COUNT(*), @di=COUNT(DISTINCT ' +
        CASE WHEN @has_id_col=1 THEN N'[Id]' ELSE N'1' END +
        N') FROM ' + @full_table;
    EXEC sp_executesql @total_sql,
         N'@tr BIGINT OUTPUT, @di BIGINT OUTPUT',
         @tr=@total_rows OUTPUT, @di=@distinct_id OUTPUT;

    DECLARE col_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA=@schema AND TABLE_NAME=@table
        ORDER BY ORDINAL_POSITION;

    OPEN col_cur;
    FETCH NEXT FROM col_cur INTO @col_name, @col_type, @ordinal;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @null_expr NVARCHAR(MAX);
        IF @col_type IN ('char','nchar','varchar','nvarchar','text','ntext')
            SET @null_expr = N'SUM(CASE WHEN ' + QUOTENAME(@col_name)
                + N' IS NULL OR LTRIM(RTRIM(' + QUOTENAME(@col_name) + N')) = '''' THEN 1 ELSE 0 END)';
        ELSE
            SET @null_expr = N'SUM(CASE WHEN ' + QUOTENAME(@col_name) + N' IS NULL THEN 1 ELSE 0 END)';

        SET @col_sql += N'
INSERT INTO #null_analysis
SELECT '
    + CAST(@ordinal AS NVARCHAR(10))
    + N', N''' + REPLACE(@col_name,'''','''''') + N''''
    + N', N''' + @col_type + N''''
    + N', ' + CAST(@total_rows AS NVARCHAR(20))
    + N', ' + @null_expr
    + N', CAST(ROUND(' + @null_expr + N' * 100.0 / NULLIF(' + CAST(@total_rows AS NVARCHAR(20)) + N',0),2) AS DECIMAL(7,2))'
    + N', COUNT(DISTINCT ' + QUOTENAME(@col_name) + N')'
    + N' FROM ' + @full_table + N';';

        FETCH NEXT FROM col_cur INTO @col_name, @col_type, @ordinal;
    END;

    CLOSE col_cur; DEALLOCATE col_cur;

    EXEC sp_executesql @col_sql;

    SELECT
        a.col_order        AS [#],
        a.column_name      AS [Column],
        a.data_type        AS [Type],
        a.total_rows       AS [TotalRows],
        @distinct_id       AS [DistinctIDs],
        a.null_or_empty    AS [NullEmpty],
        a.null_pct         AS [NullPct],
        a.distinct_values  AS [DistinctValues],
        CASE
            WHEN a.null_pct = 0  THEN 'clean'
            WHEN a.null_pct < 5  THEN 'low'
            WHEN a.null_pct < 30 THEN 'medium'
            ELSE 'high'
        END                AS [Flag]
    FROM #null_analysis a
    ORDER BY a.col_order;
END;
GO
