# Confect PetFood — Supply Chain Risk Intelligence Demo

Snowflake as the intelligence layer between **SAP S/4HANA** (via BDC zero-copy shares),
**Blue Yonder IBP + TMS**, and **external market signals** — closing the planning-to-execution gap.

## Company Profile

Fictional CPG conglomerate "Confect PetFood" with ~$38 B annual revenue across 3 divisions:

| Division | Revenue | Brands |
|----------|---------|--------|
| Petcare | $20 B | NovaPet, TailWag, PurrFresh |
| Confectionery | $9 B | ChocoSnap, NutCrunch, WaferBliss, CocoBar, MaltBurst, StarChoc, Festival |
| Food | $5 B | GrainHarvest, SauceCraft |

Scale: 12 manufacturing plants across 4 continents (EU, NA, India, APAC), 28 strategic suppliers.

## Seasonal Peaks (4 peaks, 3 continents)

| Peak | Period | Region | Key SKUs |
|------|--------|--------|----------|
| **Diwali 2026** | Oct 5 - Nov 2 | India (IN01 Mumbai) | ChocoSnap, NutCrunch, CocoBar gift boxes |
| **Halloween 2026** | Oct 6 - Oct 27 | US + EU | ChocoSnap, NutCrunch, WaferBliss, MaltBurst party bags |
| **Christmas 2026** | Nov 9 - Dec 14 | Global (NL01, GB01) | Festival Tin, StarChoc Tin, ChocoSnap & NutCrunch gift boxes |
| **Chinese New Year 2027** | Jan 19 - Feb 8 | APAC (SG01 Singapore) | ChocoSnap, NutCrunch, Festival Lunar New Year editions |
| **Spring Puppy/Kitten 2027** | Feb - Apr | EU (FR01) | NovaPet puppy & kitten nutrition |

All four confectionery peaks draw from the **same West African cocoa supply base** — a single supplier disruption cascades across three continents.

## What Gets Deployed

| File | Creates |
|------|---------|
| `01_confect_petfood_demo_sc_risk_ice.sql` | Database `CONFECT_PETFOOD_DEMO`, schema `SC_RISK_DEMO`, warehouse `CONFECT_PETFOOD_WH` (XS), Iceberg tables, intelligence views |
| `02_confect_petfood_demo_yaml.sql` | Semantic view + Cortex Agent `CONFECT_PETFOOD_SC_RISK_AGENT` ("SC Risk Intelligence") |
| `03_confect_petfood_streamlit.sql` | Stage `STREAMLIT_STAGE`, EAI `CONFECT_PETFOOD_PYPI_EAI`, Streamlit app `SC_RISK_DASHBOARD` (container runtime), grants |
| `streamlit/streamlit_app.py`, `streamlit/pyproject.toml` | Dashboard source, uploaded to the stage by GitHub Actions |
| `static_site/build_data.py` | Generates `docs/confect-petfood/data.js` for the static preview |

## Prerequisites

- Any Snowflake account (any edition, any cloud/region) with Cortex Agents available
- `ACCOUNTADMIN` role (the EAI is an account-level object)
- ~5 minutes for a full deploy

## Deployment

### Option A — GitHub Actions (recommended)

1. Go to **Actions -> Deploy CPG SC Risk -> Run workflow**
2. Choose an action and click **Run workflow**

| Action | Runs | Use when |
|--------|------|----------|
| `ping` | Connection test only | Checking secrets / key-pair auth |
| `all` | 01 + 02 + 03 | First deploy, or after data/view changes |
| `tables-only` | 01 | Rebuild data and views |
| `agent-only` | 02 | Change the semantic view or agent |
| `dashboard-only` | 03 + stage upload | Change only `streamlit_app.py` (requires 01 and 02 already deployed) |
| `teardown` | Drops database, warehouse and EAI | Cleanup |

Uses the same `SNOWFLAKE_ACCOUNT` / `SNOWFLAKE_USER` / `SNOWFLAKE_PRIVATE_KEY` secrets
as the other demos in this repo (see root README for setup).

