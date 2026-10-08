-- =============================================================================
-- 06_data_seed.sql — Synthetic Data Seeding
--
-- All data grounded in DHL Group published sustainability figures:
--   - Annual Report 2025 (ESRS E1, GHG disclosures)
--   - Sustainability Statbook 2025 (time series, fleet, energy, workforce)
--   - Sustainability Brochure (GoGreen Plus, SAF, e-vehicles)
--
-- The fictional company is "World Delivery" — a global logistics group with
-- ~580k employees, 120k vehicles (50k+ electric), operations in 220+ markets.
--
-- Scale:  Shipment emissions table uses generators for volume.
--         Master data is hand-seeded for demo narrative clarity.
--
-- Variables: <% db_name %>, <% wh_name %>
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE IDENTIFIER('<% db_name %>');
USE SCHEMA ESG;

-- =============================================================================
-- COMPANYCODE — 8 major operating entities
-- =============================================================================

INSERT OVERWRITE INTO COMPANYCODE VALUES
('WD01','World Delivery Germany GmbH',       'Bonn',       'DE','EUR','WDCA','K4','EXPRESS'),
('WD02','World Delivery North America Inc',  'Plantation', 'US','USD','WDCA','K4','EXPRESS'),
('WD03','World Delivery UK Ltd',             'London',     'GB','GBP','WDCA','K4','ECOMMERCE'),
('WD04','World Delivery Netherlands BV',     'Maastricht', 'NL','EUR','WDCA','K4','POST_PARCEL'),
('WD05','World Delivery Singapore Pte Ltd',  'Singapore',  'SG','SGD','WDCA','K4','SUPPLY_CHAIN'),
('WD06','World Delivery UAE LLC',            'Dubai',      'AE','AED','WDCA','K4','EXPRESS'),
('WD07','World Delivery Japan KK',           'Tokyo',      'JP','JPY','WDCA','K4','SUPPLY_CHAIN'),
('WD08','World Delivery Brazil Ltda',        'São Paulo',  'BR','BRL','WDCA','K4','ECOMMERCE');


-- =============================================================================
-- COSTCENTER — 80 ESG-relevant cost centers
-- =============================================================================

INSERT OVERWRITE INTO COSTCENTER
    (COSTCENTERID, EXTERNALCODE, NAME, DESCRIPTION, COMPANYCODE, DIVISION, COSTCENTERTYPE, VALIDFROM, VALIDTO)
SELECT * FROM (
    -- Express fleet operations (20 cost centers)
    SELECT 'CC-EXP-FLT-' || LPAD(ROW_NUMBER() OVER(ORDER BY seq4()),3,'0'), 'EXP-FLT-' || seq4(), 
           'Express Fleet Ops ' || CASE MOD(seq4(),5) WHEN 0 THEN 'Germany' WHEN 1 THEN 'USA' WHEN 2 THEN 'UK' WHEN 3 THEN 'Netherlands' ELSE 'Singapore' END,
           'Last-mile and line-haul fleet operations', 
           CASE MOD(seq4(),5) WHEN 0 THEN 'WD01' WHEN 1 THEN 'WD02' WHEN 2 THEN 'WD03' WHEN 3 THEN 'WD04' ELSE 'WD05' END,
           'EXPRESS', 'FLEET', '2020-01-01'::DATE, '9999-12-31'::DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 20))
    UNION ALL
    -- Express hubs (10)
    SELECT 'CC-EXP-HUB-' || LPAD(ROW_NUMBER() OVER(ORDER BY seq4()),3,'0'), 'EXP-HUB-' || seq4(),
           'Express Hub ' || CASE MOD(seq4(),5) WHEN 0 THEN 'Leipzig' WHEN 1 THEN 'Cincinnati' WHEN 2 THEN 'East Midlands' WHEN 3 THEN 'Hong Kong' ELSE 'Dubai' END,
           'Express hub facility operations and energy', 
           CASE MOD(seq4(),5) WHEN 0 THEN 'WD01' WHEN 1 THEN 'WD02' WHEN 2 THEN 'WD03' WHEN 3 THEN 'WD05' ELSE 'WD06' END,
           'EXPRESS', 'HUB', '2020-01-01'::DATE, '9999-12-31'::DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 10))
    UNION ALL
    -- Supply Chain warehouses (10)
    SELECT 'CC-SC-WH-' || LPAD(ROW_NUMBER() OVER(ORDER BY seq4()),3,'0'), 'SC-WH-' || seq4(),
           'SC Warehouse ' || CASE MOD(seq4(),4) WHEN 0 THEN 'Netherlands' WHEN 1 THEN 'Singapore' WHEN 2 THEN 'Japan' ELSE 'Brazil' END,
           'Supply chain warehouse and distribution operations',
           CASE MOD(seq4(),4) WHEN 0 THEN 'WD04' WHEN 1 THEN 'WD05' WHEN 2 THEN 'WD07' ELSE 'WD08' END,
           'SUPPLY_CHAIN', 'FACILITY', '2020-01-01'::DATE, '9999-12-31'::DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 10))
    UNION ALL
    -- eCommerce sort centers (10)
    SELECT 'CC-EC-SRT-' || LPAD(ROW_NUMBER() OVER(ORDER BY seq4()),3,'0'), 'EC-SRT-' || seq4(),
           'eCommerce Sort Center ' || CASE MOD(seq4(),3) WHEN 0 THEN 'UK' WHEN 1 THEN 'Germany' ELSE 'Brazil' END,
           'eCommerce parcel sorting facility',
           CASE MOD(seq4(),3) WHEN 0 THEN 'WD03' WHEN 1 THEN 'WD01' ELSE 'WD08' END,
           'ECOMMERCE', 'SORT_CENTER', '2020-01-01'::DATE, '9999-12-31'::DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 10))
    UNION ALL
    -- Post and Parcel (10)
    SELECT 'CC-PP-OPS-' || LPAD(ROW_NUMBER() OVER(ORDER BY seq4()),3,'0'), 'PP-OPS-' || seq4(),
           'Post and Parcel Operations ' || CASE MOD(seq4(),2) WHEN 0 THEN 'Germany' ELSE 'Netherlands' END,
           'Post and Parcel delivery operations',
           CASE MOD(seq4(),2) WHEN 0 THEN 'WD01' ELSE 'WD04' END,
           'POST_PARCEL', 'FLEET', '2020-01-01'::DATE, '9999-12-31'::DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 10))
    UNION ALL
    -- Group offices (10)
    SELECT 'CC-GRP-OFF-' || LPAD(ROW_NUMBER() OVER(ORDER BY seq4()),3,'0'), 'GRP-OFF-' || seq4(),
           'Group Office ' || CASE MOD(seq4(),4) WHEN 0 THEN 'Bonn HQ' WHEN 1 THEN 'Dubai' WHEN 2 THEN 'Singapore' ELSE 'London' END,
           'Corporate office and group functions',
           CASE MOD(seq4(),4) WHEN 0 THEN 'WD01' WHEN 1 THEN 'WD06' WHEN 2 THEN 'WD05' ELSE 'WD03' END,
           'GROUP', 'OFFICE', '2020-01-01'::DATE, '9999-12-31'::DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 10))
    UNION ALL
    -- Sustainability program cost centers (10)
    SELECT 'CC-SUS-' || LPAD(ROW_NUMBER() OVER(ORDER BY seq4()),3,'0'), 'SUS-' || seq4(),
           CASE MOD(seq4(),5) WHEN 0 THEN 'SAF Program' WHEN 1 THEN 'Fleet Electrification' WHEN 2 THEN 'Renewable Energy' WHEN 3 THEN 'Carbon Offsetting' ELSE 'GoGreen Plus Commercial' END,
           'Sustainability and decarbonization program management',
           'WD01', 'GROUP', 'SUSTAINABILITY', '2020-01-01'::DATE, '9999-12-31'::DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 10))
);


-- =============================================================================
-- PLANT — 40 physical locations
-- =============================================================================

