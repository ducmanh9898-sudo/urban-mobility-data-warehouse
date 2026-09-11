# Reporting Metrics

## Data grain
One row per station, New York business date, and reporting policy version.

## Dashboard source
mart.v_station_daily_dashboard joins persisted daily reports with
current station attributes from the SCD Type 1 station dimension.

## Metrics
- sample_count: number of stored station snapshots for the day.
- time_eligible_sample_pct: percentage of samples passing the
  timestamp eligibility rules defined by the reporting policy.
- empty_bike_sample_pct: empty-bike samples divided by
  rental-eligible samples, multiplied by 100.
- no_dock_sample_pct: no-dock samples divided by
  return-eligible samples, multiplied by 100.
- A zero denominator produces NULL, not zero percent.

## Aggregation
Network percentages use summed numerators divided by summed
denominators. Do not average station percentages.

## Interpretation limits
- Percentages describe observed samples, not time durations.
- Snapshots do not directly measure trips or customer demand.
- Manual runs can produce uneven sampling intervals.
- A daily report may contain only part of the business day.
- observed_source_15min_slots is not proof of complete cron coverage.
- Current station attributes are not historical attributes.
- Rankings initially require at least 10 eligible samples.
  This is a configurable screening rule, not a statistical guarantee.

## Refresh behavior
Metrics reflect the latest successful daily report refresh.
New fact rows appear in these metrics after the report is refreshed.
Current station attributes can change independently of that refresh.