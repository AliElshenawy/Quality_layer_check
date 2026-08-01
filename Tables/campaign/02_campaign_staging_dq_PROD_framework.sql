/*
================================================================================
CAMPAIGN — FRAMEWORK MODE: STAGING + DQ (FULL)
================================================================================

Object:       Campaign
Source:       raw.salesforce_campaign
Staging:      staging.campaign_latest
Rules:        CAM-001 to CAM-017 + CAM-URL-001 (18 rules total via framework)
Date:         2026-08-01

Status note:
  Campaign is ALREADY registered and executed in the framework. As of 2026-07-29
  dq.dq_rule_catalog holds all 18 CAM rules (is_active=1) and dq.dq_exceptions holds
  ~17,700 Campaign exceptions. This file is the reproducible framework-style script
  (previously only the object-local temp-table PROD script existed for Campaign).
  Running it rebuilds staging, refreshes the 18 rules via idempotent MERGE, and
  re-runs the incremental catalog runner.

Rule check types (must match dq.dq_rule_catalog):
  Built-in : CAM-001 NOT_NULL, CAM-002 VALID_SALESFORCE_ID, CAM-003 NOT_NULL,
             CAM-017 VALID_BOOLEAN
  CUSTOM_SQL: CAM-005..016 + CAM-URL-001
              (CAM-004 Status / CAM-006 Currency report-only: no assumed value lists)

Dependency / governance notes:
  CAM-016 (Region controlled list) is governed by staging.campaign_region_allowed_values.
          The rule SQL is GUARDED: it only flags when that table has at least one
          is_allowed=1 row, so an empty approved-list produces 0 (not false positives).
  CAM-017 (IsDeleted VALID_BOOLEAN) runs on staging.campaign_latest, which already
          excludes deleted rows, so it is expected to be ~0 here. The raw-layer
          IsDeleted token check remains a separate concern.

Staging columns (29):
  Dedup      : row_number
  Identity   : Id, ParentId, Type, RecordTypeId, IsDeleted, Name
  Lifecycle  : Status, StartDate, EndDate, IsActive
  Attributes : Year__c, Region__c, CurrencyIsoCode
  Financial  : BudgetedCost, ActualCost, AmountAllOpportunities, AmountWonOpportunities
  Metrics    : NumberOfOpportunities, HierarchyNumberOfOpportunities
  Reference  : Casesafe_Campaign_ID__c, Fundraising_page_url__c
  ETL meta   : SystemModstamp, _etl_source, _etl_source_object, _etl_loaded_at_utc,
               staging_is_duplicate, staging_duplicate_count, staging_created_at

Progress monitoring:
  SELECT check_name, last_run_status, last_source_watermark_value
  FROM dq.rule_execution_state s
  JOIN dq.dq_rule_catalog r ON r.rule_id=s.rule_id
  WHERE r.object_name='Campaign'
  ORDER BY check_name;

Force full re-scan of a rule:
  UPDATE s SET last_source_watermark_value=NULL, reprocess_review_pending=0
  FROM dq.rule_execution_state s JOIN dq.dq_rule_catalog r ON r.rule_id=s.rule_id
  WHERE r.object_name='Campaign' AND r.check_name='CAM-011';
================================================================================
*/

USE SalesforceDW;
GO
SET NOCOUNT ON;

-- ============================================================================
-- STEP 1: REBUILD STAGING (29 COLUMNS)
-- ============================================================================
PRINT '========== STEP 1: REBUILD STAGING (29 COLS) ==========';

IF OBJECT_ID(N'[staging].[campaign_latest]', N'U') IS NOT NULL
    DROP TABLE [staging].[campaign_latest];

CREATE TABLE [staging].[campaign_latest]
(
    [row_number]                        BIGINT,
    [Id]                                NVARCHAR(MAX),
    [ParentId]                          NVARCHAR(MAX),
    [Type]                              NVARCHAR(MAX),
    [RecordTypeId]                      NVARCHAR(MAX),
    [IsDeleted]                         NVARCHAR(MAX),
    [Name]                              NVARCHAR(MAX),
    [Status]                            NVARCHAR(MAX),
    [StartDate]                         NVARCHAR(MAX),
    [EndDate]                           NVARCHAR(MAX),
    [Year__c]                           NVARCHAR(MAX),
    [Region__c]                         NVARCHAR(MAX),
    [CurrencyIsoCode]                   NVARCHAR(MAX),
    [BudgetedCost]                      NVARCHAR(MAX),
    [ActualCost]                        NVARCHAR(MAX),
    [IsActive]                          NVARCHAR(MAX),
    [NumberOfOpportunities]             NVARCHAR(MAX),
    [HierarchyNumberOfOpportunities]    NVARCHAR(MAX),
    [AmountAllOpportunities]            NVARCHAR(MAX),
    [AmountWonOpportunities]            NVARCHAR(MAX),
    [Casesafe_Campaign_ID__c]           NVARCHAR(MAX),
    [Fundraising_page_url__c]           NVARCHAR(MAX),
    [SystemModstamp]                    NVARCHAR(MAX),
    [_etl_source]                       NVARCHAR(MAX),
    [_etl_source_object]                NVARCHAR(MAX),
    [_etl_loaded_at_utc]                NVARCHAR(MAX),
    [staging_is_duplicate]              BIT,
    [staging_duplicate_count]           INT,
    [staging_created_at]                DATETIME
);
GO

