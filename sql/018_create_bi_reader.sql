BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'mobility_bi'
    ) THEN
        CREATE ROLE mobility_bi
            LOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            NOBYPASSRLS;
    END IF;
END
$$;

GRANT CONNECT ON DATABASE mobility_dw TO mobility_bi;

GRANT USAGE ON SCHEMA mart TO mobility_bi;

GRANT SELECT ON mart.v_station_daily_dashboard TO mobility_bi;

COMMIT;