-- =============================================================================
-- 04_successfactors.sql — SuccessFactors BDC Data Products (workforce ESG)
--
-- Simulates SAP SuccessFactors analytics data products from BDC:
--   sap-bdc-sf-analytics-CoreWorkforceData-v1  → SF_CORE_WORKFORCE
--   (custom)                                    → SF_HEALTH_SAFETY
--
-- These feed the social dimension of ESG: employee engagement, women in
-- management, training hours, LTIFR, and compliance metrics.
--
-- Variables: <% db_name %>, <% wh_name %>
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE IDENTIFIER('<% db_name %>');
USE SCHEMA ESG;

-- =============================================================================
-- SF_CORE_WORKFORCE — quarterly workforce snapshots
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE SF_CORE_WORKFORCE (
    SNAPSHOTID              VARCHAR(15)  NOT NULL  COMMENT 'Unique snapshot record ID',
    DIVISION                VARCHAR(30)            COMMENT 'Division: EXPRESS, SUPPLY_CHAIN, ECOMMERCE, POST_PARCEL, GROUP',
    REGION                  VARCHAR(30)            COMMENT 'Region: EUROPE, AMERICAS, APAC, MEA',
    QUARTER                 VARCHAR(7)             COMMENT 'Quarter label: 2025-Q1, 2025-Q2, etc.',
    REPORTINGDATE           DATE                   COMMENT 'Last day of the quarter',
    HEADCOUNT               NUMBER(8,0)            COMMENT 'Total employees (FTE equivalent)',
    WOMENINMANAGEMENTPCT    NUMBER(5,2)            COMMENT 'Women in management positions (%)',
    ENGAGEMENTSCORE         NUMBER(5,1)            COMMENT 'Employee engagement score (0-100)',
    TRAININGHRSPEREMPLOYEE  NUMBER(6,1)            COMMENT 'Average training hours per employee per quarter',
    COMPLIANCETRAININGPCT   NUMBER(5,1)            COMMENT 'Compliance training completion rate (%)',
    VOLUNTARYTURNOVERRRATE  NUMBER(5,2)            COMMENT 'Voluntary turnover rate (%)',
    PRIMARYKEY_DIVISION     VARCHAR(30)            COMMENT 'Helper for joins — same as DIVISION',
    PRIMARY KEY (SNAPSHOTID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- SF_HEALTH_SAFETY — occupational health and safety metrics
-- Tracks the LTIFR (Lost Time Injury Frequency Rate), fatal accidents,
-- and reportable injuries per division per quarter.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE SF_HEALTH_SAFETY (
    RECORDID            VARCHAR(15)  NOT NULL  COMMENT 'Unique record ID',
    DIVISION            VARCHAR(30)            COMMENT 'Division',
    QUARTER             VARCHAR(7)             COMMENT 'Quarter label: 2025-Q1, etc.',
    REPORTINGDATE       DATE                   COMMENT 'Last day of the quarter',
    LTIFR               NUMBER(5,2)            COMMENT 'Lost Time Injury Frequency Rate (per 200k hours)',
    FATALACCIDENTS      NUMBER(3,0)            COMMENT 'Number of fatal workplace accidents',
    REPORTABLEINJURIES  NUMBER(5,0)            COMMENT 'Total reportable injuries',
    WORKHOURSM          NUMBER(10,1)           COMMENT 'Total work hours in millions',
    SAFETYTRANININGPCT  NUMBER(5,1)            COMMENT 'Safety training completion rate (%)',
    PRIMARY KEY (RECORDID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


SELECT 'SuccessFactors tables created: SF_CORE_WORKFORCE, SF_HEALTH_SAFETY' AS status;
