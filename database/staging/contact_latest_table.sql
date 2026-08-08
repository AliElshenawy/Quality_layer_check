/* ============================================================================
   Contact — INCREMENTAL "latest" staging (persistent table).
   ----------------------------------------------------------------------------
   staging.contact_latest is the deduped one-row-per-Id snapshot. This file is
   the persistent table DDL only; the incremental builder lives in
   contact_latest_SP.sql (staging.refresh_contact_latest).
   Curated column set from Tables/contact/02_contact_staging_dq_PROD_framework.sql.
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'staging') IS NULL
    EXEC (N'CREATE SCHEMA staging AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'[staging].[contact_latest]', N'U') IS NULL
BEGIN
    CREATE TABLE [staging].[contact_latest]
    (
        [row_number]                 BIGINT,
        [Id]                         NVARCHAR(MAX),
        [Name]                       NVARCHAR(MAX),
        [FirstName]                  NVARCHAR(MAX),
        [LastName]                   NVARCHAR(MAX),
        [RecordTypeId]               NVARCHAR(MAX),
        [IsDeleted]                  NVARCHAR(MAX),
        [Email]                      NVARCHAR(MAX),
        [Phone]                      NVARCHAR(MAX),
        [MobilePhone]                NVARCHAR(MAX),
        [MailingStreet]              NVARCHAR(MAX),
        [MailingCity]                NVARCHAR(MAX),
        [MailingState]               NVARCHAR(MAX),
        [MailingPostalCode]          NVARCHAR(MAX),
        [MailingCountry]             NVARCHAR(MAX),
        [External_Id__c]             NVARCHAR(MAX),
        [Regional_Office_Code__c]    NVARCHAR(MAX),
        [Gift_Aid_Status__c]         NVARCHAR(MAX),
        [Is_Donor__c]                NVARCHAR(MAX),
        [Guardian_ID__c]                            NVARCHAR(MAX),
        [Orphan_Mother_Is_Guardian__c]              NVARCHAR(MAX),
        [Orphan_Guardian_First_Name__c]             NVARCHAR(MAX),
        [Oprhan_Guardian_Last_Name__c]              NVARCHAR(MAX),
        [Orphan_Guardian_Relationship__c]           NVARCHAR(MAX),
        [Orphan_Mother_Not_Guardian_Reason__c]      NVARCHAR(MAX),
        [Orphan_Is_Mother_Alive__c]                 NVARCHAR(MAX),
        [Orphan_Mothers_Cause_Of_Death__c]          NVARCHAR(MAX),
        [Orphan_Mothers_Date_Of_Death__c]           NVARCHAR(MAX),
        [Orphan_Mother_Death_Verification_Method__c] NVARCHAR(MAX),
        [SystemModstamp]             NVARCHAR(MAX),
        [staging_is_duplicate]       BIT,
        [staging_duplicate_count]    INT,
        [staging_created_at]         DATETIME,
        [Id18] AS CONVERT(VARCHAR(18), [Id]) PERSISTED
    );
    CREATE UNIQUE INDEX [UX_contact_latest_id18] ON [staging].[contact_latest] ([Id18]);
END;
GO
