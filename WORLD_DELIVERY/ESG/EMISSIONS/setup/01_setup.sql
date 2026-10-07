-- =============================================================================
-- 01_setup.sql — Database, Schema, Warehouse
--
-- Creates the foundational Snowflake objects for the World Delivery ESG demo.
-- All subsequent files assume this context is set.
--
-- Iceberg v3 database: enables BDC share-back via managed Iceberg tables.
--
-- Variables (passed by install.sh / GitHub Actions):
--   <% db_name %>  — target database  (default: WORLD_DELIVERY)
--   <% wh_name %>  — warehouse name   (default: WORLD_DELIVERY_WH)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER('<% wh_name %>')
    WAREHOUSE_SIZE   = 'MEDIUM'
    AUTO_SUSPEND     = 60
    AUTO_RESUME      = TRUE
    COMMENT = 'World Delivery ESG demo warehouse — auto-suspends when idle';

USE WAREHOUSE IDENTIFIER('<% wh_name %>');

CREATE DATABASE IF NOT EXISTS IDENTIFIER('<% db_name %>')
    ICEBERG_VERSION_DEFAULT = 3
    CATALOG = 'SNOWFLAKE'
    ICEBERG_MERGE_ON_READ_BEHAVIOR = 'DISABLED'
    STORAGE_SERIALIZATION_POLICY = 'COMPATIBLE'
    COMMENT = 'World Delivery ESG demo — SAP BDC + Marketplace + Cortex AI';

USE DATABASE IDENTIFIER('<% db_name %>');

CREATE SCHEMA IF NOT EXISTS ESG
    COMMENT = 'ESG / Sustainability analytics — emissions, fleet, workforce, GoGreen Plus';

USE SCHEMA ESG;

SELECT 'Setup complete: database=' || CURRENT_DATABASE()
    || ', schema=' || CURRENT_SCHEMA()
    || ', warehouse=' || CURRENT_WAREHOUSE() AS status;
