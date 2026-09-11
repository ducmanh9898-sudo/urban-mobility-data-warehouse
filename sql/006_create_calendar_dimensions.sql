BEGIN;

CREATE TABLE IF NOT EXISTS dw.dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year_number SMALLINT NOT NULL,
    quarter_number SMALLINT NOT NULL
        CHECK (quarter_number BETWEEN 1 AND 4),
    month_number SMALLINT NOT NULL
        CHECK (month_number BETWEEN 1 AND 12),
    day_of_month SMALLINT NOT NULL
        CHECK (day_of_month BETWEEN 1 AND 31),
    iso_day_of_week SMALLINT NOT NULL
        CHECK (iso_day_of_week BETWEEN 1 AND 7),
    is_weekend BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS dw.dim_time (
    time_key SMALLINT PRIMARY KEY
        CHECK (time_key BETWEEN 0 AND 1439),
    time_of_day TIME NOT NULL UNIQUE,
    hour_number SMALLINT NOT NULL
        CHECK (hour_number BETWEEN 0 AND 23),
    minute_number SMALLINT NOT NULL
        CHECK (minute_number BETWEEN 0 AND 59)
);

-- Initial calendar coverage: 2026 and 2027.
INSERT INTO dw.dim_date (
    date_key,
    full_date,
    year_number,
    quarter_number,
    month_number,
    day_of_month,
    iso_day_of_week,
    is_weekend
)
SELECT
    EXTRACT(YEAR FROM calendar_day)::INTEGER * 10000
        + EXTRACT(MONTH FROM calendar_day)::INTEGER * 100
        + EXTRACT(DAY FROM calendar_day)::INTEGER,
    calendar_day::DATE,
    EXTRACT(YEAR FROM calendar_day)::SMALLINT,
    EXTRACT(QUARTER FROM calendar_day)::SMALLINT,
    EXTRACT(MONTH FROM calendar_day)::SMALLINT,
    EXTRACT(DAY FROM calendar_day)::SMALLINT,
    EXTRACT(ISODOW FROM calendar_day)::SMALLINT,
    EXTRACT(ISODOW FROM calendar_day) IN (6, 7)
FROM generate_series(
    TIMESTAMP '2026-01-01',
    TIMESTAMP '2027-12-31',
    INTERVAL '1 day'
) AS dates(calendar_day)
ON CONFLICT (date_key) DO NOTHING;

-- One row for each minute of the day.
INSERT INTO dw.dim_time (
    time_key,
    time_of_day,
    hour_number,
    minute_number
)
SELECT
    minute_of_day,
    make_time(minute_of_day / 60, minute_of_day % 60, 0),
    minute_of_day / 60,
    minute_of_day % 60
FROM generate_series(0, 1439) AS minutes(minute_of_day)
ON CONFLICT (time_key) DO NOTHING;

COMMIT;