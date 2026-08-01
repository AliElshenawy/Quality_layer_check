/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   VIEW [staging].[vw_sponsorship_latest]
AS

WITH ranked_source AS
(
    SELECT
        [Id],[IsDeleted],[Name],[CurrencyIsoCode],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[LastViewedDate],[LastReferencedDate],[Orphan__c],[Donor__c],[End_Date_Time__c],[IsActive__c],[Recurring_Donation__c],[Renewal_Due_Date__c],[Start_Date_Time__c],[Status__c],[Donor_Organization__c],[DMS_Sponsorship_ID__c],[Acknowledgment_Status__c],[DMS_ID__c],[Orphan_Account_Name__c],[Donor_ID__c],[Orphan_First_Name__c],[Orphan_Last_Name__c],[Orphan_Country__c],[Orphan_First_Sponsorship_Date__c],[Donation__c],[Recurring_Donation_Status__c],[CaseSafeOrphanId__c],[Orphan_Gender__c],[Recurring_Donation_Campaign__c],[Annual_Report_Sent__c],[Country_Logo__c],[Donor_Record_Id__c],[Orphan_Detail_Email__c],[Current_Year__c],[Orphan_Visit_Status__c],[Donor_Regional_Office_Code__c],[Orphan_Visit_ID__c],[Orphan_Visit_Due_Date__c],[Orphan_Postal_Conga__c],[Orphan_Field_Office_Reference__c],[Orphan_Age__c],[Instruction__c],[Field_Office_Orphan__c],[Regional_Office_Code_Donor__c],[Sponsorship_Id_18__c],[Sponsorship_Deactivation_Reason__c],[Donor_Care_team_Email__c],[Terminated_Orphan_Gender__c],[Terminated_Orphan_Name__c],[Terminated_Orphan_Reason__c],[Annual_Report_Public_Link__c],[Annual_Report_Status__c],[Orphan_Full_Name__c],[Annual_Report_File_Name__c],[Send_File_to_SharePoint_UK__c],[Send_File_to_SharePoint_US__c],[Send_File_to_SharePoint_IE__c],[DateToday__c],[Donor_FirstName__c],[Donor_LastName__c],[DateUS__c],[Send_File_to_SharePoint_FR__c],[Test_Conga_Batch_Formula__c],[Donor_Receipt_via_Email__c],[Donor_Receipt_via_Post__c],[Send_File_to_SharePoint_ES__c],[Donor_Language__c],[Notes_on_Donor_Preferences__c],[Review_Required__c],[Sponsorship_Duration_Months__c],[Donor_Match__c],[Postal_Donor_Letter_Conga__c],[Send_File_to_SharePoint_AR__c],[Postal_Sponsorship_Price_Increase_Letter__c],[Terminated_Orphan_Sponsoree_id__c],[Terminated_Orphan_Termination_date__c],[Send_File_to_SharePoint_CA__c],[Sponsorship_duration_in_years__c],[UK_Send_Annual_Report_to_Salesforce_File__c],[UK_Send_Postal_Report_to_Files__c],[UK_Send_Postal_Reports_COver_Letter__c],[Campaign_Source__c],[CA_Send_Annual_Report_to_Salesforce_File__c],[US_Send_Annual_Report_to_Salesforce_File__c],[FR_Send_Annual_Report_to_Salesforce_File__c],[ES_Send_Annual_Report_to_Salesforce_File__c],[AR_Save_Annual_Report_to_Salesforce_File__c],[Save_Gaza_Orphan_Report_to_Files__c],[AR_Save_Gaza_Orphan_Report_to_FIles__c],[Forgotten_Women_Orphan_Reports__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object],

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

    FROM [raw].[salesforce_sponsorship]

    WHERE [Id] IS NOT NULL
)

SELECT
    [Id],[IsDeleted],[Name],[CurrencyIsoCode],[CreatedDate],[CreatedById],[LastModifiedDate],[LastModifiedById],[SystemModstamp],[LastActivityDate],[LastViewedDate],[LastReferencedDate],[Orphan__c],[Donor__c],[End_Date_Time__c],[IsActive__c],[Recurring_Donation__c],[Renewal_Due_Date__c],[Start_Date_Time__c],[Status__c],[Donor_Organization__c],[DMS_Sponsorship_ID__c],[Acknowledgment_Status__c],[DMS_ID__c],[Orphan_Account_Name__c],[Donor_ID__c],[Orphan_First_Name__c],[Orphan_Last_Name__c],[Orphan_Country__c],[Orphan_First_Sponsorship_Date__c],[Donation__c],[Recurring_Donation_Status__c],[CaseSafeOrphanId__c],[Orphan_Gender__c],[Recurring_Donation_Campaign__c],[Annual_Report_Sent__c],[Country_Logo__c],[Donor_Record_Id__c],[Orphan_Detail_Email__c],[Current_Year__c],[Orphan_Visit_Status__c],[Donor_Regional_Office_Code__c],[Orphan_Visit_ID__c],[Orphan_Visit_Due_Date__c],[Orphan_Postal_Conga__c],[Orphan_Field_Office_Reference__c],[Orphan_Age__c],[Instruction__c],[Field_Office_Orphan__c],[Regional_Office_Code_Donor__c],[Sponsorship_Id_18__c],[Sponsorship_Deactivation_Reason__c],[Donor_Care_team_Email__c],[Terminated_Orphan_Gender__c],[Terminated_Orphan_Name__c],[Terminated_Orphan_Reason__c],[Annual_Report_Public_Link__c],[Annual_Report_Status__c],[Orphan_Full_Name__c],[Annual_Report_File_Name__c],[Send_File_to_SharePoint_UK__c],[Send_File_to_SharePoint_US__c],[Send_File_to_SharePoint_IE__c],[DateToday__c],[Donor_FirstName__c],[Donor_LastName__c],[DateUS__c],[Send_File_to_SharePoint_FR__c],[Test_Conga_Batch_Formula__c],[Donor_Receipt_via_Email__c],[Donor_Receipt_via_Post__c],[Send_File_to_SharePoint_ES__c],[Donor_Language__c],[Notes_on_Donor_Preferences__c],[Review_Required__c],[Sponsorship_Duration_Months__c],[Donor_Match__c],[Postal_Donor_Letter_Conga__c],[Send_File_to_SharePoint_AR__c],[Postal_Sponsorship_Price_Increase_Letter__c],[Terminated_Orphan_Sponsoree_id__c],[Terminated_Orphan_Termination_date__c],[Send_File_to_SharePoint_CA__c],[Sponsorship_duration_in_years__c],[UK_Send_Annual_Report_to_Salesforce_File__c],[UK_Send_Postal_Report_to_Files__c],[UK_Send_Postal_Reports_COver_Letter__c],[Campaign_Source__c],[CA_Send_Annual_Report_to_Salesforce_File__c],[US_Send_Annual_Report_to_Salesforce_File__c],[FR_Send_Annual_Report_to_Salesforce_File__c],[ES_Send_Annual_Report_to_Salesforce_File__c],[AR_Save_Annual_Report_to_Salesforce_File__c],[Save_Gaza_Orphan_Report_to_Files__c],[AR_Save_Gaza_Orphan_Report_to_FIles__c],[Forgotten_Women_Orphan_Reports__c],[_etl_run_id],[_etl_extracted_at_utc],[_etl_source_object]

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
