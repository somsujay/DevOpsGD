# Operations Guide

## Overview

This project deploys a Snowflake data platform with a RAW/CLEAN/CONFORMED layered architecture. Schema changes are managed by **schemachange** — an open-source, version-controlled database migration tool for Snowflake. All migrations live in the `finance-data-platform/` directory and are parameterized via Jinja2 templating for multi-environment support.

---

## Prerequisites

### Local Development

1. **Python 3.11+** with dependencies: `pip install -r requirements.txt`
2. **Snowflake CLI** (`snow`): `pip install snowflake-cli-labs`
3. **Key-pair auth**: RSA private key at `~/.snowflake/ci_key.p8` (or set `SNOWFLAKE_PRIVATE_KEY_PATH`)
4. **Environment variables**:
   ```bash
   export SNOWFLAKE_ACCOUNT=<your_account>
   export SNOWFLAKE_USER=<your_user>
   ```

### CI/CD (GitHub Actions)

Set these **repository secrets** (Settings > Secrets and variables > Actions):

| Secret | Description |
|--------|-------------|
| `SNOWFLAKE_ACCOUNT` | Account identifier (e.g., `KXAXARZ-GW22129`) |
| `SNOWFLAKE_USER` | Snowflake username (e.g., `SUJAYSOM`) |
| `SNOWFLAKE_PRIVATE_KEY` | Contents of the `.p8` private key file |

For the **production** environment, also set:
- `SNOWFLAKE_PROD_ACCOUNT`
- `SNOWFLAKE_PROD_USER`
- `SNOWFLAKE_PROD_PRIVATE_KEY`

---

## Environment Configuration

All environments are defined in `environments.yml`. Each environment is a **separate database** with identical schema names (no suffixes):

| Environment | Database | Schemas | Warehouse | Trigger |
|-------------|----------|---------|-----------|---------|
| dev | FINANCE_CORE_DEV_POC | RAW, CLEAN, CONFORMED, GOVERNANCE | COMPUTE_WH | Push to `develop` |
| stage | FINANCE_CORE_STAGE | RAW, CLEAN, CONFORMED, GOVERNANCE | COMPUTE_WH | Push to `release/*` |
| prod | FINANCE_CORE_PROD | RAW, CLEAN, CONFORMED, GOVERNANCE | COMPUTE_WH | Tag `v*` |

### Environment Variable Overrides

All scripts respect these environment variables (with defaults shown):

```bash
SNOWFLAKE_ACCOUNT=<your_account>
SNOWFLAKE_USER=<your_user>
SNOWFLAKE_PRIVATE_KEY_PATH=~/.snowflake/ci_key.p8
SNOWFLAKE_ROLE=SYSADMIN
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
```

Example override:
```bash
SNOWFLAKE_WAREHOUSE=LARGE_WH bash scripts/deploy_schemachange.sh --env=dev
```

---

## Scripts Reference

All scripts are located in the `scripts/` directory. Run from the project root.

### Initial Deployment

```bash
# Deploy all migrations to dev (first run creates the change history table automatically)
bash scripts/deploy_schemachange.sh --env=dev
```

### Environment-Aware Deployment (CI/CD)

```bash
# Deploy to a specific environment
bash scripts/deploy_schemachange.sh --env=dev
bash scripts/deploy_schemachange.sh --env=stage
bash scripts/deploy_schemachange.sh --env=prod

# Dry-run (shows what would be deployed without executing)
bash scripts/deploy_schemachange.sh --env=prod --dry-run
```

### Data Loading

```bash
# Historical load (full reset + initial data)
bash scripts/run_historical.sh --env=dev                  # CSV source (default)
bash scripts/run_historical.sh --env=dev --source=iceberg # Iceberg/Parquet source
bash scripts/run_historical.sh --env=stage                # Target STAGE environment

# Incremental load (requires historical load first)
bash scripts/run_incremental.sh --env=dev                  # CSV source (default)
bash scripts/run_incremental.sh --env=dev --source=iceberg # Iceberg/Parquet source
```

