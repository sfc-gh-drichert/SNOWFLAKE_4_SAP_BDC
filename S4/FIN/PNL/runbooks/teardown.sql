-- ==============================================================================
-- teardown.sql - Remove All BSH PnL Demo Objects
--
-- Drops all objects created by the BSH PnL demo setup (files 01-09).
-- Does NOT drop the S4 database or FIN schema in case they contain other demos.
--
-- Usage:
--   snow sql -f runbooks/teardown.sql \
--     --connection my_snowflake \
--     --variable db_name=S4 \
--     --variable wh_name=BSH_DEMO_WH
--   -- or --
--   make teardown
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

SELECT 'TEARDOWN: This will drop all BSH PnL demo objects.' AS warning,
       '<% db_name %>.FIN' AS target,
       'Review and confirm before running.' AS action;

-- ==============================================================================
-- 1. AI / analytical layer (created last, drop first)
-- ==============================================================================
DROP AGENT              IF EXISTS BSH_PNL_AGENT;
DROP SEMANTIC VIEW      IF EXISTS BSH_PNL_ANALYTICS_SV;
DROP CORTEX SEARCH SERVICE IF EXISTS BSH_PNL_SEARCH_SVC;

-- ==============================================================================
-- 2. Row Access Policy
-- ==============================================================================
ALTER TABLE IF EXISTS S3_FINANCE_PNL
    DROP ROW ACCESS POLICY PNL_CLIENT_ISOLATION_POLICY;

DROP ROW ACCESS POLICY IF EXISTS PNL_CLIENT_ISOLATION_POLICY;

-- ==============================================================================
-- 3. Tables
-- ==============================================================================
DROP TABLE IF EXISTS S3_FINANCE_PNL;
DROP TABLE IF EXISTS BSH_DOCUMENTS;
DROP TABLE IF EXISTS ROLE_ACCESS_MAPPING;
DROP TABLE IF EXISTS DIM_GL_ACCOUNT;
DROP TABLE IF EXISTS DIM_PRODUCT;
DROP TABLE IF EXISTS DIM_CUSTOMER;
DROP TABLE IF EXISTS DIM_COMPANY;
DROP TABLE IF EXISTS DIM_PLANT;

-- ==============================================================================
-- 4. Roles
-- DROP ROLE removes all grants to/from that role automatically.
-- No REVOKE statements needed (and REVOKE has no IF EXISTS guard anyway).
-- ==============================================================================
DROP ROLE IF EXISTS BSH_DEMO_GLOBAL_ROLE;
DROP ROLE IF EXISTS BSH_DEMO_ROLE;
DROP ROLE IF EXISTS BSH_EUROPE_DEMO_ROLE;
DROP ROLE IF EXISTS BSH_NA_DEMO_ROLE;
DROP ROLE IF EXISTS BSH_APAC_DEMO_ROLE;
DROP ROLE IF EXISTS BSH_DATA_DEPLOY_ROLE;
-- Note: BSH_GITHUB_ACTIONS user is NOT dropped — it may be used for other demos.

-- ==============================================================================
-- 5. Warehouse (commented out — may be shared across demos)
-- Uncomment if this warehouse is BSH-specific and you want to remove it.
-- ==============================================================================
-- DROP WAREHOUSE IF EXISTS IDENTIFIER('<% wh_name %>');

SELECT 'Teardown complete. All BSH PnL demo objects have been removed.' AS status;
