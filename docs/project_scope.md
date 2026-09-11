# Project Scope

## Objective

Build a warehouse of Citi Bike station availability snapshots
to support operational analysis.

## Business questions

- Which stations most frequently have zero available bikes?
- Which stations most frequently have zero available docks?
- How does station availability vary by hour and day?
- Are collected records complete, valid, and fresh enough
  for reporting?

## Initial data sources

- station_information: station ID, name, coordinates, and capacity.
- station_status: available bikes, available docks,
  operating flags, and source reporting timestamps.

Field availability and types must be verified against the feed.

## Planned collection schedule

- Collect station snapshots every 15 minutes.
- Build daily aggregates once per day.
- Store timestamps in UTC.
- Group business dates and hours using America/New_York.

## Measurement rules

- A snapshot represents station state at an observed time.
- Keep collection time and source timestamps separately.
- Availability metrics must consider station operating flags.
- Report collection coverage alongside availability metrics.
- A percentage of empty observations is a sample-based metric,
  not an exact percentage of elapsed time.

## Initial boundaries

- No individual rider information is collected.
- Station snapshots do not directly measure completed trips.
- Historical station states from before collection began
  are unavailable from these live feeds.
- Trip-history analysis is a possible future extension.

## Planned deliverables

- Python ingestion pipeline.
- PostgreSQL dimensional warehouse.
- Data quality checks and pipeline run logs.
- Linux cron schedules.
- Daily analytical marts and a Power BI dashboard.