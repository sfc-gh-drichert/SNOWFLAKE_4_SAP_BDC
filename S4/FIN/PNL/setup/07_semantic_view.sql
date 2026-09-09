-- ==============================================================================
-- 07_semantic_view.sql - BSH PnL Analytics Semantic View
--
-- DDL structure (from Snowflake docs):
--   TABLES (...), DIMENSIONS (...), METRICS (...) are top-level sibling clauses.
--   Each dimension/metric is prefixed with the logical table alias: PNL.<name>
--   Derived metrics (ratios of other metrics) have NO table prefix.
--
-- The view is built on S3_FINANCE_PNL, which has the Row Access Policy applied.
-- The Semantic View inherits the RAP automatically.
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

CREATE OR REPLACE SEMANTIC VIEW BSH_PNL_ANALYTICS_SV

  TABLES (
    PNL AS <% db_name %>.FIN.S3_FINANCE_PNL
      PRIMARY KEY (SALESORDER, ACDOCA_RACCT, COMPANYCODE, POSTINGDATE, MATERIAL, CUSTOMER)
      COMMENT = 'BSH Group PnL fact table. Row Access Policy on (CLIENT_ID, REGION) enforces data visibility.'
  )

  DIMENSIONS (
    PNL.CLIENT_ID           AS CLIENT_ID
      COMMENT = 'Tenant identifier. Row Access Policy enforces visibility per role.',
    PNL.BRAND               AS BRAND
      COMMENT = 'BSH brand: BOSCH | SIEMENS | GAGGENAU | NEFF | THERMADOR',
    PNL.CATEGORY            AS CATEGORY
      COMMENT = 'Product category: COOKING | LAUNDRY_CARE | DISH_CARE | COOLING | CONSUMER_PRODUCTS',
    PNL.SUBCATEGORY         AS SUBCATEGORY,
    PNL.PRODUCT_TIER        AS PRODUCT_TIER
      COMMENT = 'Positioning tier: PREMIUM | MID | ENTRY',
    PNL.REGION              AS REGION
      COMMENT = 'Sales region: DACH | W_EUROPE | E_EUROPE | N_AMERICA | APAC | EMERGING',
    PNL.COMPANYCODE         AS COMPANYCODE
      COMMENT = 'SAP company code: 1000=Germany, 1100=W_Europe, 1200=E_Europe, 2000=NA, 3000=APAC, 4000=Emerging',
    PNL.COUNTRY             AS COUNTRY
      COMMENT = 'Country of company code (ISO 3166-1 alpha-3)',
    PNL.DISTRIBUTIONCHANNEL AS DISTRIBUTIONCHANNEL
      COMMENT = '10=Retail Specialist | 20=Built-in/Project | 30=E-Commerce | 40=B2B',
    PNL.CUSTOMER            AS CUSTOMER
      COMMENT = 'SAP customer number',
    PNL.MATERIAL            AS MATERIAL
      COMMENT = 'BSH material/SKU number (e.g. BSH-DW-B6000)',
    PNL.PRODUCT_NAME        AS PRODUCT_NAME
      COMMENT = 'Full product name (e.g. Bosch Serie 6 PerfectDry SMV6ZCX00E)',
    PNL.ACDOCA_RACCT        AS ACDOCA_RACCT
      COMMENT = 'GL account number (e.g. 0800000=Gross Revenue, 0500000=Material COGS)',
    PNL.PNL_CATEGORY        AS PNL_CATEGORY
      COMMENT = 'PnL category: REVENUE | TRADE_SPEND | RETURNS | COGS | LOGISTICS | BRAND_ADP | SALES | RD | GA',
    PNL.POSTINGDATE         AS POSTINGDATE
      COMMENT = 'Posting date (last day of fiscal period)',
    PNL.FISCALYEAR          AS FISCALYEAR
      COMMENT = 'Fiscal year (2023 or 2024)',
    PNL.POSTINGPERIOD       AS POSTINGPERIOD
      COMMENT = 'Posting period within fiscal year (1-12)',
    PNL.MONTHYEAR           AS MONTHYEAR
      COMMENT = 'Fiscal period in YYYYMMM format (e.g. 2024003)',
    PNL.CUSTOMERGROUP       AS CUSTOMERGROUP
      COMMENT = '01=Specialist Retail | 02=Mass | 03=E-Commerce | 04=Built-in | 05=B2B'
  )

  METRICS (
    -- ── REVENUE ─────────────────────────────────────────────────────────────
    PNL.GROSS_REVENUE AS SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
      COMMENT = 'Gross Revenue before any trade deductions (EUR). Highest line in the PnL waterfall.',

    PNL.TRADE_DISCOUNTS AS SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
      COMMENT = 'Total trade deductions: customer rebates, volume bonuses, listing fees (EUR). Typically 7.5-10% of gross revenue.',

    PNL.RETURNS AS SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
      COMMENT = 'Product returns and credit notes (EUR). Typically ~1% of gross.',

    PNL.NET_REVENUE AS SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                     - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                     - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
      COMMENT = 'Net Revenue = Gross Revenue minus trade discounts and returns (EUR). Approx 91.5% of gross.',

    -- ── COST OF GOODS SOLD ───────────────────────────────────────────────────
    PNL.MATERIAL_COGS AS SUM(IFF(ACDOCA_RACCT = '0500000', -HSL, 0))
      COMMENT = 'Material cost of goods sold (EUR). Typically 45% of net revenue for Bosch/Siemens, ~36% for Gaggenau.',

    PNL.MFG_LABOUR AS SUM(IFF(ACDOCA_RACCT = '0510000', -HSL, 0))
      COMMENT = 'Manufacturing labour and assembly costs (EUR). Typically 8% of net revenue.',

    PNL.MFG_OVERHEAD AS SUM(IFF(ACDOCA_RACCT = '0520000', -HSL, 0))
      COMMENT = 'Manufacturing overhead including depreciation (EUR). Typically 8% of net revenue.',

    PNL.LOGISTICS AS SUM(IFF(PNL_CATEGORY = 'LOGISTICS', -HSL, 0))
      COMMENT = 'Outbound logistics and freight to customers (EUR). Typically 5% of net revenue.',

    PNL.GROSS_PROFIT AS SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                      - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                      - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                      - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS'), -HSL, 0))
      COMMENT = 'Gross Profit = Net Revenue minus COGS and logistics (EUR). Typically 34% of net for BSH. Gaggenau ~46%.',

    -- ── MARGINAL CONTRIBUTION 1 (DB1) ────────────────────────────────────────
    PNL.BRAND_ADP AS SUM(IFF(PNL_CATEGORY = 'BRAND_ADP', -HSL, 0))
      COMMENT = 'Brand advertising, media spend, and trade marketing (EUR). Typically 11.5% of net revenue.',

    PNL.DB1_MARGINAL_CONTRIBUTION AS SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                                    - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                                    - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                                    - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS'), -HSL, 0))
                                    - SUM(IFF(PNL_CATEGORY = 'BRAND_ADP', -HSL, 0))
      COMMENT = 'DB1 Marginal Contribution (Deckungsbeitrag 1) = Gross Profit minus brand advertising and promotion (EUR). Typically 22.5% of net.',

    -- ── MARGINAL CONTRIBUTION 2 (DB2) ────────────────────────────────────────
    PNL.SALES_COST AS SUM(IFF(PNL_CATEGORY = 'SALES', -HSL, 0))
      COMMENT = 'Sales force, key account management, and commercial costs (EUR). Typically 7% of net revenue.',

    PNL.DB2_MARGINAL_CONTRIBUTION AS SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                                    - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                                    - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                                    - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS'), -HSL, 0))
                                    - SUM(IFF(PNL_CATEGORY IN ('BRAND_ADP','SALES'), -HSL, 0))
      COMMENT = 'DB2 Marginal Contribution (Deckungsbeitrag 2) = DB1 minus sales and commercial costs (EUR). Typically 15.5% of net.',

    -- ── EBIT ──────────────────────────────────────────────────────────────────
    PNL.RD_EXPENSE AS SUM(IFF(PNL_CATEGORY = 'RD', -HSL, 0))
      COMMENT = 'Research and Development expense (EUR). BSH spends ~5.5-6% of net revenue on Research and Development — above industry average. EUR 835M in 2024.',

    PNL.GA_EXPENSE AS SUM(IFF(PNL_CATEGORY = 'GA', -HSL, 0))
      COMMENT = 'General and Administrative expenses (EUR). Typically 3.5% of net revenue.',

    PNL.EBIT AS SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
              - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
              - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
              - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS'), -HSL, 0))
              - SUM(IFF(PNL_CATEGORY IN ('BRAND_ADP','SALES'), -HSL, 0))
              - SUM(IFF(PNL_CATEGORY IN ('RD','GA'), -HSL, 0))
      COMMENT = 'EBIT - Earnings Before Interest and Tax (EUR). BSH actual 2024: approx EUR 918M (6% of EUR 15.3B net revenue).',

    -- ── VOLUME ────────────────────────────────────────────────────────────────
    PNL.TOTAL_UNITS AS SUM(IFF(ACDOCA_RACCT = '0800000', SALESVOLUME, 0))
      COMMENT = 'Total units sold (from SALESVOLUME column on revenue rows).',

    -- ── DERIVED METRICS (ratios) - no table prefix ────────────────────────────
    -- These reference the table-scoped metrics above using the PNL.<name> notation.
    EBIT_MARGIN_PCT AS PNL.EBIT / NULLIF(PNL.NET_REVENUE, 0) * 100
      COMMENT = 'EBIT Margin % of Net Revenue. BSH 2024 actual: ~6%.',

    GP_MARGIN_PCT AS PNL.GROSS_PROFIT / NULLIF(PNL.NET_REVENUE, 0) * 100
      COMMENT = 'Gross Profit Margin % of Net Revenue. BSH avg ~34%. Gaggenau ~46%.',

    DB2_MARGIN_PCT AS PNL.DB2_MARGINAL_CONTRIBUTION / NULLIF(PNL.NET_REVENUE, 0) * 100
      COMMENT = 'DB2 Marginal Contribution Margin % of Net Revenue. Typically 15.5%.',

    AVG_SELLING_PRICE_EUR AS PNL.GROSS_REVENUE / NULLIF(PNL.TOTAL_UNITS, 0)
      COMMENT = 'Average Selling Price in EUR = Gross Revenue / Units Sold. Gaggenau ASP is 4-6x higher than Bosch.'
  )

  COMMENT = 'BSH Group PnL Analytics Semantic View. Full PnL waterfall: Gross Revenue to DB1 to DB2 to EBIT. Row Access Policy inherited from S3_FINANCE_PNL: data visibility controlled per role. 2023-2024 actuals, ~100K rows. EUR currency throughout.';

-- Grant REFERENCES + SELECT (REFERENCES is required for Cortex Agent usage)
GRANT REFERENCES, SELECT ON SEMANTIC VIEW BSH_PNL_ANALYTICS_SV TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW BSH_PNL_ANALYTICS_SV TO ROLE BSH_NA_DEMO_ROLE;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW BSH_PNL_ANALYTICS_SV TO ROLE BSH_APAC_DEMO_ROLE;
-- BSH_DATA_DEPLOY_ROLE inherits via BSH_DEMO_GLOBAL_ROLE chain

SELECT 'Semantic view created: BSH_PNL_ANALYTICS_SV' AS status;
