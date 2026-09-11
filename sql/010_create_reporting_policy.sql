BEGIN;

CREATE TABLE IF NOT EXISTS ops.reporting_policy (
    policy_version TEXT PRIMARY KEY,

    max_feed_age_seconds INTEGER NOT NULL
        CHECK (max_feed_age_seconds >= 0),

    max_station_age_seconds INTEGER NOT NULL
        CHECK (max_station_age_seconds >= 0),

    future_tolerance_seconds INTEGER NOT NULL
        CHECK (future_tolerance_seconds >= 0),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO ops.reporting_policy (
    policy_version,
    max_feed_age_seconds,
    max_station_age_seconds,
    future_tolerance_seconds
)
VALUES ('v1', 300, 1800, 300)
ON CONFLICT (policy_version) DO NOTHING;

COMMIT;