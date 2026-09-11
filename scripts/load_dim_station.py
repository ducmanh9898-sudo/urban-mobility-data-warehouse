import argparse
from uuid import UUID, uuid4

from db_connection import connect_database


def text_value(record, field, required=False):
    value = record.get(field)

    if value is None:
        if required:
            raise ValueError(f"Missing {field}")
        return None

    if not isinstance(value, str):
        raise ValueError(f"{field} must be a string")

    if not value.strip():
        if required:
            raise ValueError(f"{field} must not be empty")
        return None

    return value


def number_value(value, field, minimum, maximum, integer=False):
    if type(value) not in (int, float):
        raise ValueError(f"{field} must be numeric")

    # These comparisons also reject infinity and NaN.
    if not minimum <= value <= maximum:
        raise ValueError(f"{field} is outside the allowed range")

    if integer:
        if value != int(value):
            raise ValueError(f"{field} must be an integer")
        return int(value)

    return float(value)


def prepare_station(record, source_time, collected_at, raw_run_id):
    if not isinstance(record, dict):
        raise ValueError("Station record must be an object")

    capacity = record.get("capacity")
    if capacity is not None:
        capacity = number_value(
            capacity, "capacity", 0, 2147483647, integer=True
        )

    return (
        text_value(record, "station_id", required=True),
        text_value(record, "name", required=True),
        text_value(record, "short_name"),
        text_value(record, "region_id"),
        number_value(record.get("lat"), "lat", -90, 90),
        number_value(record.get("lon"), "lon", -180, 180),
        capacity,
        source_time,
        collected_at,
        raw_run_id,
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw-run-id", type=UUID, required=True)
    args = parser.parse_args()

    raw_run_id = args.raw_run_id
    load_run_id = uuid4()
    rows_read = 0

    print(f"Raw run ID: {raw_run_id}", flush=True)
    print(f"Load run ID: {load_run_id}", flush=True)

    with connect_database() as connection:
        connection.execute(
            """
            INSERT INTO ops.pipeline_run (
                run_id, raw_run_id, job_name, status
            )
            VALUES (%s, %s, 'load_dim_station', 'running')
            """,
            (load_run_id, raw_run_id),
        )

        try:
            source_rows = connection.execute(
                """
                SELECT source_row_number, payload,
                       source_last_updated, collected_at
                FROM stg.station_information
                WHERE raw_run_id = %s
                ORDER BY source_row_number
                """,
                (raw_run_id,),
            ).fetchall()

            rows_read = len(source_rows)
            if not source_rows:
                raise ValueError("No station information found in staging")

            prepared = []
            seen_ids = set()

            for position, record, source_time, collected_at in source_rows:
                try:
                    row = prepare_station(
                        record, source_time, collected_at, raw_run_id
                    )
                except ValueError as error:
                    raise ValueError(
                        f"Source row {position}: {error}"
                    ) from error

                if row[0] in seen_ids:
                    raise ValueError(f"Duplicate station_id: {row[0]}")

                seen_ids.add(row[0])
                prepared.append(row)

            if len({row[7] for row in prepared}) != 1:
                raise ValueError("Inconsistent source timestamps in batch")

            with connection.transaction():
                # All dimension loaders use the same lock.
                connection.execute(
                    "SELECT pg_advisory_xact_lock(hashtextextended(%s, 0))",
                    ("dw.dim_station",),
                )

                existing_rows = connection.execute(
                    """
                    SELECT station_id, station_name, short_name, region_id,
                           latitude, longitude, capacity, source_last_updated
                    FROM dw.dim_station
                    WHERE station_id = ANY(%s)
                    """,
                    (list(seen_ids),),
                ).fetchall()

                existing = {row[0]: row[1:] for row in existing_rows}
                to_insert = []
                to_update = []

                for row in prepared:
                    old = existing.get(row[0])

                    if old is None:
                        to_insert.append(row)
                    elif row[7] > old[-1]:
                        to_update.append(row[1:] + (row[0],))
                    elif row[7] == old[-1] and row[1:7] != old[:-1]:
                        raise ValueError(
                            f"Conflicting content at the same source time: {row[0]}"
                        )
                    # Identical versions and older versions are skipped.

                rows_inserted = 0
                rows_updated = 0

                with connection.cursor() as cursor:
                    if to_insert:
                        cursor.executemany(
                            """
                            INSERT INTO dw.dim_station (
                                station_id, station_name, short_name, region_id,
                                latitude, longitude, capacity,
                                source_last_updated, source_collected_at,
                                source_raw_run_id
                            )
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                            """,
                            to_insert,
                        )
                        rows_inserted = cursor.rowcount

                    if to_update:
                        cursor.executemany(
                            """
                            UPDATE dw.dim_station
                            SET station_name = %s,
                                short_name = %s,
                                region_id = %s,
                                latitude = %s,
                                longitude = %s,
                                capacity = %s,
                                source_last_updated = %s,
                                source_collected_at = %s,
                                source_raw_run_id = %s,
                                updated_at = clock_timestamp()
                            WHERE station_id = %s
                            """,
                            to_update,
                        )
                        rows_updated = cursor.rowcount

                connection.execute(
                    """
                    UPDATE ops.pipeline_run
                    SET status = 'success',
                        finished_at = clock_timestamp(),
                        rows_read = %s,
                        rows_inserted = %s,
                        rows_updated = %s
                    WHERE run_id = %s
                    """,
                    (rows_read, rows_inserted, rows_updated, load_run_id),
                )

        except Exception as error:
            connection.execute(
                """
                UPDATE ops.pipeline_run
                SET status = 'failed',
                    finished_at = clock_timestamp(),
                    rows_read = %s,
                    rows_inserted = 0,
                    rows_updated = 0,
                    error_message = %s
                WHERE run_id = %s
                """,
                (rows_read, str(error)[:2000], load_run_id),
            )
            raise

    print(f"Rows read: {rows_read}")
    print(f"Rows inserted: {rows_inserted}")
    print(f"Rows updated: {rows_updated}")
    print(f"Rows skipped: {rows_read - rows_inserted - rows_updated}")
    print("Station dimension load completed.")


if __name__ == "__main__":
    main()