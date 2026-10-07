# World Delivery ESG — Demo Flow

## Setting the scene

**Audience**: CFO / Head of Sustainability / Corporate Visibility
**Context**: World Delivery has SAP S/4HANA, IBM TM1 for management reporting, Power BI for dashboards, and Databricks ("Finder") connected via SAP BDC. Emissions data sits in aggregated form across these systems. ESRS E1 reporting takes weeks of manual reconciliation.
**Snowflake position**: Complementary intelligence layer — not replacing SAP, TM1, or Finder. Filling the granularity gap between aggregated management reports and record-level ESG analytics.

---

## Act 1 — The Granularity Gap

**Open the ESG Executive Overview dashboard.**

> "These are the 7 steering KPIs the board sees every quarter. Today they come from a manual consolidation across TM1, SAP, and Excel. Let me show you what happens when we bring the underlying record-level data into Snowflake."

**Point to the GHG emissions chart:**

> "Total emissions: ~32 million tonnes CO2e. Air transport is 65%, Road 23%, Ocean 11%. This breakdown already exists in your sustainability report. But what TM1 can't show you is..."

**Navigate to Emissions Deep Dive:**

> "...drill down from group total to individual shipping lanes. Leipzig to Cincinnati, 8,500 km average, 650 kg CO2e per shipment. That's the granularity gap — 5,000 individual shipment records in this demo, representing millions in production."

**Talking point**: SAP BDC provides the master data (CompanyCode, CostCenter, Plant, ACDOCA ledger entries). The emission calculations run in Snowflake using GLEC Framework 3.1 factors. No data moved — zero-copy via BDC Connect.

---

## Act 2 — ESRS E1 Automated Reporting

**Switch to the Agent Chat page.**

> "The sustainability team spends 3 weeks each quarter reconciling Scope 1, 2, and 3 data for ESRS E1 disclosure. Let me show you an alternative."

**Ask the agent**: "Generate the ESRS E1-6 disclosure table"

> "That's the same table structure as page 86 of the annual report — Scope 1, Scope 2 market-based, Scope 3 by category. Generated in 3 seconds from record-level data."

**Ask the agent**: "Are we on track for our SBTi 2030 targets?"

> "Scope 1&2: SBTi requires -42% by 2030. Scope 3: -25%. The view calculates the trajectory required vs actual reduction rate and flags ON_TRACK or AT_RISK."

**Point to the SBTi gauge on the Executive Overview:**

> "The sustainability team can see this in real-time instead of waiting for the quarterly manual consolidation."

**Talking point**: The ESRS E1-6 view joins SAP ACDOCA (fuel/energy costs), custom emission calculations (per-shipment CO2e), and facility energy records. Cortex AI could validate emission calculations, classify fuel types, and flag anomalies.

---

## Act 3 — Green Revenue Intelligence

**Navigate to the GoGreen Plus dashboard page.**

> "Strategy 2030 calls World Delivery 'Green Logistics of Choice'. GoGreen Plus is the commercial product — customers pay a premium for emission-reduced logistics via SAF, e-vehicles, or carbon insetting. But today, connecting the commercial performance to the sustainability outcomes requires manual work."

**Point to the KPI cards:**

> "Green premium revenue, CO2e avoided, SAF deployed. These connect the commercial green product to measurable sustainability outcomes."

**Ask the agent**: "Which customers had the highest CO2e avoidance through GoGreen Plus?"

> "Mytheresa, dm-drogerie, Formula 1 — these are real DHL GoGreen Plus customers in the sustainability brochure. The agent connects order data to emission reduction certificates."

**Point to the CO2e by Technology chart:**

> "SAF is the dominant decarbonization technology — 185,000 tonnes deployed at a 10% blending ratio. But e-vehicles and insetting are growing. This view lets the commercial team price premiums based on actual decarbonization costs."

---

## Close — Full ESG Panorama

**Return to the Executive Overview.**

> "One platform, one truth, from individual shipment to board report. The 7 steering KPIs — GHG emissions, decarb effects, engagement, women in management, LTIFR, compliance training, cybersecurity — all computed from record-level data, all auditable, all real-time."

**Ask the agent**: "Give me a full ESG status across all steering KPIs"

> "This is the view that doesn't exist in any single system today. SAP has the finance and master data. SuccessFactors has workforce. TM1 has the aggregated KPIs. Finder has the cross-system analytics. But only Snowflake can bring all of these together with Marketplace enrichment and Cortex AI — and make it queryable in natural language."

---

## Key messages

1. **Complementary, not replacement** — Snowflake sits alongside SAP, TM1, Power BI, and Finder. BDC Connect provides zero-copy data access.
2. **Granularity gap** — Record-level ESG analytics (per-shipment, per-vehicle, per-facility) that aggregated systems can't provide.
3. **ESRS automation** — From manual quarterly consolidation to real-time disclosure-ready views.
4. **Green revenue attribution** — Connecting GoGreen Plus commercial performance to measurable sustainability outcomes.
5. **Time to value** — This entire demo deploys to any Snowflake account via a single GitHub Actions workflow run.
