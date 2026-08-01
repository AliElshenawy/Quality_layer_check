/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   VIEW [staging].[vw_campaign_latest]
AS

WITH ranked_source AS
(
    SELECT
        [Id],[IsDeleted],[Name],[ParentId],[Type],[RecordTypeId],[Status],[StartDate],[EndDate],[CurrencyIsoCode],[ExpectedRevenue],[BudgetedCost],[ActualCost],[ExpectedResponse],[NumberSent],[IsActive],[Description],[CampaignImageId],[NumberOfLeads],[NumberOfConvertedLeads],[NumberOfContacts],[NumberOfResponses],[NumberOfOpportunities],[NumberOfWonOpportunities],[AmountAllOpportunities],[AmountWonOpportunities],[HierarchyNumberOfLeads],[HierarchyNumberOfConvertedLeads],[HierarchyNumberOfContacts],[HierarchyNumberOfResponses],[HierarchyNumberOfOpportunities],[HierarchyNumberOfWonOpportunities],[HierarchyAmountAllOpportunities],[HierarchyAmountWonOpportunities],[HierarchyNumberSent],[HierarchyExpectedRevenue],[HierarchyBudgetedCost],[HierarchyActualCost],[OwnerId],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[LastViewedDate],[LastReferencedDate],[CampaignMemberRecordTypeId],[GW_Volunteers__Volunteer_Website_Time_Zone__c],[GW_Volunteers__Number_of_Volunteers__c],[GW_Volunteers__Volunteer_Completed_Hours__c],[GW_Volunteers__Volunteer_Jobs__c],[GW_Volunteers__Volunteer_Shifts__c],[GW_Volunteers__Volunteers_Still_Needed__c],[Money_Saved__c],[Campaign_Title__c],[Notes__c],[Unique_Name__c],[Source__c],[Department__c],[Region__c],[Year__c],[City_Code__c],[City__c],[FR_Unique_Number__c],[Sub_Region__c],[Fundraiser_Code__c],[Event_Type_Code__c],[Event_Acronym__c],[Event_Location_Code__c],[Created_Date_Time__c],[Casesafe_Campaign_ID__c],[Regional_Office_Code__c],[Campaign_Location__c],[Code__c],[Long_Name_Field__c],[DMS_Campaign_ID__c],[Max_Call_Retry__c],[Response_Percentage__c],[Retry_Intervals__c],[Parent_Campaign_CasesafeID__c],[Email_Notification__c],[Achieved_Target__c],[Description_detail__c],[Donor__c],[Fundraiser_Person__c],[Number_of_attendees__c],[Pledged_Amount__c],[Remaining_Pledge_Amount__c],[Remaining_Target__c],[Grandparent_Campaign_Casesafe_Id__c],[Dialer_Queue__c],[Country__c],[Fundraiser__c],[Fundraising_page_url__c],[Fundraising_Objective_Purpose__c],[Fundraising_Team_Code__c],[Speaker_Artist__c],[Call_List_Clearing_In_Progress__c],[Available_Amount__c],[Total_Funds_Allocated__c],[Upload_Transaction_ID__c],[Item__c],[Stipulation__c],[Donation_Value__c],[Patient__c],[Donation_Raised__c],[Funds_Allocated__c],[Total_FundsAllocated__c],[Email_Acknowledgement_Status__c],[FundraisingCode__c],[Priority__c],[Reviewed__c],[Campaign_Count__c],[Page_Type__c],[Arrival_Time__c],[External_Id__c],[Funds_Allocated_In_Campaign_Non_Pledge__c],[Funds_Allocated_In_Hierarchy_Instruction__c],[Funds_Allocated_In_Hierarchy_Non_Pledge__c],[Funds_Allocated_In_Hierarchy_Outside_CRM__c],[Income_Stream__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object],

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

    FROM [raw].[salesforce_campaign]

    WHERE [Id] IS NOT NULL
)

SELECT
    [Id],[IsDeleted],[Name],[ParentId],[Type],[RecordTypeId],[Status],[StartDate],[EndDate],[CurrencyIsoCode],[ExpectedRevenue],[BudgetedCost],[ActualCost],[ExpectedResponse],[NumberSent],[IsActive],[Description],[CampaignImageId],[NumberOfLeads],[NumberOfConvertedLeads],[NumberOfContacts],[NumberOfResponses],[NumberOfOpportunities],[NumberOfWonOpportunities],[AmountAllOpportunities],[AmountWonOpportunities],[HierarchyNumberOfLeads],[HierarchyNumberOfConvertedLeads],[HierarchyNumberOfContacts],[HierarchyNumberOfResponses],[HierarchyNumberOfOpportunities],[HierarchyNumberOfWonOpportunities],[HierarchyAmountAllOpportunities],[HierarchyAmountWonOpportunities],[HierarchyNumberSent],[HierarchyExpectedRevenue],[HierarchyBudgetedCost],[HierarchyActualCost],[OwnerId],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[LastViewedDate],[LastReferencedDate],[CampaignMemberRecordTypeId],[GW_Volunteers__Volunteer_Website_Time_Zone__c],[GW_Volunteers__Number_of_Volunteers__c],[GW_Volunteers__Volunteer_Completed_Hours__c],[GW_Volunteers__Volunteer_Jobs__c],[GW_Volunteers__Volunteer_Shifts__c],[GW_Volunteers__Volunteers_Still_Needed__c],[Money_Saved__c],[Campaign_Title__c],[Notes__c],[Unique_Name__c],[Source__c],[Department__c],[Region__c],[Year__c],[City_Code__c],[City__c],[FR_Unique_Number__c],[Sub_Region__c],[Fundraiser_Code__c],[Event_Type_Code__c],[Event_Acronym__c],[Event_Location_Code__c],[Created_Date_Time__c],[Casesafe_Campaign_ID__c],[Regional_Office_Code__c],[Campaign_Location__c],[Code__c],[Long_Name_Field__c],[DMS_Campaign_ID__c],[Max_Call_Retry__c],[Response_Percentage__c],[Retry_Intervals__c],[Parent_Campaign_CasesafeID__c],[Email_Notification__c],[Achieved_Target__c],[Description_detail__c],[Donor__c],[Fundraiser_Person__c],[Number_of_attendees__c],[Pledged_Amount__c],[Remaining_Pledge_Amount__c],[Remaining_Target__c],[Grandparent_Campaign_Casesafe_Id__c],[Dialer_Queue__c],[Country__c],[Fundraiser__c],[Fundraising_page_url__c],[Fundraising_Objective_Purpose__c],[Fundraising_Team_Code__c],[Speaker_Artist__c],[Call_List_Clearing_In_Progress__c],[Available_Amount__c],[Total_Funds_Allocated__c],[Upload_Transaction_ID__c],[Item__c],[Stipulation__c],[Donation_Value__c],[Patient__c],[Donation_Raised__c],[Funds_Allocated__c],[Total_FundsAllocated__c],[Email_Acknowledgement_Status__c],[FundraisingCode__c],[Priority__c],[Reviewed__c],[Campaign_Count__c],[Page_Type__c],[Arrival_Time__c],[External_Id__c],[Funds_Allocated_In_Campaign_Non_Pledge__c],[Funds_Allocated_In_Hierarchy_Instruction__c],[Funds_Allocated_In_Hierarchy_Non_Pledge__c],[Funds_Allocated_In_Hierarchy_Outside_CRM__c],[Income_Stream__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object]

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
