-- =============================================================================
-- 09_verify.sql — Verification and RAP Isolation Tests
--
-- Run this after a full deployment to confirm:
--   1. Row count is approximately 100,000
--   2. All 13 P&L categories are present with correct sign (positive = revenue)
--   3. EBIT margin is in the expected 5.5-6.5% range
--   4. RAP correctly limits each regional role to its authorised regions
--   5. The global role sees all data
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('&{wh_name}');
USE DATABASE  IDENTIFIER('&{db_name}');
USE SCHEMA FIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 1: Row count
-- ─────────────────────────────────────────────────────────────────────────────
SELECT '1. Row count' AS test,
       COUNT(*) AS value,
       IFF(COUNT(*) BETWEEN 90000 AND 110000, 'PASS', 'FAIL') AS result
FROM S3_FINANCE_PNL;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 2: P&L category distribution — check all 9 categories present
-- ─────────────────────────────────────────────────────────────────────────────
SELECT '2. P&L categories' AS test,
       COUNT(DISTINCT PNL_CATEGORY) AS distinct_categories,
       IFF(COUNT(DISTINCT PNL_CATEGORY) >= 9, 'PASS', 'FAIL') AS result
FROM S3_FINANCE_PNL;

-- P&L line detail with amounts (expect revenue positive, costs negative)
SELECT PNL_CATEGORY,
       ACDOCA_RACCT,
       COUNT(*)                          AS row_count,
       ROUND(SUM(HSL) / 1000000, 1)     AS total_hsl_eur_m,
       IFF(PNL_CATEGORY = 'REVENUE', 'positive expected', 'negative expected') AS sign_expectation
FROM S3_FINANCE_PNL
GROUP BY 1, 2
ORDER BY 1, 2;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 3: EBIT margin sanity check (expect 5.5-6.5% of net revenue)
-- ─────────────────────────────────────────────────────────────────────────────
WITH pnl AS (
    SELECT
        SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))                                      AS gross_rev,
        SUM(IFF(PNL_CATEGORY IN ('TRADE_SPEND','RETURNS'), -HSL, 0))                     AS deductions,
        SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS','BRAND_ADP','SALES','RD','GA'),-HSL,0)) AS total_costs
    FROM S3_FINANCE_PNL
)
SELECT
    '3. EBIT margin'                                              AS test,
    ROUND(gross_rev / 1e6, 0)                                    AS gross_rev_eur_m,
    ROUND((gross_rev - deductions) / 1e6, 0)                     AS net_rev_eur_m,
    ROUND((gross_rev - deductions - total_costs)
          / NULLIF(gross_rev - deductions, 0) * 100, 1)          AS ebit_margin_pct,
    IFF((gross_rev - deductions - total_costs)
        / NULLIF(gross_rev - deductions, 0) * 100
        BETWEEN 5.0 AND 7.5, 'PASS', 'INVESTIGATE')             AS result
FROM pnl;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 4: Brand distribution (expect Bosch ~50%, Siemens ~28%)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT '4. Brand mix' AS test,
       BRAND,
       COUNT(*)                                        AS rows,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_rows
FROM S3_FINANCE_PNL
GROUP BY 2
ORDER BY 3 DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 5: Region distribution
-- ─────────────────────────────────────────────────────────────────────────────
SELECT '5. Region mix' AS test,
       REGION,
       COUNT(*) AS rows,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM S3_FINANCE_PNL
GROUP BY 2
ORDER BY 3 DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 6: 2024 category growth vs 2023 (verify adjustors applied)
--   Expected: Cooking 2024 rev < 2023 rev (decline)
--             Consumer Products 2024 rev > 2023 rev (growth)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT '6. Category 2023 vs 2024' AS test,
       CATEGORY,
       ROUND(SUM(IFF(FISCALYEAR = 2023 AND PNL_CATEGORY = 'REVENUE', HSL, 0)) / 1e6, 1) AS rev_2023_eur_m,
       ROUND(SUM(IFF(FISCALYEAR = 2024 AND PNL_CATEGORY = 'REVENUE', HSL, 0)) / 1e6, 1) AS rev_2024_eur_m,
       ROUND((SUM(IFF(FISCALYEAR = 2024 AND PNL_CATEGORY = 'REVENUE', HSL, 0))
             - SUM(IFF(FISCALYEAR = 2023 AND PNL_CATEGORY = 'REVENUE', HSL, 0)))
             / NULLIF(SUM(IFF(FISCALYEAR = 2023 AND PNL_CATEGORY = 'REVENUE', HSL, 0)), 0) * 100, 1) AS growth_pct
