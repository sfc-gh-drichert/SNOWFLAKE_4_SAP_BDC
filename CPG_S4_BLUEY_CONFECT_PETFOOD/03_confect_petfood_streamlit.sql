-- =============================================================
-- Confect PetFood — Supply Risk Command Center
-- Streamlit-in-Snowflake Dashboard
-- =============================================================
-- Prerequisite: run 01_confect_petfood_demo_sc_risk_ice.sql first
-- (tables, views, and data must exist).
--
-- Deployment:
--   1. Upload streamlit/streamlit_app.py to the stage (GH Actions does this)
--   2. Run this file with: snow sql -f <this_file> --enable-templating NONE
-- =============================================================

USE DATABASE CONFECT_PETFOOD_DEMO;
USE SCHEMA SC_RISK_DEMO;
USE WAREHOUSE CONFECT_PETFOOD_WH;

-- Stage for Streamlit source files
CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Stage for Confect PetFood Streamlit dashboard files';

-- The Python file must be uploaded to the stage before this step.
-- GH Actions workflow does: snow stage copy streamlit/streamlit_app.py @STREAMLIT_STAGE/

-- Create the Streamlit app (warehouse runtime — no compute pool needed)
CREATE OR REPLACE STREAMLIT SC_RISK_DASHBOARD
  FROM '@CONFECT_PETFOOD_DEMO.SC_RISK_DEMO.STREAMLIT_STAGE'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = CONFECT_PETFOOD_WH
  TITLE = 'Supply Risk Command Center'
  COMMENT = 'Confect PetFood supply chain risk intelligence dashboard — 5-page SiS app';

-- Make the app live (required after CREATE STREAMLIT)
ALTER STREAMLIT SC_RISK_DASHBOARD ADD LIVE VERSION FROM LAST;

-- Grant access
GRANT USAGE ON STREAMLIT SC_RISK_DASHBOARD TO ROLE PUBLIC;
