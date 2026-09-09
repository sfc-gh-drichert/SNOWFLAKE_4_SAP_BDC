-- =============================================================================
-- 02_dimensions.sql — Reference / Dimension Tables
--
-- Creates and populates all dimension tables used by the BSH PnL fact table:
--   DIM_GL_ACCOUNT   — PnL line classification (13 rows)
--   DIM_PRODUCT      — Real BSH product SKUs with model numbers (~52 rows)
--   DIM_CUSTOMER     — Major retail and trade customers (44 rows)
--   DIM_COMPANY      — SAP company codes / legal entities (6 rows)
--   DIM_PLANT        — BSH manufacturing plants worldwide (8 rows)
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. GL ACCOUNT DIMENSION
--    Maps SAP GL account numbers to PnL categories used in the semantic view.
--    PNL_CATEGORY drives all metric calculations (GROSS_PROFIT, DB1, DB2, EBIT).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_GL_ACCOUNT (
    ACDOCA_RACCT     VARCHAR(10)   NOT NULL PRIMARY KEY
                     COMMENT 'SAP GL account number — primary key into ACDOCA',
    GL_DESCRIPTION   VARCHAR(100)
                     COMMENT 'Human-readable account description',
    PNL_CATEGORY     VARCHAR(30)
                     COMMENT 'PnL category used in semantic view metrics: REVENUE | TRADE_SPEND | RETURNS | COGS | LOGISTICS | BRAND_ADP | SALES | RD | GA',
    PNL_LEVEL        VARCHAR(10)
                     COMMENT 'First PnL level where this account appears: TOP=before Net Revenue, MC1=before DB1, MC2=before DB2, MC3=before EBIT',
    IS_CREDIT_NORMAL BOOLEAN
                     COMMENT 'TRUE = revenue account (credit balance = positive HSL); FALSE = cost account (debit balance = negative HSL)'
)
COMMENT = 'SAP GL account master — maps account numbers to PnL waterfall categories';

INSERT INTO DIM_GL_ACCOUNT VALUES
-- Revenue
('0800000', 'Gross Revenue — Product Sales',           'REVENUE',    'TOP',  TRUE),
-- Trade deductions (reduce gross revenue to arrive at net revenue)
('0810000', 'Customer Price Reductions & Rebates',     'TRADE_SPEND','TOP',  FALSE),
('0810100', 'Volume Bonuses & Listing Fees',           'TRADE_SPEND','TOP',  FALSE),
('0820000', 'Returns & Credit Notes',                  'RETURNS',    'TOP',  FALSE),
-- Cost of Goods Sold (drives Gross Profit)
('0500000', 'Cost of Material — Standard',             'COGS',       'MC1',  FALSE),
('0510000', 'Manufacturing Labour & Assembly',         'COGS',       'MC1',  FALSE),
('0520000', 'Manufacturing Overhead & Depreciation',   'COGS',       'MC1',  FALSE),
('0530000', 'Outbound Logistics & Freight',            'LOGISTICS',  'MC1',  FALSE),
-- Brand investment (drives DB1 → DB2)
('0600000', 'Brand Advertising & Media Spend',         'BRAND_ADP',  'MC2',  FALSE),
('0610000', 'Trade Marketing & Customer Activation',   'BRAND_ADP',  'MC2',  FALSE),
('0620000', 'Sales Force & Key Account Management',    'SALES',      'MC2',  FALSE),
-- Overhead (drives DB2 → EBIT)
('0700000', 'Research & Development',                  'RD',         'MC3',  FALSE),
('0710000', 'General & Administrative Expenses',       'GA',         'MC3',  FALSE);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. PRODUCT DIMENSION
--    Real BSH model numbers across all five brands and five categories.
--    LIST_PRICE_EUR is used to calculate average selling price in the SV.
--    Note: Gaggenau/Neff/Thermador are category-specialist brands — they do
--    not cover all five categories (this is intentional and realistic).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_PRODUCT (
    MATERIAL         VARCHAR(18)   NOT NULL PRIMARY KEY
                     COMMENT 'BSH internal material number (maps to SAP MATNR)',
    PRODUCT_NAME     VARCHAR(100)
                     COMMENT 'Full product name including brand and series',
    BRAND            VARCHAR(20)
                     COMMENT 'BSH brand: BOSCH | SIEMENS | GAGGENAU | NEFF | THERMADOR',
    CATEGORY         VARCHAR(30)
                     COMMENT 'Product category: COOKING | LAUNDRY_CARE | DISH_CARE | COOLING | CONSUMER_PRODUCTS',
    SUBCATEGORY      VARCHAR(50)
                     COMMENT 'Product sub-category (appliance type)',
    LIST_PRICE_EUR   NUMBER(10,2)
                     COMMENT 'Published retail list price in EUR',
    PRODUCT_TIER     VARCHAR(10)
                     COMMENT 'Positioning tier: PREMIUM | MID | ENTRY',
    ENERGY_RATING    VARCHAR(5)
                     COMMENT 'EU energy efficiency class (A, B, C, E or NULL for non-rated)'
)
COMMENT = 'BSH product catalogue — ~52 real SKUs with model numbers, covers all brands and categories';

