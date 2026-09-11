BEGIN;

CREATE TABLE IF NOT EXISTS ops.pipeline_run (
    run_id UUID PRIMARY KEY,
    raw_run_id UUID NOT NULL,
    job_name TEXT NOT NULL,

    status TEXT NOT NULL
        CHECK (status IN ('running', 'success', 'failed')),

    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMPTZ,

    rows_read INTEGER NOT NULL DEFAULT 0
        CHECK (rows_read >= 0),

    rows_inserted INTEGER NOT NULL DEFAULT 0
        CHECK (rows_inserted >= 0),

    error_message TEXT
);

CREATE TABLE IF NOT EXISTS stg.station_information (
    raw_run_id UUID NOT NULL,
    source_row_number INTEGER NOT NULL
        CHECK (source_row_number >= 1),

    load_run_id UUID NOT NULL
        REFERENCES ops.pipeline_run(run_id),

    payload JSONB NOT NULL,
    source_last_updated TIMESTAMPTZ NOT NULL,
    collected_at TIMESTAMPTZ NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (raw_run_id, source_row_number)
);

CREATE TABLE IF NOT EXISTS stg.station_status (
    raw_run_id UUID NOT NULL,
    source_row_number INTEGER NOT NULL
        CHECK (source_row_number >= 1),

    load_run_id UUID NOT NULL
        REFERENCES ops.pipeline_run(run_id),

    payload JSONB NOT NULL,
    source_last_updated TIMESTAMPTZ NOT NULL,
    collected_at TIMESTAMPTZ NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (raw_run_id, source_row_number)
);

COMMIT;