INSERT OVERWRITE INTO PLANT VALUES
-- Express Hubs
('EH01','Leipzig Hub',          'HUB',              'DE','EUROPE',   'Leipzig',    'WD01','EXPRESS',      'DE','85000'),
('EH02','Cincinnati Hub',       'HUB',              'US','AMERICAS', 'Cincinnati', 'WD02','EXPRESS',      'US','120000'),
('EH03','East Midlands Hub',    'HUB',              'GB','EUROPE',   'Nottingham', 'WD03','EXPRESS',      'GB','60000'),
('EH04','Hong Kong Hub',        'HUB',              'HK','APAC',     'Hong Kong',  'WD05','EXPRESS',      'HK','35000'),
('EH05','Dubai Hub',            'HUB',              'AE','MEA',      'Dubai',      'WD06','EXPRESS',      'AE','45000'),
('EH06','Singapore Hub',        'HUB',              'SG','APAC',     'Singapore',  'WD05','EXPRESS',      'SG','28000'),
-- Express Sort Centers
('ES01','Cologne Sort Center',  'SORT_CENTER',      'DE','EUROPE',   'Cologne',    'WD01','EXPRESS',      'DE','22000'),
('ES02','Brussels Sort Center', 'SORT_CENTER',      'BE','EUROPE',   'Brussels',   'WD04','EXPRESS',      'BE','18000'),
('ES03','LA Sort Center',       'SORT_CENTER',      'US','AMERICAS', 'Los Angeles','WD02','EXPRESS',      'US','25000'),
-- Freight Terminals
('FT01','Rotterdam Terminal',   'FREIGHT_TERMINAL', 'NL','EUROPE',   'Rotterdam',  'WD04','SUPPLY_CHAIN', 'NL','32000'),
('FT02','Hamburg Terminal',     'FREIGHT_TERMINAL', 'DE','EUROPE',   'Hamburg',    'WD01','SUPPLY_CHAIN', 'DE','28000'),
('FT03','Singapore Terminal',   'FREIGHT_TERMINAL', 'SG','APAC',     'Singapore',  'WD05','SUPPLY_CHAIN', 'SG','20000'),
('FT04','Tokyo Terminal',       'FREIGHT_TERMINAL', 'JP','APAC',     'Tokyo',      'WD07','SUPPLY_CHAIN', 'JP','15000'),
('FT05','Santos Terminal',      'FREIGHT_TERMINAL', 'BR','AMERICAS', 'Santos',     'WD08','SUPPLY_CHAIN', 'BR','18000'),
-- SC Warehouses
('WH01','Venlo Warehouse',      'WAREHOUSE',        'NL','EUROPE',   'Venlo',      'WD04','SUPPLY_CHAIN', 'NL','45000'),
('WH02','Chennai Warehouse',    'WAREHOUSE',        'IN','APAC',     'Chennai',    'WD05','SUPPLY_CHAIN', 'IN','30000'),
('WH03','Memphis Warehouse',    'WAREHOUSE',        'US','AMERICAS', 'Memphis',    'WD02','SUPPLY_CHAIN', 'US','50000'),
-- eCommerce Sort
('EC01','UK eCommerce Hub',     'SORT_CENTER',      'GB','EUROPE',   'Coventry',   'WD03','ECOMMERCE',    'GB','20000'),
('EC02','DE eCommerce Hub',     'SORT_CENTER',      'DE','EUROPE',   'Dortmund',   'WD01','ECOMMERCE',    'DE','25000'),
('EC03','BR eCommerce Hub',     'SORT_CENTER',      'BR','AMERICAS', 'Campinas',   'WD08','ECOMMERCE',    'BR','15000'),
-- Post and Parcel
('PP01','Bonn Post Center',     'SORT_CENTER',      'DE','EUROPE',   'Bonn',       'WD01','POST_PARCEL',  'DE','30000'),
('PP02','Frankfurt Post Center','SORT_CENTER',      'DE','EUROPE',   'Frankfurt',  'WD01','POST_PARCEL',  'DE','28000'),
('PP03','Munich Delivery Base', 'SORT_CENTER',      'DE','EUROPE',   'Munich',     'WD01','POST_PARCEL',  'DE','18000'),
('PP04','Amsterdam Post Hub',   'SORT_CENTER',      'NL','EUROPE',   'Amsterdam',  'WD04','POST_PARCEL',  'NL','22000'),
-- Offices
('OF01','Bonn HQ',              'OFFICE',           'DE','EUROPE',   'Bonn',       'WD01','GROUP',        'DE','35000'),
('OF02','Dubai Regional Office','OFFICE',           'AE','MEA',      'Dubai',      'WD06','GROUP',        'AE','8000'),
('OF03','Singapore Regional',   'OFFICE',           'SG','APAC',     'Singapore',  'WD05','GROUP',        'SG','6000'),
('OF04','London Office',        'OFFICE',           'GB','EUROPE',   'London',     'WD03','GROUP',        'GB','4500'),
-- Fleet Depots (co-located with plants but logically separate)
('FD01','Leipzig Fleet Depot',  'WAREHOUSE',        'DE','EUROPE',   'Leipzig',    'WD01','EXPRESS',      'DE','15000'),
('FD02','Bonn EV Fleet Depot',  'WAREHOUSE',        'DE','EUROPE',   'Bonn',       'WD01','POST_PARCEL',  'DE','12000');


-- =============================================================================
-- GENERALLEDGERACCOUNTLINEITEM — ESG-relevant GL entries
-- ~2000 rows covering fuel, energy, SAF, fleet capex, offsets
-- GL account scheme:
--   610xxx = Fossil fuel costs (diesel, jet fuel, bunker)
--   620xxx = Energy / electricity costs
--   630xxx = Sustainable Aviation Fuel (SAF)
--   640xxx = Fleet capex (e-vehicle acquisition, charging infra)
--   650xxx = Carbon offsets and renewable energy certificates
--   660xxx = Other decarb expenditure
-- =============================================================================

INSERT OVERWRITE INTO GENERALLEDGERACCOUNTLINEITEM
    (SOURCELEDGER, COMPANYCODE, FISCALYEAR, ACCOUNTINGDOCUMENT, LEDGERGLLINEITEM,
     GLACCOUNT, GLACCOUNTDESCRIPTION, COSTCENTER, PROFITCENTER,
     AMOUNTINCOMPANYCODECURRENCY, CURRENCY, POSTINGDATE, DOCUMENTDATE,
     POSTINGPERIOD, DOCUMENTTYPE, PLANT, ESGCATEGORY)
WITH months AS (
    SELECT DATEADD('month', seq4(), '2023-01-01') AS posting_date,
           LPAD(seq4()+1, 3, '0') AS posting_period,
           YEAR(DATEADD('month', seq4(), '2023-01-01'))::VARCHAR AS fiscal_year
    FROM TABLE(GENERATOR(ROWCOUNT => 36))
),
esg_accounts AS (
    SELECT * FROM (VALUES
        ('6100001','Jet fuel - aviation',      'FUEL',           8500000),
        ('6100002','Diesel - road fleet',      'FUEL',           3200000),
        ('6100003','Bunker fuel - ocean',       'FUEL',           1400000),
        ('6100004','CNG/LNG - alt road fuel',  'FUEL',            250000),
        ('6200001','Grid electricity',          'ENERGY',         1800000),
        ('6200002','Natural gas - heating',     'ENERGY',          420000),
        ('6200003','Diesel generator fuel',     'ENERGY',          180000),
        ('6300001','Sustainable Aviation Fuel', 'SAF',            1700000),
        ('6300002','HVO biodiesel',             'SAF',             350000),
        ('6400001','BEV acquisition capex',     'FLEET_CAPEX',    1250000),
        ('6400002','Charging infrastructure',   'FLEET_CAPEX',     380000),
        ('6400003','H2 fuel cell vehicles',     'FLEET_CAPEX',      85000),
        ('6500001','Carbon offset purchases',   'CARBON_OFFSET',   280000),
        ('6500002','Renewable energy certs',    'RENEWABLE_CERT',  190000),
        ('6600001','Decarb R+D and consulting', 'DECARB_OTHER',    150000)
    ) AS t(glaccount, description, esgcategory, monthly_base))
