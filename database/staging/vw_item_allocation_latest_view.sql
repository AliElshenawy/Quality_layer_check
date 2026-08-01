/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   VIEW [staging].[vw_item_allocation_latest]
AS

WITH ranked_source AS
(
    SELECT
        [Id],[OwnerId],[IsDeleted],[Name],[CurrencyIsoCode],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[npsp__Amount__c],[npsp__Campaign__c],[npsp__General_Accounting_Unit__c],[npsp__Opportunity__c],[npsp__Percent__c],[npsp__Recurring_Donation__c],[npsp__Payment__c],[Orphan__c],[Stage__c],[Check_Paid_Status__c],[DMS_Donation_Line_Item_ID__c],[Receipt_Note__c],[Stipulation_Type__c],[Quantity__c],[GAU_Name__c],[Date_of_Birth__c],[Gift_Aid_Eligible_Allocation__c],[Name__c],[Special_Instruction_Index__c],[Include_In_General_Receipt__c],[GAU_Name_for_Conga__c],[Is_Olive_Tree__c],[Donor_ID_Item_Code__c],[Item_Product_Type__c],[Donation_Item_Code__c],[Skip_Process_Automation__c],[Country__c],[Programme_Category__c],[Close_Date__c],[Is_Source_Donation_Allocation__c],[Orphan_Id__c],[Orphan_Account_Name__c],[Orphan_DMS_ID__c],[Opportunity_ID__c],[Instruction__c],[Parent_Allocation__c],[Allocation_Count__c],[Notes__c],[Type__c],[Recurring_Donation_Id_Donation__c],[Amount_Currency_Based__c],[Parent_Amount__c],[Primary_Campaign__c],[Donation_Regional_Office_Code__c],[Campaign_Department__c],[Donor_Email__c],[Olive_Tree_Certificate_Email__c],[Plaque_Name_For_Conga__c],[Donor_ID__c],[Send_Email_Olive_Tree_Certificate_To_AR__c],[Deduction__c],[RD_Status_And_Period__c],[Donation_Type__c],[Fund_Allocation__c],[Per_Unit_Price__c],[Amount_after_deduction__c],[Deduction_Amount__c],[is_closed_date_after_opening_balance__c],[is_instruction_created_this_year__c],[Deduction_Amt_Field_Office__c],[Deduction_Amt_Fundraising__c],[Deduction_Amt_Gen_Admin__c],[Deduction_Amt_Reserves__c],[Deduction_Amt_UK_Programmes__c],[Deduction_Amt_Zakat__c],[CampaignId__c],[Parent_CurrencyIsoCode__c],[Amount_Parent_Currency__c],[Amount__c],[Exchange_Rate__c],[Is_Donation_this_year__c],[Is_Pledge_Instruction_this_year__c],[Deduction_Amount_Formula__c],[Fund_Transfer_Schedule__c],[Casesafe_Item_Allocation_Id__c],[Sponsorship__c],[Ringfenced_Funds_Ref__c],[Nominal_Credit_Debit__c],[Preferred_Country__c],[Fund_Re_Allocation_Amount_Formula__c],[Price_Book__c],[Beneficiaries_Household__c],[Beneficiaries_People__c],[Data_Identifier_GUID__c],[ECardId__c],[ECardUrl__c],[ECard_Name__c],[Amount_Payout_Currency__c],[Exchange_Rate_GBP__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object],

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

    FROM [raw].[salesforce_item_allocation]

    WHERE [Id] IS NOT NULL
)

SELECT
    [Id],[OwnerId],[IsDeleted],[Name],[CurrencyIsoCode],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[npsp__Amount__c],[npsp__Campaign__c],[npsp__General_Accounting_Unit__c],[npsp__Opportunity__c],[npsp__Percent__c],[npsp__Recurring_Donation__c],[npsp__Payment__c],[Orphan__c],[Stage__c],[Check_Paid_Status__c],[DMS_Donation_Line_Item_ID__c],[Receipt_Note__c],[Stipulation_Type__c],[Quantity__c],[GAU_Name__c],[Date_of_Birth__c],[Gift_Aid_Eligible_Allocation__c],[Name__c],[Special_Instruction_Index__c],[Include_In_General_Receipt__c],[GAU_Name_for_Conga__c],[Is_Olive_Tree__c],[Donor_ID_Item_Code__c],[Item_Product_Type__c],[Donation_Item_Code__c],[Skip_Process_Automation__c],[Country__c],[Programme_Category__c],[Close_Date__c],[Is_Source_Donation_Allocation__c],[Orphan_Id__c],[Orphan_Account_Name__c],[Orphan_DMS_ID__c],[Opportunity_ID__c],[Instruction__c],[Parent_Allocation__c],[Allocation_Count__c],[Notes__c],[Type__c],[Recurring_Donation_Id_Donation__c],[Amount_Currency_Based__c],[Parent_Amount__c],[Primary_Campaign__c],[Donation_Regional_Office_Code__c],[Campaign_Department__c],[Donor_Email__c],[Olive_Tree_Certificate_Email__c],[Plaque_Name_For_Conga__c],[Donor_ID__c],[Send_Email_Olive_Tree_Certificate_To_AR__c],[Deduction__c],[RD_Status_And_Period__c],[Donation_Type__c],[Fund_Allocation__c],[Per_Unit_Price__c],[Amount_after_deduction__c],[Deduction_Amount__c],[is_closed_date_after_opening_balance__c],[is_instruction_created_this_year__c],[Deduction_Amt_Field_Office__c],[Deduction_Amt_Fundraising__c],[Deduction_Amt_Gen_Admin__c],[Deduction_Amt_Reserves__c],[Deduction_Amt_UK_Programmes__c],[Deduction_Amt_Zakat__c],[CampaignId__c],[Parent_CurrencyIsoCode__c],[Amount_Parent_Currency__c],[Amount__c],[Exchange_Rate__c],[Is_Donation_this_year__c],[Is_Pledge_Instruction_this_year__c],[Deduction_Amount_Formula__c],[Fund_Transfer_Schedule__c],[Casesafe_Item_Allocation_Id__c],[Sponsorship__c],[Ringfenced_Funds_Ref__c],[Nominal_Credit_Debit__c],[Preferred_Country__c],[Fund_Re_Allocation_Amount_Formula__c],[Price_Book__c],[Beneficiaries_Household__c],[Beneficiaries_People__c],[Data_Identifier_GUID__c],[ECardId__c],[ECardUrl__c],[ECard_Name__c],[Amount_Payout_Currency__c],[Exchange_Rate_GBP__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object]

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
