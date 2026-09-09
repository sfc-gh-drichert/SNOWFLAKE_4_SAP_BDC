-- =============================================================================
-- 05_data_seed.sql — ~100,000 Row Synthetic Data Generation
--
-- STRATEGY
-- ─────────────────────────────────────────────────────────────────────────────
-- Uses GENERATOR(ROWCOUNT=>100000) to produce exactly 100,000 rows.
-- Each row is deterministically assigned to one of 12 GL account types
-- via MOD arithmetic, so all 12 PnL lines are evenly represented (~8,333
-- rows each). Within a GL type, amounts are seeded with RANDOM(rn*k)
-- to produce row-specific values that are reproducible.
--
-- COST STRUCTURE (calibrated to BSH 2024 actuals: EBIT ~6% of net revenue)
-- ─────────────────────────────────────────────────────────────────────────────
-- All pct_factor values are expressed as a fraction of GROSS REVENUE:
--
--   Gross Revenue          +1.000  (100.0% of gross)
--   Trade Discounts        -0.075  ( -7.5%)
--   Returns                -0.010  ( -1.0%)
--   Net Revenue            = 91.5% of gross = 100% of net
--   Material COGS          -0.412  (-45.0% of net)
--   Mfg Labour             -0.073  ( -8.0% of net)
--   Mfg Overhead           -0.073  ( -8.0% of net)
--   Logistics              -0.046  ( -5.0% of net)
--   Gross Profit           = 31.1% of gross = 34.0% of net
--   Brand Advertising and Promotion              -0.082  ( -9.0% of net)
--   Trade Marketing        -0.023  ( -2.5% of net)
--   DB1 Marginal Contrib   = 20.6% of gross = 22.5% of net
--   Sales Costs            -0.064  ( -7.0% of net)
--   DB2 Marginal Contrib   = 14.2% of gross = 15.5% of net
--   Research and Development                    -0.055  ( -6.0% of net) ← BSH actual €835M/€15.3B
--   General and Administrative                    -0.032  ( -3.5% of net)
--   EBIT                   =  5.5% of gross =  6.0% of net ✓
--
-- PREMIUM BRAND OVERRIDES
--   Gaggenau:  COGS × 0.80, Trade Discounts × 0.60 → GP margin ~46%
--   Thermador: COGS × 0.87, Trade Discounts × 0.65 → GP margin ~41%
--
-- SEASONALITY MULTIPLIERS (applied to all GL lines equally)
--   Dec +35%, Nov +25%, Oct +15%, Sep +10% (IFA Berlin launch season)
--   Jan -20%, Aug -15%, Jul -10%
--
-- CATEGORY 2024 GROWTH (applied when FISCALYEAR=2024)
--   Cooking       ×0.954 (-4.6% — built-in appliance slump)
--   Laundry Care  ×1.041 (+4.1%)
--   Dish Care     ×1.032 (+3.2%)
--   Cooling       ×0.996 (-0.4%)
--   Consumer Prods×1.055 (+5.5%)
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

INSERT INTO S3_FINANCE_PNL (
    CLIENT_ID, MONTHYEAR, DATAENTRYPERIOD, FISCALYEAR, POSTINGPERIOD, POSTINGDATE,
    HSL, CURRENCY, CURRENCYTYPE,
    ACDOCA_RACCT, PNL_CATEGORY, LEDGER,
    COMPANYCODE, COUNTRY, COUNTRY_SOLD_TO,
    SALESORGANISATION, DISTRIBUTIONCHANNEL, CONTROLLINGAREA,
    REGION, PLANT, FUNCTIONALAREA, COSTCENTER,
    CUSTOMER, CUSTOMERGROUP,
    MATERIAL, PRODUCT_NAME, BRAND, CATEGORY, SUBCATEGORY, PRODUCT_TIER,
    CORPORATEBRAND, SALESVOLUME, LIST_PRICE_EUR,
    SALESORDER, BILLINGTYPE, VERSION, RECORDTYPE,
    LASTUPDATE_TS_REPORTING, CFIN_TS_DELTA
)
WITH

