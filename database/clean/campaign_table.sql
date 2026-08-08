/* ============================================================================
   Author: Mohey
   Origin: Campaign POC — Stage 4 clean TABLE (DDL only; the build proc is in
   clean/refresh_campaign_SP.sql).
   ----------------------------------------------------------------------------
   clean.campaign is PERSISTENT — it is created once and maintained INCREMENTALLY
   by clean.refresh_campaign (MERGE/upsert by Id). It is NOT dropped each run, so
   approved write-back corrections applied here survive between runs.
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'clean') IS NULL
    EXEC (N'CREATE SCHEMA [clean];');
GO

IF OBJECT_ID(N'[clean].[campaign]', N'U') IS NULL
BEGIN
    CREATE TABLE [clean].[campaign]
    (
        [Id]                        NVARCHAR(MAX),
        [Name]                      NVARCHAR(MAX),
        [ParentId]                  NVARCHAR(MAX),
        [Type]                      NVARCHAR(MAX),
        [Region__c]                 NVARCHAR(MAX),
        [BudgetedCost]              NVARCHAR(MAX),
        [ActualCost]                NVARCHAR(MAX),

        /* originals kept for before/after visibility */
        [Status_raw]                NVARCHAR(MAX),
        [CurrencyIsoCode_raw]       NVARCHAR(MAX),
        [IsActive_raw]              NVARCHAR(MAX),
        [StartDate_raw]             NVARCHAR(MAX),
        [EndDate_raw]               NVARCHAR(MAX),
        [Year_raw]                  NVARCHAR(MAX),

        /* cleaned / corrected outputs */
        [Status_clean]              NVARCHAR(200),
        [CurrencyIsoCode_clean]     NVARCHAR(10),
        [IsActive_clean]            BIT,
        [StartDate_clean]           DATE,
        [EndDate_clean]             DATE,
        [Year_clean]                INT,

        /* key / lineage carried unchanged */
        [SystemModstamp]            NVARCHAR(MAX),

        /* provenance of the clean step */
        [clean_flag]                NVARCHAR(10)  NOT NULL,   -- 'CLEAN' or 'REVIEW'
        [review_reason]             NVARCHAR(MAX) NULL,
        [clean_created_at]          DATETIME      NOT NULL,
        [clean_updated_at]          DATETIME      NOT NULL,

        /* 18-char projection of Id for the MERGE key / uniqueness */
        [Id18] AS CONVERT(VARCHAR(18), [Id]) PERSISTED
    );

    CREATE UNIQUE INDEX [UX_clean_campaign_id18] ON [clean].[campaign] ([Id18]);
END;
GO
