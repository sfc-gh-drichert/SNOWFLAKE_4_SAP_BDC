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
   | `SNOWFLAKE_ACCOUNT` | Account identifier for the target Snowflake account (e.g. `SFSEEUROPE-EU_DEMO47`) |
   | `SNOWFLAKE_USER` | Snowflake username of the service user running the deployment |
   | `SNOWFLAKE_PRIVATE_KEY` | Full contents of `bsh_demo_cicd.p8` including PEM headers — see setup guide below |

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

Key pair auth is **Snowflake-native** — it does not involve Okta, SSO, or any browser login.
You generate the keys on your laptop, register the public half in Snowflake, and store the private
half as a GitHub Secret. GitHub Actions then uses it to authenticate as the service user.

### Step 1 — Generate the key pair (your laptop terminal)

Run these two commands in a terminal. They create a private key file (`bsh_demo_cicd.p8`) and
a matching public key file (`bsh_demo_cicd.pub`) in your current directory.

```bash
# Private key — PKCS8 format, no passphrase (required for unattended CI/CD)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out bsh_demo_cicd.p8 -nocrypt

# Public key derived from the private key
openssl rsa -in bsh_demo_cicd.p8 -pubout -out bsh_demo_cicd.pub
```

> Keep `bsh_demo_cicd.p8` private. Do not commit it to any repo.

### Step 2 — Register the public key in Snowflake (Snowsight or SnowSQL)

Open Snowsight on the **target account** (e.g. EU_DEMO47) and run as `ACCOUNTADMIN`:

```sql
-- Use the named key pair approach (recommended — supports rotation and expiry)
-- Paste only the base64 body of bsh_demo_cicd.pub — omit the -----BEGIN/END----- lines

ALTER USER <your_service_user>
  ADD KEY PAIR bsh_demo_github_actions
  PUBLIC_KEY = 'MIIBIjANBgkq...';   -- paste the body of bsh_demo_cicd.pub here
```

To get just the body without headers (copy the output of this command):

```bash
grep -v "BEGIN\|END" bsh_demo_cicd.pub | tr -d '\n'
```

Verify it registered correctly:

```sql
SHOW USER KEY PAIRS FOR USER <your_service_user>;
-- Should list: bsh_demo_github_actions  ACTIVE
```

### Step 3 — Add secrets to GitHub (repo settings in your browser)

Go to **your repo → Settings → Secrets and variables → Actions → New repository secret**
and add these three secrets:

| Secret name | Where to get the value |
|---|---|
| `SNOWFLAKE_ACCOUNT` | The account identifier for EU_DEMO47, e.g. `SFSEEUROPE-EU_DEMO47` |
| `SNOWFLAKE_USER` | The Snowflake username you ran `ALTER USER` on above |
| `SNOWFLAKE_PRIVATE_KEY` | The **full contents** of `bsh_demo_cicd.p8` — copy everything including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |

```bash
# On your laptop — copy the full private key to your clipboard (macOS)
cat bsh_demo_cicd.p8 | pbcopy

# Linux equivalent
cat bsh_demo_cicd.p8 | xclip -selection clipboard
```

### Step 4 — Test it

Go to **Actions → Deploy S4.FIN.PNL — BSH P&L Demo → Run workflow**, choose `verify`, and run.
If the connection step passes, your key pair is working.

### Rotating the key later

```sql
-- Generate a new key pair (Step 1 again with a new filename), then:
ALTER USER <your_service_user>
  ROTATE KEY PAIR bsh_demo_github_actions
  PUBLIC_KEY = '<new_public_key_body>';
-- The old key stays valid for 24 hours — update the GitHub Secret before it expires
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

This explains what "adding a company" actually means, and what you have to do step by step.

### What is a "company" in this model?

Every row in `S3_FINANCE_PNL` has a `CLIENT_ID` column — for BSH all rows have `CLIENT_ID = 'BSH'`.
Adding a new company means loading rows with a different `CLIENT_ID` (e.g. `'HENKEL'`).
The table, semantic view, and isolation policy are all shared — no DDL changes are needed.

Note: `CLIENT_ID` is the **tenant** identifier. `COMPANYCODE` is something different — it is
BSH's *internal* SAP org breakdown (1000 = BSH Germany, 2000 = BSH North America, etc.).
Do not confuse the two.

### What you have to do (example: adding Henkel)

**Step 1 — Create the role and register access (Snowsight, run as ACCOUNTADMIN)**

```bash
# From the repo root — this creates the role and registers it in ROLE_ACCESS_MAPPING
make add-company COMPANY=HENKEL CONNECTION=EU_DEMO47
```

Or trigger the GitHub Actions `deploy` workflow and choose `add-company` if you add that as a
workflow option, or just run the runbook directly:

```bash
snow sql -f S4/FIN/PNL/runbooks/add_company.sql \
  --connection EU_DEMO47 \
  --variable db_name=S4 \
  --variable wh_name=BSH_DEMO_WH \
  --variable company_id=HENKEL
