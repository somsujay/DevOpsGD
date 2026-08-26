#!/usr/bin/env bash
set -euo pipefail

ENV=""
for arg in "$@"; do
  case "$arg" in
    --env=*) ENV="${arg#*=}" ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "ERROR: --env is required (dev|stage|prod)"
  exit 1
fi

DATABASE=$(python3 -c "
import yaml
with open('environments.yml') as f:
    config = yaml.safe_load(f)
print(config['$ENV']['database'])
")

WAREHOUSE=$(python3 -c "
import yaml
with open('environments.yml') as f:
    config = yaml.safe_load(f)
print(config['$ENV']['warehouse'])
")

echo "==> Running smoke tests against $ENV ($DATABASE)"

# Verify schemas exist
for SCHEMA in RAW CLEAN CONFORMED GOVERNANCE; do
  echo -n "   Checking $DATABASE.$SCHEMA... "
  snow sql -c MY_TRIAL_ACCOUNT \
    --database "$DATABASE" \
    --warehouse "$WAREHOUSE" \
    -q "SELECT CURRENT_SCHEMA();" \
    --schema "$SCHEMA" > /dev/null 2>&1 && echo "OK" || echo "MISSING"
done

echo "==> Smoke tests complete for $ENV"
