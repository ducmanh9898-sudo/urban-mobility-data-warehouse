# Warehouse Design

## Database organization

- stg: staging records before warehouse loading.
- dw: dimensions and station snapshot facts.
- mart: analytical aggregates for reporting.
- ops: pipeline runs and data quality issues.

Raw API responses are stored separately in data/raw initially.

## Planned tables

| Table | Grain: what one row represents |
|---|---|
| dw.dim_station | One station, with its latest known attributes |
| dw.dim_date | One calendar date |
| dw.dim_time | One minute of the day |
| dw.fact_station_snapshot | One station in one distinct station_status feed version |
| mart.station_daily | One station on one business date |
| ops.pipeline_run | One pipeline execution |
| ops.data_quality_issue | One detected validation issue |

## Station dimension

Use a generated station_key as the primary key.
Keep station_id as a unique source identifier.

Initially use SCD Type 1:
update changed station attributes in place.

This version does not preserve historical station names,
coordinates, or capacity in the dimension.

## Snapshot identity

Within this single-source project, identify a snapshot by:
station_id + station_status source_last_updated.

The fact table will enforce uniqueness using:
station_key + source_last_updated.

Loading the same source snapshot again must not create duplicates.
If the same identity arrives with different values, record a
data quality conflict rather than silently overwriting it.

Preserve collected_at and last_reported separately.

## Time handling

Use TIMESTAMPTZ for timestamps.
Use UTC in pipeline processing.

Derive reporting date and time from source_last_updated
in the America/New_York timezone.

## Operational metrics

A rental-eligible observation requires:
is_installed = true AND is_renting = true.

A return-eligible observation requires:
is_installed = true AND is_returning = true.

Empty-bike observation:
rental-eligible AND num_bikes_available = 0.

No-dock observation:
return-eligible AND num_docks_available = 0.

Exclude invalid or stale observations from availability KPI
denominators and report them separately.

Freshness thresholds will be configured and documented
after profiling the source.

## Interpretation limits

Metrics describe collected observations, not exact durations.
Report missing collection intervals separately.
Do not infer completed trips from changes in bike counts.