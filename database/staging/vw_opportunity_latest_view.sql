/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   VIEW [staging].[vw_opportunity_latest]
AS

WITH ranked_source AS
(
    SELECT
        [Id],[IsDeleted],[AccountId],[RecordTypeId],[IsPrivate],[Name],[Description],[StageName],[Amount],[Probability],[ExpectedRevenue],[TotalOpportunityQuantity],[CloseDate],[Type],[NextStep],[LeadSource],[IsClosed],[IsWon],[ForecastCategory],[ForecastCategoryName],[CurrencyIsoCode],[CampaignId],[HasOpportunityLineItem],[Pricebook2Id],[OwnerId],[CreatedDate],[AgeInDays],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[LastActivityInDays],[PushCount],[LastStageChangeDate],[LastStageChangeInDays],[FiscalQuarter],[FiscalYear],[Fiscal],[ContactId],[LastViewedDate],[LastReferencedDate],[PartnerAccountId],[SyncedQuoteId],[ContractId],[HasOpenActivity],[HasOverdueTask],[LastAmountChangedHistoryId],[LastCloseDateChangedHistoryId],[IsPriorityRecord],[Budget_Confirmed__c],[Discovery_Completed__c],[Is_Processed__c],[npe01__Amount_Outstanding__c],[Lost_Reason__c],[npe01__Contact_Id_for_Role__c],[npe01__Do_Not_Automatically_Create_Payment__c],[npe01__Is_Opp_From_Individual__c],[npe01__Member_Level__c],[npe01__Membership_End_Date__c],[npe01__Membership_Origin__c],[npe01__Membership_Start_Date__c],[npe01__Amount_Written_Off__c],[npe01__Number_of_Payments__c],[npe01__Payments_Made__c],[npo02__CombinedRollupFieldset__c],[npo02__systemHouseholdContactRoleProcessor__c],[npe03__Recurring_Donation__c],[npsp__Acknowledgment_Date__c],[npsp__Acknowledgment_Status__c],[npsp__Ask_Date__c],[npsp__Batch__c],[npsp__Closed_Lost_Reason__c],[npsp__Fair_Market_Value__c],[npsp__Gift_Strategy__c],[npsp__Grant_Contract_Date__c],[npsp__Grant_Contract_Number__c],[npsp__Grant_Period_End_Date__c],[npsp__Grant_Period_Start_Date__c],[npsp__Grant_Program_Area_s__c],[npsp__Grant_Requirements_Website__c],[npsp__Honoree_Contact__c],[npsp__Honoree_Name__c],[npsp__In_Kind_Description__c],[npsp__In_Kind_Donor_Declared_Value__c],[npsp__In_Kind_Type__c],[npsp__Is_Grant_Renewal__c],[npsp__Matching_Gift_Account__c],[npsp__Matching_Gift_Employer__c],[npsp__Matching_Gift_Status__c],[npsp__Matching_Gift__c],[npsp__Notification_Message__c],[npsp__Notification_Preference__c],[npsp__Notification_Recipient_Contact__c],[npsp__Notification_Recipient_Information__c],[npsp__Notification_Recipient_Name__c],[npsp__Previous_Grant_Opportunity__c],[npsp__Primary_Contact_Campaign_Member_Status__c],[npsp__Primary_Contact__c],[npsp__Qualified_Date__c],[npsp__Recurring_Donation_Installment_Name__c],[npsp__Recurring_Donation_Installment_Number__c],[npsp__Requested_Amount__c],[npsp__Tribute_Type__c],[npsp__Next_Grant_Deadline_Due_Date__c],[Donation_Type__c],[Gift_Aid_Submitted_Value__c],[Gift_Aid_Submitted__c],[Transaction_Id__c],[Medium__c],[npsp__DisableContactRoleAutomation__c],[npsp__CommitmentId__c],[GUID__c],[Is_Recurring__c],[Payment_Details__c],[Recurring_Setup__c],[Source_Opportunity__c],[Card_Payment_Details__c],[npsp__Batch_Number__c],[Gift_Aid_Eligible_Value__c],[IsFirstGift__c],[DonationCode__c],[Donation_Frequency__c],[Gift_Aid_Declaration__c],[Number_of_Installments__c],[Payment_Schedule__c],[Recurring_Type__c],[Basket_Collection_Id__c],[Effective_Date__c],[Gift_Aid_Declaration_Status__c],[Gift_Aid_Eligible_Value_Actuals__c],[fileforcem1__Sharepoint_Folder_Id__c],[Website_Code__c],[Precluded_Gift_Aid_Value__c],[Total_Refund__c],[Donor_Name__c],[Current_Year_Value__c],[Gift_Aid_Eligible_Status__c],[Casesafe_Donation_ID__c],[Source__c],[Donation_Amount_Excluding_SR__c],[Source_Donation_Transaction_ID__c],[Donation_Amount_Olive_Trees__c],[Payment_Method__c],[Estimate_Gift_Aid_Value__c],[Agency_Fees__c],[Bank_Reference__c],[Bank__c],[Donor_ID_Item_Code__c],[Duplicate_Key_Agencies__c],[Duplicate_Key_Bank_Organizations__c],[Duplicate_Key_Bank__c],[Fundraising_Page_URL__c],[Net_Donation_Amount__c],[Item_Code__c],[Skip_Process_Automation__c],[Stipulation_Type__c],[Type__c],[Donation_created_time__c],[EMIAmount__c],[Department__c],[Row_Index__c],[Transaction_Source__c],[Fundraising_Team__c],[Fundraiser__c],[Odd_Night__c],[X27th_Night__c],[Mailing_Street__c],[End_Date__c],[Contact_Email__c],[Contact_Mobile_Number__c],[Donor_Email__c],[Donor_ID__c],[Created_Date_Close_Date__c],[Recurring_Payment_Method__c],[Mailing_Address__c],[Mailing_City__c],[Mailing_Postcode__c],[Total_Donation_Amount__c],[Do_Not_Post__c],[Regional_Office_Code__c],[Check_for_regional_Code_Website_Code__c],[Contact_Record_Type__c],[Campaign_Record_Type__c],[Contact_Mailing_Country__c],[Gift_Aid_Value__c],[Basket_Status__c],[Gift_Aid_Claim_Value__c],[Difference_Gift_Aid_Value__c],[Donor_FirstName__c],[Donor_LastName__c],[Donor_Country__c],[Donation_Payment_Method__c],[Donor_National_ID__c],[Basket__c],[Total_Amount_Expected__c],[Created_Datetime__c],[First_Payment_Date__c],[PaymentIntentId__c],[Payment_Client_Secret__c],[Account_Holder_Name__c],[Account_Number__c],[Donation__c],[Finance_Approver_User__c],[Refund_Approval__c],[Refund_Reason__c],[Sort_Code__c],[Campaign_Id__c],[Recurring_Amount_MisMatch_Opp_Amount__c],[Donor_Do_Not_Call__c],[RD_Number_of_Paid_instalments__c],[npsp__Honoree_Information__c],[npsp__Notification_Recipient_Email__c],[npsp__Tribute_Notification_Date__c],[npsp__Tribute_Notification_Status__c],[FR_statement_sent__c],[Language__c],[Email_Language__c],[Close_Date_Region_Format__c],[Payment_Verification_Url__c],[Email_Opt_In__c],[Locked_For_Audit__c],[ECardId__c],[ECardUrl__c],[ECard_Email__c],[Non_Taxable_Amount__c],[Gift_Aid_Amount__c],[Gift_Aid_Payment_Date__c],[Gift_Aid_Payment_Fee__c],[Gift_Aid_Payment_Identifier__c],[Payment_Date__c],[Payment_Identifier__c],[My_Account_Donation__c],[Donation_Count__c],[Field_Office_Partner__c],[MailingStreet_40__c],[Opportunity_Age__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object],

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

    FROM [raw].[salesforce_opportunity]

    WHERE [Id] IS NOT NULL
)

