/*
================================================================================
RECURRING DONATION — FRAMEWORK MODE: STAGING + DQ (FULL)
================================================================================

Object:       Recurring_Donation
Source:       raw.salesforce_recurring_donation
Staging:      staging.recurring_donation_latest
Rules:        RD-001 to RD-023 (23 rules total via framework)
              Report-only (no assumed value lists — report distinct + ask stakeholders):
              RD-005, RD-010, RD-011, RD-012, RD-013, RD-014, RD-021.
Date:         2026-07-31

Rules added 2026-07-31 after step-by-step data investigation:
  RD-018 Amount numeric guard            (clean, parallels RD-016/017)
  RD-019 Installment_Amount numeric      (clean)
  RD-020 Failed_Payments non-negative #  (clean; raw stored as "1.0" decimals)
  RD-022 Date fields must parse          (clean guard: Start/End/Next)
  RD-023 Active RD must have Next_Payment (REAL: ~90 findings)
Investigated but NOT added as gates (semantic / business-threshold, stakeholder-owned):
  Paid_Amount vs Total_Donation_Amount   -> Total is the recurring amount, Paid is lifetime
  Active RD with >=3 failed payments      -> ~3,286 operational-risk records (monitoring)
  Open type w/ EndDate / Fixed w/o EndDate-> lifecycle semantics need owner confirmation

Staging columns (31):
  Identity/system   : row_number, Id, IsDeleted, Name, CurrencyIsoCode
  Core donor        : npe03__Contact__c, npe03__Organization__c
  Financial         : npe03__Amount__c, npe03__Installment_Amount__c,
                      npe03__Paid_Amount__c, Total_Donation_Amount__c
  Status/lifecycle  : npsp__Status__c, npsp__RecurringType__c,
                      npsp__StartDate__c, npsp__EndDate__c, npsp__ClosedReason__c
  Schedule          : npe03__Installment_Period__c, npsp__Day_of_Month__c,
                      npe03__Next_Payment_Date__c
  Classification    : Donation_Type__c, npsp__PaymentMethod__c,
                      Regional_Office_Code__c
  Reference         : npe03__Recurring_Donation_Campaign__c
  Monitoring        : Number_of_Failed_Payments__c
  ETL metadata      : SystemModstamp, _etl_source, _etl_source_object,
                      _etl_loaded_at_utc, staging_is_duplicate,
                      staging_duplicate_count, staging_created_at

Batch execution:
  @MaxRowsPerRule = 5000 → cap of NEW rows (watermark > cursor) per rule per call;
                           re-run until a run reports 0 rows still behind.
  @MaxRowsPerRule = 0    → no cap (drain all new rows this run).

Progress monitoring:
  SELECT check_name, last_run_status, last_source_watermark_value
  FROM dq.rule_execution_state s
  JOIN dq.dq_rule_catalog r ON r.rule_id=s.rule_id
  WHERE r.object_name='Recurring_Donation'
  ORDER BY check_name;

Force full re-scan of a rule:
  UPDATE s SET last_source_watermark_value=NULL, reprocess_review_pending=0
  FROM dq.rule_execution_state s JOIN dq.dq_rule_catalog r ON r.rule_id=s.rule_id
  WHERE r.object_name='Recurring_Donation' AND r.check_name='RD-008';
  -- Then skip that rule by setting is_active=0 in dq.dq_rule_catalog.

Known limitation:
  RD-008 (Contact referential integrity) will flag ALL records as violations
  because raw.salesforce_contact currently has 0 rows (table not yet loaded).
  RD-008 is seeded with a note but cap kept at 100 exceptions to avoid noise.
================================================================================
*/

USE SalesforceDW;
GO
SET NOCOUNT ON;

-- ============================================================================
-- STEP 1: REBUILD STAGING (30 COLUMNS)
-- ============================================================================
PRINT '========== STEP 1: REBUILD STAGING (30 COLS) ==========';

IF OBJECT_ID(N'[staging].[recurring_donation_latest]', N'U') IS NOT NULL
    DROP TABLE [staging].[recurring_donation_latest];

