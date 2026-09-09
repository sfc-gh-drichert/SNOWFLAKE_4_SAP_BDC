# BSH Group P&L Demo — Demo Flow Guide

A complete narrative for running the BSH Group financial P&L demo in Snowflake.
Covers setup context, role demonstrations, Cortex Agent Q&A, and a sample question bank.

---

## Architecture Overview

```
S4.FIN.S3_FINANCE_PNL  (~100K rows — SAP ACDOCA/CO-PA structure)
     │
     ├── CLIENT_ID + REGION
     │        └─ Row Access Policy  ←────────── PNL_CLIENT_ISOLATION_POLICY
     │                                           Enforces data boundaries per role.
     │                                           The Semantic View inherits this.
     │
     └── S4.FIN.BSH_PNL_ANALYTICS_SV  (Semantic View)
              Dimensions: BRAND, CATEGORY, REGION, COMPANYCODE,
                          DISTRIBUTIONCHANNEL, PRODUCT_TIER, FISCALYEAR, …
              Metrics:    GROSS_REVENUE → NET_REVENUE → GROSS_PROFIT
                          → DB1_MARGINAL_CONTRIBUTION
                          → DB2_MARGINAL_CONTRIBUTION
                          → EBIT, EBIT_MARGIN_PCT, GP_MARGIN_PCT
                          → TOTAL_UNITS, AVG_SELLING_PRICE_EUR
              │
              └── S4.FIN.BSH_PNL_AGENT  (Cortex Agent)
                       SQL tool  →  BSH_PNL_ANALYTICS_SV   (structured queries)
                       Search    →  BSH_PNL_SEARCH_SVC     (press releases, product docs)
```

---

## Role Hierarchy and Data Visibility

| Role | Companies | Regions | Use Case |
|------|-----------|---------|----------|
| `ACCOUNTADMIN` / `SYSADMIN` | All | All | Admin / setup only — do not use in demos |
| `BSH_DEMO_GLOBAL_ROLE` | All | All | Multi-company executive demo |
| `BSH_DEMO_ROLE` | BSH | All 6 | Full BSH P&L story — recommended primary demo role |
| `BSH_EUROPE_DEMO_ROLE` | BSH | DACH, W_EUROPE, E_EUROPE | European operations focus |
| `BSH_NA_DEMO_ROLE` | BSH | N_AMERICA | North America growth story |
| `BSH_APAC_DEMO_ROLE` | BSH | APAC, EMERGING | Asia-Pacific e-commerce story |

**How isolation works:** The Row Access Policy fires on every query — including Cortex Agent queries. A role that is not registered in `ROLE_ACCESS_MAPPING` for a given CLIENT_ID + REGION combination cannot retrieve those rows, regardless of what SQL is written or what the agent is asked.

---

## Demo Acts (5–15 minutes total)

### Act 1 — BSH Context (2 minutes)

> "BSH is Europe's largest home appliance manufacturer — EUR 15.3 billion in revenue in 2024,
> owned by Bosch since 2015. They make the brands in most European kitchens:
> Bosch, Siemens, Gaggenau, NEFF, Thermador.
>
> They don't publish detailed P&L because they're not publicly listed.
> All their financial data lives in SAP. What we've done is bring that SAP data structure —
> specifically the ACDOCA CO-PA profitability table — into Snowflake, populate it with
> realistic synthetic data, and put an AI layer on top."

**Switch to BSH_DEMO_ROLE:**
```sql
USE ROLE BSH_DEMO_ROLE;
```

---

### Act 2 — Data Isolation (3 minutes)

> "Before we look at the numbers, let me show you something that matters for any real
> enterprise deployment: data isolation between different demo customers."

**Show Europe-only view:**
```sql
USE ROLE BSH_EUROPE_DEMO_ROLE;
SELECT DISTINCT REGION FROM S4.FIN.S3_FINANCE_PNL ORDER BY 1;
-- Returns: DACH, E_EUROPE, W_EUROPE  (N_AMERICA, APAC, EMERGING are invisible)
```

> "The BSH Europe analyst role physically cannot see North American or APAC rows.
> This isn't a WHERE clause in a report — it's a Snowflake Row Access Policy on the base table.
> The Cortex Agent inherits it automatically. An adversarial prompt cannot bypass it."

**Compare with global role:**
```sql
USE ROLE BSH_DEMO_GLOBAL_ROLE;
SELECT DISTINCT REGION FROM S4.FIN.S3_FINANCE_PNL ORDER BY 1;
-- Returns: all 6 regions
```