SELECT
    [Id],[IsDeleted],[AccountId],[RecordTypeId],[IsPrivate],[Name],[Description],[StageName],[Amount],[Probability],[ExpectedRevenue],[TotalOpportunityQuantity],[CloseDate],[Type],[NextStep],[LeadSource],[IsClosed],[IsWon],[ForecastCategory],[ForecastCategoryName],[CurrencyIsoCode],[CampaignId],[HasOpportunityLineItem],[Pricebook2Id],[OwnerId],[CreatedDate],[AgeInDays],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[LastActivityInDays],[PushCount],[LastStageChangeDate],[LastStageChangeInDays],[FiscalQuarter],[FiscalYear],[Fiscal],[ContactId],[LastViewedDate],[LastReferencedDate],[PartnerAccountId],[SyncedQuoteId],[ContractId],[HasOpenActivity],[HasOverdueTask],[LastAmountChangedHistoryId],[LastCloseDateChangedHistoryId],[IsPriorityRecord],[Budget_Confirmed__c],[Discovery_Completed__c],[Is_Processed__c],[npe01__Amount_Outstanding__c],[Lost_Reason__c],[npe01__Contact_Id_for_Role__c],[npe01__Do_Not_Automatically_Create_Payment__c],[npe01__Is_Opp_From_Individual__c],[npe01__Member_Level__c],[npe01__Membership_End_Date__c],[npe01__Membership_Origin__c],[npe01__Membership_Start_Date__c],[npe01__Amount_Written_Off__c],[npe01__Number_of_Payments__c],[npe01__Payments_Made__c],[npo02__CombinedRollupFieldset__c],[npo02__systemHouseholdContactRoleProcessor__c],[npe03__Recurring_Donation__c],[npsp__Acknowledgment_Date__c],[npsp__Acknowledgment_Status__c],[npsp__Ask_Date__c],[npsp__Batch__c],[npsp__Closed_Lost_Reason__c],[npsp__Fair_Market_Value__c],[npsp__Gift_Strategy__c],[npsp__Grant_Contract_Date__c],[npsp__Grant_Contract_Number__c],[npsp__Grant_Period_End_Date__c],[npsp__Grant_Period_Start_Date__c],[npsp__Grant_Program_Area_s__c],[npsp__Grant_Requirements_Website__c],[npsp__Honoree_Contact__c],[npsp__Honoree_Name__c],[npsp__In_Kind_Description__c],[npsp__In_Kind_Donor_Declared_Value__c],[npsp__In_Kind_Type__c],[npsp__Is_Grant_Renewal__c],[npsp__Matching_Gift_Account__c],[npsp__Matching_Gift_Employer__c],[npsp__Matching_Gift_Status__c],[npsp__Matching_Gift__c],[npsp__Notification_Message__c],[npsp__Notification_Preference__c],[npsp__Notification_Recipient_Contact__c],[npsp__Notification_Recipient_Information__c],[npsp__Notification_Recipient_Name__c],[npsp__Previous_Grant_Opportunity__c],[npsp__Primary_Contact_Campaign_Member_Status__c],[npsp__Primary_Contact__c],[npsp__Qualified_Date__c],[npsp__Recurring_Donation_Installment_Name__c],[npsp__Recurring_Donation_Installment_Number__c],[npsp__Requested_Amount__c],[npsp__Tribute_Type__c],[npsp__Next_Grant_Deadline_Due_Date__c],[Donation_Type__c],[Gift_Aid_Submitted_Value__c],[Gift_Aid_Submitted__c],[Transaction_Id__c],[Medium__c],[npsp__DisableContactRoleAutomation__c],[npsp__CommitmentId__c],[GUID__c],[Is_Recurring__c],[Payment_Details__c],[Recurring_Setup__c],[Source_Opportunity__c],[Card_Payment_Details__c],[npsp__Batch_Number__c],[Gift_Aid_Eligible_Value__c],[IsFirstGift__c],[DonationCode__c],[Donation_Frequency__c],[Gift_Aid_Declaration__c],[Number_of_Installments__c],[Payment_Schedule__c],[Recurring_Type__c],[Basket_Collection_Id__c],[Effective_Date__c],[Gift_Aid_Declaration_Status__c],[Gift_Aid_Eligible_Value_Actuals__c],[fileforcem1__Sharepoint_Folder_Id__c],[Website_Code__c],[Precluded_Gift_Aid_Value__c],[Total_Refund__c],[Donor_Name__c],[Current_Year_Value__c],[Gift_Aid_Eligible_Status__c],[Casesafe_Donation_ID__c],[Source__c],[Donation_Amount_Excluding_SR__c],[Source_Donation_Transaction_ID__c],[Donation_Amount_Olive_Trees__c],[Payment_Method__c],[Estimate_Gift_Aid_Value__c],[Agency_Fees__c],[Bank_Reference__c],[Bank__c],[Donor_ID_Item_Code__c],[Duplicate_Key_Agencies__c],[Duplicate_Key_Bank_Organizations__c],[Duplicate_Key_Bank__c],[Fundraising_Page_URL__c],[Net_Donation_Amount__c],[Item_Code__c],[Skip_Process_Automation__c],[Stipulation_Type__c],[Type__c],[Donation_created_time__c],[EMIAmount__c],[Department__c],[Row_Index__c],[Transaction_Source__c],[Fundraising_Team__c],[Fundraiser__c],[Odd_Night__c],[X27th_Night__c],[Mailing_Street__c],[End_Date__c],[Contact_Email__c],[Contact_Mobile_Number__c],[Donor_Email__c],[Donor_ID__c],[Created_Date_Close_Date__c],[Recurring_Payment_Method__c],[Mailing_Address__c],[Mailing_City__c],[Mailing_Postcode__c],[Total_Donation_Amount__c],[Do_Not_Post__c],[Regional_Office_Code__c],[Check_for_regional_Code_Website_Code__c],[Contact_Record_Type__c],[Campaign_Record_Type__c],[Contact_Mailing_Country__c],[Gift_Aid_Value__c],[Basket_Status__c],[Gift_Aid_Claim_Value__c],[Difference_Gift_Aid_Value__c],[Donor_FirstName__c],[Donor_LastName__c],[Donor_Country__c],[Donation_Payment_Method__c],[Donor_National_ID__c],[Basket__c],[Total_Amount_Expected__c],[Created_Datetime__c],[First_Payment_Date__c],[PaymentIntentId__c],[Payment_Client_Secret__c],[Account_Holder_Name__c],[Account_Number__c],[Donation__c],[Finance_Approver_User__c],[Refund_Approval__c],[Refund_Reason__c],[Sort_Code__c],[Campaign_Id__c],[Recurring_Amount_MisMatch_Opp_Amount__c],[Donor_Do_Not_Call__c],[RD_Number_of_Paid_instalments__c],[npsp__Honoree_Information__c],[npsp__Notification_Recipient_Email__c],[npsp__Tribute_Notification_Date__c],[npsp__Tribute_Notification_Status__c],[FR_statement_sent__c],[Language__c],[Email_Language__c],[Close_Date_Region_Format__c],[Payment_Verification_Url__c],[Email_Opt_In__c],[Locked_For_Audit__c],[ECardId__c],[ECardUrl__c],[ECard_Email__c],[Non_Taxable_Amount__c],[Gift_Aid_Amount__c],[Gift_Aid_Payment_Date__c],[Gift_Aid_Payment_Fee__c],[Gift_Aid_Payment_Identifier__c],[Payment_Date__c],[Payment_Identifier__c],[My_Account_Donation__c],[Donation_Count__c],[Field_Office_Partner__c],[MailingStreet_40__c],[Opportunity_Age__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object]

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
