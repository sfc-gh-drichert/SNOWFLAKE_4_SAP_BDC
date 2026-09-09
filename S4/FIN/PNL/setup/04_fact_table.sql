-- =============================================================================
-- 04_fact_table.sql — S3_FINANCE_PNL Fact Table DDL
--
-- This table follows the Nestlé/SAP ACDOCA-style CO-PA structure
-- (DefinePnLTable.txt template) with BSH-specific extensions:
--
--   NEW columns added on top of the Nestlé template:
--     CLIENT_ID       — tenant discriminator (BSH, HENKEL, …); RAP fires here
--     BRAND           — denormalised BSH brand name
--     CATEGORY        — denormalised product category
--     SUBCATEGORY     — denormalised product sub-category
--     PRODUCT_TIER    — denormalised product tier (PREMIUM / MID / ENTRY)
--     PRODUCT_NAME    — denormalised full product name (agent readability)
--     PNL_CATEGORY    — denormalised from ACDOCA_RACCT (drives all SV metrics)
--     LIST_PRICE_EUR  — published list price for avg selling price metric
--     SALESVOLUME     — units sold (populated on REVENUE lines only)
--
-- The Row Access Policy (PNL_CLIENT_ISOLATION_POLICY) is applied here
-- on columns (CLIENT_ID, REGION).
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

