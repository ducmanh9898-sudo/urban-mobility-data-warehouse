CREATE OR REPLACE VIEW mart.v_station_daily AS
WITH aggregated AS (
    SELECT
        q.station_key,
        q.date_key,
        d.full_date AS business_date,
        q.policy_version,

        COUNT(*) AS sample_count,

        COUNT(*) FILTER (
            WHERE q.is_time_eligible
        ) AS time_eligible_samples,

        COUNT(*) FILTER (
            WHERE NOT q.is_time_eligible
        ) AS time_ineligible_samples,

        COUNT(*) FILTER (
            WHERE q.is_time_eligible AND q.has_future_timestamp
        ) AS accepted_future_samples,

        COUNT(*) FILTER (
            WHERE q.rental_eligible
        ) AS rental_eligible_samples,

        COUNT(*) FILTER (
            WHERE q.empty_bike_observation
        ) AS empty_bike_samples,

        COUNT(*) FILTER (
            WHERE q.return_eligible
        ) AS return_eligible_samples,

        COUNT(*) FILTER (
            WHERE q.no_dock_observation
        ) AS no_dock_samples,

        ROUND(
            AVG(q.num_bikes_available) FILTER (
                WHERE q.rental_eligible
            ),
            2
        ) AS avg_available_bikes,

        ROUND(
            AVG(q.num_docks_available) FILTER (
                WHERE q.return_eligible
            ),
            2
        ) AS avg_available_docks,

        COUNT(DISTINCT FLOOR(
            EXTRACT(EPOCH FROM q.source_last_updated) / 900
        )) AS observed_source_15min_slots,

        MIN(q.source_last_updated) AS first_source_updated,
        MAX(q.source_last_updated) AS last_source_updated

    FROM mart.v_station_snapshot_quality q
    JOIN dw.dim_date d
        ON d.date_key = q.date_key

    GROUP BY
        q.station_key,
        q.date_key,
        d.full_date,
        q.policy_version
)
SELECT
    *,
    ROUND(
        100.0 * empty_bike_samples
        / NULLIF(rental_eligible_samples, 0),
        2
    ) AS empty_bike_sample_pct,

    ROUND(
        100.0 * no_dock_samples
        / NULLIF(return_eligible_samples, 0),
        2
    ) AS no_dock_sample_pct

FROM aggregated;