-- =============================================================================
-- 11_bdc_l1_schema_and_catalog.sql — SAP BDC Product Catalog + L1 Schema
--
-- Sets up the control-plane objects for mapping SAP BDC data products into
-- catalog-linked databases (CLDs) and clean L1 views on top of them.
--
-- This does NOT create the zero-copy connector itself. A CONNECTED connector
-- to SAP BDC must already exist in the target account before running
-- 12_bdc_discover_shares.sql or 13_bdc_mount_clds.sql (see the
-- manage-zerocopy-sapbdc skill / SAP for Me enrollment for connector setup).
--
-- This script only registers WHICH 14 SAP BDC data products this gold layer
-- (S3_FINANCE_PNL_MDR) needs, and WHERE their raw CLDs / clean views will
-- land once mounted. Safe to re-run — MERGE ... WHEN NOT MATCHED never
-- overwrites CONFIRMED_SHARE_NAME or other fields a human has already filled
-- in on a later run.
--
-- Naming convention:
--   CLD database  : zzbdcL0_<PRODUCT_KEY>     — raw landing layer, one per BDC data product
--   L1 view       : <db_name>.L1.<VIEW_NAME>  — one stable, renamed view per root entity
--
-- Source of truth for this seed data: runbooks/sap_bdc_lineage.md, which
-- verified every PRODUCT_KEY / PRIMARY_KEY_FIELDS / ROOT_CDS_VIEW value below
-- directly against the SAP BDC CSN content (not naming convention alone).
--
-- Variables:
--   <% db_name %>  — target database (default: S4)
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER('<% db_name %>');

-- L1 schema — houses only the clean views over mounted BDC CLDs.
-- Control/log tables live in FIN alongside the rest of the demo's metadata;
-- L1 is reserved for the views gold-layer joins should actually reference.
CREATE SCHEMA IF NOT EXISTS L1
    COMMENT = 'Layer 1 — stable views over raw SAP BDC catalog-linked databases (zzbdcL0_*). Gold-layer joins should reference these views, not the raw CLDs directly.';

USE SCHEMA FIN;

-- -----------------------------------------------------------------------------
-- BDC_PRODUCT_CATALOG — one row per SAP BDC data product this gold layer needs
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS BDC_PRODUCT_CATALOG (
    PRODUCT_KEY              VARCHAR(60)   NOT NULL
                             COMMENT 'Stable key. CLD database will be zzbdcL0_<PRODUCT_KEY>.',
    CSN_FILE                 VARCHAR(200)
                             COMMENT 'SAP BDC CSN schema file this product corresponds to (documentation only).',
    ROOT_CDS_VIEW            VARCHAR(200)
                             COMMENT 'Root S/4HANA CDS view name(s) backing this product (documentation only, verified via @EndUserText.label i18n key).',
    PRIMARY_KEY_FIELDS       VARCHAR(500)
                             COMMENT 'Primary key field(s) on the root entity, verified against [key]-tagged fields in the CSN.',
    GOLD_LAYER_FK_NOTE       VARCHAR(1000)
                             COMMENT 'Which S3_FINANCE_PNL_MDR columns this product hydrates and how it joins.',
    SUGGESTED_SHARE_PATTERN  VARCHAR(200)
                             COMMENT 'Best-guess ILIKE pattern used by the discovery script to suggest a share_name match. Not authoritative — SAP share display names include tenant-specific technical suffixes that cannot be predicted from the CSN.',
    CONFIRMED_SHARE_NAME     VARCHAR(500)
                             COMMENT 'Exact share_name from SYSTEM$ZEROCOPY_CONNECTOR_LIST_SHARES, filled in by a human after reviewing discovery output (see runbooks/bdc_confirm_share.sql). NULL = not yet confirmed; the mount script skips these.',
    CLD_DATABASE_NAME        VARCHAR(200)
                             COMMENT 'Set by the mount script once the CLD is created. Always zzbdcL0_<PRODUCT_KEY> by convention.',
    LAST_MOUNTED_AT          TIMESTAMP_LTZ
                             COMMENT 'Timestamp of the last successful CREATE DATABASE ... LINKED_ZEROCOPY_CONNECTOR for this product.',
    CONSTRAINT PK_BDC_PRODUCT_CATALOG PRIMARY KEY (PRODUCT_KEY)
)
COMMENT = 'Registry of SAP BDC data products required to hydrate S3_FINANCE_PNL_MDR. Seeded from runbooks/sap_bdc_lineage.md — every field was verified against the SAP BDC CSN content, not asserted from naming convention.';

