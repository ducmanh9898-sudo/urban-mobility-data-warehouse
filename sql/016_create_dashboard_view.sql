CREATE OR REPLACE VIEW mart.v_station_daily_dashboard AS
SELECT
    d.business_date,
    d.date_key,
    d.policy_version,
    d.station_key,
    s.station_id,

    -- Station attributes reflect the current SCD Type 1 dimension.
    s.station_name AS current_station_name,
    s.region_id AS current_region_id,
    s.latitude AS current_latitude,
    s.longitude AS current_longitude,
    s.capacity AS current_capacity,

    d.sample_count,
    d.time_eligible_samples,
    d.time_ineligible_samples,
    d.accepted_future_samples,

    ROUND(
        100.0 * d.time_eligible_samples
        / NULLIF(d.sample_count, 0),
        2
    ) AS time_eligible_sample_pct,

    d.rental_eligible_samples,
    d.empty_bike_samples,
    d.empty_bike_sample_pct,
    d.avg_available_bikes,

    d.return_eligible_samples,
    d.no_dock_samples,
    d.no_dock_sample_pct,
    d.avg_available_docks,

    d.observed_source_15min_slots,
    d.first_source_updated,
    d.last_source_updated,
    d.refreshed_at,
    d.reporting_run_id

FROM mart.station_daily d
JOIN dw.dim_station s
    ON s.station_key = d.station_key;