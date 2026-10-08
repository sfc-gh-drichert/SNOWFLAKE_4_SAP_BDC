-- =============================================================================
-- 07_views.sql — Analytics Views
--
-- These 5 views synthesize across all data layers — the intelligence that
-- doesn't exist in any single source system (TM1, BW, SAP, Finder).
--
-- V_GHG_EMISSIONS_SUMMARY   — Scope 1/2/3 by division, transport mode
-- V_ESRS_E1_DISCLOSURE       — ESRS E1-6 formatted disclosure table
-- V_DECARB_PROGRESS          — SBTi target tracking with trajectory
-- V_GOGREEN_REVENUE          — Green logistics revenue attribution
-- V_ESG_KPI_DASHBOARD        — 7 steering-relevant nonfinancial KPIs
--
-- Variables: <% db_name %>, <% wh_name %>
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE IDENTIFIER('<% db_name %>');
USE SCHEMA ESG;

-- =============================================================================
-- V_GHG_EMISSIONS_SUMMARY
-- Aggregates shipment, fleet, and facility emissions into a unified view.
-- Enables drill-down from group total → division → transport mode → route.
-- =============================================================================

CREATE OR REPLACE VIEW V_GHG_EMISSIONS_SUMMARY AS
WITH shipment_emissions AS (
    SELECT
        YEAR(SHIPMENTDATE)  AS REPORTING_YEAR,
        DIVISION,
        TRANSPORTMODE,
        EMISSIONSCOPE       AS SCOPE,
        CARRIERTYPE,
        FUELTYPEUSED,
        ISGOGREENPLUSORDER,
        COUNT(*)            AS SHIPMENT_COUNT,
        SUM(CO2EKG)         AS TOTAL_CO2E_KG,
        SUM(CO2EKG)/1000    AS TOTAL_CO2E_TONNES,
        SUM(DISTANCEKM)     AS TOTAL_DISTANCE_KM,
        SUM(WEIGHTKG)       AS TOTAL_WEIGHT_KG,
        AVG(PRIMARYDATAPCT) AS AVG_PRIMARY_DATA_PCT
    FROM Z_SHIPMENT_EMISSIONS
    GROUP BY 1,2,3,4,5,6,7
),
facility_emissions AS (
    SELECT
        YEAR(REPORTINGMONTH) AS REPORTING_YEAR,
        p.DIVISION,
        'BUILDINGS' AS TRANSPORTMODE,
        fe.EMISSIONSCOPE AS SCOPE,
        'OWN_FACILITY' AS CARRIERTYPE,
        fe.ENERGYSOURCETYPE AS FUELTYPEUSED,
        FALSE AS ISGOGREENPLUSORDER,
        COUNT(*) AS SHIPMENT_COUNT,
        SUM(fe.CO2EKG) AS TOTAL_CO2E_KG,
        SUM(fe.CO2EKG)/1000 AS TOTAL_CO2E_TONNES,
        0 AS TOTAL_DISTANCE_KM,
        0 AS TOTAL_WEIGHT_KG,
        100.0 AS AVG_PRIMARY_DATA_PCT
    FROM Z_FACILITY_ENERGY fe
    JOIN PLANT p ON p.PLANT = fe.PLANT
    WHERE fe.CO2EKG > 0
    GROUP BY 1,2,4,6
)
SELECT * FROM shipment_emissions
UNION ALL
SELECT * FROM facility_emissions;


-- =============================================================================
-- V_ESRS_E1_DISCLOSURE
-- Pre-formatted ESRS E1-6 GHG disclosure table structure.
-- Matches the structure on page 86 of DHL's 2025 Annual Report.
-- =============================================================================