MERGE INTO BDC_PRODUCT_CATALOG t
USING (
    SELECT * FROM VALUES
    ('ENTRY_VIEW_JOURNAL_ENTRY',
     'sap-s4com-EntryViewJournalEntry-v1.csn.json',
     'I_OperationalAcctgDocItem',
     'CompanyCode, AccountingDocument, FiscalYear, AccountingDocumentItem',
     'Grain of S3_FINANCE_PNL_MDR. Sources HSL, ACDOCA_RACCT, COMPANYCODE, CONTROLLINGAREA, COSTCENTER, PARTNERPROFITCTR, PLANT, CUSTOMER, MATERIAL, PRODUCT, and the currency amount fields.',
     '%Journal Entry Item%'),
    ('JOURNAL_ENTRY_HEADER',
     'sap-s4com-JournalEntryHeader-v1.csn.json',
     'I_JournalEntry',
     'CompanyCode, FiscalYear, AccountingDocument',
     'Sources MONTHYEAR, FISCALYEAR, POSTINGPERIOD, POSTINGDATE, LEDGER. Joins to the item entity on CompanyCode+FiscalYear+AccountingDocument.',
     '%Journal Entry%'),
    ('GENERAL_LEDGER_ACCOUNT',
     'sap-s4com-GeneralLedgerAccount-v1.csn.json',
     'I_GLAccountInChartOfAccounts / I_ChartOfAccounts',
     'ChartOfAccounts, GLAccount',
     'Sources ACDOCA_RACCT master/hierarchy. Join: ChartOfAccounts+GLAccount.',
     '%General Ledger Account%'),
    ('CONTROLLING_AREA',
     'sap-s4com-ControllingArea-v1.csn.json',
     'I_ControllingArea',
     'ControllingArea',
     'Sources CONTROLLINGAREA master. Join: ControllingArea.',
     '%Controlling Area%'),
    ('COST_CENTER',
     'sap-s4com-CostCenter-v1.csn.json',
     'I_CostCenter',
     'ControllingArea, CostCenter, ValidityEndDate',
     'Sources COSTCENTER, ORIGINCCTR master (incl. hierarchy). Join: ControllingArea+CostCenter.',
     '%Cost Center%'),
    ('PROFIT_CENTER',
     'sap-s4com-ProfitCenter-v1.csn.json',
     'I_ProfitCenter',
     'ControllingArea, ProfitCenter, ValidityEndDate',
     'Sources PARTNERPROFITCTR master. Join: ControllingArea+ProfitCenter.',
     '%Profit Center%'),
    ('CUSTOMER',
     'sap-s4com-Customer-v1.csn.json',
     'I_Customer',
     'Customer',
     'Sources CUSTOMER, SHIPTOPARTY, CUSTOMERGROUP, CUST_SOLD_TO. Join: Customer.',
     '%Customer%'),
    ('PRODUCT',
     'sap-s4com-Product-v1.csn.json',
     'I_Product',
     'Product',
     'Sources MATERIAL, BASEPRODUCT, UNIT, current CORPORATEBRAND/RANGEBRAND. Join: Product.',
     '%Product%'),
    ('CNSLDTN_MATERIAL',
     'sap-s4com-CnsldtnMaterial-v1.csn.json',
     'I_CnsldtnMaterial',
     'Material',
     'Consolidated material view, material group. Join: Material.',
     '%Material%'),
    ('PLANT',
     'sap-s4com-Plant-v1.csn.json',
     'I_Plant',
     'Plant',
     'Sources PLANT master. Join: Plant.',
     '%Plant%'),
    ('FUNCTIONAL_AREA',
     'sap-s4com-FunctionalArea-v1.csn.json',
     'I_FunctionalArea',
     'FunctionalArea',
     'Sources FUNCTIONALAREA master. Join: FunctionalArea.',
     '%Functional Area%'),
    ('SALES_ORGANIZATIONAL_STRUCTURE',
     'sap-s4com-SalesOrganizationalStructure-v1.csn.json',
     'I_SalesOrganization / I_DistributionChannel (+ ~18 more sub-views)',
     'SalesOrganization / DistributionChannel (independent keys per sub-entity)',
     'Sources SALESORGANISATION, DISTRIBUTIONCHANNEL, SALESDISTRICT. NOTE: not a direct FK from the journal entry item — only reachable via SalesOrder.SalesOrganization/DistributionChannel.',
     '%Sales Organi%'),
    ('SALES_ORDER',
     'sap-s4com-SalesOrder-v1.csn.json',
     'I_SalesOrder',
     'SalesOrder',
     'Sources SALESORDER; the only path from the journal item to SalesOrganization/DistributionChannel. Join: SalesDocument.',
     '%Sales Order%'),
    ('BILLING_DOCUMENT',
     'sap-s4com-BillingDocument-v1.csn.json',
     'I_BillingDocument',
     'BillingDocument',
     'Sources BILLINGTYPE, billing document reference. Join: BillingDocument.',
     '%Billing Document%'),
    ('HANA_CURRENCY',
     'sap-s4com-HANACurrency-v1.csn.json',
     'I_Currency (TCURC) — bundle also includes I_CurrencyText, I_ExchangeRateType, I_ExchangeRateRawData',
     'WAERS',
     'Sources CURRENCY, CURRENCYUNIT, CURRENCYTYPE. Join is on VALUE (TransactionCurrency/CompanyCodeCurrency), not a shared field name — see Section 5 (currency analysis) in sap_bdc_lineage.md before aggregating.',
     '%Currency%')
) AS s(PRODUCT_KEY, CSN_FILE, ROOT_CDS_VIEW, PRIMARY_KEY_FIELDS, GOLD_LAYER_FK_NOTE, SUGGESTED_SHARE_PATTERN)
ON t.PRODUCT_KEY = s.PRODUCT_KEY
WHEN NOT MATCHED THEN
    INSERT (PRODUCT_KEY, CSN_FILE, ROOT_CDS_VIEW, PRIMARY_KEY_FIELDS, GOLD_LAYER_FK_NOTE, SUGGESTED_SHARE_PATTERN)
    VALUES (s.PRODUCT_KEY, s.CSN_FILE, s.ROOT_CDS_VIEW, s.PRIMARY_KEY_FIELDS, s.GOLD_LAYER_FK_NOTE, s.SUGGESTED_SHARE_PATTERN);