### Testing

```bash
# Smoke tests (schema/object existence checks)
bash scripts/run_smoke_tests.sh --env=dev

# Integration tests (object counts, procedure verification, policy checks)
# Executed via CI workflows after smoke tests pass
```

### Teardown

```bash
# Preview what will be dropped (dry-run)
bash scripts/drop_objects.sh

# Actually drop all objects (DESTRUCTIVE - cannot be undone)
bash scripts/drop_objects.sh --confirm
```

### Rollback

```bash
# Rollback to a previous version (stage/prod only)
bash scripts/rollback.sh --env=stage --version=v1.2.0
bash scripts/rollback.sh --env=prod --version=abc123f
```

---

## CI/CD Pipeline

### Workflow Triggers

| Workflow | Trigger | File |
|----------|---------|------|
| CI Lint & Validate | Push to `feature/**`, PR to `develop`, `release/*`, `main` | `.github/workflows/ci.yml` |
| Deploy to DEV | Push to `develop` | `.github/workflows/deploy-dev.yml` |
| Deploy to STAGE | Push to `release/*` | `.github/workflows/deploy-stage.yml` |
| Deploy to PROD | Tag `v*` or manual dispatch | `.github/workflows/deploy-prod.yml` |

### CI Pipeline Steps

1. **SQL Lint** — `sqlfluff lint finance-data-platform/` with Snowflake dialect
2. **Script Validation** — Verifies migration scripts exist with proper naming (V/R/A prefixes) and `environments.yml` structure

> **Note:** Branch patterns use `feature/**` (double-star) to match nested branch names like `feature/JIRA-123/add-table`. A single `*` only matches one path segment. Additionally, the CI workflow only triggers when changed files fall within the listed `paths` (`finance-data-platform/**`, `scripts/**`, `tests/**`, `environments.yml`, `schemachange-config.yml`, `.sqlfluff`) — pushes that only modify files outside these paths (e.g., README, docs) will not trigger the lint.

> **Important:** GitHub Actions reads the workflow file from the branch being pushed. If your feature branch was created before `ci.yml` was updated with the `push` trigger, the workflow won't fire because the branch still has the old version of `ci.yml`. Fix by rebasing or merging from `develop`:
> ```bash
> git checkout feature/xyz
> git merge develop   # brings in the updated ci.yml
> git push
> ```

### Deployment Pipeline Steps

1. **Deploy** — Runs `deploy_schemachange.sh` for the target environment (applies only unapplied migrations)
2. **Smoke Tests** — Validates all objects were created
3. **Integration/Regression Tests** — Validates object counts, procedures, policies

### Branch Guard (Merge Path Enforcement)

The `branch-guard.yml` workflow blocks PRs that violate the branching flow. Allowed paths:

| Source | Target | Allowed |
|--------|--------|---------|
| `feature` / `feature/*` | `develop` | Yes |
| `develop` | `release/*` | Yes |
| `release/*` | `main` | Yes |
| `hotfix/*` | `main` | Yes |
| Any other combination | — | **Blocked** |

To make this a hard gate, mark **"Enforce Branching Rules"** as a required status check in GitHub branch protection settings for `develop`, `release/*`, and `main`.

### Production Rollback (Manual)

**Option 1: GitHub CLI (from terminal)**

```bash
gh workflow run deploy-prod.yml -f action=rollback -f rollback_version=v1.2.0
```

Replace `v1.2.0` with the tag or commit SHA you want to roll back to.

**Option 2: GitHub UI (browser)**

1. Go to your repo on GitHub
2. Click **Actions** tab
3. Select **Deploy to PROD** workflow on the left
4. Click **Run workflow** button (top right)
5. Select:
   - **Action to perform:** `rollback`
   - **Version to rollback to:** enter the tag (e.g., `v1.2.0`) or commit SHA
6. Click **Run workflow**

The production environment requires 2 reviewer approvals before the rollback executes (configured in your GitHub environment protection rules).

**Prerequisites:**

