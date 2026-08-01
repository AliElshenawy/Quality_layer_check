/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dq].[suggest_field_mappings]
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH mapping_base AS
    (
        SELECT
            fm.field_mapping_id,
            fm.business_object,
            fm.business_field,
            fm.source_object,
            fm.salesforce_api_field,
            fm.mapping_status,
            fm.notes,

            COALESCE
            (
                PARSENAME(fm.source_object, 2),
                N'staging'
            ) AS source_schema,

            PARSENAME
            (
                fm.source_object,
                1
            ) AS source_name,

            LOWER
            (
                REPLACE
                (
                    REPLACE
                    (
                        REPLACE
                        (
                            REPLACE
                            (
                                fm.business_field,
                                N' ',
                                N''
                            ),
                            N'_',
                            N''
                        ),
                        N'-',
                        N''
                    ),
                    N'/',
                    N''
                )
            ) AS normalized_business_field,

            LOWER
            (
                COALESCE
                (
                    fm.notes,
                    N''
                )
            ) AS normalized_notes

        FROM dq.field_mapping AS fm

        WHERE NULLIF
              (
                  LTRIM
                  (
                      RTRIM
                      (
                          fm.salesforce_api_field
                      )
                  ),
                  N''
              ) IS NULL
    ),

    candidate_columns AS
    (
        SELECT
            mappings.field_mapping_id,
            mappings.business_object,
            mappings.business_field,
            mappings.source_object,
            mappings.mapping_status,
            mappings.notes,

            columns_source.name AS suggested_api_field,

            CASE
                /*
                    The notes explicitly mention the Salesforce
                    column, such as "Usually MailingPostalCode".
                */
                WHEN LEN(columns_source.name) >= 4
                 AND mappings.normalized_notes LIKE
                     N'%'
                     + LOWER(columns_source.name)
                     + N'%'
                    THEN 110

                /* Exact normalized name match */
                WHEN normalized_column.normalized_column_name =
                     mappings.normalized_business_field
                    THEN 100

                /*
                    Business field looks like an identifier and
                    the candidate is the registered Id column.
                */
                WHEN registry.id_column IS NOT NULL
                 AND columns_source.name = registry.id_column
                 AND mappings.normalized_business_field LIKE N'%id'
                    THEN 95

                /*
                    Example:
                    Active -> IsActive
                */
                WHEN normalized_column.normalized_column_name =
                     N'is'
                     + mappings.normalized_business_field
                    THEN 90

                /*
                    Example:
                    PostalCode -> MailingPostalCode
                */
                WHEN LEN
                     (
                         mappings.normalized_business_field
                     ) >= 4

                 AND normalized_column.normalized_column_name LIKE
                     N'%'
                     + mappings.normalized_business_field
                    THEN 80

                /*
                    Candidate name is contained within the
                    business name.
                */
                WHEN LEN
                     (
                         normalized_column.normalized_column_name
                     ) >= 4

                 AND mappings.normalized_business_field LIKE
                     N'%'
                     + normalized_column.normalized_column_name
                    THEN 70

                ELSE 0
            END AS match_score

        FROM mapping_base AS mappings

        INNER JOIN sys.schemas AS schemas_source
            ON schemas_source.name =
               mappings.source_schema

        INNER JOIN sys.objects AS objects_source
            ON objects_source.schema_id =
               schemas_source.schema_id

           AND objects_source.name =
               mappings.source_name

           AND objects_source.type IN
               (
                   N'U',
                   N'V'
               )

        INNER JOIN sys.columns AS columns_source
            ON columns_source.object_id =
               objects_source.object_id

        LEFT JOIN ctl.object_registry AS registry
            ON registry.staging_schema =
               mappings.source_schema

           AND registry.latest_view_name =
               mappings.source_name

           AND registry.is_active = 1

        CROSS APPLY
        (
            SELECT
                LOWER
                (
                    REPLACE
                    (
                        REPLACE
                        (
                            REPLACE
                            (
                                columns_source.name,
                                N'__c',
                                N''
                            ),
                            N'_',
                            N''
                        ),
                        N'-',
                        N''
                    )
                ) AS normalized_column_name
        ) AS normalized_column

        WHERE columns_source.name NOT LIKE N'[_]etl[_]%'
          AND columns_source.name <> N'_latest_row_number'
    ),

    ranked_candidates AS
    (
        SELECT
            field_mapping_id,
            business_object,
            business_field,
            source_object,
            mapping_status,
            notes,
            suggested_api_field,
            match_score,

            ROW_NUMBER() OVER
            (
                PARTITION BY field_mapping_id
                ORDER BY
                    match_score DESC,
                    suggested_api_field
            ) AS candidate_rank

        FROM candidate_columns

        WHERE match_score > 0
    )

    SELECT
        field_mapping_id,
        business_object,
        business_field,
        source_object,

        suggested_api_field,
        match_score,
        candidate_rank,

        CASE
            WHEN candidate_rank = 1
             AND match_score >= 100
                THEN N'HIGH_CONFIDENCE'

            WHEN candidate_rank = 1
             AND match_score >= 80
                THEN N'REVIEW_RECOMMENDED'

            ELSE N'ALTERNATIVE'
        END AS suggestion_status,

        mapping_status AS current_mapping_status,
        notes

    FROM ranked_candidates

    WHERE candidate_rank <= 5

    ORDER BY
        business_object,
        business_field,
        candidate_rank;
END;
GO
