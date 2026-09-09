-- =============================================================================
-- teardown.sql — Remove All BSH PnL Demo Objects
--
-- Drops all objects created by the BSH PnL demo setup (01-08 files).
-- Does NOT drop the S4 database or FIN schema if they contain other objects.
--
-- SAFETY: This script will print a warning and require confirmation before
-- proceeding if run against a database with more than just the BSH demo objects.
--
-- Usage:
--   snow sql -f runbooks/teardown.sql \
--     --connection EU_DEMO47 \
--     --variable db_name=S4 \
--     --variable wh_name=BSH_DEMO_WH
--   -- or --
--   make teardown
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

SELECT '⚠  TEARDOWN: This will drop all BSH PnL demo objects.' AS warning,
       'Database: <% db_name %>  |  Schema: <% db_name %>.FIN'       AS target,
       'Review the DROP statements below before proceeding.'    AS action;

-- ─────────────────────────────────────────────────────────────────────────────
-- Drop AI / analytical layer (created last, dropped first)
-- ─────────────────────────────────────────────────────────────────────────────
DROP CORTEX AGENT   IF EXISTS BSH_PNL_AGENT;
DROP SEMANTIC VIEW  IF EXISTS BSH_PNL_ANALYTICS_SV;
DROP CORTEX SEARCH SERVICE IF EXISTS BSH_PNL_SEARCH_SVC;

-- ─────────────────────────────────────────────────────────────────────────────
-- Remove Row Access Policy from fact table, then drop the policy
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS S3_FINANCE_PNL
    DROP ROW ACCESS POLICY PNL_CLIENT_ISOLATION_POLICY;

DROP ROW ACCESS POLICY IF EXISTS PNL_CLIENT_ISOLATION_POLICY;

-- ─────────────────────────────────────────────────────────────────────────────
-- Drop tables
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS S3_FINANCE_PNL;
DROP TABLE IF EXISTS BSH_DOCUMENTS;
DROP TABLE IF EXISTS ROLE_ACCESS_MAPPING;
DROP TABLE IF EXISTS DIM_GL_ACCOUNT;
DROP TABLE IF EXISTS DIM_PRODUCT;
DROP TABLE IF EXISTS DIM_CUSTOMER;
DROP TABLE IF EXISTS DIM_COMPANY;
DROP TABLE IF EXISTS DIM_PLANT;

-- ─────────────────────────────────────────────────────────────────────────────
-- Revoke grants and drop roles
-- ─────────────────────────────────────────────────────────────────────────────
REVOKE ROLE BSH_EUROPE_DEMO_ROLE FROM ROLE BSH_DEMO_ROLE;
REVOKE ROLE BSH_NA_DEMO_ROLE     FROM ROLE BSH_DEMO_ROLE;
REVOKE ROLE BSH_APAC_DEMO_ROLE   FROM ROLE BSH_DEMO_ROLE;
REVOKE ROLE BSH_DEMO_ROLE        FROM ROLE BSH_DEMO_GLOBAL_ROLE;
REVOKE ROLE BSH_DEMO_GLOBAL_ROLE FROM ROLE SYSADMIN;

DROP ROLE IF EXISTS BSH_DEMO_GLOBAL_ROLE;
DROP ROLE IF EXISTS BSH_DEMO_ROLE;
DROP ROLE IF EXISTS BSH_EUROPE_DEMO_ROLE;
DROP ROLE IF EXISTS BSH_NA_DEMO_ROLE;
DROP ROLE IF EXISTS BSH_APAC_DEMO_ROLE;

-- ─────────────────────────────────────────────────────────────────────────────
-- Optionally drop the warehouse (commented out — may be shared)
-- ─────────────────────────────────────────────────────────────────────────────
-- DROP WAREHOUSE IF EXISTS IDENTIFIER('<% wh_name %>');

SELECT 'Teardown complete. All BSH PnL demo objects have been removed.' AS status;
