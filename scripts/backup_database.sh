#!/usr/bin/env bash
set -euo pipefail
umask 077

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

backup_dir="$project_root/backups"
mkdir -p "$backup_dir"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

temporary_file="$(mktemp \
    --suffix=.part \
    "$backup_dir/mobility_dw_${timestamp}_XXXXXX")"

backup_file="${temporary_file%.part}.dump"

# Remove the incomplete file if the backup fails.
trap 'rm -f -- "$temporary_file"' EXIT

docker compose exec -T postgres sh -c \
    'exec pg_dump \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        --format=custom' \
    > "$temporary_file"

test -s "$temporary_file"

mv -- "$temporary_file" "$backup_file"

# Print only the completed backup path.
printf '%s\n' "$backup_file"