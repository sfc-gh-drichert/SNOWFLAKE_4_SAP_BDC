-- =============================================================================
-- 05_marketplace.sql — External / Marketplace Enrichment Tables
--
-- These tables simulate data from Snowflake Marketplace ESG providers:
--   ESG Book / Fitch    → EXT_ESG_SCORES
--   GLEC Framework      → EXT_EMISSION_FACTORS
--   Manifest Climate    → EXT_CLIMATE_RISK
--
-- Variables: <% db_name %>, <% wh_name %>
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE IDENTIFIER('<% db_name %>');
USE SCHEMA ESG;

-- =============================================================================
-- EXT_EMISSION_FACTORS — GLEC Framework / GHG Protocol emission factors
-- Used to calculate per-shipment emissions when primary data is unavailable.
-- Source: GLEC Framework 3.1, DEFRA, EPA
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE EXT_EMISSION_FACTORS (
    FACTORID            VARCHAR(15)  NOT NULL  COMMENT 'Unique factor ID',
    TRANSPORTMODE       VARCHAR(10)            COMMENT 'Mode: AIR, ROAD, OCEAN, RAIL',
    FUELTYPE            VARCHAR(20)            COMMENT 'Fuel type for this factor',
    REGION              VARCHAR(30)            COMMENT 'Geographic applicability',
    CO2EPERTONKM        NUMBER(10,6)           COMMENT 'kg CO2e per tonne-kilometer',
    CO2EPERLITER         NUMBER(10,4)           COMMENT 'kg CO2e per liter of fuel consumed',
    CO2EPERKWH           NUMBER(8,6)            COMMENT 'kg CO2e per kWh (electricity only)',
    SOURCE              VARCHAR(30)            COMMENT 'Data source: GLEC_3_1, DEFRA_2025, EPA_2025',
    VALIDYEAR           NUMBER(4,0)            COMMENT 'Year these factors are valid for',
    PRIMARY KEY (FACTORID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- EXT_ESG_SCORES — ESG provider ratings (ESG Book, Fitch, MSCI)
-- World Delivery vs logistics peer group for benchmarking.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE EXT_ESG_SCORES (
    SCOREID             VARCHAR(15)  NOT NULL  COMMENT 'Unique score record ID',
    COMPANYNAME         VARCHAR(100)           COMMENT 'Company name',
    TICKER              VARCHAR(10)            COMMENT 'Stock ticker if publicly traded',
    RATINGDATE          DATE                   COMMENT 'Date of the ESG rating',
    ESGSCORE            NUMBER(5,1)            COMMENT 'Overall ESG score (0-100)',
    ENVIRONMENTSCORE    NUMBER(5,1)            COMMENT 'Environment pillar score (0-100)',
    SOCIALSCORE         NUMBER(5,1)            COMMENT 'Social pillar score (0-100)',
    GOVERNANCESCORE     NUMBER(5,1)            COMMENT 'Governance pillar score (0-100)',
    CARBONSCORE         VARCHAR(5)             COMMENT 'Carbon rating: A, B, C, D',
    SBTISTATUS          VARCHAR(30)            COMMENT 'SBTi status: COMMITTED, TARGETS_SET, NOT_COMMITTED',
    PROVIDER            VARCHAR(30)            COMMENT 'Rating provider: ESG_BOOK, FITCH, MSCI, SUSTAINALYTICS',
    INDUSTRY            VARCHAR(50)            COMMENT 'Industry classification',
    PRIMARY KEY (SCOREID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- EXT_CLIMATE_RISK — physical and transition risk assessment
-- Assesses risk exposure at the facility/region level.
-- Source: Manifest Climate / S&P Trucost style data
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE EXT_CLIMATE_RISK (
    RISKID              VARCHAR(15)  NOT NULL  COMMENT 'Unique risk record ID',
    ASSETTYPE           VARCHAR(20)            COMMENT 'Asset type: HUB, SORT_CENTER, WAREHOUSE, FLEET_DEPOT, OFFICE',
    REGION              VARCHAR(30)            COMMENT 'Geographic region of the asset',
    COUNTRY             VARCHAR(3)             COMMENT 'ISO country code',
    PHYSICALRISKSCORE   NUMBER(5,2)            COMMENT 'Physical risk score (0-10): flood, heat, storm exposure',
    TRANSITIONRISKSCORE NUMBER(5,2)            COMMENT 'Transition risk score (0-10): carbon pricing, regulation, market',
    RISKCATEGORY        VARCHAR(30)            COMMENT 'Primary risk: FLOOD, HEAT_STRESS, STORM, CARBON_PRICING, REGULATION, STRANDED_ASSETS',
    SCENARIO            VARCHAR(20)            COMMENT 'Climate scenario: RCP_2_6, RCP_4_5, RCP_8_5',
    TIMEHORIZON         VARCHAR(10)            COMMENT 'Risk horizon: SHORT (2030), MEDIUM (2040), LONG (2050)',
    FINANCIALIMPACTUSD  NUMBER(12,0)           COMMENT 'Estimated financial impact in USD',
    ASSESSMENTDATE      DATE                   COMMENT 'Date of risk assessment',
    PRIMARY KEY (RISKID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


SELECT 'Marketplace enrichment tables created: EXT_EMISSION_FACTORS, EXT_ESG_SCORES, EXT_CLIMATE_RISK' AS status;