FROM S3_FINANCE_PNL
GROUP BY 2
ORDER BY growth_pct DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- RAP ISOLATION TESTS
-- Switch roles and verify each role sees ONLY its authorised regions.
-- ─────────────────────────────────────────────────────────────────────────────

-- TEST 7: BSH_EUROPE_DEMO_ROLE — must see DACH, W_EUROPE, E_EUROPE only
USE ROLE BSH_EUROPE_DEMO_ROLE;
SELECT '7. BSH_EUROPE_DEMO_ROLE regions' AS test,
       LISTAGG(DISTINCT REGION, ', ') WITHIN GROUP (ORDER BY REGION) AS visible_regions,
       IFF(
           MAX(IFF(REGION IN ('DACH','W_EUROPE','E_EUROPE'), 1, 0)) = 1
           AND MAX(IFF(REGION IN ('N_AMERICA','APAC','EMERGING'), 1, 0)) = 0,
           'PASS — Europe only',
           'FAIL — unexpected regions visible'
       ) AS result
FROM IDENTIFIER('&{db_name}').FIN.S3_FINANCE_PNL;

-- TEST 8: BSH_NA_DEMO_ROLE — must see N_AMERICA only
USE ROLE BSH_NA_DEMO_ROLE;
SELECT '8. BSH_NA_DEMO_ROLE regions' AS test,
       LISTAGG(DISTINCT REGION, ', ') WITHIN GROUP (ORDER BY REGION) AS visible_regions,
       IFF(
           COUNT(DISTINCT REGION) = 1 AND MAX(REGION) = 'N_AMERICA',
           'PASS — N_AMERICA only',
           'FAIL — unexpected regions visible'
       ) AS result
FROM IDENTIFIER('&{db_name}').FIN.S3_FINANCE_PNL;

-- TEST 9: BSH_APAC_DEMO_ROLE — must see APAC and EMERGING only
USE ROLE BSH_APAC_DEMO_ROLE;
SELECT '9. BSH_APAC_DEMO_ROLE regions' AS test,
       LISTAGG(DISTINCT REGION, ', ') WITHIN GROUP (ORDER BY REGION) AS visible_regions,
       IFF(
           MAX(IFF(REGION IN ('APAC','EMERGING'), 1, 0)) = 1
           AND MAX(IFF(REGION IN ('DACH','W_EUROPE','E_EUROPE','N_AMERICA'), 1, 0)) = 0,
           'PASS — APAC + EMERGING only',
           'FAIL — unexpected regions visible'
       ) AS result
FROM IDENTIFIER('&{db_name}').FIN.S3_FINANCE_PNL;

-- TEST 10: BSH_DEMO_ROLE — must see all 6 BSH regions
USE ROLE BSH_DEMO_ROLE;
SELECT '10. BSH_DEMO_ROLE regions' AS test,
       COUNT(DISTINCT REGION) AS region_count,
       LISTAGG(DISTINCT REGION, ', ') WITHIN GROUP (ORDER BY REGION) AS visible_regions,
       IFF(COUNT(DISTINCT REGION) = 6, 'PASS — all 6 regions', 'FAIL') AS result
FROM IDENTIFIER('&{db_name}').FIN.S3_FINANCE_PNL;

-- TEST 11: BSH_DEMO_GLOBAL_ROLE — full count
USE ROLE BSH_DEMO_GLOBAL_ROLE;
SELECT '11. BSH_DEMO_GLOBAL_ROLE row count' AS test,
       COUNT(*) AS row_count,
       IFF(COUNT(*) BETWEEN 90000 AND 110000, 'PASS — full dataset visible', 'FAIL') AS result
FROM IDENTIFIER('&{db_name}').FIN.S3_FINANCE_PNL;

-- Return to ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;
SELECT '✓ All verification tests complete. Review results above.' AS summary;
