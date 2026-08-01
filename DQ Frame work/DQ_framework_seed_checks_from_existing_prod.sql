/*
Seed existing object-level DQ checks into the incremental framework catalog.
Source scripts (unchanged):
- mohey_work/campaign/campaign_staging_dq_PROD.sql
- mohey_work/sponsorship/sponsorship_staging_dq_PROD.sql
- mohey_work/sponsorship_unit/sponsorship_unit_staging_dq_PROD.sql
- mohey_work/recurring_donation/recurring_donation_staging_dq_PROD.sql
- mohey_work/item_gau/item_gau_staging_dq_PROD.sql
*/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @seed TABLE
(
    object_name NVARCHAR(150) NOT NULL,
    source_view SYSNAME NOT NULL,
    check_name NVARCHAR(200) NOT NULL,
    check_type NVARCHAR(50) NOT NULL,
    target_column SYSNAME NULL,
    severity NVARCHAR(20) NOT NULL,
    description NVARCHAR(500) NULL,
    rule_definition NVARCHAR(MAX) NULL,
    rule_source NVARCHAR(100) NOT NULL,
    approval_status NVARCHAR(50) NOT NULL,
    process_name NVARCHAR(150) NOT NULL,
    is_active BIT NOT NULL
);

/* ============================================================================
   CAMPAIGN (18)
   ============================================================================ */
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-001', N'NOT_NULL', N'Id', N'CRITICAL', N'Campaign Id must not be null or blank', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-002', N'VALID_SALESFORCE_ID', N'Id', N'CRITICAL', N'Campaign Id must be 15 or 18 alphanumeric characters', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-003', N'NOT_NULL', N'Name', N'HIGH', N'Campaign Name must not be null', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-004', N'CUSTOM_SQL', NULL, N'HIGH', N'Campaign Status must be active/planned/inactive/completed/aborted/in progress and not null/blank',
N'SELECT [Id] AS record_id, [Status] AS exception_value, N''Status outside approved list'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE LOWER(COALESCE(NULLIF(LTRIM(RTRIM([Status])), ''''), ''<NULL_OR_BLANK>'')) NOT IN (''active'', ''planned'', ''inactive'', ''completed'', ''aborted'', ''in progress'')',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-005', N'CUSTOM_SQL', NULL, N'HIGH', N'Start Date must be <= End Date',
N'SELECT [Id] AS record_id, CONCAT(N''Start='', [StartDate], N'';End='', [EndDate]) AS exception_value, N''StartDate greater than EndDate'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE [StartDate] IS NOT NULL AND [EndDate] IS NOT NULL AND TRY_CONVERT(DATETIME2, [StartDate]) > TRY_CONVERT(DATETIME2, [EndDate])',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-006', N'CUSTOM_SQL', NULL, N'MEDIUM', N'Currency must be GBP/USD/EUR/CAD/AUD/SAR and not null/blank',
N'SELECT [Id] AS record_id, [CurrencyIsoCode] AS exception_value, N''Currency outside approved list'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE UPPER(COALESCE(NULLIF(LTRIM(RTRIM([CurrencyIsoCode])), ''''), ''<NULL_OR_BLANK>'')) NOT IN (''GBP'', ''USD'', ''EUR'', ''CAD'', ''AUD'', ''SAR'')',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-007', N'CUSTOM_SQL', NULL, N'MEDIUM', N'BudgetedCost must be >= 0 (no negative budgets)',
N'SELECT [Id] AS record_id, [BudgetedCost] AS exception_value, N''Negative budgeted cost'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE [BudgetedCost] IS NOT NULL AND TRY_CONVERT(NUMERIC(16,2), [BudgetedCost]) < 0',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-008', N'CUSTOM_SQL', NULL, N'MEDIUM', N'AmountWon must be <= AmountAll',
N'SELECT [Id] AS record_id, CONCAT(N''Won='', [AmountWonOpportunities], N'';All='', [AmountAllOpportunities]) AS exception_value, N''AmountWon greater than AmountAll'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE [AmountWonOpportunities] IS NOT NULL AND [AmountAllOpportunities] IS NOT NULL AND TRY_CONVERT(NUMERIC(16,2), [AmountWonOpportunities]) > TRY_CONVERT(NUMERIC(16,2), [AmountAllOpportunities])',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-009', N'CUSTOM_SQL', NULL, N'MEDIUM', N'Completed/Aborted campaigns must have IsActive = false',
N'SELECT [Id] AS record_id, CONCAT(N''Status='', [Status], N'';IsActive='', [IsActive]) AS exception_value, N''Completed or aborted campaign still active'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE LOWER(LTRIM(RTRIM([Status]))) IN (''completed'', ''aborted'') AND LOWER(LTRIM(RTRIM([IsActive]))) = ''true''',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-010', N'CUSTOM_SQL', NULL, N'HIGH', N'ParentId must reference an existing campaign Id when populated',
N'SELECT c.[Id] AS record_id, c.[ParentId] AS exception_value, N''ParentId not found in campaign set'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} c WHERE NULLIF(LTRIM(RTRIM(c.[ParentId])), '''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM {{SOURCE_VIEW}} p WHERE LTRIM(RTRIM(p.[Id])) = LTRIM(RTRIM(c.[ParentId])))',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-011', N'CUSTOM_SQL', NULL, N'LOW', N'Past EndDate campaigns should have IsActive = false',
N'SELECT [Id] AS record_id, CONCAT(N''EndDate='', [EndDate], N'';IsActive='', [IsActive]) AS exception_value, N''Past campaign still active'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE [EndDate] IS NOT NULL AND TRY_CONVERT(DATETIME2, [EndDate]) < CAST(GETUTCDATE() AS DATE) AND LOWER(LTRIM(RTRIM([IsActive]))) = ''true''',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-012', N'CUSTOM_SQL', NULL, N'LOW', N'ActualCost should not exceed 200% of BudgetedCost when BudgetedCost > 0',
N'SELECT [Id] AS record_id, CONCAT(N''Actual='', [ActualCost], N'';Budget='', [BudgetedCost]) AS exception_value, N''Actual cost greater than 2x budget'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE TRY_CONVERT(NUMERIC(18,2), [BudgetedCost]) IS NOT NULL AND TRY_CONVERT(NUMERIC(18,2), [ActualCost]) IS NOT NULL AND TRY_CONVERT(NUMERIC(18,2), [BudgetedCost]) > 0 AND TRY_CONVERT(NUMERIC(18,2), [ActualCost]) > 2 * TRY_CONVERT(NUMERIC(18,2), [BudgetedCost])',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-013', N'CUSTOM_SQL', NULL, N'MEDIUM', N'NumberOfOpportunities must be <= HierarchyNumberOfOpportunities',
N'SELECT [Id] AS record_id, CONCAT(N''Opp='', [NumberOfOpportunities], N'';HierarchyOpp='', [HierarchyNumberOfOpportunities]) AS exception_value, N''Opportunity hierarchy inconsistency'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE TRY_CONVERT(BIGINT, [NumberOfOpportunities]) IS NOT NULL AND TRY_CONVERT(BIGINT, [HierarchyNumberOfOpportunities]) IS NOT NULL AND TRY_CONVERT(BIGINT, [NumberOfOpportunities]) > TRY_CONVERT(BIGINT, [HierarchyNumberOfOpportunities])',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-014', N'CUSTOM_SQL', NULL, N'LOW', N'Casesafe_Campaign_ID__c should match Id when both populated',
N'SELECT [Id] AS record_id, [Casesafe_Campaign_ID__c] AS exception_value, N''Casesafe Campaign ID does not match Id'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM([Casesafe_Campaign_ID__c])), '''') IS NOT NULL AND NULLIF(LTRIM(RTRIM([Id])), '''') IS NOT NULL AND UPPER(LTRIM(RTRIM([Casesafe_Campaign_ID__c]))) <> UPPER(LTRIM(RTRIM([Id])))',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-015', N'CUSTOM_SQL', NULL, N'LOW', N'Year__c must be 4-digit year between 2000 and current year + 1 when populated',
N'SELECT [Id] AS record_id, [Year__c] AS exception_value, N''Invalid Year__c value'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM([Year__c])), '''') IS NOT NULL AND (TRY_CONVERT(INT, [Year__c]) IS NULL OR LEN(LTRIM(RTRIM([Year__c]))) <> 4 OR TRY_CONVERT(INT, [Year__c]) < 2000 OR TRY_CONVERT(INT, [Year__c]) > YEAR(GETUTCDATE()) + 1)',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-016', N'CUSTOM_SQL', NULL, N'MEDIUM', N'Region__c must be from approved list when populated',
N'SELECT [Id] AS record_id, [Region__c] AS exception_value, N''Region not in approved list'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM([Region__c])), '''') IS NOT NULL AND EXISTS (SELECT 1 FROM [staging].[campaign_region_allowed_values] WHERE [is_allowed] = 1) AND UPPER(LTRIM(RTRIM([Region__c]))) NOT IN (SELECT UPPER(LTRIM(RTRIM([region_value]))) FROM [staging].[campaign_region_allowed_values] WHERE [is_allowed] = 1)',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'raw.salesforce_campaign', N'CAM-017', N'VALID_BOOLEAN', N'IsDeleted', N'HIGH', N'IsDeleted must be true/false token in raw layer', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Campaign', N'staging.campaign_latest', N'CAM-URL-001', N'CUSTOM_SQL', NULL, N'MEDIUM', N'Fundraising URL must start with https://, http://, www., or be blank',
N'SELECT [Id] AS record_id, [Fundraising_page_url__c] AS exception_value, N''Fundraising URL format invalid'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE [Fundraising_page_url__c] IS NOT NULL AND [Fundraising_page_url__c] <> '''' AND NOT (LOWER([Fundraising_page_url__c]) LIKE ''https://%'' OR LOWER([Fundraising_page_url__c]) LIKE ''http://%'' OR LOWER([Fundraising_page_url__c]) LIKE ''www.%'')',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);