-- ─── GL account types — 12 lines per transaction cluster ───────────────────
gl_types AS (
    SELECT * FROM (VALUES
    --  idx  account    pnl_cat       func   pct_factor  label
        ( 0, '0800000', 'REVENUE',    'REV',  1.000,  'Gross Revenue'),
        ( 1, '0810000', 'TRADE_SPEND','SPD', -0.075,  'Trade Discounts'),
        ( 2, '0810100', 'TRADE_SPEND','SPD', -0.010,  'Volume Bonuses'),  -- returns folded into trade
        ( 3, '0820000', 'RETURNS',    'SPD', -0.010,  'Returns'),
        ( 4, '0500000', 'COGS',       'COS', -0.412,  'Material COGS'),
        ( 5, '0510000', 'COGS',       'COS', -0.073,  'Mfg Labour'),
        ( 6, '0520000', 'COGS',       'COS', -0.073,  'Mfg Overhead'),
        ( 7, '0530000', 'LOGISTICS',  'LOG', -0.046,  'Logistics'),
        ( 8, '0600000', 'BRAND_ADP',  'ADP', -0.082,  'Brand Advertising and Promotion'),
        ( 9, '0610000', 'BRAND_ADP',  'ADP', -0.023,  'Trade Marketing'),
        (10, '0620000', 'SALES',      'SLS', -0.064,  'Sales Costs'),
        (11, '0700000', 'RD',         'RD',  -0.055,  'Research and Development'),
        (12, '0710000', 'GA',         'GA',  -0.032,  'General and Administrative')
    ) t(gl_idx, racct, pnl_cat, func_area, pct_factor, lbl)
),

-- ─── 100,000 base rows from GENERATOR ──────────────────────────────────────
base AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4()) AS rn,
        UNIFORM(1, 999999, RANDOM(42))      AS rseed   -- global seed for reproducibility
    FROM TABLE(GENERATOR(ROWCOUNT => 100000))
),

