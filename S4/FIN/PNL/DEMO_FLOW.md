# BSH Group P&L Demo — Demo Flow Guide

A complete narrative for running the BSH Group financial P&L demo in Snowflake.
Covers setup context, role demonstrations, Cortex Agent QA, and a sample question bank.

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

> "BSH is Europe's largest home appliance manufacturer — EUR 15.3 billion in revenue (2024 reference year),
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

1. *"Show me the BSH Group P&L waterfall for 2025 — from gross revenue down to EBIT, for each brand."*

   Expected: table with BRAND | GROSS_REVENUE | NET_REVENUE | GROSS_PROFIT | DB1 | DB2 | EBIT | EBIT_MARGIN_PCT

2. *"What was the EBIT margin trend from 2023 to 2026 across all brands?"*

3. *"The Cooking category declined in 2024 — has it recovered in 2025 and 2026?"*
   > This combines SQL (2024 decline + 2025-2026 recovery arc) with document search (real estate cycle / AI appliance trends)

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

9. *"Show monthly Bosch revenue for 2025. What seasonal pattern do you see?"*
   > Expected: September peak (IFA Berlin product launches), November/December Christmas peak, January trough

10. *"How has North America grown since 2023? What drove that growth?"*
    > Agent should reference the Experience and Design Center expansion document

---

## Sample Cortex Agent Question Bank

### Brand Performance
- "What was BSH's total gross revenue in 2025 by brand?"
- "Compare Bosch and Siemens: revenue, gross margin, and EBIT margin side by side."
- "Which brand contributes most to group EBIT in absolute euros?"
- "What is Thermador's EBIT margin compared to BSH's overall EBIT margin?"
- "Show the DB2 margin waterfall for Gaggenau from gross revenue to DB2."

### Category Analysis
- "Which product category had the highest revenue growth between 2023 and 2026?"
- "Consumer Products has been growing consistently. What drove this growth?"
- "Compare gross margin across all five product categories."
- "What is the split between PREMIUM, MID, and ENTRY tier revenue for dishwashers?"
- "Which category has the highest average selling price?"

### Regional Deep Dive
- "How does the DACH region P&L compare to Western Europe?"
- "What is BSH's APAC revenue and EBIT margin?"
- "Which regions are above and below the group average EBIT margin?"
- "Show revenue by region from 2023 to 2026 — which grew fastest?"
- "What is the distribution channel mix in North America versus Europe?"

### Channel Strategy
- "What percentage of BSH revenue comes from E-Commerce versus Retail?"
- "Compare trade discount rates across channels — which channel has the lowest discounts?"
- "The Built-in channel was under pressure. By how much did it decline and why?"
- "Which combination of brand and distribution channel has the highest DB2 margin?"

### Cost Structure and Margins
- "Break down BSH's cost structure as a percentage of net revenue (COGS, Advertising and Promotion, Sales, Research and Development, General and Administrative)."
- "BSH invested EUR 835 million in Research and Development (2024 reference). What is that as a percentage of revenue?"
- "How does trade marketing spend compare across brands?"
- "What would EBIT be if trade discounts were reduced by 2 percentage points?"

### Contextual / Qualitative (uses search tool)
- "What is the Slide-Hide oven? Why is it a signature NEFF product?"
- "What is Home Connect and how many appliances is it connected to?"
- "What is zeolite technology in BSH dishwashers?"
- "Explain BSH's sustainability commitment — are they carbon neutral?"
- "Why does BSH invest so heavily in Research and Development compared to competitors?"

---

## Add a New Company (Runbook)

### What does "a company" mean here?

Every row in `S3_FINANCE_PNL` has a `CLIENT_ID` column. All BSH rows have `CLIENT_ID = 'BSH'`.
A "new company" is simply a set of rows with a different `CLIENT_ID` — for example `'HENKEL'`.

> `CLIENT_ID` is the **tenant** identifier.
> `COMPANYCODE` is different — it is the SAP-internal entity within a company
> (BSH uses 1000=Germany, 2000=North America, 3000=APAC, etc.).
> Do not confuse the two.

The table, semantic view, and Row Access Policy are **shared** across all companies.
The RAP reads `ROLE_ACCESS_MAPPING` dynamically, so it automatically enforces boundaries for any
new `CLIENT_ID` you register — no DDL changes required.