CREATE OR REPLACE VIEW V_ESRS_E1_DISCLOSURE AS
WITH scope1 AS (
    SELECT
        REPORTING_YEAR,
        SUM(TOTAL_CO2E_TONNES) AS SCOPE1_TONNES
    FROM V_GHG_EMISSIONS_SUMMARY
    WHERE SCOPE = '1'
    GROUP BY REPORTING_YEAR
),
scope2 AS (
    SELECT
        REPORTING_YEAR,
        SUM(TOTAL_CO2E_TONNES) AS SCOPE2_MARKET_TONNES
    FROM V_GHG_EMISSIONS_SUMMARY
    WHERE SCOPE = '2'
    GROUP BY REPORTING_YEAR
),
scope3 AS (
    SELECT
        REPORTING_YEAR,
        SUM(TOTAL_CO2E_TONNES) AS SCOPE3_TONNES
    FROM V_GHG_EMISSIONS_SUMMARY
    WHERE SCOPE = '3'
    GROUP BY REPORTING_YEAR
),
all_years AS (
    SELECT DISTINCT REPORTING_YEAR FROM V_GHG_EMISSIONS_SUMMARY
)
SELECT
    y.REPORTING_YEAR,
    'GHG Emissions' AS DISCLOSURE_CATEGORY,
    COALESCE(s1.SCOPE1_TONNES, 0) AS SCOPE_1_TONNES,
    COALESCE(s2.SCOPE2_MARKET_TONNES, 0) AS SCOPE_2_MARKET_BASED_TONNES,
    COALESCE(s1.SCOPE1_TONNES, 0) + COALESCE(s2.SCOPE2_MARKET_TONNES, 0) AS SCOPE_1_AND_2_TOTAL_TONNES,
    COALESCE(s3.SCOPE3_TONNES, 0) AS SCOPE_3_TOTAL_TONNES,
    COALESCE(s1.SCOPE1_TONNES, 0) + COALESCE(s2.SCOPE2_MARKET_TONNES, 0) + COALESCE(s3.SCOPE3_TONNES, 0) AS TOTAL_GHG_TONNES,
    ROUND(COALESCE(s1.SCOPE1_TONNES, 0) / NULLIF(COALESCE(s1.SCOPE1_TONNES, 0) + COALESCE(s2.SCOPE2_MARKET_TONNES, 0) + COALESCE(s3.SCOPE3_TONNES, 0), 0) * 100, 1) AS SCOPE_1_PCT,
    ROUND(COALESCE(s3.SCOPE3_TONNES, 0) / NULLIF(COALESCE(s1.SCOPE1_TONNES, 0) + COALESCE(s2.SCOPE2_MARKET_TONNES, 0) + COALESCE(s3.SCOPE3_TONNES, 0), 0) * 100, 1) AS SCOPE_3_PCT
FROM all_years y
LEFT JOIN scope1 s1 ON s1.REPORTING_YEAR = y.REPORTING_YEAR
LEFT JOIN scope2 s2 ON s2.REPORTING_YEAR = y.REPORTING_YEAR
LEFT JOIN scope3 s3 ON s3.REPORTING_YEAR = y.REPORTING_YEAR;


-- =============================================================================
-- V_DECARB_PROGRESS
-- Tracks progress against SBTi targets:
--   Scope 1and2: -42% by 2030 from 2020 baseline
--   Scope 3:   -25% by 2030 from 2020 baseline
-- =============================================================================

CREATE OR REPLACE VIEW V_DECARB_PROGRESS AS
WITH yearly_totals AS (
    SELECT
        REPORTING_YEAR,
        SUM(CASE WHEN SCOPE IN ('1','2') THEN TOTAL_CO2E_TONNES ELSE 0 END) AS SCOPE_1_2_TONNES,
        SUM(CASE WHEN SCOPE = '3' THEN TOTAL_CO2E_TONNES ELSE 0 END) AS SCOPE_3_TONNES,
        SUM(TOTAL_CO2E_TONNES) AS TOTAL_TONNES
    FROM V_GHG_EMISSIONS_SUMMARY
    GROUP BY REPORTING_YEAR
),
baseline AS (
    SELECT
        SCOPE_1_2_TONNES AS BASELINE_SCOPE_1_2,
        SCOPE_3_TONNES AS BASELINE_SCOPE_3
    FROM yearly_totals
    WHERE REPORTING_YEAR = (SELECT MIN(REPORTING_YEAR) FROM yearly_totals)
)
SELECT
    yt.REPORTING_YEAR,
    yt.SCOPE_1_2_TONNES,
    yt.SCOPE_3_TONNES,
    yt.TOTAL_TONNES,
    b.BASELINE_SCOPE_1_2,
    b.BASELINE_SCOPE_3,
    ROUND(b.BASELINE_SCOPE_1_2 * 0.58, 0)     AS TARGET_2030_SCOPE_1_2,
    ROUND(b.BASELINE_SCOPE_3 * 0.75, 0)        AS TARGET_2030_SCOPE_3,
    ROUND((1 - yt.SCOPE_1_2_TONNES / NULLIF(b.BASELINE_SCOPE_1_2, 0)) * 100, 1) AS REDUCTION_PCT_SCOPE_1_2,
    ROUND((1 - yt.SCOPE_3_TONNES / NULLIF(b.BASELINE_SCOPE_3, 0)) * 100, 1)     AS REDUCTION_PCT_SCOPE_3,
    42.0                                        AS TARGET_REDUCTION_PCT_SCOPE_1_2,
    25.0                                        AS TARGET_REDUCTION_PCT_SCOPE_3,
    CASE
        WHEN (1 - yt.SCOPE_1_2_TONNES / NULLIF(b.BASELINE_SCOPE_1_2, 0)) * 100
             >= 42.0 * (yt.REPORTING_YEAR - (SELECT MIN(REPORTING_YEAR) FROM yearly_totals)) / 10.0
        THEN 'ON_TRACK' ELSE 'AT_RISK'
    END AS STATUS_SCOPE_1_2,
    CASE
        WHEN (1 - yt.SCOPE_3_TONNES / NULLIF(b.BASELINE_SCOPE_3, 0)) * 100
             >= 25.0 * (yt.REPORTING_YEAR - (SELECT MIN(REPORTING_YEAR) FROM yearly_totals)) / 10.0
        THEN 'ON_TRACK' ELSE 'AT_RISK'
    END AS STATUS_SCOPE_3
