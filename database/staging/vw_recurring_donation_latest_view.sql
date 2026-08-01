/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   VIEW [staging].[vw_recurring_donation_latest]
AS

WITH ranked_source AS
(
    SELECT
        [Id],[OwnerId],[IsDeleted],[Name],[CurrencyIsoCode],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[LastViewedDate],[LastReferencedDate],[npe03__Amount__c],[npe03__Contact__c],[npe03__Date_Established__c],[npe03__Donor_Name__c],[npe03__Installment_Amount__c],[npe03__Installment_Period__c],[npe03__Installments__c],[npe03__Last_Payment_Date__c],[npe03__Next_Payment_Date__c],[npe03__Open_Ended_Status__c],[npe03__Organization__c],[npe03__Paid_Amount__c],[npe03__Recurring_Donation_Campaign__c],[npe03__Schedule_Type__c],[npe03__Total_Paid_Installments__c],[npe03__Total__c],[npsp__Always_Use_Last_Day_Of_Month__c],[npsp__Day_of_Month__c],[npsp__CurrentYearValue__c],[npsp__NextYearValue__c],[npsp__CommitmentId__c],[npsp__EndDate__c],[Card_Payment_Detail__c],[npsp__InstallmentFrequency__c],[npsp__PaymentMethod__c],[npsp__RecurringType__c],[npsp__StartDate__c],[npsp__Status__c],[npsp__ClosedReason__c],[Direct_Debit_Detail__c],[Donation_Type__c],[GAU_Allocation__c],[Opportunity__c],[npsp__DisableFirstInstallment__c],[npsp__CardExpirationMonth__c],[npsp__CardExpirationYear__c],[npsp__CardLast4__c],[npsp__LastElevateEventPlayed__c],[Source_Donation_Transaction_Id__c],[npsp__ACH_Last_4__c],[npsp__LastElevateVersionPlayed__c],[Medium__c],[Regional_Code__c],[Source__c],[Department__c],[Website_Code__c],[Regional_Office_Code__c],[npsp__ChangeType__c],[DD_Hold_Reason__c],[Account_mismatch_temp__c],[Campaign_Department__c],[Basket__c],[External_Id__c],[Payment_Method_Id__c],[Total_Amount_Percentage_Paid__c],[Total_Donation_Amount__c],[Bank_Name__c],[Routing_Number__c],[Date_Established_Region_Format__c],[Start_Date_Region_Format__c],[Card_Expiry_Date__c],[SR_Units_Allocation__c],[Total_Amount_Available_for_Instruction__c],[Total_Amount_Instructed__c],[Total_Amount_for_1_Unit_of_each_GAU__c],[Allow_Instruction__c],[Amount_Available_for_SR_Instruction__c],[Enough_funds_to_instruct__c],[Casesafe_Recurring_Donation_Id__c],[Payment_Schedule__c],[Total_Paid_Amount_excl__c],[Last_Year_Value__c],[Number_of_Unpaid_Installments__c],[Email_Acknowledgement__c],[Email_Acknowledgement_Date__c],[Number_of_Failed_Payments__c],[Total_Number_of_Failed_Payments__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object],

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

    FROM [raw].[salesforce_recurring_donation]

    WHERE [Id] IS NOT NULL
)

SELECT
    [Id],[OwnerId],[IsDeleted],[Name],[CurrencyIsoCode],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[LastViewedDate],[LastReferencedDate],[npe03__Amount__c],[npe03__Contact__c],[npe03__Date_Established__c],[npe03__Donor_Name__c],[npe03__Installment_Amount__c],[npe03__Installment_Period__c],[npe03__Installments__c],[npe03__Last_Payment_Date__c],[npe03__Next_Payment_Date__c],[npe03__Open_Ended_Status__c],[npe03__Organization__c],[npe03__Paid_Amount__c],[npe03__Recurring_Donation_Campaign__c],[npe03__Schedule_Type__c],[npe03__Total_Paid_Installments__c],[npe03__Total__c],[npsp__Always_Use_Last_Day_Of_Month__c],[npsp__Day_of_Month__c],[npsp__CurrentYearValue__c],[npsp__NextYearValue__c],[npsp__CommitmentId__c],[npsp__EndDate__c],[Card_Payment_Detail__c],[npsp__InstallmentFrequency__c],[npsp__PaymentMethod__c],[npsp__RecurringType__c],[npsp__StartDate__c],[npsp__Status__c],[npsp__ClosedReason__c],[Direct_Debit_Detail__c],[Donation_Type__c],[GAU_Allocation__c],[Opportunity__c],[npsp__DisableFirstInstallment__c],[npsp__CardExpirationMonth__c],[npsp__CardExpirationYear__c],[npsp__CardLast4__c],[npsp__LastElevateEventPlayed__c],[Source_Donation_Transaction_Id__c],[npsp__ACH_Last_4__c],[npsp__LastElevateVersionPlayed__c],[Medium__c],[Regional_Code__c],[Source__c],[Department__c],[Website_Code__c],[Regional_Office_Code__c],[npsp__ChangeType__c],[DD_Hold_Reason__c],[Account_mismatch_temp__c],[Campaign_Department__c],[Basket__c],[External_Id__c],[Payment_Method_Id__c],[Total_Amount_Percentage_Paid__c],[Total_Donation_Amount__c],[Bank_Name__c],[Routing_Number__c],[Date_Established_Region_Format__c],[Start_Date_Region_Format__c],[Card_Expiry_Date__c],[SR_Units_Allocation__c],[Total_Amount_Available_for_Instruction__c],[Total_Amount_Instructed__c],[Total_Amount_for_1_Unit_of_each_GAU__c],[Allow_Instruction__c],[Amount_Available_for_SR_Instruction__c],[Enough_funds_to_instruct__c],[Casesafe_Recurring_Donation_Id__c],[Payment_Schedule__c],[Total_Paid_Amount_excl__c],[Last_Year_Value__c],[Number_of_Unpaid_Installments__c],[Email_Acknowledgement__c],[Email_Acknowledgement_Date__c],[Number_of_Failed_Payments__c],[Total_Number_of_Failed_Payments__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object]

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
