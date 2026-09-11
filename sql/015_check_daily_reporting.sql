\pset pager off
SET TIME ZONE 'UTC';

\echo '=== Latest daily reporting attempts ==='

SELECT
    business_date,
    policy_version,
    status,
    started_at,
    finished_at,
    source_sample_count,
    rows_written,
    error_message
FROM ops.reporting_run
ORDER BY started_at DESC
LIMIT 10;

\echo '=== Reconcile stored reports with their latest successful runs ==='

WITH latest_success AS (
    SELECT DISTINCT ON (business_date, policy_version)
        run_id,
        business_date,
        policy_version,
        source_sample_count,
        rows_written,
        finished_at
    FROM ops.reporting_run
    WHERE status = 'success'
    ORDER BY
        business_date,
        policy_version,
        finished_at DESC,
        run_id DESC
),
stored_reports AS (
    SELECT
        business_date,
        policy_version,
        COUNT(*) AS report_rows,
        SUM(sample_count) AS report_samples,
        COUNT(DISTINCT reporting_run_id) AS run_id_count
    FROM mart.station_daily
    GROUP BY business_date, policy_version
)
SELECT
    COALESCE(r.business_date, d.business_date) AS business_date,
    COALESCE(r.policy_version, d.policy_version) AS policy_version,
    r.source_sample_count,
    d.report_samples,
    r.rows_written,
    d.report_rows,
    CASE
        WHEN r.run_id IS NULL THEN 'MISSING_SUCCESS_LOG'
        WHEN d.business_date IS NULL THEN 'MISSING_REPORT'
        WHEN d.report_samples <> r.source_sample_count
          OR d.report_rows <> r.rows_written
          OR d.run_id_count <> 1
          OR EXISTS (
              SELECT 1
              FROM mart.station_daily s
              WHERE s.business_date = r.business_date
                AND s.policy_version = r.policy_version
                AND s.reporting_run_id <> r.run_id
          )
        THEN 'MISMATCH'
        ELSE 'PASS'
    END AS reconciliation_status
FROM latest_success r
FULL OUTER JOIN stored_reports d
    ON d.business_date = r.business_date
   AND d.policy_version = r.policy_version
ORDER BY business_date DESC, policy_version;