-- ─── Assign all dimensions deterministically ───────────────────────────────
assigned AS (
    SELECT
        b.rn,
        b.rseed,

        -- ── Period: 45 months, Jan 2023 – Sep 2026 (partial current year) ─────
        MOD(b.rn - 1, 45)                                    AS period_offset,
        DATEADD('month', MOD(b.rn - 1, 45), '2023-01-01')   AS period_date,
        YEAR( DATEADD('month', MOD(b.rn - 1, 45), '2023-01-01'))  AS fy,
        MONTH(DATEADD('month', MOD(b.rn - 1, 45), '2023-01-01'))  AS fp,

        -- ── GL type: 13 types cycling across all rows ────────────────────────
        MOD(b.rn - 1, 13)  AS gl_idx,

        -- ── Brand (weighted: Bosch 50%, Siemens 28%, Gaggenau 7%, Neff 8%, Thermador 7%)
        CASE
            WHEN MOD(b.rn, 100) <  50 THEN 'BOSCH'
            WHEN MOD(b.rn, 100) <  78 THEN 'SIEMENS'
            WHEN MOD(b.rn, 100) <  85 THEN 'GAGGENAU'
            WHEN MOD(b.rn, 100) <  93 THEN 'NEFF'
            ELSE                            'THERMADOR'
        END  AS brand,

        -- ── Category (brand-aware: only assigns categories each brand sells)
        -- Gaggenau  : COOKING | COOLING | DISH_CARE        (luxury specialist)
        -- NEFF      : COOKING | DISH_CARE | LAUNDRY_CARE   (cooking enthusiast brand)
        -- Thermador : COOKING | COOLING | DISH_CARE        (NA luxury kitchen)
        -- Bosch/Siemens: all 5 categories
        CASE
            WHEN MOD(b.rn, 100) BETWEEN 78 AND 84  -- Gaggenau
                THEN CASE MOD(FLOOR((b.rn - 1) / 13), 3)
                     WHEN 0 THEN 'COOKING' WHEN 1 THEN 'COOLING' ELSE 'DISH_CARE' END
            WHEN MOD(b.rn, 100) >= 93              -- Thermador
                THEN CASE MOD(FLOOR((b.rn - 1) / 13), 3)
                     WHEN 0 THEN 'COOKING' WHEN 1 THEN 'COOLING' ELSE 'DISH_CARE' END
            WHEN MOD(b.rn, 100) BETWEEN 85 AND 92  -- Neff
                THEN CASE MOD(FLOOR((b.rn - 1) / 13), 3)
                     WHEN 0 THEN 'COOKING' WHEN 1 THEN 'DISH_CARE' ELSE 'LAUNDRY_CARE' END
            ELSE  -- Bosch and Siemens: all 5 categories
                CASE MOD(FLOOR((b.rn - 1) / 13), 5)
                    WHEN 0 THEN 'LAUNDRY_CARE' WHEN 1 THEN 'DISH_CARE'
                    WHEN 2 THEN 'COOKING'      WHEN 3 THEN 'COOLING'
                    ELSE 'CONSUMER_PRODUCTS'
                END
        END  AS category,

        -- ── Region (weighted: DACH 35%, W_EU 25%, E_EU 10%, NA 5%, APAC 15%, EM 10%)
        CASE
            WHEN MOD(FLOOR((b.rn - 1) / 65), 100) <  35 THEN 'DACH'
            WHEN MOD(FLOOR((b.rn - 1) / 65), 100) <  60 THEN 'W_EUROPE'
            WHEN MOD(FLOOR((b.rn - 1) / 65), 100) <  70 THEN 'E_EUROPE'
            WHEN MOD(FLOOR((b.rn - 1) / 65), 100) <  75 THEN 'N_AMERICA'
            WHEN MOD(FLOOR((b.rn - 1) / 65), 100) <  90 THEN 'APAC'
            ELSE                                               'EMERGING'
        END  AS region_name,

        -- ── Distribution channel (cycling: Retail 40%, Built-in 25%, eCom 25%, B2B 10%)
        CASE MOD(FLOOR((b.rn - 1) / 325), 4)
            WHEN 0 THEN '10'   -- Retail Specialist
            WHEN 1 THEN '20'   -- Built-in / Project
            WHEN 2 THEN '30'   -- E-Commerce
            WHEN 3 THEN '40'   -- B2B / Commercial
        END  AS dist_ch,

        -- ── Base transaction amount (EUR, varies by brand tier) ──────────────
        ROUND(
            CASE
                WHEN MOD(b.rn, 100) BETWEEN 78 AND 84  -- Gaggenau (premium)
                    THEN CAST(80000 + ABS(HASH(b.rn,  7)) % 420001 AS NUMBER(18,2))
                WHEN MOD(b.rn, 100) >= 93              -- Thermador (premium NA)
                    THEN CAST(60000 + ABS(HASH(b.rn, 11)) % 240001 AS NUMBER(18,2))
                WHEN MOD(b.rn, 100) BETWEEN 85 AND 92  -- Neff (mid-premium)
                    THEN CAST(30000 + ABS(HASH(b.rn, 13)) % 170001 AS NUMBER(18,2))
                WHEN MOD(b.rn, 100) BETWEEN 50 AND 77  -- Siemens
                    THEN CAST(40000 + ABS(HASH(b.rn, 17)) % 310001 AS NUMBER(18,2))
                ELSE                                    -- Bosch
                    CAST(50000 + ABS(HASH(b.rn, 19)) % 350001 AS NUMBER(18,2))
            END
        , 2) AS base_amount,

        -- ── Seasonality multiplier ────────────────────────────────────────────
        CASE MONTH(DATEADD('month', MOD(b.rn - 1, 45), '2023-01-01'))
            WHEN 12 THEN 1.35   -- December: Christmas peak
            WHEN 11 THEN 1.25   -- November: Black Friday + pre-Christmas
            WHEN 10 THEN 1.15   -- October: build-up
            WHEN  9 THEN 1.10   -- September: IFA Berlin launches new products
            WHEN  5 THEN 1.08   -- May: kitchen refit / spring
            WHEN  4 THEN 1.05   -- April: spring
            WHEN  6 THEN 1.00   -- June: neutral
            WHEN  3 THEN 0.95   -- March: quiet
            WHEN  7 THEN 0.90   -- July: summer lull
            WHEN  2 THEN 0.87   -- February: post-holiday trough
            WHEN  8 THEN 0.85   -- August: IFA prep dip
            WHEN  1 THEN 0.80   -- January: post-Christmas slowdown
            ELSE 1.00
        END  AS season_factor

    FROM base b
),

