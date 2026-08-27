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

# Set up Snowflake connection for CI
if [[ -n "${SNOWFLAKE_ACCOUNT:-}" ]]; then
  mkdir -p ~/.snowflake && chmod 700 ~/.snowflake
  if [[ -n "${SNOWFLAKE_PRIVATE_KEY:-}" && ! -f ~/.snowflake/ci_key.p8 ]]; then
    echo "$SNOWFLAKE_PRIVATE_KEY" > ~/.snowflake/ci_key.p8
    chmod 600 ~/.snowflake/ci_key.p8
  fi
  cat > ~/.snowflake/connections.toml <<TOML
[default]
account = "${SNOWFLAKE_ACCOUNT}"
user = "${SNOWFLAKE_USER}"
authenticator = "SNOWFLAKE_JWT"
private_key_path = "${HOME}/.snowflake/ci_key.p8"
warehouse = "${WAREHOUSE}"
TOML
  chmod 600 ~/.snowflake/connections.toml
  CONNECTION="default"
else
  CONNECTION="MY_TRIAL_ACCOUNT"
fi

echo "==> Running smoke tests against $ENV ($DATABASE)"

# Verify schemas exist
FAILED=0
for SCHEMA in RAW CLEAN CONFORMED GOVERNANCE; do
  echo -n "   Checking $DATABASE.$SCHEMA... "
  if snow sql -c "$CONNECTION" \
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
