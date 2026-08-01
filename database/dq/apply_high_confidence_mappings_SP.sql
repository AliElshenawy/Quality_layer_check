/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dq].[apply_high_confidence_mappings]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    CREATE TABLE #suggestions
    (
        field_mapping_id INT NOT NULL,
        business_object NVARCHAR(300) NOT NULL,
        business_field NVARCHAR(400) NOT NULL,
        source_object NVARCHAR(256) NOT NULL,
        suggested_api_field SYSNAME NOT NULL,
        match_score INT NOT NULL,
        candidate_rank BIGINT NOT NULL,
        suggestion_status NVARCHAR(100) NOT NULL,
        current_mapping_status NVARCHAR(100) NULL,
        notes NVARCHAR(2000) NULL
    );

    INSERT INTO #suggestions
    (
        field_mapping_id,
        business_object,
        business_field,
        source_object,
        suggested_api_field,
        match_score,
        candidate_rank,
        suggestion_status,
        current_mapping_status,
        notes
    )
    EXEC dq.suggest_field_mappings;

    ;WITH safe_suggestions AS
    (
        SELECT
            suggestion.field_mapping_id,
            suggestion.suggested_api_field,
            suggestion.match_score
        FROM #suggestions AS suggestion
        WHERE suggestion.candidate_rank = 1
          AND suggestion.suggestion_status = N'HIGH_CONFIDENCE'

          /* Do not apply when another candidate has the same score */
          AND NOT EXISTS
          (
              SELECT 1
              FROM #suggestions AS alternative
              WHERE alternative.field_mapping_id =
                    suggestion.field_mapping_id

                AND alternative.candidate_rank > 1

                AND alternative.match_score =
                    suggestion.match_score
          )
    )
    UPDATE mapping
    SET
        mapping.salesforce_api_field =
            suggestion.suggested_api_field,

        mapping.mapping_status =
            N'System Suggested - Review',

        mapping.notes =
            CASE
                WHEN NULLIF
                     (
                         LTRIM(RTRIM(mapping.notes)),
                         N''
                     ) IS NULL
                THEN
                    CONCAT
                    (
                        N'Automatically suggested from metadata. Score: ',
                        suggestion.match_score,
                        N'.'
                    )

                ELSE
                    CONCAT
                    (
                        mapping.notes,
                        N' | Automatically suggested from metadata. Score: ',
                        suggestion.match_score,
                        N'.'
                    )
            END

    FROM dq.field_mapping AS mapping

    INNER JOIN safe_suggestions AS suggestion
        ON suggestion.field_mapping_id =
           mapping.field_mapping_id

    WHERE NULLIF
          (
              LTRIM
              (
                  RTRIM
                  (
                      mapping.salesforce_api_field
                  )
              ),
              N''
          ) IS NULL;

    DECLARE @UpdatedMappings INT = @@ROWCOUNT;

    /* Summary */

    SELECT
        @UpdatedMappings AS mappings_updated,

        (
            SELECT COUNT(*)
            FROM dq.field_mapping
            WHERE mapping_status =
                  N'System Suggested - Review'
        ) AS mappings_waiting_for_review,

        (
            SELECT COUNT(*)
            FROM dq.field_mapping
            WHERE NULLIF
                  (
                      LTRIM
                      (
                          RTRIM
                          (
                              salesforce_api_field
                          )
                      ),
                      N''
                  ) IS NULL
        ) AS mappings_still_unresolved;

    /* Applied mappings */

    SELECT
        field_mapping_id,
        business_object,
        business_field,
        source_object,
        salesforce_api_field,
        mapping_status,
        notes
    FROM dq.field_mapping
    WHERE mapping_status =
          N'System Suggested - Review'
    ORDER BY
        business_object,
        business_field;

    /* Mappings that still require manual confirmation */

    SELECT
        mapping.field_mapping_id,
        mapping.business_object,
        mapping.business_field,
        mapping.source_object,

        suggestion.suggested_api_field,
        suggestion.match_score,
        suggestion.suggestion_status,

        mapping.mapping_status,
        mapping.notes

    FROM dq.field_mapping AS mapping

    LEFT JOIN #suggestions AS suggestion
        ON suggestion.field_mapping_id =
           mapping.field_mapping_id
       AND suggestion.candidate_rank = 1

    WHERE NULLIF
          (
              LTRIM
              (
                  RTRIM
                  (
                      mapping.salesforce_api_field
                  )
              ),
              N''
          ) IS NULL

    ORDER BY
        mapping.business_object,
        mapping.business_field;
END;
GO
