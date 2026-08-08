/* ============================================================================
   Author: Mohey
   Origin: Campaign POC — Stage 4 clean BUILD proc (INCREMENTAL).
   ----------------------------------------------------------------------------
   clean.refresh_campaign maintains clean.campaign INCREMENTALLY:
     - reads only staging rows changed since ctl.clean_state watermark,
     - MERGEs (upsert by Id) into the persistent clean.campaign — no full rebuild,
       so applied write-back corrections survive between runs,
     - advances the watermark,
     - syncs dq.alert (CAM-008 won>all) for the changed rows only.

   No end-dedup needed: staging.campaign_latest is already unique per Id, and the
   MERGE upserts by Id, so duplicates never accumulate.

   Gate: refuses to build while any CRITICAL Campaign exception is open.
   Reset:  EXEC clean.refresh_campaign @FullRebuild = 1;   -- truncates + rebuilds
   Run:    EXEC clean.refresh_campaign;                    -- incremental
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [clean].[refresh_campaign]
    @FullRebuild BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF OBJECT_ID(N'[clean].[campaign]', N'U') IS NULL
    BEGIN
        RAISERROR(N'clean.campaign is missing — run clean/campaign_table.sql first.', 16, 1);
        RETURN;
    END;

    IF OBJECT_ID(N'[staging].[campaign_latest]', N'U') IS NULL
    BEGIN
        RAISERROR(N'staging.campaign_latest is missing. Run staging.refresh_campaign_latest first.', 16, 1);
        RETURN;
    END;

    /* -- GATE 3: refuse while any CRITICAL exception is open. -- */
    IF OBJECT_ID(N'[dq].[dq_exceptions]', N'U') IS NOT NULL
       AND OBJECT_ID(N'[dq].[dq_rule_catalog]', N'U') IS NOT NULL
    BEGIN
        DECLARE @critical_open INT =
        (
            SELECT COUNT(*)
            FROM [dq].[dq_exceptions] e
            JOIN [dq].[dq_rule_catalog] r ON r.[rule_id] = e.[rule_id]
            WHERE e.[object_name] = N'Campaign'
              AND r.[severity]    = N'CRITICAL'
              AND e.[resolution_status] = N'Open'
        );
        IF @critical_open > 0
        BEGIN
            RAISERROR(N'Clean blocked: %d open CRITICAL Campaign exception(s).', 16, 1, @critical_open);
            RETURN;
        END;
    END;

    /* -- Watermark: full rebuild truncates and processes everything. -- */
    DECLARE @wm DATETIME2(7) = NULL;
    IF @FullRebuild = 1
        TRUNCATE TABLE [clean].[campaign];
    ELSE
        SELECT @wm = [last_clean_watermark] FROM [ctl].[clean_state] WHERE [object_name] = N'Campaign';

    /* -- Only staging rows changed since the watermark. -- */
    IF OBJECT_ID(N'tempdb..#chg') IS NOT NULL DROP TABLE #chg;
    SELECT s.*
    INTO #chg
    FROM [staging].[campaign_latest] AS s
    WHERE @wm IS NULL
       OR COALESCE(TRY_CONVERT(DATETIME2(7), s.[SystemModstamp], 127),
                   TRY_CONVERT(DATETIME2(7), s.[SystemModstamp])) > @wm;

    DECLARE @rows INT = 0;

    ;WITH src AS
    (
        SELECT
            s.[Id], s.[Name], s.[ParentId], s.[Type], s.[Region__c],
            s.[BudgetedCost], s.[ActualCost],
            s.[Status]          AS Status_raw,
            s.[CurrencyIsoCode] AS CurrencyIsoCode_raw,
            s.[IsActive]        AS IsActive_raw,
            s.[StartDate]       AS StartDate_raw,
            s.[EndDate]         AS EndDate_raw,
            s.[Year__c]         AS Year_raw,
            s.[SystemModstamp],
            LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(LOWER(CONVERT(NVARCHAR(200), s.[Status])),
                CHAR(9), N' '), N'  ', N' '), N'  ', N' '))) AS status_key,
            NULLIF(UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(10), s.[CurrencyIsoCode])))), N'') AS currency_clean,
            COALESCE(TRY_CONVERT(DATE, s.[StartDate], 127), TRY_CONVERT(DATE, s.[StartDate])) AS start_clean,
            COALESCE(TRY_CONVERT(DATE, s.[EndDate], 127),   TRY_CONVERT(DATE, s.[EndDate]))   AS end_clean,
            CASE
                WHEN LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), s.[IsActive])))) IN (N'true', N'1', N'yes', N'y') THEN 1
                WHEN LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), s.[IsActive])))) IN (N'false', N'0', N'no', N'n') THEN 0
                ELSE NULL
            END AS isactive_clean
        FROM #chg AS s
    ),
    calc AS
    (
        SELECT
            src.*,
            CASE
                WHEN status_key IS NULL OR status_key = N'' THEN N'Aborted'
                WHEN status_key = N'in progress' THEN N'In Progress'
                WHEN status_key = N'completed'   THEN N'Completed'
                WHEN status_key = N'planned'     THEN N'Planned'
                WHEN status_key = N'aborted'     THEN N'Aborted'
                ELSE status_key
            END AS status_clean,
            CASE WHEN start_clean IS NOT NULL THEN YEAR(start_clean) END AS year_clean,
            CASE WHEN currency_clean LIKE N'[A-Z][A-Z][A-Z]' THEN 1 ELSE 0 END AS currency_ok,
            CASE WHEN status_key IN (N'in progress', N'completed', N'planned', N'aborted') THEN 1 ELSE 0 END AS status_known
        FROM src
    ),
    final AS
    (
        SELECT calc.*, review.review_reason
        FROM calc
        CROSS APPLY
        (
            SELECT NULLIF(CONCAT_WS(N'; ',
                CASE WHEN [Name] IS NULL OR LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), [Name]))) = N''
                     THEN N'CAM-003 Name missing' END,
                CASE WHEN StartDate_raw IS NOT NULL AND start_clean IS NULL THEN N'invalid StartDate' END,
                CASE WHEN EndDate_raw IS NOT NULL AND end_clean IS NULL THEN N'invalid EndDate' END,
                CASE WHEN start_clean IS NOT NULL AND end_clean IS NOT NULL AND start_clean > end_clean
                     THEN N'CAM-005 StartDate after EndDate' END,
                CASE WHEN currency_clean IS NOT NULL AND currency_ok = 0
                     THEN N'CAM-006 currency not a 3-letter code' END,
                CASE WHEN status_key IS NOT NULL AND status_known = 0
                     THEN N'CAM-004 status not in standard picklist' END,
                CASE WHEN IsActive_raw IS NOT NULL AND isactive_clean IS NULL
                     THEN N'CAM-017 IsActive not boolean' END
            ), N'') AS review_reason
        ) AS review
    )
    MERGE [clean].[campaign] AS tgt
    USING final AS s
        ON tgt.[Id18] = CONVERT(VARCHAR(18), s.[Id])
    WHEN MATCHED THEN UPDATE SET
        tgt.[Name] = s.[Name], tgt.[ParentId] = s.[ParentId], tgt.[Type] = s.[Type],
        tgt.[Region__c] = s.[Region__c], tgt.[BudgetedCost] = s.[BudgetedCost], tgt.[ActualCost] = s.[ActualCost],
        tgt.[Status_raw] = s.Status_raw, tgt.[CurrencyIsoCode_raw] = s.CurrencyIsoCode_raw,
        tgt.[IsActive_raw] = s.IsActive_raw, tgt.[StartDate_raw] = s.StartDate_raw,
        tgt.[EndDate_raw] = s.EndDate_raw, tgt.[Year_raw] = s.Year_raw,
        tgt.[Status_clean] = s.status_clean, tgt.[CurrencyIsoCode_clean] = s.currency_clean,
        tgt.[IsActive_clean] = s.isactive_clean, tgt.[StartDate_clean] = s.start_clean,
        tgt.[EndDate_clean] = s.end_clean, tgt.[Year_clean] = s.year_clean,
        tgt.[SystemModstamp] = s.[SystemModstamp],
        tgt.[clean_flag] = CASE WHEN s.review_reason IS NULL THEN N'CLEAN' ELSE N'REVIEW' END,
        tgt.[review_reason] = s.review_reason,
        tgt.[clean_updated_at] = GETUTCDATE()
    WHEN NOT MATCHED THEN INSERT
        ([Id], [Name], [ParentId], [Type], [Region__c], [BudgetedCost], [ActualCost],
         [Status_raw], [CurrencyIsoCode_raw], [IsActive_raw], [StartDate_raw], [EndDate_raw], [Year_raw],
         [Status_clean], [CurrencyIsoCode_clean], [IsActive_clean], [StartDate_clean], [EndDate_clean], [Year_clean],
         [SystemModstamp], [clean_flag], [review_reason], [clean_created_at], [clean_updated_at])
    VALUES
        (s.[Id], s.[Name], s.[ParentId], s.[Type], s.[Region__c], s.[BudgetedCost], s.[ActualCost],
         s.Status_raw, s.CurrencyIsoCode_raw, s.IsActive_raw, s.StartDate_raw, s.EndDate_raw, s.Year_raw,
         s.status_clean, s.currency_clean, s.isactive_clean, s.start_clean, s.end_clean, s.year_clean,
         s.[SystemModstamp], CASE WHEN s.review_reason IS NULL THEN N'CLEAN' ELSE N'REVIEW' END,
         s.review_reason, GETUTCDATE(), GETUTCDATE());

    SET @rows = @@ROWCOUNT;

    /* -- Advance the clean watermark to the max SystemModstamp in staging. -- */
    DECLARE @newwm DATETIME2(7) =
    (
        SELECT MAX(COALESCE(TRY_CONVERT(DATETIME2(7), [SystemModstamp], 127),
                            TRY_CONVERT(DATETIME2(7), [SystemModstamp])))
        FROM [staging].[campaign_latest]
    );

    MERGE [ctl].[clean_state] AS t
    USING (SELECT N'Campaign' AS object_name) AS s ON t.[object_name] = s.object_name
    WHEN MATCHED THEN UPDATE SET
        t.[last_clean_watermark] = @newwm, t.[last_run_at] = SYSUTCDATETIME(), t.[last_rows_merged] = @rows
    WHEN NOT MATCHED THEN INSERT ([object_name], [last_clean_watermark], [last_run_at], [last_rows_merged])
        VALUES (N'Campaign', @newwm, SYSUTCDATETIME(), @rows);

    /* -- dq.alert (CAM-008 won>all) — sync only the changed rows. -- */
    IF OBJECT_ID(N'[dq].[alert]', N'U') IS NOT NULL
    BEGIN
        DELETE a FROM [dq].[alert] a
        WHERE a.[object_name] = N'Campaign' AND a.[check_name] = N'CAM-008'
          AND a.[record_id] IN (SELECT CONVERT(VARCHAR(18), [Id]) FROM #chg);

        INSERT INTO [dq].[alert]
            ([object_name], [record_id], [check_name], [severity], [issue],
             [current_value], [cleaned], [alert_status], [created_at])
        SELECT
            N'Campaign', CONVERT(VARCHAR(18), s.[Id]), N'CAM-008', N'MEDIUM',
            N'AmountWonOpportunities exceeds AmountAllOpportunities',
            CONCAT(N'Won=', s.[AmountWonOpportunities], N'; All=', s.[AmountAllOpportunities],
                   N'; Excess=',
                   CONVERT(NVARCHAR(40), TRY_CONVERT(DECIMAL(18,2), s.[AmountWonOpportunities])
                                        - TRY_CONVERT(DECIMAL(18,2), s.[AmountAllOpportunities]))),
            0, N'Open', SYSUTCDATETIME()
        FROM #chg AS s
        WHERE NULLIF(LTRIM(RTRIM(COALESCE(s.[AmountWonOpportunities], N''))), N'') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(COALESCE(s.[AmountAllOpportunities], N''))), N'') IS NOT NULL
          AND TRY_CONVERT(DECIMAL(18,2), s.[AmountWonOpportunities])
              > TRY_CONVERT(DECIMAL(18,2), s.[AmountAllOpportunities]);
    END;

    DROP TABLE #chg;
END;
GO
