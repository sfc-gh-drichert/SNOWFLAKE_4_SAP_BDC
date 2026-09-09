-- ==============================================================================
-- 08_agent.sql - BSH PnL Cortex Agent
--
-- Creates a Cortex Agent with two tools:
--   1. Cortex Analyst (text-to-SQL) -> BSH_PNL_ANALYTICS_SV semantic view
--   2. Cortex Search -> BSH_PNL_SEARCH_SVC document corpus
--
-- DDL uses CREATE OR REPLACE AGENT with FROM SPECIFICATION (YAML).
-- The agent automatically inherits the Row Access Policy from the semantic view.
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

CREATE OR REPLACE AGENT BSH_PNL_AGENT
  COMMENT = 'BSH Group financial PnL analysis agent. Answers structured margin questions via Cortex Analyst (semantic view) and qualitative market/product questions via Cortex Search (press releases, product docs). Row Access Policy on the underlying table enforces data visibility per role.'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  instructions:
    response: "You are a financial analyst for BSH Group, Europes largest home appliance manufacturer (EUR 15.3B revenue in 2024). Answer questions about PnL performance, brand margins, category trends, and regional data. Be concise and always include EUR amounts and percentage margins where relevant."
    orchestration: "For financial questions (revenue, margins, EBIT, DB1, DB2, cost structure, brand comparison, category analysis) use the PnL_Analyst tool. For qualitative questions (product descriptions, market context, why a category declined, sustainability, brand positioning) use the BSH_Docs_Search tool. For mixed questions, use both tools and combine the answer."
    sample_questions:
      - question: "What was BSH EBIT margin in 2024 vs 2023?"
      - question: "Which brand has the highest gross margin?"
      - question: "Why did the Cooking category decline in 2024?"
      - question: "Show me the PnL waterfall from Gross Revenue to EBIT for Bosch."
      - question: "Compare DB2 margin across distribution channels."

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "PnL_Analyst"
        description: "Converts natural language financial questions to SQL queries against the BSH PnL fact table. Use for: revenue, margins, EBIT, DB1, DB2, COGS, brand comparison, category trends, regional breakdowns, channel profitability, product-level analysis, year-over-year comparisons, seasonality."
    - tool_spec:
        type: "cortex_search"
        name: "BSH_Docs_Search"
        description: "Searches BSH document corpus: press releases, product briefs, brand positioning, market analysis, sustainability reports. Use for: why questions (why did X decline), product technology explanations, brand strategy, market context, manufacturing details, geographic strategy."

  tool_resources:
    PnL_Analyst:
      semantic_view: "<% db_name %>.FIN.BSH_PNL_ANALYTICS_SV"
    BSH_Docs_Search:
      search_service: "<% db_name %>.FIN.BSH_PNL_SEARCH_SVC"
      max_results: "5"
      columns_and_descriptions:
        DOCUMENT_TEXT:
          description: "Full text of the BSH document. Searchable."
          type: "string"
          searchable: true
          filterable: false
        TITLE:
          description: "Document title (press release headline, product brief name, etc.)"
          type: "string"
          searchable: false
          filterable: false
        DOCUMENT_TYPE:
          description: "Document category: PRESS_RELEASE, PRODUCT_BRIEF, MARKET_ANALYSIS, BRAND_GUIDE"
          type: "string"
          searchable: false
          filterable: true
  $$;

-- Grant USAGE on the agent to demo roles
-- (BSH_DATA_DEPLOY_ROLE inherits via BSH_DEMO_GLOBAL_ROLE chain)
GRANT USAGE ON AGENT BSH_PNL_AGENT TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT USAGE ON AGENT BSH_PNL_AGENT TO ROLE BSH_NA_DEMO_ROLE;
GRANT USAGE ON AGENT BSH_PNL_AGENT TO ROLE BSH_APAC_DEMO_ROLE;

-- ==============================================================================
-- SAMPLE VERIFIED QUESTIONS (test these after deployment)
--
-- VQ1: PnL waterfall by brand (2024)
--   "Show me the full PnL waterfall for each brand in 2024 from gross revenue to EBIT."
--
-- VQ2: Category YoY comparison
--   "Compare revenue by product category between 2023 and 2024. Which grew and which declined?"
--
-- VQ3: Gaggenau margin premium
--   "What is Gaggenau gross margin compared to the BSH group average? Why is it higher?"
--
-- VQ4: Top products by DB2
--   "Which are the top 10 products by DB2 marginal contribution in absolute EUR for 2024?"
--
-- VQ5: Regional EBIT
--   "Break down EBIT by region. Which region has the highest EBIT margin?"
--
-- VQ6: Monthly seasonality
--   "Show monthly gross revenue for Bosch in 2024. What seasonal patterns do you observe?"
--
-- VQ7: Channel profitability
--   "Compare gross margin and DB2 margin across distribution channels (Retail, Built-in, E-Commerce, B2B)."
--
-- VQ8: Cooking decline root cause (combined SQL + search)
--   "The Cooking category declined in 2024. How much did it decline and what caused it?"
-- ==============================================================================

SELECT 'Agent created: BSH_PNL_AGENT' AS status;