CREATE TABLE [staging].[recurring_donation_latest]
(
    -- dedup
    [row_number]                           BIGINT,
    -- identity / system
    [Id]                                   NVARCHAR(MAX),
    [IsDeleted]                            NVARCHAR(MAX),
    [Name]                                 NVARCHAR(MAX),
    [CurrencyIsoCode]                      NVARCHAR(MAX),
    -- donor
    [npe03__Contact__c]                    NVARCHAR(MAX),
    [npe03__Organization__c]               NVARCHAR(MAX),
    -- financial
    [npe03__Amount__c]                     NVARCHAR(MAX),
    [npe03__Installment_Amount__c]         NVARCHAR(MAX),
    [npe03__Paid_Amount__c]                NVARCHAR(MAX),
    [Total_Donation_Amount__c]             NVARCHAR(MAX),
    -- status / lifecycle
    [npsp__Status__c]                      NVARCHAR(MAX),
    [npsp__RecurringType__c]               NVARCHAR(MAX),
    [npsp__StartDate__c]                   NVARCHAR(MAX),
    [npsp__EndDate__c]                     NVARCHAR(MAX),
    [npsp__ClosedReason__c]                NVARCHAR(MAX),
    -- schedule
    [npe03__Installment_Period__c]         NVARCHAR(MAX),
    [npsp__Day_of_Month__c]                NVARCHAR(MAX),
    [npe03__Next_Payment_Date__c]          NVARCHAR(MAX),
    -- classification
    [Donation_Type__c]                     NVARCHAR(MAX),
    [npsp__PaymentMethod__c]               NVARCHAR(MAX),
    [Regional_Office_Code__c]              NVARCHAR(MAX),
    -- reference
    [npe03__Recurring_Donation_Campaign__c] NVARCHAR(MAX),
    -- monitoring
    [Number_of_Failed_Payments__c]         NVARCHAR(MAX),
    -- ETL metadata
    [SystemModstamp]                       NVARCHAR(MAX),
    [_etl_source]                          NVARCHAR(MAX),
    [_etl_source_object]                   NVARCHAR(MAX),
    [_etl_loaded_at_utc]                   NVARCHAR(MAX),
    [staging_is_duplicate]                 BIT,
    [staging_duplicate_count]              INT,
    [staging_created_at]                   DATETIME
);
GO

WITH dedup AS
(
    SELECT
        [Id], [IsDeleted], [Name], [CurrencyIsoCode],
        [npe03__Contact__c], [npe03__Organization__c],
        [npe03__Amount__c], [npe03__Installment_Amount__c], [npe03__Paid_Amount__c],
        [Total_Donation_Amount__c],
        [npsp__Status__c], [npsp__RecurringType__c],
        [npsp__StartDate__c], [npsp__EndDate__c], [npsp__ClosedReason__c],
        [npe03__Installment_Period__c], [npsp__Day_of_Month__c], [npe03__Next_Payment_Date__c],
        [Donation_Type__c], [npsp__PaymentMethod__c], [Regional_Office_Code__c],
        [npe03__Recurring_Donation_Campaign__c],
        [Number_of_Failed_Payments__c],
        [SystemModstamp], [_etl_source], [_etl_source_object], [_etl_loaded_at_utc],
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
    FROM [raw].[salesforce_recurring_donation]
    WHERE [Id] IS NOT NULL
)
INSERT INTO [staging].[recurring_donation_latest]
(
    [row_number],
    [Id], [IsDeleted], [Name], [CurrencyIsoCode],
    [npe03__Contact__c], [npe03__Organization__c],
    [npe03__Amount__c], [npe03__Installment_Amount__c], [npe03__Paid_Amount__c],
    [Total_Donation_Amount__c],
    [npsp__Status__c], [npsp__RecurringType__c],
    [npsp__StartDate__c], [npsp__EndDate__c], [npsp__ClosedReason__c],
    [npe03__Installment_Period__c], [npsp__Day_of_Month__c], [npe03__Next_Payment_Date__c],
    [Donation_Type__c], [npsp__PaymentMethod__c], [Regional_Office_Code__c],
    [npe03__Recurring_Donation_Campaign__c],
    [Number_of_Failed_Payments__c],
    [SystemModstamp], [_etl_source], [_etl_source_object], [_etl_loaded_at_utc],
    [staging_is_duplicate], [staging_duplicate_count], [staging_created_at]
)
SELECT
    rn,
    [Id], [IsDeleted], [Name], [CurrencyIsoCode],
    [npe03__Contact__c], [npe03__Organization__c],
    [npe03__Amount__c], [npe03__Installment_Amount__c], [npe03__Paid_Amount__c],
    [Total_Donation_Amount__c],
    [npsp__Status__c], [npsp__RecurringType__c],
    [npsp__StartDate__c], [npsp__EndDate__c], [npsp__ClosedReason__c],
    [npe03__Installment_Period__c], [npsp__Day_of_Month__c], [npe03__Next_Payment_Date__c],
    [Donation_Type__c], [npsp__PaymentMethod__c], [Regional_Office_Code__c],
    [npe03__Recurring_Donation_Campaign__c],
    [Number_of_Failed_Payments__c],
    [SystemModstamp], [_etl_source], [_etl_source_object], [_etl_loaded_at_utc],
    CASE WHEN dup_cnt > 1 THEN 1 ELSE 0 END,
    CASE WHEN dup_cnt > 1 THEN dup_cnt ELSE 0 END,
    GETUTCDATE()