-- ─── Join GL types and enrich with product + customer assignments ───────────
enriched AS (
    SELECT
        a.*,
        gl.racct,
        gl.pnl_cat,
        gl.func_area,
        gl.pct_factor,

        -- ── HSL amount (positive = revenue, negative = cost) ─────────────────
        ROUND(
            a.base_amount
            * gl.pct_factor
            * a.season_factor
            -- Category growth/decline adjustors by year
            -- 2024: Cooking -4.6% (built-in slump); Consumer Products +5.5%
            -- 2025: Cooking begins recovery; NA growth continues
            -- 2026: Stronger Cooking recovery; AI appliances lift Consumer Products
            * CASE
                WHEN a.fy = 2024 AND a.category = 'COOKING'          THEN 0.954
                WHEN a.fy = 2024 AND a.category = 'LAUNDRY_CARE'     THEN 1.041
                WHEN a.fy = 2024 AND a.category = 'DISH_CARE'        THEN 1.032
                WHEN a.fy = 2024 AND a.category = 'COOLING'          THEN 0.996
                WHEN a.fy = 2024 AND a.category = 'CONSUMER_PRODUCTS'THEN 1.055
                WHEN a.fy = 2025 AND a.category = 'COOKING'          THEN 1.015
                WHEN a.fy = 2025 AND a.category = 'LAUNDRY_CARE'     THEN 1.020
                WHEN a.fy = 2025 AND a.category = 'DISH_CARE'        THEN 0.990
                WHEN a.fy = 2025 AND a.category = 'COOLING'          THEN 1.000
                WHEN a.fy = 2025 AND a.category = 'CONSUMER_PRODUCTS'THEN 1.040
                WHEN a.fy = 2026 AND a.category = 'COOKING'          THEN 1.030
                WHEN a.fy = 2026 AND a.category = 'LAUNDRY_CARE'     THEN 1.030
                WHEN a.fy = 2026 AND a.category = 'DISH_CARE'        THEN 1.020
                WHEN a.fy = 2026 AND a.category = 'COOLING'          THEN 1.010
                WHEN a.fy = 2026 AND a.category = 'CONSUMER_PRODUCTS'THEN 1.060
                ELSE 1.000
              END
            -- Premium brand margin overrides (reduce cost ratios → better margins)
            * CASE
                WHEN a.brand = 'GAGGENAU'  AND gl.pnl_cat IN ('COGS','LOGISTICS')   THEN 0.80
                WHEN a.brand = 'GAGGENAU'  AND gl.pnl_cat IN ('TRADE_SPEND','RETURNS') THEN 0.60
                WHEN a.brand = 'THERMADOR' AND gl.pnl_cat IN ('COGS','LOGISTICS')   THEN 0.87
                WHEN a.brand = 'THERMADOR' AND gl.pnl_cat IN ('TRADE_SPEND','RETURNS') THEN 0.65
                ELSE 1.000
              END
        , 2) AS hsl_amount,

        -- ── Company code (derived from region) ───────────────────────────────
        CASE a.region_name
            WHEN 'DACH'      THEN '1000'
            WHEN 'W_EUROPE'  THEN '1100'
            WHEN 'E_EUROPE'  THEN '1200'
            WHEN 'N_AMERICA' THEN '2000'
            WHEN 'APAC'      THEN '3000'
            WHEN 'EMERGING'  THEN '4000'
        END AS compcode,

        -- ── Country (from company code/region) ───────────────────────────────
        CASE a.region_name
            WHEN 'DACH'      THEN 'DEU'
            WHEN 'W_EUROPE'  THEN 'FRA'
            WHEN 'E_EUROPE'  THEN 'POL'
            WHEN 'N_AMERICA' THEN 'USA'
            WHEN 'APAC'      THEN 'CHN'
            WHEN 'EMERGING'  THEN 'TUR'
        END AS country_code,

        -- ── Plant (derived from region) ───────────────────────────────────────
        CASE a.region_name
            WHEN 'DACH'      THEN CASE MOD(a.rn, 4) WHEN 0 THEN 'GI01' WHEN 1 THEN 'DI01' WHEN 2 THEN 'TR01' ELSE 'BR01' END
            WHEN 'W_EUROPE'  THEN 'TR01'
            WHEN 'E_EUROPE'  THEN 'CZ01'
            WHEN 'N_AMERICA' THEN 'NB01'
            WHEN 'APAC'      THEN 'CH01'
            WHEN 'EMERGING'  THEN 'TR02'
        END AS plant_code,

        -- ── Sales organisation (by brand) ─────────────────────────────────────
        CASE a.brand
            WHEN 'BOSCH'     THEN '0010'
            WHEN 'SIEMENS'   THEN '0020'
            WHEN 'GAGGENAU'  THEN '0030'
            WHEN 'NEFF'      THEN '0040'
            WHEN 'THERMADOR' THEN '0050'
        END AS sales_org,

        -- ── Material number (brand + category → specific SKU) ─────────────────
        CASE
            WHEN a.brand = 'BOSCH'    AND a.category = 'DISH_CARE'
                THEN CASE MOD(a.rn,4) WHEN 0 THEN 'BSH-DW-B8000' WHEN 1 THEN 'BSH-DW-B6000' WHEN 2 THEN 'BSH-DW-B4000' ELSE 'BSH-DW-B2000' END
            WHEN a.brand = 'BOSCH'    AND a.category = 'LAUNDRY_CARE'
                THEN CASE MOD(a.rn,4) WHEN 0 THEN 'BSH-WM-B8100' WHEN 1 THEN 'BSH-WM-B6100' WHEN 2 THEN 'BSH-WM-B4100' ELSE 'BSH-TD-B8100' END
            WHEN a.brand = 'BOSCH'    AND a.category = 'COOKING'
                THEN CASE MOD(a.rn,4) WHEN 0 THEN 'BSH-OV-B8000' WHEN 1 THEN 'BSH-OV-B6000' WHEN 2 THEN 'BSH-OV-B4000' ELSE 'BSH-IH-B6000' END
            WHEN a.brand = 'BOSCH'    AND a.category = 'COOLING'
                THEN CASE MOD(a.rn,3) WHEN 0 THEN 'BSH-FF-B8000' WHEN 1 THEN 'BSH-FF-B6000' ELSE 'BSH-FF-B4000' END
            WHEN a.brand = 'BOSCH'    AND a.category = 'CONSUMER_PRODUCTS'
                THEN CASE MOD(a.rn,3) WHEN 0 THEN 'BSH-CF-B8000' WHEN 1 THEN 'BSH-CF-B6000' ELSE 'BSH-VC-B6000' END
            WHEN a.brand = 'SIEMENS'  AND a.category = 'DISH_CARE'
                THEN CASE MOD(a.rn,3) WHEN 0 THEN 'BSH-DW-S7000' WHEN 1 THEN 'BSH-DW-S5000' ELSE 'BSH-DW-S3000' END
            WHEN a.brand = 'SIEMENS'  AND a.category = 'LAUNDRY_CARE'
                THEN CASE MOD(a.rn,3) WHEN 0 THEN 'BSH-WM-S7100' WHEN 1 THEN 'BSH-WM-S5100' ELSE 'BSH-TD-S7100' END
            WHEN a.brand = 'SIEMENS'  AND a.category = 'COOKING'
                THEN CASE MOD(a.rn,3) WHEN 0 THEN 'BSH-OV-S9000' WHEN 1 THEN 'BSH-OV-S7000' ELSE 'BSH-IH-S7000' END
            WHEN a.brand = 'SIEMENS'  AND a.category = 'COOLING'
                THEN CASE MOD(a.rn,2) WHEN 0 THEN 'BSH-FF-S7000' ELSE 'BSH-FF-S5000' END
            WHEN a.brand = 'SIEMENS'  AND a.category = 'CONSUMER_PRODUCTS'
                THEN CASE MOD(a.rn,2) WHEN 0 THEN 'BSH-CF-S9000' ELSE 'BSH-CF-S7000' END
            WHEN a.brand = 'GAGGENAU' AND a.category = 'COOKING'
                THEN CASE MOD(a.rn,4) WHEN 0 THEN 'BSH-OV-G4800' WHEN 1 THEN 'BSH-OV-G4700' WHEN 2 THEN 'BSH-IH-G4820' ELSE 'BSH-IH-G4250' END
            WHEN a.brand = 'GAGGENAU' AND a.category = 'COOLING'
                THEN CASE MOD(a.rn,2) WHEN 0 THEN 'BSH-RF-G4920' ELSE 'BSH-FZ-G4910' END
            WHEN a.brand = 'GAGGENAU' AND a.category = 'DISH_CARE'  THEN 'BSH-DW-G2870'
            WHEN a.brand = 'NEFF'     AND a.category = 'COOKING'
                THEN CASE MOD(a.rn,4) WHEN 0 THEN 'BSH-OV-N5770' WHEN 1 THEN 'BSH-OV-N6900' WHEN 2 THEN 'BSH-OV-N4700' ELSE 'BSH-IH-N4600' END
            WHEN a.brand = 'NEFF'     AND a.category = 'DISH_CARE'
                THEN CASE MOD(a.rn,2) WHEN 0 THEN 'BSH-DW-N5850' ELSE 'BSH-DW-N8970' END
            WHEN a.brand = 'NEFF'     AND a.category = 'LAUNDRY_CARE' THEN 'BSH-WM-N7100'
            WHEN a.brand = 'THERMADOR' AND a.category = 'COOKING'     THEN 'BSH-OV-T3600'
            WHEN a.brand = 'THERMADOR' AND a.category = 'DISH_CARE'   THEN 'BSH-DW-T3000'
            WHEN a.brand = 'THERMADOR' AND a.category = 'COOLING'
                THEN CASE MOD(a.rn,2) WHEN 0 THEN 'BSH-FF-T3600' ELSE 'BSH-FZ-T3600' END
            -- Fallback for brand/category combos not in BSH's portfolio (e.g. Gaggenau laundry)
            ELSE 'BSH-DW-B4000'
        END AS mat_code,

        -- ── Customer (region-aware assignment) ───────────────────────────────
        CASE
            WHEN a.region_name = 'DACH' THEN
                CASE MOD(a.rn, 10)
                    WHEN 0 THEN '0000100001' WHEN 1 THEN '0000100001'  -- MediaMarkt DE (20%)
                    WHEN 2 THEN '0000100003' WHEN 3 THEN '0000100003'  -- Amazon DE (20%)
                    WHEN 4 THEN '0000100007'                            -- Kueche Co (10%)
                    WHEN 5 THEN '0000100009'                            -- Nobilia (10%)
                    WHEN 6 THEN '0000100002'                            -- Saturn (10%)
                    WHEN 7 THEN '0000100004'                            -- Euronics (10%)
                    WHEN 8 THEN '0000100006'                            -- Otto (10%)
                    ELSE        '0000100008'                            -- Nolte (10%)
                END
            WHEN a.region_name = 'W_EUROPE' THEN
                CASE MOD(a.rn, 8)
                    WHEN 0 THEN '0000100020' WHEN 1 THEN '0000100020'  -- Fnac Darty (25%)
                    WHEN 2 THEN '0000100030'                            -- Currys (12.5%)
                    WHEN 3 THEN '0000100031'                            -- John Lewis (12.5%)
                    WHEN 4 THEN '0000100032'                            -- Amazon UK (12.5%)
                    WHEN 5 THEN '0000100050'                            -- Unieuro IT (12.5%)
                    WHEN 6 THEN '0000100041'                            -- Coolblue NL (12.5%)
                    ELSE        '0000100060'                            -- El Corte Inglés ES (12.5%)
                END
            WHEN a.region_name = 'E_EUROPE' THEN
                CASE MOD(a.rn, 4)
                    WHEN 0 THEN '0000100071' WHEN 1 THEN '0000100071'  -- RTV AGD PL (50%)
                    WHEN 2 THEN '0000100072'                            -- Alza.cz (25%)
                    ELSE        '0000100070'                            -- x-kom PL (25%)
                END
            WHEN a.region_name = 'N_AMERICA' THEN
                CASE MOD(a.rn, 5)
                    WHEN 0 THEN '0000100080' WHEN 1 THEN '0000100080'  -- Best Buy (40%)
                    WHEN 2 THEN '0000100082'                            -- Amazon US (20%)
                    WHEN 3 THEN '0000100081'                            -- Williams-Sonoma (20%)
                    ELSE        '0000100083'                            -- Home Depot (20%)
                END
            WHEN a.region_name = 'APAC' THEN
                CASE MOD(a.rn, 4)
                    WHEN 0 THEN '0000100090' WHEN 1 THEN '0000100090'  -- JD.com (50%)
                    WHEN 2 THEN '0000100091'                            -- Tmall (25%)
                    ELSE        '0000100093'                            -- Harvey Norman AU (25%)
                END
            ELSE   -- EMERGING
                CASE MOD(a.rn, 3)
                    WHEN 0 THEN '0000100100'                            -- Teknik Yapı TR (33%)
                    WHEN 1 THEN '0000100101'                            -- Fast Shop BR (33%)
                    ELSE        '0000100102'                            -- Croma IN (33%)
                END
        END AS cust_num

    FROM assigned a
    JOIN gl_types gl ON a.gl_idx = gl.gl_idx
)

