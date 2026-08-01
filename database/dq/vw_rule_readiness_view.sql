/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   VIEW [dq].[vw_rule_readiness]
AS
WITH rule_base AS
(
    SELECT
        r.rule_id,
        r.object_name,
        r.source_view,
        r.check_name,
        r.check_type,
        r.target_column,
        r.severity,
        r.description,
        r.is_active,
        r.rule_source,
        r.approval_status,
        r.process_name,
        r.rule_definition,

        OBJECT_ID(r.source_view) AS source_object_id

    FROM dq.dq_rule_catalog AS r
),
mapping_choice AS
(
    SELECT
        base.*,

        mapping.field_mapping_id,
        mapping.salesforce_api_field,
        mapping.mapping_status,

        CASE
            WHEN mapping.mapping_status = N'Confirmed'
             AND NULLIF
                 (
                     LTRIM(RTRIM(mapping.salesforce_api_field)),
                     N''
                 ) IS NOT NULL
                THEN mapping.salesforce_api_field

            WHEN direct_column.column_name IS NOT NULL
                THEN base.target_column

            ELSE NULL
        END AS resolved_column

    FROM rule_base AS base

    OUTER APPLY
    (
        SELECT TOP (1)
            fm.field_mapping_id,
            fm.salesforce_api_field,
            fm.mapping_status

        FROM dq.field_mapping AS fm

        WHERE fm.business_object = base.object_name
          AND fm.business_field = base.target_column
          AND fm.source_object = base.source_view

        ORDER BY
            CASE fm.mapping_status
                WHEN N'Confirmed' THEN 1
                WHEN N'System Suggested - Review' THEN 2
                ELSE 3
            END,
            fm.field_mapping_id
    ) AS mapping

    OUTER APPLY
    (
        SELECT TOP (1)
            c.name AS column_name

        FROM sys.columns AS c

        WHERE c.object_id = base.source_object_id
          AND c.name = base.target_column
    ) AS direct_column
)
SELECT
    rule_id,
    object_name,
    source_view,
    check_name,
    check_type,
    target_column,
    resolved_column,

    field_mapping_id,
    mapping_status,

    severity,
    is_active,
    rule_source,
    approval_status,
    process_name,
    rule_definition,

    CASE
        WHEN source_object_id IS NULL
            THEN N'MISSING_SOURCE_OBJECT'

        WHEN resolved_column IS NULL
            THEN N'MISSING_CONFIRMED_MAPPING'

        WHEN is_active = 1
            THEN N'ACTIVE'

        WHEN approval_status NOT LIKE N'Approved%'
         AND approval_status NOT LIKE N'Active%'
            THEN N'PENDING_BUSINESS_APPROVAL'

        WHEN check_type IN
             (
                 N'NOT_NULL',
                 N'VALID_DATETIME',
                 N'VALID_SALESFORCE_ID'
             )
            THEN N'READY_FOR_DYNAMIC_EXECUTION'

        WHEN check_type IN
             (
                 N'FORMAT',
                 N'CONTROLLED_VALUE',
                 N'CONDITIONAL_REQUIRED',
                 N'CROSS_FIELD_REQUIRED',
                 N'DUPLICATE_MATCH',
                 N'CROSS_OBJECT_VALIDATION',
                 N'BUSINESS_CLASSIFICATION'
             )
            THEN N'REQUIRES_RULE_PARAMETERS'

        ELSE N'UNSUPPORTED_CHECK_TYPE'
    END AS readiness_status,

    CASE
        WHEN source_object_id IS NULL
            THEN N'The configured source table or view does not exist.'

        WHEN resolved_column IS NULL
            THEN N'Confirm the Salesforce API field in dq.field_mapping.'

        WHEN is_active = 1
            THEN N'The rule is already active.'

        WHEN approval_status NOT LIKE N'Approved%'
         AND approval_status NOT LIKE N'Active%'
            THEN N'The rule requires process-owner approval.'

        WHEN check_type IN
             (
                 N'NOT_NULL',
                 N'VALID_DATETIME',
                 N'VALID_SALESFORCE_ID'
             )
            THEN N'The generic engine can generate this rule automatically.'

        WHEN check_type = N'FORMAT'
            THEN N'The expected format or pattern must be configured.'

        WHEN check_type = N'CONTROLLED_VALUE'
            THEN N'The approved value list must be configured.'

        WHEN check_type = N'CONDITIONAL_REQUIRED'
            THEN N'The triggering condition must be configured.'

        WHEN check_type = N'CROSS_FIELD_REQUIRED'
            THEN N'The related field and logical condition must be configured.'

        WHEN check_type = N'DUPLICATE_MATCH'
            THEN N'The match fields and normalization method must be configured.'

        WHEN check_type = N'CROSS_OBJECT_VALIDATION'
            THEN N'The related object, join columns, and validation condition must be configured.'

        WHEN check_type = N'BUSINESS_CLASSIFICATION'
            THEN N'The business classification logic must be configured.'

        ELSE N'The check type has no dynamic execution template.'
    END AS readiness_message

FROM mapping_choice;
GO
