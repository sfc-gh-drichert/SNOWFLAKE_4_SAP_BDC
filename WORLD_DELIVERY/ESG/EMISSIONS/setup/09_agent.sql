-- =============================================================================
-- 09_agent.sql — World Delivery ESG Cortex Agent
--
-- Creates a Cortex Agent with Cortex Analyst (text-to-SQL) tool pointing
-- at the WORLD_DELIVERY_ESG_SV semantic view.
--
-- Variables: <% db_name %>, <% wh_name %>
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA ESG;

CREATE OR REPLACE AGENT WORLD_DELIVERY_ESG_AGENT
  COMMENT = 'World Delivery ESG intelligence agent. Answers emissions, decarbonization, fleet, workforce, and ESRS compliance questions via Cortex Analyst semantic view.'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  instructions:
    response: >
      You are the ESG intelligence assistant for World Delivery, a global logistics
      company operating across Express, Supply Chain, eCommerce, and Post & Parcel
      divisions with ~580,000 employees and 120,000+ vehicles.

      Answer questions about:
      - GHG emissions (Scope 1, 2, 3) by division, transport mode, and fuel type
      - ESRS E1 disclosure data
      - SBTi 2030 target progress (Scope 1&2: -42%, Scope 3: -25%)
      - Emission forecasts: BAU, accelerated decarb, and SBTi-required scenarios through 2030
      - Decarbonization lever analysis: marginal abatement costs, investment required per lever
      - GoGreen Plus green logistics revenue and CO2e avoidance
      - Fleet electrification (BEV, PHEV, HVO, CNG, H2)
      - Facility energy consumption and renewable energy share
      - Workforce ESG: engagement, women in management, LTIFR, training
      - ESG rating benchmarks vs peers (FedEx, UPS, Maersk, etc.)

      Be concise. Use tables for multi-row results. Always include units
      (tonnes, kt, %, USD). Highlight critical metrics prominently.
      When showing emission data, always specify the GHG scope.

    orchestration: >
      For all ESG-related questions use the ESG_Analyst tool. It queries the
      World Delivery ESG semantic view which covers emissions, decarbonization,
      fleet, workforce, GoGreen Plus, ESRS disclosure, and peer benchmarks.

    sample_questions:
      - question: "What are our total GHG emissions by scope for FY2025?"
      - question: "Will we hit our SBTi Scope 1&2 target under the current trajectory?"
      - question: "Compare BAU vs accelerated scenario for Scope 3 emissions through 2030"
      - question: "What is the most cost-effective decarbonization lever?"
      - question: "How much do we need to invest in SAF to close the SBTi gap?"
      - question: "Show the emission forecast for Scope 1&2 under all three scenarios"
      - question: "What is the GoGreen Plus revenue by customer segment?"
      - question: "How many e-vehicles do we have by drive type?"
      - question: "Generate the ESRS E1-6 disclosure table"
      - question: "Give me the 7 steering KPIs for the latest period"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "ESG_Analyst"
        description: >
          Converts natural language ESG questions to SQL against World Delivery's
          ESG data: GHG emissions (scope 1/2/3, by division/mode/fuel), ESRS E1
          disclosure, SBTi target tracking, GoGreen Plus revenue and CO2e avoidance,
          fleet electrification, facility energy, workforce KPIs (engagement, women
          in management, LTIFR, training), and ESG peer benchmarking.

  tool_resources:
    ESG_Analyst:
      semantic_view: "<% db_name %>.ESG.WORLD_DELIVERY_ESG_SV"
      execution_environment:
        type: "warehouse"
        warehouse: "<% wh_name %>"
  $$;


-- =============================================================================
-- SAMPLE VERIFIED QUESTIONS (test these after deployment)
--
-- Act 1 — The Granularity Gap:
--   "What are our total GHG emissions by scope for FY2025?"
--   "Show Scope 1 emissions breakdown by transport mode"
--   "What are the top 5 emission routes for air transport?"
--
-- Act 2 — ESRS E1 Automated Reporting:
--   "Generate the ESRS E1-6 disclosure table"
--   "What are our decarbonization effects by technology?"
--   "Are we on track for our SBTi 2030 targets?"
--
-- Act 3 — Green Revenue Intelligence:
--   "What is the GoGreen Plus revenue by customer segment?"
--   "Which customers had the highest CO2e avoidance through GoGreen Plus?"
--
-- Close — ESG KPI Dashboard:
--   "Give me the 7 steering KPIs for the latest period"
--   "How does World Delivery compare to peers on ESG scores?"
-- =============================================================================

SELECT 'Agent created: WORLD_DELIVERY_ESG_AGENT' AS status;
