/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [ctl].[validate_pipeline_metadata]
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH registered_objects AS
    (
        SELECT
            r.object_registry_id,
            r.source_schema,
            r.source_table,
            r.object_name,
            r.id_column,
            r.watermark_column,
            r.deleted_flag_column,
            r.etl_run_column,
            r.staging_schema,
            r.latest_view_name,
            r.is_active,

            OBJECT_ID
            (
                r.source_schema + N'.' + r.source_table,
                N'U'
            ) AS source_object_id,

            OBJECT_ID
            (
                r.staging_schema + N'.' + r.latest_view_name,
                N'V'
            ) AS view_object_id

        FROM ctl.object_registry AS r
        WHERE r.is_active = 1
    ),

    object_statistics AS
    (
        SELECT
            registered.object_registry_id,
            registered.source_schema,
            registered.source_table,
            registered.object_name,
            registered.id_column,
            registered.watermark_column,
            registered.deleted_flag_column,
            registered.etl_run_column,
            registered.staging_schema,
            registered.latest_view_name,
            registered.source_object_id,
            registered.view_object_id,

            ISNULL
            (
                (
                    SELECT SUM
                    (
                        CONVERT
                        (
                            BIGINT,
                            partitions.row_count
                        )
                    )
                    FROM sys.dm_db_partition_stats AS partitions
                    WHERE partitions.object_id =
                          registered.source_object_id
                      AND partitions.index_id IN (0, 1)
                ),
                0
            ) AS approximate_raw_rows,

            (
                SELECT COUNT_BIG(*)
                FROM sys.columns AS columns_raw
                WHERE columns_raw.object_id =
                      registered.source_object_id
            ) AS raw_column_count,

            (
                SELECT COUNT_BIG(*)
                FROM sys.columns AS columns_view
                WHERE columns_view.object_id =
                      registered.view_object_id
            ) AS view_column_count

        FROM registered_objects AS registered
    )

    SELECT
        object_registry_id,
        object_name,

        source_schema + N'.' + source_table
            AS raw_object,

        staging_schema + N'.' + latest_view_name
            AS latest_view,

        approximate_raw_rows,
        raw_column_count,
        view_column_count,

        id_column,
        watermark_column,
        deleted_flag_column,
        etl_run_column,

        CASE
            WHEN source_object_id IS NULL
                THEN N'ERROR'

            WHEN view_object_id IS NULL
                THEN N'ERROR'

            WHEN id_column IS NULL
                THEN N'ERROR'

            WHEN watermark_column IS NULL
                THEN N'WARNING'

            WHEN etl_run_column IS NULL
                THEN N'WARNING'

            WHEN raw_column_count <> view_column_count
                THEN N'WARNING'

            ELSE N'PASS'
        END AS validation_status,

        CONCAT
        (
            CASE
                WHEN source_object_id IS NULL
                    THEN N'Raw table is missing. '
                ELSE N''
            END,

            CASE
                WHEN view_object_id IS NULL
                    THEN N'Latest view is missing. '
                ELSE N''
            END,

            CASE
                WHEN id_column IS NULL
                    THEN N'Id column was not detected. '
                ELSE N''
            END,

            CASE
                WHEN watermark_column IS NULL
                    THEN N'Watermark column was not detected. '
                ELSE N''
            END,

            CASE
                WHEN etl_run_column IS NULL
                    THEN N'ETL run column was not detected. '
                ELSE N''
            END,

            CASE
                WHEN source_object_id IS NOT NULL
                 AND view_object_id IS NOT NULL
                 AND raw_column_count <> view_column_count
                    THEN N'Raw and latest-view column counts differ. '
                ELSE N''
            END,

            CASE
                WHEN source_object_id IS NOT NULL
                 AND view_object_id IS NOT NULL
                 AND id_column IS NOT NULL
                 AND watermark_column IS NOT NULL
                 AND etl_run_column IS NOT NULL
                 AND raw_column_count = view_column_count
                    THEN N'Metadata validation completed successfully.'
                ELSE N''
            END
        ) AS validation_message

    FROM object_statistics
    ORDER BY
        CASE
            WHEN source_object_id IS NULL THEN 1
            WHEN view_object_id IS NULL THEN 2
            WHEN id_column IS NULL THEN 3
            WHEN watermark_column IS NULL THEN 4
            WHEN etl_run_column IS NULL THEN 5
            WHEN raw_column_count <> view_column_count THEN 6
            ELSE 7
        END,
        object_name;
END;
GO
