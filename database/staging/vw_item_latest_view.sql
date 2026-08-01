/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   VIEW [staging].[vw_item_latest]
AS

WITH ranked_source AS
(
    SELECT
        [Id],[OwnerId],[IsDeleted],[Name],[CurrencyIsoCode],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[LastViewedDate],[LastReferencedDate],[npsp__Active__c],[npsp__Average_Allocation__c],[npsp__Description__c],[npsp__First_Allocation_Date__c],[npsp__Largest_Allocation__c],[npsp__Last_Allocation_Date__c],[npsp__Number_of_Allocations_Last_N_Days__c],[npsp__Number_of_Allocations_Last_Year__c],[npsp__Number_of_Allocations_This_Year__c],[npsp__Number_of_Allocations_Two_Years_Ago__c],[npsp__Smallest_Allocation__c],[npsp__Total_Allocations_Last_N_Days__c],[npsp__Total_Allocations_Last_Year__c],[npsp__Total_Allocations_This_Year__c],[npsp__Total_Allocations_Two_Years_Ago__c],[npsp__Total_Allocations__c],[npsp__Total_Number_of_Allocations__c],[Allow_Recurring__c],[Allow_Single__c],[Allowed_Payment_Types__c],[Country__c],[Donation_Item_Code__c],[Donation_Type__c],[Gift_Aid_Eligible__c],[Product_Type__c],[Casesafe_Item_Id__c],[Include_In_General_Receipt__c],[Allow_Donation_Targets__c],[Deduction_Class__c],[Programme_Category__c],[Special_Message__c],[Stipulation_Temp__c],[Product__c],[HA_Donation_Frequency__c],[Item_Price__c],[Price_Editable__c],[Stipulation__c],[Sponsored_Orphan_Only__c],[Skip_Special_Instruction__c],[Regional_Office_Code__c],[Total_Credit__c],[Total_Funds_Available__c],[Is_Sponsorship_Renewal__c],[Deliverable_Category__c],[Parent_Item__c],[Clone_Item_Id__c],[Available_Funds_Excluding_Active_RDs__c],[Campaign__c],[Exclude_from_Bulk_update__c],[Field_office_admin_percentage__c],[Fundraising_admin_percentage__c],[General_Admin_Percentage__c],[Income_Zakat_Credit__c],[Income_sadaqa_general_charity_credit__c],[Instruction_Non_Zakat__c],[Instruction_Zakat_credit__c],[Non_Zakat_Instruction_Debit__c],[Opening_Balance_Non_Zakat__c],[Opening_Balance_Start_Date__c],[Opening_Balance_Zakat__c],[Price_Book__c],[Reserves_percentage__c],[Sadaqa_reserved_by_CN__c],[UK_programmes_admin__c],[Zakat_Instruction_Debit__c],[Zakat_Percentage__c],[Zakat_allocated_to_projects_debit__c],[Zakat_funds_reserved_by_CN__c],[non_zakat_allocated_to_projects__c],[Fundraising_Deductions_Donations__c],[Fundraising_Deduction_Formula__c],[General_Sadaqa_Admin_Deduction_Donatio__c],[General_Sadaqa_Admin_Deduction_Formula__c],[FO_Non_Zakat_Deductions_Donations__c],[FO_Non_Zakat_Deductions_Formula__c],[Total_Non_Zakat_Credit__c],[Total_Non_Zakat_Debit__c],[Total_Non_Zakat_deductions__c],[Total_Zakat_Credit__c],[Total_Zakat_Debit__c],[Total_funds_available_sadaqa__c],[Total_funds_available_zakat__c],[Total_spendable_Zakat_income__c],[Total_spendable_sadaqa_general_income__c],[HQ_Zakat_Deduction_Donations__c],[Zakat_deduction__c],[FO_Zakat_deduction__c],[Field_Office_admin_deductions__c],[Fundraising_Deduction__c],[HQ_Zakat_deduction__c],[Reserve_deduction__c],[Sadaqa_General_admin_deduction__c],[UK_Programmes__c],[HQ_Zakat_Deduction_Formula__c],[Reserve_Funds_Donations__c],[Reserve_Funds__c],[UK_Programmes_Deduction_Donations__c],[UK_Programmes_Deductions__c],[Last_Batch_Units_SR_CN__c],[Last_SR_CN_Job_Id__c],[Minimum_Quantity__c],[Sub_Type__c],[Non_Zakat_Reserved_Funds_Balance__c],[Zakat_Reserved_Funds_Balance__c],[Unrestricted_Deductions_Donations__c],[Unrestricted_Deductions_Instructions__c],[Unrestricted_Percentage__c],[Unrestricted_Deductions__c],[Implementation_Countries__c],[Zakat_Re_Allocation_Credit__c],[Non_Zakat_Re_Allocation_Credit__c],[Replace_Item__c],[Status__c],[Special_Request__c],[Impact_Note__c],[Outcome_Impact_Note__c],[Has_Certificate__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object],

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

    FROM [raw].[salesforce_item]

    WHERE [Id] IS NOT NULL
)

