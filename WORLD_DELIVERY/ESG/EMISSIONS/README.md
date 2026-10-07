# World Delivery ESG Demo

Snowflake as the ESG intelligence layer for a global logistics company — connecting SAP BDC data products, SuccessFactors workforce metrics, and Snowflake Marketplace enrichment to close the granularity gap between aggregated management reporting and record-level sustainability analytics.

## What this demo shows

| Layer | Source | What it proves |
|-------|--------|----------------|
| SAP BDC managed data products | CompanyCode, CostCenter, Plant, ACDOCA GL entries | Zero-copy BDC Connect for Snowflake — no ETL, SAP CDS entity naming |
| Custom CDS views | Shipment emissions, fleet, facility energy, GoGreen Plus | The granularity gap: per-shipment CO2e that TM1/BW can't provide |
| SuccessFactors | Workforce engagement, women in management, LTIFR | Social ESG dimension from BDC |
| Marketplace enrichment | GLEC emission factors, ESG Book scores, climate risk | External context SAP systems don't have |
| Analytics views | GHG summary, ESRS E1, SBTi tracking, GoGreen revenue, KPIs | Cross-system intelligence layer |
| Semantic View + Agent | Natural language ESG analytics | "Generate the ESRS E1-6 table" in 3 seconds |
| Streamlit Dashboard | 6-page CxO ESG dashboard | Executive-grade visualization |

## Company profile

**World Delivery** — a fictional global logistics group modeled on real-world sustainability data:
- ~580,000 employees across Express, Supply Chain, eCommerce, Post & Parcel, Group
- 120,000+ vehicles (50,000+ electric)
- Operations in 220+ countries and territories
- SBTi-validated targets: Scope 1&2 -42% by 2030, Scope 3 -25% by 2030
- 7 steering-relevant nonfinancial KPIs aligned with Strategy 2030

## Quick start

### Option A — GitHub Actions

1. Go to **Actions → Deploy World Delivery ESG Demo → Run workflow**
2. Choose `all`, set warehouse and database, click **Run workflow**
3. Open the Streamlit dashboard in Snowsight: **Streamlit → WORLD_DELIVERY_ESG_DASHBOARD**

### Option B — Local CLI

```bash
make install DEMO=WORLD_DELIVERY/ESG/EMISSIONS DATABASE=WORLD_DELIVERY WAREHOUSE=WORLD_DELIVERY_WH
```

## Setup files

| File | Purpose |
|------|---------|
| `01_setup.sql` | Iceberg v3 database, warehouse, schema |
| `02_bdc_master_data.sql` | SAP BDC managed products (CompanyCode, CostCenter, Plant, GL) |
| `03_esg_custom_cds.sql` | Custom CDS views (emissions, fleet, facility, GoGreen Plus) |
| `04_successfactors.sql` | SuccessFactors workforce + health/safety |
| `05_marketplace.sql` | External ESG enrichment (emission factors, scores, climate risk) |
| `06_data_seed.sql` | Synthetic data (~10k rows grounded in published sustainability data) |
| `07_views.sql` | 5 analytics views |
| `08_semantic_view.sql` | Cortex Analyst semantic view |
| `09_agent.sql` | Cortex Agent |
| `10_streamlit.sql` | Streamlit-in-Snowflake dashboard |
| `11_verify.sql` | Verification queries |

## Demo storyline

See [DEMO_FLOW.md](DEMO_FLOW.md) for the full 3-act narrative with talking points.

## Prerequisites

- Snowflake account (any edition, any cloud/region)
- ACCOUNTADMIN role
- A warehouse (scripts reference `WORLD_DELIVERY_WH` — override via variable)
