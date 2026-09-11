# Data Dictionary

Source: Citi Bike GBFS 2.3.
Scope: initial fields selected for the warehouse.

## Station information

| Source field | Planned SQL type | Meaning |
|---|---|---|
| station_id | TEXT | Station identifier |
| name | TEXT | Station name |
| short_name | TEXT | Short station code; preserve as text |
| lat | DOUBLE PRECISION | Latitude |
| lon | DOUBLE PRECISION | Longitude |
| region_id | TEXT | Region identifier |
| capacity | INTEGER | Station capacity |

## Station status

| Source field | Planned SQL type | Meaning |
|---|---|---|
| station_id | TEXT | Links status to station information |
| num_bikes_available | INTEGER | Available bikes |
| num_bikes_disabled | INTEGER | Unavailable bikes |
| num_docks_available | INTEGER | Available docks |
| num_docks_disabled | INTEGER | Unavailable docks |
| is_installed | BOOLEAN | Whether the station is installed |
| is_renting | BOOLEAN | Whether rentals are allowed |
| is_returning | BOOLEAN | Whether returns are allowed |
| last_reported | TIMESTAMPTZ | Station reporting time, converted from Unix seconds |

## Feed and ingestion metadata

| Field | Planned SQL type | Meaning |
|---|---|---|
| source_last_updated | TIMESTAMPTZ | Feed-level last_updated, converted from Unix seconds |
| collected_at | TIMESTAMPTZ | Time our collector received the response |
| run_id | UUID | Identifier of the pipeline execution |

## Initial validation rules

- station_id must be a non-empty string.
- Counts and capacity must be non-negative integers when present.
- Latitude must be between -90 and 90.
- Longitude must be between -180 and 180.
- Normalize supported boolean representations explicitly.
- Missing optional values remain NULL; do not replace with zero.
- Preserve raw responses for investigation and replay.
- Check duplicate IDs and unmatched IDs between feeds.