SELECT
    [Id],[OwnerId],[IsDeleted],[Name],[CurrencyIsoCode],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[LastViewedDate],[LastReferencedDate],[npsp__Active__c],[npsp__Average_Allocation__c],[npsp__Description__c],[npsp__First_Allocation_Date__c],[npsp__Largest_Allocation__c],[npsp__Last_Allocation_Date__c],[npsp__Number_of_Allocations_Last_N_Days__c],[npsp__Number_of_Allocations_Last_Year__c],[npsp__Number_of_Allocations_This_Year__c],[npsp__Number_of_Allocations_Two_Years_Ago__c],[npsp__Smallest_Allocation__c],[npsp__Total_Allocations_Last_N_Days__c],[npsp__Total_Allocations_Last_Year__c],[npsp__Total_Allocations_This_Year__c],[npsp__Total_Allocations_Two_Years_Ago__c],[npsp__Total_Allocations__c],[npsp__Total_Number_of_Allocations__c],[Allow_Recurring__c],[Allow_Single__c],[Allowed_Payment_Types__c],[Country__c],[Donation_Item_Code__c],[Donation_Type__c],[Gift_Aid_Eligible__c],[Product_Type__c],[Casesafe_Item_Id__c],[Include_In_General_Receipt__c],[Allow_Donation_Targets__c],[Deduction_Class__c],[Programme_Category__c],[Special_Message__c],[Stipulation_Temp__c],[Product__c],[HA_Donation_Frequency__c],[Item_Price__c],[Price_Editable__c],[Stipulation__c],[Sponsored_Orphan_Only__c],[Skip_Special_Instruction__c],[Regional_Office_Code__c],[Total_Credit__c],[Total_Funds_Available__c],[Is_Sponsorship_Renewal__c],[Deliverable_Category__c],[Parent_Item__c],[Clone_Item_Id__c],[Available_Funds_Excluding_Active_RDs__c],[Campaign__c],[Exclude_from_Bulk_update__c],[Field_office_admin_percentage__c],[Fundraising_admin_percentage__c],[General_Admin_Percentage__c],[Income_Zakat_Credit__c],[Income_sadaqa_general_charity_credit__c],[Instruction_Non_Zakat__c],[Instruction_Zakat_credit__c],[Non_Zakat_Instruction_Debit__c],[Opening_Balance_Non_Zakat__c],[Opening_Balance_Start_Date__c],[Opening_Balance_Zakat__c],[Price_Book__c],[Reserves_percentage__c],[Sadaqa_reserved_by_CN__c],[UK_programmes_admin__c],[Zakat_Instruction_Debit__c],[Zakat_Percentage__c],[Zakat_allocated_to_projects_debit__c],[Zakat_funds_reserved_by_CN__c],[non_zakat_allocated_to_projects__c],[Fundraising_Deductions_Donations__c],[Fundraising_Deduction_Formula__c],[General_Sadaqa_Admin_Deduction_Donatio__c],[General_Sadaqa_Admin_Deduction_Formula__c],[FO_Non_Zakat_Deductions_Donations__c],[FO_Non_Zakat_Deductions_Formula__c],[Total_Non_Zakat_Credit__c],[Total_Non_Zakat_Debit__c],[Total_Non_Zakat_deductions__c],[Total_Zakat_Credit__c],[Total_Zakat_Debit__c],[Total_funds_available_sadaqa__c],[Total_funds_available_zakat__c],[Total_spendable_Zakat_income__c],[Total_spendable_sadaqa_general_income__c],[HQ_Zakat_Deduction_Donations__c],[Zakat_deduction__c],[FO_Zakat_deduction__c],[Field_Office_admin_deductions__c],[Fundraising_Deduction__c],[HQ_Zakat_deduction__c],[Reserve_deduction__c],[Sadaqa_General_admin_deduction__c],[UK_Programmes__c],[HQ_Zakat_Deduction_Formula__c],[Reserve_Funds_Donations__c],[Reserve_Funds__c],[UK_Programmes_Deduction_Donations__c],[UK_Programmes_Deductions__c],[Last_Batch_Units_SR_CN__c],[Last_SR_CN_Job_Id__c],[Minimum_Quantity__c],[Sub_Type__c],[Non_Zakat_Reserved_Funds_Balance__c],[Zakat_Reserved_Funds_Balance__c],[Unrestricted_Deductions_Donations__c],[Unrestricted_Deductions_Instructions__c],[Unrestricted_Percentage__c],[Unrestricted_Deductions__c],[Implementation_Countries__c],[Zakat_Re_Allocation_Credit__c],[Non_Zakat_Re_Allocation_Credit__c],[Replace_Item__c],[Status__c],[Special_Request__c],[Impact_Note__c],[Outcome_Impact_Note__c],[Has_Certificate__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object]

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
