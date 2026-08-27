# Finance Data Platform

Snowflake data platform with RAW/CLEAN/CONFORMED layered architecture, managed by **schemachange** with CI/CD via GitHub Actions.

## Project Structure

```
.
├── .github/
│   ├── ENVIRONMENTS.md
│   └── workflows/
│       ├── branch-guard.yml
│       ├── ci.yml
│       ├── deploy-dev.yml
│       ├── deploy-prod.yml
│       └── deploy-stage.yml
├── finance-data-platform/          # schemachange root folder (automated pipeline)
│   ├── artifacts/                  # Stages, file formats, seed data
│   │   ├── R__iceberg_objects.sql
│   │   └── R__seed_data.sql
│   ├── raw/                        # RAW layer
│   │   └── ecomm/
│   │       └── V1.050.100__create_raw_tables.sql
│   ├── clean/                      # CLEAN layer
│   │   └── ecomm/
│   │       ├── V1.050.200__create_clean_tables.sql
│   │       └── R__ecomm_clean_procedures.sql
│   ├── conformed/                  # CONFORMED layer
│   │   └── ecomm/
│   │       ├── V1.050.300__create_conformed_tables.sql
│   │       ├── R__ecomm_procedures.sql
│   │       └── R__ecomm_views.sql
│   ├── orchestration/              # Tasks and scheduling
│   │   ├── R__ingestion_tasks.sql
│   │   └── R__orchestration.sql
│   └── governance/                 # Masking, DQ
│       ├── V1.900.100__create_masking_policies.sql
│       ├── V1.900.101__create_data_quality.sql
│       ├── R__masking_policies.sql
│       └── R__data_quality_procedures.sql
├── manual-scripts/                 # Run manually (not in pipeline)
│   ├── _platform/
│   │   └── V1.000.100__setup_schemas.sql
│   └── A__grants.sql
├── scripts/
│   ├── deploy_schemachange.sh
│   ├── rollback.sh
│   └── run_smoke_tests.sh
├── tests/
│   └── integration_test.sql
├── .gitignore
├── .sqlfluff
├── environments.yml
├── schemachange-config.yml
├── DEVOPS_MANUAL.md
├── OPERATIONS.md
├── ROLLOUT_GUIDE.md
└── VERSIONING_STRATEGY.md
```

## Quick Start

```bash
# Deploy to dev
bash scripts/deploy_schemachange.sh --env=dev

# Run smoke tests
bash scripts/run_smoke_tests.sh --env=dev

# Lint SQL
sqlfluff lint finance-data-platform/ --config .sqlfluff
```

## Environments

| Environment | Database | Trigger |
|---|---|---|
| dev | FINANCE_CORE_DEV_POC | Push to `develop` |
| stage | FINANCE_CORE_STAGE | Push to `release/*` |
| prod | FINANCE_CORE_PROD | Tag `v*` |

## Documentation

- [OPERATIONS.md](OPERATIONS.md) — Day-to-day operations, deployment, testing
- [DEVOPS_MANUAL.md](DEVOPS_MANUAL.md) — Full setup and configuration guide
- [ROLLOUT_GUIDE.md](ROLLOUT_GUIDE.md) — Step-by-step rollout procedures
- [VERSIONING_STRATEGY.md](VERSIONING_STRATEGY.md) — Migration naming conventions
- [.github/ENVIRONMENTS.md](.github/ENVIRONMENTS.md) — GitHub environment setup
