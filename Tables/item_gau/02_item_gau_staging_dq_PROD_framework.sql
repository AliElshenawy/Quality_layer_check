/*
================================================================================
ITEM_GAU STAGING + DQ (FRAMEWORK MODE)
================================================================================

Objective:
1) Build staging.item_gau_latest from raw.salesforce_item (dedup latest non-deleted), 31 columns
   including the 5 financial totals.
2) Seed / update all Item_GAU framework rules GAU-007..GAU-026 in dq.dq_rule_catalog
   (GAU-001..006 come from the base framework seed). Includes the fixed GAU-010/018 logic.
   Report-only (no assumed value lists — report distinct + ask stakeholders):
   GAU-007, GAU-008, GAU-009, GAU-015, GAU-016, GAU-017.
3) Run DQ via dq.run_incremental_catalog_rules and store outcomes in dq.dq_results / dq.dq_exceptions.

Consolidated 2026-08-01 from (source files retained for history):
  item_gau_framework_expand_rules_007_012.sql   (GAU-007..012)
  item_gau_framework_expand_rules_013_019.sql   (GAU-013..019)
  item_gau_framework_fix_and_financial.sql      (fixes 008/010/018 + GAU-020..026)

Database: SalesforceDW
Owner: Data Engineering
Date: 2026-07-30 (consolidated 2026-08-01)
================================================================================
*/

USE SalesforceDW;
GO
SET NOCOUNT ON;

-- ============================================================================
-- STEP 1: REBUILD STAGING TABLE
-- ============================================================================
PRINT '========== STEP 1: BUILD STAGING (incremental — no DROP) ==========';
-- Persistent table + incremental builder are the canonical files:
--   database/staging/item_gau_latest_table.sql  (IF NOT EXISTS table + Id18)
--   database/staging/item_gau_latest_SP.sql      (staging.refresh_item_gau_latest)
-- Deploy those first (via _deploy.sql); this step only refreshes incrementally.

EXEC staging.refresh_item_gau_latest;   -- add @FullRebuild = 1 only for a deliberate reset

DECLARE @stg_cnt BIGINT = (SELECT COUNT(*) FROM [staging].[item_gau_latest]);
PRINT 'Staging rows: ' + CAST(@stg_cnt AS VARCHAR(30));
GO

