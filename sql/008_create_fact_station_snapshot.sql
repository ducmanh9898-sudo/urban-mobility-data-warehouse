BEGIN;

CREATE TABLE IF NOT EXISTS dw.fact_station_snapshot (
    snapshot_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    station_key BIGINT NOT NULL
        REFERENCES dw.dim_station(station_key),

    date_key INTEGER NOT NULL
        REFERENCES dw.dim_date(date_key),

    time_key SMALLINT NOT NULL
        REFERENCES dw.dim_time(time_key),

    num_bikes_available INTEGER NOT NULL
        CHECK (num_bikes_available >= 0),

    num_docks_available INTEGER NOT NULL
        CHECK (num_docks_available >= 0),

    num_bikes_disabled INTEGER
        CHECK (num_bikes_disabled >= 0),

    num_docks_disabled INTEGER
        CHECK (num_docks_disabled >= 0),

    is_installed BOOLEAN NOT NULL,
    is_renting BOOLEAN NOT NULL,
    is_returning BOOLEAN NOT NULL,

    source_last_updated TIMESTAMPTZ NOT NULL,
    collected_at TIMESTAMPTZ NOT NULL,
    last_reported TIMESTAMPTZ,

    raw_run_id UUID NOT NULL,

    load_run_id UUID NOT NULL
        REFERENCES ops.pipeline_run(run_id),

    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_station_source_snapshot
        UNIQUE (station_key, source_last_updated)
);

CREATE INDEX IF NOT EXISTS idx_station_snapshot_date_time
ON dw.fact_station_snapshot (date_key, time_key);

COMMENT ON TABLE dw.fact_station_snapshot IS
    'One station per distinct station_status feed version';

COMMENT ON COLUMN dw.fact_station_snapshot.date_key IS
    'Business date from source_last_updated in America/New_York';

COMMENT ON COLUMN dw.fact_station_snapshot.time_key IS
    'Business minute from source_last_updated in America/New_York';

COMMENT ON COLUMN dw.fact_station_snapshot.collected_at IS
    'Collection time retained from the first accepted raw observation';

COMMENT ON COLUMN dw.fact_station_snapshot.last_reported IS
    'Station reporting time; NULL when unknown under the validation policy';

COMMIT;