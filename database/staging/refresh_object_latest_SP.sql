/* ============================================================================
   Author: Mohey
   Origin: Generic INCREMENTAL "latest" materializer for any object.
   ----------------------------------------------------------------------------
   staging.refresh_object_latest maintains staging.<obj>_latest INCREMENTALLY from
   the dedup view staging.vw_<obj>_latest:
     - first run / @FullRebuild: full build (SELECT * INTO from the view),
     - otherwise: delete-changed + insert-current for only the Ids whose raw
       SystemModstamp changed since ctl.staging_state (soft-deleted Ids drop out,
       because the view already excludes them).
   Watermark per object in ctl.staging_state. Campaign uses its own curated builder.

   Run:    EXEC staging.refresh_object_latest @object_short=N'sponsorship';
   Reset:  EXEC staging.refresh_object_latest @object_short=N'sponsorship', @FullRebuild=1;
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [staging].[refresh_object_latest]
    @object_short SYSNAME,
    @FullRebuild  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @qview NVARCHAR(300) = QUOTENAME(N'staging') + N'.' + QUOTENAME(N'vw_' + @object_short + N'_latest');
    DECLARE @qtbl  NVARCHAR(300) = QUOTENAME(N'staging') + N'.' + QUOTENAME(@object_short + N'_latest');
    DECLARE @qraw  NVARCHAR(300) = QUOTENAME(N'raw')     + N'.' + QUOTENAME(N'salesforce_' + @object_short);
    DECLARE @sql   NVARCHAR(MAX);

    IF OBJECT_ID(@qview, N'V') IS NULL
    BEGIN
        RAISERROR(N'Latest view %s not found — deploy staging views first.', 16, 1, @qview);
        RETURN;
    END;

    IF OBJECT_ID(@qtbl, N'U') IS NULL
    BEGIN
        /* First build: create the persistent table from the view (nothing to drop). */
        SET @sql = N'SELECT v.*, SYSUTCDATETIME() AS [staging_created_at] INTO ' + @qtbl + N' FROM ' + @qview + N' AS v;';
        EXEC sys.sp_executesql @sql;
    END
    ELSE IF @FullRebuild = 1
    BEGIN
        /* Explicit reset: keep the persistent table, TRUNCATE + reload (no DROP). */
        SET @sql = N'TRUNCATE TABLE ' + @qtbl + N';' + NCHAR(10) +
                   N'INSERT INTO ' + @qtbl + N' SELECT v.*, SYSUTCDATETIME() FROM ' + @qview + N' AS v;';
        EXEC sys.sp_executesql @sql;
    END
    ELSE
    BEGIN
        DECLARE @wm DATETIME2(7) = NULL;
        SELECT @wm = [last_staging_watermark] FROM [ctl].[staging_state] WHERE [object_name] = @object_short;

        SET @sql =
            N'IF OBJECT_ID(''tempdb..#chg'',''U'') IS NOT NULL DROP TABLE #chg;' + NCHAR(10) +
            N'SELECT DISTINCT CONVERT(VARCHAR(18),[Id]) AS id18 INTO #chg FROM ' + @qraw +
              N' WHERE [Id] IS NOT NULL AND (@w IS NULL OR COALESCE(TRY_CONVERT(DATETIME2(7),[SystemModstamp],127),TRY_CONVERT(DATETIME2(7),[SystemModstamp])) > @w);' + NCHAR(10) +
            N'DELETE t FROM ' + @qtbl + N' t JOIN #chg c ON c.id18 = CONVERT(VARCHAR(18), t.[Id]);' + NCHAR(10) +
            N'INSERT INTO ' + @qtbl + N' SELECT v.*, SYSUTCDATETIME() FROM ' + @qview + N' v JOIN #chg c ON c.id18 = CONVERT(VARCHAR(18), v.[Id]);' + NCHAR(10) +
            N'DROP TABLE #chg;';
        EXEC sys.sp_executesql @sql, N'@w DATETIME2(7)', @w = @wm;
    END;

    DECLARE @newwm DATETIME2(7);
    SET @sql = N'SELECT @o = MAX(COALESCE(TRY_CONVERT(DATETIME2(7),[SystemModstamp],127),TRY_CONVERT(DATETIME2(7),[SystemModstamp]))) FROM ' + @qraw + N';';
    EXEC sys.sp_executesql @sql, N'@o DATETIME2(7) OUTPUT', @o = @newwm OUTPUT;

    MERGE [ctl].[staging_state] AS t
    USING (SELECT @object_short AS object_name) AS s ON t.[object_name] = s.object_name
    WHEN MATCHED THEN UPDATE SET t.[last_staging_watermark] = @newwm, t.[last_run_at] = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT ([object_name], [last_staging_watermark], [last_run_at])
        VALUES (@object_short, @newwm, SYSUTCDATETIME());
END;
GO
