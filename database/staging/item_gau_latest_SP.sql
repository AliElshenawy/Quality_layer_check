/* ============================================================================
   Item / GAU — INCREMENTAL "latest" staging builder (proc).
   ----------------------------------------------------------------------------
   Maintains staging.item_gau_latest INCREMENTALLY from raw.salesforce_item:
   only Ids whose SystemModstamp changed since ctl.staging_state are re-deduped
   and upserted (delete-changed + insert-latest); soft-deleted Ids drop out.

   Run:    EXEC staging.refresh_item_gau_latest;                 -- incremental
   Reset:  EXEC staging.refresh_item_gau_latest @FullRebuild=1;  -- truncate + rebuild

   Requires: staging.item_gau_latest (item_gau_latest_table.sql).
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [staging].[refresh_item_gau_latest]
    @FullRebuild BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @FullRebuild = 1
        TRUNCATE TABLE [staging].[item_gau_latest];

    DECLARE @wm DATETIME2(7) = NULL;
    IF @FullRebuild = 0
        SELECT @wm = [last_staging_watermark] FROM [ctl].[staging_state] WHERE [object_name] = N'item_gau';

    IF OBJECT_ID(N'tempdb..#chg') IS NOT NULL DROP TABLE #chg;
    SELECT DISTINCT CONVERT(VARCHAR(18), [Id]) AS id18
    INTO #chg
    FROM [raw].[salesforce_item]
    WHERE [Id] IS NOT NULL
      AND (@wm IS NULL
           OR COALESCE(TRY_CONVERT(DATETIME2(7), [SystemModstamp], 127),
                       TRY_CONVERT(DATETIME2(7), [SystemModstamp])) > @wm);

    DECLARE @deleted INT = 0, @inserted INT = 0;

    DELETE t FROM [staging].[item_gau_latest] t JOIN #chg c ON c.id18 = CONVERT(VARCHAR(18), t.[Id]);
    SET @deleted = @@ROWCOUNT;

    ;WITH dedup AS
    (
        SELECT
            [Id], [IsDeleted], [Name], [CurrencyIsoCode], [npsp__Active__c],
            [Product_Type__c], [Programme_Category__c], [Donation_Type__c], [Country__c], [Status__c], [Campaign__c],
            [Donation_Item_Code__c], [Allow_Single__c], [Allow_Recurring__c],
            [HA_Donation_Frequency__c], [Stipulation__c], [Regional_Office_Code__c],
            [Total_Non_Zakat_Credit__c], [Total_Zakat_Credit__c],
            [Total_funds_available_sadaqa__c], [Total_funds_available_zakat__c],
            [npsp__Total_Allocations__c], [npsp__Description__c], [Gift_Aid_Eligible__c],
            [SystemModstamp],
            ROW_NUMBER() OVER (PARTITION BY CONVERT(VARCHAR(18), [Id])
                ORDER BY COALESCE(TRY_CONVERT(DATETIME2(7), [SystemModstamp], 127),
                                  TRY_CONVERT(DATETIME2(7), [SystemModstamp])) DESC) AS rn,
            COUNT(*) OVER (PARTITION BY CONVERT(VARCHAR(18), [Id])) AS dup_cnt
        FROM [raw].[salesforce_item]
        WHERE [Id] IS NOT NULL
          AND CONVERT(VARCHAR(18), [Id]) IN (SELECT id18 FROM #chg)
    )
    INSERT INTO [staging].[item_gau_latest]
    (
        [row_number],
        [Id], [IsDeleted], [Name], [CurrencyIsoCode], [npsp__Active__c],
        [Product_Type__c], [Programme_Category__c], [Donation_Type__c], [Country__c], [Status__c], [Campaign__c],
        [Donation_Item_Code__c], [Allow_Single__c], [Allow_Recurring__c],
        [HA_Donation_Frequency__c], [Stipulation__c], [Regional_Office_Code__c],
        [Total_Non_Zakat_Credit__c], [Total_Zakat_Credit__c],
        [Total_funds_available_sadaqa__c], [Total_funds_available_zakat__c],
        [npsp__Total_Allocations__c], [npsp__Description__c], [Gift_Aid_Eligible__c],
        [SystemModstamp],
        [staging_is_duplicate], [staging_duplicate_count], [staging_created_at]
    )
    SELECT
        rn,
        [Id], [IsDeleted], [Name], [CurrencyIsoCode], [npsp__Active__c],
        [Product_Type__c], [Programme_Category__c], [Donation_Type__c], [Country__c], [Status__c], [Campaign__c],
        [Donation_Item_Code__c], [Allow_Single__c], [Allow_Recurring__c],
        [HA_Donation_Frequency__c], [Stipulation__c], [Regional_Office_Code__c],
        [Total_Non_Zakat_Credit__c], [Total_Zakat_Credit__c],
        [Total_funds_available_sadaqa__c], [Total_funds_available_zakat__c],
        [npsp__Total_Allocations__c], [npsp__Description__c], [Gift_Aid_Eligible__c],
        [SystemModstamp],
        CASE WHEN dup_cnt > 1 THEN 1 ELSE 0 END,
        CASE WHEN dup_cnt > 1 THEN dup_cnt ELSE 0 END,
        GETUTCDATE()
    FROM dedup
    WHERE rn = 1
      AND COALESCE(LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), [IsDeleted])))), N'false')
          NOT IN (N'true', N'1', N'yes', N'y');
    SET @inserted = @@ROWCOUNT;

    DECLARE @newwm DATETIME2(7) =
    (
        SELECT MAX(COALESCE(TRY_CONVERT(DATETIME2(7), [SystemModstamp], 127),
                            TRY_CONVERT(DATETIME2(7), [SystemModstamp])))
        FROM [raw].[salesforce_item]
    );

    MERGE [ctl].[staging_state] AS t
    USING (SELECT N'item_gau' AS object_name) AS s ON t.[object_name] = s.object_name
    WHEN MATCHED THEN UPDATE SET
        t.[last_staging_watermark] = @newwm, t.[last_run_at] = SYSUTCDATETIME(),
        t.[last_rows_merged] = @inserted, t.[last_rows_deleted] = @deleted
    WHEN NOT MATCHED THEN INSERT ([object_name], [last_staging_watermark], [last_run_at], [last_rows_merged], [last_rows_deleted])
        VALUES (N'item_gau', @newwm, SYSUTCDATETIME(), @inserted, @deleted);

    DROP TABLE #chg;
END;
GO
