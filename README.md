# Snowflake for SAP / BDC — Demo Accelerators

A collection of Snowflake demo environments built on SAP data structures (S/4HANA, ECC, BDC).
Each demo lives under a folder path that mirrors the Snowflake database/schema hierarchy.

## Available Demos

| Path | Database | Schema | Module | Description |
|------|----------|--------|--------|-------------|
| [`S4/FIN/PNL`](S4/FIN/PNL/README.md) | S4 | FIN | PNL | R.Daneel Inc. — Financial P&L with marginal contribution (DB1/DB2/EBIT) |
| [`CPG_S4_BLUEY_CONFECT_PETFOOD`](CPG_S4_BLUEY_CONFECT_PETFOOD/README.md) | CONFECT_PETFOOD_DEMO | SC_RISK_DEMO | Supply Chain Risk | Multi-division CPG supply chain risk intelligence (SAP + Blue Yonder + external signals) |

> More demos coming: `S4/FIN/AP`, `S4/FIN/AR`, `S4/SD/ORDER_TO_CASH`, `S4/MM/PROCUREMENT`

---

## Architecture

```
S3_FINANCE_PNL  (base fact table)
  │
  ├── CLIENT_ID + REGION
  │       └── Row Access Policy  ←  data isolation enforced at DB layer
  │
  └── S4_FIN_PNL_ANALYTICS_SV  (Semantic View — inherits RAP)
          ├── Metrics: GROSS_REVENUE → NET_REVENUE → GROSS_PROFIT
          │           → DB1 → DB2 → EBIT
          └── S4_FIN_PNL_AGENT  (Cortex Agent)
                  ├── SQL tool  →  Semantic View
                  └── Search    →  S4_FIN_PNL_SEARCH_SVC (press releases, product docs)
```

---

## Quick Start

### Option A — GitHub Actions (no CLI required)

1. Fork or get access to this repo
2. Go to **Settings → Secrets and variables → Actions** and add three secrets:

   | Secret | Value |
   |--------|-------|
   | `SNOWFLAKE_ACCOUNT` | Account identifier for the target Snowflake account (e.g. `orgname-accountname`) |
   | `SNOWFLAKE_USER` | Snowflake username of the service user running the deployment |
   | `SNOWFLAKE_PRIVATE_KEY` | Full contents of `demo_cicd.p8` including PEM headers — see setup guide below |

3. Go to **Actions → Deploy S4.FIN.PNL — R.Daneel P&L Demo → Run workflow**
4. Choose `all` for a fresh install, fill in warehouse/database, click **Run workflow**

### Option B — Local Snowflake CLI

```bash
git clone https://github.com/sfc-gh-drichert/SNOWFLAKE_4_SAP_BDC.git
cd SNOWFLAKE_4_SAP_BDC

# Configure your connection (copy and edit the example)
cp .snowflake/config.toml.example ~/.snowflake/config.toml

# Deploy the R.Daneel PnL demo
make install DEMO=S4/FIN/PNL CONNECTION=my_snowflake
```

---

## Setting Up GitHub Actions — Service User & Authentication

### Use a dedicated service user (not your personal account)

Never use your personal Snowflake user for CI/CD. A service user:
- Leaves a clean audit trail (`DEMO_GITHUB_ACTIONS` vs your name in query history)
- Can be revoked independently without affecting your own access
- Can be locked to key pair only — no password, no Okta/SSO

**Run [`setup_service_user.sql`](setup_service_user.sql) on your target account first.**
It creates the service user, the low-privilege deployment role, and the authentication policy.

### What role does the service user need?

| Action | Role used | When |
|--------|-----------|------|
| First-time full deploy (`action: all`) | `ACCOUNTADMIN` | Once — creates roles, grants, RAP, warehouse |
| Ongoing data runs (`action: data-only`) | `DEMO_DATA_DEPLOY_ROLE` | Repeatable — no elevated privileges |
| Verification (`action: verify`) | `DEMO_DATA_DEPLOY_ROLE` | Repeatable |

The service user's **default role** is `DEMO_DATA_DEPLOY_ROLE` (low privilege). The setup scripts
call `USE ROLE ACCOUNTADMIN` explicitly for the steps that need it. `ACCOUNTADMIN` is never
used automatically — only when a script asks for it.

Once the infrastructure is deployed for the first time, you can revoke `ACCOUNTADMIN` from the
service user entirely. The commented-out `REVOKE` command at the bottom of
[`setup_service_user.sql`](setup_service_user.sql) does this.

### Step 1 — Generate the key pair (your laptop terminal)

Do this first so you can paste the public key directly into `setup_service_user.sql` and run everything in one shot.

