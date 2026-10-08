-- =============================================================================
-- 02_bdc_master_data.sql — SAP BDC Managed Data Products (simulated CLDs)
--
-- These tables simulate the SAP BDC managed data products that World Delivery
-- receives via BDC Connect for Snowflake. Named after real BDC CSN entity
-- conventions so the demo mirrors production architecture.
--
-- BDC Products mapped:
--   sap-s4com-CompanyCode-v1                              → COMPANYCODE
--   sap-bdc-sf-foundationobjects-EnterpriseStructure-v1   → COSTCENTER
--   sap-s4com-Plant-v1                                    → PLANT
--   sap-s4com-GeneralLedgerAccount-v1                     → GENERALLEDGERACCOUNTLINEITEM
--
-- Variables: <% db_name %>, <% wh_name %>
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE IDENTIFIER('<% db_name %>');
USE SCHEMA ESG;

-- =============================================================================
-- COMPANYCODE — SAP Company Code master
-- BDC Product: sap-s4com-CompanyCode-v1
-- World Delivery operates through 8 major company codes across 5 divisions.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE COMPANYCODE (
    COMPANYCODE         VARCHAR   NOT NULL  COMMENT 'SAP company code (BUKRS)',
    COMPANYCODENAME     VARCHAR           COMMENT 'Legal entity name',
    CITYNAME            VARCHAR            COMMENT 'Headquarters city',
    COUNTRY             VARCHAR             COMMENT 'ISO 3166-1 alpha-2 country code',
    CURRENCY            VARCHAR             COMMENT 'Local reporting currency (ISO 4217)',
    CHARTOFACCOUNTS     VARCHAR             COMMENT 'Chart of accounts key',
    FISCALYEARVARIANT   VARCHAR             COMMENT 'Fiscal year variant (K4 = calendar year)',
    DIVISION            VARCHAR            COMMENT 'World Delivery division assignment',
    PRIMARY KEY (COMPANYCODE)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- COSTCENTER — SAP / SuccessFactors Cost Center master
-- BDC Product: sap-bdc-sf-foundationobjects-EnterpriseStructure-v1
-- ESG-relevant cost centers: fleet, facilities, hubs, line haul, offices.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE COSTCENTER (
    COSTCENTERID        VARCHAR  NOT NULL  COMMENT 'Cost center ID (SAP KOSTL)',
    EXTERNALCODE        VARCHAR            COMMENT 'External code for cross-system mapping',
    NAME                VARCHAR           COMMENT 'Cost center descriptive name',
    DESCRIPTION         VARCHAR           COMMENT 'Purpose and function of this cost center',
    COMPANYCODE         VARCHAR             COMMENT 'FK → COMPANYCODE.COMPANYCODE',
    DIVISION            VARCHAR            COMMENT 'Division: EXPRESS, SUPPLY_CHAIN, ECOMMERCE, POST_PARCEL, GROUP',
    COSTCENTERTYPE      VARCHAR            COMMENT 'Type: FLEET, FACILITY, LINEHAUL, HUB, SORT_CENTER, OFFICE, SUSTAINABILITY',
    VALIDFROM           DATE                   COMMENT 'Effective start date',
    VALIDTO             DATE                   COMMENT 'Effective end date (9999-12-31 = open)',
    PRIMARY KEY (COSTCENTERID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- PLANT — SAP Plant master
-- BDC Product: sap-s4com-Plant-v1
-- Represents physical locations: express hubs, sort centers, freight terminals,
-- offices, and warehouses across the global network.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE PLANT (
    PLANT               VARCHAR   NOT NULL  COMMENT 'SAP plant code (WERKS)',
    PLANTNAME           VARCHAR            COMMENT 'Plant / facility name',
    PLANTCATEGORY       VARCHAR            COMMENT 'Category: HUB, SORT_CENTER, FREIGHT_TERMINAL, OFFICE, WAREHOUSE',
    COUNTRY             VARCHAR             COMMENT 'ISO country code',
    REGION              VARCHAR            COMMENT 'Geographic region: EUROPE, AMERICAS, APAC, MEA',
    CITYNAME            VARCHAR            COMMENT 'City location',
    COMPANYCODE         VARCHAR             COMMENT 'FK → COMPANYCODE.COMPANYCODE',
    DIVISION            VARCHAR            COMMENT 'Division: EXPRESS, SUPPLY_CHAIN, ECOMMERCE, POST_PARCEL, GROUP',
    FACTORYCALENDAR     VARCHAR             COMMENT 'Factory calendar ID',
    FLOORSPACESQM       NUMBER(10,0)           COMMENT 'Total floor space in square meters',
    PRIMARY KEY (PLANT)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


-- =============================================================================
-- GENERALLEDGERACCOUNTLINEITEM — ACDOCA journal entries
-- BDC Product: sap-s4com-GeneralLedgerAccount-v1
-- Filtered to ESG-relevant GL accounts: fuel, energy, SAF, fleet capex,
-- carbon offsets, decarb expenditure, renewable energy certificates.
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE GENERALLEDGERACCOUNTLINEITEM (
    SOURCELEDGER                    VARCHAR   NOT NULL  COMMENT 'Ledger ID (0L = leading ledger)',
    COMPANYCODE                     VARCHAR   NOT NULL  COMMENT 'FK → COMPANYCODE.COMPANYCODE',
    FISCALYEAR                      VARCHAR   NOT NULL  COMMENT 'Fiscal year (YYYY)',
    ACCOUNTINGDOCUMENT              VARCHAR  NOT NULL  COMMENT 'Accounting document number (BELNR)',
    LEDGERGLLINEITEM                VARCHAR   NOT NULL  COMMENT 'Line item number within document',
    GLACCOUNT                       VARCHAR            COMMENT 'G/L account number — ESG ranges: 6100xx=fuel, 6200xx=energy, 6300xx=SAF, 6400xx=fleet_capex, 6500xx=carbon_offset',
    GLACCOUNTDESCRIPTION            VARCHAR           COMMENT 'G/L account description',
    COSTCENTER                      VARCHAR            COMMENT 'FK → COSTCENTER.COSTCENTERID',
    PROFITCENTER                    VARCHAR            COMMENT 'Profit center',
    AMOUNTINCOMPANYCODECURRENCY     NUMBER(15,2)           COMMENT 'Amount in local currency (positive = debit)',
    CURRENCY                        VARCHAR             COMMENT 'Document currency (ISO 4217)',
    POSTINGDATE                     DATE                   COMMENT 'Posting date of the journal entry',
    DOCUMENTDATE                    DATE                   COMMENT 'Document date (invoice/receipt date)',
    POSTINGPERIOD                   VARCHAR             COMMENT 'Fiscal period (01-12)',
    DOCUMENTTYPE                    VARCHAR             COMMENT 'Document type (SA=GL, KR=vendor invoice, AA=asset)',
    PLANT                           VARCHAR             COMMENT 'FK → PLANT.PLANT',
    ESGCATEGORY                     VARCHAR            COMMENT 'ESG cost category: FUEL, ENERGY, SAF, FLEET_CAPEX, CARBON_OFFSET, RENEWABLE_CERT, DECARB_OTHER',
    PRIMARY KEY (SOURCELEDGER, COMPANYCODE, FISCALYEAR, ACCOUNTINGDOCUMENT, LEDGERGLLINEITEM)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;


SELECT 'BDC master data tables created: COMPANYCODE, COSTCENTER, PLANT, GENERALLEDGERACCOUNTLINEITEM' AS status;
