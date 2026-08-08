/* ============================================================================
   Item / GAU — INCREMENTAL "latest" staging (persistent table).
   ----------------------------------------------------------------------------
   staging.item_gau_latest is the deduped one-row-per-Id snapshot. This file is
   the persistent table DDL only; the incremental builder lives in
   item_gau_latest_SP.sql (staging.refresh_item_gau_latest).
   Curated column set from Tables/item_gau/02_item_gau_staging_dq_PROD_framework.sql.
   Source: raw.salesforce_item.
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'staging') IS NULL
    EXEC (N'CREATE SCHEMA staging AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'[staging].[item_gau_latest]', N'U') IS NULL
BEGIN
    CREATE TABLE [staging].[item_gau_latest]
    (
        [row_number]                        BIGINT,
        [Id]                                NVARCHAR(MAX),
        [IsDeleted]                         NVARCHAR(MAX),
        [Name]                              NVARCHAR(MAX),
        [CurrencyIsoCode]                   NVARCHAR(MAX),
        [npsp__Active__c]                   NVARCHAR(MAX),
        [Product_Type__c]                   NVARCHAR(MAX),
        [Programme_Category__c]             NVARCHAR(MAX),
        [Donation_Type__c]                  NVARCHAR(MAX),
        [Country__c]                        NVARCHAR(MAX),
        [Status__c]                         NVARCHAR(MAX),
        [Campaign__c]                       NVARCHAR(MAX),
        [Donation_Item_Code__c]             NVARCHAR(MAX),
        [Allow_Single__c]                   NVARCHAR(MAX),
        [Allow_Recurring__c]                NVARCHAR(MAX),
        [HA_Donation_Frequency__c]          NVARCHAR(MAX),
        [Stipulation__c]                    NVARCHAR(MAX),
        [Regional_Office_Code__c]           NVARCHAR(MAX),
        [Total_Non_Zakat_Credit__c]         NVARCHAR(MAX),
        [Total_Zakat_Credit__c]             NVARCHAR(MAX),
        [Total_funds_available_sadaqa__c]   NVARCHAR(MAX),
        [Total_funds_available_zakat__c]    NVARCHAR(MAX),
        [npsp__Total_Allocations__c]        NVARCHAR(MAX),
        [npsp__Description__c]              NVARCHAR(MAX),
        [Gift_Aid_Eligible__c]              NVARCHAR(MAX),
        [SystemModstamp]                    NVARCHAR(MAX),
        [staging_is_duplicate]              BIT,
        [staging_duplicate_count]           INT,
        [staging_created_at]                DATETIME,
        [Id18] AS CONVERT(VARCHAR(18), [Id]) PERSISTED
    );
    CREATE UNIQUE INDEX [UX_item_gau_latest_id18] ON [staging].[item_gau_latest] ([Id18]);
END;
GO
