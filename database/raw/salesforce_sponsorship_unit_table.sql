/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [raw].[salesforce_sponsorship_unit](
	[Id] [varchar](max) NULL,
	[IsDeleted] [varchar](max) NULL,
	[Name] [varchar](max) NULL,
	[CurrencyIsoCode] [varchar](max) NULL,
	[CreatedDate] [varchar](max) NULL,
	[CreatedById] [varchar](max) NULL,
	[LastModifiedDate] [varchar](max) NULL,
	[LastModifiedById] [varchar](max) NULL,
	[SystemModstamp] [varchar](max) NULL,
	[LastActivityDate] [varchar](max) NULL,
	[Sponsorship__c] [varchar](max) NULL,
	[GAU_Allocation__c] [varchar](max) NULL,
	[Payment_Period__c] [varchar](max) NULL,
	[Donation_Date__c] [varchar](max) NULL,
	[OrphanAccountID__c] [varchar](max) NULL,
	[Orphan_Id__c] [varchar](max) NULL,
	[GAU_Name__c] [varchar](max) NULL,
	[Deferred_Amount_in_GBP__c] [varchar](max) NULL,
	[Deferred_Amount_in_LC__c] [varchar](max) NULL,
	[Local_Currency_Of_Deferred_Funds__c] [varchar](max) NULL,
	[Orphan_Account_Name__c] [varchar](max) NULL,
	[Casesafe_Id__c] [varchar](max) NULL,
	[_etl_run_id] [bigint] NULL,
	[_etl_extracted_at_utc] [datetime] NULL,
	[_etl_source_object] [varchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
