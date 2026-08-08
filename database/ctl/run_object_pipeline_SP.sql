/* ============================================================================
   Author: Mohey
   Origin: Incremental pipeline orchestrator — one trigger runs the whole chain.
   ----------------------------------------------------------------------------
   ctl.run_object_pipeline runs STAGING -> DQ -> CLEAN for one object or ALL,
   incrementally (each stage is watermark-driven on SystemModstamp), logging a
   row per object to ctl.etl_run_control. ADF (or an operator) calls this after
   ingest; a caught-up object simply does no work.

   It resolves each object's per-object procs BY NAME CONVENTION and SKIPS any
   that don't exist yet, so it works today (Campaign clean, RD staging) and grows
   as more per-object staging/clean procs are added:
       staging.refresh_<object_short>_latest   (incremental staging)
       clean.refresh_<object_short>            (incremental clean; Campaign only so far)
   DQ is the one generic engine (dq.run_incremental_catalog_rules).

   Usage:
     EXEC ctl.run_object_pipeline;                                   -- all objects
     EXEC ctl.run_object_pipeline @object_name = N'Recurring_Donation';
     EXEC ctl.run_object_pipeline @object_name = N'Campaign', @rebuild_staging = 1;
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [ctl].[run_object_pipeline]
    @object_name     NVARCHAR(150) = NULL,   -- NULL = every object below
    @rebuild_staging BIT           = 0,      -- pass-through @FullRebuild to the staging proc
    @MaxRowsPerRule  BIGINT        = 0,      -- 0 = drain all new rows in the DQ runner
    @run_clean       BIT           = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* object_name (catalog form, underscores) -> object_short (proc-name segment) */
    DECLARE @reg TABLE (object_name NVARCHAR(150), object_short SYSNAME);
    INSERT INTO @reg (object_name, object_short) VALUES
        (N'Campaign',            N'campaign'),
        (N'Contact',             N'contact'),
        (N'Item_GAU',            N'item_gau'),
        (N'Recurring_Donation',  N'recurring_donation'),
        (N'Sponsorship',         N'sponsorship'),
        (N'Sponsorship_Unit',    N'sponsorship_unit'),
        (N'Opportunity',         N'opportunity'),
        (N'Payment',             N'payment'),
        (N'Item_Allocation',     N'item_allocation');

    IF @object_name IS NOT NULL
        DELETE FROM @reg WHERE object_name <> @object_name;

    IF NOT EXISTS (SELECT 1 FROM @reg)
    BEGIN
        RAISERROR(N'Unknown @object_name ''%s'' — not in the pipeline registry.', 16, 1, @object_name);
        RETURN;
    END;

    DECLARE @on NVARCHAR(150), @os SYSNAME, @run_id BIGINT, @cmd NVARCHAR(400);

    DECLARE obj_cur CURSOR LOCAL FAST_FORWARD FOR SELECT object_name, object_short FROM @reg;
    OPEN obj_cur;
    FETCH NEXT FROM obj_cur INTO @on, @os;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO [ctl].[etl_run_control] ([object_name], [load_type], [start_time], [status])
        VALUES (@on, N'PIPELINE', SYSUTCDATETIME(), N'Running');
        SET @run_id = SCOPE_IDENTITY();

        BEGIN TRY
            /* 1) STAGING (incremental) — only if the per-object proc exists */
            SET @cmd = N'[staging].[refresh_' + @os + N'_latest]';
            IF OBJECT_ID(@cmd, N'P') IS NOT NULL
                EXEC sys.sp_executesql
                     N'EXEC ' + @cmd + N' @FullRebuild = @fr;',
                     N'@fr BIT', @fr = @rebuild_staging;

            /* 2) DQ (incremental, watermark-driven) — scoped to this object */
            EXEC [dq].[run_incremental_catalog_rules]
                 @ObjectNameFilter = @on,
                 @MaxRowsPerRule   = @MaxRowsPerRule;

            /* 3) CLEAN (incremental) — only if the per-object proc exists (gate is inside it) */
            IF @run_clean = 1
            BEGIN
                SET @cmd = N'[clean].[refresh_' + @os + N']';
                IF OBJECT_ID(@cmd, N'P') IS NOT NULL
                    EXEC sys.sp_executesql N'EXEC ' + @cmd + N';';
            END;

            UPDATE [ctl].[etl_run_control]
            SET [status] = N'Success', [end_time] = SYSUTCDATETIME()
            WHERE [run_id] = @run_id;
        END TRY
        BEGIN CATCH
            UPDATE [ctl].[etl_run_control]
            SET [status] = N'Failed', [end_time] = SYSUTCDATETIME(), [error_message] = ERROR_MESSAGE()
            WHERE [run_id] = @run_id;
            /* keep going with the next object */
        END CATCH;

        FETCH NEXT FROM obj_cur INTO @on, @os;
    END;
    CLOSE obj_cur;
    DEALLOCATE obj_cur;

    SELECT [run_id], [object_name], [load_type], [status], [start_time], [end_time], [error_message]
    FROM [ctl].[etl_run_control]
    WHERE [load_type] = N'PIPELINE'
      AND [start_time] >= DATEADD(MINUTE, -30, SYSUTCDATETIME())
    ORDER BY [run_id] DESC;
END;
GO