SELECT
    '0L',
    CASE MOD(ROW_NUMBER() OVER (ORDER BY m.posting_date, a.glaccount), 8)
        WHEN 0 THEN 'WD01' WHEN 1 THEN 'WD02' WHEN 2 THEN 'WD03' WHEN 3 THEN 'WD04'
        WHEN 4 THEN 'WD05' WHEN 5 THEN 'WD06' WHEN 6 THEN 'WD07' ELSE 'WD08' END,
    m.fiscal_year,
    'ESG' || LPAD(ROW_NUMBER() OVER (ORDER BY m.posting_date, a.glaccount), 7, '0'),
    '001',
    a.glaccount,
    a.description,
    NULL,  -- costcenter filled optionally
    NULL,  -- profitcenter
    ROUND(a.monthly_base * (1 + UNIFORM(-0.15, 0.15, RANDOM())) * 
          CASE WHEN m.fiscal_year = '2025' THEN 1.05 WHEN m.fiscal_year = '2024' THEN 1.02 ELSE 1.0 END, 2),
    'EUR',
    m.posting_date,
    m.posting_date,
    m.posting_period,
    'KR',
    NULL,  -- plant
    a.esgcategory
FROM months m
CROSS JOIN esg_accounts a;


-- =============================================================================
-- Z_SHIPMENT_EMISSIONS — 5000 per-shipment emission records
-- Distribution mirrors DHL: Air 65%, Road 23%, Ocean 11%, Rail 1%
-- =============================================================================

INSERT OVERWRITE INTO Z_SHIPMENT_EMISSIONS
    (SHIPMENTID, TRANSPORTMODE, DIVISION, COMPANYCODE, ORIGIN, DESTINATION,
     SHIPMENTDATE, DISTANCEKM, WEIGHTKG, CO2EKG, EMISSIONSCOPE, CALCULATIONMETHOD,
     PRIMARYDATAPCT, FUELTYPEUSED, FUELQUANTITYLITERS, ISGOGREENPLUSORDER, CARRIERTYPE)
WITH base_data AS (
    SELECT
        'SHP-' || LPAD(ROW_NUMBER() OVER (ORDER BY seq4()), 7, '0') AS SHIPMENTID,
        CASE
            WHEN seq4() < 3250 THEN 'AIR'        -- 65%
            WHEN seq4() < 4400 THEN 'ROAD'       -- 23%
            WHEN seq4() < 4950 THEN 'OCEAN'      -- 11%
            ELSE 'RAIL'                           -- 1%
        END AS TRANSPORTMODE,
        CASE MOD(seq4(), 5)
            WHEN 0 THEN 'EXPRESS' WHEN 1 THEN 'EXPRESS' WHEN 2 THEN 'SUPPLY_CHAIN'
            WHEN 3 THEN 'ECOMMERCE' ELSE 'POST_PARCEL'
        END AS DIVISION,
        CASE MOD(seq4(), 8)
            WHEN 0 THEN 'WD01' WHEN 1 THEN 'WD02' WHEN 2 THEN 'WD03' WHEN 3 THEN 'WD04'
            WHEN 4 THEN 'WD05' WHEN 5 THEN 'WD06' WHEN 6 THEN 'WD07' ELSE 'WD08'
        END AS COMPANYCODE,
        seq4() AS RN
    FROM TABLE(GENERATOR(ROWCOUNT => 5000))
)
SELECT
    SHIPMENTID,
    TRANSPORTMODE,
    DIVISION,
    COMPANYCODE,
    CASE TRANSPORTMODE
        WHEN 'AIR'   THEN CASE MOD(RN, 6) WHEN 0 THEN 'Leipzig' WHEN 1 THEN 'Cincinnati' WHEN 2 THEN 'Hong Kong' WHEN 3 THEN 'Dubai' WHEN 4 THEN 'Singapore' ELSE 'East Midlands' END
        WHEN 'ROAD'  THEN CASE MOD(RN, 4) WHEN 0 THEN 'Bonn' WHEN 1 THEN 'Munich' WHEN 2 THEN 'London' ELSE 'Amsterdam' END
        WHEN 'OCEAN' THEN CASE MOD(RN, 3) WHEN 0 THEN 'Rotterdam' WHEN 1 THEN 'Singapore' ELSE 'Santos' END
        ELSE CASE MOD(RN, 2) WHEN 0 THEN 'Hamburg' ELSE 'Rotterdam' END
    END,
    CASE TRANSPORTMODE
        WHEN 'AIR'   THEN CASE MOD(RN+3, 6) WHEN 0 THEN 'Tokyo' WHEN 1 THEN 'London' WHEN 2 THEN 'New York' WHEN 3 THEN 'Sao Paulo' WHEN 4 THEN 'Mumbai' ELSE 'Sydney' END
        WHEN 'ROAD'  THEN CASE MOD(RN+2, 4) WHEN 0 THEN 'Frankfurt' WHEN 1 THEN 'Brussels' WHEN 2 THEN 'Birmingham' ELSE 'Cologne' END
        WHEN 'OCEAN' THEN CASE MOD(RN+1, 3) WHEN 0 THEN 'Shanghai' WHEN 1 THEN 'Chennai' ELSE 'Hamburg' END
        ELSE CASE MOD(RN+1, 2) WHEN 0 THEN 'Munich' ELSE 'Berlin' END
    END,
    DATEADD('day', -UNIFORM(0, 730, RANDOM()), '2025-12-31')::DATE,
    CASE TRANSPORTMODE
        WHEN 'AIR'   THEN ROUND(UNIFORM(500, 12000, RANDOM()), 1)
        WHEN 'ROAD'  THEN ROUND(UNIFORM(50, 800, RANDOM()), 1)
        WHEN 'OCEAN' THEN ROUND(UNIFORM(2000, 20000, RANDOM()), 1)
        ELSE ROUND(UNIFORM(200, 2000, RANDOM()), 1)
    END,
    ROUND(UNIFORM(5, 25000, RANDOM()), 2),
    ROUND(
        CASE TRANSPORTMODE
            WHEN 'AIR'   THEN UNIFORM(500, 12000, RANDOM()) * UNIFORM(5, 25000, RANDOM()) / 1000.0 * 0.6
            WHEN 'ROAD'  THEN UNIFORM(50, 800, RANDOM()) * UNIFORM(5, 25000, RANDOM()) / 1000.0 * 0.1
            WHEN 'OCEAN' THEN UNIFORM(2000, 20000, RANDOM()) * UNIFORM(5, 25000, RANDOM()) / 1000.0 * 0.01
            ELSE UNIFORM(200, 2000, RANDOM()) * UNIFORM(5, 25000, RANDOM()) / 1000.0 * 0.03
        END + UNIFORM(-50, 200, RANDOM()), 4),
    CASE WHEN MOD(RN, 3) = 0 THEN '1' ELSE '3' END,
    CASE MOD(RN, 4) WHEN 0 THEN 'GLEC_DEFAULT' WHEN 1 THEN 'GLEC_MODELED' WHEN 2 THEN 'DEFRA' ELSE 'EPA' END,
    CASE WHEN MOD(RN, 3) = 0 THEN 95.0 ELSE ROUND(UNIFORM(10, 50, RANDOM()), 1) END,
    CASE TRANSPORTMODE
        WHEN 'AIR'   THEN CASE WHEN UNIFORM(0, 100, RANDOM()) < 12 THEN 'SAF' ELSE 'JET_A1' END
        WHEN 'ROAD'  THEN CASE MOD(RN, 10) WHEN 0 THEN 'BEV_ELEC' WHEN 1 THEN 'HVO' WHEN 2 THEN 'CNG' ELSE 'DIESEL' END
        WHEN 'OCEAN' THEN 'BUNKER_FUEL'
        ELSE 'ELECTRIC_RAIL'
    END,
    ROUND(UNIFORM(10, 5000, RANDOM()), 2),
    UNIFORM(0, 100, RANDOM()) < 8,
    CASE WHEN MOD(RN, 3) = 0 THEN 'OWN_FLEET' ELSE 'SUBCONTRACTED' END
;


-- =============================================================================
-- Z_FACILITY_ENERGY — 500 monthly facility energy records
-- =============================================================================