INSERT INTO DIM_PRODUCT VALUES
-- ── BOSCH — DISH CARE ──────────────────────────────────────────────────────
('BSH-DW-B8000', 'Bosch Serie 8 SMS8YCX02G PerfectDry',               'BOSCH',    'DISH_CARE',        'Dishwasher Freestanding',        999.00,  'PREMIUM', 'A'),
('BSH-DW-B6000', 'Bosch Serie 6 SMV6ZCX00E PerfectDry Integrated',    'BOSCH',    'DISH_CARE',        'Dishwasher Fully Integrated',    799.00,  'MID',     'A'),
('BSH-DW-B4000', 'Bosch Serie 4 SMS4HVW31E',                          'BOSCH',    'DISH_CARE',        'Dishwasher Freestanding',        549.00,  'MID',     'E'),
('BSH-DW-B2000', 'Bosch Serie 2 SMS2ITI11E',                          'BOSCH',    'DISH_CARE',        'Dishwasher Freestanding',        349.00,  'ENTRY',   'E'),
-- ── BOSCH — LAUNDRY CARE ────────────────────────────────────────────────────
('BSH-WM-B8100', 'Bosch Serie 8 WGB254A0GB EcoSilence 10kg',          'BOSCH',    'LAUNDRY_CARE',     'Washing Machine Front Load',    1199.00, 'PREMIUM', 'A'),
('BSH-WM-B6100', 'Bosch Serie 6 WAU28PHSGES 9kg',                     'BOSCH',    'LAUNDRY_CARE',     'Washing Machine Front Load',     699.00,  'MID',     'A'),
('BSH-WM-B4100', 'Bosch Serie 4 WAN28080GB 8kg',                      'BOSCH',    'LAUNDRY_CARE',     'Washing Machine Front Load',     499.00,  'ENTRY',   'B'),
('BSH-TD-B8100', 'Bosch Serie 8 WTX87MH9GB Heat Pump Dryer 9kg',      'BOSCH',    'LAUNDRY_CARE',     'Tumble Dryer Heat Pump',         999.00,  'PREMIUM', 'A'),
-- ── BOSCH — COOKING ─────────────────────────────────────────────────────────
('BSH-OV-B8000', 'Bosch Serie 8 HBG7784B1B Pyrolytic',                'BOSCH',    'COOKING',          'Built-in Oven Pyrolytic',       1299.00, 'PREMIUM', 'A'),
('BSH-OV-B6000', 'Bosch Serie 6 HRS578BS6B Steam Oven',               'BOSCH',    'COOKING',          'Built-in Steam Oven',            999.00,  'MID',     'A'),
('BSH-OV-B4000', 'Bosch Serie 4 HBA172BS1',                           'BOSCH',    'COOKING',          'Built-in Oven',                  449.00,  'ENTRY',   'A'),
('BSH-IH-B6000', 'Bosch Serie 6 PXE675DC1E FlexInduction 60cm',       'BOSCH',    'COOKING',          'Induction Hob 60cm',             549.00,  'MID',     NULL),
-- ── BOSCH — COOLING ─────────────────────────────────────────────────────────
('BSH-FF-B8000', 'Bosch Serie 8 KAN93AAIFP FrenchDoor 590L',          'BOSCH',    'COOLING',          'French Door Refrigerator',      1499.00, 'PREMIUM', 'C'),
('BSH-FF-B6000', 'Bosch Serie 6 KGN86AIDP NoFrost 631L',              'BOSCH',    'COOLING',          'Fridge Freezer NoFrost',        1199.00, 'MID',     'C'),
('BSH-FF-B4000', 'Bosch Serie 4 KGV58VLEAS NoFrost',                  'BOSCH',    'COOLING',          'Fridge Freezer Combi',           649.00,  'ENTRY',   'E'),
-- ── BOSCH — CONSUMER PRODUCTS ───────────────────────────────────────────────
('BSH-CF-B8000', 'Bosch VeroBar AromaPro CTL636ES6 1.4L',             'BOSCH',    'CONSUMER_PRODUCTS','Fully Automatic Coffee Machine', 1199.00, 'PREMIUM', NULL),
('BSH-CF-B6000', 'Bosch VeroCafe Plus TIS65621GB',                    'BOSCH',    'CONSUMER_PRODUCTS','Fully Automatic Coffee Machine',  799.00,  'MID',     NULL),
('BSH-VC-B6000', 'Bosch BCS122GB Unlimited 7 Cordless Vacuum',        'BOSCH',    'CONSUMER_PRODUCTS','Cordless Vacuum Cleaner',         299.00,  'MID',     NULL),
-- ── SIEMENS — DISH CARE ─────────────────────────────────────────────────────
('BSH-DW-S7000', 'Siemens iQ700 SN63HX01BE Fully Integrated',         'SIEMENS',  'DISH_CARE',        'Dishwasher Fully Integrated',    849.00,  'PREMIUM', 'A'),
('BSH-DW-S5000', 'Siemens iQ500 SN55ES16ME',                          'SIEMENS',  'DISH_CARE',        'Dishwasher Freestanding',        599.00,  'MID',     'B'),
('BSH-DW-S3000', 'Siemens iQ300 SN43ES14ME',                          'SIEMENS',  'DISH_CARE',        'Dishwasher Freestanding',        449.00,  'ENTRY',   'E'),
-- ── SIEMENS — LAUNDRY CARE ──────────────────────────────────────────────────
('BSH-WM-S7100', 'Siemens iQ700 WG52A2X0GB 10kg',                     'SIEMENS',  'LAUNDRY_CARE',     'Washing Machine Front Load',     849.00,  'PREMIUM', 'A'),
('BSH-WM-S5100', 'Siemens iQ500 WM14N093GB 9kg',                      'SIEMENS',  'LAUNDRY_CARE',     'Washing Machine Front Load',     699.00,  'MID',     'A'),
('BSH-TD-S7100', 'Siemens iQ700 WT47W5W0 Heat Pump Dryer 9kg',        'SIEMENS',  'LAUNDRY_CARE',     'Tumble Dryer Heat Pump',         949.00,  'PREMIUM', 'A'),
-- ── SIEMENS — COOKING ───────────────────────────────────────────────────────
('BSH-OV-S9000', 'Siemens studioLine HS858GXS6B',                     'SIEMENS',  'COOKING',          'Built-in Oven Premium',         1499.00, 'PREMIUM', 'A'),
('BSH-OV-S7000', 'Siemens iQ700 HB578GBS6B Pyrolytic',                'SIEMENS',  'COOKING',          'Built-in Oven Pyrolytic',       1199.00, 'MID',     'A'),
('BSH-IH-S7000', 'Siemens EX977KXX1E flexInduction 90cm',             'SIEMENS',  'COOKING',          'Induction Hob 90cm',             999.00,  'MID',     NULL),
-- ── SIEMENS — COOLING ───────────────────────────────────────────────────────
('BSH-FF-S7000', 'Siemens iQ700 KF96NAXEA FrenchDoor',                'SIEMENS',  'COOLING',          'French Door Refrigerator',      1699.00, 'PREMIUM', 'C'),
('BSH-FF-S5000', 'Siemens iQ500 KG49NXWEP NoFrost',                   'SIEMENS',  'COOLING',          'Fridge Freezer NoFrost',         799.00,  'MID',     'C'),
-- ── SIEMENS — CONSUMER PRODUCTS ─────────────────────────────────────────────
('BSH-CF-S9000', 'Siemens EQ900 TQ907D03 Fully Automatic',            'SIEMENS',  'CONSUMER_PRODUCTS','Fully Automatic Coffee Machine', 1299.00, 'PREMIUM', NULL),
('BSH-CF-S7000', 'Siemens EQ700 TQ703R07',                            'SIEMENS',  'CONSUMER_PRODUCTS','Fully Automatic Coffee Machine',  999.00,  'MID',     NULL),
-- ── GAGGENAU — COOKING (premium/luxury only) ────────────────────────────────
('BSH-OV-G4800', 'Gaggenau BO480112 Combi-Steam Oven 60cm',           'GAGGENAU', 'COOKING',          'Built-in Combi Steam Oven',     3800.00, 'PREMIUM', 'A'),
('BSH-OV-G4700', 'Gaggenau BS470112 Steam Oven 60cm',                 'GAGGENAU', 'COOKING',          'Built-in Steam Oven',           3200.00, 'PREMIUM', 'A'),
('BSH-IH-G4820', 'Gaggenau CX482101 Full Surface Induction',          'GAGGENAU', 'COOKING',          'Full Surface Induction Hob',    4500.00, 'PREMIUM', NULL),
('BSH-IH-G4250', 'Gaggenau VG425211 Vario Gas Cooktop',               'GAGGENAU', 'COOKING',          'Gas Cooktop',                   2800.00, 'PREMIUM', NULL),
-- ── GAGGENAU — COOLING ──────────────────────────────────────────────────────
('BSH-RF-G4920', 'Gaggenau RC492304 Vario Refrigerator Column 212L',  'GAGGENAU', 'COOLING',          'Vario Refrigerator Column',     4200.00, 'PREMIUM', 'C'),
('BSH-FZ-G4910', 'Gaggenau RF491300 Vario Freezer Column 212L',       'GAGGENAU', 'COOLING',          'Vario Freezer Column',          3800.00, 'PREMIUM', 'C'),
-- ── GAGGENAU — DISH CARE ────────────────────────────────────────────────────
('BSH-DW-G2870', 'Gaggenau GM287161 Fully Integrated 60cm',           'GAGGENAU', 'DISH_CARE',        'Dishwasher Fully Integrated',   2800.00, 'PREMIUM', 'A'),
-- ── NEFF — COOKING ──────────────────────────────────────────────────────────
('BSH-OV-N5770', 'NEFF B57VR22N0B Slide-Hide Pyrolytic',              'NEFF',     'COOKING',          'Built-in Oven Pyrolytic',        999.00,  'PREMIUM', 'A'),
('BSH-OV-N6900', 'NEFF B69FH7AN0B CircoTherm',                        'NEFF',     'COOKING',          'Built-in Oven',                  849.00,  'MID',     'A'),
('BSH-OV-N4700', 'NEFF B47CR32N0B Pyrolytic',                         'NEFF',     'COOKING',          'Built-in Oven Pyrolytic',        779.00,  'MID',     'A'),
('BSH-IH-N4600', 'NEFF T46PT60X0 Induction Hob 60cm',                 'NEFF',     'COOKING',          'Induction Hob 60cm',             549.00,  'MID',     NULL),
-- ── NEFF — DISH CARE ────────────────────────────────────────────────────────
('BSH-DW-N5850', 'NEFF S585T60X1GB Fully Integrated',                 'NEFF',     'DISH_CARE',        'Dishwasher Fully Integrated',    749.00,  'MID',     'A'),
('BSH-DW-N8970', 'NEFF S897HMX80G Fully Integrated',                  'NEFF',     'DISH_CARE',        'Dishwasher Fully Integrated',    849.00,  'PREMIUM', 'A'),
-- ── NEFF — LAUNDRY CARE ─────────────────────────────────────────────────────
('BSH-WM-N7100', 'NEFF W7540X5GB Serie 7 9kg',                        'NEFF',     'LAUNDRY_CARE',     'Washing Machine Front Load',     699.00,  'MID',     'A'),
-- ── THERMADOR — North America premium brand ──────────────────────────────────
('BSH-OV-T3600', 'Thermador MEDS607BS 30-inch Double Wall Oven',      'THERMADOR','COOKING',          'Double Wall Oven',              4000.00, 'PREMIUM', NULL),
('BSH-DW-T3000', 'Thermador DWHD771WFP StarDry Panel Ready',          'THERMADOR','DISH_CARE',        'Dishwasher Panel Ready',        2000.00, 'PREMIUM', 'A'),
('BSH-FF-T3600', 'Thermador T36IT905NP 36-inch Column Refrigerator',  'THERMADOR','COOLING',          'Column Refrigerator',           5500.00, 'PREMIUM', NULL),
('BSH-FZ-T3600', 'Thermador T36IZ900NP 36-inch Column Freezer',       'THERMADOR','COOLING',          'Column Freezer',                5000.00, 'PREMIUM', NULL);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. CUSTOMER DIMENSION
--    Major retail, built-in/project, and e-commerce customers by region.
--    CUSTOMER_GROUP mirrors SAP customer group codes used in ACDOCA.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_CUSTOMER (
    CUSTOMER_NUMBER  VARCHAR(10)   NOT NULL PRIMARY KEY
                     COMMENT 'SAP customer number (maps to KUNNR)',
    CUSTOMER_NAME    VARCHAR(100)
                     COMMENT 'Full customer / retailer name',
    COUNTRY          VARCHAR(3)
                     COMMENT 'Country of customer headquarters (ISO 3166-1 alpha-3)',
    REGION           VARCHAR(20)
                     COMMENT 'Sales region: DACH | W_EUROPE | E_EUROPE | N_AMERICA | APAC | EMERGING',
    CUSTOMER_GROUP   VARCHAR(2)
                     COMMENT 'SAP customer group: 01=Specialist Retail | 02=Mass Retail | 03=E-Commerce | 04=Built-in/Project | 05=B2B/Commercial',
    CHANNEL_CODE     VARCHAR(2)
                     COMMENT 'Distribution channel: 10=Retail | 20=Built-in | 30=eCom | 40=B2B',
    CUSTOMER_TIER    VARCHAR(10)
                     COMMENT 'Account tier: KEY | STANDARD | SMALL'
)
COMMENT = 'BSH customer master — 44 major retail and trade customers across all regions';

