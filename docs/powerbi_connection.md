# Power BI Desktop Connection

- Server: localhost:5433
- Database: mobility_dw
- Authentication: Database
- Username: mobility_bi
- Mode: Import
- Source view: mart.v_station_daily_dashboard
- Power Query name: Station Daily

Set the reader password interactively with psql:
\password mobility_bi

Do not store the password in this repository.

Keep station_id as Text and business_date as Date.

Refresh the daily report in PostgreSQL before refreshing Power BI
when updated daily metrics are needed.