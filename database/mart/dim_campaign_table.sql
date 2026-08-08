/* ============================================================================
   Author: Mohey
   Origin: Scripted from live SalesforceDW (existing table, added to repo 2026-08-06).
   ----------------------------------------------------------------------------
   mart.dim_campaign — reporting dimension for Campaign (Power BI reads the mart,
   never raw/history). Grain: one row per campaign. Populate from clean.campaign
   (build/refresh proc to be added with the mart layer, SDE-017).
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[mart].[dim_campaign]', N'U') IS NULL
BEGIN
    CREATE TABLE [mart].[dim_campaign]
    (
        [campaign_key]          INT IDENTITY(1,1) NOT NULL,
        [campaign_id]           NVARCHAR(36)  NULL,
        [campaign_name]         NVARCHAR(MAX) NULL,
        [campaign_type]         NVARCHAR(MAX) NULL,
        [campaign_status]       NVARCHAR(MAX) NULL,
        [is_active]             NVARCHAR(20)  NULL,
        [parent_campaign_id]    NVARCHAR(36)  NULL,
        [parent_campaign_name]  NVARCHAR(MAX) NULL,
        [department]            NVARCHAR(MAX) NULL,
        [source]                NVARCHAR(MAX) NULL,
        [region]                NVARCHAR(MAX) NULL,
        [country]               NVARCHAR(MAX) NULL,
        [currency]              NVARCHAR(6)   NULL,
        [campaign_year]         INT           NULL,
        [campaign_code]         NVARCHAR(MAX) NULL,
        [owner_id]              NVARCHAR(MAX) NULL,
        [record_type]           NVARCHAR(MAX) NULL,
        [dw_created_at]         DATETIME2(7)  NULL
            CONSTRAINT [DF_dim_campaign_created] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_dim_campaign] PRIMARY KEY CLUSTERED ([campaign_key])
    );
END;
GO