-- -----------------------------------------------------------------------------
-- BDC_L1_VIEW_MAP — one row per L1 view to build on top of a mounted CLD.
-- Most products map 1:1 to a view; GENERAL_LEDGER_ACCOUNT and
-- SALES_ORGANIZATIONAL_STRUCTURE each need two, since their CLD bundles
-- multiple entities that matter to the gold layer.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS BDC_L1_VIEW_MAP (
    PRODUCT_KEY          VARCHAR(60)   NOT NULL
                         COMMENT 'FK to BDC_PRODUCT_CATALOG.PRODUCT_KEY.',
    VIEW_NAME            VARCHAR(60)   NOT NULL
                         COMMENT 'Final view is <db_name>.L1.<VIEW_NAME>.',
    ROOT_ENTITY_PATTERN  VARCHAR(200)
                         COMMENT 'Table name (or LIKE pattern) inside the CLD this view is built from. The mount script requires an exact single match before creating the view — it will not guess.',
    MATCHED_TABLE_FQN    VARCHAR(500)
                         COMMENT 'Fully-qualified table the mount script actually matched. NULL until resolved.',
    LAST_REFRESHED_AT    TIMESTAMP_LTZ
                         COMMENT 'Timestamp the view was last (re)created.',
    CONSTRAINT PK_BDC_L1_VIEW_MAP PRIMARY KEY (VIEW_NAME)
)
COMMENT = 'One row per L1 view to build on top of a mounted BDC CLD root entity table.';

