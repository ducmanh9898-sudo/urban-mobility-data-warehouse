import argparse
import gzip
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID, uuid4

from psycopg import sql
from psycopg.types.json import Jsonb

from db_connection import connect_database


FEED_NAMES = ("station_information", "station_status")


def read_feed(manifest_path, feed):
    name = feed["name"]
    filename = f"{name}.json.gz"

    if feed["file"] != filename:
        raise ValueError(f"Unexpected filename: {name}")

    with gzip.open(manifest_path.parent / filename, "rb") as file:
        body = file.read()

    if hashlib.sha256(body).hexdigest() != feed["sha256"]:
        raise ValueError(f"Checksum mismatch: {name}")

    payload = json.loads(body)
    if payload.get("version") != "2.3" or feed["version"] != "2.3":
        raise ValueError(f"Unexpected GBFS version: {name}")

    stations = payload["data"]["stations"]
    if not isinstance(stations, list) or not stations:
        raise ValueError(f"Empty or invalid station list: {name}")

    if len(stations) != feed["record_count"]:
        raise ValueError(f"Record count mismatch: {name}")

    source_timestamp = payload["last_updated"]
    if type(source_timestamp) is not int or source_timestamp <= 0:
        raise ValueError(f"Invalid source timestamp: {name}")

    if source_timestamp != feed["source_last_updated"]:
        raise ValueError(f"Source timestamp mismatch: {name}")

    source_time = datetime.fromtimestamp(source_timestamp, timezone.utc)
    collected_at = datetime.fromisoformat(feed["collected_at"])

    if collected_at.tzinfo is None:
        raise ValueError(f"Missing collection timezone: {name}")

    return stations, source_time, collected_at


def insert_feed(connection, name, data, raw_run_id, load_run_id):
    stations, source_time, collected_at = data
    table = sql.Identifier("stg", name)

    # Refuse to silently reuse a raw ID with changed content.
    existing = connection.execute(
        sql.SQL("""
            SELECT source_row_number, payload,
                   source_last_updated, collected_at
            FROM {}
            WHERE raw_run_id = %s
        """).format(table),
        (raw_run_id,),
    ).fetchall()

    for row_number, payload, old_source_time, old_collected_at in existing:
        if (
            row_number > len(stations)
            or payload != stations[row_number - 1]
            or old_source_time != source_time
            or old_collected_at != collected_at
        ):
            raise ValueError(f"Existing staging content differs: {name}")

    statement = sql.SQL("""
        INSERT INTO {} (
            raw_run_id, source_row_number, load_run_id,
            payload, source_last_updated, collected_at
        )
        VALUES (%s, %s, %s, %s, %s, %s)
        ON CONFLICT (raw_run_id, source_row_number) DO NOTHING
    """).format(table)

    rows = [
        (
            raw_run_id,
            position,
            load_run_id,
            Jsonb(station),
            source_time,
            collected_at,
        )
        for position, station in enumerate(stations, start=1)
    ]

    with connection.cursor() as cursor:
        cursor.executemany(statement, rows)
        return cursor.rowcount


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()

    manifest_path = args.manifest.resolve()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    raw_run_id = UUID(manifest["run_id"])
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
            VALUES (%s, %s, 'load_staging', 'running')
            """,
            (load_run_id, raw_run_id),
        )

        try:
            if manifest.get("status") != "collected":
                raise ValueError("Collection is not complete")

            entries = manifest["feeds"]
            if (
                len(entries) != 2
                or {entry["name"] for entry in entries} != set(FEED_NAMES)
            ):
                raise ValueError("Expected exactly two station feeds")

            feeds = {entry["name"]: entry for entry in entries}
            prepared = {}

            for name in FEED_NAMES:
                prepared[name] = read_feed(manifest_path, feeds[name])
                rows_read += len(prepared[name][0])

            rows_inserted = 0

            with connection.transaction():
                # Serialize loads of the same raw collection.
                connection.execute(
                    "SELECT pg_advisory_xact_lock(hashtextextended(%s, 0))",
                    (str(raw_run_id),),
                )

                for name in FEED_NAMES:
                    rows_inserted += insert_feed(
                        connection,
                        name,
                        prepared[name],
                        raw_run_id,
                        load_run_id,
                    )

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
    print("Staging load completed.")


if __name__ == "__main__":
    main()