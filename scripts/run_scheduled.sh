#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
trigger="${1:-manual}"

cd "$project_root"

mkdir -p "$project_root/logs"
log_file="$project_root/logs/pipeline-$(date -u +%F).log"

exec >> "$log_file" 2>&1

printf '\n[%s] Trigger: %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$trigger"

exec "$project_root/.venv/bin/python" \
    -u "$project_root/scripts/run_pipeline.py"