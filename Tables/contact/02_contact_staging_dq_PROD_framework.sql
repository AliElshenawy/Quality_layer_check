/*
================================================================================
CONTACT — FRAMEWORK MODE: STAGING + DQ (FULL)
================================================================================

Object:       Contact
Source:       raw.salesforce_contact  (1,901,058 rows, 526 cols, 32 deleted)
Staging:      staging.contact_latest
Rules:        CON-001 .. CON-009 (9 rules total via framework)
Date:         2026-08-05
Owner:        Data Engineering
Status:       First build. Client validation rules incorporated (see below).

How to run (SSMS):
  Open this file against SalesforceDW and Execute. Steps 1-4 rebuild staging,
  seed/refresh the 9 CON rules (idempotent MERGE), reset watermarks, and run the
  incremental catalog runner. Step 5 is a re-runnable progress snapshot.

Client validation rules mapped (source: Human Appeal):
  Donor_Mailing_Address_Required            -> CON-004 (core four; State report-only)
  Check_if_Gift_Aid_Validation_is_correct   -> CON-007 (Gift Aid Yes/No only)
  Email_Field_is_Significant                -> CON-005 (Email required)

Rule check types (must match dq.dq_rule_catalog):
  Built-in : CON-001 NOT_NULL, CON-002 VALID_SALESFORCE_ID, CON-003 NOT_NULL,
             CON-009 VALID_BOOLEAN
  CUSTOM_SQL: CON-004, CON-005, CON-006, CON-007, CON-008

Governance / report-only notes (see 03_..._ANALYSIS.md):
  - CON-007 gates Gift_Aid_Status__c values that are PRESENT but not Yes/No
    (i.e. 'Unspecified' = 352,838). NULL/blank is NOT gated (report-only per DQ policy).
    Yes/No is the client-approved authoritative list.
  - MailingState (88.55% empty) is deliberately NOT enforced by CON-004; report-only
    until stakeholders confirm State is mandatory.
  - External_Id__c duplicates (8 groups / 16 rows) are a report-only finding, kept out
    of the framework to avoid a 1.9M-row self-join.

Progress monitoring:
  SELECT check_name, last_run_status, last_source_watermark_value
  FROM dq.rule_execution_state s
  JOIN dq.dq_rule_catalog r ON r.rule_id=s.rule_id
  WHERE r.object_name='Contact' ORDER BY check_name;

Force full re-scan of a rule:
  UPDATE s SET last_source_watermark_value=NULL, reprocess_review_pending=0
  FROM dq.rule_execution_state s JOIN dq.dq_rule_catalog r ON r.rule_id=s.rule_id
  WHERE r.object_name='Contact' AND r.check_name='CON-005';
================================================================================
*/

USE SalesforceDW;
GO
SET NOCOUNT ON;

-- ============================================================================
-- STEP 1: BUILD STAGING (INCREMENTAL — no DROP)
--   Persistent table + incremental builder are the canonical files:
--     database/staging/contact_latest_table.sql  (IF NOT EXISTS table + Id18)
--     database/staging/contact_latest_SP.sql      (staging.refresh_contact_latest)
--   Deploy those first (via _deploy.sql); this step only refreshes incrementally.
-- ============================================================================
PRINT '========== STEP 1: BUILD STAGING (incremental) ==========';

EXEC staging.refresh_contact_latest;   -- add @FullRebuild = 1 only for a deliberate reset

DECLARE @stg_cnt BIGINT = (SELECT COUNT(*) FROM [staging].[contact_latest]);
PRINT 'Staging rows: ' + CAST(@stg_cnt AS VARCHAR(30));
GO

-- ============================================================================
-- STEP 2: SEED / UPDATE ALL RULES (CON-001..009) — SAFE MERGE
-- ============================================================================
PRINT '========== STEP 2: SEED RULES CON-001..009 ==========';

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