> "Adding a new company? One SQL script. No DDL changes to the table, semantic view,
> or policy required."

---

### Act 3 — The P&L Waterfall (4 minutes)

> "Now let's ask the agent to tell us the BSH P&L story."

**Switch back to full BSH role:**
```sql
USE ROLE BSH_DEMO_ROLE;
```

**Suggested agent questions:**

1. *"Show me the BSH Group P&L waterfall for 2024 — from gross revenue down to EBIT, for each brand."*

   Expected: table with BRAND | GROSS_REVENUE | NET_REVENUE | GROSS_PROFIT | DB1 | DB2 | EBIT | EBIT_MARGIN_PCT

2. *"What was the EBIT margin in 2024 compared to 2023 across all brands?"*

3. *"Why is the Cooking category declining? How much did it decline in 2024?"*
   > This combines SQL (category revenue down 4.6%) with document search (real estate cycle explanation from the press release)

---

### Act 4 — Premium Brand Story (3 minutes)

> "Gaggenau is a small brand by volume — only 7% of BSH's revenue.
> But watch what it does to the margin picture."

**Suggested agent questions:**

4. *"Compare Gaggenau's gross margin and EBIT margin to Bosch and Siemens."*

   Expected: Gaggenau GP margin ~46% vs Bosch ~32-33%. The story: ultra-premium pricing,
   minimal trade discounts, controlled distribution through kitchen studios.

5. *"What are the top 10 products by DB2 contribution in euros? Show brand and category."*

6. *"Which brand has the highest average selling price? How does it compare to its gross margin?"*

> "This is the story Gaggenau's finance team tells internally.
> With Snowflake, every analyst can run this in seconds."

---

### Act 5 — Regional and Channel Insight (3 minutes)

7. *"Break down EBIT by region. Which region has the highest margin?"*

8. *"Compare gross margin across distribution channels — Retail, Built-in, E-Commerce, B2B."*
   > Expected: Built-in channel has highest margin (Gaggenau/NEFF bias), E-Commerce has lower

9. *"Show monthly Bosch revenue for 2024. What seasonal pattern do you see?"*
   > Expected: September peak (IFA Berlin product launches), November/December Christmas peak, January trough

10. *"North America grew 3% in 2024. What drove that growth?"*
    > Agent should reference the Experience and Design Center expansion document

---

## Sample Cortex Agent Question Bank

### Brand Performance
- "What was BSH's total gross revenue in 2024 by brand?"
- "Compare Bosch and Siemens: revenue, gross margin, and EBIT margin side by side."
- "Which brand contributes most to group EBIT in absolute euros?"
- "What is Thermador's EBIT margin compared to BSH's overall EBIT margin?"
- "Show the DB2 margin waterfall for Gaggenau from gross revenue to DB2."

### Category Analysis
- "Which product category had the highest revenue growth in 2024?"
- "Consumer Products grew 5.5% in 2024. What drove this growth?"
- "Compare gross margin across all five product categories."
- "What is the split between PREMIUM, MID, and ENTRY tier revenue for dishwashers?"
- "Which category has the highest average selling price?"

### Regional Deep Dive
- "How does the DACH region P&L compare to Western Europe?"
- "What is BSH's APAC revenue and EBIT margin?"
- "Which regions are above and below the group average EBIT margin?"
- "Show revenue by region for 2023 and 2024 — which grew fastest?"
- "What is the distribution channel mix in North America versus Europe?"

### Channel Strategy
- "What percentage of BSH revenue comes from E-Commerce versus Retail?"
- "Compare trade discount rates across channels — which channel has the lowest discounts?"
- "The Built-in channel declined in 2024. By how much and why?"
- "Which combination of brand and distribution channel has the highest DB2 margin?"

### Cost Structure and Margins
- "Break down BSH's cost structure as a percentage of net revenue (COGS, A&P, Sales, R&D, G&A)."
- "BSH invested EUR 835 million in R&D in 2024. What is that as a percentage of revenue?"
- "How does trade marketing spend compare across brands?"
- "What would EBIT be if trade discounts were reduced by 2 percentage points?"

### Contextual / Qualitative (uses search tool)
- "What is the Slide&Hide oven? Why is it a signature NEFF product?"
- "What is Home Connect and how many appliances is it connected to?"
- "What is zeolite technology in BSH dishwashers?"
- "Explain BSH's sustainability commitment — are they carbon neutral?"
- "Why does BSH invest so heavily in R&D compared to competitors?"

---

