-- Confect PetFood Demo | Supply Chain Risk Intelligence Demo
-- Co-authored with CoCo
--
-- Snowflake as intelligence layer between SAP S/4 (via BDC), Blue Yonder IBP + TMS,
-- and external market signals — closing the planning-to-execution gap.
--
-- Framing: SAP and Blue Yonder are the systems of record.
--          Snowflake is the intelligence amplifier connecting them to the world.
--
-- Scale: Reflects a multi-division CPG ~$38B annual revenue:
--   Petcare ($20B)  — NovaPet, TailWag, PurrFresh
--   Confectionery ($9B) — ChocoSnap, NutCrunch, WaferBliss, CocoBar, MaltBurst, StarChoc
--   Food ($5B) — GrainHarvest, SauceCraft
--   130+ manufacturing sites · 80+ markets · 28 strategic suppliers in scope
--
-- Run this script in any Snowflake account.
--
-- Demo date context: August 2026
--   Act 1: Christmas 2026 peak (Nov-Dec) — primary confectionery season
--   Act 2: Logistics deep-dive — Abidjan-Rotterdam cocoa lane disruption
--   Act 3: NovaPet Spring 2027 (Feb-Apr) — H5N1 biosecurity crisis
--   Act 4: Global cascade — Diwali (Oct-Nov, India), CNY (Jan-Feb, APAC)
--          Same cocoa supply crunch hits four peaks on three continents
-- =============================================================
USE ROLE ACCOUNTADMIN;

-- Create a dedicated warehouse for this demo (XS is sufficient)
CREATE WAREHOUSE IF NOT EXISTS CONFECT_PETFOOD_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;
USE WAREHOUSE CONFECT_PETFOOD_WH;

CREATE OR REPLACE DATABASE CONFECT_PETFOOD_DEMO
  ICEBERG_VERSION_DEFAULT = 3
  CATALOG = 'SNOWFLAKE'
  ICEBERG_MERGE_ON_READ_BEHAVIOR = 'DISABLED'
  STORAGE_SERIALIZATION_POLICY = 'COMPATIBLE';

USE DATABASE CONFECT_PETFOOD_DEMO;
CREATE OR REPLACE SCHEMA SC_RISK_DEMO;
USE SCHEMA SC_RISK_DEMO;

-- =============================================================
-- LAYER 1: SAP BDC DATA PRODUCTS
-- Source: SAP S/4HANA via SAP Business Data Cloud (zero-copy share)
-- Tables named after their CDS view / BDC product catalog names.
-- =============================================================

