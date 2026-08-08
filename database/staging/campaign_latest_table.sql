/* ============================================================================
   Author: Mohey
   Origin: Campaign POC — INCREMENTAL "latest" staging (persistent table).
   ----------------------------------------------------------------------------
   staging.campaign_latest is the deduped one-row-per-Id snapshot. This file is
   the persistent table DDL only; the incremental builder lives in
   campaign_latest_SP.sql (staging.refresh_campaign_latest).
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'staging') IS NULL
    EXEC (N'CREATE SCHEMA staging AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'[staging].[campaign_latest]', N'U') IS NULL
BEGIN
    CREATE TABLE [staging].[campaign_latest]
    (
        [row_number]                        BIGINT,
        [Id]                                NVARCHAR(MAX),
        [ParentId]                          NVARCHAR(MAX),
        [Type]                              NVARCHAR(MAX),
        [RecordTypeId]                      NVARCHAR(MAX),
        [IsDeleted]                         NVARCHAR(MAX),
        [Name]                              NVARCHAR(MAX),
        [Status]                            NVARCHAR(MAX),
        [StartDate]                         NVARCHAR(MAX),
        [EndDate]                           NVARCHAR(MAX),
        [Year__c]                           NVARCHAR(MAX),
        [Region__c]                         NVARCHAR(MAX),
        [CurrencyIsoCode]                   NVARCHAR(MAX),
        [BudgetedCost]                      NVARCHAR(MAX),
        [ActualCost]                        NVARCHAR(MAX),
        [IsActive]                          NVARCHAR(MAX),
        [NumberOfOpportunities]             NVARCHAR(MAX),
        [HierarchyNumberOfOpportunities]    NVARCHAR(MAX),
        [AmountAllOpportunities]            NVARCHAR(MAX),
        [AmountWonOpportunities]            NVARCHAR(MAX),
        [Casesafe_Campaign_ID__c]           NVARCHAR(MAX),
        [Fundraising_page_url__c]           NVARCHAR(MAX),
        [SystemModstamp]                    NVARCHAR(MAX),
        [staging_is_duplicate]              BIT,
        [staging_duplicate_count]           INT,
        [staging_created_at]                DATETIME,
        [Id18] AS CONVERT(VARCHAR(18), [Id]) PERSISTED
    );
    CREATE UNIQUE INDEX [UX_campaign_latest_id18] ON [staging].[campaign_latest] ([Id18]);
END;
GO