## Add a New Company (Runbook)

To onboard a second demo company (e.g. Henkel, Miele, Bayer):

```bash
# Step 1: Run the onboarding script
make add-company COMPANY=HENKEL CONNECTION=EU_DEMO47

# Step 2: Load Henkel P&L data
# → Insert rows into S4.FIN.S3_FINANCE_PNL with CLIENT_ID = 'HENKEL'
# → Use your own data generation script or adapt 05_data_seed.sql

# Step 3: Create a Henkel-specific agent (optional but recommended)
# → Add CREATE CORTEX AGENT HENKEL_PNL_AGENT ... to a new 08_agent_henkel.sql

# Step 4: Test isolation
USE ROLE HENKEL_DEMO_ROLE;
SELECT DISTINCT CLIENT_ID FROM S4.FIN.S3_FINANCE_PNL;
-- Returns: HENKEL only  (BSH rows invisible to this role)

USE ROLE BSH_DEMO_ROLE;
SELECT DISTINCT CLIENT_ID FROM S4.FIN.S3_FINANCE_PNL;
-- Returns: BSH only  (Henkel rows invisible to this role)
```

**What does NOT change:** `S3_FINANCE_PNL` DDL, `BSH_PNL_ANALYTICS_SV`, `PNL_CLIENT_ISOLATION_POLICY`.

---

## Technical Reference

### All Snowflake Objects Created

```
Database/Schema:
  S4.FIN

Tables:
  S4.FIN.S3_FINANCE_PNL         Main P&L fact (~100K rows, RAP applied)
  S4.FIN.DIM_GL_ACCOUNT         GL account / P&L line master (13 rows)
  S4.FIN.DIM_PRODUCT            BSH product catalogue (52 SKUs)
  S4.FIN.DIM_CUSTOMER           Retail customer master (44 rows)
  S4.FIN.DIM_COMPANY            SAP company code master (6 rows)
  S4.FIN.DIM_PLANT              Manufacturing plant master (8 rows)
  S4.FIN.ROLE_ACCESS_MAPPING    Role → CLIENT_ID + REGION access registry
  S4.FIN.BSH_DOCUMENTS          Document corpus for Cortex Search (~20 rows)

Policies:
  S4.FIN.PNL_CLIENT_ISOLATION_POLICY   Two-column RAP on (CLIENT_ID, REGION)

AI Objects:
  S4.FIN.BSH_PNL_SEARCH_SVC      Cortex Search on BSH_DOCUMENTS
  S4.FIN.BSH_PNL_ANALYTICS_SV    Semantic View (P&L waterfall)
  S4.FIN.BSH_PNL_AGENT           Cortex Agent (SQL + Search)

Roles:
  BSH_DEMO_GLOBAL_ROLE    All clients, all regions
  BSH_DEMO_ROLE           BSH, all regions
  BSH_EUROPE_DEMO_ROLE    BSH: DACH + W_EUROPE + E_EUROPE
  BSH_NA_DEMO_ROLE        BSH: N_AMERICA
  BSH_APAC_DEMO_ROLE      BSH: APAC + EMERGING
```

### P&L Metric Quick Reference

| Metric | Formula | Typical % of Net Revenue |
|--------|---------|--------------------------|
| GROSS_REVENUE | SUM(HSL) where category=REVENUE | ~109% |
| TRADE_DISCOUNTS | ABS(SUM) where category=TRADE_SPEND | ~7.5% |
| NET_REVENUE | Gross – Discounts – Returns | 100% |
| MATERIAL_COGS | ABS(SUM) where account=0500000 | ~45% |
| GROSS_PROFIT | Net Revenue – COGS – Logistics | ~34% |
| DB1 | Gross Profit – Brand A&P | ~22.5% |
| DB2 | DB1 – Sales Costs | ~15.5% |
| EBIT | DB2 – R&D – G&A | ~6.0% |

### Row Access Policy Logic

```
RETURNS BOOLEAN ->
  CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN')   -- admin bypass
  OR EXISTS (
    SELECT 1 FROM ROLE_ACCESS_MAPPING
    WHERE ROLE_NAME     = CURRENT_ROLE()
      AND (ALLOWED_CLIENT IS NULL OR ALLOWED_CLIENT = CLIENT_ID)  -- tenant filter
      AND (ALLOWED_REGION IS NULL OR ALLOWED_REGION = REGION)     -- region filter
  )
```

To add a new (role, client, region) permission: `INSERT INTO ROLE_ACCESS_MAPPING`.
No other changes needed.
