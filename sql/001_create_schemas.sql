BEGIN;

CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS ops;

COMMENT ON SCHEMA stg IS
    'Staging data before warehouse loading';

COMMENT ON SCHEMA dw IS
    'Warehouse dimensions and snapshot facts';

COMMENT ON SCHEMA mart IS
    'Analytical aggregates for reporting';

COMMENT ON SCHEMA ops IS
    'Pipeline execution and data quality tracking';

COMMIT;