INSERT OVERWRITE INTO Z_FACILITY_ENERGY
    (FACILITYENERGYID, PLANT, REPORTINGMONTH, ENERGYSOURCETYPE, CONSUMPTIONKWH,
     CONSUMPTIONMWH, CO2EKG, EMISSIONSCOPE, RENEWABLEPCT, GRIDEMIISSIONFACTOR)
WITH plants AS (
    SELECT PLANT, PLANTCATEGORY FROM PLANT WHERE PLANTCATEGORY IN ('HUB','SORT_CENTER','WAREHOUSE','FREIGHT_TERMINAL','OFFICE')
),
months AS (
    SELECT DATEADD('month', seq4(), '2023-01-01') AS reporting_month FROM TABLE(GENERATOR(ROWCOUNT => 36))
),
sources AS (
    SELECT * FROM (VALUES
        ('GRID_CONVENTIONAL', 0.60, 2, 0.0),
        ('GRID_RENEWABLE',    0.25, 2, 100.0),
        ('SOLAR_ONSITE',      0.08, 1, 100.0),
        ('DIESEL_GENERATOR',  0.04, 1, 0.0),
        ('NATURAL_GAS',       0.03, 1, 0.0)
    ) AS t(src, share, scope, renewable_pct))
SELECT
    'FE-' || LPAD(ROW_NUMBER() OVER (ORDER BY p.plant, m.reporting_month, s.src), 7, '0'),
    p.plant,
    m.reporting_month,
    s.src,
    ROUND(CASE p.plantcategory
        WHEN 'HUB' THEN 850000 WHEN 'SORT_CENTER' THEN 350000 WHEN 'WAREHOUSE' THEN 280000
        WHEN 'FREIGHT_TERMINAL' THEN 420000 ELSE 120000 END
        * s.share * (1 + UNIFORM(-0.15, 0.15, RANDOM())), 1),
    ROUND(CASE p.plantcategory
        WHEN 'HUB' THEN 850 WHEN 'SORT_CENTER' THEN 350 WHEN 'WAREHOUSE' THEN 280
        WHEN 'FREIGHT_TERMINAL' THEN 420 ELSE 120 END
        * s.share * (1 + UNIFORM(-0.15, 0.15, RANDOM())), 3),
    ROUND(CASE p.plantcategory
        WHEN 'HUB' THEN 850000 WHEN 'SORT_CENTER' THEN 350000 WHEN 'WAREHOUSE' THEN 280000
        WHEN 'FREIGHT_TERMINAL' THEN 420000 ELSE 120000 END
        * s.share * (1 + UNIFORM(-0.15, 0.15, RANDOM()))
        * CASE s.src WHEN 'GRID_CONVENTIONAL' THEN 0.400 WHEN 'DIESEL_GENERATOR' THEN 0.700 WHEN 'NATURAL_GAS' THEN 0.200 ELSE 0.0 END, 4),
    s.scope::VARCHAR,
    s.renewable_pct,
    CASE s.src WHEN 'GRID_CONVENTIONAL' THEN 0.400 WHEN 'GRID_RENEWABLE' THEN 0.0 WHEN 'SOLAR_ONSITE' THEN 0.0 WHEN 'DIESEL_GENERATOR' THEN 0.700 ELSE 0.200 END
FROM plants p
CROSS JOIN months m
CROSS JOIN sources s
WHERE UNIFORM(0, 100, RANDOM()) < 35  -- sample ~35% to get ~500 rows
;


-- =============================================================================
-- Z_FLEET_VEHICLE — 1000 vehicles (500 e-vehicles + 500 conventional)
-- =============================================================================

INSERT OVERWRITE INTO Z_FLEET_VEHICLE
    (VEHICLEID, DRIVETYPE, VEHICLECATEGORY, DIVISION, PLANT, COMPANYCODE,
     MANUFACTURER, MODEL, MANUFACTUREYEAR, CO2GPERKM, PAYLOADKG, RANGEKMFULL,
     ISACTIVE, ACQUISITIONDATE)
SELECT
    'VEH-' || LPAD(ROW_NUMBER() OVER (ORDER BY seq4()), 6, '0'),
    CASE
        WHEN seq4() < 350 THEN 'BEV'       -- 35% battery electric
        WHEN seq4() < 500 THEN 'PHEV'      -- 15% plug-in hybrid
        WHEN seq4() < 580 THEN 'HVO'       -- 8% HVO biodiesel
        WHEN seq4() < 620 THEN 'CNG'       -- 4% compressed natural gas
        WHEN seq4() < 625 THEN 'H2'        -- 0.5% hydrogen fuel cell
        ELSE 'DIESEL'                       -- 37.5% diesel (legacy)
    END,
    CASE MOD(seq4(), 3) WHEN 0 THEN 'LAST_MILE' WHEN 1 THEN 'LINE_HAUL' ELSE 'SPECIAL' END,
    CASE MOD(seq4(), 5) WHEN 0 THEN 'EXPRESS' WHEN 1 THEN 'POST_PARCEL' WHEN 2 THEN 'ECOMMERCE' WHEN 3 THEN 'SUPPLY_CHAIN' ELSE 'EXPRESS' END,
    CASE MOD(seq4(), 6) WHEN 0 THEN 'FD01' WHEN 1 THEN 'FD02' WHEN 2 THEN 'ES01' WHEN 3 THEN 'PP01' WHEN 4 THEN 'EC01' ELSE 'EH01' END,
    CASE MOD(seq4(), 5) WHEN 0 THEN 'WD01' WHEN 1 THEN 'WD01' WHEN 2 THEN 'WD03' WHEN 3 THEN 'WD04' ELSE 'WD02' END,
    CASE WHEN seq4() < 500 THEN
        CASE MOD(seq4(), 4) WHEN 0 THEN 'StreetScooter' WHEN 1 THEN 'Mercedes eVito' WHEN 2 THEN 'Ford E-Transit' ELSE 'Volta Zero' END
    ELSE
        CASE MOD(seq4(), 3) WHEN 0 THEN 'Mercedes Sprinter' WHEN 1 THEN 'VW Crafter' ELSE 'MAN TGE' END
    END,
    CASE WHEN seq4() < 500 THEN 'Electric Van' ELSE 'Diesel Van' END,
    UNIFORM(2019, 2026, RANDOM()),
    CASE WHEN seq4() < 500 THEN 0.0 ELSE ROUND(UNIFORM(120, 280, RANDOM()), 1) END,
    CASE MOD(seq4(), 3) WHEN 0 THEN 800 WHEN 1 THEN 3500 ELSE 1200 END,
    CASE WHEN seq4() < 500 THEN UNIFORM(150, 350, RANDOM()) ELSE UNIFORM(600, 1200, RANDOM()) END,
    TRUE,
    DATEADD('day', -UNIFORM(0, 2000, RANDOM()), '2025-12-31')::DATE
FROM TABLE(GENERATOR(ROWCOUNT => 1000));


-- =============================================================================
-- Z_FLEET_FUEL_LOG — 3000 daily fuel/charging records
-- =============================================================================

INSERT OVERWRITE INTO Z_FLEET_FUEL_LOG
    (LOGID, VEHICLEID, LOGDATE, FUELTYPE, QUANTITYLITERS, DISTANCEKM,
     CO2EKG, COSTLOCALCURRENCY, CURRENCY)
SELECT
    'FL-' || LPAD(ROW_NUMBER() OVER (ORDER BY seq4()), 7, '0'),
    'VEH-' || LPAD(MOD(seq4(), 1000) + 1, 6, '0'),
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), '2025-12-31')::DATE,
    CASE WHEN MOD(seq4(), 1000) < 500 THEN 'BEV_ELEC' ELSE 'DIESEL' END,
    CASE WHEN MOD(seq4(), 1000) < 500
        THEN ROUND(UNIFORM(20, 80, RANDOM()), 2)      -- KWH for EV
        ELSE ROUND(UNIFORM(30, 120, RANDOM()), 2)     -- liters for diesel
    END,
    ROUND(UNIFORM(50, 350, RANDOM()), 1),
    CASE WHEN MOD(seq4(), 1000) < 500
        THEN ROUND(UNIFORM(20, 80, RANDOM()) * 0.0, 4)    -- zero direct CO2e for BEV
        ELSE ROUND(UNIFORM(30, 120, RANDOM()) * 2.68, 4)  -- 2.68 kg CO2e/liter diesel
    END,
    ROUND(UNIFORM(15, 200, RANDOM()), 2),
    'EUR'
