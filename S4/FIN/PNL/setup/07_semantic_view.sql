-- =============================================================================
-- 07_semantic_view.sql — BSH PnL Analytics Semantic View
--
-- Creates the Snowflake Semantic View that the Cortex Agent (and Cortex Analyst)
-- uses to answer structured PnL questions.
--
-- The view is built on S3_FINANCE_PNL, which has the Row Access Policy applied.
-- The Semantic View INHERITS the RAP automatically — no WHERE filter is needed
-- in the view DDL, and no agent query needs to include CLIENT_ID or REGION filters.
--
-- PnL WATERFALL IMPLEMENTED:
--   GROSS_REVENUE
--   └─ minus TRADE_DISCOUNTS + RETURNS
--      = NET_REVENUE
--      └─ minus MATERIAL_COGS + MFG_LABOUR + MFG_OVERHEAD + LOGISTICS
--         = GROSS_PROFIT  (GP_MARGIN_PCT)
--         └─ minus BRAND_ADP (Advertising and Promotion + Trade Marketing)
--            = DB1_MARGINAL_CONTRIBUTION
--            └─ minus SALES_COST
--               = DB2_MARGINAL_CONTRIBUTION  (DB2_MARGIN_PCT)
--               └─ minus RD_EXPENSE + GA_EXPENSE
--                  = EBIT  (EBIT_MARGIN_PCT)
--
-- NOTE ON DERIVED METRICS:
-- Snowflake Semantic View syntax may or may not support derived metrics that
-- reference other named metrics (e.g. NET_REVENUE = GROSS_REVENUE - TRADE_DISCOUNTS).
-- If your account version does not support this, replace derived metrics with
-- their full SUM(CASE...) expansion, or create a wrapper view first and build
-- the SV on that view.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

