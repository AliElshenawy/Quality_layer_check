/*
================================================================================
SPONSORSHIP - FRAMEWORK MODE RULE SEED + 200K FIRST PASS
================================================================================

Object:       Sponsorship
Source:       raw.salesforce_sponsorship
Staging:      staging.sponsorship_latest
Rules:        SP-001 to SP-010
Date:         2026-07-31

Usage:
  1. Run sponsorship_staging_dq_PROD.sql first to rebuild staging.sponsorship_latest.
  2. Review local temp output.
  3. Run this file to seed framework rules and execute a controlled 200K-row pass.

Large-table note:
  This object has 228,229 raw rows. @MaxRowsPerRule is set to 200000 for the
  first framework pass. Set it to 0 only after review approval.
================================================================================
*/

USE SalesforceDW;
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[staging].[sponsorship_latest]', N'U') IS NULL
BEGIN
    THROW 51000, 'Missing staging.sponsorship_latest. Run sponsorship_staging_dq_PROD.sql first.', 1;
END;
GO

PRINT '========== SPONSORSHIP: SEED FRAMEWORK RULES ==========';

DECLARE @rules TABLE
(
    object_name     NVARCHAR(150) NOT NULL,
    source_view     SYSNAME       NOT NULL,
    check_name      NVARCHAR(200) NOT NULL,
    check_type      NVARCHAR(50)  NOT NULL,
    target_column   SYSNAME       NULL,
    severity        NVARCHAR(20)  NOT NULL,
    description     NVARCHAR(500) NULL,
    rule_definition NVARCHAR(MAX) NULL,
    rule_source     NVARCHAR(100) NOT NULL,
    approval_status NVARCHAR(50)  NOT NULL,
    process_name    NVARCHAR(150) NOT NULL,
    is_active       BIT           NOT NULL
);

