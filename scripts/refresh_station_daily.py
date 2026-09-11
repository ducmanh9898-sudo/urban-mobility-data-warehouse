import argparse
from datetime import date, datetime, timedelta
from uuid import uuid4
from zoneinfo import ZoneInfo

from db_connection import connect_database


POLICY_VERSION = "v1"
BUSINESS_TIMEZONE = ZoneInfo("America/New_York")

REPORT_COLUMNS = """
    station_key,
    date_key,
    business_date,
    policy_version,
    sample_count,
    time_eligible_samples,
    time_ineligible_samples,
    accepted_future_samples,
    rental_eligible_samples,
    empty_bike_samples,
    return_eligible_samples,
    no_dock_samples,
    avg_available_bikes,
    avg_available_docks,
    observed_source_15min_slots,
    first_source_updated,
    last_source_updated,
    empty_bike_sample_pct,
    no_dock_sample_pct
"""


def refresh_report(business_date):
    run_id = uuid4()
    date_key = int(business_date.strftime("%Y%m%d"))
    source_count = 0

    print(f"Reporting run ID: {run_id}", flush=True)
    print(f"Business date: {business_date}", flush=True)
    print(f"Policy version: {POLICY_VERSION}", flush=True)

    with connect_database() as connection:
        connection.execute(
            """
            INSERT INTO ops.reporting_run (
                run_id, business_date, policy_version, status
            )
            VALUES (%s, %s, %s, 'running')
            """,
            (run_id, business_date, POLICY_VERSION),
        )

        try:
            # Session lock: released when this connection closes.
            # Acquire before starting the reporting transaction.
            lock_name = (
                f"station_daily:{business_date}:{POLICY_VERSION}"
            )
            connection.execute(
                "SELECT pg_advisory_lock(hashtextextended(%s, 0))",
                (lock_name,),
            )

            with connection.transaction():
                connection.execute(
                    "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ"
                )

                source_count = connection.execute(
                    """
                    SELECT COUNT(*)
                    FROM dw.fact_station_snapshot
                    WHERE date_key = %s
                    """,
                    (date_key,),
                ).fetchone()[0]

                if source_count == 0:
                    raise ValueError(
                        f"No fact samples for {business_date}; "
                        "existing report has not been replaced."
                    )

                # Replace only the requested date and policy.
                connection.execute(
                    """
                    DELETE FROM mart.station_daily
                    WHERE business_date = %s
                      AND policy_version = %s
                    """,
                    (business_date, POLICY_VERSION),
                )

                # REPORT_COLUMNS is a fixed internal constant.
                connection.execute(
                    f"""
                    INSERT INTO mart.station_daily (
                        {REPORT_COLUMNS},
                        refreshed_at,
                        reporting_run_id
                    )
                    SELECT
                        {REPORT_COLUMNS},
                        CURRENT_TIMESTAMP,
                        %s
                    FROM mart.v_station_daily
                    WHERE business_date = %s
                      AND policy_version = %s
                    """,
                    (run_id, business_date, POLICY_VERSION),
                )

                rows_written, report_samples = connection.execute(
                    """
                    SELECT
                        COUNT(*),
                        COALESCE(SUM(sample_count), 0)
                    FROM mart.station_daily
                    WHERE business_date = %s
                      AND policy_version = %s
                      AND reporting_run_id = %s
                    """,
                    (business_date, POLICY_VERSION, run_id),
                ).fetchone()

                if report_samples != source_count:
                    raise ValueError(
                        "Sample reconciliation failed: "
                        f"fact={source_count}, report={report_samples}"
                    )

                connection.execute(
                    """
                    UPDATE ops.reporting_run
                    SET status = 'success',
                        finished_at = clock_timestamp(),
                        source_sample_count = %s,
                        rows_written = %s
                    WHERE run_id = %s
                    """,
                    (source_count, rows_written, run_id),
                )

        except Exception as exc:
            # The reporting transaction has rolled back.
            connection.execute(
                """
                UPDATE ops.reporting_run
                SET status = 'failed',
                    finished_at = clock_timestamp(),
                    source_sample_count = %s,
                    rows_written = 0,
                    error_message = %s
                WHERE run_id = %s
                """,
                (source_count, str(exc)[:2000], run_id),
            )
            raise

    print(f"Source samples: {source_count}", flush=True)
    print(f"Report rows written: {rows_written}", flush=True)
    print("Daily report refresh completed.", flush=True)


def main():
    today = datetime.now(BUSINESS_TIMEZONE).date()

    parser = argparse.ArgumentParser(
        description="Refresh the station daily reporting table."
    )
    parser.add_argument(
        "--date",
        type=date.fromisoformat,
        default=today - timedelta(days=1),
        help="Business date YYYY-MM-DD; default: yesterday in New York.",
    )
    args = parser.parse_args()

    if args.date > today:
        parser.error("--date cannot be a future business date")

    if args.date == today:
        print(
            "Current business day: this report contains "
            "only samples available so far.",
            flush=True,
        )

    refresh_report(args.date)


if __name__ == "__main__":
    main()