```

This creates `HENKEL_DEMO_ROLE` and adds this row to `ROLE_ACCESS_MAPPING`:

| ROLE_NAME | ALLOWED_CLIENT | ALLOWED_REGION | Meaning |
|-----------|---------------|----------------|---------|
| HENKEL_DEMO_ROLE | HENKEL | NULL | Henkel role sees all Henkel regions |

**Step 2 — Load Henkel's data**

Insert rows into `S3_FINANCE_PNL` with `CLIENT_ID = 'HENKEL'`. The simplest approach is to
copy and adapt `05_data_seed.sql` — change the literal `'BSH'` to `'HENKEL'` and adjust
product names, brands, and amounts to match the new company's profile.

```sql
-- Minimum viable test — confirm isolation works before loading full data
INSERT INTO S4.FIN.S3_FINANCE_PNL (CLIENT_ID, REGION, BRAND, CATEGORY, PNL_CATEGORY, HSL,
    FISCALYEAR, POSTINGPERIOD, POSTINGDATE, CURRENCY, ACDOCA_RACCT, COMPANYCODE,
    SALESORDER, VERSION, RECORDTYPE, LASTUPDATE_TS_REPORTING, CFIN_TS_DELTA)
VALUES ('HENKEL', 'DACH', 'HENKEL_CONSUMER', 'CONSUMER_GOODS', 'REVENUE',
        1500000, 2024, 3, '2024-03-31', 'EUR', '0800000', '1000',
        'SO-TEST-001', '000', '00', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());
```

**Step 3 — Test isolation**

```sql
-- As Henkel role: should see only HENKEL rows
USE ROLE HENKEL_DEMO_ROLE;
SELECT DISTINCT CLIENT_ID FROM S4.FIN.S3_FINANCE_PNL;
-- Returns: HENKEL

-- As BSH role: should NOT see HENKEL rows
USE ROLE BSH_DEMO_ROLE;
SELECT DISTINCT CLIENT_ID FROM S4.FIN.S3_FINANCE_PNL;
-- Returns: BSH only

-- As global role: sees both
USE ROLE BSH_DEMO_GLOBAL_ROLE;
SELECT DISTINCT CLIENT_ID FROM S4.FIN.S3_FINANCE_PNL;
-- Returns: BSH, HENKEL
```

**Step 4 — Create a Henkel Cortex Agent (optional)**

The existing `BSH_PNL_AGENT` already works for Henkel data (the semantic view is shared),
but a company-specific agent lets you tailor the system prompt with Henkel context:

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE S4; USE SCHEMA FIN;

CREATE OR REPLACE CORTEX AGENT HENKEL_PNL_AGENT
    SEMANTIC_VIEWS  = (S4.FIN.BSH_PNL_ANALYTICS_SV)
    SEARCH_SERVICES = (S4.FIN.BSH_PNL_SEARCH_SVC)
    COMMENT = 'Henkel P&L analysis agent';

GRANT USAGE ON CORTEX AGENT HENKEL_PNL_AGENT TO ROLE HENKEL_DEMO_ROLE;
```

### What does NOT change when you add a company

| Object | Changes needed? |
|--------|-----------------|
| `S3_FINANCE_PNL` table DDL | No — same table, new rows |
| `PNL_CLIENT_ISOLATION_POLICY` RAP | No — reads `ROLE_ACCESS_MAPPING` dynamically |
| `BSH_PNL_ANALYTICS_SV` semantic view | No — shared across all companies |
| `ROLE_ACCESS_MAPPING` | Yes — one INSERT row per new company |

See [`S4/FIN/PNL/runbooks/add_company.sql`](S4/FIN/PNL/runbooks/add_company.sql) for the
full runbook SQL.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for conventions on adding new demos.
