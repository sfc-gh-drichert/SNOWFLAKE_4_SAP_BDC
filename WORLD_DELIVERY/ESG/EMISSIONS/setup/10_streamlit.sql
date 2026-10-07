-- =============================================================================
-- 10_streamlit.sql — Deploy Streamlit ESG Dashboard
--
-- Creates the internal stage and STREAMLIT object.
-- The Python source file (streamlit_app.py) and environment.yml must be
-- uploaded to the stage BEFORE running this script:
--
--   snow stage put WORLD_DELIVERY/ESG/EMISSIONS/streamlit_app.py \
--     @<db>.ESG.WORLD_DELIVERY_ESG_STG --overwrite
--   snow stage put WORLD_DELIVERY/ESG/EMISSIONS/environment.yml \
--     @<db>.ESG.WORLD_DELIVERY_ESG_STG --overwrite
--
-- The GitHub Actions workflow handles this automatically.
--
-- Variables: <% db_name %>, <% wh_name %>
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE IDENTIFIER('<% db_name %>');
USE SCHEMA ESG;

CREATE STAGE IF NOT EXISTS WORLD_DELIVERY_ESG_STG
    COMMENT = 'Streamlit app source code and dependencies for ESG dashboard';

CREATE OR REPLACE STREAMLIT WORLD_DELIVERY_ESG_DASHBOARD
    ROOT_LOCATION   = '@WORLD_DELIVERY_ESG_STG'
    MAIN_FILE       = 'streamlit_app.py'
    QUERY_WAREHOUSE = IDENTIFIER('<% wh_name %>')
    COMMENT         = 'World Delivery ESG CxO Dashboard — emissions, fleet, GoGreen Plus, workforce, agent chat';

SELECT 'Streamlit dashboard created: WORLD_DELIVERY_ESG_DASHBOARD' AS status;
