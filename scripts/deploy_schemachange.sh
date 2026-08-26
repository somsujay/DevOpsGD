#!/usr/bin/env bash
set -euo pipefail

# Parse arguments
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

echo "==> Deploying to environment: $ENV"

# Read database from environments.yml
DATABASE=$(python3 -c "
import yaml, sys
with open('environments.yml') as f:
    config = yaml.safe_load(f)
env = config.get('$ENV')
if not env:
    print(f'ERROR: Environment $ENV not found in environments.yml', file=sys.stderr)
    sys.exit(1)
print(env['database'])
")

WAREHOUSE=$(python3 -c "
import yaml
with open('environments.yml') as f:
    config = yaml.safe_load(f)
print(config['$ENV']['warehouse'])
")

echo "   Database: $DATABASE"
echo "   Warehouse: $WAREHOUSE"

# Read all schema variables from environments.yml
RAW_SCHEMA=$(python3 -c "
import yaml
with open('environments.yml') as f:
    config = yaml.safe_load(f)
print(config['$ENV']['raw_schema'])
")
CLEAN_SCHEMA=$(python3 -c "
import yaml
with open('environments.yml') as f:
    config = yaml.safe_load(f)
print(config['$ENV']['clean_schema'])
")
CONFORMED_SCHEMA=$(python3 -c "
import yaml
with open('environments.yml') as f:
    config = yaml.safe_load(f)
print(config['$ENV']['conformed_schema'])
")
GOVERNANCE_SCHEMA=$(python3 -c "
import yaml
with open('environments.yml') as f:
    config = yaml.safe_load(f)
print(config['$ENV']['governance_schema'])
")

# Build vars JSON
VARS_JSON="{\"database\": \"${DATABASE}\", \"warehouse\": \"${WAREHOUSE}\", \"raw_schema\": \"${RAW_SCHEMA}\", \"clean_schema\": \"${CLEAN_SCHEMA}\", \"conformed_schema\": \"${CONFORMED_SCHEMA}\", \"governance_schema\": \"${GOVERNANCE_SCHEMA}\", \"environment\": \"${ENV}\", \"role\": \"SYSADMIN\"}"
echo "   Vars: $VARS_JSON"
export SCHEMACHANGE_VARS="$VARS_JSON"

# Run schemachange
schemachange deploy \
  --root-folder finance-data-platform \
  --snowflake-account "$SNOWFLAKE_ACCOUNT" \
  --snowflake-user "$SNOWFLAKE_USER" \
  --snowflake-private-key-path ~/.snowflake/ci_key.p8 \
  --snowflake-warehouse "$WAREHOUSE" \
  --snowflake-database "$DATABASE" \
  --change-history-table "$DATABASE.METADATA.CHANGE_HISTORY" \
  --create-change-history-table \
  --vars "$VARS_JSON"

echo "==> Deployment complete for $ENV"
