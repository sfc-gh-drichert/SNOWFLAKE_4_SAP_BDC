-- =============================================================
-- Confect PetFood — Supply Risk Command Center
-- Streamlit-in-Snowflake Dashboard (Container Runtime)
-- =============================================================
-- Prerequisite: run 01_confect_petfood_demo_sc_risk_ice.sql first.
--
-- Deployment:
--   1. Upload streamlit_app.py to the stage (GH Actions does this)
--   2. Run this file with: snow sql -f <this_file> --enable-templating NONE
--
-- No pyproject.toml needed — the container runtime ships with
-- streamlit, pandas, altair, snowflake-connector pre-installed.
-- No EAI needed when there is no dependency file.
-- =============================================================

USE DATABASE CONFECT_PETFOOD_DEMO;
USE SCHEMA SC_RISK_DEMO;
USE WAREHOUSE CONFECT_PETFOOD_WH;

-- Stage for Streamlit source files
CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Stage for Confect PetFood Streamlit dashboard files';

-- Create the Streamlit app (container runtime — modern Streamlit, no EAI needed)
CREATE OR REPLACE STREAMLIT SC_RISK_DASHBOARD
  FROM '@CONFECT_PETFOOD_DEMO.SC_RISK_DEMO.STREAMLIT_STAGE'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = CONFECT_PETFOOD_WH
  RUNTIME_NAME = 'SYSTEM$ST_CONTAINER_RUNTIME_PY3_11'
  TITLE = 'Supply Risk Command Center'
  COMMENT = 'Confect PetFood supply chain risk intelligence dashboard';

-- Make the app live
ALTER STREAMLIT SC_RISK_DASHBOARD ADD LIVE VERSION FROM LAST;

-- Grant access
GRANT USAGE ON STREAMLIT SC_RISK_DASHBOARD TO ROLE PUBLIC;
