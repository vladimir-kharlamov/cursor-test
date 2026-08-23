#!/bin/sh
set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

cd "$PROJECT_ROOT"
printf '%s\n' 'Seeding 1,000,000 rows into posts...'
docker compose exec -T postgres psql -U cursor_user -d cursor_test < sql/seed/seed-1m.sql
printf '%s\n' 'Seed complete. Row count:'
docker compose exec -T postgres psql -U cursor_user -d cursor_test -c 'SELECT count(*) FROM posts;'
