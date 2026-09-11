\pset pager off
SET TIME ZONE 'UTC';

\echo '=== Network summary for the selected business date ==='

SELECT
    business_date,
    policy_version,
    COUNT(*) AS stations_observed,
    SUM(sample_count) AS total_samples,

    ROUND(
        100.0 * SUM(time_eligible_samples)
        / NULLIF(SUM(sample_count), 0),
        2
    ) AS time_eligible_sample_pct,

    ROUND(
        100.0 * SUM(empty_bike_samples)
        / NULLIF(SUM(rental_eligible_samples), 0),
        2
    ) AS empty_bike_sample_pct,

    ROUND(
        100.0 * SUM(no_dock_samples)
        / NULLIF(SUM(return_eligible_samples), 0),
        2
    ) AS no_dock_sample_pct,

    MIN(first_source_updated) AS first_source_updated,
    MAX(last_source_updated) AS last_source_updated,
    MAX(refreshed_at) AS report_refreshed_at

FROM mart.v_station_daily_dashboard
WHERE business_date = :'business_date'::date
  AND policy_version = 'v1'
GROUP BY business_date, policy_version;

\echo '=== Top stations by empty-bike sample percentage ==='

SELECT
    station_id,
    current_station_name,
    rental_eligible_samples,
    empty_bike_samples,
    empty_bike_sample_pct,
    avg_available_bikes

FROM mart.v_station_daily_dashboard
WHERE business_date = :'business_date'::date
  AND policy_version = 'v1'
  AND rental_eligible_samples >= :min_samples
  AND empty_bike_samples > 0

ORDER BY
    empty_bike_sample_pct DESC,
    rental_eligible_samples DESC,
    station_id
LIMIT 10;

\echo '=== Top stations by no-dock sample percentage ==='

SELECT
    station_id,
    current_station_name,
    return_eligible_samples,
    no_dock_samples,
    no_dock_sample_pct,
    avg_available_docks

FROM mart.v_station_daily_dashboard
WHERE business_date = :'business_date'::date
  AND policy_version = 'v1'
  AND return_eligible_samples >= :min_samples
  AND no_dock_samples > 0

ORDER BY
    no_dock_sample_pct DESC,
    return_eligible_samples DESC,
    station_id
LIMIT 10;