INSERT INTO @rules VALUES
(N'Sponsorship', N'staging.sponsorship_latest', N'SP-001', N'NOT_NULL', N'Id', N'CRITICAL',
 N'Sponsorship Id must not be null or blank', NULL, N'SP_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship', N'staging.sponsorship_latest', N'SP-002', N'VALID_SALESFORCE_ID', N'Id', N'CRITICAL',
 N'Sponsorship Id must be 15 or 18 characters', NULL, N'SP_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship', N'staging.sponsorship_latest', N'SP-003', N'CUSTOM_SQL', N'Donor__c', N'HIGH',
 N'Active sponsorships must have Donor__c',
 N'SELECT [Id] AS record_id, [Donor__c] AS exception_value, N''Active sponsorship missing Donor__c'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE LOWER(LTRIM(RTRIM(COALESCE([IsActive__c],N''false''))))=N''true'' AND NULLIF(LTRIM(RTRIM(COALESCE([Donor__c],N''''))),N'''') IS NULL',
 N'SP_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship', N'staging.sponsorship_latest', N'SP-004', N'CUSTOM_SQL', N'Orphan__c', N'HIGH',
 N'Active sponsorships must have Orphan__c',
 N'SELECT [Id] AS record_id, [Orphan__c] AS exception_value, N''Active sponsorship missing Orphan__c'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE LOWER(LTRIM(RTRIM(COALESCE([IsActive__c],N''false''))))=N''true'' AND NULLIF(LTRIM(RTRIM(COALESCE([Orphan__c],N''''))),N'''') IS NULL',
 N'SP_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship', N'staging.sponsorship_latest', N'SP-005', N'CUSTOM_SQL', NULL, N'HIGH',
 N'Status__c and IsActive__c should be consistent',
 N'SELECT [Id] AS record_id, CONCAT(N''Status='',COALESCE([Status__c],N''NULL''),N'';IsActive='',COALESCE([IsActive__c],N''NULL'')) AS exception_value, N''Status and active flag are inconsistent'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE (UPPER(LTRIM(RTRIM(COALESCE([Status__c],N''''))))=N''ACTIVE'' AND LOWER(LTRIM(RTRIM(COALESCE([IsActive__c],N''false''))))<>N''true'') OR (UPPER(LTRIM(RTRIM(COALESCE([Status__c],N'''')))) IN (N''TERMINATED'',N''CLOSED'',N''INACTIVE'') AND LOWER(LTRIM(RTRIM(COALESCE([IsActive__c],N''false''))))=N''true'')',
 N'SP_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship', N'staging.sponsorship_latest', N'SP-006', N'CUSTOM_SQL', N'Recurring_Donation__c', N'MEDIUM',
 N'Active sponsorships should have Recurring_Donation__c',
 N'SELECT [Id] AS record_id, [Recurring_Donation__c] AS exception_value, N''Active sponsorship missing Recurring_Donation__c'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE LOWER(LTRIM(RTRIM(COALESCE([IsActive__c],N''false''))))=N''true'' AND NULLIF(LTRIM(RTRIM(COALESCE([Recurring_Donation__c],N''''))),N'''') IS NULL',
 N'SP_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship', N'staging.sponsorship_latest', N'SP-007', N'CUSTOM_SQL', NULL, N'HIGH',
 N'Start date must be <= End date when both populated',
 N'SELECT [Id] AS record_id, CONCAT(N''Start='',COALESCE([Start_Date_Time__c],N''NULL''),N'';End='',COALESCE([End_Date_Time__c],N''NULL'')) AS exception_value, N''Start date is after end date'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([Start_Date_Time__c],N''''))),N'''') IS NOT NULL AND NULLIF(LTRIM(RTRIM(COALESCE([End_Date_Time__c],N''''))),N'''') IS NOT NULL AND TRY_CONVERT(DATETIME2,[Start_Date_Time__c]) > TRY_CONVERT(DATETIME2,[End_Date_Time__c])',
 N'SP_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship', N'staging.sponsorship_latest', N'SP-008', N'CUSTOM_SQL', N'Sponsorship_Deactivation_Reason__c', N'MEDIUM',
 N'Terminated/inactive sponsorship should have deactivation reason',
 N'SELECT [Id] AS record_id, [Sponsorship_Deactivation_Reason__c] AS exception_value, N''Inactive sponsorship missing deactivation reason'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE (UPPER(LTRIM(RTRIM(COALESCE([Status__c],N'''')))) IN (N''TERMINATED'',N''CLOSED'',N''INACTIVE'') OR LOWER(LTRIM(RTRIM(COALESCE([IsActive__c],N''false''))))<>N''true'') AND NULLIF(LTRIM(RTRIM(COALESCE([Sponsorship_Deactivation_Reason__c],N''''))),N'''') IS NULL',
 N'SP_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship', N'staging.sponsorship_latest', N'SP-009', N'CUSTOM_SQL', N'Donor__c', N'HIGH',
 N'Donor__c should exist in raw.salesforce_contact when populated',
 N'SELECT s.[Id] AS record_id, s.[Donor__c] AS exception_value, N''Donor__c not found in raw.salesforce_contact'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} s WHERE NULLIF(LTRIM(RTRIM(COALESCE(s.[Donor__c],N''''))),N'''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_contact] c WHERE LTRIM(RTRIM(c.[Id]))=LTRIM(RTRIM(s.[Donor__c])))',
 N'SP_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship', N'staging.sponsorship_latest', N'SP-010', N'CUSTOM_SQL', N'Recurring_Donation__c', N'HIGH',
 N'Recurring_Donation__c should exist in raw.salesforce_recurring_donation when populated',
 N'SELECT s.[Id] AS record_id, s.[Recurring_Donation__c] AS exception_value, N''Recurring_Donation__c not found in raw.salesforce_recurring_donation'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} s WHERE NULLIF(LTRIM(RTRIM(COALESCE(s.[Recurring_Donation__c],N''''))),N'''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_recurring_donation] rd WHERE LTRIM(RTRIM(rd.[Id]))=LTRIM(RTRIM(s.[Recurring_Donation__c])))',
 N'SP_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1);

MERGE dq.dq_rule_catalog AS tgt
USING (SELECT * FROM @rules) AS src
    ON tgt.object_name = src.object_name AND tgt.check_name = src.check_name
WHEN MATCHED THEN
    UPDATE SET source_view = src.source_view, check_type = src.check_type,
        target_column = src.target_column, severity = src.severity,
        description = src.description, rule_definition = src.rule_definition,
        rule_source = src.rule_source, approval_status = src.approval_status,
        process_name = src.process_name, is_active = src.is_active
WHEN NOT MATCHED BY TARGET THEN
    INSERT (object_name, source_view, check_name, check_type, target_column,
            severity, description, is_active, created_at,
            rule_source, approval_status, process_name, rule_definition)
    VALUES (src.object_name, src.source_view, src.check_name, src.check_type,
            src.target_column, src.severity, src.description, src.is_active,
            SYSUTCDATETIME(), src.rule_source, src.approval_status,
            src.process_name, src.rule_definition);
GO

PRINT '========== SPONSORSHIP: RESET WATERMARKS FOR FULL RE-SCAN ==========';
UPDATE s
SET s.last_source_watermark_value = NULL,
    s.reprocess_review_pending = 0
FROM dq.rule_execution_state s
JOIN dq.dq_rule_catalog r ON r.rule_id = s.rule_id
WHERE r.object_name = N'Sponsorship';
GO

PRINT '========== SPONSORSHIP: RUN FRAMEWORK 200K FIRST PASS ==========';
EXEC dq.run_incremental_catalog_rules
    @ObjectNameFilter     = N'Sponsorship',
    @MaxRowsPerRule       = 200000,
    @MaxExceptionsPerRule = 50000,
    @ResolveWhenFull      = 1;
GO

PRINT '========== SPONSORSHIP: PROGRESS SNAPSHOT ==========';
SELECT r.check_name, r.severity, s.last_run_status,
       s.last_source_watermark_value,
       ISNULL(dr.check_status, 'NOT RUN') AS last_status,
       ISNULL(dr.failed_count, 0) AS failed_count,
       CONVERT(VARCHAR(23), dr.checked_at, 121) AS checked_at
FROM dq.dq_rule_catalog r
JOIN dq.rule_execution_state s ON s.rule_id = r.rule_id
LEFT JOIN (
    SELECT check_name, check_status, failed_count, checked_at,
           ROW_NUMBER() OVER (PARTITION BY check_name ORDER BY checked_at DESC) AS rn
    FROM dq.dq_results
    WHERE object_name = N'Sponsorship'
) dr ON dr.check_name = r.check_name AND dr.rn = 1
WHERE r.object_name = N'Sponsorship'
ORDER BY r.check_name;
GO
