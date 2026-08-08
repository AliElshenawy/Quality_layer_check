/* ============================================================================
   db_inventory.sql — snapshot of the current SalesforceDW schema (read-only).
   ----------------------------------------------------------------------------
   Use it to see "what is up on SQL" before a migration and to compare two
   environments (local vs Azure). Run it in BOTH, save each output, and diff:
   anything present in one but not the other is a migration item. The repo
   (`database/_deploy.sql`) stays the source of truth — apply missing objects
   from there, and add columns with ALTER (never DROP).

   Run (pipe-separated, easy to diff):
     sqlcmd -S localhost -d SalesforceDW -E -C -N -W -s"|" -i scripts/db_inventory.sql > inventory_local.txt
     sqlcmd -S quality-check-poc-sql.database.windows.net -d SalesforceDW -G -C -N -W -s"|" -i scripts/db_inventory.sql > inventory_azure.txt
     diff inventory_local.txt inventory_azure.txt
   ============================================================================ */
SET NOCOUNT ON;

PRINT '== 1) TABLES + ROW COUNTS ==';
SELECT s.name AS [schema], t.name AS [table], SUM(p.rows) AS [rows]
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY s.name, t.name
ORDER BY s.name, t.name;

PRINT '== 2) COLUMNS (shape of every table) ==';
SELECT s.name AS [schema], t.name AS [table], c.column_id AS ord, c.name AS [column],
       ty.name AS [type], c.max_length, c.is_nullable, c.is_computed
FROM sys.columns c
JOIN sys.tables t   ON t.object_id = c.object_id
JOIN sys.schemas s  ON s.schema_id = t.schema_id
JOIN sys.types ty   ON ty.user_type_id = c.user_type_id
ORDER BY s.name, t.name, c.column_id;

PRINT '== 3) VIEWS ==';
SELECT s.name AS [schema], v.name AS [view]
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
ORDER BY s.name, v.name;

PRINT '== 4) PROCEDURES + FUNCTIONS ==';
SELECT s.name AS [schema], o.name AS [routine], o.type_desc
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE o.type IN ('P', 'FN', 'IF', 'TF')
ORDER BY s.name, o.type_desc, o.name;

PRINT '== 5) INDEXES / KEYS ==';
SELECT s.name AS [schema], t.name AS [table], i.name AS [index],
       i.type_desc, i.is_unique, i.is_primary_key
FROM sys.indexes i
JOIN sys.tables t  ON t.object_id = i.object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE i.type > 0
ORDER BY s.name, t.name, i.name;

PRINT '== 6) PIPELINE STATE (where each object is) ==';
SELECT object_name, watermark_column, last_watermark_value, last_success_run_id
FROM ctl.watermark_control ORDER BY object_name;
SELECT object_name, last_staging_watermark, last_run_at FROM ctl.staging_state ORDER BY object_name;
SELECT object_name, last_clean_watermark, last_run_at FROM ctl.clean_state ORDER BY object_name;
SELECT object_name, COUNT(*) AS rules FROM dq.dq_rule_catalog GROUP BY object_name ORDER BY object_name;
GO
