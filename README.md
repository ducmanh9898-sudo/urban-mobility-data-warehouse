# Urban Mobility Data Warehouse

A data engineering portfolio project that builds a PostgreSQL
data warehouse from real Citi Bike station availability data.

## Business objective

Analyze station availability patterns to identify stations
that frequently have no available bikes or no available docks.

## Data source

Citi Bike public GBFS feeds:
- station_information: station metadata and location.
- station_status: current station availability and operating status.

Source: https://citibikenyc.com/system-data

## Technology

- Python: data ingestion and processing.
- PostgreSQL: data warehouse and analytical SQL.
- Docker Compose: local database environment.
- Linux cron: planned scheduled execution.
- Power BI: planned reporting and visualization.

## Current progress

- Project structure initialized.
- Local PostgreSQL running through Docker Compose.
- Database connectivity verified.

## Planned features

- Periodic collection of station snapshots.
- Raw response storage.
- Data validation and duplicate prevention.
- Dimensional modeling and daily analytical marts.
- Scheduled execution, run logs, and failure handling.
- Data quality and availability dashboards.

## Local database setup

1. Copy `.env.example` to `.env`.
2. Set a local database password.
3. Run `docker compose up -d`.
4. Check the service using `docker compose ps`.

## Data handling

Credentials, raw data, and runtime logs are excluded from Git.
Data use follows the source provider's data policy.