### Option B — Manual

Run the files **in order** in a Snowflake worksheet or via Snowflake CLI:

```
1. 01_confect_petfood_demo_sc_risk_ice.sql   -- Database, warehouse, Iceberg tables, views
2. 02_confect_petfood_demo_yaml.sql          -- Semantic view + Cortex Agent
3. CREATE STAGE IF NOT EXISTS CONFECT_PETFOOD_DEMO.SC_RISK_DEMO.STREAMLIT_STAGE DIRECTORY = (ENABLE = TRUE);
   PUT streamlit/streamlit_app.py and streamlit/pyproject.toml
     to @CONFECT_PETFOOD_DEMO.SC_RISK_DEMO.STREAMLIT_STAGE (AUTO_COMPRESS=FALSE OVERWRITE=TRUE)
4. 03_confect_petfood_streamlit.sql          -- Streamlit app, EAI, grants
```

## Viewing the Dashboard

- **Live app:** Snowsight -> **Projects -> Streamlit -> SC_RISK_DASHBOARD**
  (database `CONFECT_PETFOOD_DEMO`, schema `SC_RISK_DEMO`). The first start takes a minute or two
  while the container runtime installs packages.
- **Agent in Snowflake CoWork:** open Snowflake CoWork (`https://ai.snowflake.com`) and pick **SC Risk Intelligence**.
- **Static preview (no Snowflake needed):** `docs/confect-petfood/` is a click-through copy with data generated
  from the SQL. Serve it locally with `python3 -m http.server -d docs 8765` and open
  `http://127.0.0.1:8765/confect-petfood/`. It can't call the agent, and Plan Override changes are simulated
  in the browser only. GitHub Pages is not enabled because the repo is private.
  Regenerate data after SQL changes with `python3 CPG_S4_BLUEY_CONFECT_PETFOOD/static_site/build_data.py`.

## Dashboard — Supply Risk Command Center

| Page | Shows |
|------|-------|
| **Overview** | Headline KPIs, the three source systems, risk tier mix |
| **SAP BDC Zero Copy** | SAP master data, BOMs, POs and stock read in place from BDC shares |
| **Blue Yonder Planning** | Demand forecast vs. committed plan by peak event, coverage gaps, **Plan Override** |
| **External Signals** | Commodity prices, port congestion, vessels, outbreaks, news |
| **Risk Command Center** | Composite risk leaderboard and per-material drill-down |

**Plan Override (write-back).** On Blue Yonder Planning, choose a material, enter a new committed quantity and a
reason. The app shows the before/after coverage gap and writes it back to Snowflake (`MERGE` into `BY_PLAN_OVERRIDES`).

**Ask Cowork — SC Risk Intelligence.** There's a chat panel at the bottom of every page, backed by the
`CONFECT_PETFOOD_SC_RISK_AGENT` agent (called with `SNOWFLAKE.CORTEX.DATA_AGENT_RUN`).
- **Page-aware:** each question carries what's on screen: the current page, the peak-event filter, the
  Plan Override material, and the drill-down material. So "explain the risk drivers for the selected material" works.
- **Answers:** text, tables, charts, and the SQL the agent used.
- **Suggested questions:** two one-click questions per page.
- **Conversation:** it continues across pages. **New chat** resets it.
- **Open in Snowflake CoWork:** the sidebar button opens the full CoWork experience.

**Permissions.** Agent calls use the calling user's **default role** and **default warehouse**. That role needs:
- the `SNOWFLAKE.CORTEX_USER` (or `CORTEX_AGENT_USER`) database role;
- USAGE on the agent. File 03 grants this to `PUBLIC`.

The agent's Analyst tool runs SQL on `CONFECT_PETFOOD_WH`, which is pinned in `tool_resources` and granted to `PUBLIC` in file 02. So callers don't need a default warehouse. If the panel shows "Agent call failed", check these first.

## Risk Logic (Intelligence Views)

