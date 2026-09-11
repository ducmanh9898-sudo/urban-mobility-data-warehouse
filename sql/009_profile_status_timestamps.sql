SET TIME ZONE 'UTC';

-- Report 1: feed freshness when it was collected.
SELECT
    COUNT(*) AS station_rows,
    MIN(source_last_updated) AS min_source_updated,
    MAX(source_last_updated) AS max_source_updated,
    MIN(collected_at) AS first_collected_at,
    MAX(collected_at) AS last_collected_at,
    ROUND(
        MIN(EXTRACT(EPOCH FROM (collected_at - source_last_updated))),
        2
    ) AS min_feed_age_seconds,
    ROUND(
        MAX(EXTRACT(EPOCH FROM (collected_at - source_last_updated))),
        2
    ) AS max_feed_age_seconds
FROM stg.station_status
WHERE raw_run_id = :'raw_run_id'::uuid;


-- Report 2: station reporting time, grouped by operational state.
WITH parsed AS (
    SELECT
        payload -> 'is_installed' AS is_installed,
        payload -> 'is_renting' AS is_renting,
        payload -> 'is_returning' AS is_returning,
        collected_at,
        CASE
            WHEN jsonb_typeof(payload -> 'last_reported') = 'number'
            THEN (payload ->> 'last_reported')::NUMERIC
        END AS reported_epoch
    FROM stg.station_status
    WHERE raw_run_id = :'raw_run_id'::uuid
),
ages AS (
    SELECT
        *,
        CASE
            -- Positive whole seconds, within Python datetime's upper limit.
            WHEN reported_epoch BETWEEN 1 AND 253402300799
                 AND reported_epoch = TRUNC(reported_epoch)
            THEN EXTRACT(EPOCH FROM collected_at) - reported_epoch
        END AS age_seconds
    FROM parsed
),
classified AS (
    SELECT
        *,
        CASE
            WHEN reported_epoch = 0
                THEN 'unknown_zero'
            WHEN age_seconds IS NULL
                THEN 'invalid_or_missing'
            WHEN age_seconds < -300
                THEN 'future_over_5min'
            WHEN age_seconds < 0
                THEN 'slightly_future'
            WHEN age_seconds > 1800
                THEN 'older_than_30min'
            ELSE 'within_30min'
        END AS time_category
    FROM ages
)
SELECT
    is_installed,
    is_renting,
    is_returning,
    time_category,
    COUNT(*) AS station_rows,
    ROUND(MIN(age_seconds) / 60, 2) AS min_age_minutes,
    ROUND(MAX(age_seconds) / 60, 2) AS max_age_minutes
FROM classified
GROUP BY
    is_installed,
    is_renting,
    is_returning,
    time_category
ORDER BY
    is_installed,
    is_renting,
    is_returning,
    time_category;