FROM yearly_totals yt
CROSS JOIN baseline b;


-- =============================================================================
-- V_GOGREEN_REVENUE
-- Connects green logistics product (GoGreen Plus) to measurable sustainability
-- outcomes: revenue, CO2e avoided, SAF deployed, customer impact.
-- =============================================================================

CREATE OR REPLACE VIEW V_GOGREEN_REVENUE AS
SELECT
    YEAR(ORDERDATE)     AS REPORTING_YEAR,
    QUARTER(ORDERDATE)  AS REPORTING_QUARTER,
    CUSTOMERNAME,
    CUSTOMERSEGMENT,
    DIVISION,
    DECARBTECHNOLOGY,
    COUNT(*)            AS ORDER_COUNT,
    SUM(PREMIUMUSD)     AS GREEN_PREMIUM_USD,
    SUM(BASESHIPMENTCOSTUSD) AS BASE_REVENUE_USD,
    SUM(PREMIUMUSD) + SUM(BASESHIPMENTCOSTUSD) AS TOTAL_REVENUE_USD,
    ROUND(SUM(PREMIUMUSD) / NULLIF(SUM(BASESHIPMENTCOSTUSD), 0) * 100, 1) AS GREEN_PREMIUM_PCT,
    SUM(CO2EAVOIDEDKG)  AS CO2E_AVOIDED_KG,
    SUM(CO2EAVOIDEDKG)/1000 AS CO2E_AVOIDED_TONNES,
    SUM(SAFQUANTITYKG)  AS SAF_DEPLOYED_KG,
    SUM(SAFQUANTITYKG)/1000 AS SAF_DEPLOYED_TONNES,
    AVG(SAFBLENDINGPCT) AS AVG_SAF_BLENDING_PCT,
    COUNT(DISTINCT CERTIFICATEID) AS CERTIFICATES_ISSUED
FROM Z_GOGREEN_PLUS_ORDER
GROUP BY 1,2,3,4,5,6;


-- =============================================================================
-- V_ESG_KPI_DASHBOARD
-- The 7 steering-relevant nonfinancial KPIs aligned with Strategy 2030.
-- Designed for the executive overview page of the Streamlit dashboard.
-- =============================================================================

CREATE OR REPLACE VIEW V_ESG_KPI_DASHBOARD AS
WITH latest_year_emissions AS (
    SELECT
        REPORTING_YEAR,
        SUM(TOTAL_CO2E_TONNES) / 1000000 AS TOTAL_GHG_MT
    FROM V_GHG_EMISSIONS_SUMMARY
    WHERE REPORTING_YEAR = (SELECT MAX(REPORTING_YEAR) FROM V_GHG_EMISSIONS_SUMMARY)
    GROUP BY REPORTING_YEAR
),
decarb_effects AS (
    SELECT
        REPORTING_YEAR,
        SUM(CASE WHEN FUELTYPEUSED IN ('SAF','HVO','BEV_ELEC','ELECTRIC_RAIL','H2','CNG') THEN TOTAL_CO2E_TONNES ELSE 0 END) AS AVOIDED_TONNES
    FROM V_GHG_EMISSIONS_SUMMARY
    WHERE REPORTING_YEAR = (SELECT MAX(REPORTING_YEAR) FROM V_GHG_EMISSIONS_SUMMARY)
    GROUP BY REPORTING_YEAR
),
latest_workforce AS (
    SELECT
        AVG(ENGAGEMENTSCORE) AS AVG_ENGAGEMENT,
        SUM(HEADCOUNT * WOMENINMANAGEMENTPCT / 100.0) / NULLIF(SUM(HEADCOUNT), 0) * 100 AS WIM_PCT,
        AVG(COMPLIANCETRAININGPCT) AS COMPLIANCE_PCT
    FROM SF_CORE_WORKFORCE
    WHERE QUARTER = (SELECT MAX(QUARTER) FROM SF_CORE_WORKFORCE)
),
latest_safety AS (
    SELECT
        SUM(REPORTABLEINJURIES * 200000.0) / NULLIF(SUM(WORKHOURSM * 1000000), 0) AS OVERALL_LTIFR
    FROM SF_HEALTH_SAFETY
    WHERE QUARTER = (SELECT MAX(QUARTER) FROM SF_HEALTH_SAFETY)
)
SELECT
    e.REPORTING_YEAR,
    ROUND(e.TOTAL_GHG_MT, 2) AS KPI_1_GHG_EMISSIONS_MT,
    ROUND(d.AVOIDED_TONNES / 1000, 1) AS KPI_2_DECARB_EFFECTS_KT,
    ROUND(w.AVG_ENGAGEMENT, 1) AS KPI_3_EMPLOYEE_ENGAGEMENT_PCT,
    ROUND(w.WIM_PCT, 1) AS KPI_4_WOMEN_IN_MGMT_PCT,
    ROUND(s.OVERALL_LTIFR, 1) AS KPI_5_LTIFR,
    ROUND(w.COMPLIANCE_PCT, 1) AS KPI_6_COMPLIANCE_TRAINING_PCT,
    'A-' AS KPI_7_CYBERSECURITY_RATING