CREATE OR REPLACE SEMANTIC VIEW BSH_PNL_ANALYTICS_SV
    TABLES (
        PNL TABLE IDENTIFIER('<% db_name %>').FIN.S3_FINANCE_PNL
        PRIMARY KEY (SALESORDER, ACDOCA_RACCT, COMPANYCODE, POSTINGDATE, MATERIAL, CUSTOMER)

        DIMENSIONS (

            -- ── TENANT + ISOLATION ─────────────────────────────────────────
            CLIENT_ID       COMMENT 'Tenant identifier. Row Access Policy enforces which CLIENT_ID values are visible per role. No need to filter manually — RAP handles it.',

            -- ── BRAND + PRODUCT ────────────────────────────────────────────
            BRAND           COMMENT 'BSH brand: BOSCH | SIEMENS | GAGGENAU | NEFF | THERMADOR',
            CATEGORY        COMMENT 'Product category: COOKING | LAUNDRY_CARE | DISH_CARE | COOLING | CONSUMER_PRODUCTS',
            SUBCATEGORY     COMMENT 'Product sub-category (e.g. Dishwasher Fully Integrated)',
            PRODUCT_TIER    COMMENT 'Positioning tier: PREMIUM | MID | ENTRY',
            MATERIAL        COMMENT 'BSH material/SKU number (e.g. BSH-DW-B6000)',
            PRODUCT_NAME    COMMENT 'Full product name (e.g. Bosch Serie 6 PerfectDry SMV6ZCX00E)',

            -- ── GEOGRAPHY ─────────────────────────────────────────────────
            REGION          COMMENT 'Sales region: DACH | W_EUROPE | E_EUROPE | N_AMERICA | APAC | EMERGING',
            COMPANYCODE     COMMENT 'SAP company code (BSH internal): 1000=Germany, 1100=W_Europe, 1200=E_Europe, 2000=NA, 3000=APAC, 4000=Emerging',
            COUNTRY         COMMENT 'Country of company code (ISO 3166-1 alpha-3)',
            PLANT           COMMENT 'Manufacturing plant code',

            -- ── CUSTOMER + CHANNEL ────────────────────────────────────────
            CUSTOMER        COMMENT 'SAP customer number',
            CUSTOMERGROUP   COMMENT 'Customer group: 01=Specialist Retail | 02=Mass | 03=E-Commerce | 04=Built-in | 05=B2B',
            DISTRIBUTIONCHANNEL
                            COMMENT 'Distribution channel: 10=Retail | 20=Built-in | 30=E-Commerce | 40=B2B',

            -- ── PnL CLASSIFICATION ────────────────────────────────────────
            ACDOCA_RACCT    COMMENT 'GL account number (e.g. 0800000=Gross Revenue, 0500000=Material COGS)',
            PNL_CATEGORY    COMMENT 'PnL category: REVENUE | TRADE_SPEND | RETURNS | COGS | LOGISTICS | BRAND_ADP | SALES | RD | GA',

            -- ── TIME ──────────────────────────────────────────────────────
            POSTINGDATE     COMMENT 'Posting date (last day of fiscal period)',
            FISCALYEAR      COMMENT 'Fiscal year (2023 or 2024)',
            POSTINGPERIOD   COMMENT 'Posting period within fiscal year (1-12)',
            MONTHYEAR       COMMENT 'Fiscal period in YYYYMMM format (e.g. 2024003)'
        )

        METRICS (

            -- ── REVENUE ────────────────────────────────────────────────────
            GROSS_REVENUE = SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                COMMENT 'Gross Revenue before any trade deductions (EUR). Highest line in the PnL waterfall.',

            TRADE_DISCOUNTS = SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                COMMENT 'Total trade deductions: customer rebates, volume bonuses, listing fees (EUR). Typically 7.5-10% of gross revenue. Gaggenau has lower discounts (~4.5%).',

            RETURNS = SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                COMMENT 'Product returns and credit notes (EUR). Typically ~1% of gross.',

            NET_REVENUE = SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                          - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                          - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                COMMENT 'Net Revenue = Gross Revenue minus trade discounts and returns (EUR). Approximately 91.5% of gross. The primary revenue reference for margin ratios.',

            -- ── COST OF GOODS SOLD ─────────────────────────────────────────
            MATERIAL_COGS = SUM(IFF(ACDOCA_RACCT = '0500000', -HSL, 0))
                COMMENT 'Material cost of goods sold (EUR) — purchased components and raw materials. Typically 45% of net revenue for Bosch/Siemens, ~36% for Gaggenau.',

            MFG_LABOUR = SUM(IFF(ACDOCA_RACCT = '0510000', -HSL, 0))
                COMMENT 'Manufacturing labour and assembly costs (EUR). Typically 8% of net revenue.',

            MFG_OVERHEAD = SUM(IFF(ACDOCA_RACCT = '0520000', -HSL, 0))
                COMMENT 'Manufacturing overhead including depreciation (EUR). Typically 8% of net revenue.',

            LOGISTICS = SUM(IFF(PNL_CATEGORY = 'LOGISTICS', -HSL, 0))
                COMMENT 'Outbound logistics and freight to customers (EUR). Typically 5% of net revenue.',

            GROSS_PROFIT = SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                           - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                           - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                           - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS'), -HSL, 0))
                COMMENT 'Gross Profit = Net Revenue minus COGS and logistics (EUR). Typically 34% of net for BSH overall. Gaggenau ~46%, Bosch/Siemens ~32-33%.',

            GP_MARGIN_PCT = (
                              SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                              - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                              - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                              - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS'), -HSL, 0))
                            )
                            / NULLIF(
                              SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                              - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                              - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                            , 0) * 100
                COMMENT 'Gross Profit Margin % of Net Revenue. BSH avg ~34%. Gaggenau ~46%.',

            -- ── MARGINAL CONTRIBUTION 1 (DB1) ─────────────────────────────
            BRAND_ADP = SUM(IFF(PNL_CATEGORY = 'BRAND_ADP', -HSL, 0))
                COMMENT 'Brand advertising, media spend, and trade marketing (EUR). Typically 11.5% of net revenue. Bosch invests heavily in brand media.',

            DB1_MARGINAL_CONTRIBUTION = SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                                        - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                                        - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                                        - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS'), -HSL, 0))
                                        - SUM(IFF(PNL_CATEGORY = 'BRAND_ADP', -HSL, 0))
                COMMENT 'DB1 Marginal Contribution (Deckungsbeitrag 1) = Gross Profit minus brand advertising and promotion (EUR). Typically 22.5% of net revenue. Key metric for brand investment decisions.',

            -- ── MARGINAL CONTRIBUTION 2 (DB2) ─────────────────────────────
            SALES_COST = SUM(IFF(PNL_CATEGORY = 'SALES', -HSL, 0))
                COMMENT 'Sales force, key account management, and commercial costs (EUR). Typically 7% of net revenue.',

            DB2_MARGINAL_CONTRIBUTION = SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                                        - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                                        - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                                        - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS'), -HSL, 0))
                                        - SUM(IFF(PNL_CATEGORY IN ('BRAND_ADP','SALES'), -HSL, 0))
                COMMENT 'DB2 Marginal Contribution (Deckungsbeitrag 2) = DB1 minus sales and commercial costs (EUR). Typically 15.5% of net revenue. Used for regional and brand profitability.',

            DB2_MARGIN_PCT = (
                               SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                               - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                               - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                               - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS'), -HSL, 0))
                               - SUM(IFF(PNL_CATEGORY IN ('BRAND_ADP','SALES'), -HSL, 0))
                             )
                             / NULLIF(
                               SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                               - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                               - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                             , 0) * 100
                COMMENT 'DB2 Marginal Contribution Margin % of Net Revenue. Typically 15.5%.',

            -- ── EBIT ──────────────────────────────────────────────────────
            RD_EXPENSE = SUM(IFF(PNL_CATEGORY = 'RD', -HSL, 0))
                COMMENT 'Research & Development expense (EUR). BSH spends ~5.5-6% of net revenue on Research and Development — above industry average. EUR 835M in 2024 (5.5% of EUR 15.3B revenue).',

            GA_EXPENSE = SUM(IFF(PNL_CATEGORY = 'GA', -HSL, 0))
                COMMENT 'General & Administrative expenses (EUR). Typically 3.5% of net revenue.',

            EBIT = SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                   - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                   - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                   - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS'), -HSL, 0))
                   - SUM(IFF(PNL_CATEGORY IN ('BRAND_ADP','SALES'), -HSL, 0))
                   - SUM(IFF(PNL_CATEGORY IN ('RD','GA'), -HSL, 0))
                COMMENT 'EBIT — Earnings Before Interest and Tax (EUR). BSH actual 2024: approximately EUR 918M (6% of EUR 15.3B net revenue). Gaggenau contributes disproportionately to group EBIT despite low volume.',

            EBIT_MARGIN_PCT = (
                                SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                                - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                                - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                                - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS'), -HSL, 0))
                                - SUM(IFF(PNL_CATEGORY IN ('BRAND_ADP','SALES'), -HSL, 0))
                                - SUM(IFF(PNL_CATEGORY IN ('RD','GA'), -HSL, 0))
                              )
                              / NULLIF(
                                SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                                - SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))
                                - SUM(IFF(PNL_CATEGORY = 'RETURNS', -HSL, 0))
                              , 0) * 100
                COMMENT 'EBIT Margin % of Net Revenue. BSH 2024 actual: ~6%.',

            -- ── VOLUME ────────────────────────────────────────────────────
            TOTAL_UNITS = SUM(IFF(ACDOCA_RACCT = '0800000', SALESVOLUME, 0))
                COMMENT 'Total units sold (calculated from SALESVOLUME column on revenue rows). Populated on ACDOCA_RACCT=0800000 (Gross Revenue) lines only.',

            AVG_SELLING_PRICE_EUR = SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
                                    / NULLIF(SUM(IFF(ACDOCA_RACCT = '0800000', SALESVOLUME, 0)), 0)
                COMMENT 'Average Selling Price in EUR = Gross Revenue / Units Sold. Gaggenau ASP is 4-6x higher than Bosch. Monitor for mix shift from premium to entry tier.'
        )
    )
COMMENT = 'BSH Group PnL Analytics Semantic View — ACDOCA/CO-PA profitability analysis. Full PnL waterfall: Gross Revenue → Net Revenue → Gross Profit → DB1 → DB2 → EBIT. Row Access Policy inherited from S3_FINANCE_PNL: data visibility controlled per role. 2023-2024 actuals, ~100K rows. EUR currency throughout.';

-- Grant select on semantic view to demo roles
GRANT SELECT ON SEMANTIC VIEW BSH_PNL_ANALYTICS_SV TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT SELECT ON SEMANTIC VIEW BSH_PNL_ANALYTICS_SV TO ROLE BSH_NA_DEMO_ROLE;
GRANT SELECT ON SEMANTIC VIEW BSH_PNL_ANALYTICS_SV TO ROLE BSH_APAC_DEMO_ROLE;

SELECT 'Semantic view created: BSH_PNL_ANALYTICS_SV' AS status;
