-- =============================================================================
-- 14_bdc_verify_clds.sql — Verify Mounted CLDs and L1 Views (read-only)
--
-- Run after 13_bdc_mount_clds.sql. Confirms:
--   1. Every planned CLD/view actually mounted/resolved (nothing silently skipped)
--   2. Every resolved L1 view returns at least one row
--   3. FK joins documented in runbooks/sap_bdc_lineage.md actually return rows
--      when joined against S3_FINANCE_PNL_MDR
--
-- This script makes NO changes — every statement is read-only. If any test
-- below shows FAIL or a warning, resolve it before pointing real gold-layer
-- SQL at these views.
--
-- Variables:
--   <% db_name %>  — target database (default: S4)
--   <% wh_name %>  — warehouse name (default: BSH_DEMO_WH)
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 1: Coverage — every product mounted? every view resolved?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT '1. CLD coverage' AS test,
       COUNT(*)                                              AS products_total,
       COUNT(CLD_DATABASE_NAME)                               AS clds_mounted,
       COUNT(*) - COUNT(CLD_DATABASE_NAME)                    AS products_not_yet_mountable,
       IFF(COUNT(*) = COUNT(CLD_DATABASE_NAME), 'PASS', 'INCOMPLETE — see row detail below') AS result
FROM BDC_PRODUCT_CATALOG;

SELECT PRODUCT_KEY, CONFIRMED_SHARE_NAME, CLD_DATABASE_NAME,
       IFF(CLD_DATABASE_NAME IS NULL,
           IFF(CONFIRMED_SHARE_NAME IS NULL, 'NOT CONFIRMED YET', 'CONFIRMED BUT NOT MOUNTED — run 13_bdc_mount_clds.sql'),
           'MOUNTED')
       AS status
FROM BDC_PRODUCT_CATALOG
ORDER BY PRODUCT_KEY;

SELECT '2. L1 view coverage' AS test,
       COUNT(*)                                       AS views_planned,
       COUNT(MATCHED_TABLE_FQN)                        AS views_resolved,
       COUNT(*) - COUNT(MATCHED_TABLE_FQN)             AS views_unresolved,
       IFF(COUNT(*) = COUNT(MATCHED_TABLE_FQN), 'PASS', 'INCOMPLETE — see row detail below') AS result
FROM BDC_L1_VIEW_MAP;

SELECT VIEW_NAME, PRODUCT_KEY, ROOT_ENTITY_PATTERN, MATCHED_TABLE_FQN,
       IFF(MATCHED_TABLE_FQN IS NULL, 'UNRESOLVED — check BDC_CLD_MOUNT_LOG for the SKIPPED/FAILED reason', 'RESOLVED') AS status
FROM BDC_L1_VIEW_MAP
ORDER BY VIEW_NAME;

-- Most recent SKIPPED/FAILED log entries, if any.
SELECT RAN_AT, STAGE, PRODUCT_KEY, VIEW_NAME, STATUS, DETAIL
FROM BDC_CLD_MOUNT_LOG
WHERE STATUS IN ('SKIPPED', 'FAILED')
ORDER BY RAN_AT DESC
LIMIT 50;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 3: Every resolved L1 view returns at least one row.
-- Built dynamically since view names vary — results land in a temp table.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE VERIFY_BDC_L1_VIEW_ROWCOUNTS()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    v_sql STRING;
    v_row_count INT;
BEGIN
    CREATE OR REPLACE TEMPORARY TABLE L1_VIEW_ROW_COUNTS (
        VIEW_NAME VARCHAR(60),
        ROW_COUNT INT,
        STATUS    VARCHAR(20)
    );

    FOR rec IN (SELECT VIEW_NAME FROM BDC_L1_VIEW_MAP WHERE MATCHED_TABLE_FQN IS NOT NULL) DO
        BEGIN
            v_sql := 'SELECT COUNT(*) AS CNT FROM L1.' || rec.VIEW_NAME;
            EXECUTE IMMEDIATE v_sql;
            SELECT CNT INTO :v_row_count FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

            INSERT INTO L1_VIEW_ROW_COUNTS (VIEW_NAME, ROW_COUNT, STATUS)
            VALUES (rec.VIEW_NAME, v_row_count, IFF(v_row_count > 0, 'PASS', 'FAIL — zero rows'));
        EXCEPTION
            WHEN OTHER THEN
                INSERT INTO L1_VIEW_ROW_COUNTS (VIEW_NAME, ROW_COUNT, STATUS)
                VALUES (rec.VIEW_NAME, NULL, 'FAIL — ' || SQLERRM);
        END;
    END FOR;

    RETURN 'Row-count check complete — see L1_VIEW_ROW_COUNTS.';
END;
$$;

CALL VERIFY_BDC_L1_VIEW_ROWCOUNTS();
SELECT '3. L1 view row counts' AS test, VIEW_NAME, ROW_COUNT, STATUS
FROM L1_VIEW_ROW_COUNTS
ORDER BY VIEW_NAME;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 4: FK join sanity checks against S3_FINANCE_PNL_MDR.
-- Only the unambiguous 1:1 joins documented in sap_bdc_lineage.md are
-- checked here. Product/Material and the two-hop SalesOrganization join are
-- intentionally excluded — see the lineage doc for why those need care.
-- Each check only runs if the underlying view has been resolved.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT '4a. CUSTOMER join' AS test,
       (SELECT COUNT(*) FROM L1.CUSTOMER c JOIN S3_FINANCE_PNL_MDR g ON g.CUSTOMER = c."Customer") AS matched_rows,
       IFF((SELECT COUNT(*) FROM L1.CUSTOMER c JOIN S3_FINANCE_PNL_MDR g ON g.CUSTOMER = c."Customer") > 0, 'PASS', 'FAIL — no matches, check join column names/casing') AS result
