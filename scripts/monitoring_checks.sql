/* ============================================================================
   monitoring_checks.sql — "what needs attention" after a run (read-only).
   ----------------------------------------------------------------------------
   Empty result sets = healthy. Run after each pipeline run or on a schedule
   (SQL Agent locally; a scheduled query / Logic App on Azure to email/Teams):
     sqlcmd -S localhost -d SalesforceDW -E -C -N -W -s"|" -i scripts/monitoring_checks.sql
   ============================================================================ */
SET NOCOUNT ON;

PRINT '== 1) FAILED / non-success runs (last 2 days) ==';
SELECT run_id, object_name, load_type, status, rows_extracted, rows_loaded,
       error_message, start_time, end_time
FROM ctl.etl_run_control
WHERE status NOT IN (N'Success')
  AND start_time >= DATEADD(DAY, -2, SYSUTCDATETIME())
ORDER BY start_time DESC;

PRINT '== 2) DQ rules that ERRORed ==';
SELECT r.object_name, r.check_name, s.last_run_status, s.last_prepared_at
FROM dq.rule_execution_state s
JOIN dq.dq_rule_catalog r ON r.rule_id = s.rule_id
WHERE s.last_run_status = N'ERROR'
ORDER BY r.object_name, r.check_name;

PRINT '== 3) CRITICAL open exceptions (should be 0 for a clean-eligible object) ==';
SELECT r.object_name, r.check_name, COUNT(*) AS critical_open
FROM dq.dq_exceptions e
JOIN dq.dq_rule_catalog r ON r.rule_id = e.rule_id
WHERE r.severity = N'CRITICAL' AND e.resolution_status = N'Open'
GROUP BY r.object_name, r.check_name
ORDER BY critical_open DESC;

PRINT '== 4) Runs still stuck in Running > 3h (possible hang) ==';
SELECT run_id, object_name, load_type, status, start_time
FROM ctl.etl_run_control
WHERE status = N'Running' AND start_time < DATEADD(HOUR, -3, SYSUTCDATETIME())
ORDER BY start_time;
GO