FROM dedup
WHERE rn = 1
  AND COALESCE(LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), [IsDeleted])))), N'false')
      NOT IN (N'true', N'1', N'yes', N'y');

DECLARE @stg_cnt BIGINT = (SELECT COUNT(*) FROM [staging].[recurring_donation_latest]);
PRINT 'Staging rows loaded: ' + CAST(@stg_cnt AS VARCHAR(30));
GO

-- ============================================================================
-- STEP 2: SEED / UPDATE ALL RULES (RD-001 to RD-023) — SAFE MERGE
-- ============================================================================
PRINT '========== STEP 2: SEED RULES RD-001..023 ==========';

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

-- RD-001: Id must not be null (NOT_NULL type — handled by framework built-in)
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-001', N'NOT_NULL',
    N'Id', N'CRITICAL', N'Recurring Donation Id must not be null or blank',
    NULL, N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-002: Id must be valid 18-char Salesforce ID
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-002', N'VALID_SALESFORCE_ID',
    N'Id', N'CRITICAL', N'Recurring Donation Id must be 15 or 18 characters',
    NULL, N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-003: Contact or Organization must be populated
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-003', N'CUSTOM_SQL',
    NULL, N'HIGH', N'At least one of Contact or Organization must be populated',
    N'SELECT [Id] AS record_id, '
    + N'CONCAT(N''Contact='',COALESCE([npe03__Contact__c],N''NULL''),N'';Org='',COALESCE([npe03__Organization__c],N''NULL'')) AS exception_value, '
    + N'N''Both Contact and Organization are null'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([npe03__Contact__c],N''''))),N'''') IS NULL '
    + N'AND NULLIF(LTRIM(RTRIM(COALESCE([npe03__Organization__c],N''''))),N'''') IS NULL',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 0   -- DEFERRED: needs donor/Contact data (off for now)
),
-- RD-004: Active RD must have Amount > 0
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-004', N'CUSTOM_SQL',
    N'npe03__Amount__c', N'HIGH', N'Active recurring donation must have amount > 0',
    N'SELECT [Id] AS record_id, [npe03__Amount__c] AS exception_value, '
    + N'N''Active RD has null or non-positive amount'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE UPPER(LTRIM(RTRIM(COALESCE([npsp__Status__c],N'''')))) = N''ACTIVE'' '
    + N'AND (TRY_CONVERT(DECIMAL(18,2),[npe03__Amount__c]) IS NULL OR TRY_CONVERT(DECIMAL(18,2),[npe03__Amount__c]) <= 0)',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-006: Day of month validity
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-006', N'CUSTOM_SQL',
    N'npsp__Day_of_Month__c', N'MEDIUM', N'npsp__Day_of_Month__c must be 1-31 or Last_Day when populated',
    N'SELECT [Id] AS record_id, [npsp__Day_of_Month__c] AS exception_value, '
    + N'N''Day_of_Month outside valid range'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([npsp__Day_of_Month__c],N''''))),N'''') IS NOT NULL '
    + N'AND NOT (UPPER(LTRIM(RTRIM([npsp__Day_of_Month__c])))=N''LAST_DAY'' OR TRY_CONVERT(INT,[npsp__Day_of_Month__c]) BETWEEN 1 AND 31)',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-007: StartDate must be <= EndDate
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-007', N'CUSTOM_SQL',
    NULL, N'HIGH', N'npsp__StartDate__c must not be after npsp__EndDate__c when both populated',
    N'SELECT [Id] AS record_id, '
    + N'CONCAT(N''Start='', [npsp__StartDate__c], N'';End='', [npsp__EndDate__c]) AS exception_value, '
    + N'N''StartDate is after EndDate'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([npsp__StartDate__c],N''''))),N'''') IS NOT NULL '
    + N'AND NULLIF(LTRIM(RTRIM(COALESCE([npsp__EndDate__c],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DATETIME2,[npsp__StartDate__c]) > TRY_CONVERT(DATETIME2,[npsp__EndDate__c])',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-008: Contact referential integrity — NOTE: raw.salesforce_contact is currently empty.
--         Cap set to 100 to avoid flooding. Re-enable at full capacity once Contact is loaded.
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-008', N'CUSTOM_SQL',
    N'npe03__Contact__c', N'HIGH',
    N'npe03__Contact__c must exist in raw.salesforce_contact when populated — NOTE: contact table currently empty, result is informational only',
    N'SELECT TOP 100 rd.[Id] AS record_id, rd.[npe03__Contact__c] AS exception_value, '
    + N'N''Contact ID not found in raw.salesforce_contact'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} rd '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE(rd.[npe03__Contact__c],N''''))),N'''') IS NOT NULL '
    + N'AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_contact] c WHERE LTRIM(RTRIM(c.[Id]))=LTRIM(RTRIM(rd.[npe03__Contact__c])))',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 0   -- DEFERRED: raw.salesforce_contact not loaded (off for now)
),
-- RD-009: Campaign referential integrity
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-009', N'CUSTOM_SQL',
    N'npe03__Recurring_Donation_Campaign__c', N'MEDIUM',
    N'npe03__Recurring_Donation_Campaign__c must exist in raw.salesforce_campaign when populated',
    N'SELECT rd.[Id] AS record_id, rd.[npe03__Recurring_Donation_Campaign__c] AS exception_value, '
    + N'N''Campaign ID not found in raw.salesforce_campaign'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} rd '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE(rd.[npe03__Recurring_Donation_Campaign__c],N''''))),N'''') IS NOT NULL '
    + N'AND NOT EXISTS (SELECT 1 FROM [raw].[salesforce_campaign] c WHERE LTRIM(RTRIM(c.[Id]))=LTRIM(RTRIM(rd.[npe03__Recurring_Donation_Campaign__c])))',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-015: Closed RD should have ClosedReason
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-015', N'CUSTOM_SQL',
    N'npsp__ClosedReason__c', N'MEDIUM',
    N'Closed recurring donation should have npsp__ClosedReason__c populated',
    N'SELECT [Id] AS record_id, [npsp__ClosedReason__c] AS exception_value, '
    + N'N''Closed RD missing ClosedReason'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE UPPER(LTRIM(RTRIM(COALESCE([npsp__Status__c],N'''')))) = N''CLOSED'' '
    + N'AND NULLIF(LTRIM(RTRIM(COALESCE([npsp__ClosedReason__c],N''''))),N'''') IS NULL',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-016: npe03__Paid_Amount__c must be numeric when populated
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-016', N'CUSTOM_SQL',
    N'npe03__Paid_Amount__c', N'HIGH',
    N'npe03__Paid_Amount__c must be numeric when populated',
    N'SELECT [Id] AS record_id, [npe03__Paid_Amount__c] AS exception_value, '
    + N'N''npe03__Paid_Amount__c is not numeric'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([npe03__Paid_Amount__c],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DECIMAL(18,2),[npe03__Paid_Amount__c]) IS NULL',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-017: Total_Donation_Amount__c must be numeric when populated
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-017', N'CUSTOM_SQL',
    N'Total_Donation_Amount__c', N'HIGH',
    N'Total_Donation_Amount__c must be numeric when populated',
    N'SELECT [Id] AS record_id, [Total_Donation_Amount__c] AS exception_value, '
    + N'N''Total_Donation_Amount__c is not numeric'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([Total_Donation_Amount__c],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DECIMAL(18,2),[Total_Donation_Amount__c]) IS NULL',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-018: npe03__Amount__c must be numeric when populated (guard, parallels RD-016/017)
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-018', N'CUSTOM_SQL',
    N'npe03__Amount__c', N'HIGH',
    N'npe03__Amount__c must be numeric when populated',
    N'SELECT [Id] AS record_id, [npe03__Amount__c] AS exception_value, '
    + N'N''npe03__Amount__c is not numeric'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([npe03__Amount__c],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DECIMAL(18,2),[npe03__Amount__c]) IS NULL',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-019: npe03__Installment_Amount__c must be numeric when populated
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-019', N'CUSTOM_SQL',
    N'npe03__Installment_Amount__c', N'MEDIUM',
    N'npe03__Installment_Amount__c must be numeric when populated',
    N'SELECT [Id] AS record_id, [npe03__Installment_Amount__c] AS exception_value, '
    + N'N''npe03__Installment_Amount__c is not numeric'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([npe03__Installment_Amount__c],N''''))),N'''') IS NOT NULL '
    + N'AND TRY_CONVERT(DECIMAL(18,2),[npe03__Installment_Amount__c]) IS NULL',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-020: Number_of_Failed_Payments__c must be a non-negative number when populated
--         (raw values are decimal strings like "1.0"; use DECIMAL not INT)
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-020', N'CUSTOM_SQL',
    N'Number_of_Failed_Payments__c', N'MEDIUM',
    N'Number_of_Failed_Payments__c must be a non-negative number when populated',
    N'SELECT [Id] AS record_id, [Number_of_Failed_Payments__c] AS exception_value, '
    + N'N''Number_of_Failed_Payments__c is not a non-negative number'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([Number_of_Failed_Payments__c],N''''))),N'''') IS NOT NULL '
    + N'AND (TRY_CONVERT(DECIMAL(18,4),[Number_of_Failed_Payments__c]) IS NULL OR TRY_CONVERT(DECIMAL(18,4),[Number_of_Failed_Payments__c]) < 0)',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-022: date fields must be parseable when populated (Start/End/Next)
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-022', N'CUSTOM_SQL',
    NULL, N'MEDIUM',
    N'StartDate, EndDate and Next_Payment_Date must be valid dates when populated',
    N'SELECT [Id] AS record_id, '
    + N'CONCAT(N''Start='',COALESCE([npsp__StartDate__c],N''NULL''),N'';End='',COALESCE([npsp__EndDate__c],N''NULL''),N'';Next='',COALESCE([npe03__Next_Payment_Date__c],N''NULL'')) AS exception_value, '
    + N'N''One or more date fields cannot be parsed'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE (NULLIF(LTRIM(RTRIM(COALESCE([npsp__StartDate__c],N''''))),N'''') IS NOT NULL AND TRY_CONVERT(DATETIME2,[npsp__StartDate__c]) IS NULL) '
    + N'OR (NULLIF(LTRIM(RTRIM(COALESCE([npsp__EndDate__c],N''''))),N'''') IS NOT NULL AND TRY_CONVERT(DATETIME2,[npsp__EndDate__c]) IS NULL) '
    + N'OR (NULLIF(LTRIM(RTRIM(COALESCE([npe03__Next_Payment_Date__c],N''''))),N'''') IS NOT NULL AND TRY_CONVERT(DATETIME2,[npe03__Next_Payment_Date__c]) IS NULL)',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- RD-023: Active recurring donation must have a Next_Payment_Date scheduled (REAL findings)
(
    N'Recurring_Donation', N'staging.recurring_donation_latest', N'RD-023', N'CUSTOM_SQL',
    N'npe03__Next_Payment_Date__c', N'HIGH',
    N'Active recurring donation must have a Next_Payment_Date scheduled',
    N'SELECT [Id] AS record_id, '
    + N'CONCAT(N''Status='',COALESCE([npsp__Status__c],N''NULL''),N'';Next=NULL'') AS exception_value, '
    + N'N''Active RD has no Next_Payment_Date'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE UPPER(LTRIM(RTRIM(COALESCE([npsp__Status__c],N''''))) ) = N''ACTIVE'' '
    + N'AND NULLIF(LTRIM(RTRIM(COALESCE([npe03__Next_Payment_Date__c],N''''))),N'''') IS NULL',
    N'RD_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
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
--         (RD-001/002 were already checked against old staging — force recheck)
-- ============================================================================
PRINT '========== STEP 3: RESET WATERMARKS FOR CLEAN RE-EVAL ==========';

UPDATE s
SET s.last_source_watermark_value = NULL,
    s.reprocess_review_pending = 0
FROM dq.rule_execution_state s
JOIN dq.dq_rule_catalog r ON r.rule_id = s.rule_id
WHERE r.object_name = N'Recurring_Donation';

PRINT 'All Recurring_Donation rule watermarks reset to NULL';
GO

-- ============================================================================
-- STEP 4: RUN FRAMEWORK — BATCH-SAFE
-- ============================================================================
-- This is a 258K-row table. Use @MaxRowsPerRule = 5000 for time-boxed passes.
-- Re-run STEP 4 until a run reports 0 rows still behind (status CAUGHT_UP).
-- For a full unboxed run: set @MaxRowsPerRule = 0.
-- ============================================================================
PRINT '========== STEP 4: RUN FRAMEWORK ==========';

EXEC dq.run_incremental_catalog_rules
    @ObjectNameFilter     = N'Recurring_Donation',
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
    FROM dq.dq_results WHERE object_name = N'Recurring_Donation'
) dr ON dr.check_name = r.check_name AND dr.rn = 1
WHERE r.object_name = N'Recurring_Donation'
ORDER BY r.check_name;
GO

-- ============================================================================
-- STANDALONE QUERIES (run any time independently)
-- ============================================================================

-- A: Progress check — status of each rule and how far its watermark has advanced
/*
SELECT last_run_status, COUNT(*) AS cnt
FROM dq.rule_execution_state s
JOIN dq.dq_rule_catalog r ON r.rule_id = s.rule_id
WHERE r.object_name = 'Recurring_Donation'
GROUP BY last_run_status;
*/

-- B: Force full re-scan of a specific rule, or skip it via is_active=0
/*
UPDATE s SET last_source_watermark_value = NULL, reprocess_review_pending = 0
FROM dq.rule_execution_state s JOIN dq.dq_rule_catalog r ON r.rule_id=s.rule_id
WHERE r.object_name = 'Recurring_Donation' AND r.check_name = 'RD-008';

UPDATE dq.dq_rule_catalog SET is_active = 0
WHERE object_name = 'Recurring_Donation' AND check_name = 'RD-008';
*/

-- C: Open exceptions by rule
/*
SELECT r.check_name, r.severity, COUNT(*) AS open_cnt
FROM dq.dq_exceptions e JOIN dq.dq_rule_catalog r ON r.rule_id=e.rule_id
WHERE r.object_name='Recurring_Donation' AND e.resolution_status='OPEN'
GROUP BY r.check_name, r.severity ORDER BY open_cnt DESC;
*/

-- D: Timing audit — when did each rule last run?
/*
SELECT object_name,
       COUNT(DISTINCT check_name) AS rules_run,
       MIN(checked_at)            AS first_run,
       MAX(checked_at)            AS last_run,
       DATEDIFF(SECOND, MIN(checked_at), MAX(checked_at)) AS span_sec
FROM dq.dq_results
WHERE object_name = 'Recurring_Donation'
GROUP BY object_name;
*/
