-- =============================================================================
-- 03_esg_custom_cds.sql — Custom CDS Views (ESG-specific data)
--
-- These tables simulate custom CDS views that World Delivery would create
-- in S/4HANA for ESG tracking. SAP BDC does not have managed ESG data
-- products yet — this is the granularity gap that Snowflake fills.
--
-- Z_ prefix follows SAP custom object naming convention.
--
-- Variables: <% db_name %>, <% wh_name %>
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE IDENTIFIER('<% db_name %>');
USE SCHEMA ESG;

-- =============================================================================
-- Z_SHIPMENT_EMISSIONS — per-shipment GHG calculation
-- The core granularity gap table: millions of individual shipment emission
-- records that TM1/BW only sees as aggregated monthly totals.
-- Calculation follows GLEC Framework 3.1 / ISO 14083.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE Z_SHIPMENT_EMISSIONS (
    SHIPMENTID          VARCHAR  NOT NULL  COMMENT 'Unique shipment identifier',
    TRANSPORTMODE       VARCHAR            COMMENT 'Mode: AIR, ROAD, OCEAN, RAIL',
    DIVISION            VARCHAR            COMMENT 'Division: EXPRESS, SUPPLY_CHAIN, ECOMMERCE, POST_PARCEL',
    COMPANYCODE         VARCHAR             COMMENT 'FK → COMPANYCODE.COMPANYCODE',
    ORIGIN              VARCHAR            COMMENT 'Origin city or hub code',
    DESTINATION         VARCHAR            COMMENT 'Destination city or hub code',
    SHIPMENTDATE        DATE                   COMMENT 'Date shipment was dispatched',
    DISTANCEKM          NUMBER(10,1)           COMMENT 'Distance traveled in kilometers',
    WEIGHTKG            NUMBER(10,2)           COMMENT 'Shipment weight in kilograms',
    CO2EKG              NUMBER(12,4)           COMMENT 'CO2-equivalent emissions in kilograms',
    EMISSIONSCOPE       VARCHAR             COMMENT 'GHG Protocol scope: 1 (own fleet) or 3 (subcontracted)',
    CALCULATIONMETHOD   VARCHAR            COMMENT 'Method: GLEC_DEFAULT, GLEC_MODELED, DEFRA, EPA',
    PRIMARYDATAPCT      NUMBER(5,1)            COMMENT 'Percentage of primary data used in calculation',
    FUELTYPEUSED        VARCHAR            COMMENT 'Fuel: JET_A1, SAF, DIESEL, HVO, BEV_ELEC, CNG, LNG, BUNKER_FUEL',
    FUELQUANTITYLITERS  NUMBER(10,2)           COMMENT 'Fuel consumed in liters (or KWH for BEV)',
    ISGOGREENPLUSORDER  BOOLEAN                COMMENT 'TRUE if part of GoGreen Plus emission-reduced offering',
    CARRIERTYPE         VARCHAR            COMMENT 'OWN_FLEET or SUBCONTRACTED',
    PRIMARY KEY (SHIPMENTID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- Z_FACILITY_ENERGY — monthly facility energy consumption
-- Tracks energy by source type per facility, enabling Scope 1 (onsite gen)
-- and Scope 2 (purchased electricity) separation.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE Z_FACILITY_ENERGY (
    FACILITYENERGYID    VARCHAR  NOT NULL  COMMENT 'Unique record ID',
    PLANT               VARCHAR             COMMENT 'FK → PLANT.PLANT',
    REPORTINGMONTH      DATE                   COMMENT 'First day of reporting month',
    ENERGYSOURCETYPE    VARCHAR            COMMENT 'Source: GRID_CONVENTIONAL, GRID_RENEWABLE, SOLAR_ONSITE, WIND_ONSITE, DIESEL_GENERATOR, NATURAL_GAS',
    CONSUMPTIONKWH      NUMBER(12,1)           COMMENT 'Energy consumed in kilowatt-hours',
    CONSUMPTIONMWH      NUMBER(10,3)           COMMENT 'Energy consumed in megawatt-hours',
    CO2EKG              NUMBER(12,4)           COMMENT 'CO2-equivalent emissions from this consumption',
    EMISSIONSCOPE       VARCHAR             COMMENT 'GHG scope: 1 (onsite gen) or 2 (purchased)',
    RENEWABLEPCT        NUMBER(5,1)            COMMENT 'Percentage that is renewable (0-100)',
    GRIDEMIISSIONFACTOR  NUMBER(8,4)           COMMENT 'Grid emission factor used (kg CO2e per KWH)',
    PRIMARY KEY (FACILITYENERGYID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- Z_FLEET_VEHICLE — fleet master data
-- World Delivery operates 120,000+ vehicles globally, with 50,000+ electric.
-- This table carries the drive type, division, and emission characteristics.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE Z_FLEET_VEHICLE (
    VEHICLEID           VARCHAR  NOT NULL  COMMENT 'Vehicle registration/asset ID',
    DRIVETYPE           VARCHAR            COMMENT 'Drive type: BEV, PHEV, HVO, CNG, DIESEL, H2',
    VEHICLECATEGORY     VARCHAR            COMMENT 'Category: LAST_MILE, LINE_HAUL, SPECIAL',
    DIVISION            VARCHAR            COMMENT 'Division operating this vehicle',
    PLANT               VARCHAR             COMMENT 'FK → PLANT.PLANT — home depot',
    COMPANYCODE         VARCHAR             COMMENT 'FK → COMPANYCODE.COMPANYCODE',
    MANUFACTURER        VARCHAR            COMMENT 'Vehicle manufacturer',
    MODEL               VARCHAR            COMMENT 'Vehicle model',
    MANUFACTUREYEAR     NUMBER(4,0)            COMMENT 'Year of manufacture',
    CO2GPERKM           NUMBER(6,1)            COMMENT 'Rated CO2 emissions in grams per kilometer',
    PAYLOADKG           NUMBER(8,0)            COMMENT 'Maximum payload capacity in kilograms',
    RANGEKMFULL         NUMBER(6,0)            COMMENT 'Range in km on full tank/charge',
    ISACTIVE            BOOLEAN                COMMENT 'TRUE if vehicle is in active service',
    ACQUISITIONDATE     DATE                   COMMENT 'Date vehicle entered fleet',
    PRIMARY KEY (VEHICLEID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- Z_FLEET_FUEL_LOG — vehicle fuel/energy consumption log
-- Daily records of fuel or electricity consumed per vehicle.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE Z_FLEET_FUEL_LOG (
    LOGID               VARCHAR  NOT NULL  COMMENT 'Unique log entry ID',
    VEHICLEID           VARCHAR            COMMENT 'FK → Z_FLEET_VEHICLE.VEHICLEID',
    LOGDATE             DATE                   COMMENT 'Date of fueling/charging event',
    FUELTYPE            VARCHAR            COMMENT 'Fuel: DIESEL, HVO, SAF, CNG, LNG, BEV_ELEC, H2',
    QUANTITYLITERS      NUMBER(10,2)           COMMENT 'Liters dispensed (or KWH for electric)',
    DISTANCEKM          NUMBER(8,1)            COMMENT 'Distance driven since last log',
    CO2EKG              NUMBER(10,4)           COMMENT 'CO2e emissions from this consumption',
    COSTLOCALCURRENCY   NUMBER(10,2)           COMMENT 'Cost in local currency',
    CURRENCY            VARCHAR             COMMENT 'Currency code (ISO 4217)',
    PRIMARY KEY (LOGID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- Z_GOGREEN_PLUS_ORDER — Green logistics premium product orders
-- GoGreen Plus offers emission-reduced logistics via SAF, e-vehicles, and
-- carbon offsetting. Tracks customer orders and CO2e avoidance.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE Z_GOGREEN_PLUS_ORDER (
    ORDERID             VARCHAR  NOT NULL  COMMENT 'GoGreen Plus order ID',
    CUSTOMERNAME        VARCHAR           COMMENT 'Customer company name',
    CUSTOMERSEGMENT     VARCHAR            COMMENT 'Segment: ENTERPRISE, MID_MARKET, SMB',
    DIVISION            VARCHAR            COMMENT 'Division fulfilling the order',
    SHIPMENTID          VARCHAR            COMMENT 'FK → Z_SHIPMENT_EMISSIONS.SHIPMENTID (optional)',
    ORDERDATE           DATE                   COMMENT 'Date order was placed',
    SAFBLENDINGPCT      NUMBER(5,1)            COMMENT 'SAF blending percentage applied (0-100)',
    SAFQUANTITYKG       NUMBER(10,2)           COMMENT 'SAF quantity in kilograms used',
    CO2EAVOIDEDKG       NUMBER(12,4)           COMMENT 'CO2e avoided compared to conventional transport',
    PREMIUMUSD          NUMBER(10,2)           COMMENT 'Green premium charged in USD',
    BASESHIPMENTCOSTUSD NUMBER(10,2)           COMMENT 'Base shipment cost before green premium',
    CERTIFICATEID       VARCHAR            COMMENT 'Emission reduction certificate reference',
    DECARBTECHNOLOGY    VARCHAR            COMMENT 'Technology: SAF, BEV, INSETTING, OFFSETTING',
    PRIMARY KEY (ORDERID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- Z_EMISSION_FORECAST — Predictive emission scenarios through 2030
--
-- A sustainability CxO needs to forecast, not just report. This table holds
-- projected emissions under 3 scenarios:
--   BAU        — business as usual (current trajectory continues)
--   ACCELERATED — increased decarb investment (SAF ramp, fleet electrification)
--   SBTI_REQUIRED — the linear reduction path needed to hit SBTi 2030 targets
--
-- Actuals (IS_FORECAST=FALSE) are backfilled from V_GHG_EMISSIONS_SUMMARY.
-- Forecasts (IS_FORECAST=TRUE) are seeded from a model or formula.
-- In production, these would be generated by Snowflake ML FORECAST or
-- Cortex AI, re-trained monthly on actual emission trends.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE Z_EMISSION_FORECAST (
    FORECASTID          VARCHAR  NOT NULL  COMMENT 'Unique forecast record ID',
    REPORTING_YEAR      NUMBER(4,0)            COMMENT 'Year (2020-2030)',
    SCOPE_GROUP         VARCHAR            COMMENT 'SCOPE_1_2 or SCOPE_3',
    SCENARIO            VARCHAR            COMMENT 'Scenario: ACTUAL, BAU, ACCELERATED, SBTI_REQUIRED',
    TOTAL_CO2E_TONNES   NUMBER(15,0)           COMMENT 'Total CO2e emissions in tonnes for this year/scope/scenario',
    REDUCTION_FROM_BASE_PCT NUMBER(6,2)        COMMENT 'Reduction percentage vs 2020 baseline',
    IS_FORECAST         BOOLEAN                COMMENT 'FALSE = historical actual, TRUE = projected',
    KEY_ASSUMPTIONS     VARCHAR           COMMENT 'Key assumptions driving this scenario (for tooltip/narrative)',
    FORECAST_DATE       DATE                   COMMENT 'Date this forecast was generated',
    MODEL_VERSION       VARCHAR            COMMENT 'Forecast model version identifier',
    PRIMARY KEY (FORECASTID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- Z_DECARB_LEVERS — Decarbonization lever projections
--
-- Models the impact of individual decarb levers (SAF, fleet electrification,
-- renewable energy, efficiency, insetting) under each scenario.
-- Enables "what-if" analysis: what happens if SAF scales to 30% by 2028?
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE Z_DECARB_LEVERS (
    LEVERID             VARCHAR  NOT NULL  COMMENT 'Unique lever projection ID',
    REPORTING_YEAR      NUMBER(4,0)            COMMENT 'Projection year (2024-2030)',
    SCENARIO            VARCHAR            COMMENT 'Scenario: BAU, ACCELERATED, SBTI_REQUIRED',
    LEVER_NAME          VARCHAR            COMMENT 'Lever: SAF, FLEET_ELECTRIFICATION, RENEWABLE_ENERGY, EFFICIENCY, INSETTING',
    CO2E_REDUCTION_KT   NUMBER(10,1)           COMMENT 'Projected CO2e reduction in kilotonnes from this lever',
    INVESTMENT_MEUR     NUMBER(10,1)           COMMENT 'Projected investment in millions EUR',
    COST_PER_TONNE_EUR  NUMBER(8,0)            COMMENT 'Marginal abatement cost EUR per tonne CO2e avoided',
    READINESS           VARCHAR            COMMENT 'Technology readiness: DEPLOYED, SCALING, PILOT, EMERGING',
    PRIMARY KEY (LEVERID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


SELECT 'Custom CDS ESG tables created: Z_SHIPMENT_EMISSIONS, Z_FACILITY_ENERGY, Z_FLEET_VEHICLE, Z_FLEET_FUEL_LOG, Z_GOGREEN_PLUS_ORDER, Z_EMISSION_FORECAST, Z_DECARB_LEVERS' AS status;