- The tag/SHA must exist in git history
- You must have write access to the repo
- For the CLI option, you need `gh` authenticated (`gh auth login`)

---

## Schemachange Migrations

All migrations live in `finance-data-platform/` and are managed by [schemachange](https://github.com/Snowflake-Labs/schemachange). Schemachange recursively discovers scripts in subdirectories and executes them based on version order.

### Script Types

| Prefix | Behavior | Example |
|--------|----------|---------|
| `V` | Versioned — runs exactly once, in version order | `V1.050.200__create_clean_tables.sql` |
| `R` | Repeatable — re-runs whenever file content changes (checksum) | `R__ecomm_views.sql` |
| `A` | Always — runs on every deployment | `A__grants.sql` |

### Migration Inventory

| Version | Location | Objects Created |
|---------|----------|----------------|
| V1.050.100 | `raw/ecomm/` | T_Customer, T_Account, T_Transaction |
| V1.050.200 | `clean/ecomm/` | DimCustomer, DimAccount, DimTransactionType, DimDate |
| V1.050.300 | `conformed/ecomm/` | FactDailyTransaction, FactDailyAgg |
| V1.900.100 | `governance/` | Masking policies (NAME, EMAIL, PHONE, LOCATION, FINANCIAL_ID, AMOUNT) |
| V1.900.101 | `governance/` | DATA_QUALITY_LOG table |
| R__ | `clean/ecomm/` | SCD-2 (Customer), SCD-1 (Account), dimension loaders |
| R__ | `conformed/ecomm/` | Fact table loaders, aggregation procedures |
| R__ | `conformed/ecomm/` | MonthlySpendProfile, TxnTypeTrend views |
| R__ | `orchestration/` | Daily_ETL_Run() master orchestrator |
| R__ | `orchestration/` | TASK_LOAD_CUSTOMER, TASK_LOAD_ACCOUNT, TASK_LOAD_TRANSACTION |
| R__ | `artifacts/` | CSV_FORMAT, DATA_STAGE, STREAM_DATA_FILES |
| R__ | `artifacts/` | PARQUET_FORMAT, ICEBERG_STAGE |
| R__ | `governance/` | Masking policy definitions & column assignments |
| R__ | `governance/` | Cleanse_Raw_Data(), Run_Data_Quality_Checks() |

### Manual Scripts (not in pipeline)

These scripts are run manually before the first deploy or when permissions need updating:

| Script | Location | Purpose |
|--------|----------|---------|
| `V1.000.100__setup_schemas.sql` | `scripts/manual-scripts/_platform/` | Creates RAW, CLEAN, CONFORMED, GOVERNANCE, METADATA schemas |
| `A__grants.sql` | `scripts/manual-scripts/` | Applies grants and future privileges to roles |

```bash
# Run platform setup (one-time, before first deploy)
snow sql -c MY_TRIAL_ACCOUNT -f scripts/manual-scripts/_platform/V1.000.100__setup_schemas.sql

# Run grants (as needed after permission changes)
snow sql -c MY_TRIAL_ACCOUNT -f scripts/manual-scripts/A__grants.sql
```

### Change History Table

Schemachange tracks applied migrations in `<DATABASE>.METADATA.CHANGE_HISTORY`. This table is auto-created on first deploy (`--create-change-history-table`).

### Adding a New Migration

1. Create a new file in the appropriate `finance-data-platform/` subdirectory:
   ```
   finance-data-platform/clean/ecomm/V1.050.201__add_customer_segment.sql
   ```

2. Use Jinja variables for environment portability:
   ```sql
   USE DATABASE {{ database }};
   ALTER TABLE {{ clean_schema }}.DIMCUSTOMER ADD COLUMN SEGMENT VARCHAR(50);
   ```

3. Test locally with dry-run:
   ```bash
   bash scripts/deploy_schemachange.sh --env=dev --dry-run
   ```

4. Apply:
   ```bash
   bash scripts/deploy_schemachange.sh --env=dev
   ```

5. Commit and push — CI/CD handles stage/prod automatically.

### Configuration

- **Config file**: `schemachange-config.yml` (root-folder, default vars, change history table)
- **Deploy script**: `scripts/deploy_schemachange.sh` (environment-aware wrapper)
- **Dependencies**: `requirements.txt` (schemachange, pyyaml, jinja2)

### Jinja Variables Available in Migrations

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `{{ database }}` | Target database name | `FINANCE_CORE_DEV` |
| `{{ warehouse }}` | Compute warehouse | `COMPUTE_WH` |
| `{{ role }}` | Deployment role | `SYSADMIN` |
| `{{ environment }}` | Environment name | `dev` |
| `{{ raw_schema }}` | Raw schema name | `RAW` |
| `{{ clean_schema }}` | Clean schema name | `CLEAN` |
| `{{ conformed_schema }}` | Conformed schema name | `CONFORMED` |
| `{{ governance_schema }}` | Governance schema name | `GOVERNANCE` |

---

## Data Flow

```
Source Files (CSV/Parquet)
    │
    ▼
RAW (Raw Landing)
    │  T_Customer, T_Account, T_Transaction
    │  Loaded via: Stage → Stream → Tasks (CSV) or COPY INTO (Parquet)
    │
    ▼
CLEAN (Conformed Dimensions)
    │  DimCustomer (SCD-2), DimAccount (SCD-1)
    │  DimTransactionType, DimDate
    │
    ▼
CONFORMED (Business Facts)
       FactDailyTransaction, FactDailyAgg
       Views: MonthlySpendProfile, TxnTypeTrend
```

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Nonexistent warehouse` | Warehouse not created in target account | Set `SNOWFLAKE_WAREHOUSE` env var to an existing warehouse |
| `JWT token is invalid` | Public key not registered with user | Run `ALTER USER <user> SET RSA_PUBLIC_KEY='...'` in Snowflake |
| `404 Not Found: post <account>.snowflakecomputing.com` | Wrong account identifier format | Use full format: `ORGNAME-ACCOUNTNAME` (e.g., `KXAXARZ-GW22129`) |
| `Connection default is not configured` | Missing `-c` flag or connection not in toml | Ensure `~/.snowflake/connections.toml` has the connection section |
| `Schema does not exist` | Database not created yet | Run `deploy_schemachange.sh` for the target environment first |

---

## Adding a New Environment

1. Add entry to `environments.yml`:
   ```yaml
   newenv:
     database: FINANCE_CORE_NEWENV
     raw_schema: RAW
     clean_schema: CLEAN
     conformed_schema: CONFORMED
     governance_schema: GOVERNANCE
     warehouse: COMPUTE_WH
     connection: MY_TRIAL_ACCOUNT
   ```

2. Create the database in Snowflake:
   ```sql
   CREATE DATABASE IF NOT EXISTS FINANCE_CORE_NEWENV;
   ```

3. Deploy (schemachange will create the change history table and apply all migrations):
   ```bash
   bash scripts/deploy_schemachange.sh --env=newenv
   ```

---

## Key-Pair Authentication Setup

1. Generate RSA key pair:
   ```bash
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out ~/.snowflake/trial_key.p8 -nocrypt
   openssl rsa -in ~/.snowflake/trial_key.p8 -pubout -out ~/.snowflake/trial_key.pub
   chmod 600 ~/.snowflake/trial_key.p8
   ```

2. Register public key in Snowflake:
   ```sql
   ALTER USER SUJAYSOM SET RSA_PUBLIC_KEY='<paste public key without headers>';
   ```

3. Configure `~/.snowflake/connections.toml`:
   ```toml
   [MY_TRIAL_ACCOUNT]
   account = "KXAXARZ-GW22129"
   user = "SUJAYSOM"
   authenticator = "SNOWFLAKE_JWT"
   private_key_path = "/path/to/.snowflake/trial_key.p8"
   warehouse = "COMPUTE_WH"
   database = "FINANCE_CORE_DEV"
   ```
