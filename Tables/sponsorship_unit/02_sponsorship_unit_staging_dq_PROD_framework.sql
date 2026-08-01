/*
================================================================================
SPONSORSHIP UNIT - FRAMEWORK MODE RULE SEED + 200K FIRST PASS
================================================================================

Object:       Sponsorship_Unit
Source:       raw.salesforce_sponsorship_unit
Staging:      staging.sponsorship_unit_latest
Rules:        SU-001 to SU-009
Date:         2026-07-31

Usage:
  1. Run sponsorship_unit_staging_dq_PROD.sql first to rebuild staging.
  2. Review local temp output.
  3. Run this file to seed framework rules and execute a controlled 200K-row pass.

Large-table note:
  This object has 1,291,058 raw rows. @MaxRowsPerRule is set to 200000 for the
  first framework pass. Set it to 0 only after review approval.
================================================================================
*/

USE SalesforceDW;
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[staging].[sponsorship_unit_latest]', N'U') IS NULL
BEGIN
    THROW 51000, 'Missing staging.sponsorship_unit_latest. Run sponsorship_unit_staging_dq_PROD.sql first.', 1;
END;
GO

PRINT '========== SPONSORSHIP UNIT: SEED FRAMEWORK RULES ==========';

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
(N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-001', N'NOT_NULL', N'Id', N'CRITICAL',
 N'Sponsorship Unit Id must not be null or blank', NULL, N'SU_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-002', N'VALID_SALESFORCE_ID', N'Id', N'CRITICAL',
 N'Sponsorship Unit Id must be 15 or 18 characters', NULL, N'SU_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-003', N'CUSTOM_SQL', N'Sponsorship__c', N'CRITICAL',
 N'Sponsorship__c must be populated',
 N'SELECT [Id] AS record_id, [Sponsorship__c] AS exception_value, N''Sponsorship__c is blank'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([Sponsorship__c],N''''))),N'''') IS NULL',
 N'SU_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-004', N'CUSTOM_SQL', N'Sponsorship__c', N'CRITICAL',
 N'Sponsorship__c should exist in raw.salesforce_sponsorship',
 N'SELECT su.[Id] AS record_id, su.[Sponsorship__c] AS exception_value, N''Sponsorship__c not found in raw.salesforce_sponsorship'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} su WHERE NULLIF(LTRIM(RTRIM(COALESCE(su.[Sponsorship__c],N''''))),N'''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_sponsorship] s WHERE LTRIM(RTRIM(s.[Id]))=LTRIM(RTRIM(su.[Sponsorship__c])))',
 N'SU_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-005', N'CUSTOM_SQL', N'Deferred_Amount_in_GBP__c', N'HIGH',
 N'Deferred_Amount_in_GBP__c should not be negative',
 N'SELECT [Id] AS record_id, [Deferred_Amount_in_GBP__c] AS exception_value, N''Deferred GBP amount is negative'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE TRY_CONVERT(DECIMAL(18,2), [Deferred_Amount_in_GBP__c]) < 0',
 N'SU_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-006', N'CUSTOM_SQL', N'Local_Currency_Of_Deferred_Funds__c', N'MEDIUM',
 N'Local currency should be set when deferred LC amount is populated',
 N'SELECT [Id] AS record_id, CONCAT(N''LC='',COALESCE([Deferred_Amount_in_LC__c],N''NULL''),N'';Currency='',COALESCE([Local_Currency_Of_Deferred_Funds__c],N''NULL'')) AS exception_value, N''LC amount populated without local currency'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([Deferred_Amount_in_LC__c],N''''))),N'''') IS NOT NULL AND NULLIF(LTRIM(RTRIM(COALESCE([Local_Currency_Of_Deferred_Funds__c],N''''))),N'''') IS NULL',
 N'SU_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-007', N'CUSTOM_SQL', N'Donation_Date__c', N'MEDIUM',
 N'Donation_Date__c should be valid date when populated',
 N'SELECT [Id] AS record_id, [Donation_Date__c] AS exception_value, N''Donation_Date__c is not a valid date'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([Donation_Date__c],N''''))),N'''') IS NOT NULL AND TRY_CONVERT(DATETIME2, [Donation_Date__c]) IS NULL',
 N'SU_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-008', N'CUSTOM_SQL', N'GAU_Allocation__c', N'LOW',
 N'GAU_Allocation__c should exist in raw.salesforce_item_allocation when populated',
 N'SELECT su.[Id] AS record_id, su.[GAU_Allocation__c] AS exception_value, N''GAU_Allocation__c not found in raw.salesforce_item_allocation'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} su WHERE NULLIF(LTRIM(RTRIM(COALESCE(su.[GAU_Allocation__c],N''''))),N'''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_item_allocation] ia WHERE LTRIM(RTRIM(ia.[Id]))=LTRIM(RTRIM(su.[GAU_Allocation__c])))',
 N'SU_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1),
(N'Sponsorship_Unit', N'staging.sponsorship_unit_latest', N'SU-009', N'CUSTOM_SQL', N'Sponsorship__c', N'MEDIUM',
 N'Units should not point to deleted sponsorships',
 N'SELECT su.[Id] AS record_id, su.[Sponsorship__c] AS exception_value, N''Unit points to deleted sponsorship'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} su JOIN [raw].[salesforce_sponsorship] s ON LTRIM(RTRIM(s.[Id]))=LTRIM(RTRIM(su.[Sponsorship__c])) WHERE LOWER(LTRIM(RTRIM(COALESCE(s.[IsDeleted],N''false'')))) IN (N''true'',N''1'',N''yes'',N''y'')',
 N'SU_FRAMEWORK', N'Draft', N'DQ_FRAMEWORK', 1);

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

PRINT '========== SPONSORSHIP UNIT: RESET WATERMARKS FOR FULL RE-SCAN ==========';
UPDATE s
SET s.last_source_watermark_value = NULL,
    s.reprocess_review_pending = 0
FROM dq.rule_execution_state s
JOIN dq.dq_rule_catalog r ON r.rule_id = s.rule_id
WHERE r.object_name = N'Sponsorship_Unit';
GO

PRINT '========== SPONSORSHIP UNIT: RUN FRAMEWORK 200K FIRST PASS ==========';
EXEC dq.run_incremental_catalog_rules
    @ObjectNameFilter     = N'Sponsorship_Unit',
    @MaxRowsPerRule       = 200000,
    @MaxExceptionsPerRule = 50000,
    @ResolveWhenFull      = 1;
GO

PRINT '========== SPONSORSHIP UNIT: PROGRESS SNAPSHOT ==========';
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
    WHERE object_name = N'Sponsorship_Unit'
) dr ON dr.check_name = r.check_name AND dr.rn = 1
WHERE r.object_name = N'Sponsorship_Unit'
ORDER BY r.check_name;
GO
