-- =============================================================================
-- 08_semantic_view.sql — World Delivery ESG Semantic View
--
-- Built on the 5 analytics views. Enables Cortex Analyst to answer
-- natural language ESG questions across emissions, decarb, fleet,
-- GoGreen Plus, and workforce KPIs.
--
-- DDL structure follows S4/FIN/PNL/setup/07_semantic_view.sql pattern:
--   TABLES (...), DIMENSIONS (...), METRICS (...) as top-level clauses.
--
-- Variables: <% db_name %>, <% wh_name %>
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA ESG;

CREATE OR REPLACE SEMANTIC VIEW WORLD_DELIVERY_ESG_SV

  TABLES (
    -- Core emissions summary
    GHG AS <% db_name %>.ESG.V_GHG_EMISSIONS_SUMMARY
      PRIMARY KEY (REPORTING_YEAR, DIVISION, TRANSPORTMODE, SCOPE, FUELTYPEUSED)
      COMMENT = 'GHG emissions aggregated by year, division, transport mode, scope, and fuel type. Central table for emissions analysis.',

    -- ESRS disclosure
    ESRS AS <% db_name %>.ESG.V_ESRS_E1_DISCLOSURE
      PRIMARY KEY (REPORTING_YEAR)
      COMMENT = 'Pre-formatted ESRS E1-6 GHG disclosure table. Scope 1, 2 (market-based), and 3 totals by year.',

    -- Decarbonization progress
    DECARB AS <% db_name %>.ESG.V_DECARB_PROGRESS
      PRIMARY KEY (REPORTING_YEAR)
      COMMENT = 'SBTi 2030 target tracking. Shows baseline, current, and target for Scope 1&2 (-42%) and Scope 3 (-25%).',

    -- GoGreen Plus commercial
    GOGREEN AS <% db_name %>.ESG.V_GOGREEN_REVENUE
      PRIMARY KEY (REPORTING_YEAR, REPORTING_QUARTER, CUSTOMERNAME, DECARBTECHNOLOGY)
      COMMENT = 'GoGreen Plus green logistics product performance. Revenue, CO2e avoided, SAF deployed, by customer and technology.',

    -- 7 KPIs
    KPIS AS <% db_name %>.ESG.V_ESG_KPI_DASHBOARD
      PRIMARY KEY (REPORTING_YEAR)
      COMMENT = 'The 7 steering-relevant nonfinancial KPIs: GHG emissions, decarb effects, engagement, women in management, LTIFR, compliance training, cybersecurity rating.',

    -- Shipment-level detail
    SHIPMENTS AS <% db_name %>.ESG.Z_SHIPMENT_EMISSIONS
      PRIMARY KEY (SHIPMENTID)
      COMMENT = 'Individual shipment emission records. Enables drill-down from aggregate to shipment level — the granularity gap.',

    -- Fleet master
    FLEET AS <% db_name %>.ESG.Z_FLEET_VEHICLE
      PRIMARY KEY (VEHICLEID)
      COMMENT = 'Fleet vehicle master data. Drive types: BEV, PHEV, HVO, CNG, H2, DIESEL. World Delivery operates 1000 sample vehicles (scaled from 120k+ real fleet).',

    -- Facility energy
    ENERGY AS <% db_name %>.ESG.Z_FACILITY_ENERGY
      PRIMARY KEY (FACILITYENERGYID)
      COMMENT = 'Monthly facility energy consumption by source type. Enables Scope 1 (onsite gen) and Scope 2 (purchased) analysis.',

    -- GoGreen Plus orders detail
    GGORDERS AS <% db_name %>.ESG.Z_GOGREEN_PLUS_ORDER
      PRIMARY KEY (ORDERID)
      COMMENT = 'Individual GoGreen Plus customer orders with SAF blending %, CO2e avoided, and green premium.',

    -- Workforce
    WORKFORCE AS <% db_name %>.ESG.SF_CORE_WORKFORCE
      PRIMARY KEY (SNAPSHOTID)
      COMMENT = 'Quarterly workforce ESG metrics: headcount, engagement, women in management, training, compliance.',

    -- Health & Safety
    SAFETY AS <% db_name %>.ESG.SF_HEALTH_SAFETY
      PRIMARY KEY (RECORDID)
      COMMENT = 'Quarterly occupational health and safety. LTIFR per division.',

    -- ESG scores benchmark
    SCORES AS <% db_name %>.ESG.EXT_ESG_SCORES
      PRIMARY KEY (SCOREID)
      COMMENT = 'External ESG ratings from ESG Book, Fitch, Sustainalytics. World Delivery vs logistics peer group.',

    -- Emission forecast scenarios
    FORECAST AS <% db_name %>.ESG.V_EMISSION_FORECAST
      PRIMARY KEY (REPORTING_YEAR, SCOPE_GROUP, SCENARIO)
      COMMENT = 'Emission projections through 2030 under 3 scenarios: BAU (current trajectory), ACCELERATED (doubled decarb investment), SBTI_REQUIRED (linear path to target). Combines historical actuals with forecasts.',

    -- Decarb lever analysis
    LEVERS AS <% db_name %>.ESG.V_DECARB_LEVER_ANALYSIS
      PRIMARY KEY (REPORTING_YEAR, SCENARIO, LEVER_NAME)
      COMMENT = 'Marginal abatement cost curve: CO2e reduction potential and EUR investment required per decarbonization lever (SAF, fleet electrification, renewable energy, efficiency, H2, insetting) under each scenario.'
  )

  DIMENSIONS (
    -- GHG dimensions
    GHG.REPORTING_YEAR       AS REPORTING_YEAR
      COMMENT = 'Calendar/fiscal year of the data (2024-2025)',
    GHG.DIVISION             AS DIVISION
      COMMENT = 'Business division: EXPRESS, SUPPLY_CHAIN, ECOMMERCE, POST_PARCEL, GROUP',
    GHG.TRANSPORTMODE        AS TRANSPORT_MODE
      COMMENT = 'Transport mode: AIR (65% of emissions), ROAD (23%), OCEAN (11%), RAIL (1%), BUILDINGS',
    GHG.SCOPE                AS GHG_SCOPE
      COMMENT = 'GHG Protocol scope: 1 = own fleet/onsite, 2 = purchased energy, 3 = subcontracted transport',
    GHG.CARRIERTYPE          AS CARRIER_TYPE
      COMMENT = 'OWN_FLEET, SUBCONTRACTED, or OWN_FACILITY',
    GHG.FUELTYPEUSED         AS FUEL_TYPE
      COMMENT = 'Fuel or energy source: JET_A1, SAF, DIESEL, HVO, BEV_ELEC, CNG, BUNKER_FUEL, ELECTRIC_RAIL, NATURAL_GAS, SOLAR, etc.',
    GHG.ISGOGREENPLUSORDER   AS IS_GOGREEN_PLUS
      COMMENT = 'TRUE if emissions are from GoGreen Plus orders (emission-reduced logistics)',

    -- ESRS
    ESRS.DISCLOSURE_CATEGORY AS DISCLOSURE_CATEGORY
      COMMENT = 'ESRS disclosure category label',

    -- Decarb
    DECARB.STATUS_SCOPE_1_2  AS SBTI_STATUS_SCOPE_1_2
      COMMENT = 'SBTi Scope 1&2 target status: ON_TRACK or AT_RISK',
    DECARB.STATUS_SCOPE_3    AS SBTI_STATUS_SCOPE_3
      COMMENT = 'SBTi Scope 3 target status: ON_TRACK or AT_RISK',

    -- GoGreen
    GOGREEN.CUSTOMERNAME     AS GOGREEN_CUSTOMER
      COMMENT = 'GoGreen Plus customer name',
    GOGREEN.CUSTOMERSEGMENT  AS CUSTOMER_SEGMENT
      COMMENT = 'Customer segment: ENTERPRISE, MID_MARKET, SMB',
    GOGREEN.DECARBTECHNOLOGY AS DECARB_TECHNOLOGY
      COMMENT = 'Decarbonization technology used: SAF, BEV, INSETTING, OFFSETTING',

    -- Fleet
    FLEET.DRIVETYPE          AS DRIVE_TYPE
      COMMENT = 'Vehicle drive type: BEV (battery electric), PHEV, HVO, CNG, H2, DIESEL',
    FLEET.VEHICLECATEGORY    AS VEHICLE_CATEGORY
      COMMENT = 'Vehicle category: LAST_MILE, LINE_HAUL, SPECIAL',

    -- Shipment detail
    SHIPMENTS.TRANSPORTMODE  AS SHIPMENT_MODE
      COMMENT = 'Transport mode of individual shipment',
    SHIPMENTS.ORIGIN         AS ORIGIN
      COMMENT = 'Shipment origin city or hub',
    SHIPMENTS.DESTINATION    AS DESTINATION
      COMMENT = 'Shipment destination city or hub',

    -- Energy
    ENERGY.ENERGYSOURCETYPE  AS ENERGY_SOURCE
      COMMENT = 'Facility energy source: GRID_CONVENTIONAL, GRID_RENEWABLE, SOLAR_ONSITE, DIESEL_GENERATOR, NATURAL_GAS',

    -- Workforce
    WORKFORCE.QUARTER        AS WORKFORCE_QUARTER
      COMMENT = 'Quarter label (e.g. 2025-Q4)',
    WORKFORCE.REGION         AS WORKFORCE_REGION
      COMMENT = 'Geographic region: EUROPE, AMERICAS, APAC, MEA',

    -- Scores
    SCORES.COMPANYNAME       AS ESG_COMPANY
      COMMENT = 'Company name in ESG rating',
    SCORES.PROVIDER          AS ESG_PROVIDER
      COMMENT = 'Rating provider: ESG_BOOK, FITCH, SUSTAINALYTICS',

    -- Forecast
    FORECAST.SCOPE_GROUP     AS FORECAST_SCOPE
      COMMENT = 'Forecast scope group: SCOPE_1_2 or SCOPE_3',
    FORECAST.SCENARIO        AS FORECAST_SCENARIO
      COMMENT = 'Forecast scenario: ACTUAL (historical), BAU (business as usual), ACCELERATED (doubled decarb investment), SBTI_REQUIRED (linear path to 2030 target)',
    FORECAST.IS_FORECAST     AS IS_FORECAST
      COMMENT = 'FALSE = historical actual, TRUE = projected future value',
    FORECAST.TARGET_STATUS   AS TARGET_STATUS
      COMMENT = 'ACTUAL, TARGET_PATH, MEETS_TARGET, or MISSES_TARGET — whether this data point meets the SBTi 2030 requirement',
    FORECAST.KEY_ASSUMPTIONS AS FORECAST_ASSUMPTIONS
      COMMENT = 'Key assumptions driving the forecast scenario — for narrative context',

    -- Decarb levers
    LEVERS.LEVER_NAME        AS DECARB_LEVER
      COMMENT = 'Decarbonization lever: SAF, FLEET_ELECTRIFICATION, RENEWABLE_ENERGY, EFFICIENCY, H2_FUEL_CELL, INSETTING',
    LEVERS.READINESS         AS LEVER_READINESS
      COMMENT = 'Technology readiness: DEPLOYED, SCALING, PILOT, EMERGING'
  )

  METRICS (
    -- ── EMISSIONS ──────────────────────────────────────────────────────────
    GHG.TOTAL_CO2E_TONNES   AS SUM(GHG.TOTAL_CO2E_TONNES)
      COMMENT = 'Total CO2-equivalent emissions in metric tonnes',
    GHG.TOTAL_CO2E_KG       AS SUM(GHG.TOTAL_CO2E_KG)
      COMMENT = 'Total CO2-equivalent emissions in kilograms',
    GHG.SHIPMENT_COUNT      AS SUM(GHG.SHIPMENT_COUNT)
      COMMENT = 'Number of shipments or facility records',
    GHG.TOTAL_DISTANCE_KM   AS SUM(GHG.TOTAL_DISTANCE_KM)
      COMMENT = 'Total distance in kilometers',
    GHG.TOTAL_WEIGHT_KG     AS SUM(GHG.TOTAL_WEIGHT_KG)
      COMMENT = 'Total weight transported in kilograms',
    GHG.AVG_PRIMARY_DATA_PCT AS AVG(GHG.AVG_PRIMARY_DATA_PCT)
      COMMENT = 'Average percentage of primary data used in emission calculations',

    -- ── ESRS DISCLOSURE ────────────────────────────────────────────────────
    ESRS.SCOPE_1_TONNES              AS SUM(ESRS.SCOPE_1_TONNES)
      COMMENT = 'Scope 1 GHG emissions (own fleet, onsite generation) in tonnes',
    ESRS.SCOPE_2_MARKET_BASED_TONNES AS SUM(ESRS.SCOPE_2_MARKET_BASED_TONNES)
      COMMENT = 'Scope 2 GHG emissions (market-based, purchased energy) in tonnes',
    ESRS.SCOPE_3_TOTAL_TONNES        AS SUM(ESRS.SCOPE_3_TOTAL_TONNES)
      COMMENT = 'Scope 3 GHG emissions (subcontracted transport, value chain) in tonnes',
    ESRS.TOTAL_GHG_TONNES            AS SUM(ESRS.TOTAL_GHG_TONNES)
      COMMENT = 'Total GHG emissions across all scopes in tonnes',

    -- ── DECARB PROGRESS ────────────────────────────────────────────────────
    DECARB.SCOPE_1_2_TONNES          AS SUM(DECARB.SCOPE_1_2_TONNES)
      COMMENT = 'Current Scope 1+2 emissions in tonnes',
    DECARB.REDUCTION_PCT_SCOPE_1_2   AS AVG(DECARB.REDUCTION_PCT_SCOPE_1_2)
      COMMENT = 'Reduction percentage vs baseline for Scope 1+2. Target: -42% by 2030.',
    DECARB.REDUCTION_PCT_SCOPE_3     AS AVG(DECARB.REDUCTION_PCT_SCOPE_3)
      COMMENT = 'Reduction percentage vs baseline for Scope 3. Target: -25% by 2030.',

    -- ── GOGREEN PLUS ───────────────────────────────────────────────────────
    GOGREEN.GREEN_PREMIUM_USD        AS SUM(GOGREEN.GREEN_PREMIUM_USD)
      COMMENT = 'GoGreen Plus green premium revenue in USD',
    GOGREEN.TOTAL_REVENUE_USD        AS SUM(GOGREEN.TOTAL_REVENUE_USD)
      COMMENT = 'Total GoGreen Plus revenue (base + premium) in USD',
    GOGREEN.CO2E_AVOIDED_TONNES      AS SUM(GOGREEN.CO2E_AVOIDED_TONNES)
      COMMENT = 'CO2e emissions avoided through GoGreen Plus in tonnes',
    GOGREEN.SAF_DEPLOYED_TONNES      AS SUM(GOGREEN.SAF_DEPLOYED_TONNES)
      COMMENT = 'Sustainable Aviation Fuel deployed in tonnes',
    GOGREEN.CERTIFICATES_ISSUED      AS SUM(GOGREEN.CERTIFICATES_ISSUED)
      COMMENT = 'Number of emission reduction certificates issued',
    GOGREEN.ORDER_COUNT              AS SUM(GOGREEN.ORDER_COUNT)
      COMMENT = 'Number of GoGreen Plus orders',

    -- ── FLEET ──────────────────────────────────────────────────────────────
    FLEET_COUNT AS COUNT(FLEET.VEHICLEID)
      COMMENT = 'Total vehicles in fleet',

    -- ── WORKFORCE ──────────────────────────────────────────────────────────
    WORKFORCE.HEADCOUNT              AS SUM(WORKFORCE.HEADCOUNT)
      COMMENT = 'Total employees (FTE equivalent)',
    WORKFORCE.ENGAGEMENTSCORE        AS AVG(WORKFORCE.ENGAGEMENTSCORE)
      COMMENT = 'Employee engagement score (0-100). Target: >85%.',
    WORKFORCE.WOMENINMANAGEMENTPCT   AS AVG(WORKFORCE.WOMENINMANAGEMENTPCT)
      COMMENT = 'Women in management positions (%). Target: 30% by 2030.',
    WORKFORCE.TRAININGHRSPEREMPLOYEE AS AVG(WORKFORCE.TRAININGHRSPEREMPLOYEE)
      COMMENT = 'Average training hours per employee per quarter',

    -- ── SAFETY ─────────────────────────────────────────────────────────────
    SAFETY.LTIFR                     AS AVG(SAFETY.LTIFR)
      COMMENT = 'Lost Time Injury Frequency Rate per 200k work hours. Lower is better.',

    -- ── ESG SCORES ─────────────────────────────────────────────────────────
    SCORES.ESGSCORE                  AS AVG(SCORES.ESGSCORE)
      COMMENT = 'Overall ESG score (0-100) from external rating provider',
    SCORES.ENVIRONMENTSCORE          AS AVG(SCORES.ENVIRONMENTSCORE)
      COMMENT = 'Environment pillar score (0-100)',

    -- ── KPI DASHBOARD ──────────────────────────────────────────────────────
    KPIS.KPI_1_GHG_EMISSIONS_MT      AS SUM(KPIS.KPI_1_GHG_EMISSIONS_MT)
      COMMENT = 'KPI 1: Total logistics-related GHG emissions in million tonnes CO2e',
    KPIS.KPI_2_DECARB_EFFECTS_KT     AS SUM(KPIS.KPI_2_DECARB_EFFECTS_KT)
      COMMENT = 'KPI 2: Realized decarbonization effects in kilotonnes CO2e',
    KPIS.KPI_3_EMPLOYEE_ENGAGEMENT_PCT AS AVG(KPIS.KPI_3_EMPLOYEE_ENGAGEMENT_PCT)
      COMMENT = 'KPI 3: Employee engagement score (%)',
    KPIS.KPI_4_WOMEN_IN_MGMT_PCT     AS AVG(KPIS.KPI_4_WOMEN_IN_MGMT_PCT)
      COMMENT = 'KPI 4: Women in management (%)',
    KPIS.KPI_5_LTIFR                  AS AVG(KPIS.KPI_5_LTIFR)
      COMMENT = 'KPI 5: Lost Time Injury Frequency Rate',
    KPIS.KPI_6_COMPLIANCE_TRAINING_PCT AS AVG(KPIS.KPI_6_COMPLIANCE_TRAINING_PCT)
      COMMENT = 'KPI 6: Compliance training completion rate (%)',

    -- ── FORECAST & SCENARIOS ──────────────────────────────────────────────
    FORECAST.TOTAL_CO2E_TONNES       AS SUM(FORECAST.TOTAL_CO2E_TONNES)
      COMMENT = 'Forecasted (or actual) CO2e emissions in tonnes for the year/scope/scenario',
    FORECAST.TOTAL_CO2E_MT           AS SUM(FORECAST.TOTAL_CO2E_MT)
      COMMENT = 'Forecasted (or actual) CO2e emissions in million tonnes',
    FORECAST.REDUCTION_FROM_BASE_PCT AS AVG(FORECAST.REDUCTION_FROM_BASE_PCT)
      COMMENT = 'Percentage reduction from 2020 baseline for this scenario',

    -- ── DECARB LEVERS ─────────────────────────────────────────────────────
    LEVERS.CO2E_REDUCTION_KT         AS SUM(LEVERS.CO2E_REDUCTION_KT)
      COMMENT = 'CO2e reduction potential in kilotonnes from this decarbonization lever',
    LEVERS.INVESTMENT_MEUR           AS SUM(LEVERS.INVESTMENT_MEUR)
      COMMENT = 'Investment required in millions EUR',
    LEVERS.COST_PER_TONNE_EUR        AS AVG(LEVERS.COST_PER_TONNE_EUR)
      COMMENT = 'Marginal abatement cost: EUR per tonne CO2e avoided. Lower = more cost-effective.',
    LEVERS.CUMULATIVE_REDUCTION_KT   AS MAX(LEVERS.CUMULATIVE_REDUCTION_KT)
      COMMENT = 'Cumulative CO2e reduction across all levers ordered by cost-effectiveness'
  )

  COMMENT = 'World Delivery ESG Analytics Semantic View. Covers: GHG emissions by scope/mode/division, ESRS E1 disclosure, SBTi 2030 target tracking, emission forecasts (3 scenarios through 2030), decarbonization lever analysis (marginal abatement cost curve), GoGreen Plus commercial ESG, fleet electrification, facility energy, workforce engagement, health & safety, and peer ESG benchmarking.';


SELECT 'Semantic view created: WORLD_DELIVERY_ESG_SV' AS status;