/* ============================================================================
   SPONSORSHIP (10)
   ============================================================================ */
INSERT INTO @seed VALUES (N'Sponsorship', N'staging.sponsorship_latest', N'SP-001', N'NOT_NULL', N'Id', N'CRITICAL', N'Sponsorship Id must not be null or blank', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship', N'staging.sponsorship_latest', N'SP-002', N'VALID_SALESFORCE_ID', N'Id', N'CRITICAL', N'Sponsorship Id must be 15 or 18 characters', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship', N'staging.sponsorship_latest', N'SP-003', N'CUSTOM_SQL', NULL, N'HIGH', N'Active sponsorships must have Donor__c',
N'SELECT [Id] AS record_id, [Donor__c] AS exception_value, N''Active sponsorship missing Donor__c'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE LOWER(LTRIM(RTRIM(COALESCE([IsActive__c], ''false'')))) = ''true'' AND NULLIF(LTRIM(RTRIM(COALESCE([Donor__c], ''''))), '''') IS NULL',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship', N'staging.sponsorship_latest', N'SP-004', N'CUSTOM_SQL', NULL, N'HIGH', N'Active sponsorships must have Orphan__c',
N'SELECT [Id] AS record_id, [Orphan__c] AS exception_value, N''Active sponsorship missing Orphan__c'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE LOWER(LTRIM(RTRIM(COALESCE([IsActive__c], ''false'')))) = ''true'' AND NULLIF(LTRIM(RTRIM(COALESCE([Orphan__c], ''''))), '''') IS NULL',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship', N'staging.sponsorship_latest', N'SP-005', N'CUSTOM_SQL', NULL, N'HIGH', N'Status__c and IsActive__c should be consistent',
N'SELECT [Id] AS record_id, CONCAT(N''Status='', COALESCE([Status__c], ''NULL''), N'';IsActive='', COALESCE([IsActive__c], ''NULL'')) AS exception_value, N''Status/active inconsistency'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE (UPPER(LTRIM(RTRIM(COALESCE([Status__c], '''')))) = ''ACTIVE'' AND LOWER(LTRIM(RTRIM(COALESCE([IsActive__c], ''false'')))) <> ''true'') OR (UPPER(LTRIM(RTRIM(COALESCE([Status__c], '''')))) IN (''TERMINATED'',''CLOSED'',''INACTIVE'') AND LOWER(LTRIM(RTRIM(COALESCE([IsActive__c], ''false'')))) = ''true'')',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship', N'staging.sponsorship_latest', N'SP-006', N'CUSTOM_SQL', NULL, N'MEDIUM', N'Active sponsorships should have Recurring_Donation__c',
N'SELECT [Id] AS record_id, [Recurring_Donation__c] AS exception_value, N''Active sponsorship missing Recurring_Donation__c'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE LOWER(LTRIM(RTRIM(COALESCE([IsActive__c], ''false'')))) = ''true'' AND NULLIF(LTRIM(RTRIM(COALESCE([Recurring_Donation__c], ''''))), '''') IS NULL',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship', N'staging.sponsorship_latest', N'SP-007', N'CUSTOM_SQL', NULL, N'HIGH', N'Start date must be <= End date when both populated',
N'SELECT [Id] AS record_id, CONCAT(N''Start='', [Start_Date_Time__c], N'';End='', [End_Date_Time__c]) AS exception_value, N''Start date greater than end date'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([Start_Date_Time__c], ''''))), '''') IS NOT NULL AND NULLIF(LTRIM(RTRIM(COALESCE([End_Date_Time__c], ''''))), '''') IS NOT NULL AND TRY_CONVERT(DATETIME2, [Start_Date_Time__c]) > TRY_CONVERT(DATETIME2, [End_Date_Time__c])',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship', N'staging.sponsorship_latest', N'SP-008', N'CUSTOM_SQL', NULL, N'MEDIUM', N'Terminated/Inactive sponsorship should have deactivation reason',
N'SELECT [Id] AS record_id, [Sponsorship_Deactivation_Reason__c] AS exception_value, N''Missing deactivation reason for inactive sponsorship'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE (UPPER(LTRIM(RTRIM(COALESCE([Status__c], '''')))) IN (''TERMINATED'',''CLOSED'',''INACTIVE'') OR LOWER(LTRIM(RTRIM(COALESCE([IsActive__c], ''false'')))) <> ''true'') AND NULLIF(LTRIM(RTRIM(COALESCE([Sponsorship_Deactivation_Reason__c], ''''))), '''') IS NULL',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship', N'staging.sponsorship_latest', N'SP-009', N'CUSTOM_SQL', NULL, N'HIGH', N'Donor__c should exist in raw.salesforce_contact when populated',
N'SELECT s.[Id] AS record_id, s.[Donor__c] AS exception_value, N''Donor__c not found in raw.salesforce_contact'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} s WHERE NULLIF(LTRIM(RTRIM(COALESCE(s.[Donor__c], ''''))), '''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_contact] c WHERE LTRIM(RTRIM(c.[Id])) = LTRIM(RTRIM(s.[Donor__c])))',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship', N'staging.sponsorship_latest', N'SP-010', N'CUSTOM_SQL', NULL, N'HIGH', N'Recurring_Donation__c should exist in raw.salesforce_recurring_donation when populated',
N'SELECT s.[Id] AS record_id, s.[Recurring_Donation__c] AS exception_value, N''Recurring_Donation__c not found in raw.salesforce_recurring_donation'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} s WHERE NULLIF(LTRIM(RTRIM(COALESCE(s.[Recurring_Donation__c], ''''))), '''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_recurring_donation] rd WHERE LTRIM(RTRIM(rd.[Id])) = LTRIM(RTRIM(s.[Recurring_Donation__c])))',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);

/* ============================================================================
   SPONSORSHIP UNIT (9)
   ============================================================================ */
INSERT INTO @seed VALUES (N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-001', N'NOT_NULL', N'Id', N'CRITICAL', N'Sponsorship Unit Id must not be null or blank', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-002', N'VALID_SALESFORCE_ID', N'Id', N'CRITICAL', N'Sponsorship Unit Id must be 15 or 18 characters', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-003', N'CUSTOM_SQL', NULL, N'CRITICAL', N'Sponsorship__c must be populated',
N'SELECT [Id] AS record_id, [Sponsorship__c] AS exception_value, N''Missing Sponsorship__c'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([Sponsorship__c], ''''))), '''') IS NULL',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-004', N'CUSTOM_SQL', NULL, N'CRITICAL', N'Sponsorship__c should exist in raw.salesforce_sponsorship',
N'SELECT su.[Id] AS record_id, su.sponsorship_key AS exception_value, N''Sponsorship__c not found in raw.salesforce_sponsorship'' AS exception_details, NULL AS etl_run_id FROM (SELECT [Id], LTRIM(RTRIM([Sponsorship__c])) AS sponsorship_key FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([Sponsorship__c], ''''))), '''') IS NOT NULL) su LEFT JOIN (SELECT DISTINCT LTRIM(RTRIM([Id])) AS sponsorship_key FROM [raw].[salesforce_sponsorship] WHERE NULLIF(LTRIM(RTRIM(COALESCE([Id], ''''))), '''') IS NOT NULL) sp ON sp.sponsorship_key = su.sponsorship_key WHERE sp.sponsorship_key IS NULL',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-005', N'CUSTOM_SQL', NULL, N'HIGH', N'Deferred_Amount_in_GBP__c should not be negative',
N'SELECT [Id] AS record_id, [Deferred_Amount_in_GBP__c] AS exception_value, N''Deferred amount in GBP is negative'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE TRY_CONVERT(DECIMAL(18,2), [Deferred_Amount_in_GBP__c]) < 0',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-006', N'CUSTOM_SQL', NULL, N'MEDIUM', N'Local currency should be set when deferred LC amount is populated',
N'SELECT [Id] AS record_id, CONCAT(N''LC='', COALESCE([Deferred_Amount_in_LC__c], ''NULL''), N'';Currency='', COALESCE([Local_Currency_Of_Deferred_Funds__c], ''NULL'')) AS exception_value, N''Missing local currency for deferred LC amount'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([Deferred_Amount_in_LC__c], ''''))), '''') IS NOT NULL AND NULLIF(LTRIM(RTRIM(COALESCE([Local_Currency_Of_Deferred_Funds__c], ''''))), '''') IS NULL',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-007', N'VALID_DATETIME', N'Donation_Date__c', N'MEDIUM', N'Donation_Date__c should be valid date when populated', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-008', N'CUSTOM_SQL', NULL, N'LOW', N'GAU_Allocation__c should exist in raw.salesforce_item_allocation when populated',
N'SELECT su.[Id] AS record_id, su.[GAU_Allocation__c] AS exception_value, N''GAU_Allocation__c not found in raw.salesforce_item_allocation'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} su WHERE NULLIF(LTRIM(RTRIM(COALESCE(su.[GAU_Allocation__c], ''''))), '''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_item_allocation] ia WHERE LTRIM(RTRIM(ia.[Id])) = LTRIM(RTRIM(su.[GAU_Allocation__c])))',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-009', N'CUSTOM_SQL', NULL, N'MEDIUM', N'Units should not point to deleted sponsorships',
N'SELECT su.[Id] AS record_id, su.[Sponsorship__c] AS exception_value, N''Sponsorship__c points to deleted sponsorship'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} su JOIN [raw].[salesforce_sponsorship] s ON LTRIM(RTRIM(s.[Id])) = LTRIM(RTRIM(su.[Sponsorship__c])) WHERE LOWER(LTRIM(RTRIM(COALESCE(s.[IsDeleted], ''false'')))) IN (''true'', ''1'', ''yes'', ''y'')',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);

/* ============================================================================
   RECURRING DONATION (9)
   ============================================================================ */
INSERT INTO @seed VALUES (N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-001', N'NOT_NULL', N'Id', N'CRITICAL', N'Recurring Donation Id must not be null or blank', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-002', N'VALID_SALESFORCE_ID', N'Id', N'CRITICAL', N'Recurring Donation Id must be 15 or 18 characters', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-003', N'CUSTOM_SQL', NULL, N'HIGH', N'At least one of Contact or Organization must be populated',
N'SELECT [Id] AS record_id, CONCAT(N''Contact='', COALESCE([npe03__Contact__c], ''NULL''), N'';Org='', COALESCE([npe03__Organization__c], ''NULL'')) AS exception_value, N''Both Contact and Organization are blank'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([npe03__Contact__c], ''''))), '''') IS NULL AND NULLIF(LTRIM(RTRIM(COALESCE([npe03__Organization__c], ''''))), '''') IS NULL',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-004', N'CUSTOM_SQL', NULL, N'HIGH', N'Active recurring donations must have amount > 0',
N'SELECT [Id] AS record_id, [npe03__Amount__c] AS exception_value, N''Active recurring donation with invalid amount'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE UPPER(LTRIM(RTRIM(COALESCE([npsp__Status__c], '''')))) = ''ACTIVE'' AND (TRY_CONVERT(DECIMAL(18,2), [npe03__Amount__c]) IS NULL OR TRY_CONVERT(DECIMAL(18,2), [npe03__Amount__c]) <= 0)',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-005', N'CUSTOM_SQL', NULL, N'HIGH', N'Recurring status must be in approved list',
N'SELECT [Id] AS record_id, [npsp__Status__c] AS exception_value, N''Recurring status outside approved list'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE UPPER(LTRIM(RTRIM(COALESCE([npsp__Status__c], '''')))) NOT IN (''ACTIVE'', ''LAPSED'', ''CLOSED'', ''PAUSED'')',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-006', N'CUSTOM_SQL', NULL, N'MEDIUM', N'Day of month must be 1-31 or Last_Day when populated',
N'SELECT [Id] AS record_id, [npsp__Day_of_Month__c] AS exception_value, N''Invalid day-of-month token'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([npsp__Day_of_Month__c], ''''))), '''') IS NOT NULL AND NOT (UPPER(LTRIM(RTRIM([npsp__Day_of_Month__c]))) = ''LAST_DAY'' OR (TRY_CONVERT(INT, [npsp__Day_of_Month__c]) BETWEEN 1 AND 31))',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-007', N'CUSTOM_SQL', NULL, N'HIGH', N'StartDate must be <= EndDate when both populated',
N'SELECT [Id] AS record_id, CONCAT(N''Start='', [npsp__StartDate__c], N'';End='', [npsp__EndDate__c]) AS exception_value, N''StartDate greater than EndDate'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([npsp__StartDate__c], ''''))), '''') IS NOT NULL AND NULLIF(LTRIM(RTRIM(COALESCE([npsp__EndDate__c], ''''))), '''') IS NOT NULL AND TRY_CONVERT(DATETIME2, [npsp__StartDate__c]) > TRY_CONVERT(DATETIME2, [npsp__EndDate__c])',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-008', N'CUSTOM_SQL', NULL, N'HIGH', N'Contact id should exist in raw.salesforce_contact when populated',
N'SELECT rd.[Id] AS record_id, rd.[npe03__Contact__c] AS exception_value, N''Contact id not found in raw.salesforce_contact'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} rd WHERE NULLIF(LTRIM(RTRIM(COALESCE(rd.[npe03__Contact__c], ''''))), '''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_contact] c WHERE LTRIM(RTRIM(c.[Id])) = LTRIM(RTRIM(rd.[npe03__Contact__c])))',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-009', N'CUSTOM_SQL', NULL, N'MEDIUM', N'Recurring campaign should exist in raw.salesforce_campaign when populated',
N'SELECT rd.[Id] AS record_id, rd.[npe03__Recurring_Donation_Campaign__c] AS exception_value, N''Recurring campaign not found in raw.salesforce_campaign'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} rd WHERE NULLIF(LTRIM(RTRIM(COALESCE(rd.[npe03__Recurring_Donation_Campaign__c], ''''))), '''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_campaign] c WHERE LTRIM(RTRIM(c.[Id])) = LTRIM(RTRIM(rd.[npe03__Recurring_Donation_Campaign__c])))',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);

/* ============================================================================
   ITEM GAU (6)
   ============================================================================ */
INSERT INTO @seed VALUES (N'Item_GAU', N'staging.item_gau_latest', N'GAU-001', N'NOT_NULL', N'Id', N'CRITICAL', N'Item Id must not be null or blank', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Item_GAU', N'staging.item_gau_latest', N'GAU-002', N'VALID_SALESFORCE_ID', N'Id', N'CRITICAL', N'Item Id must be 15 or 18 characters', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Item_GAU', N'staging.item_gau_latest', N'GAU-003', N'NOT_NULL', N'Name', N'HIGH', N'Item Name must not be null or blank', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Item_GAU', N'staging.item_gau_latest', N'GAU-004', N'VALID_BOOLEAN', N'npsp__Active__c', N'MEDIUM', N'npsp__Active__c should be true/false when populated', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Item_GAU', N'staging.item_gau_latest', N'GAU-005', N'CUSTOM_SQL', NULL, N'MEDIUM', N'CurrencyIsoCode should be populated for active items',
N'SELECT [Id] AS record_id, [CurrencyIsoCode] AS exception_value, N''Active item missing CurrencyIsoCode'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c], ''false'')))) = ''true'' AND NULLIF(LTRIM(RTRIM(COALESCE([CurrencyIsoCode], ''''))), '''') IS NULL',
N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);
INSERT INTO @seed VALUES (N'Item_GAU', N'staging.item_gau_latest', N'GAU-006', N'VALID_BOOLEAN', N'IsDeleted', N'HIGH', N'IsDeleted token should be true/false when populated', NULL, N'MOHEY_PROD_MIGRATION', N'Approved', N'DQ_FRAMEWORK', 1);

/* ============================================================================
   UPSERT INTO dq.dq_rule_catalog
   ============================================================================ */
MERGE dq.dq_rule_catalog AS tgt
USING
(
    SELECT *
    FROM @seed
) AS src
ON tgt.object_name = src.object_name
AND tgt.check_name = src.check_name
WHEN MATCHED THEN
    UPDATE SET
        tgt.source_view = src.source_view,
        tgt.check_type = src.check_type,
        tgt.target_column = src.target_column,
        tgt.severity = src.severity,
        tgt.description = src.description,
        tgt.is_active = src.is_active,
        tgt.rule_source = src.rule_source,
        tgt.approval_status = src.approval_status,
        tgt.process_name = src.process_name,
        tgt.rule_definition = src.rule_definition
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        object_name,
        source_view,
        check_name,
        check_type,
        target_column,
        severity,
        description,
        is_active,
        created_at,
        rule_source,
        approval_status,
        process_name,
        rule_definition
    )
    VALUES
    (
        src.object_name,
        src.source_view,
        src.check_name,
        src.check_type,
        src.target_column,
        src.severity,
        src.description,
        src.is_active,
        SYSUTCDATETIME(),
        src.rule_source,
        src.approval_status,
        src.process_name,
        src.rule_definition
    );

SELECT
    object_name,
    check_type,
    COUNT(*) AS rules_count
FROM @seed
GROUP BY object_name, check_type
ORDER BY object_name, check_type;

SELECT
    object_name,
    COUNT(*) AS total_rules
FROM dq.dq_rule_catalog
WHERE process_name = N'DQ_FRAMEWORK'
GROUP BY object_name
ORDER BY object_name;
