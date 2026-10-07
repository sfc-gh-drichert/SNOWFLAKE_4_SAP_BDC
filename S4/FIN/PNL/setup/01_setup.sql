-- =============================================================================
-- 01_setup.sql — Database, Schema, Warehouse
--
-- Creates the foundational Snowflake objects for the R.Daneel PnL demo.
-- All subsequent files assume this context is set.
--
-- Variables (passed by install.sh / GitHub Actions):
--   <% db_name %>  — target database  (default: S4)
--   <% wh_name %>  — warehouse name   (default: S4_FIN_DEMO_WH)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Warehouse — medium size, auto-suspend after 60 seconds idle
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER('<% wh_name %>')
    WAREHOUSE_SIZE   = 'MEDIUM'
    AUTO_SUSPEND     = 60
    AUTO_RESUME      = TRUE
    COMMENT = 'R.Daneel demo warehouse — auto-suspends when idle';

USE WAREHOUSE IDENTIFIER('<% wh_name %>');

-- Database — mirrors SAP system name (S4 = S/4HANA)
CREATE DATABASE IF NOT EXISTS IDENTIFIER('<% db_name %>')
    COMMENT = 'SAP S/4HANA demo data — R.Daneel Inc. and future company datasets';

USE DATABASE IDENTIFIER('<% db_name %>');

-- Schema — FIN mirrors the SAP Finance module
CREATE SCHEMA IF NOT EXISTS FIN
    COMMENT = 'SAP Finance (FI/CO) schema — PnL, AP, AR modules live here';

USE SCHEMA FIN;

SELECT 'Setup complete: database=' || CURRENT_DATABASE()
    || ', schema=' || CURRENT_SCHEMA()
    || ', warehouse=' || CURRENT_WAREHOUSE() AS status;