WITH dedup AS
(
    SELECT
        [Id], [ParentId], [Type], [RecordTypeId], [IsDeleted], [Name], [Status], [StartDate], [EndDate],
        [Year__c], [Region__c], [CurrencyIsoCode], [BudgetedCost], [ActualCost], [IsActive],
        [NumberOfOpportunities], [HierarchyNumberOfOpportunities], [AmountAllOpportunities], [AmountWonOpportunities],
        [Casesafe_Campaign_ID__c], [Fundraising_page_url__c], [SystemModstamp],
        [_etl_source], [_etl_source_object], [_etl_loaded_at_utc],
        ROW_NUMBER() OVER
        (
            PARTITION BY CONVERT(VARCHAR(18), [Id])
            ORDER BY COALESCE
            (
                TRY_CONVERT(DATETIME2(7), [SystemModstamp], 127),
                TRY_CONVERT(DATETIME2(7), [SystemModstamp])
            ) DESC
        ) AS rn,
        COUNT(*) OVER (PARTITION BY [Id]) AS dup_cnt
    FROM [raw].[salesforce_campaign]
    WHERE [Id] IS NOT NULL
)
INSERT INTO [staging].[campaign_latest]
(
    [row_number],
    [Id], [ParentId], [Type], [RecordTypeId], [IsDeleted], [Name], [Status], [StartDate], [EndDate],
    [Year__c], [Region__c], [CurrencyIsoCode], [BudgetedCost], [ActualCost], [IsActive],
    [NumberOfOpportunities], [HierarchyNumberOfOpportunities], [AmountAllOpportunities], [AmountWonOpportunities],
    [Casesafe_Campaign_ID__c], [Fundraising_page_url__c], [SystemModstamp],
    [_etl_source], [_etl_source_object], [_etl_loaded_at_utc],
    [staging_is_duplicate], [staging_duplicate_count], [staging_created_at]
)
SELECT
    rn,
    [Id], [ParentId], [Type], [RecordTypeId], [IsDeleted], [Name], [Status], [StartDate], [EndDate],
    [Year__c], [Region__c], [CurrencyIsoCode], [BudgetedCost], [ActualCost], [IsActive],
    [NumberOfOpportunities], [HierarchyNumberOfOpportunities], [AmountAllOpportunities], [AmountWonOpportunities],
    [Casesafe_Campaign_ID__c], [Fundraising_page_url__c], [SystemModstamp],
    [_etl_source], [_etl_source_object], [_etl_loaded_at_utc],
    CASE WHEN dup_cnt > 1 THEN 1 ELSE 0 END,
    CASE WHEN dup_cnt > 1 THEN dup_cnt ELSE 0 END,
    GETUTCDATE()
FROM dedup
WHERE rn = 1
  AND COALESCE(LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), [IsDeleted])))), N'false')
      NOT IN (N'true', N'1', N'yes', N'y');

DECLARE @stg_cnt BIGINT = (SELECT COUNT(*) FROM [staging].[campaign_latest]);
PRINT 'Staging rows loaded: ' + CAST(@stg_cnt AS VARCHAR(30));
GO

-- ============================================================================
-- STEP 2: SEED / UPDATE ALL RULES (CAM-001..017 + CAM-URL-001) — SAFE MERGE
-- ============================================================================
PRINT '========== STEP 2: SEED RULES CAM-001..017 + CAM-URL-001 ==========';

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

