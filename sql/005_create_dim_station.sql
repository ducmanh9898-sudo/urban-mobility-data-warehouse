BEGIN;

CREATE TABLE IF NOT EXISTS dw.dim_station (
    station_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    station_id TEXT NOT NULL UNIQUE
        CHECK (BTRIM(station_id) <> ''),

    station_name TEXT NOT NULL
        CHECK (BTRIM(station_name) <> ''),

    short_name TEXT,
    region_id TEXT,

    latitude DOUBLE PRECISION NOT NULL
        CHECK (latitude BETWEEN -90 AND 90),

    longitude DOUBLE PRECISION NOT NULL
        CHECK (longitude BETWEEN -180 AND 180),

    capacity INTEGER
        CHECK (capacity >= 0),

    source_last_updated TIMESTAMPTZ NOT NULL,
    source_collected_at TIMESTAMPTZ NOT NULL,
    source_raw_run_id UUID NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE dw.dim_station IS
    'Latest known station attributes; SCD Type 1';

COMMENT ON COLUMN dw.dim_station.station_key IS
    'Warehouse-generated surrogate key';

COMMENT ON COLUMN dw.dim_station.station_id IS
    'Unique station identifier from Citi Bike';

COMMIT;