# Contributing a New Demo

This repo organises demos so that the **folder path mirrors the Snowflake object path**:

```
<DATABASE>/<SCHEMA>/<MODULE>/
```

Examples:
- `S4/FIN/PNL/`   → database `S4`, schema `FIN`, module `PNL`
- `S4/FIN/AP/`    → database `S4`, schema `FIN`, module `AP` (Accounts Payable)
- `S4/SD/OTC/`    → database `S4`, schema `SD`, module `OTC` (Order-to-Cash)

---

## Directory Structure for a New Demo

```
<DB>/<SCHEMA>/<MODULE>/
├── README.md          # One-page overview: what the demo shows, prerequisites, how to run
├── DEMO_FLOW.md       # Full demo narrative with talking points and sample agent questions
├── setup/
│   ├── 01_setup.sql           # Warehouse, database, schema
│   ├── 02_dimensions.sql      # Dimension/reference tables
│   ├── 03_rbac.sql            # Roles, Row Access Policy, grants
│   ├── 04_fact_table.sql      # Main fact/event table DDL
│   ├── 05_data_seed.sql       # Synthetic data generation
│   ├── 06_search.sql          # Cortex Search service (if applicable)
│   ├── 07_semantic_view.sql   # Semantic View DDL
│   ├── 08_agent.sql           # Cortex Agent DDL
│   └── 09_verify.sql          # Sanity checks + RAP isolation tests
└── runbooks/
    ├── add_company.sql        # Steps to onboard a new tenant/company
    └── teardown.sql           # Drop all demo objects (non-destructive guard)
```

---

## SQL File Conventions

### Variable substitution

Every SQL file must accept `db_name` and `wh_name` variables and open with:

```sql
USE ROLE ACCOUNTADMIN;
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER('&{wh_name}')
  WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;
USE WAREHOUSE IDENTIFIER('&{wh_name}');
CREATE DATABASE IF NOT EXISTS IDENTIFIER('&{db_name}');
USE DATABASE IDENTIFIER('&{db_name}');
CREATE SCHEMA IF NOT EXISTS <SCHEMA>;
USE SCHEMA <SCHEMA>;
```

This lets the install tooling (`install.sh`, `Makefile`, GitHub Actions) pass any target database or warehouse without editing the SQL.

### Idempotency

Use `CREATE OR REPLACE` and `CREATE IF NOT EXISTS` throughout so the scripts can be re-run safely.

### Comments

Every table column should have a `COMMENT` annotation. Every significant SQL block should have a section header comment explaining *why*, not just *what*.

---

## GitHub Actions Workflow

Add a new workflow file at `.github/workflows/deploy-<db>-<schema>-<module>.yml` following the pattern in [`deploy-s4-fin-pnl.yml`](.github/workflows/deploy-s4-fin-pnl.yml). Update the `BASE` variable to point to your demo's `setup/` folder.

---

## Update the Root README

Add a row to the **Available Demos** table in [`README.md`](README.md).
