/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [ctl].[refresh_object_registry]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DROP TABLE IF EXISTS #discovered_objects;

    SELECT
        s.name AS source_schema,
        t.name AS source_table,

        CASE
            WHEN COL_LENGTH
                 (
                     QUOTENAME(s.name) + N'.' + QUOTENAME(t.name),
                     N'Id'
                 ) IS NOT NULL
            THEN N'Id'
        END AS id_column,

        CASE
            WHEN COL_LENGTH
                 (
                     QUOTENAME(s.name) + N'.' + QUOTENAME(t.name),
                     N'SystemModstamp'
                 ) IS NOT NULL
            THEN N'SystemModstamp'

            WHEN COL_LENGTH
                 (
                     QUOTENAME(s.name) + N'.' + QUOTENAME(t.name),
                     N'LastModifiedDate'
                 ) IS NOT NULL
            THEN N'LastModifiedDate'

            WHEN COL_LENGTH
                 (
                     QUOTENAME(s.name) + N'.' + QUOTENAME(t.name),
                     N'CreatedDate'
                 ) IS NOT NULL
            THEN N'CreatedDate'
        END AS watermark_column,

        CASE
            WHEN COL_LENGTH
                 (
                     QUOTENAME(s.name) + N'.' + QUOTENAME(t.name),
                     N'IsDeleted'
                 ) IS NOT NULL
            THEN N'IsDeleted'
        END AS deleted_flag_column,

        CASE
            WHEN COL_LENGTH
                 (
                     QUOTENAME(s.name) + N'.' + QUOTENAME(t.name),
                     N'_etl_run_id'
                 ) IS NOT NULL
            THEN N'_etl_run_id'
        END AS etl_run_column,

        CAST
        (
            N'vw_'
            + REPLACE(t.name, N'salesforce_', N'')
            + N'_latest'
            AS SYSNAME
        ) AS latest_view_name

    INTO #discovered_objects

    FROM sys.tables AS t

    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id

    WHERE s.name = N'raw'
      AND t.name LIKE N'salesforce[_]%';

    /* Update existing objects */

    UPDATE registry
    SET
        registry.id_column = discovered.id_column,
        registry.watermark_column = discovered.watermark_column,
        registry.deleted_flag_column =
            discovered.deleted_flag_column,
        registry.etl_run_column = discovered.etl_run_column,
        registry.latest_view_name = discovered.latest_view_name,
        registry.is_active = 1,
        registry.updated_at = SYSDATETIME()

    FROM ctl.object_registry AS registry

    INNER JOIN #discovered_objects AS discovered
        ON discovered.source_schema =
           registry.source_schema
       AND discovered.source_table =
           registry.source_table;

    /* Insert newly discovered objects */

    INSERT INTO ctl.object_registry
    (
        source_schema,
        source_table,
        id_column,
        watermark_column,
        deleted_flag_column,
        etl_run_column,
        latest_view_name,
        is_active
    )
    SELECT
        discovered.source_schema,
        discovered.source_table,
        discovered.id_column,
        discovered.watermark_column,
        discovered.deleted_flag_column,
        discovered.etl_run_column,
        discovered.latest_view_name,
        1

    FROM #discovered_objects AS discovered

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM ctl.object_registry AS registry
        WHERE registry.source_schema =
              discovered.source_schema
          AND registry.source_table =
              discovered.source_table
    );

    /* Disable raw objects that no longer exist */

    UPDATE registry
    SET
        registry.is_active = 0,
        registry.updated_at = SYSDATETIME()

    FROM ctl.object_registry AS registry

    WHERE registry.source_schema = N'raw'
      AND NOT EXISTS
      (
          SELECT 1
          FROM #discovered_objects AS discovered
          WHERE discovered.source_schema =
                registry.source_schema
            AND discovered.source_table =
                registry.source_table
      );

    SELECT
        object_registry_id,
        source_schema,
        source_table,
        object_name,
        id_column,
        watermark_column,
        deleted_flag_column,
        etl_run_column,
        latest_view_name,
        is_active
    FROM ctl.object_registry
    ORDER BY source_table;
END;
GO