INSERT INTO DIM_CUSTOMER VALUES
-- ── Germany ────────────────────────────────────────────────────────────────
('0000100001', 'MediaMarkt Deutschland GmbH',        'DEU', 'DACH',     '01', '10', 'KEY'),
('0000100002', 'Saturn GmbH',                         'DEU', 'DACH',     '01', '10', 'KEY'),
('0000100003', 'Amazon.de Marketplace',              'DEU', 'DACH',     '03', '30', 'KEY'),
('0000100004', 'Euronics Deutschland eG',            'DEU', 'DACH',     '01', '10', 'STANDARD'),
('0000100005', 'Expert SE',                          'DEU', 'DACH',     '01', '10', 'STANDARD'),
('0000100006', 'Otto GmbH & Co KG',                  'DEU', 'DACH',     '03', '30', 'STANDARD'),
('0000100007', 'Kueche Co GmbH (Built-in)',           'DEU', 'DACH',     '04', '20', 'KEY'),
('0000100008', 'Nolte Küchen GmbH',                  'DEU', 'DACH',     '04', '20', 'STANDARD'),
('0000100009', 'Nobilia-Werke GmbH',                 'DEU', 'DACH',     '04', '20', 'KEY'),
('0000100010', 'REWE Group (Small Appliances)',       'DEU', 'DACH',     '02', '10', 'STANDARD'),
-- ── Austria / Switzerland ──────────────────────────────────────────────────
('0000100011', 'Cosmos Electro GmbH Austria',       'AUT', 'DACH',     '01', '10', 'STANDARD'),
('0000100012', 'Interdiscount AG Switzerland',      'CHE', 'DACH',     '01', '10', 'STANDARD'),
-- ── France ────────────────────────────────────────────────────────────────
('0000100020', 'Fnac Darty SA',                     'FRA', 'W_EUROPE',  '01', '10', 'KEY'),
('0000100021', 'Amazon.fr',                         'FRA', 'W_EUROPE',  '03', '30', 'STANDARD'),
('0000100022', 'But International SAS',             'FRA', 'W_EUROPE',  '01', '10', 'STANDARD'),
('0000100023', 'Schmidt Groupe (Built-in)',          'FRA', 'W_EUROPE',  '04', '20', 'STANDARD'),
-- ── United Kingdom ────────────────────────────────────────────────────────
('0000100030', 'Currys plc',                        'GBR', 'W_EUROPE',  '01', '10', 'KEY'),
('0000100031', 'John Lewis Partnership',            'GBR', 'W_EUROPE',  '01', '10', 'KEY'),
('0000100032', 'Amazon.co.uk',                      'GBR', 'W_EUROPE',  '03', '30', 'STANDARD'),
('0000100033', 'AO World plc',                      'GBR', 'W_EUROPE',  '03', '30', 'STANDARD'),
-- ── BeNeLux ───────────────────────────────────────────────────────────────
('0000100040', 'MediaMarkt Nederland BV',           'NLD', 'W_EUROPE',  '01', '10', 'STANDARD'),
('0000100041', 'Coolblue B.V.',                     'NLD', 'W_EUROPE',  '03', '30', 'STANDARD'),
-- ── Italy ─────────────────────────────────────────────────────────────────
('0000100050', 'Unieuro SpA',                       'ITA', 'W_EUROPE',  '01', '10', 'STANDARD'),
('0000100051', 'Mediaworld SpA (MediaMarkt Italy)', 'ITA', 'W_EUROPE',  '01', '10', 'STANDARD'),
-- ── Spain ─────────────────────────────────────────────────────────────────
('0000100060', 'El Corte Inglés SA',                'ESP', 'W_EUROPE',  '01', '10', 'STANDARD'),
('0000100061', 'MediaMarkt Spain',                  'ESP', 'W_EUROPE',  '01', '10', 'STANDARD'),
-- ── Eastern Europe ────────────────────────────────────────────────────────
('0000100070', 'x-kom SA Poland',                   'POL', 'E_EUROPE',  '03', '30', 'STANDARD'),
('0000100071', 'RTV Euro AGD Poland',               'POL', 'E_EUROPE',  '01', '10', 'STANDARD'),
('0000100072', 'Alza.cz Czech Republic',            'CZE', 'E_EUROPE',  '03', '30', 'STANDARD'),
('0000100073', 'Domo-elektro Romania',              'ROU', 'E_EUROPE',  '01', '10', 'SMALL'),
-- ── North America ─────────────────────────────────────────────────────────
('0000100080', 'Best Buy Co. Inc.',                 'USA', 'N_AMERICA', '01', '10', 'KEY'),
('0000100081', 'Williams-Sonoma Inc.',              'USA', 'N_AMERICA', '01', '10', 'KEY'),
('0000100082', 'Amazon.com USA',                    'USA', 'N_AMERICA', '03', '30', 'KEY'),
('0000100083', 'The Home Depot Inc.',               'USA', 'N_AMERICA', '02', '10', 'STANDARD'),
('0000100084', 'Costco Wholesale Corporation',      'USA', 'N_AMERICA', '02', '10', 'STANDARD'),
-- ── Asia-Pacific ──────────────────────────────────────────────────────────
('0000100090', 'JD.com Inc. China',                 'CHN', 'APAC',      '03', '30', 'KEY'),
('0000100091', 'Tmall (Alibaba Group) China',       'CHN', 'APAC',      '03', '30', 'KEY'),
('0000100092', 'Bic Camera Inc. Japan',             'JPN', 'APAC',      '01', '10', 'STANDARD'),
('0000100093', 'Harvey Norman Australia',           'AUS', 'APAC',      '01', '10', 'STANDARD'),
-- ── Emerging Markets ──────────────────────────────────────────────────────
('0000100100', 'Teknik Yapı Turkey',                'TUR', 'EMERGING',  '01', '10', 'STANDARD'),
('0000100101', 'Fast Shop Brazil',                  'BRA', 'EMERGING',  '01', '10', 'STANDARD'),
('0000100102', 'Croma Retail India',                'IND', 'EMERGING',  '01', '10', 'SMALL');

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. COMPANY CODE DIMENSION
--    SAP-authentic internal legal entity codes for BSH Group.
--    These map to COMPANYCODE in ACDOCA and represent BSH's own org structure.
--    Note: CLIENT_ID ('BSH') is the TENANT identifier that lives on the fact
--    table — COMPANYCODE is BSH's internal SAP entity breakdown within that tenant.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_COMPANY (
    COMPANYCODE      VARCHAR(4)    NOT NULL PRIMARY KEY
                     COMMENT 'SAP company code (maps to BUKRS in ACDOCA)',
    COMPANY_NAME     VARCHAR(100)
                     COMMENT 'Legal entity name',
    COUNTRY          VARCHAR(3)
                     COMMENT 'Country of incorporation (ISO 3166-1 alpha-3)',
    REGION           VARCHAR(20)
                     COMMENT 'Sales region this entity primarily serves',
    CONTROLLING_AREA VARCHAR(4)
                     COMMENT 'SAP controlling area (KOKRS)',
    CURRENCY         VARCHAR(3)
                     COMMENT 'Local currency (ISO 4217)'
)
COMMENT = 'BSH Group SAP company code master — 6 legal entities; all belong to CLIENT_ID=BSH';