```bash
# Private key — PKCS8 format, no passphrase (required for unattended CI/CD)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out demo_cicd.p8 -nocrypt

# Public key derived from the private key
openssl rsa -in demo_cicd.p8 -pubout -out demo_cicd.pub
```

> Keep `demo_cicd.p8` private. Do not commit it to any repo.

Get the public key body — one long base64 string, no headers, no line breaks:

```bash
grep -v "BEGIN\|END" demo_cicd.pub | tr -d '\n'
# Copy this output — you will paste it into the setup script in the next step
```

### Step 2 — Edit and run setup_service_user.sql (Snowsight, as ACCOUNTADMIN)

Open `setup_service_user.sql` from the repo root. Find the key registration block near the bottom:

```sql
-- ALTER USER DEMO_GITHUB_ACTIONS
--     ADD KEY PAIR demo_github_actions
--     PUBLIC_KEY = '...';
```

Uncomment those three lines and replace `'...'` with the public key body you copied in Step 1:

```sql
ALTER USER DEMO_GITHUB_ACTIONS
    ADD KEY PAIR demo_github_actions
    PUBLIC_KEY = 'MIIBIjANBgkq...';   -- your key body here
```

Then open Snowsight on the target account, paste the full script into a SQL worksheet, and run it.
This creates the service user, role, authentication policy, and registers the key — all in one run.

Or from the command line:

```bash
snow sql -f setup_service_user.sql --connection my_snowflake
```

Verify the key registered:

```sql
SHOW USER KEY PAIRS FOR USER DEMO_GITHUB_ACTIONS;
-- Should show: demo_github_actions   ACTIVE
```

### Step 3 — Add secrets to GitHub (repo settings in your browser)

Go to **your repo → Settings → Secrets and variables → Actions → New repository secret**
and add these three secrets:

| Secret name | Where to get the value |
|---|---|
| `SNOWFLAKE_ACCOUNT` | Your Snowflake account identifier, e.g. `orgname-accountname` |
| `SNOWFLAKE_USER` | `DEMO_GITHUB_ACTIONS` |
| `SNOWFLAKE_PRIVATE_KEY` | Full contents of `demo_cicd.p8` — include the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |

```bash
# Copy the full private key to your clipboard
cat demo_cicd.p8 | pbcopy                        # macOS
cat demo_cicd.p8 | xclip -selection clipboard   # Linux
```

### Step 4 — Test the connection

Go to **Actions → Deploy S4.FIN.PNL — R.Daneel P&L Demo → Run workflow**, choose `verify`, and run.
If the connection step passes, the key pair is working and you are ready for a full deploy.

### Rotating the key later

```sql
-- Generate a new key pair (repeat Step 1 with a new filename), then in Snowsight:
ALTER USER DEMO_GITHUB_ACTIONS
    ROTATE KEY PAIR demo_github_actions
    PUBLIC_KEY = '<new_public_key_body>';
-- The old key stays valid for 24 hours — update the GitHub Secret before it expires
```

---

## Role Overview

| Role | Companies visible | Regions visible | Use case |
|------|-------------------|-----------------|----------|
| `ACCOUNTADMIN` / `SYSADMIN` | All | All | Admin / setup only |
| `S4_FIN_DEMO_GLOBAL_ROLE` | All | All | Multi-company exec demo |
| `S4_FIN_DEMO_ROLE` | R.Daneel | All | Full R.Daneel P&L story |
| `S4_FIN_EUROPE_DEMO_ROLE` | R.Daneel | DACH, W_EUROPE, E_EUROPE | European operations focus |
| `S4_FIN_NA_DEMO_ROLE` | R.Daneel | N_AMERICA | North America growth story |
| `S4_FIN_APAC_DEMO_ROLE` | R.Daneel | APAC, EMERGING | Asia-Pacific expansion |

Data isolation is enforced by a **Row Access Policy** on `(CLIENT_ID, REGION)` — not a WHERE clause in a report. A role that doesn't have access to a region physically cannot retrieve those rows, regardless of how the query is written.

---

## Adding a New Company

This explains what "adding a company" actually means, and what you have to do step by step.

### What is a "company" in this model?

Every row in `S3_FINANCE_PNL` has a `CLIENT_ID` column — for R.Daneel all rows have `CLIENT_ID = 'RDANEEL'`.
Adding a new company means loading rows with a different `CLIENT_ID` (e.g. `'HENKEL'`).
The table, semantic view, and isolation policy are all shared — no DDL changes are needed.

Note: `CLIENT_ID` is the **tenant** identifier. `COMPANYCODE` is something different — it is
R.Daneel's *internal* SAP org breakdown (1000 = R.Daneel Germany, 2000 = R.Daneel North America, etc.).
Do not confuse the two.

### What you have to do (example: adding Henkel)

**Step 1 — Create the role and register access (Snowsight, run as ACCOUNTADMIN)**

