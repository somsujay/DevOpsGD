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

# Determine connection
if [[ -n "${SNOWFLAKE_ACCOUNT:-}" && -n "${SNOWFLAKE_USER:-}" ]]; then
  # CI mode: set up connection from env vars
  mkdir -p ~/.snowflake && chmod 700 ~/.snowflake
  if [[ -n "${SNOWFLAKE_PRIVATE_KEY:-}" && ! -f ~/.snowflake/ci_key.p8 ]]; then
    echo "$SNOWFLAKE_PRIVATE_KEY" > ~/.snowflake/ci_key.p8
    chmod 600 ~/.snowflake/ci_key.p8
  fi
  # Use snow sql with inline params
  SNOW_CMD="snow sql --account $SNOWFLAKE_ACCOUNT --user $SNOWFLAKE_USER --authenticator SNOWFLAKE_JWT --private-key-path $HOME/.snowflake/ci_key.p8"
else
  # Local mode: use connection from environments.yml
  CONNECTION=$(python3 -c "
import yaml
with open('environments.yml') as f:
    config = yaml.safe_load(f)
print(config['$ENV']['connection'])
")
  SNOW_CMD="snow sql -c $CONNECTION"
fi

echo "==> Running smoke tests against $ENV ($DATABASE)"

# Verify schemas exist
FAILED=0
for SCHEMA in RAW CLEAN CONFORMED GOVERNANCE; do
  echo -n "   Checking $DATABASE.$SCHEMA... "
  if $SNOW_CMD \
    --database "$DATABASE" \
    --warehouse "$WAREHOUSE" \
    --schema "$SCHEMA" \
    -q "SELECT CURRENT_SCHEMA();" > /dev/null 2>&1; then
    echo "OK"
  else
    echo "MISSING"
    FAILED=1
  fi
done

if [[ "$FAILED" -eq 1 ]]; then
  echo "ERROR: One or more schemas are missing"
  exit 1
fi

echo "==> Smoke tests complete for $ENV"