-- CON-001: Id must not be null (built-in NOT_NULL)
(
    N'Contact', N'staging.contact_latest', N'CON-001', N'NOT_NULL',
    N'Id', N'CRITICAL', N'Contact Id must not be null or blank',
    NULL, N'CON_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-002: Id must be a valid Salesforce Id (built-in)
(
    N'Contact', N'staging.contact_latest', N'CON-002', N'VALID_SALESFORCE_ID',
    N'Id', N'CRITICAL', N'Contact Id must be 15 or 18 characters',
    NULL, N'CON_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-003: LastName must not be null (built-in NOT_NULL) — required on all channels
(
    N'Contact', N'staging.contact_latest', N'CON-003', N'NOT_NULL',
    N'LastName', N'HIGH', N'Contact LastName must not be null or blank (required on all channels)',
    NULL, N'CON_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-004: Mailing address required — core four (Street, City, PostalCode, Country).
--          Client rule Donor_Mailing_Address_Required. State excluded (88.55% empty; report-only).
(
    N'Contact', N'staging.contact_latest', N'CON-004', N'CUSTOM_SQL',
    NULL, N'HIGH', N'Mailing address incomplete: Street, City, PostalCode or Country missing (client: Donor_Mailing_Address_Required; State report-only)',
    N'SELECT [Id] AS record_id, '
    + N'CONCAT(N''Street='',ISNULL([MailingStreet],N''(null)''),N'';City='',ISNULL([MailingCity],N''(null)''),N'';Postal='',ISNULL([MailingPostalCode],N''(null)''),N'';Country='',ISNULL([MailingCountry],N''(null)'')) AS exception_value, '
    + N'N''Mailing address incomplete (missing Street/City/PostalCode/Country)'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([MailingStreet],N''''))),N'''') IS NULL '
    + N'OR NULLIF(LTRIM(RTRIM(COALESCE([MailingCity],N''''))),N'''') IS NULL '
    + N'OR NULLIF(LTRIM(RTRIM(COALESCE([MailingPostalCode],N''''))),N'''') IS NULL '
    + N'OR NULLIF(LTRIM(RTRIM(COALESCE([MailingCountry],N''''))),N'''') IS NULL',
    N'CON_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-005: Email required — client rule Email_Field_is_Significant
(
    N'Contact', N'staging.contact_latest', N'CON-005', N'CUSTOM_SQL',
    N'Email', N'HIGH', N'Email is required (client: Email_Field_is_Significant); also the primary matching key',
    N'SELECT [Id] AS record_id, ISNULL([Email],N''(null)'') AS exception_value, '
    + N'N''Email is missing (required field / primary match key)'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([Email],N''''))),N'''') IS NULL',
    N'CON_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-006: Email format invalid when present (engineering-safe, mechanical)
(
    N'Contact', N'staging.contact_latest', N'CON-006', N'CUSTOM_SQL',
    N'Email', N'MEDIUM', N'Email present but not a valid x@y.z format (no @, no dot, or contains space)',
    N'SELECT [Id] AS record_id, [Email] AS exception_value, '
    + N'N''Email present but fails basic format check'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([Email],N''''))),N'''') IS NOT NULL '
    + N'AND (LTRIM(RTRIM([Email])) NOT LIKE N''%_@_%.__%'' OR LTRIM(RTRIM([Email])) LIKE N''% %'')',
    N'CON_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-007: Gift Aid Status may only be Yes or No — client rule.
--          Flags PRESENT values not in (Yes,No) (i.e. 'Unspecified'). NULL/blank NOT gated (report-only).
(
    N'Contact', N'staging.contact_latest', N'CON-007', N'CUSTOM_SQL',
    N'Gift_Aid_Status__c', N'MEDIUM', N'Gift Aid Status must be Yes or No when set (client: Check_if_Gift_Aid_Validation_is_correct). NULL/blank not gated.',
    N'SELECT [Id] AS record_id, [Gift_Aid_Status__c] AS exception_value, '
    + N'N''Gift Aid Status is set to a value other than Yes/No'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([Gift_Aid_Status__c],N''''))),N'''') IS NOT NULL '
    + N'AND LOWER(LTRIM(RTRIM([Gift_Aid_Status__c]))) NOT IN (N''yes'', N''no'')',
    N'CON_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-008: External_Id__c missing (matching-key completeness)
(
    N'Contact', N'staging.contact_latest', N'CON-008', N'CUSTOM_SQL',
    N'External_Id__c', N'MEDIUM', N'External_Id__c missing — integration matching/dedup key is blank',
    N'SELECT [Id] AS record_id, N''(null)'' AS exception_value, '
    + N'N''External_Id__c is missing (duplicate-prevention key)'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE NULLIF(LTRIM(RTRIM(COALESCE([External_Id__c],N''''))),N'''') IS NULL',
    N'CON_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-VR-001: Mobile must not contain a comma (Salesforce VR: Comma_Not_Allowed_Mobile).
(
    N'Contact', N'staging.contact_latest', N'CON-VR-001', N'CUSTOM_SQL',
    N'MobilePhone', N'LOW', N'MobilePhone contains a comma (client VR: Comma_Not_Allowed_Mobile) — use semicolons to separate multiple numbers',
    N'SELECT [Id] AS record_id, [MobilePhone] AS exception_value, '
    + N'N''MobilePhone contains a comma'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE [MobilePhone] LIKE N''%,%''',
    N'CON_VALIDATION_RULE', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-VR-002: MailingCity must not contain a comma (Salesforce VR: Comma_Not_Allowed_MailingCity).
(
    N'Contact', N'staging.contact_latest', N'CON-VR-002', N'CUSTOM_SQL',
    N'MailingCity', N'LOW', N'MailingCity contains a comma (client VR: Comma_Not_Allowed_MailingCity) — use semicolons instead',
    N'SELECT [Id] AS record_id, [MailingCity] AS exception_value, '
    + N'N''MailingCity contains a comma'' AS exception_details, NULL AS etl_run_id '
    + N'FROM {{SOURCE_VIEW}} '
    + N'WHERE [MailingCity] LIKE N''%,%''',
    N'CON_VALIDATION_RULE', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-VR-003: Guardian Id must not contain a comma (Salesforce VR: Comma_Not_Allowed_Guardian_Id).
(
    N'Contact', N'staging.contact_latest', N'CON-VR-003', N'CUSTOM_SQL',
    N'Guardian_ID__c', N'LOW', N'Guardian_ID__c contains a comma (client VR: Comma_Not_Allowed_Guardian_Id)',
    N'SELECT [Id] AS record_id, [Guardian_ID__c] AS exception_value, N''Guardian_ID__c contains a comma'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE [Guardian_ID__c] LIKE N''%,%''',
    N'CON_VALIDATION_RULE', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-VR-004: if Mother is not the guardian, guardian details must be complete (Salesforce VR: If_Mother_Is_Guardian_is_False).
(
    N'Contact', N'staging.contact_latest', N'CON-VR-004', N'CUSTOM_SQL',
    N'Orphan_Mother_Is_Guardian__c', N'MEDIUM', N'Mother not guardian but guardian details incomplete (client VR: If_Mother_Is_Guardian_is_False)',
    N'SELECT [Id] AS record_id, CONCAT(N''GFirst='',COALESCE([Orphan_Guardian_First_Name__c],N''(null)''),N'';GLast='',COALESCE([Oprhan_Guardian_Last_Name__c],N''(null)''),N'';Rel='',COALESCE([Orphan_Guardian_Relationship__c],N''(null)''),N'';Reason='',COALESCE([Orphan_Mother_Not_Guardian_Reason__c],N''(null)'')) AS exception_value, N''Mother not guardian but guardian details incomplete'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE LOWER(LTRIM(RTRIM([Orphan_Mother_Is_Guardian__c]))) = N''no'' AND (NULLIF(LTRIM(RTRIM(COALESCE([Orphan_Guardian_First_Name__c],N''''))),N'''') IS NULL OR NULLIF(LTRIM(RTRIM(COALESCE([Oprhan_Guardian_Last_Name__c],N''''))),N'''') IS NULL OR NULLIF(LTRIM(RTRIM(COALESCE([Orphan_Guardian_Relationship__c],N''''))),N'''') IS NULL OR NULLIF(LTRIM(RTRIM(COALESCE([Orphan_Mother_Not_Guardian_Reason__c],N''''))),N'''') IS NULL)',
    N'CON_VALIDATION_RULE', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-VR-005: if Mother is not alive, death details must be complete (Salesforce VR: IF_Mother_not_alive).
(
    N'Contact', N'staging.contact_latest', N'CON-VR-005', N'CUSTOM_SQL',
    N'Orphan_Is_Mother_Alive__c', N'MEDIUM', N'Mother not alive but death details incomplete (client VR: IF_Mother_not_alive)',
    N'SELECT [Id] AS record_id, CONCAT(N''Cause='',COALESCE([Orphan_Mothers_Cause_Of_Death__c],N''(null)''),N'';DoD='',COALESCE([Orphan_Mothers_Date_Of_Death__c],N''(null)''),N'';Method='',COALESCE([Orphan_Mother_Death_Verification_Method__c],N''(null)'')) AS exception_value, N''Mother not alive but death details incomplete'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE LOWER(LTRIM(RTRIM([Orphan_Is_Mother_Alive__c]))) = N''no'' AND (NULLIF(LTRIM(RTRIM(COALESCE([Orphan_Mothers_Cause_Of_Death__c],N''''))),N'''') IS NULL OR NULLIF(LTRIM(RTRIM(COALESCE([Orphan_Mothers_Date_Of_Death__c],N''''))),N'''') IS NULL OR NULLIF(LTRIM(RTRIM(COALESCE([Orphan_Mother_Death_Verification_Method__c],N''''))),N'''') IS NULL)',
    N'CON_VALIDATION_RULE', N'Approved', N'DQ_FRAMEWORK', 1
),
-- CON-009: IsDeleted must be a valid boolean token (built-in VALID_BOOLEAN)
--          Runs on staging (deleted rows already excluded) so expected ~0 here.
(
    N'Contact', N'staging.contact_latest', N'CON-009', N'VALID_BOOLEAN',
    N'IsDeleted', N'HIGH', N'IsDeleted must be a true/false token',
    NULL, N'CON_FRAMEWORK', N'Approved', N'DQ_FRAMEWORK', 1
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
--         (No-op on first run — state rows are created by the runner in STEP 4.)
-- ============================================================================
PRINT '========== STEP 3: RESET WATERMARKS FOR CLEAN RE-EVAL ==========';

UPDATE s
SET s.last_source_watermark_value = NULL,
    s.reprocess_review_pending = 0
FROM dq.rule_execution_state s
JOIN dq.dq_rule_catalog r ON r.rule_id = s.rule_id
WHERE r.object_name = N'Contact';

PRINT 'Contact rule watermarks reset (rows affected shown above; 0 on first run)';
GO

-- ============================================================================
-- STEP 4: RUN FRAMEWORK
--   Contact is large (~1.9M rows). @MaxRowsPerRule = 0 => single full pass per rule.
--   @MaxExceptionsPerRule sized to capture the full address/email/gift-aid populations.
-- ============================================================================
PRINT '========== STEP 4: RUN FRAMEWORK ==========';

EXEC dq.run_incremental_catalog_rules
    @ObjectNameFilter     = N'Contact',
    @MaxRowsPerRule       = 0,
    @MaxExceptionsPerRule = 500000,
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
    FROM dq.dq_results WHERE object_name = N'Contact'
) dr ON dr.check_name = r.check_name AND dr.rn = 1
WHERE r.object_name = N'Contact'
ORDER BY r.check_name;
GO

-- Open exceptions summary (official layer)
SELECT r.check_name, r.severity, COUNT(*) AS open_exceptions
FROM dq.dq_exceptions e
JOIN dq.dq_rule_catalog r ON r.rule_id = e.rule_id
WHERE r.object_name = N'Contact' AND e.resolution_status = 'OPEN'
GROUP BY r.check_name, r.severity
ORDER BY open_exceptions DESC;
GO