-- CAM-001: Id must not be null (built-in NOT_NULL)
(
    N'Campaign', N'staging.campaign_latest', N'CAM-001', N'NOT_NULL',
    N'Id', N'CRITICAL', N'Campaign Id must not be null or blank',
    NULL, N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-002: Id must be a valid Salesforce Id (built-in)
(
    N'Campaign', N'staging.campaign_latest', N'CAM-002', N'VALID_SALESFORCE_ID',
    N'Id', N'CRITICAL', N'Campaign Id must be 15 or 18 characters',
    NULL, N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-003: Name must not be null (built-in NOT_NULL)
(
    N'Campaign', N'staging.campaign_latest', N'CAM-003', N'NOT_NULL',
    N'Name', N'HIGH', N'Campaign Name must not be null or blank',
    NULL, N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-005: StartDate must be <= EndDate
(
    N'Campaign', N'staging.campaign_latest', N'CAM-005', N'CUSTOM_SQL',
    NULL, N'HIGH', N'StartDate must not be after EndDate when both populated',
    N'SELECT [Id] AS record_id, CONCAT(N''Start='',[StartDate],N'';End='',[EndDate]) AS exception_value, '
    + N'N''StartDate is after EndDate'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([StartDate],N''''))),N'''') IS NOT NULL '
    + N'AND NULLIF(LTRIM(RTRIM(COALESCE([EndDate],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DATETIME2,[StartDate]) > TRY_CONVERT(DATETIME2,[EndDate])',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-007: BudgetedCost must be >= 0
(
    N'Campaign', N'staging.campaign_latest', N'CAM-007', N'CUSTOM_SQL',
    N'BudgetedCost', N'MEDIUM', N'BudgetedCost must be >= 0 (no negative budgets)',
    N'SELECT [Id] AS record_id, [BudgetedCost] AS exception_value, '
    + N'N''BudgetedCost is negative'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([BudgetedCost],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DECIMAL(18,2),[BudgetedCost]) < 0',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-008: AmountWon must be <= AmountAll
(
    N'Campaign', N'staging.campaign_latest', N'CAM-008', N'CUSTOM_SQL',
    NULL, N'MEDIUM', N'AmountWonOpportunities must be <= AmountAllOpportunities',
    N'SELECT [Id] AS record_id, CONCAT(N''Won='',[AmountWonOpportunities],N'';All='',[AmountAllOpportunities]) AS exception_value, '
    + N'N''AmountWon exceeds AmountAll'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([AmountWonOpportunities],N''''))),N'''') IS NOT NULL '
    + N'AND NULLIF(LTRIM(RTRIM(COALESCE([AmountAllOpportunities],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DECIMAL(18,2),[AmountWonOpportunities]) > TRY_CONVERT(DECIMAL(18,2),[AmountAllOpportunities])',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-009: Completed/Aborted campaigns must have IsActive = false
(
    N'Campaign', N'staging.campaign_latest', N'CAM-009', N'CUSTOM_SQL',
    NULL, N'MEDIUM', N'Completed/Aborted campaigns must have IsActive = false',
    N'SELECT [Id] AS record_id, CONCAT(N''Status='',[Status],N'';IsActive='',[IsActive]) AS exception_value, '
    + N'N''Completed/Aborted campaign still marked active'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE LOWER(LTRIM(RTRIM(COALESCE([Status],N'''')))) IN (N''completed'',N''aborted'') '
    + N'AND LOWER(LTRIM(RTRIM(COALESCE([IsActive],N''false'')))) = N''true''',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-010: ParentId must reference an existing campaign Id (self-referential)
(
    N'Campaign', N'staging.campaign_latest', N'CAM-010', N'CUSTOM_SQL',
    N'ParentId', N'HIGH', N'ParentId must reference an existing campaign Id when populated',
    N'SELECT c.[Id] AS record_id, c.[ParentId] AS exception_value, '
    + N'N''ParentId does not reference an existing campaign'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} c '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE(c.[ParentId],N''''))),N'''') IS NOT NULL '
    + N'AND NOT EXISTS (SELECT 1 FROM {{SOURCE_VIEW}} p WHERE LTRIM(RTRIM(p.[Id]))=LTRIM(RTRIM(c.[ParentId])))',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-011: Past EndDate campaigns should have IsActive = false
(
    N'Campaign', N'staging.campaign_latest', N'CAM-011', N'CUSTOM_SQL',
    NULL, N'LOW', N'Past EndDate campaigns should have IsActive = false',
    N'SELECT [Id] AS record_id, CONCAT(N''EndDate='',[EndDate],N'';IsActive='',[IsActive]) AS exception_value, '
    + N'N''Past EndDate campaign still marked active'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([EndDate],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DATETIME2,[EndDate]) < CAST(GETUTCDATE() AS DATE) '
    + N'AND LOWER(LTRIM(RTRIM(COALESCE([IsActive],N''false'')))) = N''true''',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-012: ActualCost should not exceed 200% of BudgetedCost when BudgetedCost > 0
(
    N'Campaign', N'staging.campaign_latest', N'CAM-012', N'CUSTOM_SQL',
    NULL, N'LOW', N'ActualCost should not exceed 200% of BudgetedCost when BudgetedCost > 0',
    N'SELECT [Id] AS record_id, CONCAT(N''Actual='',[ActualCost],N'';Budget='',[BudgetedCost]) AS exception_value, '
    + N'N''ActualCost exceeds 200% of BudgetedCost'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE TRY_CONVERT(DECIMAL(18,2),[BudgetedCost]) > 0 '
    + N'AND TRY_CONVERT(DECIMAL(18,2),[ActualCost]) > 2 * TRY_CONVERT(DECIMAL(18,2),[BudgetedCost])',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-013: NumberOfOpportunities must be <= HierarchyNumberOfOpportunities
(
    N'Campaign', N'staging.campaign_latest', N'CAM-013', N'CUSTOM_SQL',
    NULL, N'MEDIUM', N'NumberOfOpportunities must be <= HierarchyNumberOfOpportunities',
    N'SELECT [Id] AS record_id, CONCAT(N''Opp='',[NumberOfOpportunities],N'';HierOpp='',[HierarchyNumberOfOpportunities]) AS exception_value, '
    + N'N''NumberOfOpportunities exceeds HierarchyNumberOfOpportunities'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE TRY_CONVERT(BIGINT,[NumberOfOpportunities]) > TRY_CONVERT(BIGINT,[HierarchyNumberOfOpportunities])',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-014: Casesafe_Campaign_ID__c should match Id when both populated
(
    N'Campaign', N'staging.campaign_latest', N'CAM-014', N'CUSTOM_SQL',
    N'Casesafe_Campaign_ID__c', N'LOW', N'Casesafe_Campaign_ID__c should match Id when both populated',
    N'SELECT [Id] AS record_id, [Casesafe_Campaign_ID__c] AS exception_value, '
    + N'N''Casesafe_Campaign_ID__c does not match Id'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([Casesafe_Campaign_ID__c],N''''))),N'''') IS NOT NULL '
    + N'AND NULLIF(LTRIM(RTRIM(COALESCE([Id],N''''))),N'''') IS NOT NULL '
    + N'AND UPPER(LTRIM(RTRIM([Casesafe_Campaign_ID__c]))) <> UPPER(LTRIM(RTRIM([Id])))',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-015: Year__c must be a valid 4-digit year (2000..current+1) when populated
(
    N'Campaign', N'staging.campaign_latest', N'CAM-015', N'CUSTOM_SQL',
    N'Year__c', N'LOW', N'Year__c must be a 4-digit year between 2000 and current year + 1 when populated',
    N'SELECT [Id] AS record_id, [Year__c] AS exception_value, '
    + N'N''Year__c is not a valid 4-digit year in range'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([Year__c],N''''))),N'''') IS NOT NULL '
    + N'AND (TRY_CONVERT(INT,[Year__c]) IS NULL OR LEN(LTRIM(RTRIM([Year__c]))) <> 4 '
    + N'OR TRY_CONVERT(INT,[Year__c]) < 2000 OR TRY_CONVERT(INT,[Year__c]) > YEAR(GETUTCDATE()) + 1)',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-016: Region__c must be from approved list — GUARDED (only flags when list loaded)
(
    N'Campaign', N'staging.campaign_latest', N'CAM-016', N'CUSTOM_SQL',
    N'Region__c', N'MEDIUM', N'Region__c must be from approved list when populated (governed by staging.campaign_region_allowed_values)',
    N'SELECT [Id] AS record_id, [Region__c] AS exception_value, '
    + N'N''Region__c outside approved list'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([Region__c],N''''))),N'''') IS NOT NULL '
    + N'AND EXISTS (SELECT 1 FROM [staging].[campaign_region_allowed_values] WHERE [is_allowed]=1) '
    + N'AND UPPER(LTRIM(RTRIM([Region__c]))) NOT IN '
    + N'(SELECT UPPER(LTRIM(RTRIM([region_value]))) FROM [staging].[campaign_region_allowed_values] WHERE [is_allowed]=1)',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-017: IsDeleted must be a valid boolean token (built-in VALID_BOOLEAN)
--          Runs on staging (deleted rows already excluded) so expected ~0 here.
(
    N'Campaign', N'staging.campaign_latest', N'CAM-017', N'VALID_BOOLEAN',
    N'IsDeleted', N'HIGH', N'IsDeleted must be a true/false token',
    NULL, N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CAM-URL-001: Fundraising URL must start with https://, http://, www., or be blank
(
    N'Campaign', N'staging.campaign_latest', N'CAM-URL-001', N'CUSTOM_SQL',
    N'Fundraising_page_url__c', N'MEDIUM', N'Fundraising URL must start with https://, http://, www., or be blank',
    N'SELECT [Id] AS record_id, [Fundraising_page_url__c] AS exception_value, '
    + N'N''Fundraising URL does not start with https://, http:// or www.'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([Fundraising_page_url__c],N''''))),N'''') IS NOT NULL '
    + N'AND LOWER(LTRIM(RTRIM([Fundraising_page_url__c]))) NOT LIKE N''https://%'' '
    + N'AND LOWER(LTRIM(RTRIM([Fundraising_page_url__c]))) NOT LIKE N''http://%'' '
    + N'AND LOWER(LTRIM(RTRIM([Fundraising_page_url__c]))) NOT LIKE N''www.%''',
    N'CAM_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
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

PRINT 'Rules merged: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- ============================================================================
-- STEP 3: RESET WATERMARKS SO RULES RE-EVALUATE ALL ROWS
-- ============================================================================
PRINT '========== STEP 3: RESET WATERMARKS FOR CLEAN RE-EVAL ==========';

UPDATE s
SET s.last_source_watermark_value = NULL,
    s.reprocess_review_pending = 0
FROM dq.rule_execution_state s
JOIN dq.dq_rule_catalog r ON r.rule_id = s.rule_id
WHERE r.object_name = N'Campaign';

PRINT 'All Campaign rule watermarks reset to NULL';
GO

-- ============================================================================
-- STEP 4: RUN FRAMEWORK
-- ============================================================================
-- Campaign is small (~40K rows). A single unboxed pass is fine (@MaxRowsPerRule = 0).
-- ============================================================================
PRINT '========== STEP 4: RUN FRAMEWORK ==========';

EXEC dq.run_incremental_catalog_rules
    @ObjectNameFilter     = N'Campaign',
    @MaxRowsPerRule       = 0,
    @MaxExceptionsPerRule = 50000,
    @ResolveWhenFull      = 1;
GO

-- ============================================================================
-- STEP 5: PROGRESS CHECK — rerun this block any time to monitor
-- ============================================================================
PRINT '========== STEP 5: PROGRESS SNAPSHOT ==========';

SELECT
    r.check_name,
    r.severity,
    s.last_run_status,
    s.last_source_watermark_value,
    ISNULL(dr.check_status, 'NOT RUN')  AS last_status,
    ISNULL(dr.failed_count, 0)          AS failed_count,
    CONVERT(VARCHAR(23), dr.checked_at, 121) AS checked_at
FROM dq.dq_rule_catalog r
JOIN dq.rule_execution_state s ON s.rule_id = r.rule_id
LEFT JOIN (
    SELECT check_name, check_status, failed_count, checked_at,
           ROW_NUMBER() OVER (PARTITION BY check_name ORDER BY checked_at DESC) AS rn
    FROM dq.dq_results WHERE object_name = N'Campaign'
) dr ON dr.check_name = r.check_name AND dr.rn = 1
WHERE r.object_name = N'Campaign'
ORDER BY r.check_name;
GO

-- ============================================================================
-- STANDALONE QUERIES (run any time independently)
-- ============================================================================

-- A: Status of each rule and how far its watermark has advanced
/*
SELECT last_run_status, COUNT(*) AS cnt
FROM dq.rule_execution_state s
JOIN dq.dq_rule_catalog r ON r.rule_id = s.rule_id
WHERE r.object_name = 'Campaign'
GROUP BY last_run_status;
*/

-- B: Force full re-scan of a specific rule, or skip it via is_active=0
/*
UPDATE s SET last_source_watermark_value = NULL, reprocess_review_pending = 0
FROM dq.rule_execution_state s JOIN dq.dq_rule_catalog r ON r.rule_id=s.rule_id
WHERE r.object_name = 'Campaign' AND r.check_name = 'CAM-011';

UPDATE dq.dq_rule_catalog SET is_active = 0
WHERE object_name = 'Campaign' AND check_name = 'CAM-016';
*/

-- C: Open exceptions by rule
/*
SELECT r.check_name, r.severity, COUNT(*) AS open_cnt
FROM dq.dq_exceptions e JOIN dq.dq_rule_catalog r ON r.rule_id=e.rule_id
WHERE r.object_name='Campaign' AND e.resolution_status='OPEN'
GROUP BY r.check_name, r.severity ORDER BY open_cnt DESC;
*/