INSERT INTO DIM_COMPANY VALUES
('1000', 'BSH Hausgeräte GmbH — Munich HQ',              'DEU', 'DACH',     'BSH0', 'EUR'),
('1100', 'BSH Western Europe Operations GmbH',           'FRA', 'W_EUROPE', 'BSH0', 'EUR'),
('1200', 'BSH Eastern Europe GmbH',                      'POL', 'E_EUROPE', 'BSH0', 'EUR'),
('2000', 'BSH Home Appliances Corporation (NA)',         'USA', 'N_AMERICA','BSH0', 'USD'),
('3000', 'BSH Home Appliances (China) Ltd.',             'CHN', 'APAC',     'BSH0', 'CNY'),
('4000', 'BSH Emerging Markets GmbH',                    'TUR', 'EMERGING', 'BSH0', 'EUR');

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. PLANT DIMENSION
--    BSH manufacturing plants worldwide.
--    Maps to WERKS in SAP and the PLANT column in S3_FINANCE_PNL.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_PLANT (
    PLANT            VARCHAR(4)    NOT NULL PRIMARY KEY
                     COMMENT 'SAP plant code (maps to WERKS)',
    PLANT_NAME       VARCHAR(100)
                     COMMENT 'Plant location and name',
    COUNTRY          VARCHAR(3)
                     COMMENT 'Country where plant is located',
    REGION           VARCHAR(20)
                     COMMENT 'Sales region this plant primarily serves',
    SPECIALTY        VARCHAR(100)
                     COMMENT 'Main product lines manufactured at this plant'
)
COMMENT = 'BSH manufacturing plant master — 8 plants worldwide';