FROM TABLE(GENERATOR(ROWCOUNT => 3000));


-- =============================================================================
-- Z_GOGREEN_PLUS_ORDER — 300 green logistics customer orders
-- Customer names inspired by DHL GoGreen Plus case studies
-- =============================================================================

INSERT OVERWRITE INTO Z_GOGREEN_PLUS_ORDER
    (ORDERID, CUSTOMERNAME, CUSTOMERSEGMENT, DIVISION, SHIPMENTID, ORDERDATE,
     SAFBLENDINGPCT, SAFQUANTITYKG, CO2EAVOIDEDKG, PREMIUMUSD,
     BASESHIPMENTCOSTUSD, CERTIFICATEID, DECARBTECHNOLOGY)
SELECT
    'GGP-' || LPAD(ROW_NUMBER() OVER (ORDER BY seq4()), 5, '0'),
    CASE MOD(seq4(), 12)
        WHEN 0  THEN 'Mytheresa' WHEN 1  THEN 'dm-drogerie markt' WHEN 2 THEN 'Formula 1 Logistics'
        WHEN 3  THEN 'BASF SE' WHEN 4  THEN 'Siemens AG' WHEN 5 THEN 'BMW Group'
        WHEN 6  THEN 'Unilever NV' WHEN 7 THEN 'Nestlé SA' WHEN 8 THEN 'IKEA'
        WHEN 9  THEN 'Zalando SE' WHEN 10 THEN 'Maersk Supply' ELSE 'Procter and Gamble'
    END,
    CASE MOD(seq4(), 3) WHEN 0 THEN 'ENTERPRISE' WHEN 1 THEN 'MID_MARKET' ELSE 'SMB' END,
    CASE MOD(seq4(), 4) WHEN 0 THEN 'EXPRESS' WHEN 1 THEN 'SUPPLY_CHAIN' WHEN 2 THEN 'ECOMMERCE' ELSE 'EXPRESS' END,
    'SHP-' || LPAD(UNIFORM(1, 5000, RANDOM()), 7, '0'),
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), '2025-12-31')::DATE,
    ROUND(UNIFORM(5, 30, RANDOM()), 1),   -- SAF blending %
    ROUND(UNIFORM(100, 5000, RANDOM()), 2), -- SAF quantity kg
    ROUND(UNIFORM(500, 50000, RANDOM()), 4), -- CO2e avoided kg
    ROUND(UNIFORM(200, 15000, RANDOM()), 2), -- premium USD
    ROUND(UNIFORM(1000, 80000, RANDOM()), 2), -- base cost USD
    'CERT-WD-' || LPAD(ROW_NUMBER() OVER (ORDER BY seq4()), 5, '0'),
    CASE MOD(seq4(), 4) WHEN 0 THEN 'SAF' WHEN 1 THEN 'BEV' WHEN 2 THEN 'INSETTING' ELSE 'OFFSETTING' END
FROM TABLE(GENERATOR(ROWCOUNT => 300));


-- =============================================================================
-- SF_CORE_WORKFORCE — quarterly snapshots (5 divisions x 4 regions x 10 quarters)
-- Scaled from DHL Statbook: 583,998 total headcount, 82% engagement, 28.1% WIM
-- =============================================================================

INSERT OVERWRITE INTO SF_CORE_WORKFORCE
    (SNAPSHOTID, DIVISION, REGION, QUARTER, REPORTINGDATE, HEADCOUNT,
     WOMENINMANAGEMENTPCT, ENGAGEMENTSCORE, TRAININGHRSPEREMPLOYEE,
     COMPLIANCETRAININGPCT, VOLUNTARYTURNOVERRRATE, PRIMARYKEY_DIVISION)
WITH divisions AS (
    SELECT * FROM (VALUES
        ('EXPRESS',       240000, 82, 27.5, 12.0, 96.5, 5.2),
        ('SUPPLY_CHAIN',  145000, 80, 29.0, 10.5, 95.0, 6.1),
        ('ECOMMERCE',      95000, 83, 30.2, 11.0, 97.0, 7.5),
        ('POST_PARCEL',    85000, 81, 25.8,  9.5, 94.5, 4.8),
        ('GROUP',          18000, 85, 35.0, 15.0, 98.5, 3.2)
    ) AS t(division, headcount, engagement, wim_pct, training_hrs, compliance_pct, turnover))
),
regions AS (
    SELECT * FROM (VALUES ('EUROPE',0.55), ('AMERICAS',0.22), ('APAC',0.18), ('MEA',0.05)) AS t(region, share))
),
quarters AS (
    SELECT 'Q' || (MOD(seq4(), 4) + 1) AS q_label,
           2024 + FLOOR(seq4() / 4) AS yr,
           seq4() AS q_idx
    FROM TABLE(GENERATOR(ROWCOUNT => 8))
)
SELECT
    'WF-' || LPAD(ROW_NUMBER() OVER (ORDER BY q.yr, q.q_label, d.division, r.region), 5, '0'),
    d.division,
    r.region,
    q.yr || '-' || q.q_label,
    LAST_DAY(TO_DATE(q.yr || '-' || (CASE q.q_label WHEN 'Q1' THEN '03' WHEN 'Q2' THEN '06' WHEN 'Q3' THEN '09' ELSE '12' END) || '-01', 'YYYY-MM-DD')),
    ROUND(d.headcount * r.share * (1 + (q.q_idx - 4) * 0.005 + UNIFORM(-0.02, 0.02, RANDOM()))),
    ROUND(d.wim_pct + (q.q_idx - 4) * 0.15 + UNIFORM(-0.3, 0.3, RANDOM()), 2),
    ROUND(d.engagement + (q.q_idx - 4) * 0.3 + UNIFORM(-1, 1, RANDOM()), 1),
    ROUND(d.training_hrs + UNIFORM(-1, 1, RANDOM()), 1),
    ROUND(d.compliance_pct + UNIFORM(-0.5, 0.5, RANDOM()), 1),
    ROUND(d.turnover + UNIFORM(-0.5, 0.5, RANDOM()), 2),
    d.division
FROM divisions d
CROSS JOIN regions r
CROSS JOIN quarters q;


-- =============================================================================
-- SF_HEALTH_SAFETY — quarterly LTIFR by division
-- DHL Statbook: overall LTIFR improved from 20 (2016) to 3.3 (2024)
-- =============================================================================

INSERT OVERWRITE INTO SF_HEALTH_SAFETY
    (RECORDID, DIVISION, QUARTER, REPORTINGDATE, LTIFR, FATALACCIDENTS,
     REPORTABLEINJURIES, WORKHOURSM, SAFETYTRANININGPCT)
WITH divisions AS (
    SELECT * FROM (VALUES
        ('EXPRESS',       3.8, 0, 120, 45.0, 97.0),
        ('SUPPLY_CHAIN',  4.2, 0,  85, 28.0, 96.0),
        ('ECOMMERCE',     2.9, 0,  65, 18.0, 98.0),
        ('POST_PARCEL',   3.1, 0,  90, 16.0, 95.0),
        ('GROUP',         1.2, 0,  12,  3.5, 99.0)
    ) AS t(division, ltifr, fatals, injuries, work_hrs_m, safety_training))
),
quarters AS (
    SELECT 'Q' || (MOD(seq4(), 4) + 1) AS q_label,
           2024 + FLOOR(seq4() / 4) AS yr,
           seq4() AS q_idx
    FROM TABLE(GENERATOR(ROWCOUNT => 8))
)
SELECT
    'HS-' || LPAD(ROW_NUMBER() OVER (ORDER BY q.yr, q.q_label, d.division), 4, '0'),
    d.division,
    q.yr || '-' || q.q_label,
    LAST_DAY(TO_DATE(q.yr || '-' || (CASE q.q_label WHEN 'Q1' THEN '03' WHEN 'Q2' THEN '06' WHEN 'Q3' THEN '09' ELSE '12' END) || '-01', 'YYYY-MM-DD')),
    ROUND(d.ltifr + UNIFORM(-0.3, 0.3, RANDOM()) - (q.q_idx * 0.05), 2),
    d.fatals,
    ROUND(d.injuries + UNIFORM(-10, 10, RANDOM())),
    ROUND(d.work_hrs_m + UNIFORM(-1, 1, RANDOM()), 1),
    ROUND(d.safety_training + UNIFORM(-0.5, 0.5, RANDOM()), 1)
