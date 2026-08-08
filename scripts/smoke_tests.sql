/* ============================================================================
   smoke_tests.sql — repeatable per-stage sanity checks (read-only).
   ----------------------------------------------------------------------------
   Each row returns PASS / FAIL / WARN. A FAIL should block promotion.
   Run after a pipeline run, or wire into SQL Agent / CI:
     sqlcmd -S localhost -d SalesforceDW -E -C -N -W -s"|" -i scripts/smoke_tests.sql
   Add a new object by extending the two UNION lists below.
   ============================================================================ */
SET NOCOUNT ON;

PRINT '== STAGING: one row per Id (0 duplicates) ==';
SELECT 'staging_unique_id' AS test, q.object,
       CASE WHEN q.dup = 0 THEN 'PASS' ELSE 'FAIL' END AS result, q.dup AS detail
FROM (
    SELECT 'campaign_latest' AS object,
           (SELECT COUNT(*) FROM (SELECT Id18 FROM staging.campaign_latest GROUP BY Id18 HAVING COUNT(*) > 1) x) AS dup
    UNION ALL SELECT 'contact_latest',
           (SELECT COUNT(*) FROM (SELECT Id18 FROM staging.contact_latest GROUP BY Id18 HAVING COUNT(*) > 1) x)
    UNION ALL SELECT 'item_gau_latest',
           (SELECT COUNT(*) FROM (SELECT Id18 FROM staging.item_gau_latest GROUP BY Id18 HAVING COUNT(*) > 1) x)
    UNION ALL SELECT 'recurring_donation_latest',
           (SELECT COUNT(*) FROM (SELECT Id18 FROM staging.recurring_donation_latest GROUP BY Id18 HAVING COUNT(*) > 1) x)
) q;

PRINT '== DQ: 0 CRITICAL open exceptions per object (the clean gate) ==';
SELECT 'dq_zero_critical' AS test, r.object_name AS object,
       CASE WHEN COUNT(e.record_id) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
       COUNT(e.record_id) AS detail
FROM dq.dq_rule_catalog r
LEFT JOIN dq.dq_exceptions e
       ON e.rule_id = r.rule_id AND e.resolution_status = 'Open'
WHERE r.severity = 'CRITICAL'
GROUP BY r.object_name
ORDER BY r.object_name;

PRINT '== CLEAN: clean.<obj> row count vs staging (drift) ==';
SELECT 'clean_vs_staging' AS test, 'Campaign' AS object,
       CASE WHEN (SELECT COUNT(*) FROM clean.campaign) = (SELECT COUNT(*) FROM staging.campaign_latest)
            THEN 'PASS' ELSE 'WARN' END AS result,
       CONCAT((SELECT COUNT(*) FROM clean.campaign), ' clean / ',
              (SELECT COUNT(*) FROM staging.campaign_latest), ' staging') AS detail;
GO
