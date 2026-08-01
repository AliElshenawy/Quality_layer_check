/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   VIEW [staging].[vw_payment_latest]
AS

WITH ranked_source AS
(
    SELECT
        [Id],[IsDeleted],[Name],[CurrencyIsoCode],[RecordTypeId],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastViewedDate],[LastReferencedDate],[npe01__Opportunity__c],[npe01__Check_Reference_Number__c],[npe01__Custom_Payment_Field__c],[npe01__Paid__c],[npe01__Payment_Amount__c],[npe01__Payment_Date__c],[npe01__Payment_Method__c],[npe01__Scheduled_Date__c],[npe01__Written_Off__c],[npsp__Payment_Acknowledged_Date__c],[npsp__Payment_Acknowledgment_Status__c],[npsp__Authorized_Date__c],[npsp__Authorized_UTC_Timestamp__c],[npsp__Card_Expiration_Month__c],[npsp__Card_Expiration_Year__c],[npsp__Card_Last_4__c],[npsp__Card_Network__c],[npsp__Elevate_Original_Payment_ID__c],[npsp__Elevate_Payment_Created_Date__c],[npsp__Elevate_Payment_Created_UTC_Timestamp__c],[npsp__Elevate_Payment_ID__c],[npsp__Gateway_ID__c],[npsp__Gateway_Payment_ID__c],[npsp__Origin_ID__c],[npsp__Origin_Name__c],[npsp__Origin_Type__c],[npsp__Type__c],[npsp__Donor_Cover_Amount__c],[npsp__Batch_Number__c],[npsp__ACH_Last_4__c],[Payment_Stage__c],[npsp__ACH_Code__c],[npsp__Elevate_Payment_API_Declined_Reason__c],[npsp__Elevate_Payment_API_Status__c],[Income_Debit_History__c],[Authorisation_Code__c],[Bank_Notes__c],[Card_Payment_History__c],[Card_Type__c],[Contact__c],[Deposit_Bank_Account__c],[Deposit_Date__c],[Deposit_Pay_Slip__c],[Gateway_Customer_Reference__c],[Gift_Aid_Precluded__c],[Name_On_Card__c],[Order_ID__c],[Payment_Reference__c],[Payment_Vendor__c],[Postal_Order__c],[Status__c],[Transaction_ID__c],[Transaction_Source__c],[Transaction_Type__c],[DMS_DonationPayment_ID__c],[Payment_Description__c],[npsp__Elevate_Transaction_Fee__c],[npsp__Gateway_Transaction_Fee__c],[npsp__Total_Transaction_Fees__c],[Reason_for_Refund__c],[Amount_Decimal__c],[AUDDIS_Ref__c],[Card_Details__c],[Payment_Status__c],[Amount__c],[Payment__c],[Payout_Id__c],[Exchange_Rate__c],[Agency_Fees__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object],

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

    FROM [raw].[salesforce_payment]

    WHERE [Id] IS NOT NULL
)

SELECT
    [Id],[IsDeleted],[Name],[CurrencyIsoCode],[RecordTypeId],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastViewedDate],[LastReferencedDate],[npe01__Opportunity__c],[npe01__Check_Reference_Number__c],[npe01__Custom_Payment_Field__c],[npe01__Paid__c],[npe01__Payment_Amount__c],[npe01__Payment_Date__c],[npe01__Payment_Method__c],[npe01__Scheduled_Date__c],[npe01__Written_Off__c],[npsp__Payment_Acknowledged_Date__c],[npsp__Payment_Acknowledgment_Status__c],[npsp__Authorized_Date__c],[npsp__Authorized_UTC_Timestamp__c],[npsp__Card_Expiration_Month__c],[npsp__Card_Expiration_Year__c],[npsp__Card_Last_4__c],[npsp__Card_Network__c],[npsp__Elevate_Original_Payment_ID__c],[npsp__Elevate_Payment_Created_Date__c],[npsp__Elevate_Payment_Created_UTC_Timestamp__c],[npsp__Elevate_Payment_ID__c],[npsp__Gateway_ID__c],[npsp__Gateway_Payment_ID__c],[npsp__Origin_ID__c],[npsp__Origin_Name__c],[npsp__Origin_Type__c],[npsp__Type__c],[npsp__Donor_Cover_Amount__c],[npsp__Batch_Number__c],[npsp__ACH_Last_4__c],[Payment_Stage__c],[npsp__ACH_Code__c],[npsp__Elevate_Payment_API_Declined_Reason__c],[npsp__Elevate_Payment_API_Status__c],[Income_Debit_History__c],[Authorisation_Code__c],[Bank_Notes__c],[Card_Payment_History__c],[Card_Type__c],[Contact__c],[Deposit_Bank_Account__c],[Deposit_Date__c],[Deposit_Pay_Slip__c],[Gateway_Customer_Reference__c],[Gift_Aid_Precluded__c],[Name_On_Card__c],[Order_ID__c],[Payment_Reference__c],[Payment_Vendor__c],[Postal_Order__c],[Status__c],[Transaction_ID__c],[Transaction_Source__c],[Transaction_Type__c],[DMS_DonationPayment_ID__c],[Payment_Description__c],[npsp__Elevate_Transaction_Fee__c],[npsp__Gateway_Transaction_Fee__c],[npsp__Total_Transaction_Fees__c],[Reason_for_Refund__c],[Amount_Decimal__c],[AUDDIS_Ref__c],[Card_Details__c],[Payment_Status__c],[Amount__c],[Payment__c],[Payout_Id__c],[Exchange_Rate__c],[Agency_Fees__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object]

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
