#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

trigger="${1:-manual}"

if (( $# > 0 )); then
    shift
fi

cd "$project_root"
mkdir -p "$project_root/logs"

log_file="$project_root/logs/daily-report-$(date -u +%F).log"
exec >> "$log_file" 2>&1

printf '\n[%s] Daily report trigger: %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$trigger"

if "$project_root/.venv/bin/python" -u \
    "$project_root/scripts/refresh_station_daily.py" "$@"; then

    printf '[%s] Daily report job succeeded\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
else
    exit_code=$?

    printf '[%s] Daily report job failed; exit_code=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$exit_code"

    exit "$exit_code"
fi