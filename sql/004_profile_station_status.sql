-- Report 1: available counts must fit non-negative SQL integers.
WITH source_rows AS (
    SELECT payload
    FROM stg.station_status
    WHERE raw_run_id = :'raw_run_id'::uuid
),
field_values AS (
    SELECT fields.field_name, fields.field_value
    FROM source_rows s
    CROSS JOIN LATERAL (
        VALUES
            ('num_bikes_available',
             s.payload -> 'num_bikes_available'),
            ('num_docks_available',
             s.payload -> 'num_docks_available')
    ) AS fields(field_name, field_value)
),
checked AS (
    SELECT
        field_name,
        CASE
            WHEN jsonb_typeof(field_value) = 'number'
            THEN
                field_value::numeric BETWEEN 0 AND 2147483647
                AND field_value::numeric = TRUNC(field_value::numeric)
            ELSE FALSE
        END AS is_valid
    FROM field_values
)
SELECT
    field_name,
    COUNT(*) AS checked_rows,
    COUNT(*) FILTER (WHERE NOT is_valid) AS invalid_rows
FROM checked
GROUP BY field_name
ORDER BY field_name;


-- Report 2: accept JSON booleans or numeric 0/1.
WITH source_rows AS (
    SELECT payload
    FROM stg.station_status
    WHERE raw_run_id = :'raw_run_id'::uuid
),
field_values AS (
    SELECT fields.field_name, fields.field_value
    FROM source_rows s
    CROSS JOIN LATERAL (
        VALUES
            ('is_installed', s.payload -> 'is_installed'),
            ('is_renting', s.payload -> 'is_renting'),
            ('is_returning', s.payload -> 'is_returning')
    ) AS fields(field_name, field_value)
)
SELECT
    field_name,
    COUNT(*) AS checked_rows,
    COUNT(*) FILTER (
        WHERE (
            field_value IN (
                '0'::jsonb,
                '1'::jsonb,
                'false'::jsonb,
                'true'::jsonb
            )
        ) IS NOT TRUE
    ) AS invalid_rows
FROM field_values
GROUP BY field_name
ORDER BY field_name;


-- Report 3: distribution of operational states.
SELECT
    payload -> 'is_installed' AS is_installed,
    payload -> 'is_renting' AS is_renting,
    payload -> 'is_returning' AS is_returning,
    COUNT(*) AS station_rows
FROM stg.station_status
WHERE raw_run_id = :'raw_run_id'::uuid
GROUP BY
    payload -> 'is_installed',
    payload -> 'is_renting',
    payload -> 'is_returning'
ORDER BY station_rows DESC;