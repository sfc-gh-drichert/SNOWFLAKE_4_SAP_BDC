# Snowflake for SAP / BDC — Demo Accelerators

A collection of Snowflake demo environments built on SAP data structures (S/4HANA, ECC, BDC).
Each demo lives under a folder path that mirrors the Snowflake database/schema hierarchy.

## Available Demos

| Path | Database | Schema | Module | Description |
|------|----------|--------|--------|-------------|
| [`S4/FIN/PNL`](S4/FIN/PNL/README.md) | S4 | FIN | PNL | BSH Group — Financial P&L with marginal contribution (DB1/DB2/EBIT) |

> More demos coming: `S4/FIN/AP`, `S4/FIN/AR`, `S4/SD/ORDER_TO_CASH`, `S4/MM/PROCUREMENT`

---

## Architecture

```
S3_FINANCE_PNL  (base fact table)
  │
  ├── CLIENT_ID + REGION
  │       └── Row Access Policy  ←  data isolation enforced at DB layer
  │
  └── BSH_PNL_ANALYTICS_SV  (Semantic View — inherits RAP)
          ├── Metrics: GROSS_REVENUE → NET_REVENUE → GROSS_PROFIT
          │           → DB1 → DB2 → EBIT
          └── BSH_PNL_AGENT  (Cortex Agent)
                  ├── SQL tool  →  Semantic View
                  └── Search    →  BSH_PNL_SEARCH_SVC (press releases, product docs)
```

---

## Quick Start

### Option A — GitHub Actions (no CLI required)

1. Fork or get access to this repo
2. Go to **Settings → Secrets and variables → Actions** and add three secrets:

   | Secret | Value |
   |--------|-------|
   | `SNOWFLAKE_ACCOUNT` | Your account identifier (e.g. `abc12345.eu-west-1`) |
   | `SNOWFLAKE_USER` | Snowflake user with ACCOUNTADMIN privileges |
   | `SNOWFLAKE_PRIVATE_KEY` | RSA private key — PEM format, no passphrase (see below) |

3. Go to **Actions → Deploy S4.FIN.PNL — BSH P&L Demo → Run workflow**
4. Choose `all` for a fresh install, fill in warehouse/database, click **Run workflow**

### Option B — Local Snowflake CLI

```bash
git clone https://github.com/sfc-gh-drichert/SNOWFLAKE_4_SAP_BDC.git
cd SNOWFLAKE_4_SAP_BDC

# Configure your connection (copy and edit the example)
cp .snowflake/config.toml.example ~/.snowflake/config.toml

# Deploy the BSH PnL demo
make install DEMO=S4/FIN/PNL CONNECTION=EU_DEMO47
```

---

## Setting Up Key Pair Authentication (for GitHub Actions)

```bash
# Generate private key (no passphrase)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt

# Derive public key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# Register public key in Snowflake (run as ACCOUNTADMIN)
# ALTER USER <your_user> SET RSA_PUBLIC_KEY='<paste contents of rsa_key.pub, header/footer excluded>';

# Copy the private key into GitHub Secret SNOWFLAKE_PRIVATE_KEY
cat rsa_key.p8
```

---

## Role Overview

| Role | Companies visible | Regions visible | Use case |
|------|-------------------|-----------------|----------|
| `ACCOUNTADMIN` / `SYSADMIN` | All | All | Admin / setup only |
| `BSH_DEMO_GLOBAL_ROLE` | All | All | Multi-company exec demo |
| `BSH_DEMO_ROLE` | BSH | All | Full BSH P&L story |
| `BSH_EUROPE_DEMO_ROLE` | BSH | DACH, W_EUROPE, E_EUROPE | European operations focus |
| `BSH_NA_DEMO_ROLE` | BSH | N_AMERICA | North America growth story |
| `BSH_APAC_DEMO_ROLE` | BSH | APAC, EMERGING | Asia-Pacific expansion |

Data isolation is enforced by a **Row Access Policy** on `(CLIENT_ID, REGION)` — not a WHERE clause in a report. A role that doesn't have access to a region physically cannot retrieve those rows, regardless of how the query is written.

---

## Adding a New Company

See [`S4/FIN/PNL/runbooks/add_company.sql`](S4/FIN/PNL/runbooks/add_company.sql) — zero DDL changes to the fact table, semantic view, or RAP policy are required.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for conventions on adding new demos.
