/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   VIEW [staging].[vw_sponsorship_unit_latest]
AS

WITH ranked_source AS
(
    SELECT
        [Id],[IsDeleted],[Name],[CurrencyIsoCode],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[Sponsorship__c],[GAU_Allocation__c],[Payment_Period__c],[Donation_Date__c],[OrphanAccountID__c],[Orphan_Id__c],[GAU_Name__c],[Deferred_Amount_in_GBP__c],[Deferred_Amount_in_LC__c],[Local_Currency_Of_Deferred_Funds__c],[Orphan_Account_Name__c],[Casesafe_Id__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object],

        ROW_NUMBER() OVER
        (
            PARTITION BY
                CONVERT
                (
                    VARCHAR(18),
                    [Id]
                )

            ORDER BY
                COALESCE
                (
                    TRY_CONVERT
                    (
                        DATETIME2(7),
                        [SystemModstamp],
                        127
                    ),
                    TRY_CONVERT
                    (
                        DATETIME2(7),
                        [SystemModstamp]
                    )
                ) DESC,TRY_CONVERT
                   (
                       BIGINT,
                       [_etl_run_id]
                   ) DESC
        ) AS _latest_row_number

    FROM [raw].[salesforce_sponsorship_unit]

    WHERE [Id] IS NOT NULL
)

SELECT
    [Id],[IsDeleted],[Name],[CurrencyIsoCode],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[Sponsorship__c],[GAU_Allocation__c],[Payment_Period__c],[Donation_Date__c],[OrphanAccountID__c],[Orphan_Id__c],[GAU_Name__c],[Deferred_Amount_in_GBP__c],[Deferred_Amount_in_LC__c],[Local_Currency_Of_Deferred_Funds__c],[Orphan_Account_Name__c],[Casesafe_Id__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object]

FROM ranked_source

WHERE _latest_row_number = 1
                AND COALESCE
                (
                    LOWER
                    (
                        LTRIM
                        (
                            RTRIM
                            (
                                CONVERT
                                (
                                    NVARCHAR(20),
                                    [IsDeleted]
                                )
                            )
                        )
                    ),
                    N'false'
                ) NOT IN
                (
                    N'true',
                    N'1',
                    N'yes',
                    N'y'
                );
GO