-- ─── Final SELECT joining product dimension for denormalised columns ────────
SELECT
    'BSH'                                                        AS CLIENT_ID,
    CAST(e.fy * 1000 + e.fp AS NUMBER(38,0))                    AS MONTHYEAR,
    LPAD(CAST(e.fy AS VARCHAR) || LPAD(CAST(e.fp AS VARCHAR),3,'0'),7,'0') AS DATAENTRYPERIOD,
    e.fy                                                         AS FISCALYEAR,
    e.fp                                                         AS POSTINGPERIOD,
    LAST_DAY(e.period_date)                                      AS POSTINGDATE,
    e.hsl_amount                                                 AS HSL,
    'EUR'                                                        AS CURRENCY,
    '10'                                                         AS CURRENCYTYPE,
    e.racct                                                      AS ACDOCA_RACCT,
    e.pnl_cat                                                    AS PNL_CATEGORY,
    '0L'                                                         AS LEDGER,
    e.compcode                                                   AS COMPANYCODE,
    e.country_code                                               AS COUNTRY,
    e.country_code                                               AS COUNTRY_SOLD_TO,
    e.sales_org                                                  AS SALESORGANISATION,
    e.dist_ch                                                    AS DISTRIBUTIONCHANNEL,
    'BSH0'                                                       AS CONTROLLINGAREA,
    e.region_name                                                AS REGION,
    e.plant_code                                                 AS PLANT,
    e.func_area                                                  AS FUNCTIONALAREA,
    e.compcode || '-' || e.func_area                             AS COSTCENTER,
    e.cust_num                                                   AS CUSTOMER,
    -- Customer group from DIM_CUSTOMER (join on customer number)
    COALESCE(c.CUSTOMER_GROUP, '01')                             AS CUSTOMERGROUP,
    e.mat_code                                                   AS MATERIAL,
    COALESCE(p.PRODUCT_NAME, 'Bosch Serie 4 SMS4HVW31E')        AS PRODUCT_NAME,
    e.brand                                                      AS BRAND,
    e.category                                                   AS CATEGORY,
    COALESCE(p.SUBCATEGORY, 'Dishwasher Freestanding')          AS SUBCATEGORY,
    COALESCE(p.PRODUCT_TIER, 'MID')                             AS PRODUCT_TIER,
    e.brand                                                      AS CORPORATEBRAND,
    -- Units sold: revenue rows only, derived from amount / list price
    CASE WHEN e.racct = '0800000'
        THEN ROUND(ABS(e.hsl_amount) / NULLIF(COALESCE(p.LIST_PRICE_EUR, 500), 0), 0)
        ELSE NULL
    END                                                          AS SALESVOLUME,
    COALESCE(p.LIST_PRICE_EUR, 500.00)                          AS LIST_PRICE_EUR,
    'SO-' || LPAD(CAST(e.rn AS VARCHAR), 7, '0')               AS SALESORDER,
    CASE WHEN e.racct = '0820000' THEN 'G2' ELSE 'F2' END      AS BILLINGTYPE,
    '000'                                                        AS VERSION,
    '00'                                                         AS RECORDTYPE,
    CURRENT_TIMESTAMP()                                          AS LASTUPDATE_TS_REPORTING,
    DATEADD('minute', -MOD(e.rn, 120), CURRENT_TIMESTAMP())     AS CFIN_TS_DELTA

FROM enriched e
LEFT JOIN DIM_PRODUCT  p ON e.mat_code = p.MATERIAL
LEFT JOIN DIM_CUSTOMER c ON e.cust_num = c.CUSTOMER_NUMBER;

-- ─────────────────────────────────────────────────────────────────────────────
-- Quick sanity check
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'Total rows'   AS metric, COUNT(*) AS value FROM S3_FINANCE_PNL
UNION ALL
SELECT 'Brands',       COUNT(DISTINCT BRAND)    FROM S3_FINANCE_PNL
UNION ALL
SELECT 'Products',     COUNT(DISTINCT MATERIAL) FROM S3_FINANCE_PNL
UNION ALL
SELECT 'Customers',    COUNT(DISTINCT CUSTOMER) FROM S3_FINANCE_PNL
UNION ALL
SELECT 'Fiscal years', COUNT(DISTINCT FISCALYEAR) FROM S3_FINANCE_PNL;