CREATE OR REPLACE TABLE S3_FINANCE_PNL (

    -- ── TENANT ISOLATION ───────────────────────────────────────────────────
    CLIENT_ID                       VARCHAR(50)
        COMMENT 'Tenant identifier — Row Access Policy enforces visibility per role. BSH = BSH Group. HENKEL, etc. for future companies.',

    -- ── PERIOD / TIME ──────────────────────────────────────────────────────
    MONTHYEAR                       NUMBER(38,0)
        COMMENT 'Fiscal period in YYYYMMM format (e.g. 2024003 = March 2024)',
    DATAENTRYPERIOD                 VARCHAR(16)
        COMMENT 'Data entry period for manual / system postings',
    FISCALYEAR                      NUMBER(4,0)
        COMMENT 'Fiscal year',
    POSTINGPERIOD                   NUMBER(2,0)
        COMMENT 'Posting period number within fiscal year (1-12)',
    POSTINGDATE                     DATE
        COMMENT 'Actual posting date of the GL document (last day of period)',

    -- ── AMOUNT ─────────────────────────────────────────────────────────────
    HSL                             NUMBER(18,2)
        COMMENT 'Amount in EUR (company code currency). Positive = revenue/credit; negative = cost/debit. This is the primary PnL value used in all metric calculations.',
    CURRENCY                        VARCHAR(5)
        COMMENT 'Currency code (ISO 4217). EUR for all demo rows; future: USD for COMPANYCODE=2000, CNY for 3000.',
    CURRENCYTYPE                    VARCHAR(2)
        COMMENT 'Currency type: 10=company code currency, 30=group currency',

    -- ── GL ACCOUNT / PnL CLASSIFICATION ────────────────────────────────────
    ACDOCA_RACCT                    VARCHAR(10)
        COMMENT 'GL account number — primary join key to DIM_GL_ACCOUNT and the PnL hierarchy. See 02_dimensions.sql for mapping.',
    PNL_CATEGORY                    VARCHAR(30)
        COMMENT 'Denormalised from ACDOCA_RACCT: REVENUE | TRADE_SPEND | RETURNS | COGS | LOGISTICS | BRAND_ADP | SALES | RD | GA. Used directly in Semantic View metric expressions.',
    LEDGER                          VARCHAR(4)
        COMMENT 'SAP ledger: 0L = standard ledger (actuals)',

    -- ── ORGANISATIONAL DIMENSIONS ───────────────────────────────────────────
    COMPANYCODE                     VARCHAR(4)
        COMMENT 'SAP company code (BUKRS). BSH-internal entity: 1000=Germany, 1100=W_Europe, 1200=E_Europe, 2000=NA (USD), 3000=China (CNY), 4000=Emerging. NOT the same as CLIENT_ID — see design notes in 03_rbac.sql.',
    COUNTRY                         VARCHAR(3)
        COMMENT 'Country of the company code (ISO 3166-1 alpha-3)',
    COUNTRY_SOLD_TO                 VARCHAR(3)
        COMMENT 'Country of the sold-to party',
    SALESORGANISATION               VARCHAR(4)
        COMMENT 'SAP sales organisation: 0010=Bosch, 0020=Siemens, 0030=Gaggenau, 0040=Neff, 0050=Thermador',
    DISTRIBUTIONCHANNEL             VARCHAR(2)
        COMMENT 'Distribution channel: 10=Retail Specialist | 20=Built-in/Project | 30=E-Commerce | 40=B2B/Commercial',
    REPORTINGUNITASREALIGNED        VARCHAR(10)
        COMMENT 'Reporting unit after realignment adjustments',
    CONTROLLINGAREA                 VARCHAR(4)
        COMMENT 'SAP controlling area (BSH0 for all BSH entities)',
    REGION                          VARCHAR(20)
        COMMENT 'Sales region: DACH | W_EUROPE | E_EUROPE | N_AMERICA | APAC | EMERGING. SECOND column in the Row Access Policy — controls regional visibility.',
    SALESDISTRICT                   VARCHAR(6)
        COMMENT 'SAP sales district',
    PLANT                           VARCHAR(4)
        COMMENT 'Manufacturing plant (maps to DIM_PLANT.PLANT)',
    FUNCTIONALAREA                  VARCHAR(16)
        COMMENT 'SAP functional area used in cost-of-sales accounting: REV=Revenue, SPD=Trade Spend, COS=COGS, LOG=Logistics, ADP=Advertising, SLS=Sales, RD=Research and Development, GA=General and Administrative',
    COSTCENTER                      VARCHAR(10)
        COMMENT 'SAP cost centre (KOSTL)',
    ORIGINCCTR                      VARCHAR(10)
        COMMENT 'Origin cost centre (sending/source cost centre)',
    PARTNERPROFITCTR                VARCHAR(10)
        COMMENT 'Partner profit centre for intercompany transactions',

    -- ── CUSTOMER DIMENSIONS ────────────────────────────────────────────────
    CUSTOMER                        VARCHAR(10)
        COMMENT 'SAP customer number — sold-to party (maps to DIM_CUSTOMER)',
    SHIPTOPARTY                     VARCHAR(10)
        COMMENT 'SAP ship-to party number',
    CUSTOMERGROUP                   VARCHAR(2)
        COMMENT 'SAP customer group: 01=Specialist Retail | 02=Mass Retail | 03=E-Commerce | 04=Built-in/Project | 05=B2B',
    KEYCUSTOMER                     VARCHAR(10)
        COMMENT 'Key customer identifier for strategic account tracking',
    CUST_SOLD_TO                    VARCHAR(10)
        COMMENT 'Sold-to customer reference',
    CUSTOMER_SALES                  VARCHAR(10)
        COMMENT 'Customer sales record reference',
    CUSTHIER_LEVEL                  VARCHAR(10)
        COMMENT 'Customer hierarchy level',
    COUNTRYCUSTHIER4                VARCHAR(10)
        COMMENT 'Country customer hierarchy level 4',
    CUSTOMERHIERARCHYASPOSTED03     VARCHAR(18)
        COMMENT 'Customer hierarchy level 3 as originally posted',
    CUSTOMERHIERARCHYASPOSTED04     VARCHAR(18)
        COMMENT 'Customer hierarchy level 4 as originally posted',
    CUSTOMERHIERARCHYASPOSTED05     VARCHAR(18)
        COMMENT 'Customer hierarchy level 5 as originally posted',
    CUSTOMERHIERARCHYASPOSTED06     VARCHAR(18)
        COMMENT 'Customer hierarchy level 6 as originally posted',
    CL3                             VARCHAR(18)
        COMMENT 'Customer level 3 (realigned)',
    CL4                             VARCHAR(18)
        COMMENT 'Customer level 4 (realigned)',
    CL5                             VARCHAR(18)
        COMMENT 'Customer level 5 (realigned)',
    CL6                             VARCHAR(18)
        COMMENT 'Customer level 6 (realigned)',
    SALESCREDITASPOSTED             VARCHAR(20)
        COMMENT 'Sales credit as originally posted',
    SALESCREDITASREALIGNED          VARCHAR(20)
        COMMENT 'Sales credit after realignment',
    SALESCHANNELASPOSTED            VARCHAR(20)
        COMMENT 'Sales channel as originally posted',
    SALESCHANNELASREALIGNED         VARCHAR(20)
        COMMENT 'Sales channel after realignment',
    LOCALSALESCHANNEL               VARCHAR(20)
        COMMENT 'Local sales channel code',
    CUSTOMERCHANNELASPOSTED         VARCHAR(20)
        COMMENT 'Customer channel as originally posted',
    CUSTOMERCHANNELASREALIGNED      VARCHAR(20)
        COMMENT 'Customer channel after realignment',

    -- ── PRODUCT DIMENSIONS ────────────────────────────────────────────────
    MATERIAL                        VARCHAR(18)
        COMMENT 'SAP material number — maps to DIM_PRODUCT.MATERIAL',
    PRODUCT_NAME                    VARCHAR(100)
        COMMENT 'Full product name (denormalised from DIM_PRODUCT for agent readability)',
    BRAND                           VARCHAR(20)
        COMMENT 'BSH brand (denormalised): BOSCH | SIEMENS | GAGGENAU | NEFF | THERMADOR',
    CATEGORY                        VARCHAR(30)
        COMMENT 'Product category (denormalised): COOKING | LAUNDRY_CARE | DISH_CARE | COOLING | CONSUMER_PRODUCTS',
    SUBCATEGORY                     VARCHAR(50)
        COMMENT 'Product sub-category (denormalised, e.g. "Dishwasher Fully Integrated")',
    PRODUCT_TIER                    VARCHAR(10)
        COMMENT 'Product positioning tier (denormalised): PREMIUM | MID | ENTRY',
    BASEPRODUCT                     VARCHAR(18)
        COMMENT 'SAP base product code',
    UNIT                            VARCHAR(3)
        COMMENT 'SAP material unit of measure',
    ECPRODUCTTYPEASPOSTED           VARCHAR(20)
        COMMENT 'EC product type as originally posted',
    ECPRODUCTTYPEASREALIGNED        VARCHAR(20)
        COMMENT 'EC product type after realignment',
    ECPRODUCTGROUPASPOSTED          VARCHAR(20)
        COMMENT 'EC product group as originally posted',
    ECPRODUCTGROUPASREALIGNED       VARCHAR(20)
        COMMENT 'EC product group after realignment',
    ECPRODUCTCATEGORYASPOSTED       VARCHAR(20)
        COMMENT 'EC product category as originally posted',
    ECPRODUCTCATEGORYASREALIGNED    VARCHAR(20)
        COMMENT 'EC product category after realignment',
    CORPORATEBRANDASPOSTED          VARCHAR(20)
        COMMENT 'Corporate brand as originally posted',
    CORPORATEBRANDASREALIGNED       VARCHAR(20)
        COMMENT 'Corporate brand after realignment',
    RANGEBRANDASPOSTED              VARCHAR(20)
        COMMENT 'Range brand as originally posted',
    RANGEBRANDASREALIGNED           VARCHAR(20)
        COMMENT 'Range brand after realignment',
    CORPORATEBRAND                  VARCHAR(20)
        COMMENT 'Corporate brand code (current, same as BRAND)',
    RANGEBRAND                      VARCHAR(20)
        COMMENT 'Range brand code (current)',
    BRANDDENOMINATION               VARCHAR(40)
        COMMENT 'Brand denomination description',
    LOCALPRODUCTHIGH                VARCHAR(18)
        COMMENT 'Local product hierarchy — high level',
    LOCALPRODUCTLOW                 VARCHAR(18)
        COMMENT 'Local product hierarchy — low level',
    LOCALPRODUCTMIDDLE              VARCHAR(18)
        COMMENT 'Local product hierarchy — mid level',

    -- ── QUANTITIES ────────────────────────────────────────────────────────
    SALESVOLUME                     NUMBER(18,3)
        COMMENT 'Units sold — populated on REVENUE lines (ACDOCA_RACCT=0800000) only. Derived as HSL / LIST_PRICE_EUR. Used for avg selling price metric.',
    LIST_PRICE_EUR                  NUMBER(10,2)
        COMMENT 'Published list price in EUR (denormalised from DIM_PRODUCT). Used in AVG_SELLING_PRICE_EUR metric.',
    SALESVOLUME3000                 NUMBER(18,3)
        COMMENT 'Sales volume (CO-PA value field 3000)',
    INDQTY6210                      NUMBER(18,3)
        COMMENT 'Industrial quantity (CO-PA value field 6210)',
    QUANTITY                        NUMBER(18,3)
        COMMENT 'Transaction quantity',
    UNITOFMEASURE                   VARCHAR(3)
        COMMENT 'Unit of measure for transaction quantity',
    BASEQUANTITY                    NUMBER(18,3)
        COMMENT 'Base quantity',

    -- ── DOCUMENT CONTROL ──────────────────────────────────────────────────
    OBJECTTYPE                      VARCHAR(10)
        COMMENT 'SAP CO object type',
    BILLINGTYPE                     VARCHAR(4)
        COMMENT 'Billing document type: F2=Invoice, G2=Credit Note, RE=Return',
    ORIGINGROUP                     VARCHAR(4)
        COMMENT 'SAP origin group',
    SALESORDER                      VARCHAR(20)
        COMMENT 'Sales order number (synthetic: SO-XXXXXXXX)',
    VERSION                         VARCHAR(3)
        COMMENT 'Plan/actual version: 000=Actuals, 001=Budget, 002=Latest Estimate',
    RECORDTYPE                      VARCHAR(2)
        COMMENT 'SAP record type: 00=Actuals posting, F=Billing document',
    SPECIALSCENARIO                 VARCHAR(10)
        COMMENT 'Special scenario flag (intercompany, sample, etc.)',
    SPECIALSCENARIO_ID              VARCHAR(10)
        COMMENT 'Special scenario identifier',
    BUSINESS_TRANSACTION_CATEGORY   VARCHAR(10)
        COMMENT 'Business transaction category',
    NON_GLOBE                       VARCHAR(1)
        COMMENT 'Non-GLOBE indicator: Y=excluded from global reporting',
    MARKETCHARACT1                  VARCHAR(20)
        COMMENT 'Market characteristic dimension 1',
    MARKETCHARACT2                  VARCHAR(20)
        COMMENT 'Market characteristic dimension 2',
    MARKETCHARACT3                  VARCHAR(20)
        COMMENT 'Market characteristic dimension 3',

    -- ── TIMESTAMPS ────────────────────────────────────────────────────────
    LASTUPDATE_TS_REPORTING         TIMESTAMP_LTZ(9)
        COMMENT 'Last update timestamp for reporting refresh tracking',
    CFIN_TS_DELTA                   TIMESTAMP_LTZ(9)
        COMMENT 'Central Finance delta timestamp — tracks source system change events'

)
COMMENT = 'BSH Group PnL fact table — ACDOCA/CO-PA profitability analysis structure. ~100K rows, Jan 2023–Sep 2026 (2026 partial). CLIENT_ID=BSH on all rows. Row Access Policy enforces CLIENT_ID + REGION isolation per role. Follows the Nestlé DefinePnLTable.txt template with BSH-specific extensions.';

-- ─────────────────────────────────────────────────────────────────────────────
-- Apply the Row Access Policy (created in 03_rbac.sql)
-- The policy fires on every SELECT — the Semantic View inherits this automatically.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE S3_FINANCE_PNL
    ADD ROW ACCESS POLICY PNL_CLIENT_ISOLATION_POLICY ON (CLIENT_ID, REGION);

-- Grant SELECT to leaf demo roles (parent roles inherit via hierarchy)
GRANT SELECT ON TABLE S3_FINANCE_PNL TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE S3_FINANCE_PNL TO ROLE BSH_NA_DEMO_ROLE;
GRANT SELECT ON TABLE S3_FINANCE_PNL TO ROLE BSH_APAC_DEMO_ROLE;
-- Grant INSERT/TRUNCATE to the CI/CD service role for data refresh runs
GRANT INSERT, TRUNCATE ON TABLE S3_FINANCE_PNL TO ROLE BSH_DATA_DEPLOY_ROLE;

-- Confirm table was created with RAP applied
DESCRIBE TABLE S3_FINANCE_PNL;
