-- =============================================================================
-- 08_agent.sql — BSH PnL Cortex Agent
--
-- Creates the Cortex Agent with two tools:
--   1. SQL tool  → BSH_PNL_ANALYTICS_SV (structured PnL queries)
--   2. Search    → BSH_PNL_SEARCH_SVC   (qualitative/contextual questions)
--
-- The agent can answer questions like:
--   "What was BSH's EBIT margin in 2024?" → SQL tool
--   "Why did the Cooking category decline?" → Search tool
--   "How does Gaggenau compare to Bosch?" → Both tools combined
--
-- NOTE ON CREATE CORTEX AGENT SYNTAX:
-- The exact DDL for Cortex Agent creation varies by Snowflake account version
-- and region. Check Snowflake release notes for the current syntax in your
-- EU_DEMO47 account. The syntax below follows the documented pattern as of 2025.
-- If your account uses a different syntax, adjust the SEMANTIC_VIEWS and
-- SEARCH_SERVICES parameters accordingly.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

CREATE OR REPLACE CORTEX AGENT BSH_PNL_AGENT
    SEMANTIC_VIEWS  = (IDENTIFIER('<% db_name %>').FIN.BSH_PNL_ANALYTICS_SV)
    SEARCH_SERVICES = (IDENTIFIER('<% db_name %>').FIN.BSH_PNL_SEARCH_SVC)
    COMMENT = 'BSH Group financial PnL analysis agent. '
              'Answers structured margin questions via the Semantic View and qualitative '
              'market/product questions via the BSH document search service. '
              'Row Access Policy on the underlying table enforces data visibility per role — '
              'the agent automatically sees only data the calling role is authorised to access.'
;

-- =============================================================================
-- VERIFIED QUERY EXAMPLES
-- These are pre-validated questions with expected answer shapes.
-- Use them in demos to show consistent, accurate responses.
-- =============================================================================

-- VQ1: Full PnL waterfall by brand (2024 actuals)
-- Expected: table with BRAND, GROSS_REVENUE, NET_REVENUE, GROSS_PROFIT,
--           DB1_MARGINAL_CONTRIBUTION, DB2_MARGINAL_CONTRIBUTION, EBIT,
--           GP_MARGIN_PCT, EBIT_MARGIN_PCT, sorted by GROSS_REVENUE desc
-- Agent question: "Show me the full PnL waterfall for each brand in 2024,
--                  from gross revenue down to EBIT with margin percentages."

-- VQ2: Category revenue YoY comparison (2023 vs 2024)
-- Expected: table with CATEGORY, REV_2023, REV_2024, GROWTH_PCT
--           Cooking should show -4.6%, Consumer Products +5.5%
-- Agent question: "Compare revenue by product category between 2023 and 2024.
--                  Which categories grew and which declined?"

-- VQ3: Gaggenau gross margin vs BSH group average
-- Expected: Gaggenau GP_MARGIN_PCT ~46%, Group avg ~34%
-- Agent question: "What is Gaggenau's gross margin compared to the BSH group average?
--                  Why is it higher?"

-- VQ4: Top 10 products by DB2 contribution (2024)
-- Expected: table of PRODUCT_NAME, BRAND, CATEGORY, DB2_MARGINAL_CONTRIBUTION,
--           DB2_MARGIN_PCT, sorted by DB2 EUR desc
-- Agent question: "Which are the top 10 products by marginal contribution (DB2)
--                  in absolute euros for 2024?"

-- VQ5: Regional EBIT breakdown
-- Expected: table with REGION, GROSS_REVENUE, EBIT, EBIT_MARGIN_PCT
-- Agent question: "Break down EBIT by region. Which region has the highest EBIT margin?"

-- VQ6: Monthly revenue trend — seasonality
-- Expected: time series showing Nov/Dec peaks and Jan dip
-- Agent question: "Show monthly gross revenue for Bosch in 2024.
--                  What do you observe about seasonal patterns?"

-- VQ7: Channel profitability (Retail vs Built-in vs E-Commerce vs B2B)
-- Expected: table with DISTRIBUTIONCHANNEL, NET_REVENUE, GP_MARGIN_PCT, DB2_MARGIN_PCT
-- Agent question: "Compare gross margin and DB2 margin across distribution channels.
--                  Which channel is most profitable?"

-- VQ8: Cooking category decline root cause (combines SQL + search)
-- Expected: SQL shows Cooking -4.6% in 2024, search returns market analysis doc
-- Agent question: "The Cooking category declined in 2024. How much did it decline
--                  and what caused it?"

-- Grant agent usage to demo roles (inherited by parent roles)
GRANT USAGE ON CORTEX AGENT BSH_PNL_AGENT TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT USAGE ON CORTEX AGENT BSH_PNL_AGENT TO ROLE BSH_NA_DEMO_ROLE;
GRANT USAGE ON CORTEX AGENT BSH_PNL_AGENT TO ROLE BSH_APAC_DEMO_ROLE;

SELECT 'Agent created: BSH_PNL_AGENT' AS status;