INSERT INTO DIM_PLANT VALUES
('GI01', 'BSH Giengen Plant — Swabia, Germany',     'DEU', 'DACH',     'Dishwashers — global technology centre, 1,500+ variants'),
('DI01', 'BSH Dillingen Plant — Swabia, Germany',   'DEU', 'DACH',     'Refrigerators and freezers'),
('TR01', 'BSH Traunreut Plant — Bavaria, Germany',  'DEU', 'DACH',     'Cooking and baking appliances'),
('BR01', 'BSH Bretten Plant — Baden, Germany',      'DEU', 'DACH',     'Ovens — new premium series production'),
('CZ01', 'BSH Michalovce Plant — Slovakia',         'SVK', 'E_EUROPE', 'Washing machines and tumble dryers'),
('NB01', 'BSH New Bern NC Plant — USA',             'USA', 'N_AMERICA','Dishwashers and cooking — North American market'),
('CH01', 'BSH Chuzhou Plant — Anhui, China',        'CHN', 'APAC',     'Washing machines and small appliances for APAC'),
('TR02', 'BSH Çerkezköy Plant — Tekirdağ, Turkey',  'TUR', 'EMERGING', 'Small appliances and coffee machines');

-- ─────────────────────────────────────────────────────────────────────────────
-- Verification
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'DIM_GL_ACCOUNT'  AS table_name, COUNT(*) AS rows FROM DIM_GL_ACCOUNT  UNION ALL
SELECT 'DIM_PRODUCT',                   COUNT(*)         FROM DIM_PRODUCT      UNION ALL
SELECT 'DIM_CUSTOMER',                  COUNT(*)         FROM DIM_CUSTOMER     UNION ALL
SELECT 'DIM_COMPANY',                   COUNT(*)         FROM DIM_COMPANY      UNION ALL
SELECT 'DIM_PLANT',                     COUNT(*)         FROM DIM_PLANT
ORDER BY 1;