FROM divisions d
CROSS JOIN quarters q;


-- =============================================================================
-- EXT_EMISSION_FACTORS — GLEC Framework factors
-- =============================================================================

INSERT OVERWRITE INTO EXT_EMISSION_FACTORS VALUES
('EF-AIR-01',  'AIR',   'JET_A1',     'GLOBAL',  0.602000, 2.5400, NULL,     'GLEC_3_1', 2025),
('EF-AIR-02',  'AIR',   'SAF',        'GLOBAL',  0.060200, 0.2540, NULL,     'GLEC_3_1', 2025),
('EF-RD-01',   'ROAD',  'DIESEL',     'EUROPE',  0.096000, 2.6800, NULL,     'GLEC_3_1', 2025),
('EF-RD-02',   'ROAD',  'DIESEL',     'AMERICAS',0.105000, 2.6800, NULL,     'EPA_2025',  2025),
('EF-RD-03',   'ROAD',  'HVO',        'EUROPE',  0.009600, 0.2680, NULL,     'GLEC_3_1', 2025),
('EF-RD-04',   'ROAD',  'BEV_ELEC',   'EUROPE',  0.020000, NULL,   0.400000, 'GLEC_3_1', 2025),
('EF-RD-05',   'ROAD',  'BEV_ELEC',   'AMERICAS',0.025000, NULL,   0.500000, 'EPA_2025',  2025),
('EF-RD-06',   'ROAD',  'CNG',        'EUROPE',  0.072000, 2.0200, NULL,     'GLEC_3_1', 2025),
('EF-RD-07',   'ROAD',  'H2',         'EUROPE',  0.005000, NULL,   NULL,     'GLEC_3_1', 2025),
('EF-OC-01',   'OCEAN', 'BUNKER_FUEL','GLOBAL',  0.008500, 3.1140, NULL,     'GLEC_3_1', 2025),
('EF-OC-02',   'OCEAN', 'LNG',        'GLOBAL',  0.007000, 2.7500, NULL,     'GLEC_3_1', 2025),
('EF-RL-01',   'RAIL',  'ELECTRIC_RAIL','EUROPE', 0.028000, NULL,   0.400000, 'DEFRA_2025',2025),
('EF-RL-02',   'RAIL',  'DIESEL_RAIL','GLOBAL',  0.045000, 2.6800, NULL,     'DEFRA_2025',2025),
('EF-BLD-01',  NULL,    'GRID_CONV',  'EUROPE',  NULL,      NULL,   0.400000, 'DEFRA_2025',2025),
('EF-BLD-02',  NULL,    'GRID_CONV',  'AMERICAS',NULL,      NULL,   0.500000, 'EPA_2025',  2025),
('EF-BLD-03',  NULL,    'GRID_CONV',  'APAC',    NULL,      NULL,   0.600000, 'DEFRA_2025',2025),
('EF-BLD-04',  NULL,    'NATURAL_GAS','GLOBAL',  NULL,      2.0000, NULL,     'DEFRA_2025',2025),
('EF-BLD-05',  NULL,    'DIESEL_GEN', 'GLOBAL',  NULL,      2.6800, NULL,     'DEFRA_2025',2025);


-- =============================================================================
-- EXT_ESG_SCORES — World Delivery + logistics peer group
-- =============================================================================

INSERT OVERWRITE INTO EXT_ESG_SCORES VALUES
('ESG-001','World Delivery Group','WDLV','2025-09-30', 72.5, 68.0, 75.0, 74.5,'B', 'TARGETS_SET',    'ESG_BOOK',       'Transportation and Logistics'),
('ESG-002','World Delivery Group','WDLV','2024-09-30', 69.8, 65.2, 73.0, 71.2,'B', 'TARGETS_SET',    'ESG_BOOK',       'Transportation and Logistics'),
('ESG-003','FedEx Corporation',   'FDX', '2025-09-30', 58.2, 52.0, 62.0, 60.6,'C', 'COMMITTED',      'ESG_BOOK',       'Transportation and Logistics'),
('ESG-004','United Parcel Service','UPS','2025-09-30', 65.0, 60.5, 68.0, 66.5,'B', 'TARGETS_SET',    'ESG_BOOK',       'Transportation and Logistics'),
('ESG-005','Maersk',              'MAERSK','2025-09-30',70.0, 72.0, 65.0, 73.0,'B', 'TARGETS_SET',    'ESG_BOOK',       'Transportation and Logistics'),
('ESG-006','Kuehne+Nagel',        'KNIN','2025-09-30', 62.5, 58.0, 64.0, 65.5,'B', 'COMMITTED',      'ESG_BOOK',       'Transportation and Logistics'),
('ESG-007','DSV Panalpina',       'DSV', '2025-09-30', 55.0, 50.0, 58.0, 57.0,'C', 'NOT_COMMITTED',  'ESG_BOOK',       'Transportation and Logistics'),
('ESG-008','XPO Logistics',       'XPO', '2025-09-30', 48.5, 42.0, 52.0, 51.5,'C', 'NOT_COMMITTED',  'ESG_BOOK',       'Transportation and Logistics'),
('ESG-009','World Delivery Group','WDLV','2025-09-30', 74.0, 70.5, 76.0, 75.5,'B', 'TARGETS_SET',    'SUSTAINALYTICS', 'Transportation and Logistics'),
('ESG-010','World Delivery Group','WDLV','2025-09-30', 71.0, 67.0, 73.5, 72.5,'B', 'TARGETS_SET',    'FITCH',          'Transportation and Logistics');


-- =============================================================================
-- EXT_CLIMATE_RISK — physical and transition risk
-- =============================================================================

INSERT OVERWRITE INTO EXT_CLIMATE_RISK VALUES
('CR-001','HUB',          'EUROPE',   'DE', 3.2, 5.5, 'CARBON_PRICING',  'RCP_4_5','SHORT', 12000000,'2025-06-30'),
('CR-002','HUB',          'EUROPE',   'DE', 4.8, 5.5, 'FLOOD',           'RCP_8_5','MEDIUM',28000000,'2025-06-30'),
('CR-003','HUB',          'AMERICAS', 'US', 5.5, 4.2, 'STORM',           'RCP_4_5','SHORT', 18000000,'2025-06-30'),
('CR-004','HUB',          'APAC',     'HK', 6.8, 3.5, 'STORM',           'RCP_8_5','SHORT', 35000000,'2025-06-30'),
('CR-005','HUB',          'MEA',      'AE', 7.2, 4.0, 'HEAT_STRESS',     'RCP_8_5','MEDIUM',22000000,'2025-06-30'),
('CR-006','SORT_CENTER',  'EUROPE',   'DE', 2.5, 5.5, 'CARBON_PRICING',  'RCP_4_5','SHORT',  5000000,'2025-06-30'),
('CR-007','SORT_CENTER',  'EUROPE',   'GB', 4.0, 6.0, 'REGULATION',      'RCP_4_5','SHORT',  8000000,'2025-06-30'),
('CR-008','WAREHOUSE',    'APAC',     'IN', 6.5, 3.0, 'FLOOD',           'RCP_8_5','MEDIUM',15000000,'2025-06-30'),
('CR-009','WAREHOUSE',    'AMERICAS', 'US', 3.8, 4.5, 'REGULATION',      'RCP_4_5','MEDIUM', 7000000,'2025-06-30'),
('CR-010','FREIGHT_TERMINAL','EUROPE','NL', 5.2, 5.8, 'FLOOD',           'RCP_8_5','LONG',  42000000,'2025-06-30'),
('CR-011','FREIGHT_TERMINAL','APAC',  'SG', 4.5, 3.2, 'FLOOD',           'RCP_4_5','MEDIUM',12000000,'2025-06-30'),
('CR-012','FLEET_DEPOT',  'EUROPE',   'DE', 2.0, 6.5, 'STRANDED_ASSETS', 'RCP_2_6','SHORT', 25000000,'2025-06-30'),
('CR-013','FLEET_DEPOT',  'EUROPE',   'DE', 2.0, 4.0, 'STRANDED_ASSETS', 'RCP_4_5','MEDIUM',15000000,'2025-06-30'),
('CR-014','OFFICE',       'EUROPE',   'DE', 1.5, 5.0, 'CARBON_PRICING',  'RCP_4_5','SHORT',  2000000,'2025-06-30'),
('CR-015','OFFICE',       'MEA',      'AE', 7.0, 3.5, 'HEAT_STRESS',     'RCP_8_5','MEDIUM', 3000000,'2025-06-30');


