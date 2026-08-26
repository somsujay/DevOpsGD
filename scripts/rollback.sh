#!/usr/bin/env bash
set -euo pipefail

ENV=""
VERSION=""
for arg in "$@"; do
  case "$arg" in
    --env=*) ENV="${arg#*=}" ;;
    --version=*) VERSION="${arg#*=}" ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "ERROR: --env is required (dev|stage|prod)"
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  echo "ERROR: --version is required (e.g., v1.2.0)"
  exit 1
fi

echo "==> Rolling back $ENV to version: $VERSION"

# Checkout the target version's SQL
git checkout "$VERSION" -- finance-data-platform/

# Re-run deployment at that version
bash scripts/deploy_schemachange.sh --env="$ENV"

echo "==> Rollback complete: $ENV is now at $VERSION"
