-- =============================================================================
-- 11_verify.sql — Verification queries for World Delivery ESG demo
--
-- Run this AFTER all other setup scripts to confirm the deployment is correct.
-- Checks: row counts, view outputs, key metric spot-checks.
--
-- Variables: <% db_name %>, <% wh_name %>
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE IDENTIFIER('<% db_name %>');
USE SCHEMA ESG;

-- =============================================================================
-- 1. Row count verification
-- =============================================================================
SELECT 'COMPANYCODE' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM COMPANYCODE
UNION ALL SELECT 'COSTCENTER', COUNT(*) FROM COSTCENTER
UNION ALL SELECT 'PLANT', COUNT(*) FROM PLANT
UNION ALL SELECT 'GL_LINE_ITEMS', COUNT(*) FROM GENERALLEDGERACCOUNTLINEITEM
UNION ALL SELECT 'SHIPMENT_EMISSIONS', COUNT(*) FROM Z_SHIPMENT_EMISSIONS
UNION ALL SELECT 'FACILITY_ENERGY', COUNT(*) FROM Z_FACILITY_ENERGY
UNION ALL SELECT 'FLEET_VEHICLE', COUNT(*) FROM Z_FLEET_VEHICLE
UNION ALL SELECT 'FLEET_FUEL_LOG', COUNT(*) FROM Z_FLEET_FUEL_LOG
UNION ALL SELECT 'GOGREEN_PLUS_ORDER', COUNT(*) FROM Z_GOGREEN_PLUS_ORDER
UNION ALL SELECT 'SF_CORE_WORKFORCE', COUNT(*) FROM SF_CORE_WORKFORCE
UNION ALL SELECT 'SF_HEALTH_SAFETY', COUNT(*) FROM SF_HEALTH_SAFETY
UNION ALL SELECT 'EXT_EMISSION_FACTORS', COUNT(*) FROM EXT_EMISSION_FACTORS
UNION ALL SELECT 'EXT_ESG_SCORES', COUNT(*) FROM EXT_ESG_SCORES
UNION ALL SELECT 'EXT_CLIMATE_RISK', COUNT(*) FROM EXT_CLIMATE_RISK
UNION ALL SELECT 'EMISSION_FORECAST', COUNT(*) FROM Z_EMISSION_FORECAST
UNION ALL SELECT 'DECARB_LEVERS', COUNT(*) FROM Z_DECARB_LEVERS;

-- =============================================================================
-- 2. View output verification
-- =============================================================================
SELECT 'V_GHG_EMISSIONS_SUMMARY' AS VIEW_NAME, COUNT(*) AS ROWS FROM V_GHG_EMISSIONS_SUMMARY
UNION ALL SELECT 'V_ESRS_E1_DISCLOSURE', COUNT(*) FROM V_ESRS_E1_DISCLOSURE
UNION ALL SELECT 'V_DECARB_PROGRESS', COUNT(*) FROM V_DECARB_PROGRESS
UNION ALL SELECT 'V_GOGREEN_REVENUE', COUNT(*) FROM V_GOGREEN_REVENUE
UNION ALL SELECT 'V_ESG_KPI_DASHBOARD', COUNT(*) FROM V_ESG_KPI_DASHBOARD
UNION ALL SELECT 'V_EMISSION_FORECAST', COUNT(*) FROM V_EMISSION_FORECAST
UNION ALL SELECT 'V_DECARB_LEVER_ANALYSIS', COUNT(*) FROM V_DECARB_LEVER_ANALYSIS;

-- =============================================================================
-- 3. Key metric spot-checks
-- =============================================================================

-- Total emissions should exist
SELECT 'Total emissions (tonnes)' AS CHECK_NAME,
       SUM(TOTAL_CO2E_TONNES) AS VALUE
FROM V_GHG_EMISSIONS_SUMMARY;

-- ESRS disclosure should have scope data
SELECT * FROM V_ESRS_E1_DISCLOSURE ORDER BY REPORTING_YEAR DESC LIMIT 2;

-- SBTi progress should show reduction percentages
SELECT * FROM V_DECARB_PROGRESS ORDER BY REPORTING_YEAR DESC LIMIT 2;

-- KPI dashboard should return 1 row with all 7 KPIs
SELECT * FROM V_ESG_KPI_DASHBOARD;

-- Fleet should have BEV vehicles
SELECT DRIVETYPE, COUNT(*) AS CNT
FROM Z_FLEET_VEHICLE WHERE ISACTIVE = TRUE
GROUP BY 1 ORDER BY CNT DESC;

-- GoGreen Plus should have revenue
SELECT SUM(GREEN_PREMIUM_USD) AS TOTAL_GREEN_PREMIUM,
       SUM(CO2E_AVOIDED_TONNES) AS TOTAL_CO2E_AVOIDED
FROM V_GOGREEN_REVENUE;

-- =============================================================================
-- 4. Semantic view exists
-- =============================================================================
SHOW SEMANTIC VIEWS LIKE 'WORLD_DELIVERY_ESG_SV' IN SCHEMA ESG;

-- =============================================================================
-- 5. Agent exists
-- =============================================================================
SHOW AGENTS LIKE 'WORLD_DELIVERY_ESG_AGENT' IN SCHEMA ESG;

SELECT 'Verification complete' AS status;
