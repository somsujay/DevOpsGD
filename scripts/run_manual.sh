#!/usr/bin/env bash
set -euo pipefail

# Runs manual scripts that are not part of the automated pipeline.
# Usage:
#   bash scripts/run_manual.sh --script=platform --env=dev
#   bash scripts/run_manual.sh --script=grants --env=dev
#   bash scripts/run_manual.sh --script=all --env=dev

SCRIPT=""
ENV=""
for arg in "$@"; do
  case "$arg" in
    --script=*) SCRIPT="${arg#*=}" ;;
    --env=*) ENV="${arg#*=}" ;;
  esac
done

if [[ -z "$SCRIPT" || -z "$ENV" ]]; then
  echo "Usage: bash scripts/run_manual.sh --script=<platform|grants|all> --env=<dev|stage|prod>"
  exit 1
fi

# Read config from environments.yml
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

CONNECTION=$(python3 -c "
import yaml
with open('environments.yml') as f:
    config = yaml.safe_load(f)
print(config['$ENV']['connection'])
")

# Build Jinja variables for substitution
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

# Render Jinja templates and execute
run_sql_file() {
  local FILE="$1"
  local DESC="$2"

  echo "==> Running: $DESC ($FILE)"
  echo "    Database: $DATABASE | Warehouse: $WAREHOUSE"

  # Render Jinja variables
  RENDERED=$(python3 -c "
import sys
with open('$FILE') as f:
    content = f.read()
content = content.replace('{{ database }}', '$DATABASE')
content = content.replace('{{ warehouse }}', '$WAREHOUSE')
content = content.replace('{{ raw_schema }}', '$RAW_SCHEMA')
content = content.replace('{{ clean_schema }}', '$CLEAN_SCHEMA')
content = content.replace('{{ conformed_schema }}', '$CONFORMED_SCHEMA')
content = content.replace('{{ governance_schema }}', '$GOVERNANCE_SCHEMA')
content = content.replace('{{ environment }}', '$ENV')
content = content.replace('{{ role }}', 'SYSADMIN')
print(content)
")

  # Execute rendered SQL
  echo "$RENDERED" | snow sql -c "$CONNECTION" \
    --database "$DATABASE" \
    --warehouse "$WAREHOUSE" \
    -i

  echo "    Done: $DESC"
  echo ""
}

case "$SCRIPT" in
  platform)
    run_sql_file "manual-scripts/_platform/V1.000.100__setup_schemas.sql" "Schema setup"
    ;;
  grants)
    run_sql_file "manual-scripts/A__grants.sql" "Apply grants"
    ;;
  all)
    run_sql_file "manual-scripts/_platform/V1.000.100__setup_schemas.sql" "Schema setup"
    run_sql_file "manual-scripts/A__grants.sql" "Apply grants"
    ;;
  *)
    echo "ERROR: Unknown script '$SCRIPT'. Use: platform, grants, or all"
    exit 1
    ;;
esac

echo "==> Manual scripts complete for $ENV"
