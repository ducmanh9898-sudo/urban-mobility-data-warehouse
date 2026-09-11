BEGIN;

CREATE TABLE IF NOT EXISTS ops.reporting_run (
    run_id UUID PRIMARY KEY,
    business_date DATE NOT NULL,
    policy_version TEXT NOT NULL
        REFERENCES ops.reporting_policy(policy_version),
    status TEXT NOT NULL
        CHECK (status IN ('running', 'success', 'failed')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMPTZ,
    source_sample_count BIGINT NOT NULL DEFAULT 0,
    rows_written INTEGER NOT NULL DEFAULT 0,
    error_message TEXT
);

CREATE TABLE IF NOT EXISTS mart.station_daily (
    station_key BIGINT NOT NULL
        REFERENCES dw.dim_station(station_key),
    date_key INTEGER NOT NULL
        REFERENCES dw.dim_date(date_key),
    business_date DATE NOT NULL,
    policy_version TEXT NOT NULL
        REFERENCES ops.reporting_policy(policy_version),

    sample_count BIGINT NOT NULL CHECK (sample_count > 0),
    time_eligible_samples BIGINT NOT NULL,
    time_ineligible_samples BIGINT NOT NULL,
    accepted_future_samples BIGINT NOT NULL,

    rental_eligible_samples BIGINT NOT NULL,
    empty_bike_samples BIGINT NOT NULL,
    return_eligible_samples BIGINT NOT NULL,
    no_dock_samples BIGINT NOT NULL,

    avg_available_bikes NUMERIC,
    avg_available_docks NUMERIC,
    observed_source_15min_slots BIGINT NOT NULL,

    first_source_updated TIMESTAMPTZ NOT NULL,
    last_source_updated TIMESTAMPTZ NOT NULL,

    empty_bike_sample_pct NUMERIC(5, 2),
    no_dock_sample_pct NUMERIC(5, 2),

    refreshed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reporting_run_id UUID NOT NULL
        REFERENCES ops.reporting_run(run_id),

    PRIMARY KEY (station_key, business_date, policy_version),

    CHECK (
        time_eligible_samples >= 0
        AND time_ineligible_samples >= 0
        AND time_eligible_samples + time_ineligible_samples = sample_count
    ),
    CHECK (
        accepted_future_samples BETWEEN 0 AND time_eligible_samples
    ),
    CHECK (
        rental_eligible_samples BETWEEN 0 AND time_eligible_samples
        AND empty_bike_samples BETWEEN 0 AND rental_eligible_samples
    ),
    CHECK (
        return_eligible_samples BETWEEN 0 AND time_eligible_samples
        AND no_dock_samples BETWEEN 0 AND return_eligible_samples
    )
);

CREATE INDEX IF NOT EXISTS ix_station_daily_date_policy
    ON mart.station_daily (business_date, policy_version);

COMMIT;