FROM latest_year_emissions e
CROSS JOIN decarb_effects d
CROSS JOIN latest_workforce w
CROSS JOIN latest_safety s;


-- =============================================================================
-- V_EMISSION_FORECAST
-- Combines historical actuals with future scenario projections.
-- Enables the CxO to see: "Where are we heading? Will we hit 2030?"
-- =============================================================================

CREATE OR REPLACE VIEW V_EMISSION_FORECAST AS
SELECT
    REPORTING_YEAR,
    SCOPE_GROUP,
    SCENARIO,
    TOTAL_CO2E_TONNES,
    TOTAL_CO2E_TONNES / 1000000.0 AS TOTAL_CO2E_MT,
    REDUCTION_FROM_BASE_PCT,
    IS_FORECAST,
    KEY_ASSUMPTIONS,
    CASE SCOPE_GROUP
        WHEN 'SCOPE_1_2' THEN 42.0
        WHEN 'SCOPE_3'   THEN 25.0
    END AS SBTI_TARGET_REDUCTION_PCT,
    CASE SCOPE_GROUP
        WHEN 'SCOPE_1_2' THEN 4360000
        WHEN 'SCOPE_3'   THEN 24530000
    END AS SBTI_TARGET_2030_TONNES,
    CASE
        WHEN IS_FORECAST = FALSE THEN 'ACTUAL'
        WHEN SCENARIO = 'SBTI_REQUIRED' THEN 'TARGET_PATH'
        WHEN TOTAL_CO2E_TONNES <= (CASE SCOPE_GROUP WHEN 'SCOPE_1_2' THEN 4360000 ELSE 24530000 END)
            THEN 'MEETS_TARGET'
        ELSE 'MISSES_TARGET'
    END AS TARGET_STATUS
FROM Z_EMISSION_FORECAST;


-- =============================================================================
-- V_DECARB_LEVER_ANALYSIS
-- Marginal abatement cost curve: which levers deliver the most CO2e reduction
-- per EUR invested, by scenario and year.
-- =============================================================================

CREATE OR REPLACE VIEW V_DECARB_LEVER_ANALYSIS AS
SELECT
    REPORTING_YEAR,
    SCENARIO,
    LEVER_NAME,
    CO2E_REDUCTION_KT,
    INVESTMENT_MEUR,
    COST_PER_TONNE_EUR,
    READINESS,
    SUM(CO2E_REDUCTION_KT) OVER (PARTITION BY SCENARIO, REPORTING_YEAR ORDER BY COST_PER_TONNE_EUR ROWS UNBOUNDED PRECEDING) AS CUMULATIVE_REDUCTION_KT,
    SUM(INVESTMENT_MEUR) OVER (PARTITION BY SCENARIO, REPORTING_YEAR ORDER BY COST_PER_TONNE_EUR ROWS UNBOUNDED PRECEDING) AS CUMULATIVE_INVESTMENT_MEUR
FROM Z_DECARB_LEVERS;


SELECT 'Analytics views created: V_GHG_EMISSIONS_SUMMARY, V_ESRS_E1_DISCLOSURE, V_DECARB_PROGRESS, V_GOGREEN_REVENUE, V_ESG_KPI_DASHBOARD, V_EMISSION_FORECAST, V_DECARB_LEVER_ANALYSIS' AS status;