-- =============================================================================
-- Z_EMISSION_FORECAST — 3 scenarios x 2 scope groups x 11 years (2020-2030)
--
-- Anchored in DHL's real SBTi targets:
--   2020 baseline: Scope 1+2 = 7.52M t, Scope 3 = 32.7M t
--   2030 SBTi:     Scope 1+2 = 4.36M t (-42%), Scope 3 = 24.53M t (-25%)
--
-- Scenarios:
--   ACTUAL       — historical actuals (2020-2025), from DHL statbook
--   BAU          — current trajectory continues (insufficient for SBTi)
--   ACCELERATED  — doubled SAF + accelerated fleet electrification
--   SBTI_REQUIRED — linear reduction path needed to hit 2030 targets
-- =============================================================================

INSERT OVERWRITE INTO Z_EMISSION_FORECAST
    (FORECASTID, REPORTING_YEAR, SCOPE_GROUP, SCENARIO, TOTAL_CO2E_TONNES,
     REDUCTION_FROM_BASE_PCT, IS_FORECAST, KEY_ASSUMPTIONS, FORECAST_DATE, MODEL_VERSION)
-- Historical actuals (scaled from DHL Climate Targets sheet)
SELECT * FROM (VALUES
  ('FC-A-12-20',2020,'SCOPE_1_2','ACTUAL',   7520000, 0.0,  FALSE,'Baseline year','2026-10-01','v1.0'),
  ('FC-A-12-21',2021,'SCOPE_1_2','ACTUAL',   7350000,-2.3,  FALSE,'COVID recovery','2026-10-01','v1.0'),
  ('FC-A-12-22',2022,'SCOPE_1_2','ACTUAL',   7180000,-4.5,  FALSE,'Fleet electrification begins','2026-10-01','v1.0'),
  ('FC-A-12-23',2023,'SCOPE_1_2','ACTUAL',   6900000,-8.2,  FALSE,'SAF scaling + 30k e-vehicles','2026-10-01','v1.0'),
  ('FC-A-12-24',2024,'SCOPE_1_2','ACTUAL',   6650000,-11.6, FALSE,'50k e-vehicles milestone','2026-10-01','v1.0'),
  ('FC-A-12-25',2025,'SCOPE_1_2','ACTUAL',   6460000,-14.1, FALSE,'185kt SAF deployed','2026-10-01','v1.0'),
  ('FC-A-3-20', 2020,'SCOPE_3',  'ACTUAL',  32700000, 0.0,  FALSE,'Baseline year','2026-10-01','v1.0'),
  ('FC-A-3-21', 2021,'SCOPE_3',  'ACTUAL',  32100000,-1.8,  FALSE,'COVID impact on volumes','2026-10-01','v1.0'),
  ('FC-A-3-22', 2022,'SCOPE_3',  'ACTUAL',  31800000,-2.8,  FALSE,'Volume recovery, efficiency gains','2026-10-01','v1.0'),
  ('FC-A-3-23', 2023,'SCOPE_3',  'ACTUAL',  31400000,-4.0,  FALSE,'Carrier sustainability requirements','2026-10-01','v1.0'),
  ('FC-A-3-24', 2024,'SCOPE_3',  'ACTUAL',  32190000,-1.6,  FALSE,'Volume growth offset efficiency','2026-10-01','v1.0'),
  ('FC-A-3-25', 2025,'SCOPE_3',  'ACTUAL',  31500000,-3.7,  FALSE,'GoGreen Plus scaling','2026-10-01','v1.0')
) AS t(id,yr,scope,scenario,co2e,reduction,is_fc,assumptions,fc_date,model)
UNION ALL
-- BAU scenario: current ~2.5% annual reduction Scope 1+2, ~1% Scope 3
SELECT
    'FC-BAU-' || s.scope || '-' || y.yr,
    y.yr, s.scope, 'BAU',
    ROUND(s.base * POWER(1 - s.annual_rate, y.yr - 2025)),
    ROUND((1 - POWER(1 - s.annual_rate, y.yr - 2020)) * 100, 2),
    TRUE,
    'Current trajectory: ' || (s.annual_rate*100) || '% annual reduction continues',
    '2026-10-01'::DATE, 'v1.0'
FROM (VALUES (2026),(2027),(2028),(2029),(2030)) AS y(yr)
CROSS JOIN (VALUES
    ('SCOPE_1_2', 6460000, 0.028),
    ('SCOPE_3',   31500000, 0.012)
) AS s(scope, base, annual_rate)
UNION ALL
-- ACCELERATED scenario: doubled decarb investment, SAF to 30%, 80k e-vehicles
SELECT
    'FC-ACC-' || s.scope || '-' || y.yr,
    y.yr, s.scope, 'ACCELERATED',
    ROUND(s.base * POWER(1 - s.annual_rate, y.yr - 2025)),
    ROUND((1 - POWER(1 - s.annual_rate, y.yr - 2020) * s.base / s.baseline_2020) * 100, 2),
    TRUE,
    s.assumptions,
    '2026-10-01'::DATE, 'v1.0'
FROM (VALUES (2026),(2027),(2028),(2029),(2030)) AS y(yr)
CROSS JOIN (VALUES
    ('SCOPE_1_2', 6460000, 0.052, 7520000, 'SAF to 30% blend by 2028, 80k e-vehicles by 2029, 100% renewable electricity'),
    ('SCOPE_3',   31500000, 0.028, 32700000, 'Carrier sustainability mandates, GoGreen Plus to 15% of revenue, rail modal shift')
) AS s(scope, base, annual_rate, baseline_2020, assumptions)
UNION ALL
-- SBTi REQUIRED: linear path from 2025 actuals to 2030 targets
SELECT
    'FC-SBT-' || s.scope || '-' || y.yr,
    y.yr, s.scope, 'SBTI_REQUIRED',
    ROUND(s.current_2025 + (s.target_2030 - s.current_2025) * (y.yr - 2025) / 5.0),
    ROUND((1 - (s.current_2025 + (s.target_2030 - s.current_2025) * (y.yr - 2025) / 5.0) / s.baseline_2020) * 100, 2),
    TRUE,
    'Linear reduction required to meet SBTi 2030: ' || s.target_label,
    '2026-10-01'::DATE, 'v1.0'
FROM (VALUES (2026),(2027),(2028),(2029),(2030)) AS y(yr)
CROSS JOIN (VALUES
    ('SCOPE_1_2', 6460000, 4360000, 7520000, '-42% from 2020 baseline'),
    ('SCOPE_3',   31500000, 24530000, 32700000, '-25% from 2020 baseline')
) AS s(scope, current_2025, target_2030, baseline_2020, target_label);


-- =============================================================================
-- Z_DECARB_LEVERS — marginal abatement cost curve data for each lever
-- Models what each decarbonization technology contributes per scenario
-- =============================================================================

INSERT OVERWRITE INTO Z_DECARB_LEVERS
    (LEVERID, REPORTING_YEAR, SCENARIO, LEVER_NAME, CO2E_REDUCTION_KT,
     INVESTMENT_MEUR, COST_PER_TONNE_EUR, READINESS)