MERGE INTO BDC_L1_VIEW_MAP t
USING (
    SELECT * FROM VALUES
    ('ENTRY_VIEW_JOURNAL_ENTRY',       'JOURNAL_ENTRY_ITEM',    'OperationalAcctgDocItem'),
    ('JOURNAL_ENTRY_HEADER',           'JOURNAL_ENTRY_HEADER',  'JournalEntry'),
    ('GENERAL_LEDGER_ACCOUNT',         'GL_ACCOUNT',            'GLAccountInChartOfAccounts'),
    ('GENERAL_LEDGER_ACCOUNT',         'CHART_OF_ACCOUNTS',     'ChartOfAccounts'),
    ('CONTROLLING_AREA',               'CONTROLLING_AREA',      'ControllingArea'),
    ('COST_CENTER',                    'COST_CENTER',           'CostCenter'),
    ('PROFIT_CENTER',                  'PROFIT_CENTER',         'ProfitCenter'),
    ('CUSTOMER',                       'CUSTOMER',              'Customer'),
    ('PRODUCT',                        'PRODUCT',               'Product'),
    ('CNSLDTN_MATERIAL',               'MATERIAL',              'CnsldtnMaterial'),
    ('PLANT',                          'PLANT',                 'Plant'),
    ('FUNCTIONAL_AREA',                'FUNCTIONAL_AREA',       'FunctionalArea'),
    ('SALES_ORGANIZATIONAL_STRUCTURE', 'SALES_ORGANIZATION',    'SalesOrganization'),
    ('SALES_ORGANIZATIONAL_STRUCTURE', 'DISTRIBUTION_CHANNEL',  'DistributionChannel'),
    ('SALES_ORDER',                    'SALES_ORDER',           'SalesOrder'),
    ('BILLING_DOCUMENT',               'BILLING_DOCUMENT',      'BillingDocument'),
    ('HANA_CURRENCY',                  'CURRENCY',              'TCURC')
) AS s(PRODUCT_KEY, VIEW_NAME, ROOT_ENTITY_PATTERN)
ON t.VIEW_NAME = s.VIEW_NAME
WHEN NOT MATCHED THEN
    INSERT (PRODUCT_KEY, VIEW_NAME, ROOT_ENTITY_PATTERN)
    VALUES (s.PRODUCT_KEY, s.VIEW_NAME, s.ROOT_ENTITY_PATTERN);

-- -----------------------------------------------------------------------------
-- BDC_CLD_MOUNT_LOG — append-only audit log written by the mount procedures
-- in 13_bdc_mount_clds.sql. Never truncated automatically.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS BDC_CLD_MOUNT_LOG (
    LOG_ID       NUMBER AUTOINCREMENT,
    RAN_AT       TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    STAGE        VARCHAR(20)   COMMENT 'CLD or VIEW.',
    PRODUCT_KEY  VARCHAR(60),
    VIEW_NAME    VARCHAR(60),
    STATUS       VARCHAR(20)   COMMENT 'CREATED, ALREADY_EXISTS, SKIPPED, FAILED.',
    DETAIL       VARCHAR(2000),
    CONSTRAINT PK_BDC_CLD_MOUNT_LOG PRIMARY KEY (LOG_ID)
)
COMMENT = 'Append-only audit log of CLD mount and L1 view creation attempts. Never automatically cleared.';

-- ==============================================================================
-- Confirmation
-- ==============================================================================
SELECT 'BDC catalog ready.' AS status,
       (SELECT COUNT(*) FROM BDC_PRODUCT_CATALOG) AS products_registered,
       (SELECT COUNT(*) FROM BDC_L1_VIEW_MAP)     AS views_planned,
       (SELECT COUNT(*) FROM BDC_PRODUCT_CATALOG WHERE CONFIRMED_SHARE_NAME IS NOT NULL) AS shares_confirmed_so_far;

SELECT PRODUCT_KEY, ROOT_CDS_VIEW, PRIMARY_KEY_FIELDS, CONFIRMED_SHARE_NAME, CLD_DATABASE_NAME
FROM BDC_PRODUCT_CATALOG
ORDER BY PRODUCT_KEY;