- **`V_SEASONAL_COVERAGE_GAP`:** one row per material × peak event, with stock joined on material **and** plant.
  The S&OP commitment is pro-rated to the peak weeks (`committed × peak_weeks / horizon_weeks`). The gap is peak
  forecast minus the pro-rated commitment and stock, floored at 0.
- **`V_SUPPLY_RISK_SCORE`:** composite score and tier (HIGH / MODERATE / LOW) per material × plant. For a SKU
  made in several plants, shortfall and revenue at risk are split evenly across those plants so totals aren't
  double-counted. Expected totals from the generated data: 35 rows, HIGH 18 / MODERATE 10 / LOW 7, ≈ $0.89 M
  revenue at risk.

## Demo Storyline (4 Acts)

### Act 1 — The Familiar Peak (Christmas 2026)

> "Which confectionery SKUs have a supply coverage gap for Christmas?"

The biggest seasonal peak — Festival Tins, StarChoc, ChocoSnap gift boxes. Reveals significant revenue at risk from cocoa shortfall as demand ramps for the holiday season.

### Act 2 — The Root Cause (Logistics Deep-Dive)

> "Why is the carrier acceptance rate so low on the Abidjan-Rotterdam lane?"

Connects: Atlantic Origins force majeure -> port congestion -> vessel delays -> blocked POs. The cocoa supply chain is under stress.

### Act 3 — The Hidden Risk (Petcare / Biosecurity)

> "Are there any supply risks in European petcare this quarter?"

H5N1 outbreak blocking 2/3 protein suppliers — invisible in SAP/BY alone. Only Bretagne Agri (LIFNR-FR-003) operational.

### Act 4 — The Global Cascade (Diwali + CNY)

> "Compare revenue at risk across all seasonal peaks"

The cocoa supply crunch doesn't just hit Christmas — it cascades across **Diwali** (India, Oct-Nov), **Halloween** (US/EU, Oct), and **Chinese New Year** (APAC, Jan-Feb). Same suppliers, same raw materials, global demand. The coverage gaps in Mumbai and Singapore are even worse than Europe because those plants have less safety stock.

### Close — Full Panorama

> "Give me a full supply chain risk overview across all divisions and peaks"

Composite risk score across everything — the view no single system can provide.

## Risk Scenarios in the Data

1. **H5N1 Avian Flu** — 2 of 3 NovaPet poultry protein suppliers blocked by movement restrictions in Pays de la Loire. Only Bretagne Agri (LIFNR-FR-003) operational.
2. **Cocoa Supply Crunch (Global)** — LIFNR-CI-003 (Atlantic Origins) is sole-source with contract expiring Oct 2026 + Ivory Coast drought + force majeure. Demand from Christmas, Diwali, Halloween, and CNY all competing for the same constrained supply.
3. **Port/Logistics Disruption** — Rotterdam congested, cocoa vessels delayed on Abidjan-Rotterdam lane. Carrier acceptance rate below 50%.
4. **New Market Coverage Risk** — India (IN01) and Singapore (SG01) plants have low initial stock and LOW confidence consensus plans, creating visible coverage gaps for Diwali and CNY.
5. **Credit Risk** — Suppliers with B/B- ratings flagged in BOM risk explosion.

## Cleanup

Run the `teardown` workflow action, or:

```sql
DROP DATABASE IF EXISTS CONFECT_PETFOOD_DEMO;   -- tables, views, agent, Streamlit app, stage
DROP WAREHOUSE IF EXISTS CONFECT_PETFOOD_WH;
DROP INTEGRATION IF EXISTS CONFECT_PETFOOD_PYPI_EAI;
```

## Repository Layout

```
CPG_S4_BLUEY_CONFECT_PETFOOD/
  01_..._sc_risk_ice.sql      data + views
  02_..._yaml.sql             semantic view + agent
  03_..._streamlit.sql        dashboard object + grants
  streamlit/                  streamlit_app.py, pyproject.toml
  static_site/build_data.py   static preview data generator
docs/confect-petfood/         static click-through preview
.github/workflows/deploy-cpg-sc-risk.yml
```

## Co-authored with CoCo