-- 1.1  I_SUPPLIER  (Vendor Master — BDC: Procurement & Purchasing)
CREATE OR REPLACE ICEBERG TABLE I_SUPPLIER (
    SUPPLIER_ID         VARCHAR     NOT NULL,   -- SAP LIFNR
    SUPPLIER_NAME       VARCHAR,
    COUNTRY             VARCHAR,
    REGION              VARCHAR,
    SUPPLIER_TYPE       VARCHAR,
    CREDIT_RATING       VARCHAR,
    CONTRACT_START      DATE,
    CONTRACT_END        DATE,
    IS_SOLE_SOURCE      BOOLEAN,
    PAYMENT_TERMS_DAYS  NUMBER(3,0),
    IS_ACTIVE           BOOLEAN,
    PRIMARY KEY (SUPPLIER_ID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;



INSERT INTO I_SUPPLIER VALUES
-- === Cocoa & confectionery ingredients ===
('LIFNR-CI-001','WEST COCOA PROCESSING SA','Ivory Coast','Grand Abidjan','Cocoa Processor','A+','2024-01-01','2028-12-31',FALSE,45,TRUE),
('LIFNR-CI-002','SAHEL AGRI TRADERS LTD','Ivory Coast','Grand Abidjan','Cocoa Trader','A','2024-06-01','2027-06-30',FALSE,45,TRUE),
('LIFNR-CI-003','ATLANTIC ORIGINS CI','Ivory Coast','Grand Abidjan','Cocoa Trader','B','2023-11-01','2026-10-31',TRUE,60,TRUE),  -- RISK: sole source, contract expiry Oct-26
('LIFNR-BE-001','WEST COCOA BELGIUM NV','Belgium','Antwerp Province','Cocoa Processor','A+','2024-01-01','2029-06-30',FALSE,45,TRUE),
('LIFNR-GH-001','SAHEL AGRI GHANA LTD','Ghana','Greater Accra','Cocoa Trader','A-','2024-01-01','2028-06-30',FALSE,45,TRUE),
-- === Sugar ===
('LIFNR-NL-001','BENELUX SUIKER BV','Netherlands','Utrecht','Sugar Refiner','A','2023-01-01','2027-12-31',FALSE,30,TRUE),
('LIFNR-DE-001','RHEINZUCKER AG','Germany','Baden-Württemberg','Sugar Refiner','A+','2023-01-01','2028-06-30',FALSE,30,TRUE),
('LIFNR-GB-001','CROWN SUGARS LTD','United Kingdom','London','Sugar Refiner','A-','2024-04-01','2027-03-31',FALSE,30,TRUE),
('LIFNR-BR-001','TROPICANA AÇUCAR SA','Brazil','São Paulo','Sugar Refiner','A','2023-06-01','2028-12-31',FALSE,45,TRUE),
('LIFNR-MX-001','DULCE CRISTAL SA DE CV','Mexico','Jalisco','Sugar Refiner','A-','2023-01-01','2027-06-30',FALSE,45,TRUE),
('LIFNR-US-001','HEARTLAND SWEETENERS INC','United States','Illinois','Sweeteners','A','2023-01-01','2028-06-30',FALSE,30,TRUE),
-- === Packaging ===
('LIFNR-NL-002','EUROPACK SOLUTIONS NL BV','Netherlands','Noord-Holland','Packaging','B+','2024-01-01','2026-12-31',FALSE,45,TRUE),
('LIFNR-PL-001','CENTRAL PACK POLAND SP Z OO','Poland','Masovia','Packaging','A-','2024-03-01','2027-12-31',FALSE,45,TRUE),
-- === Dairy & fats ===
('LIFNR-NL-003','NORDMILK INGREDIENTS BV','Netherlands','Gelderland','Dairy Ingredients','A','2023-01-01','2027-09-30',FALSE,30,TRUE),
('LIFNR-MY-001','PACIFIC OLEO INTERNATIONAL','Malaysia','Selangor','Palm Fat','A','2023-01-01','2028-12-31',FALSE,30,TRUE),
-- === Peanuts ===
('LIFNR-US-003','SOUTHERN NUT GROWERS LLC','United States','Georgia','Peanuts','A-','2023-01-01','2027-12-31',FALSE,30,TRUE),
('LIFNR-AR-001','PAMPA NUTS SA','Argentina','Córdoba','Peanuts','B+','2023-06-01','2026-12-31',FALSE,45,TRUE),
-- === Protein suppliers — NovaPet / H5N1 scenario ===
('LIFNR-FR-001','VOLAILLE ATLANTIQUE SAS','France','Pays de la Loire','Poultry Protein','B-','2024-01-01','2026-12-31',FALSE,45,TRUE),  -- RISK: H5N1 zone
('LIFNR-FR-002','LOIRE PROTEIN GROUP','France','Pays de la Loire','Poultry Protein','B','2024-01-01','2026-12-31',FALSE,45,TRUE),  -- RISK: H5N1 zone
('LIFNR-FR-003','BRETAGNE AGRI PROTEINS','France','Bretagne','Poultry Protein','A-','2024-01-01','2027-12-31',FALSE,45,TRUE),  -- safe zone alternate
('LIFNR-DE-002','NORDFLEISCH PROTEIN GMBH','Germany','Nordrhein-Westfalen','Animal Protein','A-','2023-06-01','2027-06-30',FALSE,30,TRUE),
('LIFNR-US-002','MIDWEST PROTEIN INGREDIENTS LLC','United States','Arkansas','Animal Protein','A','2023-01-01','2028-12-31',FALSE,30,TRUE),
-- === Fish meal ===
('LIFNR-NO-001','NORDIC MARINE PROTEINS AS','Norway','Vestland','Fish Meal','A','2023-01-01','2028-12-31',FALSE,30,TRUE),
('LIFNR-TH-001','SIAM OCEAN FEEDS CO LTD','Thailand','Samut Sakhon','Fish Meal','A-','2023-06-01','2027-12-31',FALSE,45,TRUE),
-- === Cereals & grains ===
('LIFNR-FR-004','CENTRE GRAINS INGREDIENTS','France','Auvergne','Cereals & Rice','A','2023-01-01','2027-12-31',FALSE,30,TRUE),
('LIFNR-AU-001','SOUTHERN MILLS PTY LTD','Australia','New South Wales','Wheat & Starch','A-','2023-01-01','2027-12-31',FALSE,45,TRUE),
('LIFNR-TH-002','BANGKOK RICE EXPORTS CO LTD','Thailand','Bangkok','Rice','A','2023-01-01','2027-12-31',FALSE,45,TRUE),
-- === Vitamins & mineral premix ===
('LIFNR-CH-001','ALPINE NUTRITION AG','Switzerland','Kaiseraugst','Vitamin & Mineral Premix','A+','2023-01-01','2028-12-31',FALSE,30,TRUE);


-- 1.2  I_PRODUCT  (Material Master — BDC semantic entity)
CREATE OR REPLACE ICEBERG TABLE I_PRODUCT (
    MATERIAL_ID         VARCHAR     NOT NULL,
    MATERIAL_DESC       VARCHAR,
    DIVISION            VARCHAR,    -- CONFECTIONERY, PETCARE, FOOD
    BRAND               VARCHAR,
    CATEGORY            VARCHAR,
    CRITICALITY         VARCHAR,
    BASE_UNIT           VARCHAR,
    UNIT_WHOLESALE_USD  NUMBER(8,2),
    PRIMARY KEY (MATERIAL_ID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO I_PRODUCT VALUES
-- === CONFECTIONERY — Halloween peak SKUs ===
('CS-HWEEN-400G', 'ChocoSnap Milk Choc Halloween Party Bag 400g',   'CONFECTIONERY','ChocoSnap',    'Seasonal Bagged Candy','HIGH',  'EA', 1.92),
('CSP-HWEEN-400G','ChocoSnap Peanut Halloween Party Bag 400g',      'CONFECTIONERY','ChocoSnap',    'Seasonal Bagged Candy','HIGH',  'EA', 2.05),
('CSS-US-400G',   'ChocoSnap Halloween Fun Mix 400g N America',     'CONFECTIONERY','ChocoSnap',    'Seasonal Bagged Candy','HIGH',  'EA', 2.10),
('NC-HWEEN-500G', 'NutCrunch Halloween Selection Box 500g',          'CONFECTIONERY','NutCrunch',   'Seasonal Boxed Candy', 'HIGH',  'EA', 2.20),
('WB-HWEEN-450G', 'WaferBliss Halloween Treat Bag 450g',             'CONFECTIONERY','WaferBliss',  'Seasonal Bagged Candy','MEDIUM','EA', 1.98),
('MB-HWEEN-350G', 'MaltBurst Halloween Sharing Bag 350g',            'CONFECTIONERY','MaltBurst',   'Seasonal Bagged Candy','MEDIUM','EA', 1.85),
('CB-HWEEN-260G', 'CocoBar Halloween Mix 260g',                      'CONFECTIONERY','CocoBar',     'Seasonal Bagged Candy','MEDIUM','EA', 1.78),
-- === CONFECTIONERY — Christmas (primary global peak) ===
('FEST-XMAS-650G','Festival Collection Tin 650g',                    'CONFECTIONERY','Festival',    'Seasonal Tin',        'HIGH',  'EA', 4.50),
('STAR-XMAS-450G','StarChoc Chocolates Christmas Tin 450g',          'CONFECTIONERY','StarChoc',    'Seasonal Tin',        'HIGH',  'EA', 2.85),
('CS-XMAS-400G',  'ChocoSnap Milk Choc Christmas Gift Box 400g',    'CONFECTIONERY','ChocoSnap',   'Seasonal Gift Box',   'HIGH',  'EA', 2.40),
('NC-XMAS-500G',  'NutCrunch Christmas Selection Box 500g',          'CONFECTIONERY','NutCrunch',   'Seasonal Boxed Candy','HIGH',  'EA', 2.60),
-- === CONFECTIONERY — Diwali (India / APAC) ===
('CS-DIWALI-400G', 'ChocoSnap Diwali Gift Box 400g',                'CONFECTIONERY','ChocoSnap',   'Seasonal Gift Box',   'HIGH',  'EA', 2.20),
('NC-DIWALI-500G', 'NutCrunch Diwali Assortment 500g',              'CONFECTIONERY','NutCrunch',   'Seasonal Gift Box',   'HIGH',  'EA', 2.50),
('CB-DIWALI-300G', 'CocoBar Diwali Selection 300g',                  'CONFECTIONERY','CocoBar',     'Seasonal Gift Box',   'MEDIUM','EA', 1.90),
-- === CONFECTIONERY — Chinese New Year (APAC) ===
('CS-CNY-400G',    'ChocoSnap Lunar New Year Gift Box 400g',        'CONFECTIONERY','ChocoSnap',   'Seasonal Gift Box',   'HIGH',  'EA', 2.35),
('NC-CNY-500G',    'NutCrunch Lunar New Year Tin 500g',              'CONFECTIONERY','NutCrunch',   'Seasonal Tin',        'HIGH',  'EA', 2.55),
('FEST-CNY-650G',  'Festival Lunar New Year Collection 650g',        'CONFECTIONERY','Festival',    'Seasonal Tin',        'HIGH',  'EA', 4.80),
-- === PETCARE — NovaPet ===
('NP-PUP-MED-4KG','NovaPet Medium Puppy 4kg',                       'PETCARE','NovaPet',   'Puppy Nutrition',       'HIGH',  'EA', 14.80),
('NP-KIT-2KG',    'NovaPet Kitten 2kg',                             'PETCARE','NovaPet',   'Kitten Nutrition',      'HIGH',  'EA',  9.60),
('NP-PUP-GNT-35', 'NovaPet Giant Puppy 3.5kg',                      'PETCARE','NovaPet',   'Puppy Nutrition',       'HIGH',  'EA', 16.20),
('NP-KIT-IND-2KG','NovaPet Indoor Kitten 2kg',                      'PETCARE','NovaPet',   'Kitten Nutrition',      'MEDIUM','EA', 10.40),
('NP-ADL-MED-10K','NovaPet Medium Adult 10kg',                      'PETCARE','NovaPet',   'Adult Dog Nutrition',   'MEDIUM','EA', 32.50),
-- === PETCARE — TailWag ===
('TW-ADL-15KG',   'TailWag Adult Complete 15kg',                    'PETCARE','TailWag',   'Adult Dog Nutrition',    'HIGH',  'EA', 18.50),
('TW-PUP-3KG',    'TailWag Puppy Chicken & Rice 3kg',               'PETCARE','TailWag',   'Puppy Nutrition',        'HIGH',  'EA',  8.20),
-- === PETCARE — PurrFresh ===
('PF-ADL-400G',   'PurrFresh Adult Chicken in Jelly 400g',          'PETCARE','PurrFresh', 'Adult Cat Nutrition',    'HIGH',  'EA',  1.45),
('PF-KIT-300G',   'PurrFresh Kitten Pouch 300g',                    'PETCARE','PurrFresh', 'Kitten Nutrition',       'MEDIUM','EA',  1.35),
-- === FOOD ===
('GH-LG-500G',    'GrainHarvest Long Grain Rice 500g',              'FOOD','GrainHarvest','Ambient Rice',         'MEDIUM','EA',  1.85),
('GH-EXP-250G',   'GrainHarvest Microwave Express 250g',            'FOOD','GrainHarvest','Microwave Rice',       'HIGH',  'EA',  1.25),
('SC-PASTA-500G', 'SauceCraft Pasta Sauce Bolognese 500g',           'FOOD','SauceCraft',  'Pasta Sauce',            'MEDIUM','EA',  1.60);


-- 1.3  I_PRODUCTPLANT  (12 plants across 4 continents)
CREATE OR REPLACE ICEBERG TABLE I_PRODUCTPLANT (
    MATERIAL_ID          VARCHAR     NOT NULL,
    PLANT                VARCHAR     NOT NULL,
    PLANT_NAME           VARCHAR,
    PLANT_COUNTRY        VARCHAR,
    SAFETY_STOCK_DAYS    NUMBER(3,0),
    REORDER_POINT_DAYS   NUMBER(3,0),
    PRODUCTION_LEAD_DAYS NUMBER(3,0),
    PRIMARY KEY (MATERIAL_ID, PLANT)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO I_PRODUCTPLANT VALUES
-- NL01: Breda (Netherlands) — main confectionery hub
('CS-HWEEN-400G',  'NL01','Breda Confectionery',   'Netherlands',  42,28,21),
('CSP-HWEEN-400G', 'NL01','Breda Confectionery',   'Netherlands',  42,28,21),
('NC-HWEEN-500G',  'NL01','Breda Confectionery',   'Netherlands',  42,28,21),
('MB-HWEEN-350G',  'NL01','Breda Confectionery',   'Netherlands',  35,21,14),
-- GB01: Swindon (UK) — MaltBurst, Festival, StarChoc
('WB-HWEEN-450G',  'GB01','Swindon Factory',       'United Kingdom',35,21,14),
('FEST-XMAS-650G', 'GB01','Swindon Factory',       'United Kingdom',42,28,21),
('STAR-XMAS-450G', 'GB01','Swindon Factory',       'United Kingdom',42,28,21),
-- DE01: Cologne (Germany) — WaferBliss, CocoBar continental EU
('WB-HWEEN-450G',  'DE01','Cologne Factory',       'Germany',       35,21,14),
('CB-HWEEN-260G',  'DE01','Cologne Factory',       'Germany',       35,21,14),
('NC-HWEEN-500G',  'DE01','Cologne Factory',       'Germany',       42,28,21),
-- US01: Lancaster PA — North America confectionery
('CSS-US-400G',    'US01','Lancaster Factory',     'United States', 42,28,21),
('NC-HWEEN-500G',  'US01','Lancaster Factory',     'United States', 42,28,21),
('WB-HWEEN-450G',  'US01','Lancaster Factory',     'United States', 35,21,14),
-- FR01: Montpellier — NovaPet headquarters
('NP-PUP-MED-4KG', 'FR01','Montpellier Factory',   'France',        45,30,14),
('NP-KIT-2KG',     'FR01','Montpellier Factory',   'France',        45,30,14),
('NP-PUP-GNT-35',  'FR01','Montpellier Factory',   'France',        45,30,14),
('NP-KIT-IND-2KG', 'FR01','Montpellier Factory',   'France',        45,30,14),
('NP-ADL-MED-10K', 'FR01','Montpellier Factory',   'France',        42,28,14),
-- NL02: Tilburg — TailWag/PurrFresh
('TW-ADL-15KG',    'NL02','Tilburg Petcare',        'Netherlands',   42,28,14),
('TW-PUP-3KG',     'NL02','Tilburg Petcare',        'Netherlands',   42,28,14),
('PF-ADL-400G',    'NL02','Tilburg Petcare',        'Netherlands',   35,21,10),
('PF-KIT-300G',    'NL02','Tilburg Petcare',        'Netherlands',   35,21,10),
-- US02: Nashville TN — TailWag/PurrFresh NA
('TW-ADL-15KG',    'US02','Nashville Factory',      'United States', 42,28,14),
('PF-ADL-400G',    'US02','Nashville Factory',      'United States', 35,21,10),
-- GB02: Kettering — Food
('GH-LG-500G',     'GB02','Kettering Food Plant',   'United Kingdom',28,21,10),
('GH-EXP-250G',    'GB02','Kettering Food Plant',   'United Kingdom',28,21,10),
('SC-PASTA-500G',  'GB02','Kettering Food Plant',   'United Kingdom',28,21,10),
-- IN01: Mumbai — India confectionery (Diwali)
('CS-DIWALI-400G', 'IN01','Mumbai Confectionery',   'India',         35,21,14),
('NC-DIWALI-500G', 'IN01','Mumbai Confectionery',   'India',         35,21,14),
('CB-DIWALI-300G', 'IN01','Mumbai Confectionery',   'India',         35,21,14),
-- SG01: Singapore — APAC confectionery hub (CNY)
('CS-CNY-400G',    'SG01','Singapore Hub',          'Singapore',     35,21,14),
('NC-CNY-500G',    'SG01','Singapore Hub',          'Singapore',     35,21,14),
('FEST-CNY-650G',  'SG01','Singapore Hub',          'Singapore',     42,28,21),
-- Christmas expansion — NL01 + GB01
('CS-XMAS-400G',   'NL01','Breda Confectionery',    'Netherlands',   42,28,21),
('NC-XMAS-500G',   'NL01','Breda Confectionery',    'Netherlands',   42,28,21);


-- 1.4  I_BILLOFMATERIAL / I_BILLOFMATERIALITEM
CREATE OR REPLACE ICEBERG TABLE I_BILLOFMATERIAL (
    BOM_ID          VARCHAR     NOT NULL,
    MATERIAL_ID     VARCHAR     NOT NULL,
    PLANT           VARCHAR     NOT NULL,
    BOM_TYPE        VARCHAR,
    VALID_FROM      DATE,
    PRIMARY KEY (BOM_ID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO I_BILLOFMATERIAL VALUES
('BOM-CS-NL01',   'CS-HWEEN-400G',  'NL01','PRODUCTION','2024-01-01'),
('BOM-CSP-NL01',  'CSP-HWEEN-400G', 'NL01','PRODUCTION','2024-01-01'),
('BOM-CSS-US01',  'CSS-US-400G',    'US01','PRODUCTION','2024-01-01'),
('BOM-NC-NL01',   'NC-HWEEN-500G',  'NL01','PRODUCTION','2024-01-01'),
('BOM-NC-US01',   'NC-HWEEN-500G',  'US01','PRODUCTION','2024-01-01'),
('BOM-WB-DE01',   'WB-HWEEN-450G',  'DE01','PRODUCTION','2024-01-01'),
('BOM-MB-NL01',   'MB-HWEEN-350G',  'NL01','PRODUCTION','2024-01-01'),
('BOM-CB-DE01',   'CB-HWEEN-260G',  'DE01','PRODUCTION','2024-01-01'),
('BOM-FEST-GB01', 'FEST-XMAS-650G', 'GB01','PRODUCTION','2024-01-01'),
('BOM-NP-PUP-FR01','NP-PUP-MED-4KG','FR01','PRODUCTION','2024-01-01'),
('BOM-NP-KIT-FR01','NP-KIT-2KG',    'FR01','PRODUCTION','2024-01-01'),
('BOM-NP-GNT-FR01','NP-PUP-GNT-35', 'FR01','PRODUCTION','2024-01-01'),
('BOM-TW-NL02',   'TW-ADL-15KG',    'NL02','PRODUCTION','2024-01-01'),
('BOM-PF-NL02',   'PF-ADL-400G',    'NL02','PRODUCTION','2024-01-01'),
('BOM-GH-GB02',   'GH-LG-500G',     'GB02','PRODUCTION','2024-01-01'),
('BOM-GH-EXP-GB02','GH-EXP-250G',   'GB02','PRODUCTION','2024-01-01'),
-- Diwali BOMs (IN01)
('BOM-CS-DIW-IN01','CS-DIWALI-400G', 'IN01','PRODUCTION','2026-01-01'),
('BOM-NC-DIW-IN01','NC-DIWALI-500G', 'IN01','PRODUCTION','2026-01-01'),
('BOM-CB-DIW-IN01','CB-DIWALI-300G', 'IN01','PRODUCTION','2026-01-01'),
-- CNY BOMs (SG01)
('BOM-CS-CNY-SG01','CS-CNY-400G',    'SG01','PRODUCTION','2026-01-01'),
('BOM-NC-CNY-SG01','NC-CNY-500G',    'SG01','PRODUCTION','2026-01-01'),
('BOM-FEST-CNY-SG01','FEST-CNY-650G','SG01','PRODUCTION','2026-01-01'),
-- Christmas expansion BOMs (NL01)
('BOM-CS-XMAS-NL01','CS-XMAS-400G', 'NL01','PRODUCTION','2024-01-01'),
('BOM-NC-XMAS-NL01','NC-XMAS-500G', 'NL01','PRODUCTION','2024-01-01');


CREATE OR REPLACE ICEBERG TABLE I_BILLOFMATERIALITEM (
    BOM_ID              VARCHAR     NOT NULL,
    ITEM_NUMBER         NUMBER(4,0) NOT NULL,
    COMPONENT_ID        VARCHAR,
    COMPONENT_DESC      VARCHAR,
    COMPONENT_QTY       NUMBER(10,3),
    COMPONENT_UNIT      VARCHAR,
    IS_CRITICAL         BOOLEAN,
    PREFERRED_SUPPLIER  VARCHAR,
    PRIMARY KEY (BOM_ID, ITEM_NUMBER)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO I_BILLOFMATERIALITEM VALUES
-- BOM-CS-NL01 (ChocoSnap Milk)
('BOM-CS-NL01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.260,'KG',TRUE,'LIFNR-CI-003'),
('BOM-CS-NL01',20,'SUGAR-WHITE-01','White Sugar Refined',0.320,'KG',FALSE,'LIFNR-NL-001'),
('BOM-CS-NL01',30,'MILK-POWDER-01','Whole Milk Powder',0.120,'KG',FALSE,'LIFNR-NL-003'),
('BOM-CS-NL01',40,'PALM-FAT-01','Palm Fat Fractionated',0.080,'KG',FALSE,'LIFNR-MY-001'),
('BOM-CS-NL01',50,'PKG-FLOW-01','Flow Wrap Film 400g',1.000,'EA',FALSE,'LIFNR-NL-002'),
-- BOM-CSP-NL01 (ChocoSnap Peanut)
('BOM-CSP-NL01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.220,'KG',TRUE,'LIFNR-CI-003'),
('BOM-CSP-NL01',20,'PEANUT-RST-01','Roasted Peanut Halves',0.180,'KG',TRUE,'LIFNR-US-003'),
('BOM-CSP-NL01',30,'SUGAR-WHITE-01','White Sugar Refined',0.280,'KG',FALSE,'LIFNR-NL-001'),
('BOM-CSP-NL01',40,'MILK-POWDER-01','Whole Milk Powder',0.100,'KG',FALSE,'LIFNR-NL-003'),
('BOM-CSP-NL01',50,'PKG-FLOW-01','Flow Wrap Film 400g',1.000,'EA',FALSE,'LIFNR-NL-002'),
-- BOM-CSS-US01 (ChocoSnap US Fun Mix)
('BOM-CSS-US01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.250,'KG',TRUE,'LIFNR-CI-003'),
('BOM-CSS-US01',20,'SUGAR-WHITE-01','White Sugar Refined',0.310,'KG',FALSE,'LIFNR-US-001'),
('BOM-CSS-US01',30,'PEANUT-RST-01','Roasted Peanut Halves',0.150,'KG',TRUE,'LIFNR-US-003'),
('BOM-CSS-US01',40,'MILK-POWDER-01','Whole Milk Powder',0.110,'KG',FALSE,'LIFNR-NL-003'),
-- BOM-NC-NL01 (NutCrunch)
('BOM-NC-NL01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.200,'KG',TRUE,'LIFNR-CI-003'),
('BOM-NC-NL01',20,'PEANUT-RST-01','Roasted Peanut Halves',0.220,'KG',TRUE,'LIFNR-US-003'),
('BOM-NC-NL01',30,'CARAMEL-01','Caramel Filling',0.180,'KG',FALSE,'LIFNR-DE-001'),
('BOM-NC-NL01',40,'SUGAR-WHITE-01','White Sugar Refined',0.200,'KG',FALSE,'LIFNR-NL-001'),
-- BOM-NC-US01 (NutCrunch US)
('BOM-NC-US01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.200,'KG',TRUE,'LIFNR-CI-003'),
('BOM-NC-US01',20,'PEANUT-RST-01','Roasted Peanut Halves',0.220,'KG',TRUE,'LIFNR-US-003'),
('BOM-NC-US01',30,'CARAMEL-01','Caramel Filling',0.180,'KG',FALSE,'LIFNR-US-001'),
-- BOM-WB-DE01 (WaferBliss)
('BOM-WB-DE01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.150,'KG',TRUE,'LIFNR-CI-003'),
('BOM-WB-DE01',20,'WHEAT-FLOUR-01','Wheat Flour Type 550',0.180,'KG',FALSE,'LIFNR-AU-001'),
('BOM-WB-DE01',30,'SUGAR-WHITE-01','White Sugar Refined',0.220,'KG',FALSE,'LIFNR-DE-001'),
-- BOM-MB-NL01 (MaltBurst)
('BOM-MB-NL01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.180,'KG',TRUE,'LIFNR-CI-001'),
('BOM-MB-NL01',20,'MALT-EXTRACT-01','Barley Malt Extract',0.140,'KG',FALSE,'LIFNR-AU-001'),
('BOM-MB-NL01',30,'MILK-POWDER-01','Whole Milk Powder',0.100,'KG',FALSE,'LIFNR-NL-003'),
-- BOM-CB-DE01 (CocoBar)
('BOM-CB-DE01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.200,'KG',TRUE,'LIFNR-CI-001'),
('BOM-CB-DE01',20,'COCONUT-OIL-01','Coconut Oil Refined',0.100,'KG',FALSE,'LIFNR-MY-001'),
('BOM-CB-DE01',30,'SUGAR-WHITE-01','White Sugar Refined',0.180,'KG',FALSE,'LIFNR-DE-001'),
-- BOM-FEST-GB01 (Festival Tin)
('BOM-FEST-GB01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.300,'KG',TRUE,'LIFNR-BE-001'),
('BOM-FEST-GB01',20,'SUGAR-WHITE-01','White Sugar Refined',0.350,'KG',FALSE,'LIFNR-GB-001'),
('BOM-FEST-GB01',30,'MILK-POWDER-01','Whole Milk Powder',0.150,'KG',FALSE,'LIFNR-NL-003'),
('BOM-FEST-GB01',40,'PKG-TIN-01','Printed Tin 650g',1.000,'EA',FALSE,'LIFNR-PL-001'),
-- BOM-NP-PUP-FR01 (NovaPet Medium Puppy)
('BOM-NP-PUP-FR01',10,'CHICK-MEAL-01','Dehydrated Chicken Protein',0.300,'KG',TRUE,'LIFNR-FR-001'),
('BOM-NP-PUP-FR01',20,'RICE-BROKEN-01','Broken Rice',0.250,'KG',FALSE,'LIFNR-TH-002'),
('BOM-NP-PUP-FR01',30,'FISH-MEAL-01','Norwegian Fish Meal',0.100,'KG',TRUE,'LIFNR-NO-001'),
('BOM-NP-PUP-FR01',40,'VIT-PREMIX-01','Vitamin-Mineral Premix',0.015,'KG',TRUE,'LIFNR-CH-001'),
-- BOM-NP-KIT-FR01 (NovaPet Kitten)
('BOM-NP-KIT-FR01',10,'CHICK-MEAL-01','Dehydrated Chicken Protein',0.320,'KG',TRUE,'LIFNR-FR-002'),
('BOM-NP-KIT-FR01',20,'FISH-MEAL-01','Norwegian Fish Meal',0.150,'KG',TRUE,'LIFNR-NO-001'),
('BOM-NP-KIT-FR01',30,'RICE-BROKEN-01','Broken Rice',0.200,'KG',FALSE,'LIFNR-TH-002'),
('BOM-NP-KIT-FR01',40,'VIT-PREMIX-01','Vitamin-Mineral Premix',0.018,'KG',TRUE,'LIFNR-CH-001'),
-- BOM-NP-GNT-FR01 (NovaPet Giant Puppy)
('BOM-NP-GNT-FR01',10,'CHICK-MEAL-01','Dehydrated Chicken Protein',0.350,'KG',TRUE,'LIFNR-FR-001'),
('BOM-NP-GNT-FR01',20,'FISH-MEAL-01','Norwegian Fish Meal',0.120,'KG',TRUE,'LIFNR-NO-001'),
('BOM-NP-GNT-FR01',30,'WHEAT-FLOUR-01','Wheat Flour Type 550',0.200,'KG',FALSE,'LIFNR-FR-004'),
('BOM-NP-GNT-FR01',40,'VIT-PREMIX-01','Vitamin-Mineral Premix',0.020,'KG',TRUE,'LIFNR-CH-001'),
-- BOM-TW-NL02 (TailWag Adult)
('BOM-TW-NL02',10,'CHICK-MEAL-01','Dehydrated Chicken Protein',0.280,'KG',TRUE,'LIFNR-FR-003'),
('BOM-TW-NL02',20,'WHEAT-FLOUR-01','Wheat Flour Type 550',0.300,'KG',FALSE,'LIFNR-AU-001'),
('BOM-TW-NL02',30,'FISH-MEAL-01','Norwegian Fish Meal',0.080,'KG',FALSE,'LIFNR-NO-001'),
-- BOM-PF-NL02 (PurrFresh Adult)
('BOM-PF-NL02',10,'FISH-MEAL-01','Norwegian Fish Meal',0.200,'KG',TRUE,'LIFNR-NO-001'),
('BOM-PF-NL02',20,'CHICK-MEAL-01','Dehydrated Chicken Protein',0.150,'KG',TRUE,'LIFNR-FR-003'),
('BOM-PF-NL02',30,'RICE-BROKEN-01','Broken Rice',0.100,'KG',FALSE,'LIFNR-TH-002'),
-- BOM-GH-GB02 (GrainHarvest Rice)
('BOM-GH-GB02',10,'RICE-LG-01','Long Grain Parboiled Rice',0.480,'KG',TRUE,'LIFNR-TH-002'),
('BOM-GH-GB02',20,'PKG-POUCH-01','Retort Pouch 500g',1.000,'EA',FALSE,'LIFNR-PL-001'),
-- BOM-GH-EXP-GB02 (GrainHarvest Express)
('BOM-GH-EXP-GB02',10,'RICE-LG-01','Long Grain Parboiled Rice',0.240,'KG',TRUE,'LIFNR-TH-002'),
('BOM-GH-EXP-GB02',20,'PKG-MICRO-01','Microwave Tray 250g',1.000,'EA',FALSE,'LIFNR-PL-001'),
-- BOM-CS-DIW-IN01 (ChocoSnap Diwali — same cocoa supply chain as EU)
('BOM-CS-DIW-IN01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.240,'KG',TRUE,'LIFNR-CI-003'),
('BOM-CS-DIW-IN01',20,'SUGAR-WHITE-01','White Sugar Refined',0.300,'KG',FALSE,'LIFNR-BR-001'),
('BOM-CS-DIW-IN01',30,'MILK-POWDER-01','Whole Milk Powder',0.110,'KG',FALSE,'LIFNR-NL-003'),
-- BOM-NC-DIW-IN01 (NutCrunch Diwali)
('BOM-NC-DIW-IN01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.200,'KG',TRUE,'LIFNR-CI-003'),
('BOM-NC-DIW-IN01',20,'PEANUT-RST-01','Roasted Peanut Halves',0.220,'KG',TRUE,'LIFNR-AR-001'),
('BOM-NC-DIW-IN01',30,'SUGAR-WHITE-01','White Sugar Refined',0.200,'KG',FALSE,'LIFNR-BR-001'),
-- BOM-CB-DIW-IN01 (CocoBar Diwali)
('BOM-CB-DIW-IN01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.180,'KG',TRUE,'LIFNR-CI-003'),
('BOM-CB-DIW-IN01',20,'COCONUT-OIL-01','Coconut Oil Refined',0.120,'KG',FALSE,'LIFNR-MY-001'),
('BOM-CB-DIW-IN01',30,'SUGAR-WHITE-01','White Sugar Refined',0.160,'KG',FALSE,'LIFNR-BR-001'),
-- BOM-CS-CNY-SG01 (ChocoSnap CNY — same cocoa supply chain)
('BOM-CS-CNY-SG01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.250,'KG',TRUE,'LIFNR-CI-003'),
('BOM-CS-CNY-SG01',20,'SUGAR-WHITE-01','White Sugar Refined',0.310,'KG',FALSE,'LIFNR-MX-001'),
('BOM-CS-CNY-SG01',30,'MILK-POWDER-01','Whole Milk Powder',0.100,'KG',FALSE,'LIFNR-NL-003'),
-- BOM-NC-CNY-SG01 (NutCrunch CNY)
('BOM-NC-CNY-SG01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.200,'KG',TRUE,'LIFNR-CI-003'),
('BOM-NC-CNY-SG01',20,'PEANUT-RST-01','Roasted Peanut Halves',0.200,'KG',TRUE,'LIFNR-US-003'),
('BOM-NC-CNY-SG01',30,'SUGAR-WHITE-01','White Sugar Refined',0.210,'KG',FALSE,'LIFNR-MX-001'),
-- BOM-FEST-CNY-SG01 (Festival CNY Tin)
('BOM-FEST-CNY-SG01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.300,'KG',TRUE,'LIFNR-CI-003'),
('BOM-FEST-CNY-SG01',20,'SUGAR-WHITE-01','White Sugar Refined',0.350,'KG',FALSE,'LIFNR-MX-001'),
('BOM-FEST-CNY-SG01',30,'MILK-POWDER-01','Whole Milk Powder',0.150,'KG',FALSE,'LIFNR-NL-003'),
('BOM-FEST-CNY-SG01',40,'PKG-TIN-01','Printed Tin 650g',1.000,'EA',FALSE,'LIFNR-PL-001'),
-- BOM-CS-XMAS-NL01 (ChocoSnap Christmas)
('BOM-CS-XMAS-NL01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.260,'KG',TRUE,'LIFNR-CI-003'),
('BOM-CS-XMAS-NL01',20,'SUGAR-WHITE-01','White Sugar Refined',0.320,'KG',FALSE,'LIFNR-NL-001'),
('BOM-CS-XMAS-NL01',30,'MILK-POWDER-01','Whole Milk Powder',0.120,'KG',FALSE,'LIFNR-NL-003'),
-- BOM-NC-XMAS-NL01 (NutCrunch Christmas)
('BOM-NC-XMAS-NL01',10,'COCOA-MASS-01','Cocoa Mass West Africa',0.200,'KG',TRUE,'LIFNR-CI-003'),
('BOM-NC-XMAS-NL01',20,'PEANUT-RST-01','Roasted Peanut Halves',0.220,'KG',TRUE,'LIFNR-US-003'),
('BOM-NC-XMAS-NL01',30,'SUGAR-WHITE-01','White Sugar Refined',0.200,'KG',FALSE,'LIFNR-NL-001');


-- =============================================================
-- LAYER 2: SAP TRANSACTIONAL DATA (replicated via BDC)
-- =============================================================

-- 2.1 Purchase Order Headers (M_V_POH_AGGR simplified)
CREATE OR REPLACE ICEBERG TABLE M_V_POH_AGGR (
    PO_NUMBER       VARCHAR     NOT NULL,
    PO_DATE         DATE,
    SUPPLIER_ID     VARCHAR,
    MATERIAL_ID     VARCHAR,
    PLANT           VARCHAR,
    ORDER_QTY       NUMBER(12,0),
    ORDER_UNIT      VARCHAR,
    NET_VALUE_USD   NUMBER(12,2),
    DELIVERY_DATE   DATE,
    GR_DATE         DATE,       -- NULL = not yet received
    PO_STATUS       VARCHAR,
    PRIMARY KEY (PO_NUMBER)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO M_V_POH_AGGR VALUES
('4500001234','2026-07-15','LIFNR-CI-003','CS-HWEEN-400G','NL01',22500,'KG',208125.00,'2026-08-22',NULL,'OPEN'),
('4500001235','2026-07-15','LIFNR-CI-003','CSP-HWEEN-400G','NL01',18000,'KG',166500.00,'2026-08-22',NULL,'OPEN'),
('4500001236','2026-07-01','LIFNR-CI-001','CS-HWEEN-400G','NL01',30000,'KG',270000.00,'2026-08-05','2026-08-06','RECEIVED'),
('4500001237','2026-07-01','LIFNR-NL-001','CS-HWEEN-400G','NL01',40000,'KG',120000.00,'2026-08-01','2026-08-01','RECEIVED'),
('4500001238','2026-07-10','LIFNR-US-003','CSP-HWEEN-400G','NL01',15000,'KG',67500.00,'2026-08-18','2026-08-19','RECEIVED'),
('4500001239','2026-07-10','LIFNR-US-003','NC-HWEEN-500G','US01',20000,'KG',90000.00,'2026-08-15','2026-08-16','RECEIVED'),
('4500001240','2026-07-20','LIFNR-CI-003','NC-HWEEN-500G','NL01',25000,'KG',237500.00,'2026-08-30',NULL,'OPEN'),
('4500001241','2026-07-10','LIFNR-GH-001','CS-HWEEN-400G','NL01',20000,'KG',180000.00,'2026-08-17','2026-08-16','RECEIVED'),
('4500001242','2026-08-01','LIFNR-CI-003','CSS-US-400G','US01',14500,'KG',137750.00,'2026-09-05',NULL,'OPEN'),
('4500001243','2026-07-20','LIFNR-NL-001','NC-HWEEN-500G','NL01',25000,'KG',75000.00,'2026-08-20','2026-08-20','RECEIVED'),
('4500001244','2026-06-15','LIFNR-FR-001','NP-PUP-MED-4KG','FR01',8000,'KG',112000.00,'2026-07-30','2026-07-30','RECEIVED'),
('4500001245','2026-07-15','LIFNR-FR-001','NP-PUP-MED-4KG','FR01',8000,'KG',112000.00,'2026-08-30',NULL,'BLOCKED'),
('4500001246','2026-07-15','LIFNR-BE-001','CS-HWEEN-400G','NL01',15000,'KG',142500.00,'2026-08-15','2026-08-15','RECEIVED'),
('4500001247','2026-07-20','LIFNR-FR-002','NP-KIT-2KG','FR01',6000,'KG',72000.00,'2026-08-25',NULL,'BLOCKED'),
('4500001248','2026-07-25','LIFNR-GH-001','NC-HWEEN-500G','NL01',18000,'KG',171000.00,'2026-08-28',NULL,'OPEN'),
('4500001249','2026-08-05','LIFNR-FR-003','NP-PUP-MED-4KG','FR01',5000,'KG',70000.00,'2026-09-10',NULL,'OPEN'),
('4500001250','2026-07-01','LIFNR-NO-001','NP-KIT-2KG','FR01',3000,'KG',45000.00,'2026-08-05','2026-08-04','RECEIVED'),
('4500001300','2026-08-01','LIFNR-CI-003','FEST-XMAS-650G','GB01',20000,'KG',190000.00,'2026-09-15',NULL,'OPEN'),
('4500001310','2026-08-10','LIFNR-NO-001','PF-ADL-400G','NL02',4000,'KG',60000.00,'2026-09-09',NULL,'OPEN'),
('4500001500','2026-07-20','LIFNR-CI-003','CSS-US-400G','US01',14500,'KG',137750.00,'2026-08-25',NULL,'OPEN');


-- 2.2 Stock Snapshot (PPH_DDL_STOCK_1 equivalent)
CREATE OR REPLACE ICEBERG TABLE PPH_DDL_STOCK_1 (
    MATERIAL_ID         VARCHAR     NOT NULL,
    PLANT               VARCHAR     NOT NULL,
    UNRESTRICTED_STOCK  NUMBER(12,0),
    IN_TRANSIT_STOCK    NUMBER(12,0),
    SAFETY_STOCK        NUMBER(12,0),
    DAILY_CONSUMPTION   NUMBER(10,0),
    DAYS_OF_SUPPLY      NUMBER(5,1),
    SNAPSHOT_DATE       DATE,
    PRIMARY KEY (MATERIAL_ID, PLANT)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO PPH_DDL_STOCK_1 VALUES
('CS-HWEEN-400G', 'NL01',185000, 22500,210000,5000,37.0,'2026-08-20'),
('CSP-HWEEN-400G','NL01',110000, 18000,168000,4000,27.5,'2026-08-20'),
('CSS-US-400G',   'US01', 95000, 14500,168000,4000,23.8,'2026-08-20'),
('NC-HWEEN-500G', 'NL01',145000, 25000,189000,4500,32.2,'2026-08-20'),
('NC-HWEEN-500G', 'US01',120000, 20000,168000,4000,30.0,'2026-08-20'),
('WB-HWEEN-450G', 'DE01', 80000,     0,105000,3000,26.7,'2026-08-20'),
('MB-HWEEN-350G', 'NL01', 92000,     0, 87500,2500,36.8,'2026-08-20'),
('CB-HWEEN-260G', 'DE01', 55000,     0, 70000,2000,27.5,'2026-08-20'),
('FEST-XMAS-650G','GB01', 40000, 20000,126000,3000,13.3,'2026-08-20'),
('STAR-XMAS-450G','GB01', 35000,     0,105000,2500,14.0,'2026-08-20'),
('NP-PUP-MED-4KG','FR01', 18000,  5000, 31500, 700,25.7,'2026-08-20'),
('NP-KIT-2KG',    'FR01', 12000,  6000, 22500, 500,24.0,'2026-08-20'),
('NP-PUP-GNT-35', 'FR01', 14000,     0, 27000, 600,23.3,'2026-08-20'),
('NP-KIT-IND-2KG','FR01', 10000,     0, 18000, 400,25.0,'2026-08-20'),
('NP-ADL-MED-10K','FR01', 22000,     0, 25200, 600,36.7,'2026-08-20'),
('TW-ADL-15KG',   'NL02', 38000,     0, 42000,1000,38.0,'2026-08-20'),
('TW-PUP-3KG',    'NL02', 15000,     0, 16800, 400,37.5,'2026-08-20'),
('PF-ADL-400G',   'NL02', 25000,  4000, 17500, 500,50.0,'2026-08-20'),
('PF-KIT-300G',   'NL02', 12000,     0, 10500, 300,40.0,'2026-08-20'),
('GH-LG-500G',    'GB02', 30000,     0, 21000, 750,40.0,'2026-08-20'),
('GH-EXP-250G',   'GB02', 22000,     0, 16800, 600,36.7,'2026-08-20'),
('SC-PASTA-500G', 'GB02', 18000,     0, 14000, 500,36.0,'2026-08-20'),
-- Diwali SKUs (IN01) — new market, low initial stock = visible coverage risk
('CS-DIWALI-400G', 'IN01', 15000,     0, 52500,1500,10.0,'2026-08-20'),
('NC-DIWALI-500G', 'IN01', 12000,     0, 42000,1200,10.0,'2026-08-20'),
('CB-DIWALI-300G', 'IN01',  8000,     0, 28000, 800,10.0,'2026-08-20'),
-- CNY SKUs (SG01) — early planning stage, low stock
('CS-CNY-400G',    'SG01', 10000,     0, 42000,1200, 8.3,'2026-08-20'),
('NC-CNY-500G',    'SG01',  8000,     0, 42000,1200, 6.7,'2026-08-20'),
('FEST-CNY-650G',  'SG01',  5000,     0, 63000,1500, 3.3,'2026-08-20'),
-- Christmas expansion (NL01)
('CS-XMAS-400G',   'NL01', 45000,     0,168000,4000,11.3,'2026-08-20'),
('NC-XMAS-500G',   'NL01', 40000,     0,189000,4500, 8.9,'2026-08-20'),
('STAR-XMAS-450G', 'NL01', 30000,     0,105000,2500,12.0,'2026-08-20');


-- =============================================================
-- LAYER 3: BLUE YONDER IBP & TMS DATA
-- =============================================================

-- 3.1 Demand Forecast (BY IBP export)
CREATE OR REPLACE ICEBERG TABLE BY_DEMAND_FORECAST (
    MATERIAL_ID      VARCHAR     NOT NULL,
    WEEK_START       DATE        NOT NULL,
    FORECAST_QTY     NUMBER(12,0),
    BASELINE_QTY     NUMBER(12,0),
    SEASONAL_LIFT_PCT NUMBER(5,1),
    IS_PEAK_WEEK     BOOLEAN,
    PEAK_EVENT       VARCHAR,
    FORECAST_VERSION VARCHAR,
    PRIMARY KEY (MATERIAL_ID, WEEK_START)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO BY_DEMAND_FORECAST
WITH weeks AS (
    SELECT DATEADD('week', seq4(), '2026-08-18') AS week_start
    FROM TABLE(GENERATOR(ROWCOUNT => 26))
)
SELECT material_id, week_start,
    ROUND(base_qty * (1 + CASE WHEN week_start BETWEEN peak_start AND peak_end THEN lift ELSE 0 END) + UNIFORM(-500,500,RANDOM())),
    base_qty,
    CASE WHEN week_start BETWEEN peak_start AND peak_end THEN lift*100 ELSE 0 END,
    week_start BETWEEN peak_start AND peak_end,
    CASE WHEN week_start BETWEEN peak_start AND peak_end THEN peak_event ELSE NULL END,
    'IBP-2026-AUG-W3'
FROM weeks CROSS JOIN (
    SELECT 'CS-HWEEN-400G'  AS material_id, 5000  AS base_qty, '2026-10-06' ::DATE AS peak_start, '2026-10-27'::DATE AS peak_end, 2.8 AS lift, 'HALLOWEEN_2026' AS peak_event UNION ALL
    SELECT 'CSP-HWEEN-400G',                4000,              '2026-10-06',                        '2026-10-27',                  2.5,         'HALLOWEEN_2026' UNION ALL
    SELECT 'CSS-US-400G',                   4000,              '2026-10-06',                        '2026-10-27',                  3.0,         'HALLOWEEN_2026' UNION ALL
    SELECT 'NC-HWEEN-500G',                 4500,              '2026-10-06',                        '2026-10-27',                  2.6,         'HALLOWEEN_2026' UNION ALL
    SELECT 'WB-HWEEN-450G',                 3000,              '2026-10-06',                        '2026-10-27',                  2.2,         'HALLOWEEN_2026' UNION ALL
    SELECT 'MB-HWEEN-350G',                 2500,              '2026-10-13',                        '2026-10-27',                  1.8,         'HALLOWEEN_2026' UNION ALL
    SELECT 'CB-HWEEN-260G',                 2000,              '2026-10-13',                        '2026-10-27',                  1.5,         'HALLOWEEN_2026' UNION ALL
    SELECT 'FEST-XMAS-650G',                3000,              '2026-11-09',                        '2026-12-14',                  3.2,         'CHRISTMAS_2026' UNION ALL
    SELECT 'STAR-XMAS-450G',                2500,              '2026-11-09',                        '2026-12-14',                  2.8,         'CHRISTMAS_2026' UNION ALL
    SELECT 'CS-XMAS-400G',                  4000,              '2026-11-09',                        '2026-12-14',                  3.0,         'CHRISTMAS_2026' UNION ALL
    SELECT 'NC-XMAS-500G',                  4500,              '2026-11-09',                        '2026-12-14',                  2.8,         'CHRISTMAS_2026' UNION ALL
    -- Diwali 2026 (Oct 20 is Diwali — peak buying Oct 6-Nov 2)
    SELECT 'CS-DIWALI-400G',                1500,              '2026-10-05',                        '2026-11-02',                  2.8,         'DIWALI_2026' UNION ALL
    SELECT 'NC-DIWALI-500G',                1200,              '2026-10-05',                        '2026-11-02',                  2.5,         'DIWALI_2026' UNION ALL
    SELECT 'CB-DIWALI-300G',                 800,              '2026-10-05',                        '2026-11-02',                  2.0,         'DIWALI_2026' UNION ALL
    -- Chinese New Year 2027 (Feb 6 is CNY — peak buying Jan 19 - Feb 8)
    SELECT 'CS-CNY-400G',                   1200,              '2027-01-19',                        '2027-02-08',                  3.0,         'CNY_2027' UNION ALL
    SELECT 'NC-CNY-500G',                   1200,              '2027-01-19',                        '2027-02-08',                  2.8,         'CNY_2027' UNION ALL
    SELECT 'FEST-CNY-650G',                 1500,              '2027-01-19',                        '2027-02-08',                  3.5,         'CNY_2027' UNION ALL
    -- Petcare peaks (unchanged)
    SELECT 'NP-PUP-MED-4KG',                700,              '2027-02-03',                        '2027-03-31',                  1.4,         'SPRING_PUPPY_2027' UNION ALL
    SELECT 'NP-KIT-2KG',                     500,              '2027-02-03',                        '2027-03-31',                  1.6,         'SPRING_KITTEN_2027'
) sku;


-- 3.2 Consensus Plan (S&OP output)
CREATE OR REPLACE ICEBERG TABLE BY_CONSENSUS_PLAN (
    MATERIAL_ID         VARCHAR     NOT NULL,
    PLAN_VERSION        VARCHAR,
    COMMITTED_QTY       NUMBER(12,0),
    REVENUE_PLAN_USD    NUMBER(14,2),
    PLAN_CONFIDENCE     VARCHAR,
    PRIMARY KEY (MATERIAL_ID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO BY_CONSENSUS_PLAN VALUES
('CS-HWEEN-400G', 'S&OP-2026-AUG',280000, 537600.00,'HIGH'),
('CSP-HWEEN-400G','S&OP-2026-AUG',220000, 451000.00,'HIGH'),
('CSS-US-400G',   'S&OP-2026-AUG',210000, 441000.00,'HIGH'),
('NC-HWEEN-500G', 'S&OP-2026-AUG',260000, 572000.00,'HIGH'),
('WB-HWEEN-450G', 'S&OP-2026-AUG',160000, 316800.00,'MEDIUM'),
('MB-HWEEN-350G', 'S&OP-2026-AUG',120000, 222000.00,'MEDIUM'),
('CB-HWEEN-260G', 'S&OP-2026-AUG', 90000, 160200.00,'MEDIUM'),
('FEST-XMAS-650G','S&OP-2026-AUG',180000, 810000.00,'HIGH'),
('STAR-XMAS-450G','S&OP-2026-AUG',120000, 342000.00,'MEDIUM'),
('CS-XMAS-400G',  'S&OP-2026-AUG',200000, 480000.00,'HIGH'),
('NC-XMAS-500G',  'S&OP-2026-AUG',220000, 572000.00,'HIGH'),
-- Diwali — new market entry, lower confidence
('CS-DIWALI-400G','S&OP-2026-AUG', 40000,  88000.00,'LOW'),
('NC-DIWALI-500G','S&OP-2026-AUG', 35000,  87500.00,'LOW'),
('CB-DIWALI-300G','S&OP-2026-AUG', 20000,  38000.00,'LOW'),
-- CNY — APAC growth market, medium confidence
('CS-CNY-400G',   'S&OP-2026-AUG', 30000,  70500.00,'MEDIUM'),
('NC-CNY-500G',   'S&OP-2026-AUG', 30000,  76500.00,'MEDIUM'),
('FEST-CNY-650G', 'S&OP-2026-AUG', 35000, 168000.00,'MEDIUM'),
-- Petcare (unchanged)
('NP-PUP-MED-4KG','S&OP-2026-AUG', 42000, 621600.00,'MEDIUM'),
('NP-KIT-2KG',    'S&OP-2026-AUG', 32000, 307200.00,'MEDIUM'),
('NP-PUP-GNT-35', 'S&OP-2026-AUG', 35000, 567000.00,'MEDIUM');


-- 3.3 Loads (TMS)
CREATE OR REPLACE ICEBERG TABLE BY_LOADS (
    LOAD_ID             VARCHAR     NOT NULL,
    LANE_ID             VARCHAR,
    CARRIER_ID          VARCHAR,
    SHIPMENT_DATE       DATE,
    DELIVERY_DATE       DATE,
    LOAD_STATUS         VARCHAR,
    RELATED_PO          VARCHAR,
    WEIGHT_KG           NUMBER(10,0),
    PRIMARY KEY (LOAD_ID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO BY_LOADS VALUES
('LD-001','LANE-CIABJ-NLRTM','MAERSK-OCEAN','2026-08-01','2026-08-22','LATE','4500001234',22500),
('LD-002','LANE-CIABJ-NLRTM','CMA-CGM',     '2026-07-28','2026-08-18','DELIVERED','4500001236',30000),
('LD-003','LANE-CIABJ-NLRTM','HAPAG',        '2026-08-14','2026-08-15','DELIVERED','4500001246',15000),
('LD-004','LANE-CIABJ-USNYC','MAERSK-OCEAN','2026-08-05','2026-08-24','LATE','4500001500',14500),
('LD-005','LANE-NOSVG-NLRTM','NO-BULK-01',  '2026-09-05','2026-09-09','SCHEDULED','4500001310',4000),
('LD-006','LANE-CIABJ-NLRTM','CMA-CGM',     '2026-08-05','2026-08-28','IN_TRANSIT','4500001248',18000),
('LD-007','LANE-CIABJ-NLRTM','CMA-CGM',     '2026-07-25','2026-08-17','DELIVERED','4500001241',20000),
('LD-008','LANE-CIABJ-NLRTM','CMA-CGM',     '2026-08-01','2026-09-15','BLOCKED','4500001300',20000),
('LD-009','LANE-NLRTM-GB01', 'ROAD-NL-01',  '2026-08-21','2026-08-22','SCHEDULED',NULL,12000),
('LD-010','LANE-CIABJ-NLRTM','MAERSK-OCEAN','2026-07-20','2026-08-30','LATE','4500001240',25000);


-- 3.4 Lanes
CREATE OR REPLACE ICEBERG TABLE BY_LANES (
    LANE_ID             VARCHAR     NOT NULL,
    ORIGIN_PORT         VARCHAR,
    DESTINATION_PORT    VARCHAR,
    MODE                VARCHAR,
    TRANSIT_DAYS_AVG    NUMBER(3,0),
    PRIMARY KEY (LANE_ID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO BY_LANES VALUES
('LANE-CIABJ-NLRTM','CIABJ','NLRTM','OCEAN',21),
('LANE-CIABJ-USNYC','CIABJ','USNYC','OCEAN',18),
('LANE-NOSVG-NLRTM','NOSVG','NLRTM','OCEAN', 4),
('LANE-NOSVG-BEANR','NOSVG','BEANR','OCEAN', 3),
('LANE-NLRTM-GB01', 'NLRTM','GBFXT','ROAD',  1),
('LANE-BEANR-DE01', 'BEANR','DEHAM','ROAD',  1);


-- 3.5 Tender Events
CREATE OR REPLACE ICEBERG TABLE BY_TENDER_EVENTS (
    TENDER_ID       VARCHAR     NOT NULL,
    LOAD_ID         VARCHAR,
    CARRIER_ID      VARCHAR,
    TENDER_TIME     TIMESTAMP_NTZ,
    RESPONSE_TYPE   VARCHAR,
    RESPONSE_TIME   TIMESTAMP_NTZ,
    PRIMARY KEY (TENDER_ID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO BY_TENDER_EVENTS VALUES
('TE-001','LD-001','MAERSK-OCEAN','2026-07-28 09:00:00','LATE_ACCEPT','2026-07-29 14:30:00'),
('TE-002','LD-004','CMA-CGM',     '2026-08-01 10:00:00','REJECTED',   '2026-08-01 12:00:00'),
('TE-003','LD-004','MAERSK-OCEAN','2026-08-02 08:00:00','LATE_ACCEPT','2026-08-03 16:00:00'),
('TE-004','LD-008','CMA-CGM',     '2026-07-25 09:00:00','SILENT_DECLINE',NULL),
('TE-005','LD-008','HAPAG',        '2026-07-26 09:00:00','SILENT_DECLINE',NULL),
('TE-006','LD-008','MAERSK-OCEAN','2026-07-27 09:00:00','REJECTED',   '2026-07-27 11:00:00'),
('TE-007','LD-010','CMA-CGM',     '2026-07-15 10:00:00','LATE_ACCEPT','2026-07-17 09:00:00'),
('TE-008','LD-005','NO-BULK-01',  '2026-09-01 08:00:00','ACCEPTED',   '2026-09-01 09:30:00'),
('TE-009','LD-006','CMA-CGM',     '2026-08-01 09:00:00','ACCEPTED',   '2026-08-01 10:00:00');


-- =============================================================
-- LAYER 4: EXTERNAL MARKET SIGNALS
-- =============================================================

CREATE OR REPLACE ICEBERG TABLE EXT_COMMODITY_PRICES (
    PRICE_DATE      DATE         NOT NULL,
    COMMODITY       VARCHAR      NOT NULL,
    SPOT_PRICE      NUMBER(10,2),
    SUPPLY_TIGHTNESS VARCHAR,
    PRICE_UNIT      VARCHAR,
    CURRENCY        VARCHAR,
    YOY_CHANGE_PCT  NUMBER(5,2),
    PRIMARY KEY (PRICE_DATE, COMMODITY)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO EXT_COMMODITY_PRICES
WITH dates AS (SELECT DATEADD('day',-seq4(),'2026-08-20') AS price_date FROM TABLE(GENERATOR(ROWCOUNT=>90)))
SELECT price_date, commodity,
    ROUND(base_spot * (1 + trend_factor * DATEDIFF('day',price_date,'2026-08-20')/90) + UNIFORM(-50,50,RANDOM()), 2),
    tightness,
    unit, currency, ROUND(yoy_change+UNIFORM(-2.0,2.0,RANDOM()),2)
FROM dates CROSS JOIN (
    SELECT 'COCOA'        AS commodity, 9250.00 AS base_spot, 0.18 AS trend_factor,'USD/MT' AS unit,'USD' AS currency, 28.4 AS yoy_change,'TIGHT'  AS tightness UNION ALL
    SELECT 'SUGAR_WHITE',               520.00,              -0.04,               'USD/MT',       'USD',              -3.2,              'NORMAL' UNION ALL
    SELECT 'CHICKEN_MEAL',             1380.00,               0.22,               'EUR/MT',       'EUR',              31.5,              'TIGHT'  UNION ALL
    SELECT 'PALM_OIL',                  968.00,               0.06,               'USD/MT',       'USD',               8.2,              'NORMAL' UNION ALL
    SELECT 'WHEAT',                     242.00,              -0.08,               'USD/MT',       'USD',              -5.1,              'LOOSE'
) c;


CREATE OR REPLACE  ICEBERG TABLE EXT_PORT_CONGESTION (
    REPORT_DATE         DATE            NOT NULL,
    PORT_CODE           VARCHAR     NOT NULL,
    PORT_NAME           VARCHAR,
    COUNTRY             VARCHAR,
    CONGESTION_SCORE    NUMBER(4,1),
    AVG_WAIT_HOURS      NUMBER(6,1),
    VESSELS_AT_ANCHOR   NUMBER(5,0),
    GATE_THROUGHPUT_PCT NUMBER(5,1),
    ALERT_LEVEL         VARCHAR,
    PRIMARY KEY (REPORT_DATE, PORT_CODE)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO EXT_PORT_CONGESTION
WITH dates AS (SELECT DATEADD('day',-seq4(),'2026-08-20') AS report_date FROM TABLE(GENERATOR(ROWCOUNT=>45)))
SELECT report_date, port_code, port_name, country,
    ROUND(base_score+UNIFORM(-0.5,0.5,RANDOM())+trend,1),
    ROUND(base_wait +UNIFORM(-4,4,RANDOM())+(trend*12),1),
    ROUND(base_vessels+UNIFORM(-3,3,RANDOM()),0),
    ROUND(base_throughput+UNIFORM(-3,3,RANDOM())-(trend*5),1),
    CASE WHEN base_score+trend>7 THEN 'CRITICAL' WHEN base_score+trend>5 THEN 'HIGH' WHEN base_score+trend>3 THEN 'ELEVATED' ELSE 'NORMAL' END
FROM dates CROSS JOIN (
    SELECT 'NLRTM' AS port_code,'Port of Rotterdam'        AS port_name,'Netherlands'  AS country,7.2 AS base_score,48.0 AS base_wait,24 AS base_vessels,78.0 AS base_throughput,0.08 AS trend UNION ALL
    SELECT 'CIABJ',             'Port of Abidjan',                       'Ivory Coast',             5.8,             36.0,             18,               84.0,               0.05 UNION ALL
    SELECT 'BEANR',             'Port of Antwerp',                       'Belgium',                 4.1,             22.0,             12,               91.0,              -0.02 UNION ALL
    SELECT 'GBFXT',             'Port of Felixstowe',                    'United Kingdom',           3.8,             18.0,             10,               93.0,               0.01 UNION ALL
    SELECT 'USNYC',             'Port of New York/NJ',                   'United States',            4.5,             26.0,             15,               88.0,               0.04 UNION ALL
    SELECT 'NOSVG',             'Port of Bergen',                        'Norway',                   1.8,              8.0,              4,               97.0,              -0.01
) p;


CREATE OR REPLACE  ICEBERG TABLE EXT_VESSEL_TRACKER (
    VESSEL_ID           VARCHAR     NOT NULL,
    VESSEL_NAME         VARCHAR,
    VESSEL_TYPE         VARCHAR,
    CARRIER_ID          VARCHAR,
    CARGO_TYPE          VARCHAR,
    RELATED_PO          VARCHAR,
    DEPARTURE_PORT      VARCHAR,
    DESTINATION_PORT    VARCHAR,
    DEPARTURE_DATE      DATE,
    ORIGINAL_ETA        DATE,
    REVISED_ETA         DATE,
    CURRENT_STATUS      VARCHAR,
    DELAY_DAYS          NUMBER(4,0),
    LAST_POSITION_DESC  VARCHAR,
    PRIMARY KEY (VESSEL_ID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3

;

INSERT INTO EXT_VESSEL_TRACKER VALUES
('MV-AFRICAN-QUEEN','MV African Queen','BULK CARRIER','MAERSK-OCEAN','Cocoa Beans','4500001234','CIABJ','NLRTM','2026-08-01','2026-08-22','2026-08-26','AT_ANCHOR', 4,
 'Waiting at Rotterdam outer anchorage — berth unavailable due to port congestion'),
('MV-SAHARA-STAR',  'MV Sahara Star', 'CONTAINER',  'CMA-CGM',    'Cocoa Mass', NULL,          'CIABJ','NLRTM','2026-07-28','2026-08-18','2026-08-18','IN_PORT',   0,
 'Berthed Rotterdam — discharge in progress'),
('MV-CAPE-HARVEST', 'MV Cape Harvest','BULK CARRIER','HAPAG',      'Cocoa Mass', '4500001246',  'BEANR','NLRTM','2026-08-14','2026-08-15','2026-08-15','IN_PORT',   0,
 'West Cocoa BE consignment — discharge complete'),
('MV-NORDIC-BULK',  'MV Nordic Bulk', 'BULK CARRIER','NO-BULK-01', 'Fish Meal',  '4500001310',  'NOSVG','NLRTM','2026-09-05','2026-09-09','2026-09-09','SCHEDULED', 0,
 'Scheduled departure Bergen — on time for Montpellier'),
('MV-ATLANTIC-WAVE','MV Atlantic Wave','CONTAINER',  'MAERSK-OCEAN','Cocoa Mass','4500001500',  'CIABJ','USNYC','2026-08-05','2026-08-24','2026-08-29','AT_ANCHOR', 5,
 'Waiting New York anchorage — Lancaster PA supply at risk'),
('MV-ACCRA-PRIDE',  'MV Accra Pride', 'BULK CARRIER','CMA-CGM',    'Cocoa Mass', '4500001248',  'AAGLO','NLRTM','2026-08-05','2026-08-28','2026-08-27','IN_TRANSIT',0,
 'En route Rotterdam — Sahel Agri Ghana consignment, on schedule'),
('MV-GHANA-STAR',   'MV Ghana Star',  'BULK CARRIER','CMA-CGM',    'Cocoa Beans','4500001241',  'AAGLO','NLRTM','2026-07-25','2026-08-17','2026-08-16','ARRIVED',  -1,
 'Arrived Rotterdam 1 day early — discharge 85% complete'),
('MV-NORDIC-FROST', 'MV Nordic Frost','REEFER',      'NO-BULK-01', 'Fish Meal',  NULL,          'NOSVG','BEANR','2026-08-18','2026-08-22','2026-08-22','IN_TRANSIT',0,
 'En route Antwerp — PurrFresh fish meal consignment NL02, on schedule');


CREATE OR REPLACE  ICEBERG TABLE EXT_OUTBREAK_ALERTS (
    ALERT_ID             VARCHAR     NOT NULL,
    ALERT_DATE           DATE,
    PATHOGEN             VARCHAR,
    DISEASE_NAME         VARCHAR,
    COUNTRY              VARCHAR,
    REGION               VARCHAR,
    RISK_LEVEL           VARCHAR,
    MOVEMENT_RESTRICTION BOOLEAN,
    PROTECTION_ZONE_KM   NUMBER(5,0),
    SURVEILLANCE_ZONE_KM NUMBER(5,0),
    AFFECTED_SPECIES     VARCHAR,
    STATUS               VARCHAR,
    SOURCE_AUTHORITY     VARCHAR,
    SUPPLY_CHAIN_IMPACT  VARCHAR,
    PRIMARY KEY (ALERT_ID)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3;

INSERT INTO EXT_OUTBREAK_ALERTS VALUES
('ALT-2026-FR-001','2026-01-15','H5N1 HPAI','Highly Pathogenic Avian Influenza','France',
 'Pays de la Loire (Loire-Atlantique, Vendée)','HIGH',TRUE,3,10,'Poultry','ACTIVE','DGAL',
 'Impacts Volaille Atlantique and Loire Protein — NovaPet supplier LIFNR-FR-001, LIFNR-FR-002'),
('ALT-2026-FR-002','2026-01-20','H5N1 HPAI','Highly Pathogenic Avian Influenza — extended zone','France',
 'Pays de la Loire extended','HIGH',TRUE,10,30,'Poultry','ACTIVE','DGAL/ANSES',
 'Zone extension — both primary NovaPet protein suppliers blocked. Bretagne Agri unaffected'),
('ALT-2026-FR-003','2026-02-01','H5N1 HPAI','H5N1 Surveillance only — Bretagne','France',
 'Bretagne (surveillance zone)','LOW',FALSE,0,10,'Poultry','RESOLVED','DGAL',
 'Surveillance only — no restrictions. LIFNR-FR-003 (Bretagne Agri) fully operational'),
('ALT-2026-CI-001','2026-07-01','DROUGHT','Extended Dry Season — Cocoa Yield Impact','Ivory Coast',
 'Grand Abidjan, Yamoussoukro hinterland','MEDIUM',FALSE,0,0,'Cocoa crop','ACTIVE','Conseil Café-Cacao',
 'Cocoa arrivals at Abidjan -18% YoY. Atlantic Origins (LIFNR-CI-003) supply availability directly impacted'),
('ALT-2026-DE-001','2026-06-10','FMD','Foot-and-Mouth Disease — contained','Germany',
 'Bayerischer Wald (limited)','LOW',FALSE,3,10,'Livestock','RESOLVED','Friedrich-Loeffler-Institut',
 'Contained — no impact on protein supply. Nordfleisch (LIFNR-DE-002) unaffected'),
('ALT-2026-TH-001','2026-03-15','FLOOD','Chao Phraya River Flooding — logistics disruption','Thailand',
 'Ayutthaya, Pathum Thani','MEDIUM',FALSE,0,0,'Rice/cereal','RESOLVED','Thai Met Dept',
 'Flooding resolved. Bangkok Rice Exports (LIFNR-TH-002) back to normal operations');


CREATE OR REPLACE  ICEBERG TABLE EXT_NEWS_RISK_EVENTS (
    EVENT_ID            VARCHAR     NOT NULL,
    EVENT_DATE          DATE,
    HEADLINE            VARCHAR,
    SOURCE              VARCHAR,
    RISK_CATEGORY       VARCHAR,
    AFFECTED_REGION     VARCHAR,
    AFFECTED_COMMODITY  VARCHAR,
    SEVERITY            VARCHAR,
    SUPPLY_CHAIN_SIGNAL VARCHAR,
    RELATED_SUPPLIER    VARCHAR,
    PRIMARY KEY (EVENT_ID)
)CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
ICEBERG_VERSION = 3

;

INSERT INTO EXT_NEWS_RISK_EVENTS VALUES
('NRE-001','2026-08-15','Rotterdam port workers threaten industrial action — wage talks stalled for 3rd time',
 'Lloyd''s List Intelligence','LABOR','Rotterdam, Netherlands','MULTIPLE','HIGH',
 'Port throughput risk: Rotterdam gate capacity may drop 30-40% from Aug 22 if strike proceeds. Affects all NL01 inbound','NULL'),
('NRE-002','2026-08-10','Ivory Coast cocoa arrivals down 18% year-on-year as extended dry season bites',
 'Agrimoney / CCC Report','COMMODITY','Ivory Coast, West Africa','COCOA','HIGH',
 'Reduced origin supply. Premium over futures widening. LIFNR-CI-003 likely to miss Sept delivery','LIFNR-CI-003'),
('NRE-003','2026-07-22','West Africa: Harmattan winds arrive early — cocoa harvest delayed 2-3 weeks',
 'Tropical Research Services','COMMODITY','Ivory Coast, Ghana','COCOA','MEDIUM',
 'Seasonal harvest delay compounds logistics pressure. All Abidjan-origin cocoa shipments affected',NULL),
('NRE-004','2026-01-12','French poultry farms ordered to quarantine following H5N1 in Loire-Atlantique',
 'Le Monde / DGAL Official Gazette','BIOSECURITY','Pays de la Loire, France','CHICKEN','CRITICAL',
 'Movement restrictions active. Poultry processing suspended in 3km zone. Affects Volaille Atlantique (LIFNR-FR-001)','LIFNR-FR-001'),
('NRE-005','2026-01-20','DGAL extends H5N1 protection zone — 10km radius now covers Vendée sites',
 'DGAL Official Gazette','BIOSECURITY','Pays de la Loire, France','CHICKEN','CRITICAL',
 'Zone extension covers Loire Protein facility. Both primary NovaPet protein suppliers now restricted','LIFNR-FR-002'),
('NRE-006','2026-08-05','Global ocean freight rates surge 22% on Asia-Europe — spillover to Africa routes',
 'Drewry / Freightos Baltic Index','LOGISTICS','Global ocean freight','MULTIPLE','MEDIUM',
 'Spot rate pressure on Abidjan-Rotterdam lane. Contract premium now 19%. Carrier acceptance declining',NULL),
('NRE-007','2026-08-18','Bretagne Agri confirms normal operations in Bretagne — no H5N1 restrictions',
 'Bretagne Agri Press Release','BIOSECURITY','Bretagne, France','CHICKEN','LOW',
 'Confirmed alternate supplier LIFNR-FR-003 fully operational. 8,000 MT/quarter available','LIFNR-FR-003'),
('NRE-008','2026-08-12','Atlantic Origins declares force majeure on September cocoa deliveries from Ivory Coast',
 'Reuters Commodities','COMMODITY','Ivory Coast / Rotterdam','COCOA','CRITICAL',
 'Force majeure by LIFNR-CI-003 (Atlantic Origins) on all Sept 2026 contracts. 22,500 MT EU + 14,500 MT US at risk','LIFNR-CI-003'),
('NRE-009','2026-08-01','Suez Canal traffic normalises — minor positive effect on West Africa lanes',
 'Splash 247 Maritime','LOGISTICS','Suez Canal / Red Sea','MULTIPLE','LOW',
 'Canal transit improving. Minor positive effect on Abidjan-Rotterdam schedule reliability expected Q4',NULL),
('NRE-010','2026-07-28','US FDA issues import alert on poultry products from Pays de la Loire',
 'US FDA Federal Register','BIOSECURITY','Pays de la Loire, France','CHICKEN','HIGH',
 'Import alert 99-38 issued. Affects contingency sourcing from French suppliers to US plants','LIFNR-FR-001'),
('NRE-011','2026-08-08','West Cocoa Antwerp confirms full availability for spot cocoa orders',
 'West Cocoa Investor Update','COMMODITY','Antwerp, Belgium','COCOA','LOW',
 'LIFNR-BE-001 confirms 15,000 MT spot availability at listed premium. Alternative to CI-003 for Q4','LIFNR-BE-001'),
('NRE-012','2026-08-20','Cocoa futures hit 18-month high on ICE London as West Africa outlook worsens',
 'Financial Times Commodities','COMMODITY','Global cocoa market','COCOA','HIGH',
 'ICE cocoa futures 9,800 GBP/MT. Forward purchasing +28% YoY for Oct-Dec contracts. Cost exposure significant',NULL);


-- =============================================================
-- LAYER 5: INTELLIGENCE VIEWS
-- Snowflake computes the "so what" SAP and BY cannot see alone.
-- =============================================================

-- Plan overrides table (written by Streamlit dashboard)
CREATE TABLE IF NOT EXISTS BY_PLAN_OVERRIDES (
    MATERIAL_ID         VARCHAR     NOT NULL,
    OVERRIDE_QTY        NUMBER(12,0),
    OVERRIDE_REASON     VARCHAR,
    OVERRIDDEN_BY       VARCHAR     DEFAULT CURRENT_USER(),
    OVERRIDE_TIMESTAMP  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (MATERIAL_ID)
);

CREATE OR REPLACE VIEW V_BOM_RISK_EXPLOSION AS
SELECT
    s.SUPPLIER_ID, s.SUPPLIER_NAME,
    s.COUNTRY AS SUPPLIER_COUNTRY, s.REGION AS SUPPLIER_REGION,
    s.CREDIT_RATING, s.IS_SOLE_SOURCE, s.CONTRACT_END,
    bi.COMPONENT_ID, bi.COMPONENT_DESC, bi.IS_CRITICAL AS COMPONENT_IS_CRITICAL,
    b.MATERIAL_ID AS FINISHED_GOOD_ID, p.MATERIAL_DESC AS FINISHED_GOOD_DESC,
    p.DIVISION, p.BRAND, p.UNIT_WHOLESALE_USD, b.PLANT, pp.SAFETY_STOCK_DAYS,
    st.DAYS_OF_SUPPLY AS CURRENT_DAYS_OF_SUPPLY,
    (pp.SAFETY_STOCK_DAYS - st.DAYS_OF_SUPPLY) AS SAFETY_STOCK_GAP_DAYS,
    CASE
        WHEN oa.RISK_LEVEL IN ('HIGH','CRITICAL') THEN 'BIOSECURITY_RESTRICTION'
        WHEN s.CREDIT_RATING IN ('B','B-','C')    THEN 'LOW_CREDIT_RATING'
        WHEN s.IS_SOLE_SOURCE = TRUE              THEN 'SOLE_SOURCE_DEPENDENCY'
        ELSE 'DELIVERY_DELAY'
    END AS RISK_REASON,
    COALESCE(oa.DISEASE_NAME, nr.RISK_CATEGORY) AS RISK_EVENT_TYPE,
    COALESCE(oa.RISK_LEVEL, s.CREDIT_RATING)    AS RISK_LEVEL
FROM I_SUPPLIER s
JOIN I_BILLOFMATERIALITEM bi ON bi.PREFERRED_SUPPLIER = s.SUPPLIER_ID
JOIN I_BILLOFMATERIAL b      ON b.BOM_ID = bi.BOM_ID
JOIN I_PRODUCT p             ON p.MATERIAL_ID = b.MATERIAL_ID
JOIN I_PRODUCTPLANT pp       ON pp.MATERIAL_ID = b.MATERIAL_ID AND pp.PLANT = b.PLANT
LEFT JOIN PPH_DDL_STOCK_1 st ON st.MATERIAL_ID = b.MATERIAL_ID AND st.PLANT = b.PLANT
LEFT JOIN EXT_OUTBREAK_ALERTS oa  ON oa.COUNTRY = s.COUNTRY AND oa.STATUS = 'ACTIVE'
LEFT JOIN EXT_NEWS_RISK_EVENTS nr ON nr.RELATED_SUPPLIER = s.SUPPLIER_ID AND nr.SEVERITY IN ('HIGH','CRITICAL')
WHERE s.CREDIT_RATING IN ('B','B-','B+','C','C+')
   OR s.IS_SOLE_SOURCE = TRUE
   OR oa.ALERT_ID IS NOT NULL
   OR (st.DAYS_OF_SUPPLY < pp.SAFETY_STOCK_DAYS AND st.DAYS_OF_SUPPLY IS NOT NULL);


-- Grain: one row per MATERIAL_ID x PEAK_EVENT.
-- The S&OP commitment covers the whole forecast horizon, so it is pro-rated to the
-- peak weeks before comparing it with peak-week demand.
CREATE OR REPLACE VIEW V_SEASONAL_COVERAGE_GAP AS
WITH horizon AS (
    SELECT MATERIAL_ID, COUNT(DISTINCT WEEK_START) AS HORIZON_WEEKS
    FROM BY_DEMAND_FORECAST GROUP BY MATERIAL_ID
),
peak_demand AS (
    SELECT f.MATERIAL_ID, f.PEAK_EVENT,
        SUM(f.FORECAST_QTY)     AS TOTAL_FORECAST_QTY,
        SUM(f.BASELINE_QTY)     AS TOTAL_BASELINE_QTY,
        AVG(f.SEASONAL_LIFT_PCT) AS AVG_LIFT_PCT,
        COUNT(*)                 AS PEAK_WEEKS
    FROM BY_DEMAND_FORECAST f WHERE f.IS_PEAK_WEEK = TRUE
    GROUP BY f.MATERIAL_ID, f.PEAK_EVENT
),
committed_plan AS (
    SELECT MATERIAL_ID, SUM(COMMITTED_QTY) AS TOTAL_COMMITTED_QTY,
        SUM(REVENUE_PLAN_USD) AS TOTAL_REVENUE_PLAN_USD
    FROM BY_CONSENSUS_PLAN GROUP BY MATERIAL_ID
),
-- Stock and safety targets rolled up across plants (joined on MATERIAL_ID + PLANT)
material_stock AS (
    SELECT pp.MATERIAL_ID,
        SUM(COALESCE(st.UNRESTRICTED_STOCK, 0)) AS UNRESTRICTED_STOCK,
        MIN(st.DAYS_OF_SUPPLY)                  AS DAYS_OF_SUPPLY,
        MAX(pp.SAFETY_STOCK_DAYS)               AS SAFETY_STOCK_DAYS
    FROM I_PRODUCTPLANT pp
    LEFT JOIN PPH_DDL_STOCK_1 st ON st.MATERIAL_ID = pp.MATERIAL_ID AND st.PLANT = pp.PLANT
    GROUP BY pp.MATERIAL_ID
),
gap AS (
    SELECT pd.*, h.HORIZON_WEEKS, cp.TOTAL_COMMITTED_QTY,
        ROUND(cp.TOTAL_COMMITTED_QTY * pd.PEAK_WEEKS / h.HORIZON_WEEKS, 0) AS PEAK_COMMITTED_QTY
    FROM peak_demand pd
    JOIN horizon h              ON h.MATERIAL_ID = pd.MATERIAL_ID
    LEFT JOIN committed_plan cp ON cp.MATERIAL_ID = pd.MATERIAL_ID
)
SELECT
    g.MATERIAL_ID, p.MATERIAL_DESC, p.DIVISION, p.BRAND, p.UNIT_WHOLESALE_USD,
    g.PEAK_EVENT, g.PEAK_WEEKS,
    g.TOTAL_FORECAST_QTY                              AS DEMAND_FORECAST_QTY,
    g.TOTAL_COMMITTED_QTY                             AS BY_COMMITTED_QTY,
    g.PEAK_COMMITTED_QTY,
    COALESCE(ms.UNRESTRICTED_STOCK, 0)                AS CURRENT_STOCK_QTY,
    COALESCE(ms.DAYS_OF_SUPPLY, 0)                    AS DAYS_OF_SUPPLY,
    ms.SAFETY_STOCK_DAYS,
    GREATEST(g.TOTAL_FORECAST_QTY - COALESCE(g.PEAK_COMMITTED_QTY, 0), 0) AS SUPPLY_SHORTFALL_QTY,
    ROUND(GREATEST(g.TOTAL_FORECAST_QTY - COALESCE(g.PEAK_COMMITTED_QTY, 0), 0) * p.UNIT_WHOLESALE_USD, 0) AS REVENUE_AT_RISK_USD,
    CASE
        WHEN g.TOTAL_FORECAST_QTY > COALESCE(g.PEAK_COMMITTED_QTY, 0)
         AND ms.DAYS_OF_SUPPLY < ms.SAFETY_STOCK_DAYS  THEN 'CRITICAL'
        WHEN g.TOTAL_FORECAST_QTY > COALESCE(g.PEAK_COMMITTED_QTY, 0) THEN 'HIGH'
        WHEN ms.DAYS_OF_SUPPLY < ms.SAFETY_STOCK_DAYS  THEN 'MEDIUM'
        ELSE 'LOW'
    END AS COVERAGE_STATUS
FROM gap g
JOIN I_PRODUCT p             ON p.MATERIAL_ID = g.MATERIAL_ID
LEFT JOIN material_stock ms  ON ms.MATERIAL_ID = g.MATERIAL_ID;


CREATE OR REPLACE VIEW V_SUPPLY_RISK_SCORE AS
WITH supplier_risk AS (
    SELECT b.MATERIAL_ID,
        MAX(CASE
            WHEN oa.RISK_LEVEL = 'CRITICAL' THEN 95
            WHEN oa.RISK_LEVEL = 'HIGH'     THEN 80
            WHEN s.CREDIT_RATING IN ('B-','C') AND s.IS_SOLE_SOURCE THEN 85
            WHEN s.CREDIT_RATING = 'B'      THEN 60
            WHEN s.IS_SOLE_SOURCE           THEN 50
            ELSE 20
        END) AS supplier_risk_score,
        MAX(CASE WHEN oa.STATUS = 'ACTIVE' THEN oa.RISK_LEVEL END) AS biosecurity_alert,
        LISTAGG(DISTINCT s.SUPPLIER_ID, ', ') WITHIN GROUP (ORDER BY s.SUPPLIER_ID) AS at_risk_suppliers
    FROM I_BILLOFMATERIAL b
    JOIN I_BILLOFMATERIALITEM bi ON bi.BOM_ID = b.BOM_ID
    JOIN I_SUPPLIER s            ON s.SUPPLIER_ID = bi.PREFERRED_SUPPLIER
    LEFT JOIN EXT_OUTBREAK_ALERTS oa ON oa.COUNTRY = s.COUNTRY AND oa.STATUS = 'ACTIVE'
    WHERE bi.IS_CRITICAL = TRUE GROUP BY b.MATERIAL_ID
),
transport_risk AS (
    SELECT po.MATERIAL_ID,
        AVG(CASE WHEN te.RESPONSE_TYPE = 'SILENT_DECLINE' THEN 90 WHEN te.RESPONSE_TYPE = 'REJECTED' THEN 70 WHEN te.RESPONSE_TYPE = 'LATE_ACCEPT' THEN 45 ELSE 15 END) AS transport_risk_score,
        AVG(pc.CONGESTION_SCORE * 10) AS port_congestion_score,
        COUNT(CASE WHEN l.LOAD_STATUS IN ('LATE','MISSED','BLOCKED') THEN 1 END) AS disrupted_loads
    FROM M_V_POH_AGGR po
    LEFT JOIN BY_LOADS l  ON l.RELATED_PO = po.PO_NUMBER
    LEFT JOIN BY_LANES ln ON ln.LANE_ID = l.LANE_ID
    LEFT JOIN BY_TENDER_EVENTS te ON te.LOAD_ID = l.LOAD_ID
    LEFT JOIN EXT_PORT_CONGESTION pc ON pc.PORT_CODE = ln.ORIGIN_PORT AND pc.REPORT_DATE = '2026-08-20'
    WHERE po.GR_DATE IS NULL GROUP BY po.MATERIAL_ID
),
coverage_risk AS (
    SELECT MATERIAL_ID,
        CASE WHEN COVERAGE_STATUS = 'CRITICAL' THEN 95 WHEN COVERAGE_STATUS = 'HIGH' THEN 75 WHEN COVERAGE_STATUS = 'MEDIUM' THEN 45 ELSE 15 END AS coverage_risk_score,
        SUPPLY_SHORTFALL_QTY, REVENUE_AT_RISK_USD, DAYS_OF_SUPPLY, SAFETY_STOCK_DAYS, PEAK_EVENT
    FROM V_SEASONAL_COVERAGE_GAP
),
external_risk AS (
    SELECT b.MATERIAL_ID,
        MAX(CASE WHEN nr.SEVERITY = 'CRITICAL' THEN 90 WHEN nr.SEVERITY = 'HIGH' THEN 70 WHEN nr.SEVERITY = 'MEDIUM' THEN 40 ELSE 15 END) AS ext_risk_score
    FROM EXT_NEWS_RISK_EVENTS nr
    JOIN I_BILLOFMATERIALITEM bi ON bi.PREFERRED_SUPPLIER = nr.RELATED_SUPPLIER
    JOIN I_BILLOFMATERIAL b      ON b.BOM_ID = bi.BOM_ID
    WHERE nr.SEVERITY IN ('HIGH','CRITICAL','MEDIUM') GROUP BY b.MATERIAL_ID
),
commodity_risk AS (
    SELECT CASE COMMODITY WHEN 'COCOA' THEN 'CONFECTIONERY' WHEN 'CHICKEN_MEAL' THEN 'PETCARE' ELSE NULL END AS division,
        MAX(CASE WHEN SUPPLY_TIGHTNESS = 'TIGHT' THEN 65 ELSE 20 END) AS commodity_risk_score,
        AVG(YOY_CHANGE_PCT) AS avg_yoy_change
    FROM EXT_COMMODITY_PRICES WHERE PRICE_DATE >= DATEADD('day', -7, '2026-08-20') GROUP BY 1
)
SELECT
    p.MATERIAL_ID, p.MATERIAL_DESC, p.DIVISION, p.BRAND, pp.PLANT, cr.PEAK_EVENT,
    ROUND(COALESCE(sr.supplier_risk_score,20)*0.30 + COALESCE(tr.transport_risk_score,20)*0.25 +
          COALESCE(cr.coverage_risk_score,15)*0.25 + COALESCE(er.ext_risk_score,10)*0.10 +
          COALESCE(cm.commodity_risk_score,10)*0.10, 1) AS COMPOSITE_RISK_SCORE,
    CASE
        WHEN ROUND(COALESCE(sr.supplier_risk_score,20)*0.30+COALESCE(tr.transport_risk_score,20)*0.25+COALESCE(cr.coverage_risk_score,15)*0.25+COALESCE(er.ext_risk_score,10)*0.10+COALESCE(cm.commodity_risk_score,10)*0.10,1)>=75 THEN 'CRITICAL'
        WHEN ROUND(COALESCE(sr.supplier_risk_score,20)*0.30+COALESCE(tr.transport_risk_score,20)*0.25+COALESCE(cr.coverage_risk_score,15)*0.25+COALESCE(er.ext_risk_score,10)*0.10+COALESCE(cm.commodity_risk_score,10)*0.10,1)>=55 THEN 'HIGH'
        WHEN ROUND(COALESCE(sr.supplier_risk_score,20)*0.30+COALESCE(tr.transport_risk_score,20)*0.25+COALESCE(cr.coverage_risk_score,15)*0.25+COALESCE(er.ext_risk_score,10)*0.10+COALESCE(cm.commodity_risk_score,10)*0.10,1)>=35 THEN 'MODERATE'
        ELSE 'LOW'
    END AS RISK_TIER,
    COALESCE(sr.at_risk_suppliers,'None')  AS AT_RISK_SUPPLIERS,
    COALESCE(sr.biosecurity_alert,'None')  AS BIOSECURITY_ALERT,
    -- material-level shortfall split evenly across the plants that make it, so SUMs don't double count
    ROUND(COALESCE(cr.SUPPLY_SHORTFALL_QTY, 0) / COUNT(*) OVER (PARTITION BY p.MATERIAL_ID), 0) AS SUPPLY_SHORTFALL_QTY,
    ROUND(COALESCE(cr.REVENUE_AT_RISK_USD, 0)  / COUNT(*) OVER (PARTITION BY p.MATERIAL_ID), 0) AS REVENUE_AT_RISK_USD,
    COALESCE(cr.DAYS_OF_SUPPLY, 0)        AS DAYS_OF_SUPPLY,
    COALESCE(cr.SAFETY_STOCK_DAYS, 42)    AS SAFETY_STOCK_DAYS,
    COALESCE(tr.disrupted_loads, 0)        AS DISRUPTED_LOAD_COUNT,
    COALESCE(cm.avg_yoy_change, 0)         AS COMMODITY_YOY_CHANGE_PCT
FROM I_PRODUCT p
JOIN I_PRODUCTPLANT pp         ON pp.MATERIAL_ID = p.MATERIAL_ID
LEFT JOIN supplier_risk sr     ON sr.MATERIAL_ID = p.MATERIAL_ID
LEFT JOIN transport_risk tr    ON tr.MATERIAL_ID = p.MATERIAL_ID
LEFT JOIN coverage_risk cr     ON cr.MATERIAL_ID = p.MATERIAL_ID
LEFT JOIN external_risk er     ON er.MATERIAL_ID = p.MATERIAL_ID
LEFT JOIN commodity_risk cm    ON cm.division = p.DIVISION;
