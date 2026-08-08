/* ============================================================================
   Recurring Donation — INCREMENTAL "latest" staging builder (proc).
   ----------------------------------------------------------------------------
   Maintains staging.recurring_donation_latest INCREMENTALLY from
   raw.salesforce_recurring_donation: only Ids whose SystemModstamp changed since
   ctl.staging_state are re-deduped and upserted (delete-changed + insert-latest);
   soft-deleted Ids drop out.

   Run:    EXEC staging.refresh_recurring_donation_latest;                 -- incremental
   Reset:  EXEC staging.refresh_recurring_donation_latest @FullRebuild=1;  -- truncate + rebuild

   Requires: staging.recurring_donation_latest (recurring_donation_latest_table.sql).
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [staging].[refresh_recurring_donation_latest]
    @FullRebuild BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @FullRebuild = 1
        TRUNCATE TABLE [staging].[recurring_donation_latest];

    DECLARE @wm DATETIME2(7) = NULL;
    IF @FullRebuild = 0
        SELECT @wm = [last_staging_watermark] FROM [ctl].[staging_state] WHERE [object_name] = N'recurring_donation';

    IF OBJECT_ID(N'tempdb..#chg') IS NOT NULL DROP TABLE #chg;
    SELECT DISTINCT CONVERT(VARCHAR(18), [Id]) AS id18
    INTO #chg
    FROM [raw].[salesforce_recurring_donation]
    WHERE [Id] IS NOT NULL
      AND (@wm IS NULL
           OR COALESCE(TRY_CONVERT(DATETIME2(7), [SystemModstamp], 127),
                       TRY_CONVERT(DATETIME2(7), [SystemModstamp])) > @wm);

    DECLARE @deleted INT = 0, @inserted INT = 0;

    DELETE t FROM [staging].[recurring_donation_latest] t JOIN #chg c ON c.id18 = CONVERT(VARCHAR(18), t.[Id]);
    SET @deleted = @@ROWCOUNT;

    ;WITH dedup AS
    (
        SELECT
            [Id], [IsDeleted], [Name], [CurrencyIsoCode],
            [npe03__Contact__c], [npe03__Organization__c],
            [npe03__Amount__c], [npe03__Installment_Amount__c], [npe03__Paid_Amount__c],
            [Total_Donation_Amount__c],
            [npsp__Status__c], [npsp__RecurringType__c],
            [npsp__StartDate__c], [npsp__EndDate__c], [npsp__ClosedReason__c],
            [npe03__Installment_Period__c], [npsp__Day_of_Month__c], [npe03__Next_Payment_Date__c],
            [Donation_Type__c], [npsp__PaymentMethod__c], [Regional_Office_Code__c],
            [npe03__Recurring_Donation_Campaign__c], [Number_of_Failed_Payments__c],
            [SystemModstamp],
            ROW_NUMBER() OVER (PARTITION BY CONVERT(VARCHAR(18), [Id])
                ORDER BY COALESCE(TRY_CONVERT(DATETIME2(7), [SystemModstamp], 127),
                                  TRY_CONVERT(DATETIME2(7), [SystemModstamp])) DESC) AS rn,
            COUNT(*) OVER (PARTITION BY CONVERT(VARCHAR(18), [Id])) AS dup_cnt
        FROM [raw].[salesforce_recurring_donation]
        WHERE [Id] IS NOT NULL
          AND CONVERT(VARCHAR(18), [Id]) IN (SELECT id18 FROM #chg)
    )
    INSERT INTO [staging].[recurring_donation_latest]
    (
        [row_number],
        [Id], [IsDeleted], [Name], [CurrencyIsoCode],
        [npe03__Contact__c], [npe03__Organization__c],
        [npe03__Amount__c], [npe03__Installment_Amount__c], [npe03__Paid_Amount__c],
        [Total_Donation_Amount__c],
        [npsp__Status__c], [npsp__RecurringType__c],
        [npsp__StartDate__c], [npsp__EndDate__c], [npsp__ClosedReason__c],
        [npe03__Installment_Period__c], [npsp__Day_of_Month__c], [npe03__Next_Payment_Date__c],
        [Donation_Type__c], [npsp__PaymentMethod__c], [Regional_Office_Code__c],
        [npe03__Recurring_Donation_Campaign__c], [Number_of_Failed_Payments__c],
        [SystemModstamp],
        [staging_is_duplicate], [staging_duplicate_count], [staging_created_at]
    )
    SELECT
        rn,
        [Id], [IsDeleted], [Name], [CurrencyIsoCode],
        [npe03__Contact__c], [npe03__Organization__c],
        [npe03__Amount__c], [npe03__Installment_Amount__c], [npe03__Paid_Amount__c],
        [Total_Donation_Amount__c],
        [npsp__Status__c], [npsp__RecurringType__c],
        [npsp__StartDate__c], [npsp__EndDate__c], [npsp__ClosedReason__c],
        [npe03__Installment_Period__c], [npsp__Day_of_Month__c], [npe03__Next_Payment_Date__c],
        [Donation_Type__c], [npsp__PaymentMethod__c], [Regional_Office_Code__c],
        [npe03__Recurring_Donation_Campaign__c], [Number_of_Failed_Payments__c],
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
        FROM [raw].[salesforce_recurring_donation]
    );

    MERGE [ctl].[staging_state] AS t
    USING (SELECT N'recurring_donation' AS object_name) AS s ON t.[object_name] = s.object_name
    WHEN MATCHED THEN UPDATE SET
        t.[last_staging_watermark] = @newwm, t.[last_run_at] = SYSUTCDATETIME(),
        t.[last_rows_merged] = @inserted, t.[last_rows_deleted] = @deleted
    WHEN NOT MATCHED THEN INSERT ([object_name], [last_staging_watermark], [last_run_at], [last_rows_merged], [last_rows_deleted])
        VALUES (N'recurring_donation', @newwm, SYSUTCDATETIME(), @inserted, @deleted);

    DROP TABLE #chg;
END;
GO
