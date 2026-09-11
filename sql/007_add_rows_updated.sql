BEGIN;

ALTER TABLE ops.pipeline_run
ADD COLUMN IF NOT EXISTS rows_updated INTEGER NOT NULL DEFAULT 0
CHECK (rows_updated >= 0);

COMMENT ON COLUMN ops.pipeline_run.rows_updated IS
    'Number of existing target rows updated by this execution';

COMMIT;