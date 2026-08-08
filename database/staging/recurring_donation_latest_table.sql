/* ============================================================================
   Recurring Donation — INCREMENTAL "latest" staging (persistent table).
   ----------------------------------------------------------------------------
   staging.recurring_donation_latest is the deduped one-row-per-Id snapshot.
   This file is the persistent table DDL only; the incremental builder lives in
   recurring_donation_latest_SP.sql (staging.refresh_recurring_donation_latest).
   Curated column set from
   Tables/recurring_donation/02_recurring_donation_staging_dq_PROD_framework.sql.
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'staging') IS NULL
    EXEC (N'CREATE SCHEMA staging AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'[staging].[recurring_donation_latest]', N'U') IS NULL
BEGIN
    CREATE TABLE [staging].[recurring_donation_latest]
    (
        [row_number]                            BIGINT,
        [Id]                                    NVARCHAR(MAX),
        [IsDeleted]                             NVARCHAR(MAX),
        [Name]                                  NVARCHAR(MAX),
        [CurrencyIsoCode]                       NVARCHAR(MAX),
        [npe03__Contact__c]                     NVARCHAR(MAX),
        [npe03__Organization__c]                NVARCHAR(MAX),
        [npe03__Amount__c]                      NVARCHAR(MAX),
        [npe03__Installment_Amount__c]          NVARCHAR(MAX),
        [npe03__Paid_Amount__c]                 NVARCHAR(MAX),
        [Total_Donation_Amount__c]              NVARCHAR(MAX),
        [npsp__Status__c]                       NVARCHAR(MAX),
        [npsp__RecurringType__c]                NVARCHAR(MAX),
        [npsp__StartDate__c]                    NVARCHAR(MAX),
        [npsp__EndDate__c]                      NVARCHAR(MAX),
        [npsp__ClosedReason__c]                 NVARCHAR(MAX),
        [npe03__Installment_Period__c]          NVARCHAR(MAX),
        [npsp__Day_of_Month__c]                 NVARCHAR(MAX),
        [npe03__Next_Payment_Date__c]           NVARCHAR(MAX),
        [Donation_Type__c]                      NVARCHAR(MAX),
        [npsp__PaymentMethod__c]                NVARCHAR(MAX),
        [Regional_Office_Code__c]               NVARCHAR(MAX),
        [npe03__Recurring_Donation_Campaign__c] NVARCHAR(MAX),
        [Number_of_Failed_Payments__c]          NVARCHAR(MAX),
        [SystemModstamp]                        NVARCHAR(MAX),
        [staging_is_duplicate]                  BIT,
        [staging_duplicate_count]               INT,
        [staging_created_at]                    DATETIME,
        [Id18] AS CONVERT(VARCHAR(18), [Id]) PERSISTED
    );
    CREATE UNIQUE INDEX [UX_recurring_donation_latest_id18] ON [staging].[recurring_donation_latest] ([Id18]);
END;
GO
