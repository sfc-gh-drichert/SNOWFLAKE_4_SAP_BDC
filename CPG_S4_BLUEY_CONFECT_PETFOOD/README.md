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

Scale: 8 manufacturing plants, 28 strategic suppliers, Europe + US.

## Prerequisites

- Any Snowflake account (any edition, any cloud/region)
- `ACCOUNTADMIN` role
- ~5 minutes to run both files in sequence

## Deployment

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

## Demo Storyline (3 Acts)

### Act 1 — The Gap (Confectionery / Halloween)

> "Which confectionery SKUs have a supply coverage gap for Halloween?"

Reveals $30 M+ revenue at risk from cocoa supply shortfall.

### Act 2 — The Root Cause (Logistics Deep-Dive)

> "Why is the carrier acceptance rate so low on the Abidjan-Rotterdam lane?"

Connects: force majeure -> port congestion -> vessel delays -> blocked POs.

### Act 3 — The Hidden Risk (Petcare / Biosecurity)

> "Are there any supply risks in European petcare this quarter?"

H5N1 outbreak blocking 2/3 protein suppliers — invisible in SAP/BY alone.

### Close — Full Panorama

> "Give me a full supply chain risk overview across all divisions and peaks"

Composite risk score across everything — the view no single system can provide.

## Risk Scenarios in the Data

1. **H5N1 Avian Flu** — 2 of 3 NovaPet poultry protein suppliers blocked by movement restrictions in Pays de la Loire. Only Bretagne Agri (LIFNR-FR-003) operational.
2. **Cocoa Supply Crunch** — LIFNR-CI-003 (Atlantic Origins) is sole-source with contract expiring Oct 2026 + Ivory Coast drought + force majeure. Halloween peak demand coincides.
3. **Port/Logistics Disruption** — Rotterdam congested, cocoa vessels delayed on Abidjan-Rotterdam lane. Carrier acceptance rate below 50%.
4. **Credit Risk** — Suppliers with B/B- ratings flagged in BOM risk explosion.

## Cleanup

```sql
DROP DATABASE IF EXISTS CONFECT_PETFOOD_DEMO;
DROP WAREHOUSE IF EXISTS CONFECT_PETFOOD_WH;
```

## Co-authored with CoCo
