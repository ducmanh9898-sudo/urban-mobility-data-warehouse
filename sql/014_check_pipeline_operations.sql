\pset pager off
SET TIME ZONE 'UTC';

\echo '=== Latest recorded run for each loading job ==='

SELECT DISTINCT ON (job_name)
    job_name,
    status,
    started_at,
    finished_at,
    rows_read,
    rows_inserted,
    rows_updated
FROM ops.pipeline_run
ORDER BY job_name, started_at DESC, run_id DESC;

\echo '=== Latest timestamps stored in the fact table ==='

WITH latest AS (
    SELECT
        MAX(source_last_updated) AS latest_source_updated,
        MAX(collected_at) AS latest_collected_at,
        MAX(loaded_at) AS latest_loaded_at
    FROM dw.fact_station_snapshot
)
SELECT
    CURRENT_TIMESTAMP AS checked_at,
    latest_source_updated,
    latest_collected_at,
    latest_loaded_at,
    ROUND(
        EXTRACT(
            EPOCH FROM (CURRENT_TIMESTAMP - latest_source_updated)
        ) / 60,
        2
    ) AS source_age_minutes
FROM latest;

\echo '=== Failed loading runs within the last 24 hours ==='

SELECT
    job_name,
    raw_run_id,
    started_at,
    finished_at,
    error_message
FROM ops.pipeline_run
WHERE status = 'failed'
  AND started_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY started_at DESC
LIMIT 20;