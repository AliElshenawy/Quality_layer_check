/* ============================================================
   Dynamic NULL / Empty Analysis — Stored Procedure
   
   STEP 1 – Create the SP (run once):
       Execute the CREATE PROCEDURE block below.

   STEP 2 – Call it:
       EXEC dbo.usp_null_analysis @schema='raw', @table='salesforce_campaign';

   SP lives at: dbo.usp_null_analysis
   ============================================================ */

IF OBJECT_ID('dbo.usp_null_analysis','P') IS NOT NULL
    DROP PROCEDURE dbo.usp_null_analysis;
GO

CREATE PROCEDURE dbo.usp_null_analysis
    @schema NVARCHAR(128) = N'raw',
    @table  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_WARNINGS OFF;

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

    -- check if Id column exists
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA=@schema AND TABLE_NAME=@table AND COLUMN_NAME='Id')
        SET @has_id_col = 1;

    -- get total rows and distinct Id as scalars
    SET @total_sql = N'SELECT @tr=COUNT(*), @di=COUNT(DISTINCT ' +
        CASE WHEN @has_id_col=1 THEN N'[Id]' ELSE N'1' END +
        N') FROM ' + @full_table;
    EXEC sp_executesql @total_sql,
         N'@tr BIGINT OUTPUT, @di BIGINT OUTPUT',
         @tr=@total_rows OUTPUT, @di=@distinct_id OUTPUT;

    -- build per-column dynamic inserts using scalar values
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

/* ── Quick call examples ─────────────────────────────────────
EXEC dbo.usp_null_analysis @schema='raw', @table='salesforce_campaign';
EXEC dbo.usp_null_analysis @schema='raw', @table='salesforce_contact';
EXEC dbo.usp_null_analysis @schema='staging', @table='campaign_latest';
──────────────────────────────────────────────────────────── */

-- (the original ad-hoc DECLARE block below is superseded by the SP above)

DECLARE @schema      NVARCHAR(128) = N'raw';   -- ← change schema
DECLARE @table       NVARCHAR(128) = N'campaign';  -- ← change table

-- ── internals ────────────────────────────────────────────────
DECLARE @full_table  NVARCHAR(256) = QUOTENAME(@schema) + N'.' + QUOTENAME(@table);
DECLARE @total_sql   NVARCHAR(MAX);
DECLARE @col_sql     NVARCHAR(MAX) = N'';
DECLARE @col_name    NVARCHAR(128);
DECLARE @col_type    NVARCHAR(128);
DECLARE @total_rows  BIGINT;
DECLARE @distinct_id BIGINT;

-- ── 1. total rows + distinct on first PK-like column ─────────
-- We'll compute total_rows and distinct_id inside the dynamic query
-- and store them in a temp table for the final join.

IF OBJECT_ID('tempdb..#null_analysis') IS NOT NULL
    DROP TABLE #null_analysis;

CREATE TABLE #null_analysis (
    col_order        INT,
    column_name      NVARCHAR(128),
    data_type        NVARCHAR(128),
    total_rows       BIGINT,
    null_or_empty    BIGINT,
    null_pct         DECIMAL(7,2),
    distinct_values  BIGINT
);

IF OBJECT_ID('tempdb..#id_stats') IS NOT NULL
    DROP TABLE #id_stats;

CREATE TABLE #id_stats (
    total_rows  BIGINT,
    distinct_id BIGINT
);

-- ── 2. build per-column INSERT statements dynamically ─────────
DECLARE col_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        c.COLUMN_NAME,
        c.DATA_TYPE,
        c.ORDINAL_POSITION
    FROM INFORMATION_SCHEMA.COLUMNS c
    WHERE c.TABLE_SCHEMA = @schema
      AND c.TABLE_NAME   = @table
    ORDER BY c.ORDINAL_POSITION;

OPEN col_cursor;

DECLARE @ordinal INT;

FETCH NEXT FROM col_cursor INTO @col_name, @col_type, @ordinal;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @null_expr NVARCHAR(MAX);

    -- For string-like types also count empty-string as "missing"
    IF @col_type IN ('char','nchar','varchar','nvarchar','text','ntext')
        SET @null_expr = N'SUM(CASE WHEN ' + QUOTENAME(@col_name) + N' IS NULL OR LTRIM(RTRIM(' + QUOTENAME(@col_name) + N')) = '''' THEN 1 ELSE 0 END)';
    ELSE
        SET @null_expr = N'SUM(CASE WHEN ' + QUOTENAME(@col_name) + N' IS NULL THEN 1 ELSE 0 END)';

    SET @col_sql = @col_sql + N'
INSERT INTO #null_analysis (col_order, column_name, data_type, total_rows, null_or_empty, null_pct, distinct_values)
SELECT
    ' + CAST(@ordinal AS NVARCHAR(10)) + N',
    N''' + REPLACE(@col_name, '''', '''''') + N''',
    N''' + @col_type + N''',
    s.total_rows,
    ' + @null_expr + N',
    CAST(ROUND(' + @null_expr + N' * 100.0 / NULLIF(s.total_rows, 0), 2) AS DECIMAL(7,2)),
    COUNT(DISTINCT ' + QUOTENAME(@col_name) + N')
FROM ' + @full_table + N'
CROSS JOIN #id_stats s;
';

    FETCH NEXT FROM col_cursor INTO @col_name, @col_type, @ordinal;
END;

CLOSE col_cursor;
DEALLOCATE col_cursor;

-- ── 3. populate total_rows + distinct on "Id" column (first col) ──
SET @total_sql = N'
INSERT INTO #id_stats (total_rows, distinct_id)
SELECT
    COUNT(*),
    COUNT(DISTINCT ' +
    -- use [Id] if it exists, otherwise COUNT(*) for both
    CASE WHEN EXISTS (
            SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = @table AND COLUMN_NAME = 'Id'
         )
         THEN N'[Id]'
         ELSE N'1'
    END
    + N')
FROM ' + @full_table + N';';

EXEC sp_executesql @total_sql, N'@schema NVARCHAR(128), @table NVARCHAR(128)', @schema, @table;

-- ── 4. run column loop ─────────────────────────────────────────
EXEC sp_executesql @col_sql;

-- ── 5. final result ────────────────────────────────────────────
SELECT
    a.col_order                                        AS [#],
    a.column_name                                      AS [Column],
    a.data_type                                        AS [Type],
    a.total_rows                                       AS [Total Rows],
    i.distinct_id                                      AS [Distinct IDs],
    a.null_or_empty                                    AS [Null / Empty],
    a.null_pct                                         AS [Null %],
    a.distinct_values                                  AS [Distinct Values],
    -- quick traffic-light flag
    CASE
        WHEN a.null_pct = 0    THEN '✅ clean'
        WHEN a.null_pct < 5    THEN '🟡 low'
        WHEN a.null_pct < 30   THEN '🟠 medium'
        ELSE                        '🔴 high'
    END                                                AS [Flag]
FROM #null_analysis  a
CROSS JOIN #id_stats i
ORDER BY a.col_order;

-- cleanup
DROP TABLE #null_analysis;
DROP TABLE #id_stats;
