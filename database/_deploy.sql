/* ============================================================================
   Author: Mohey
   Origin: Added to the database after the base structure (DQ watermark framework).
   ============================================================================ */

/* ============================================================================
   SalesforceDW structure deploy script
   ----------------------------------------------------------------------------
   Recreates the database structure by running every object file in dependency
   order (schemas -> tables -> views -> procedures; FKs/indexes live inside each
   table file).

   HOW TO RUN (from THIS 'database' folder so the relative :r paths resolve):

     cd "d:/career/github/VA Work/database"
     sqlcmd -S localhost -E -d SalesforceDW -C -N -b -i _deploy.sql

   Notes:
   - 00_database.sql (CREATE DATABASE + settings) is intentionally NOT included
     here; it is environment-specific. Run it manually first on a brand-new
     server after editing the data/log file paths.
   - Assumes the target database already exists and is selected via -d.
   ============================================================================ */
:on error exit
SET NOCOUNT ON;
GO

/* 1) Schemas -------------------------------------------------------------- */
:r 00_schemas.sql

/* 2) raw tables (no dependencies) ---------------------------------------- */
:r raw\salesforce_campaign_table.sql
:r raw\salesforce_contact_table.sql
:r raw\salesforce_item_table.sql
:r raw\salesforce_item_allocation_table.sql
:r raw\salesforce_opportunity_table.sql
:r raw\salesforce_payment_table.sql
:r raw\salesforce_recurring_donation_table.sql
:r raw\salesforce_sponsorship_table.sql
:r raw\salesforce_sponsorship_unit_table.sql

/* 3) ctl tables ---------------------------------------------------------- */
:r ctl\etl_run_control_table.sql
:r ctl\object_registry_table.sql
:r ctl\watermark_control_table.sql
:r ctl\loaded_salesforce_item_allocation_ids_table.sql
:r ctl\loaded_salesforce_opportunity_ids_table.sql
:r ctl\clean_state_table.sql
:r ctl\staging_state_table.sql

/* 4) dq tables (dq_rule_catalog before dq_exceptions for the FK) --------- */
:r dq\dq_rule_catalog_table.sql
:r dq\field_mapping_table.sql
:r dq\dq_exceptions_table.sql
:r dq\dq_results_table.sql
:r dq\field_profile_table.sql
:r dq\profile_run_table.sql
:r dq\technical_result_table.sql
:r dq\technical_run_table.sql
:r dq\rule_execution_state_table.sql
:r dq\rule_execution_audit_table.sql
:r dq\dq_alert_table.sql

/* 5) staging resume tables ----------------------------------------------- */
:r staging\salesforce_item_allocation_resume_batch_table.sql
:r staging\salesforce_item_allocation_resume_ids_table.sql
:r staging\salesforce_opportunity_resume_batch_table.sql
:r staging\salesforce_opportunity_resume_ids_table.sql

/* 6) staging views (depend on raw tables) -------------------------------- */
:r staging\vw_item_allocation_latest_view.sql
:r staging\vw_opportunity_latest_view.sql
:r staging\vw_payment_latest_view.sql
:r staging\vw_contact_latest_view.sql
:r staging\vw_recurring_donation_latest_view.sql
:r staging\vw_campaign_latest_view.sql
:r staging\vw_sponsorship_latest_view.sql
:r staging\vw_sponsorship_unit_latest_view.sql
:r staging\vw_item_latest_view.sql

/* 6b) staging materialized latest tables + incremental builders ---------- */
:r staging\campaign_latest_table.sql
:r staging\contact_latest_table.sql
:r staging\item_gau_latest_table.sql
:r staging\recurring_donation_latest_table.sql
:r staging\refresh_object_latest_SP.sql
:r staging\campaign_latest_SP.sql
:r staging\contact_latest_SP.sql
:r staging\item_gau_latest_SP.sql
:r staging\recurring_donation_latest_SP.sql

/* 6c) clean table (persistent) + incremental build proc ------------------ */
:r clean\campaign_table.sql
:r clean\refresh_campaign_SP.sql

/* 7) dq view (depends on dq_rule_catalog + field_mapping) ---------------- */
:r dq\vw_rule_readiness_view.sql

/* 8) ctl procedures ------------------------------------------------------ */
:r ctl\refresh_latest_views_SP.sql
:r ctl\refresh_object_registry_SP.sql
:r ctl\validate_pipeline_metadata_SP.sql

/* 9) dq procedures (framework procs last; depend on views + tables) ------ */
:r dq\analyze_object_SP.sql
:r dq\apply_high_confidence_mappings_SP.sql
:r dq\run_active_catalog_rules_SP.sql
:r dq\run_dynamic_field_profile_SP.sql
:r dq\run_dynamic_technical_checks_SP.sql
:r dq\suggest_field_mappings_SP.sql
:r dq\prepare_incremental_rule_queue_SP.sql
:r dq\run_incremental_catalog_rules_SP.sql

/* 9b) pipeline orchestrator (staging -> DQ -> clean; depends on the above) */
:r ctl\run_object_pipeline_SP.sql

/* 10) mart tables -------------------------------------------------------- */
:r mart\dim_campaign_table.sql

/* 11) dbo utilities ------------------------------------------------------ */
:r dbo\usp_null_analysis_SP.sql

PRINT 'SalesforceDW structure deploy complete.';
GO