WHERE EXISTS (SELECT 1 FROM BDC_L1_VIEW_MAP WHERE VIEW_NAME = 'CUSTOMER' AND MATCHED_TABLE_FQN IS NOT NULL);

SELECT '4b. COST_CENTER join' AS test,
       (SELECT COUNT(*) FROM L1.COST_CENTER cc JOIN S3_FINANCE_PNL_MDR g ON g.COSTCENTER = cc."CostCenter" AND g.CONTROLLINGAREA = cc."ControllingArea") AS matched_rows,
       IFF((SELECT COUNT(*) FROM L1.COST_CENTER cc JOIN S3_FINANCE_PNL_MDR g ON g.COSTCENTER = cc."CostCenter" AND g.CONTROLLINGAREA = cc."ControllingArea") > 0, 'PASS', 'FAIL — no matches, check join column names/casing') AS result
WHERE EXISTS (SELECT 1 FROM BDC_L1_VIEW_MAP WHERE VIEW_NAME = 'COST_CENTER' AND MATCHED_TABLE_FQN IS NOT NULL);

SELECT '4c. PROFIT_CENTER join' AS test,
       (SELECT COUNT(*) FROM L1.PROFIT_CENTER pc JOIN S3_FINANCE_PNL_MDR g ON g.PARTNERPROFITCTR = pc."ProfitCenter" AND g.CONTROLLINGAREA = pc."ControllingArea") AS matched_rows,
       IFF((SELECT COUNT(*) FROM L1.PROFIT_CENTER pc JOIN S3_FINANCE_PNL_MDR g ON g.PARTNERPROFITCTR = pc."ProfitCenter" AND g.CONTROLLINGAREA = pc."ControllingArea") > 0, 'PASS', 'FAIL — no matches, check join column names/casing') AS result
WHERE EXISTS (SELECT 1 FROM BDC_L1_VIEW_MAP WHERE VIEW_NAME = 'PROFIT_CENTER' AND MATCHED_TABLE_FQN IS NOT NULL);

SELECT '4d. PLANT join' AS test,
       (SELECT COUNT(*) FROM L1.PLANT p JOIN S3_FINANCE_PNL_MDR g ON g.PLANT = p."Plant") AS matched_rows,
       IFF((SELECT COUNT(*) FROM L1.PLANT p JOIN S3_FINANCE_PNL_MDR g ON g.PLANT = p."Plant") > 0, 'PASS', 'FAIL — no matches, check join column names/casing') AS result
WHERE EXISTS (SELECT 1 FROM BDC_L1_VIEW_MAP WHERE VIEW_NAME = 'PLANT' AND MATCHED_TABLE_FQN IS NOT NULL);

SELECT '4e. FUNCTIONAL_AREA join' AS test,
       (SELECT COUNT(*) FROM L1.FUNCTIONAL_AREA fa JOIN S3_FINANCE_PNL_MDR g ON g.FUNCTIONALAREA = fa."FunctionalArea") AS matched_rows,
       IFF((SELECT COUNT(*) FROM L1.FUNCTIONAL_AREA fa JOIN S3_FINANCE_PNL_MDR g ON g.FUNCTIONALAREA = fa."FunctionalArea") > 0, 'PASS', 'FAIL — no matches, check join column names/casing') AS result
WHERE EXISTS (SELECT 1 FROM BDC_L1_VIEW_MAP WHERE VIEW_NAME = 'FUNCTIONAL_AREA' AND MATCHED_TABLE_FQN IS NOT NULL);

SELECT '4f. GL_ACCOUNT join' AS test,
       (SELECT COUNT(*) FROM L1.GL_ACCOUNT gl JOIN S3_FINANCE_PNL_MDR g ON g.ACDOCA_RACCT = gl."GLAccount") AS matched_rows,
       IFF((SELECT COUNT(*) FROM L1.GL_ACCOUNT gl JOIN S3_FINANCE_PNL_MDR g ON g.ACDOCA_RACCT = gl."GLAccount") > 0, 'PASS', 'FAIL — no matches, check join column names/casing') AS result
WHERE EXISTS (SELECT 1 FROM BDC_L1_VIEW_MAP WHERE VIEW_NAME = 'GL_ACCOUNT' AND MATCHED_TABLE_FQN IS NOT NULL);

SELECT '4g. CONTROLLING_AREA join' AS test,
       (SELECT COUNT(*) FROM L1.CONTROLLING_AREA ca JOIN S3_FINANCE_PNL_MDR g ON g.CONTROLLINGAREA = ca."ControllingArea") AS matched_rows,
       IFF((SELECT COUNT(*) FROM L1.CONTROLLING_AREA ca JOIN S3_FINANCE_PNL_MDR g ON g.CONTROLLINGAREA = ca."ControllingArea") > 0, 'PASS', 'FAIL — no matches, check join column names/casing') AS result
WHERE EXISTS (SELECT 1 FROM BDC_L1_VIEW_MAP WHERE VIEW_NAME = 'CONTROLLING_AREA' AND MATCHED_TABLE_FQN IS NOT NULL);

SELECT 'Note: PRODUCT/MATERIAL and the two-hop SALES_ORGANIZATION/DISTRIBUTION_CHANNEL joins are intentionally not checked here — see Section 4 (join keys) of sap_bdc_lineage.md before wiring those into gold-layer SQL.' AS reminder;