```bash
# From the repo root — this creates the role and registers it in ROLE_ACCESS_MAPPING
make add-company COMPANY=HENKEL CONNECTION=my_snowflake
```

Or trigger the GitHub Actions `deploy` workflow and choose `add-company` if you add that as a
workflow option, or just run the runbook directly:

```bash
snow sql -f S4/FIN/PNL/runbooks/add_company.sql \
  --connection my_snowflake \
  --variable db_name=S4 \
  --variable wh_name=S4_FIN_DEMO_WH \
  --variable company_id=HENKEL
```

This creates `HENKEL_DEMO_ROLE` and adds this row to `ROLE_ACCESS_MAPPING`:

| ROLE_NAME | ALLOWED_CLIENT | ALLOWED_REGION | Meaning |
|-----------|---------------|----------------|---------|
| HENKEL_DEMO_ROLE | HENKEL | NULL | Henkel role sees all Henkel regions |

**Step 2 — Load Henkel's data**

Insert rows into `S3_FINANCE_PNL` with `CLIENT_ID = 'HENKEL'`. The simplest approach is to
copy and adapt `05_data_seed.sql` — change the literal `'RDANEEL'` to `'HENKEL'` and adjust
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

-- As R.Daneel role: should NOT see HENKEL rows
USE ROLE S4_FIN_DEMO_ROLE;
SELECT DISTINCT CLIENT_ID FROM S4.FIN.S3_FINANCE_PNL;
-- Returns: R.Daneel only

-- As global role: sees both
USE ROLE S4_FIN_DEMO_GLOBAL_ROLE;
SELECT DISTINCT CLIENT_ID FROM S4.FIN.S3_FINANCE_PNL;
-- Returns: RDANEEL, HENKEL
```

**Step 4 — Create a Henkel Cortex Agent (optional)**

The existing `S4_FIN_PNL_AGENT` already works for Henkel data (the semantic view is shared),
but a company-specific agent lets you tailor the system prompt with Henkel context:

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE S4; USE SCHEMA FIN;

CREATE OR REPLACE CORTEX AGENT HENKEL_PNL_AGENT
    SEMANTIC_VIEWS  = (S4.FIN.S4_FIN_PNL_ANALYTICS_SV)
    SEARCH_SERVICES = (S4.FIN.S4_FIN_PNL_SEARCH_SVC)
    COMMENT = 'Henkel P&L analysis agent';

GRANT USAGE ON CORTEX AGENT HENKEL_PNL_AGENT TO ROLE HENKEL_DEMO_ROLE;
```

### What does NOT change when you add a company

| Object | Changes needed? |
|--------|-----------------|
| `S3_FINANCE_PNL` table DDL | No — same table, new rows |
| `PNL_CLIENT_ISOLATION_POLICY` RAP | No — reads `ROLE_ACCESS_MAPPING` dynamically |
| `S4_FIN_PNL_ANALYTICS_SV` semantic view | No — shared across all companies |
| `ROLE_ACCESS_MAPPING` | Yes — one INSERT row per new company |

See [`S4/FIN/PNL/runbooks/add_company.sql`](S4/FIN/PNL/runbooks/add_company.sql) for the
full runbook SQL.

---

## Mapping SAP BDC Data Products into the Gold Layer

`S4.FIN.S3_FINANCE_PNL_MDR` (the P&L gold table) references SAP master and
transactional data — customers, cost/profit centers, GL accounts, sales
orders, currency, etc. — that lives in SAP Business Data Cloud (BDC), not in
this repo. This section maps those SAP BDC data products into Snowflake as
catalog-linked databases (CLDs), and puts a stable view on top of each one so
gold-layer SQL never has to reference SAP-generated CLD internals directly.

See [`S4/FIN/PNL/runbooks/sap_bdc_lineage.md`](S4/FIN/PNL/runbooks/sap_bdc_lineage.md)
for the full lineage analysis (CDS view → BDC data product → gold layer,
including primary/foreign keys and a currency-handling risk analysis) that
this mapping was built from.

### Naming convention

| Layer | Object | Example |
|---|---|---|
| Raw / landing | CLD database | `zzbdcL0_CUSTOMER` |
| Clean | View | `S4.L1.CUSTOMER` |

`zz` sorts these CLDs to the bottom of any object listing; `bdc` marks the
source system; `L0` is the raw layer. `L1` is the schema every gold-layer
join should actually point at — it insulates you from SAP's internal CLD
table naming, which can vary between BDC releases.

### Prerequisite (not covered by this repo)

A **CONNECTED** zero-copy connector to SAP BDC must already exist in the
target Snowflake account. Setting one up is an account-level, one-time
action — see the `manage-zerocopy-sapbdc` Cortex Code skill, or
`SHOW ZEROCOPY CONNECTORS IN ACCOUNT;` to check if one already exists.