SELECT * FROM (VALUES
  -- BAU scenario — current planned investment levels
  ('DL-BAU-SAF-26',  2026,'BAU','SAF',                 250, 220, 880,'DEPLOYED'),
  ('DL-BAU-SAF-27',  2027,'BAU','SAF',                 320, 270, 844,'DEPLOYED'),
  ('DL-BAU-SAF-28',  2028,'BAU','SAF',                 400, 330, 825,'DEPLOYED'),
  ('DL-BAU-SAF-29',  2029,'BAU','SAF',                 480, 400, 833,'SCALING'),
  ('DL-BAU-SAF-30',  2030,'BAU','SAF',                 560, 470, 839,'SCALING'),
  ('DL-BAU-FLT-26',  2026,'BAU','FLEET_ELECTRIFICATION',45, 160,3556,'DEPLOYED'),
  ('DL-BAU-FLT-27',  2027,'BAU','FLEET_ELECTRIFICATION',55, 180,3273,'DEPLOYED'),
  ('DL-BAU-FLT-28',  2028,'BAU','FLEET_ELECTRIFICATION',65, 200,3077,'SCALING'),
  ('DL-BAU-FLT-29',  2029,'BAU','FLEET_ELECTRIFICATION',75, 210,2800,'SCALING'),
  ('DL-BAU-FLT-30',  2030,'BAU','FLEET_ELECTRIFICATION',85, 220,2588,'SCALING'),
  ('DL-BAU-REN-26',  2026,'BAU','RENEWABLE_ENERGY',    180, 45, 250,'DEPLOYED'),
  ('DL-BAU-REN-27',  2027,'BAU','RENEWABLE_ENERGY',    200, 50, 250,'DEPLOYED'),
  ('DL-BAU-REN-28',  2028,'BAU','RENEWABLE_ENERGY',    220, 55, 250,'DEPLOYED'),
  ('DL-BAU-REN-29',  2029,'BAU','RENEWABLE_ENERGY',    240, 58, 242,'DEPLOYED'),
  ('DL-BAU-REN-30',  2030,'BAU','RENEWABLE_ENERGY',    260, 60, 231,'DEPLOYED'),
  ('DL-BAU-EFF-26',  2026,'BAU','EFFICIENCY',          120, 30, 250,'DEPLOYED'),
  ('DL-BAU-EFF-27',  2027,'BAU','EFFICIENCY',          130, 32, 246,'DEPLOYED'),
  ('DL-BAU-EFF-28',  2028,'BAU','EFFICIENCY',          135, 33, 244,'DEPLOYED'),
  ('DL-BAU-EFF-29',  2029,'BAU','EFFICIENCY',          140, 34, 243,'DEPLOYED'),
  ('DL-BAU-EFF-30',  2030,'BAU','EFFICIENCY',          145, 35, 241,'DEPLOYED'),
  -- ACCELERATED scenario — doubled investment, new technologies
  ('DL-ACC-SAF-26',  2026,'ACCELERATED','SAF',          350, 380, 1086,'DEPLOYED'),
  ('DL-ACC-SAF-27',  2027,'ACCELERATED','SAF',          520, 520, 1000,'DEPLOYED'),
  ('DL-ACC-SAF-28',  2028,'ACCELERATED','SAF',          750, 680, 907,'SCALING'),
  ('DL-ACC-SAF-29',  2029,'ACCELERATED','SAF',          950, 800, 842,'SCALING'),
  ('DL-ACC-SAF-30',  2030,'ACCELERATED','SAF',         1200, 950, 792,'SCALING'),
  ('DL-ACC-FLT-26',  2026,'ACCELERATED','FLEET_ELECTRIFICATION',80, 320,4000,'DEPLOYED'),
  ('DL-ACC-FLT-27',  2027,'ACCELERATED','FLEET_ELECTRIFICATION',120,420,3500,'SCALING'),
  ('DL-ACC-FLT-28',  2028,'ACCELERATED','FLEET_ELECTRIFICATION',170,500,2941,'SCALING'),
  ('DL-ACC-FLT-29',  2029,'ACCELERATED','FLEET_ELECTRIFICATION',220,550,2500,'SCALING'),
  ('DL-ACC-FLT-30',  2030,'ACCELERATED','FLEET_ELECTRIFICATION',280,580,2071,'SCALING'),
  ('DL-ACC-REN-26',  2026,'ACCELERATED','RENEWABLE_ENERGY',220, 65, 295,'DEPLOYED'),
  ('DL-ACC-REN-27',  2027,'ACCELERATED','RENEWABLE_ENERGY',280, 80, 286,'DEPLOYED'),
  ('DL-ACC-REN-28',  2028,'ACCELERATED','RENEWABLE_ENERGY',350,100, 286,'DEPLOYED'),
  ('DL-ACC-REN-29',  2029,'ACCELERATED','RENEWABLE_ENERGY',400,110, 275,'DEPLOYED'),
  ('DL-ACC-REN-30',  2030,'ACCELERATED','RENEWABLE_ENERGY',450,115, 256,'DEPLOYED'),
  ('DL-ACC-H2-28',   2028,'ACCELERATED','H2_FUEL_CELL',    15, 40,2667,'PILOT'),
  ('DL-ACC-H2-29',   2029,'ACCELERATED','H2_FUEL_CELL',    35, 80,2286,'PILOT'),
  ('DL-ACC-H2-30',   2030,'ACCELERATED','H2_FUEL_CELL',    80,150,1875,'EMERGING'),
  ('DL-ACC-INS-26',  2026,'ACCELERATED','INSETTING',        50, 15, 300,'DEPLOYED'),
  ('DL-ACC-INS-27',  2027,'ACCELERATED','INSETTING',        80, 22, 275,'DEPLOYED'),
  ('DL-ACC-INS-28',  2028,'ACCELERATED','INSETTING',       120, 30, 250,'SCALING'),
  ('DL-ACC-INS-29',  2029,'ACCELERATED','INSETTING',       160, 38, 238,'SCALING'),
  ('DL-ACC-INS-30',  2030,'ACCELERATED','INSETTING',       200, 45, 225,'SCALING')
) AS t(id,yr,scenario,lever,co2e_kt,invest,cost_per_t,readiness);


SELECT 'Data seed complete. Row counts:' AS status;
SELECT 'COMPANYCODE: ' || COUNT(*) FROM COMPANYCODE
UNION ALL SELECT 'COSTCENTER: ' || COUNT(*) FROM COSTCENTER
UNION ALL SELECT 'PLANT: ' || COUNT(*) FROM PLANT
UNION ALL SELECT 'GL_ENTRIES: ' || COUNT(*) FROM GENERALLEDGERACCOUNTLINEITEM
UNION ALL SELECT 'SHIPMENT_EMISSIONS: ' || COUNT(*) FROM Z_SHIPMENT_EMISSIONS
UNION ALL SELECT 'FACILITY_ENERGY: ' || COUNT(*) FROM Z_FACILITY_ENERGY
UNION ALL SELECT 'FLEET_VEHICLE: ' || COUNT(*) FROM Z_FLEET_VEHICLE
UNION ALL SELECT 'FLEET_FUEL_LOG: ' || COUNT(*) FROM Z_FLEET_FUEL_LOG
UNION ALL SELECT 'GOGREEN_PLUS: ' || COUNT(*) FROM Z_GOGREEN_PLUS_ORDER
UNION ALL SELECT 'WORKFORCE: ' || COUNT(*) FROM SF_CORE_WORKFORCE
UNION ALL SELECT 'HEALTH_SAFETY: ' || COUNT(*) FROM SF_HEALTH_SAFETY
UNION ALL SELECT 'EMISSION_FACTORS: ' || COUNT(*) FROM EXT_EMISSION_FACTORS
UNION ALL SELECT 'ESG_SCORES: ' || COUNT(*) FROM EXT_ESG_SCORES
UNION ALL SELECT 'CLIMATE_RISK: ' || COUNT(*) FROM EXT_CLIMATE_RISK
UNION ALL SELECT 'EMISSION_FORECAST: ' || COUNT(*) FROM Z_EMISSION_FORECAST
UNION ALL SELECT 'DECARB_LEVERS: ' || COUNT(*) FROM Z_DECARB_LEVERS;
