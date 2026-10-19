-- =============================================================================
-- 02_dimensions.sql — Reference / Dimension Tables
--
-- Creates and populates all dimension tables used by the R.Daneel PnL fact table:
--   DIM_GL_ACCOUNT   — PnL line classification (13 rows)
--   DIM_PRODUCT      — Real R.Daneel product SKUs with model numbers (~52 rows)
--   DIM_CUSTOMER     — Major retail and trade customers (44 rows)
--   DIM_COMPANY      — SAP company codes / legal entities (6 rows)
--   DIM_PLANT        — R.Daneel manufacturing plants worldwide (8 rows)
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
--    Real R.Daneel model numbers across all five brands and five categories.
--    LIST_PRICE_EUR is used to calculate average selling price in the SV.
--    Note: Solaria/Terminus/Aurora are category-specialist brands — they do
--    not cover all five categories (this is intentional and realistic).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_PRODUCT (
    MATERIAL         VARCHAR(18)   NOT NULL PRIMARY KEY
                     COMMENT 'R.Daneel internal material number (maps to SAP MATNR)',
    PRODUCT_NAME     VARCHAR(100)
                     COMMENT 'Full product name including brand and series',
    BRAND            VARCHAR(20)
                     COMMENT 'R.Daneel brand: GISKARD | CALVIN | SOLARIA | TERMINUS | AURORA',
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
COMMENT = 'R.Daneel product catalogue — ~52 real SKUs with model numbers, covers all brands and categories';

INSERT INTO DIM_PRODUCT VALUES
-- ── GISKARD — DISH CARE ──────────────────────────────────────────────────────
('RD-DW-G8000', 'Giskard Series 8 DryMax',               'GISKARD',    'DISH_CARE',        'Dishwasher Freestanding',        999.00,  'PREMIUM', 'A'),
('RD-DW-G6000', 'Giskard Series 6 DryMax Integrated',    'GISKARD',    'DISH_CARE',        'Dishwasher Fully Integrated',    799.00,  'MID',     'A'),
('RD-DW-G4000', 'Giskard Series 4 Dishwasher',                          'GISKARD',    'DISH_CARE',        'Dishwasher Freestanding',        549.00,  'MID',     'E'),
('RD-DW-G2000', 'Giskard Series 2 Dishwasher',                          'GISKARD',    'DISH_CARE',        'Dishwasher Freestanding',        349.00,  'ENTRY',   'E'),
-- ── GISKARD — LAUNDRY CARE ────────────────────────────────────────────────────
('RD-WM-G8100', 'Giskard Series 8 QuietDrive 10kg',          'GISKARD',    'LAUNDRY_CARE',     'Washing Machine Front Load',    1199.00, 'PREMIUM', 'A'),
('RD-WM-G6100', 'Giskard Series 6 9kg',                     'GISKARD',    'LAUNDRY_CARE',     'Washing Machine Front Load',     699.00,  'MID',     'A'),
('RD-WM-G4100', 'Giskard Series 4 8kg',                      'GISKARD',    'LAUNDRY_CARE',     'Washing Machine Front Load',     499.00,  'ENTRY',   'B'),
('RD-TD-G8100', 'Giskard Series 8 Heat Pump Dryer 9kg',      'GISKARD',    'LAUNDRY_CARE',     'Tumble Dryer Heat Pump',         999.00,  'PREMIUM', 'A'),
-- ── GISKARD — COOKING ─────────────────────────────────────────────────────────
('RD-OV-G8000', 'Giskard Series 8 Pyrolytic',                'GISKARD',    'COOKING',          'Built-in Oven Pyrolytic',       1299.00, 'PREMIUM', 'A'),
('RD-OV-G6000', 'Giskard Series 6 Steam Oven',               'GISKARD',    'COOKING',          'Built-in Steam Oven',            999.00,  'MID',     'A'),
('RD-OV-G4000', 'Giskard Series 4 Oven',                           'GISKARD',    'COOKING',          'Built-in Oven',                  449.00,  'ENTRY',   'A'),
('RD-IH-G6000', 'Giskard Series 6 ZoneFlex 60cm',       'GISKARD',    'COOKING',          'Induction Hob 60cm',             549.00,  'MID',     NULL),
-- ── GISKARD — COOLING ─────────────────────────────────────────────────────────
('RD-FF-G8000', 'Giskard Series 8 FrenchDoor 590L',          'GISKARD',    'COOLING',          'French Door Refrigerator',      1499.00, 'PREMIUM', 'C'),
('RD-FF-G6000', 'Giskard Series 6 FrostFree 631L',              'GISKARD',    'COOLING',          'Fridge Freezer FrostFree',        1199.00, 'MID',     'C'),
('RD-FF-G4000', 'Giskard Series 4 FrostFree',                  'GISKARD',    'COOLING',          'Fridge Freezer Combi',           649.00,  'ENTRY',   'E'),
-- ── GISKARD — CONSUMER PRODUCTS ───────────────────────────────────────────────
('RD-CF-G8000', 'Giskard Brew Pro 1.4L',             'GISKARD',    'CONSUMER_PRODUCTS','Fully Automatic Coffee Machine', 1199.00, 'PREMIUM', NULL),
('RD-CF-G6000', 'Giskard Brew Plus',                    'GISKARD',    'CONSUMER_PRODUCTS','Fully Automatic Coffee Machine',  799.00,  'MID',     NULL),
('RD-VC-G6000', 'Giskard CordFree 7 Cordless Vacuum',        'GISKARD',    'CONSUMER_PRODUCTS','Cordless Vacuum Cleaner',         299.00,  'MID',     NULL),
-- ── CALVIN — DISH CARE ─────────────────────────────────────────────────────
('RD-DW-C7000', 'Calvin C700 Fully Integrated',         'CALVIN',  'DISH_CARE',        'Dishwasher Fully Integrated',    849.00,  'PREMIUM', 'A'),
('RD-DW-C5000', 'Calvin C500 Dishwasher',                          'CALVIN',  'DISH_CARE',        'Dishwasher Freestanding',        599.00,  'MID',     'B'),
('RD-DW-C3000', 'Calvin C300 Dishwasher',                          'CALVIN',  'DISH_CARE',        'Dishwasher Freestanding',        449.00,  'ENTRY',   'E'),
-- ── CALVIN — LAUNDRY CARE ──────────────────────────────────────────────────
('RD-WM-C7100', 'Calvin C700 10kg',                     'CALVIN',  'LAUNDRY_CARE',     'Washing Machine Front Load',     849.00,  'PREMIUM', 'A'),
('RD-WM-C5100', 'Calvin C500 9kg',                      'CALVIN',  'LAUNDRY_CARE',     'Washing Machine Front Load',     699.00,  'MID',     'A'),
('RD-TD-C7100', 'Calvin C700 Heat Pump Dryer 9kg',        'CALVIN',  'LAUNDRY_CARE',     'Tumble Dryer Heat Pump',         949.00,  'PREMIUM', 'A'),
-- ── CALVIN — COOKING ───────────────────────────────────────────────────────
('RD-OV-C9000', 'Calvin Studio Oven',                     'CALVIN',  'COOKING',          'Built-in Oven Premium',         1499.00, 'PREMIUM', 'A'),
('RD-OV-C7000', 'Calvin C700 Pyrolytic',                'CALVIN',  'COOKING',          'Built-in Oven Pyrolytic',       1199.00, 'MID',     'A'),
('RD-IH-C7000', 'Calvin ZoneFlex 90cm',             'CALVIN',  'COOKING',          'Induction Hob 90cm',             999.00,  'MID',     NULL),
-- ── CALVIN — COOLING ───────────────────────────────────────────────────────
('RD-FF-C7000', 'Calvin C700 FrenchDoor',                'CALVIN',  'COOLING',          'French Door Refrigerator',      1699.00, 'PREMIUM', 'C'),
('RD-FF-C5000', 'Calvin C500 FrostFree',                   'CALVIN',  'COOLING',          'Fridge Freezer FrostFree',         799.00,  'MID',     'C'),
-- ── CALVIN — CONSUMER PRODUCTS ─────────────────────────────────────────────
('RD-CF-C9000', 'Calvin Barista 900 Fully Automatic',            'CALVIN',  'CONSUMER_PRODUCTS','Fully Automatic Coffee Machine', 1299.00, 'PREMIUM', NULL),
('RD-CF-C7000', 'Calvin Barista 700',                            'CALVIN',  'CONSUMER_PRODUCTS','Fully Automatic Coffee Machine',  999.00,  'MID',     NULL),
-- ── SOLARIA — COOKING (premium/luxury only) ────────────────────────────────
('RD-OV-S4800', 'Solaria Combi-Steam Oven 60cm',           'SOLARIA', 'COOKING',          'Built-in Combi Steam Oven',     3800.00, 'PREMIUM', 'A'),
('RD-OV-S4700', 'Solaria Steam Oven 60cm',                 'SOLARIA', 'COOKING',          'Built-in Steam Oven',           3200.00, 'PREMIUM', 'A'),
('RD-IH-S4820', 'Solaria Full Surface Induction',          'SOLARIA', 'COOKING',          'Full Surface Induction Hob',    4500.00, 'PREMIUM', NULL),
('RD-IH-S4250', 'Solaria Modular Gas Cooktop',               'SOLARIA', 'COOKING',          'Gas Cooktop',                   2800.00, 'PREMIUM', NULL),
-- ── SOLARIA — COOLING ──────────────────────────────────────────────────────
('RD-RF-S4920', 'Solaria Modular Refrigerator Column 212L',  'SOLARIA', 'COOLING',          'Modular Refrigerator Column',     4200.00, 'PREMIUM', 'C'),
('RD-FZ-S4910', 'Solaria Modular Freezer Column 212L',       'SOLARIA', 'COOLING',          'Modular Freezer Column',          3800.00, 'PREMIUM', 'C'),
-- ── SOLARIA — DISH CARE ────────────────────────────────────────────────────
('RD-DW-S2870', 'Solaria Fully Integrated Dishwasher 60cm',           'SOLARIA', 'DISH_CARE',        'Dishwasher Fully Integrated',   2800.00, 'PREMIUM', 'A'),
-- ── TERMINUS — COOKING ──────────────────────────────────────────────────────────
('RD-OV-T5770', 'Terminus GlideDoor Pyrolytic Oven',              'TERMINUS',     'COOKING',          'Built-in Oven Pyrolytic',        999.00,  'PREMIUM', 'A'),
('RD-OV-T6900', 'Terminus AirFlow Oven',                        'TERMINUS',     'COOKING',          'Built-in Oven',                  849.00,  'MID',     'A'),
('RD-OV-T4700', 'Terminus Pyrolytic Oven',                         'TERMINUS',     'COOKING',          'Built-in Oven Pyrolytic',        779.00,  'MID',     'A'),
('RD-IH-T4600', 'Terminus Induction Hob 60cm',                 'TERMINUS',     'COOKING',          'Induction Hob 60cm',             549.00,  'MID',     NULL),
-- ── TERMINUS — DISH CARE ────────────────────────────────────────────────────────
('RD-DW-T5850', 'Terminus Fully Integrated Dishwasher',                 'TERMINUS',     'DISH_CARE',        'Dishwasher Fully Integrated',    749.00,  'MID',     'A'),
('RD-DW-T8970', 'Terminus Pro Fully Integrated Dishwasher',                  'TERMINUS',     'DISH_CARE',        'Dishwasher Fully Integrated',    849.00,  'PREMIUM', 'A'),
-- ── TERMINUS — LAUNDRY CARE ─────────────────────────────────────────────────────
('RD-WM-T7100', 'Terminus Series 7 9kg',                        'TERMINUS',     'LAUNDRY_CARE',     'Washing Machine Front Load',     699.00,  'MID',     'A'),
-- ── AURORA — North America premium brand ──────────────────────────────────
('RD-OV-A3600', 'Aurora 30-inch Double Wall Oven',      'AURORA','COOKING',          'Double Wall Oven',              4000.00, 'PREMIUM', NULL),
('RD-DW-A3000', 'Aurora ProDry Panel Ready',          'AURORA','DISH_CARE',        'Dishwasher Panel Ready',        2000.00, 'PREMIUM', 'A'),
('RD-FF-A3600', 'Aurora 36-inch Column Refrigerator',  'AURORA','COOLING',          'Column Refrigerator',           5500.00, 'PREMIUM', NULL),
('RD-FZ-A3600', 'Aurora 36-inch Column Freezer',       'AURORA','COOLING',          'Column Freezer',                5000.00, 'PREMIUM', NULL);

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
COMMENT = 'R.Daneel customer master — 44 major retail and trade customers across all regions';

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
--    SAP-authentic internal legal entity codes for R.Daneel Inc..
--    These map to COMPANYCODE in ACDOCA and represent R.Daneel's own org structure.
--    Note: CLIENT_ID ('RDANEEL') is the TENANT identifier that lives on the fact
--    table — COMPANYCODE is R.Daneel's internal SAP entity breakdown within that tenant.
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
COMMENT = 'R.Daneel Inc. SAP company code master — 6 legal entities; all belong to CLIENT_ID=RDANEEL';

INSERT INTO DIM_COMPANY VALUES
('1000', 'R.Daneel Appliances GmbH — Munich HQ',              'DEU', 'DACH',     'RD00', 'EUR'),
('1100', 'R.Daneel Western Europe Operations GmbH',           'FRA', 'W_EUROPE', 'RD00', 'EUR'),
('1200', 'R.Daneel Eastern Europe GmbH',                      'POL', 'E_EUROPE', 'RD00', 'EUR'),
('2000', 'R.Daneel Home Appliances Corporation (NA)',         'USA', 'N_AMERICA','RD00', 'USD'),
('3000', 'R.Daneel Home Appliances (China) Ltd.',             'CHN', 'APAC',     'RD00', 'CNY'),
('4000', 'R.Daneel Emerging Markets GmbH',                    'TUR', 'EMERGING', 'RD00', 'EUR');

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. PLANT DIMENSION
--    R.Daneel manufacturing plants worldwide.
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
COMMENT = 'R.Daneel manufacturing plant master — 8 plants worldwide';

INSERT INTO DIM_PLANT VALUES
('GI01', 'R.Daneel Giengen Plant — Swabia, Germany',     'DEU', 'DACH',     'Dishwashers — global technology centre, 1,500+ variants'),
('DI01', 'R.Daneel Dillingen Plant — Swabia, Germany',   'DEU', 'DACH',     'Refrigerators and freezers'),
('TR01', 'R.Daneel Traunreut Plant — Bavaria, Germany',  'DEU', 'DACH',     'Cooking and baking appliances'),
('BR01', 'R.Daneel Bretten Plant — Baden, Germany',      'DEU', 'DACH',     'Ovens — new premium series production'),
('CZ01', 'R.Daneel Michalovce Plant — Slovakia',         'SVK', 'E_EUROPE', 'Washing machines and tumble dryers'),
('NB01', 'R.Daneel New Bern NC Plant — USA',             'USA', 'N_AMERICA','Dishwashers and cooking — North American market'),
('CH01', 'R.Daneel Chuzhou Plant — Anhui, China',        'CHN', 'APAC',     'Washing machines and small appliances for APAC'),
('TR02', 'R.Daneel Çerkezköy Plant — Tekirdağ, Turkey',  'TUR', 'EMERGING', 'Small appliances and coffee machines');

-- ─────────────────────────────────────────────────────────────────────────────
-- Verification
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'DIM_GL_ACCOUNT'  AS table_name, COUNT(*) AS row_count FROM DIM_GL_ACCOUNT  UNION ALL
SELECT 'DIM_PRODUCT',                   COUNT(*)         FROM DIM_PRODUCT      UNION ALL
SELECT 'DIM_CUSTOMER',                  COUNT(*)         FROM DIM_CUSTOMER     UNION ALL
SELECT 'DIM_COMPANY',                   COUNT(*)         FROM DIM_COMPANY      UNION ALL
SELECT 'DIM_PLANT',                     COUNT(*)         FROM DIM_PLANT
ORDER BY 1;
