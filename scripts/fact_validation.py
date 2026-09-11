from datetime import datetime, timezone
from zoneinfo import ZoneInfo


BUSINESS_TIMEZONE = ZoneInfo("America/New_York")


def whole_number(value, field, maximum=2147483647):
    if type(value) not in (int, float):
        raise ValueError(f"{field} must be numeric")

    if not 0 <= value <= maximum:
        raise ValueError(f"{field} is outside the allowed range")

    if value != int(value):
        raise ValueError(f"{field} must be an integer")

    return int(value)


def optional_count(record, field):
    value = record.get(field)
    if value is None:
        return None
    return whole_number(value, field)


def boolean_value(value, field):
    if type(value) is bool:
        return value

    if type(value) in (int, float) and value in (0, 1):
        return bool(value)

    raise ValueError(f"{field} must be boolean or numeric 0/1")


def prepare_snapshot(
    record,
    source_time,
    collected_at,
    station_keys,
    raw_run_id,
    load_run_id,
):
    if not isinstance(record, dict):
        raise ValueError("Station status must be an object")

    station_id = record.get("station_id")
    if not isinstance(station_id, str) or not station_id.strip():
        raise ValueError("Invalid station_id")

    if station_id not in station_keys:
        raise ValueError(f"Station missing from dimension: {station_id}")

    reported_epoch = whole_number(
        record.get("last_reported"),
        "last_reported",
        maximum=253402300799,
    )

    # Explicit project rule: zero represents unknown reporting time.
    # Other valid timestamps are preserved, even when very old.
    last_reported = (
        None
        if reported_epoch == 0
        else datetime.fromtimestamp(reported_epoch, timezone.utc)
    )

    business_time = source_time.astimezone(BUSINESS_TIMEZONE)
    date_key = (
        business_time.year * 10000
        + business_time.month * 100
        + business_time.day
    )
    time_key = business_time.hour * 60 + business_time.minute

    return (
        station_keys[station_id],
        date_key,
        time_key,
        whole_number(
            record.get("num_bikes_available"), "num_bikes_available"
        ),
        whole_number(
            record.get("num_docks_available"), "num_docks_available"
        ),
        optional_count(record, "num_bikes_disabled"),
        optional_count(record, "num_docks_disabled"),
        boolean_value(record.get("is_installed"), "is_installed"),
        boolean_value(record.get("is_renting"), "is_renting"),
        boolean_value(record.get("is_returning"), "is_returning"),
        source_time,
        collected_at,
        last_reported,
        raw_run_id,
        load_run_id,
    )