### Why this can't be a single script

SAP BDC share names and the table names inside a mounted CLD both include
SAP-generated, tenant-specific details that can't be predicted in advance
(e.g. `"Sales Order (BDF730, sap.s4pce:apiResource:SalesOrder:v1)"`). So the
process is deliberately split into discover → confirm → mount, with a human
reviewing the real names before anything gets created — no script silently
guesses and mounts.

### Step-by-step

1. **Catalog setup (once).** Creates the `L1` schema and the control tables
   (`BDC_PRODUCT_CATALOG`, `BDC_L1_VIEW_MAP`, `BDC_CLD_MOUNT_LOG`), seeded
   with the 14 SAP BDC data products this gold layer needs.

   ```bash
   make bdc-catalog CONNECTION=my_snowflake DATABASE=S4
   ```

2. **Share the data products from SAP BDC.** In the SAP BDC catalog, someone
   with the right roles (BDC Data Packages read, Catalog Asset read, Cloud
   Data Product share) must share each of the 14 products to this Snowflake
   account. This repo cannot trigger that step — it happens entirely on the
   SAP side.

3. **Discover (read-only, repeat as needed).** Lists what's actually been
   shared and suggests matches against the 14 products.

   ```bash
   make bdc-discover CONNECTOR=SAP_BDC_DB.SAP_SCHEMA.SAP_CONNECTOR
   ```

   Review the output — the "suggested" column is a heuristic, not a
   guarantee. Note the exact `share_name` for each product you're ready to
   mount.

4. **Confirm.** Record the exact share name for each product, one at a time
   (or via the GitHub Action's `confirm` action with a JSON blob covering
   all of them at once).

   ```bash
   make bdc-confirm PRODUCT_KEY=CUSTOMER SHARE_NAME="Customer (BDF730, sap.s4com:apiResource:Customer:v1)"
   ```

5. **Mount.** Creates the `zzbdcL0_*` CLDs for every confirmed product, then
   resolves each one's root entity table and creates the matching `S4.L1`
   view. Safe to re-run — already-mounted CLDs and views are skipped, not
   recreated.

   ```bash
   make bdc-mount CONNECTOR=SAP_BDC_DB.SAP_SCHEMA.SAP_CONNECTOR
   ```

6. **Verify (read-only).** Confirms every planned CLD/view resolved, that
   each view returns rows, and that the documented foreign keys actually
   join into `S3_FINANCE_PNL_MDR`.

   ```bash
   make bdc-verify
   ```

   Any `SKIPPED` or `FAILED` row in `BDC_CLD_MOUNT_LOG` means the mount
   script found zero or more than one candidate table inside a CLD and
   refused to guess — resolve those manually (see the comments in
   `13_bdc_mount_clds.sql` for how).

7. **Teardown**, if needed. Drops all mounted CLDs and `L1` views but keeps
   `CONFIRMED_SHARE_NAME`, so re-mounting later doesn't require re-confirming
   shares.

   ```bash
   make bdc-teardown
   ```

### Via GitHub Actions

Same steps, via **Actions → Deploy S4.FIN.PNL — SAP BDC CLD Mapping → Run
workflow**. Choose the `action` (`catalog-setup` / `discover` / `confirm` /
`mount` / `verify` / `teardown`) and fill in `connector_fqn`. For `confirm`,
paste a JSON object into `confirmed_shares_json`:

```json
{
  "CUSTOMER": "Customer (BDF730, sap.s4com:apiResource:Customer:v1)",
  "COST_CENTER": "Cost Center (BDF730, sap.s4com:apiResource:CostCenter:v1)"
}
```

### Known limitations

- None of this has been run end-to-end against a real BDC-connected
  Snowflake account — the SQL was syntax-validated (compile-only) against a
  live account, but the actual `CREATE DATABASE ... LINKED_ZEROCOPY_CONNECTOR`
  and root-entity table matching logic have not been exercised against real
  SAP BDC data. Treat the first real run as a test run and check
  `BDC_CLD_MOUNT_LOG` carefully.
- `GENERAL_LEDGER_ACCOUNT` and `SALES_ORGANIZATIONAL_STRUCTURE` each produce
  two `L1` views (their CLDs bundle multiple entities relevant to the gold
  layer) — everything else is 1:1.
- The `SALES_ORGANIZATION`/`DISTRIBUTION_CHANNEL` views are not directly
  joinable from the journal entry item — see the lineage doc for the
  two-hop path via `SALES_ORDER`.
- Currency handling (`HSL`/`CURRENCY`/`CURRENCYTYPE`) has open correctness
  questions independent of this mapping — read Section 5 of the lineage doc
  before writing any aggregate query against the mounted currency data.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for conventions on adding new demos.