### Step 1 — Create the role and register access

Run from your laptop (or trigger via GitHub Actions → `deploy` with the runbook):

```bash
make add-company COMPANY=HENKEL CONNECTION=my_snowflake
```

This creates `HENKEL_DEMO_ROLE` and inserts one row into `ROLE_ACCESS_MAPPING`:

| ROLE_NAME | ALLOWED_CLIENT | ALLOWED_REGION | Effect |
|-----------|---------------|----------------|--------|
| HENKEL_DEMO_ROLE | HENKEL | NULL | Full Henkel access, all regions |

### Step 2 — Load Henkel's data

Insert rows into `S3_FINANCE_PNL` with `CLIENT_ID = 'HENKEL'`.
The easiest path is to copy `05_data_seed.sql`, replace `'BSH'` with `'HENKEL'`, and adapt the
product names, brand names, and amount ranges to match Henkel's business profile.

For a quick isolation test before building a full dataset, one row is enough:

```sql
INSERT INTO S4.FIN.S3_FINANCE_PNL
    (CLIENT_ID, REGION, BRAND, CATEGORY, PNL_CATEGORY, HSL,
     FISCALYEAR, POSTINGPERIOD, POSTINGDATE, CURRENCY,
     ACDOCA_RACCT, COMPANYCODE, SALESORDER, VERSION, RECORDTYPE,
     LASTUPDATE_TS_REPORTING, CFIN_TS_DELTA)
VALUES
    ('HENKEL', 'DACH', 'HENKEL_CONSUMER', 'CONSUMER_GOODS', 'REVENUE',
     1500000, 2024, 3, '2024-03-31', 'EUR',
     '0800000', '1000', 'SO-HENKEL-001', '000', '00',
     CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());
```

### Step 3 — Verify isolation

```sql
-- Henkel role: should see only HENKEL rows
USE ROLE HENKEL_DEMO_ROLE;
SELECT DISTINCT CLIENT_ID FROM S4.FIN.S3_FINANCE_PNL;
-- Expected: HENKEL

-- BSH role: must not see HENKEL rows
USE ROLE BSH_DEMO_ROLE;
SELECT DISTINCT CLIENT_ID FROM S4.FIN.S3_FINANCE_PNL;
-- Expected: BSH only

-- Global role: sees both companies side by side
USE ROLE BSH_DEMO_GLOBAL_ROLE;
SELECT CLIENT_ID, COUNT(*) AS rows FROM S4.FIN.S3_FINANCE_PNL GROUP BY 1;
-- Expected: BSH ~100,000 rows  |  HENKEL however many you loaded
```

### Step 4 — Create a Henkel Cortex Agent (optional)

The shared `BSH_PNL_ANALYTICS_SV` semantic view already works for Henkel data.
A company-specific agent just lets you tailor the system prompt:

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE S4; USE SCHEMA FIN;

CREATE OR REPLACE CORTEX AGENT HENKEL_PNL_AGENT
    SEMANTIC_VIEWS  = (S4.FIN.BSH_PNL_ANALYTICS_SV)
    SEARCH_SERVICES = (S4.FIN.BSH_PNL_SEARCH_SVC)
    COMMENT = 'Henkel P&L analysis agent';

GRANT USAGE ON CORTEX AGENT HENKEL_PNL_AGENT TO ROLE HENKEL_DEMO_ROLE;
```

### Summary: what changes and what does not

| Object | Changes needed? |
|--------|-----------------|
| `S3_FINANCE_PNL` table DDL | No — same table, new rows with new `CLIENT_ID` |
| `PNL_CLIENT_ISOLATION_POLICY` RAP | No — reads `ROLE_ACCESS_MAPPING` dynamically |
| `BSH_PNL_ANALYTICS_SV` semantic view | No — shared, works for any company |
| `ROLE_ACCESS_MAPPING` | Yes — one `INSERT` row via `make add-company` |
| New company's data | Yes — you need to create the data rows |

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
| DB1 | Gross Profit – Brand Advertising and Promotion | ~22.5% |
| DB2 | DB1 – Sales Costs | ~15.5% |
| EBIT | DB2 – Research and Development – General and Administrative | ~6.0% |

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
