-- Report 1: identifiers within each feed.
WITH source_rows AS (
    SELECT 'station_information' AS feed, payload
    FROM stg.station_information
    WHERE raw_run_id = :'raw_run_id'::uuid

    UNION ALL

    SELECT 'station_status', payload
    FROM stg.station_status
    WHERE raw_run_id = :'raw_run_id'::uuid
),
parsed AS (
    SELECT
        feed,
        CASE
            WHEN jsonb_typeof(payload -> 'station_id') = 'string'
                 AND BTRIM(payload ->> 'station_id') <> ''
            THEN payload ->> 'station_id'
        END AS station_id
    FROM source_rows
),
id_counts AS (
    SELECT feed, station_id, COUNT(*) AS occurrences
    FROM parsed
    WHERE station_id IS NOT NULL
    GROUP BY feed, station_id
),
feed_names AS (
    SELECT 'station_information' AS feed
    UNION ALL
    SELECT 'station_status'
)
SELECT
    f.feed,
    (SELECT COUNT(*) FROM parsed p
     WHERE p.feed = f.feed) AS total_rows,

    (SELECT COUNT(*) FROM parsed p
     WHERE p.feed = f.feed
       AND p.station_id IS NULL) AS invalid_id_rows,

    (SELECT COUNT(*) FROM id_counts c
     WHERE c.feed = f.feed) AS distinct_valid_ids,

    (SELECT COUNT(*) FROM id_counts c
     WHERE c.feed = f.feed
       AND c.occurrences > 1) AS duplicated_id_groups
FROM feed_names f
ORDER BY f.feed;


-- Report 2: valid identifiers missing from the other feed.
WITH info_ids AS (
    SELECT DISTINCT payload ->> 'station_id' AS station_id
    FROM stg.station_information
    WHERE raw_run_id = :'raw_run_id'::uuid
      AND jsonb_typeof(payload -> 'station_id') = 'string'
      AND BTRIM(payload ->> 'station_id') <> ''
),
status_ids AS (
    SELECT DISTINCT payload ->> 'station_id' AS station_id
    FROM stg.station_status
    WHERE raw_run_id = :'raw_run_id'::uuid
      AND jsonb_typeof(payload -> 'station_id') = 'string'
      AND BTRIM(payload ->> 'station_id') <> ''
)
SELECT
    COUNT(*) FILTER (
        WHERE s.station_id IS NULL
    ) AS information_without_status,

    COUNT(*) FILTER (
        WHERE i.station_id IS NULL
    ) AS status_without_information
FROM info_ids i
FULL OUTER JOIN status_ids s
    ON i.station_id = s.station_id;