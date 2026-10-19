-- ==============================================================================
-- teardown_bdc_clds.sql — Remove Mounted BDC CLDs and L1 Views
--
-- Drops every L1 view registered in BDC_L1_VIEW_MAP, then every zzbdcL0_*
-- CLD database registered in BDC_PRODUCT_CATALOG. Views are dropped first
-- since they depend on the CLDs.
--
-- Does NOT:
--   - Drop the zero-copy connector itself
--   - Drop BDC_PRODUCT_CATALOG, BDC_L1_VIEW_MAP, or BDC_CLD_MOUNT_LOG
--   - Clear CONFIRMED_SHARE_NAME — re-running 13_bdc_mount_clds.sql after this
--     teardown will re-mount everything without needing to re-confirm shares
--   - Drop the L1 schema itself (in case other non-BDC views live there later)
--
-- Usage:
--   snow sql -f runbooks/teardown_bdc_clds.sql \
--     --connection my_snowflake \
--     --variable db_name=S4 \
--     --variable wh_name=SAP_BDC_PNL_WH
--   -- or --
--   make bdc-teardown
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

SELECT 'TEARDOWN: This will drop all mounted BDC CLDs and their L1 views.' AS warning,
       '<% db_name %>.L1 (views) and zzbdcL0_* (CLD databases)' AS target,
       'Review and confirm before running.' AS action;

-- -----------------------------------------------------------------------------
-- STEP 1: Drop L1 views (dependents first).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE TEARDOWN_BDC_L1_VIEWS()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    v_sql STRING;
BEGIN
    FOR rec IN (SELECT VIEW_NAME FROM BDC_L1_VIEW_MAP) DO
        BEGIN
            v_sql := 'DROP VIEW IF EXISTS L1.' || rec.VIEW_NAME;
            EXECUTE IMMEDIATE v_sql;

            UPDATE BDC_L1_VIEW_MAP
               SET MATCHED_TABLE_FQN = NULL, LAST_REFRESHED_AT = NULL
             WHERE VIEW_NAME = rec.VIEW_NAME;

            INSERT INTO BDC_CLD_MOUNT_LOG (STAGE, VIEW_NAME, STATUS, DETAIL)
            VALUES ('VIEW', rec.VIEW_NAME, 'DROPPED', 'L1.' || rec.VIEW_NAME || ' dropped by teardown.');
        EXCEPTION
            WHEN OTHER THEN
                INSERT INTO BDC_CLD_MOUNT_LOG (STAGE, VIEW_NAME, STATUS, DETAIL)
                VALUES ('VIEW', rec.VIEW_NAME, 'FAILED', SQLERRM);
        END;
    END FOR;
    RETURN 'L1 views dropped.';
END;
$$;

CALL TEARDOWN_BDC_L1_VIEWS();

-- -----------------------------------------------------------------------------
-- STEP 2: Drop CLD databases.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE TEARDOWN_BDC_CLDS()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    v_sql STRING;
BEGIN
    FOR rec IN (SELECT PRODUCT_KEY, CLD_DATABASE_NAME
                FROM BDC_PRODUCT_CATALOG
                WHERE CLD_DATABASE_NAME IS NOT NULL) DO
        BEGIN
            v_sql := 'DROP DATABASE IF EXISTS IDENTIFIER(''' || rec.CLD_DATABASE_NAME || ''')';
            EXECUTE IMMEDIATE v_sql;

            UPDATE BDC_PRODUCT_CATALOG
               SET CLD_DATABASE_NAME = NULL, LAST_MOUNTED_AT = NULL
             WHERE PRODUCT_KEY = rec.PRODUCT_KEY;

            INSERT INTO BDC_CLD_MOUNT_LOG (STAGE, PRODUCT_KEY, STATUS, DETAIL)
            VALUES ('CLD', rec.PRODUCT_KEY, 'DROPPED', rec.CLD_DATABASE_NAME || ' dropped by teardown.');
        EXCEPTION
            WHEN OTHER THEN
                INSERT INTO BDC_CLD_MOUNT_LOG (STAGE, PRODUCT_KEY, STATUS, DETAIL)
                VALUES ('CLD', rec.PRODUCT_KEY, 'FAILED', SQLERRM);
        END;
    END FOR;
    RETURN 'CLD databases dropped.';
END;
$$;

CALL TEARDOWN_BDC_CLDS();

SELECT * FROM BDC_CLD_MOUNT_LOG ORDER BY RAN_AT DESC LIMIT 40;

SELECT 'Teardown complete. CONFIRMED_SHARE_NAME values were preserved — ' ||
       're-run 13_bdc_mount_clds.sql to re-mount without re-confirming shares.' AS status;
