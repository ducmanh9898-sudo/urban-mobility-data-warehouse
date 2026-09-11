import argparse
from uuid import UUID, uuid4

from db_connection import connect_database
from fact_validation import prepare_snapshot


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
            VALUES (%s, %s, 'load_fact_snapshot', 'running')
            """,
            (load_run_id, raw_run_id),
        )

        try:
            source_rows = connection.execute(
                """
                SELECT source_row_number, payload,
                       source_last_updated, collected_at
                FROM stg.station_status
                WHERE raw_run_id = %s
                ORDER BY source_row_number
                """,
                (raw_run_id,),
            ).fetchall()

            rows_read = len(source_rows)
            if not source_rows:
                raise ValueError("No station status found in staging")

            source_times = {row[2] for row in source_rows}
            if len(source_times) != 1:
                raise ValueError("Inconsistent source timestamps in batch")

            source_time = source_rows[0][2]

            station_keys = dict(connection.execute(
                "SELECT station_id, station_key FROM dw.dim_station"
            ).fetchall())

            prepared = []
            seen_keys = set()

            for position, record, updated_at, collected_at in source_rows:
                try:
                    row = prepare_snapshot(
                        record,
                        updated_at,
                        collected_at,
                        station_keys,
                        raw_run_id,
                        load_run_id,
                    )
                except ValueError as error:
                    raise ValueError(
                        f"Source row {position}: {error}"
                    ) from error

                if row[0] in seen_keys:
                    raise ValueError(
                        f"Duplicate station within snapshot: {row[0]}"
                    )

                seen_keys.add(row[0])
                prepared.append(row)

            with connection.transaction():
                # Serialize loaders handling the same feed version.
                lock_name = f"fact_station_snapshot:{source_time.isoformat()}"
                connection.execute(
                    "SELECT pg_advisory_xact_lock(hashtextextended(%s, 0))",
                    (lock_name,),
                )

                existing_rows = connection.execute(
                    """
                    SELECT station_key, date_key, time_key,
                           num_bikes_available, num_docks_available,
                           num_bikes_disabled, num_docks_disabled,
                           is_installed, is_renting, is_returning,
                           source_last_updated, last_reported
                    FROM dw.fact_station_snapshot
                    WHERE source_last_updated = %s
                      AND station_key = ANY(%s)
                    """,
                    (source_time, list(seen_keys)),
                ).fetchall()

                existing = {row[0]: row for row in existing_rows}
                to_insert = []

                for row in prepared:
                    old = existing.get(row[0])

                    # Compare source content, excluding collection/load metadata.
                    source_content = row[:11] + (row[12],)

                    if old is None:
                        to_insert.append(row)
                    elif old != source_content:
                        raise ValueError(
                            "Conflicting content for station_key "
                            f"{row[0]} at {source_time.isoformat()}"
                        )
                    # An identical snapshot keeps its first collection metadata.

                rows_inserted = 0

                if to_insert:
                    with connection.cursor() as cursor:
                        cursor.executemany(
                            """
                            INSERT INTO dw.fact_station_snapshot (
                                station_key, date_key, time_key,
                                num_bikes_available, num_docks_available,
                                num_bikes_disabled, num_docks_disabled,
                                is_installed, is_renting, is_returning,
                                source_last_updated, collected_at, last_reported,
                                raw_run_id, load_run_id
                            )
                            VALUES (
                                %s, %s, %s, %s, %s,
                                %s, %s, %s, %s, %s,
                                %s, %s, %s, %s, %s
                            )
                            """,
                            to_insert,
                        )
                        rows_inserted = cursor.rowcount

                connection.execute(
                    """
                    UPDATE ops.pipeline_run
                    SET status = 'success',
                        finished_at = clock_timestamp(),
                        rows_read = %s,
                        rows_inserted = %s
                    WHERE run_id = %s
                    """,
                    (rows_read, rows_inserted, load_run_id),
                )

        except Exception as error:
            connection.execute(
                """
                UPDATE ops.pipeline_run
                SET status = 'failed',
                    finished_at = clock_timestamp(),
                    rows_read = %s,
                    rows_inserted = 0,
                    error_message = %s
                WHERE run_id = %s
                """,
                (rows_read, str(error)[:2000], load_run_id),
            )
            raise

    print(f"Rows read: {rows_read}")
    print(f"Rows inserted: {rows_inserted}")
    print(f"Rows skipped: {rows_read - rows_inserted}")
    print("Fact snapshot load completed.")


if __name__ == "__main__":
    main()