-- ============================================================================
-- STEP 2: SEED / UPDATE ALL ITEM_GAU RULES (GAU-007..026) — SAFE MERGE
--   GAU-001..006 come from the base framework seed
--   (mohey_work/DQ Frame work/DQ_framework_seed_checks_from_existing_prod.sql).
--   GAU-008 / GAU-010 / GAU-018 use the CORRECTED definitions
--   (expanded Programme list, non-Pledge Country scope, Sponsorship/Ticket scope).
-- ============================================================================
PRINT '========== STEP 2: SEED RULES GAU-007..026 ==========';

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
-- GAU-010: Active non-Pledge item must have Country (FIXED — Pledge exempt)
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-010', N'CUSTOM_SQL', NULL, N'HIGH',
    N'Active non-Pledge item must have Country__c populated',
    N'SELECT [Id] AS record_id, [Country__c] AS exception_value, '
    + N'N''Active non-Pledge item missing Country__c'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c],N''false'')))) = N''true'' '
    + N'AND UPPER(LTRIM(RTRIM(COALESCE([Product_Type__c],N'''')))) <> N''PLEDGE'' '
    + N'AND NULLIF(LTRIM(RTRIM(COALESCE([Country__c],N''''))),N'''') IS NULL',
    N'ITEM_GAU_EXPANSION', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-011: Status consistent with active flag
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-011', N'CUSTOM_SQL', NULL, N'MEDIUM',
    N'Status__c should be consistent with active flag',
    N'SELECT [Id] AS record_id, CONCAT(N''Status='', COALESCE([Status__c], ''NULL''), N'';Active='', COALESCE([npsp__Active__c], ''NULL'')) AS exception_value, N''Status/active inconsistency'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE (LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c], ''false'')))) = ''true'' AND UPPER(LTRIM(RTRIM(COALESCE([Status__c], '''')))) IN (''INACTIVE'',''CLOSED'',''ARCHIVED'')) OR (LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c], ''false'')))) = ''true'' AND NULLIF(LTRIM(RTRIM(COALESCE([Status__c], ''''))), '''') IS NULL)',
    N'ITEM_GAU_EXPANSION', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-012: Campaign referential integrity
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-012', N'CUSTOM_SQL', NULL, N'MEDIUM',
    N'Campaign__c should exist in raw.salesforce_campaign when populated',
    N'SELECT i.[Id] AS record_id, i.[Campaign__c] AS exception_value, N''Campaign__c not found in raw.salesforce_campaign'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} i WHERE NULLIF(LTRIM(RTRIM(COALESCE(i.[Campaign__c], ''''))), '''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_campaign] c WHERE LTRIM(RTRIM(c.[Id])) = LTRIM(RTRIM(i.[Campaign__c])))',
    N'ITEM_GAU_EXPANSION', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-013: Donation_Item_Code uniqueness
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-013', N'CUSTOM_SQL',
    N'Donation_Item_Code__c', N'HIGH',
    N'Donation_Item_Code__c must be unique across non-null values',
    N'SELECT [Id] AS record_id, [Donation_Item_Code__c] AS exception_value, '
    + N'CONCAT(N''Duplicate Donation_Item_Code__c shared by '', CAST(dup_cnt AS NVARCHAR(10)), N'' records'') AS exception_details, '
    + N'NULL AS etl_run_id '
    + N'FROM (SELECT [Id], [Donation_Item_Code__c], COUNT(*) OVER (PARTITION BY LTRIM(RTRIM([Donation_Item_Code__c]))) AS dup_cnt '
    + N'FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM(COALESCE([Donation_Item_Code__c],N''''))),N'''') IS NOT NULL) x '
    + N'WHERE dup_cnt > 1',
    N'ITEM_GAU_EXPANSION_2', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-014: Active item must have Product_Type
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-014', N'CUSTOM_SQL',
    N'Product_Type__c', N'HIGH',
    N'Active item must have Product_Type__c populated',
    N'SELECT [Id] AS record_id, [Product_Type__c] AS exception_value, '
    + N'N''Active item missing Product_Type__c'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c],N''false'')))) = N''true'' '
    + N'AND NULLIF(LTRIM(RTRIM(COALESCE([Product_Type__c],N''''))),N'''') IS NULL',
    N'ITEM_GAU_EXPANSION_2', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-018: Sponsorship/Ticket allow-flag consistency (FIXED — scoped)
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-018', N'CUSTOM_SQL',
    NULL, N'LOW',
    N'Active Sponsorship/Ticket item should have Allow_Single__c or Allow_Recurring__c set to true',
    N'SELECT [Id] AS record_id, '
    + N'CONCAT(N''Allow_Single='',COALESCE([Allow_Single__c],N''NULL''),N'';Allow_Recurring='',COALESCE([Allow_Recurring__c],N''NULL'')) AS exception_value, '
    + N'N''Sponsorship/Ticket item has both Allow_Single__c and Allow_Recurring__c false'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c],N''false'')))) = N''true'' '
    + N'AND UPPER(LTRIM(RTRIM(COALESCE([Product_Type__c],N'''')))) IN (N''SPONSORSHIP'',N''TICKET'') '
    + N'AND LOWER(LTRIM(RTRIM(COALESCE([Allow_Single__c],N''false'')))) = N''false'' '
    + N'AND LOWER(LTRIM(RTRIM(COALESCE([Allow_Recurring__c],N''false'')))) = N''false''',
    N'ITEM_GAU_EXPANSION_2', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-019: Active item must have Status
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-019', N'CUSTOM_SQL',
    N'Status__c', N'MEDIUM',
    N'Active item must have Status__c populated',
    N'SELECT [Id] AS record_id, [Status__c] AS exception_value, '
    + N'N''Active item missing Status__c'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c],N''false'')))) = N''true'' '
    + N'AND NULLIF(LTRIM(RTRIM(COALESCE([Status__c],N''''))),N'''') IS NULL',
    N'ITEM_GAU_EXPANSION_2', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-020: Total_Non_Zakat_Credit__c not null
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-020', N'CUSTOM_SQL',
    N'Total_Non_Zakat_Credit__c', N'HIGH',
    N'Total_Non_Zakat_Credit__c must not be null',
    N'SELECT [Id] AS record_id, [Total_Non_Zakat_Credit__c] AS exception_value, '
    + N'N''Total_Non_Zakat_Credit__c is null'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE [Total_Non_Zakat_Credit__c] IS NULL',
    N'ITEM_GAU_FINANCIAL', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-021: Total_Zakat_Credit__c not null
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-021', N'CUSTOM_SQL',
    N'Total_Zakat_Credit__c', N'HIGH',
    N'Total_Zakat_Credit__c must not be null',
    N'SELECT [Id] AS record_id, [Total_Zakat_Credit__c] AS exception_value, '
    + N'N''Total_Zakat_Credit__c is null'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE [Total_Zakat_Credit__c] IS NULL',
    N'ITEM_GAU_FINANCIAL', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-022: Total_funds_available_sadaqa__c not null
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-022', N'CUSTOM_SQL',
    N'Total_funds_available_sadaqa__c', N'HIGH',
    N'Total_funds_available_sadaqa__c must not be null',
    N'SELECT [Id] AS record_id, [Total_funds_available_sadaqa__c] AS exception_value, '
    + N'N''Total_funds_available_sadaqa__c is null'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE [Total_funds_available_sadaqa__c] IS NULL',
    N'ITEM_GAU_FINANCIAL', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-023: Total_funds_available_zakat__c not null
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-023', N'CUSTOM_SQL',
    N'Total_funds_available_zakat__c', N'HIGH',
    N'Total_funds_available_zakat__c must not be null',
    N'SELECT [Id] AS record_id, [Total_funds_available_zakat__c] AS exception_value, '
    + N'N''Total_funds_available_zakat__c is null'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE [Total_funds_available_zakat__c] IS NULL',
    N'ITEM_GAU_FINANCIAL', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-024: Total_Non_Zakat_Credit__c numeric
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-024', N'CUSTOM_SQL',
    N'Total_Non_Zakat_Credit__c', N'HIGH',
    N'Total_Non_Zakat_Credit__c must parse as a valid number when populated',
    N'SELECT [Id] AS record_id, [Total_Non_Zakat_Credit__c] AS exception_value, '
    + N'N''Total_Non_Zakat_Credit__c is not numeric'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([Total_Non_Zakat_Credit__c],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DECIMAL(18,2), [Total_Non_Zakat_Credit__c]) IS NULL',
    N'ITEM_GAU_FINANCIAL', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-025: Total_Zakat_Credit__c numeric
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-025', N'CUSTOM_SQL',
    N'Total_Zakat_Credit__c', N'HIGH',
    N'Total_Zakat_Credit__c must parse as a valid number when populated',
    N'SELECT [Id] AS record_id, [Total_Zakat_Credit__c] AS exception_value, '
    + N'N''Total_Zakat_Credit__c is not numeric'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([Total_Zakat_Credit__c],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DECIMAL(18,2), [Total_Zakat_Credit__c]) IS NULL',
    N'ITEM_GAU_FINANCIAL', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-VR-001: inactive item still holds unspent funds (Salesforce VR: Deactivate_Item_After_Emptying_Funds).
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-VR-001', N'CUSTOM_SQL',
    NULL, N'MEDIUM',
    N'Inactive item still has unspent funds (client VR: Deactivate_Item_After_Emptying_Funds) — Zakat or Non-Zakat credit > 0 while Active=false',
    N'SELECT [Id] AS record_id, '
    + N'CONCAT(N''Active='',COALESCE([npsp__Active__c],N''NULL''),N'';Zakat='',COALESCE([Total_Zakat_Credit__c],N''NULL''),N'';NonZakat='',COALESCE([Total_Non_Zakat_Credit__c],N''NULL'')) AS exception_value, '
    + N'N''Inactive item still has unspent Zakat/Non-Zakat funds'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c],N''false'')))) = N''false'' '
    + N'AND (TRY_CONVERT(DECIMAL(18,2), [Total_Zakat_Credit__c]) > 0 OR TRY_CONVERT(DECIMAL(18,2), [Total_Non_Zakat_Credit__c]) > 0)',
    N'ITEM_GAU_VALIDATION_RULE', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-VR-002: Ticket items cannot be Gift Aid Eligible (Salesforce VR: Ticket_Items_Gift_Eligibility).
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-VR-002', N'CUSTOM_SQL',
    N'Gift_Aid_Eligible__c', N'MEDIUM',
    N'Ticket item marked Gift Aid Eligible (client VR: Ticket_Items_Gift_Eligibility)',
    N'SELECT [Id] AS record_id, CONCAT(N''ProductType='',COALESCE([Product_Type__c],N''(null)''),N'';GiftAidEligible='',COALESCE([Gift_Aid_Eligible__c],N''(null)'')) AS exception_value, N''Ticket item marked Gift Aid Eligible'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE UPPER(LTRIM(RTRIM(COALESCE([Product_Type__c],N'''')))) = N''TICKET'' AND LOWER(LTRIM(RTRIM(COALESCE([Gift_Aid_Eligible__c],N''false'')))) IN (N''true'',N''1'',N''yes'')',
    N'ITEM_GAU_VALIDATION_RULE', N'Approved', N'DQ_FRAMEWORK', 1
),
-- GAU-026: npsp__Total_Allocations__c numeric
(
    N'Item_GAU', N'staging.item_gau_latest', N'GAU-026', N'CUSTOM_SQL',
    N'npsp__Total_Allocations__c', N'MEDIUM',
    N'npsp__Total_Allocations__c must parse as a valid number when populated',
    N'SELECT [Id] AS record_id, [npsp__Total_Allocations__c] AS exception_value, '
    + N'N''npsp__Total_Allocations__c is not numeric'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([npsp__Total_Allocations__c],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DECIMAL(18,2), [npsp__Total_Allocations__c]) IS NULL',
    N'ITEM_GAU_FINANCIAL', N'Approved', N'DQ_FRAMEWORK', 1
);

MERGE dq.dq_rule_catalog AS tgt
USING (SELECT * FROM @rules) AS src
    ON  tgt.object_name = src.object_name
    AND tgt.check_name  = src.check_name
WHEN MATCHED THEN
    UPDATE SET
        tgt.source_view     = src.source_view,
        tgt.check_type      = src.check_type,
        tgt.target_column   = src.target_column,
        tgt.severity        = src.severity,
        tgt.description     = src.description,
        tgt.rule_definition = src.rule_definition,
        tgt.rule_source     = src.rule_source,
        tgt.approval_status = src.approval_status,
        tgt.process_name    = src.process_name,
        tgt.is_active       = src.is_active
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (object_name, source_view, check_name, check_type, target_column,
     severity, description, is_active, created_at,
     rule_source, approval_status, process_name, rule_definition)
    VALUES
    (src.object_name, src.source_view, src.check_name, src.check_type, src.target_column,
     src.severity, src.description, src.is_active, SYSUTCDATETIME(),
     src.rule_source, src.approval_status, src.process_name, src.rule_definition);

PRINT 'Item_GAU rules merged: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- Rule logic may have changed and staging was rebuilt; reset watermarks so every
-- Item_GAU rule re-evaluates all rows on the next run.
UPDATE s
SET s.last_source_watermark_value = NULL,
    s.reprocess_review_pending = 0
FROM dq.rule_execution_state s
JOIN dq.dq_rule_catalog r ON r.rule_id = s.rule_id
WHERE r.object_name = N'Item_GAU';
PRINT 'Item_GAU rule watermarks reset to NULL';
GO

-- ============================================================================
-- STEP 3: EXECUTE FRAMEWORK DQ FOR ITEM_GAU
-- ============================================================================
PRINT '========== STEP 3: RUN FRAMEWORK DQ (ITEM_GAU) ==========';
EXEC dq.run_incremental_catalog_rules
    @ObjectNameFilter = N'Item_GAU',
    @RunOnlyPending = 0,
    @MaxRowsPerRule = 0,
    @MaxExceptionsPerRule = 50000,
    @ResolveWhenFull = 1;
GO

-- ============================================================================
-- STEP 4: REVIEW RESULTS
-- ============================================================================
PRINT '========== STEP 4: FRAMEWORK RESULT SNAPSHOT ==========';

WITH latest_result AS
(
    SELECT
        dr.object_name,
        dr.check_name,
        dr.severity,
        dr.failed_count,
        dr.check_status,
        dr.checked_at,
        ROW_NUMBER() OVER
        (
            PARTITION BY dr.object_name, dr.check_name
            ORDER BY dr.checked_at DESC, dr.dq_result_id DESC
        ) AS rn
    FROM dq.dq_results dr
    WHERE dr.object_name = N'Item_GAU'
)
SELECT
    object_name,
    check_name,
    severity,
    failed_count,
    check_status,
    checked_at
FROM latest_result
WHERE rn = 1
ORDER BY check_name;

SELECT
    r.check_name,
    COUNT(*) AS open_exceptions
FROM dq.dq_exceptions e
JOIN dq.dq_rule_catalog r
  ON r.rule_id = e.rule_id
WHERE r.process_name = N'DQ_FRAMEWORK'
  AND r.object_name = N'Item_GAU'
  AND e.resolution_status = N'OPEN'
GROUP BY r.check_name
ORDER BY r.check_name;
GO
