# R.Daneel Inc. — Financial P&L Demo

**Database:** `S4` | **Schema:** `FIN` | **Module:** `PNL`

A complete Snowflake demo environment built on R.Daneel Inc. financials, using an SAP ACDOCA/CO-PA data structure. Includes ~100,000 synthetic rows with real R.Daneel product names, a five-role RBAC hierarchy with row-level data isolation, and a Cortex Agent that can answer both structured P&L questions and qualitative market questions.

---

## What This Demo Shows

- **SAP ACDOCA structure**: the fact table mirrors real SAP CO-PA profitability analysis fields
- **Multi-level P&L (Deckungsbeitrag)**: full waterfall from Gross Revenue → DB1 → DB2 → EBIT
- **Real R.Daneel data**: Bosch, Siemens, Gaggenau, NEFF, Thermador — real model numbers, real price points
- **Data isolation via Row Access Policy**: European, North American, and APAC roles see only their data — enforced at the database layer, not in a WHERE clause
- **AI layer**: Cortex Agent combines structured SQL (via Semantic View) with document search (press releases, product briefs)

---

## Quick Setup

### GitHub Actions (no CLI needed)

1. Ensure the three [required secrets](../../README.md#setting-up-key-pair-authentication-for-github-actions) are configured in the repo
2. Go to **Actions → Deploy S4.FIN.PNL — R.Daneel P&L Demo → Run workflow**
3. Leave defaults (`all`, `S4`, `S4_FIN_DEMO_WH`) and click **Run workflow**

### Local CLI

```bash
# From repo root:
make install DEMO=S4/FIN/PNL CONNECTION=my_snowflake

# Or directly:
./install.sh my_snowflake S4 S4_FIN_DEMO_WH S4/FIN/PNL
```

---

## Objects Created

| Object | Type | Description |
|--------|------|-------------|
| `S4.FIN.S3_FINANCE_PNL` | Table | Main P&L fact table (~100K rows) with RAP |
| `S4.FIN.DIM_GL_ACCOUNT` | Table | 13 GL account / P&L line definitions |
| `S4.FIN.DIM_PRODUCT` | Table | 52 real R.Daneel SKUs with model numbers |
| `S4.FIN.DIM_CUSTOMER` | Table | 44 major retail customers |
| `S4.FIN.DIM_COMPANY` | Table | 6 R.Daneel SAP company codes |
| `S4.FIN.DIM_PLANT` | Table | 8 R.Daneel manufacturing plants |
| `S4.FIN.ROLE_ACCESS_MAPPING` | Table | Role → data access registry |
| `S4.FIN.S4_FIN_DOCUMENTS` | Table | ~20 document rows for Cortex Search |
| `S4.FIN.PNL_CLIENT_ISOLATION_POLICY` | Row Access Policy | Two-column isolation on (CLIENT_ID, REGION) |
| `S4.FIN.S4_FIN_PNL_SEARCH_SVC` | Cortex Search | Document corpus search |
| `S4.FIN.S4_FIN_PNL_ANALYTICS_SV` | Semantic View | P&L waterfall metrics (Gross Revenue → EBIT) |
| `S4.FIN.S4_FIN_PNL_AGENT` | Cortex Agent | SQL + Search tools, R.Daneel-specific system prompt |
| `S4_FIN_DEMO_GLOBAL_ROLE` | Role | All companies, all regions |
| `S4_FIN_DEMO_ROLE` | Role | All R.Daneel data, all regions |
| `S4_FIN_EUROPE_DEMO_ROLE` | Role | RDANEEL: DACH + W_EUROPE + E_EUROPE |
| `S4_FIN_NA_DEMO_ROLE` | Role | RDANEEL: N_AMERICA |
| `S4_FIN_APAC_DEMO_ROLE` | Role | RDANEEL: APAC + EMERGING |

---

## Demo Narrative

See **[DEMO_FLOW.md](DEMO_FLOW.md)** for the full demo script with talking points and sample agent questions.

---

## Adding a New Company

```bash
make add-company COMPANY=HENKEL CONNECTION=my_snowflake
```

Then load Henkel data rows with `CLIENT_ID = 'HENKEL'`. The Row Access Policy and Semantic View require no DDL changes. See [`runbooks/add_company.sql`](runbooks/add_company.sql) for full instructions.

---

## Verification

```bash
make verify CONNECTION=my_snowflake
```

Runs 11 automated checks including row count, EBIT margin sanity (expect ~6%), and RAP isolation tests per role.

---

## Teardown

```bash
make teardown CONNECTION=my_snowflake
```
