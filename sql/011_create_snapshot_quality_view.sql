CREATE OR REPLACE VIEW mart.v_station_snapshot_quality AS
WITH ages AS (
    SELECT
        f.*,
        p.policy_version,
        p.max_feed_age_seconds,
        p.max_station_age_seconds,
        p.future_tolerance_seconds,

        EXTRACT(
            EPOCH FROM (f.collected_at - f.source_last_updated)
        ) AS feed_age_seconds,

        EXTRACT(
            EPOCH FROM (f.collected_at - f.last_reported)
        ) AS station_age_seconds

    FROM dw.fact_station_snapshot f
    CROSS JOIN ops.reporting_policy p
    WHERE p.policy_version = 'v1'
),
checked AS (
    SELECT
        *,
        COALESCE(
            feed_age_seconds BETWEEN
                -future_tolerance_seconds AND max_feed_age_seconds
            AND station_age_seconds BETWEEN
                -future_tolerance_seconds AND max_station_age_seconds,
            FALSE
        ) AS is_time_eligible,

        COALESCE(
            feed_age_seconds < 0 OR station_age_seconds < 0,
            FALSE
        ) AS has_future_timestamp
    FROM ages
)
SELECT
    snapshot_key,
    station_key,
    date_key,
    time_key,
    raw_run_id,
    policy_version,

    source_last_updated,
    collected_at,
    last_reported,
    feed_age_seconds,
    station_age_seconds,
    has_future_timestamp,

    num_bikes_available,
    num_docks_available,
    is_installed,
    is_renting,
    is_returning,
    is_time_eligible,

    (
        is_time_eligible AND is_installed AND is_renting
    ) AS rental_eligible,

    (
        is_time_eligible AND is_installed AND is_returning
    ) AS return_eligible,

    (
        is_time_eligible
        AND is_installed
        AND is_renting
        AND num_bikes_available = 0
    ) AS empty_bike_observation,

    (
        is_time_eligible
        AND is_installed
        AND is_returning
        AND num_docks_available = 0
    ) AS no_dock_observation

FROM checked;