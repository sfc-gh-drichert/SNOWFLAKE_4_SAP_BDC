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

## Prerequisites

- Any Snowflake account (any edition, any cloud/region)
- `ACCOUNTADMIN` role
- ~5 minutes to run both files in sequence

## Deployment

### Option A — GitHub Actions (recommended)

1. Go to **Actions -> Deploy CPG SC Risk -> Run workflow**
2. Choose `all` and click **Run workflow**

Uses the same `SNOWFLAKE_ACCOUNT` / `SNOWFLAKE_USER` / `SNOWFLAKE_PRIVATE_KEY` secrets
as the other demos in this repo (see root README for setup).

### Option B — Manual

Run the files **in order** in a Snowflake worksheet or via SnowSQL:

```
1. 01_confect_petfood_demo_sc_risk_ice.sql   -- Database, warehouse, Iceberg tables, views
2. 02_confect_petfood_demo_yaml.sql          -- Semantic view + Cortex Agent
```

The scripts create a dedicated `CONFECT_PETFOOD_WH` (XS) warehouse automatically.

## Data Architecture

| Layer | Source System | What It Contains |
|-------|-------------|------------------|
| **1 — SAP BDC** | S/4HANA master data, BOMs, POs, stock | Zero-copy share via BDC — SAP CDS naming (I_SUPPLIER, I_PRODUCT, etc.) |
| **2 — SAP Transactional** | Purchase orders, stock snapshots | M_V_POH_AGGR, PPH_DDL_STOCK_1 |
| **3 — Blue Yonder** | Demand forecasts, loads, lanes, tenders | BY_DEMAND_FORECAST, BY_LOADS, BY_LANES, BY_TENDER_EVENTS |
| **4 — External Signals** | Commodity prices, news, ports, vessels, outbreaks | EXT_COMMODITY_PRICES, EXT_PORT_CONGESTION, EXT_VESSEL_TRACKER, etc. |
| **5 — Intelligence Views** | Composite risk scoring | V_BOM_RISK_EXPLOSION, V_SEASONAL_COVERAGE_GAP, V_SUPPLY_RISK_SCORE |
| **6 — Semantic View + Agent** | Cortex Analyst + Cortex Agent | Natural language access to the entire risk model |

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

```sql
DROP DATABASE IF EXISTS CONFECT_PETFOOD_DEMO;
DROP WAREHOUSE IF EXISTS CONFECT_PETFOOD_WH;
```

## Co-authored with CoCo
