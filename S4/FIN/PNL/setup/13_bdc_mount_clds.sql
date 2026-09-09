-- =============================================================================
-- 13_bdc_mount_clds.sql — Mount CLDs and Create L1 Views
--
-- Two-phase, idempotent mount:
--   Phase 1 (MOUNT_BDC_CLDS)     — for every product with a CONFIRMED_SHARE_NAME,
--                                   CREATE DATABASE zzbdcL0_<PRODUCT_KEY>
--                                   LINKED_ZEROCOPY_CONNECTOR if it doesn't exist yet.
--   Phase 2 (CREATE_BDC_L1_VIEWS) — for every mounted product, resolve its root
--                                   entity table inside the CLD and
--                                   CREATE OR REPLACE VIEW L1.<VIEW_NAME> on top of it.
--
-- Every action (created / already-exists / skipped / failed) is logged to
-- BDC_CLD_MOUNT_LOG — nothing here fails silently. A "SKIPPED" row for a view
-- means the mount script found zero or more than one candidate table inside
-- the CLD and refused to guess; resolve that one manually (see
-- 14_bdc_verify_clds.sql for how to spot these).
--
-- Both stored procedures were syntax-validated via compile-only execution
-- against a live Snowflake account before being written here, but this file
-- has NOT been run end-to-end against a real BDC-connected connector — there
-- is no way to do that without one. Treat the first real run as a test run:
-- check BDC_CLD_MOUNT_LOG carefully afterward.
--
-- Variables:
--   <% db_name %>        — target database (default: S4)
--   <% wh_name %>        — warehouse name (default: BSH_DEMO_WH)
--   <% connector_fqn %>  — fully-qualified zero-copy connector name,
--                          e.g. SAP_BDC_DB.SAP_SCHEMA.SAP_CONNECTOR
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- PHASE 1: Mount CLDs for every product with a confirmed share name.
-- Naming convention: zzbdcL0_<PRODUCT_KEY> (deterministic, always this pattern).
-- Safe to re-run: skips (and logs ALREADY_EXISTS) any CLD that already exists.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE MOUNT_BDC_CLDS(CONNECTOR_FQN STRING)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    v_cld_name STRING;
    v_sql STRING;
    v_exists_count INT;
BEGIN
    FOR rec IN (SELECT PRODUCT_KEY, CONFIRMED_SHARE_NAME
                FROM BDC_PRODUCT_CATALOG
                WHERE CONFIRMED_SHARE_NAME IS NOT NULL) DO

        v_cld_name := 'ZZBDCL0_' || rec.PRODUCT_KEY;

        -- Idempotency check: does this CLD database already exist?
        SHOW DATABASES LIKE :v_cld_name;
        SELECT COUNT(*) INTO :v_exists_count FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

        IF (v_exists_count > 0) THEN
            UPDATE BDC_PRODUCT_CATALOG
               SET CLD_DATABASE_NAME = v_cld_name
             WHERE PRODUCT_KEY = rec.PRODUCT_KEY
               AND CLD_DATABASE_NAME IS NULL;

            INSERT INTO BDC_CLD_MOUNT_LOG (STAGE, PRODUCT_KEY, STATUS, DETAIL)
            VALUES ('CLD', rec.PRODUCT_KEY, 'ALREADY_EXISTS', v_cld_name || ' already exists — skipped.');
            CONTINUE;
        END IF;

        BEGIN
            v_sql := 'CREATE DATABASE IDENTIFIER(''' || v_cld_name || ''') ' ||
                     'LINKED_ZEROCOPY_CONNECTOR = (CONNECTOR_NAME => ''' || :CONNECTOR_FQN || ''', ' ||
                     'SHARE_NAME => ''' || REPLACE(rec.CONFIRMED_SHARE_NAME, '''', '''''') || ''', ' ||
                     'SYNC_INTERVAL_SECONDS => 86400)';
            EXECUTE IMMEDIATE v_sql;

            UPDATE BDC_PRODUCT_CATALOG
               SET CLD_DATABASE_NAME = v_cld_name,
                   LAST_MOUNTED_AT = CURRENT_TIMESTAMP()
             WHERE PRODUCT_KEY = rec.PRODUCT_KEY;

            INSERT INTO BDC_CLD_MOUNT_LOG (STAGE, PRODUCT_KEY, STATUS, DETAIL)
            VALUES ('CLD', rec.PRODUCT_KEY, 'CREATED',
                    v_cld_name || ' mounted from share: ' || rec.CONFIRMED_SHARE_NAME);
        EXCEPTION
            WHEN OTHER THEN
                INSERT INTO BDC_CLD_MOUNT_LOG (STAGE, PRODUCT_KEY, STATUS, DETAIL)
                VALUES ('CLD', rec.PRODUCT_KEY, 'FAILED', SQLERRM);
        END;
    END FOR;

    RETURN 'CLD mount phase complete — see BDC_CLD_MOUNT_LOG for per-product results.';
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PHASE 2: Create/refresh L1 views for every planned view whose product is
-- mounted. Only acts when exactly one candidate table is found inside the
-- CLD matching ROOT_ENTITY_PATTERN — an exact (case-insensitive) match is
-- tried first via SHOW TABLES LIKE; ambiguous or missing matches are logged
-- as SKIPPED rather than guessed.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE CREATE_BDC_L1_VIEWS()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    v_cld_name STRING;
    v_pattern STRING;
    v_match_count INT;
    v_matched_table STRING;
    v_sql STRING;
BEGIN
    FOR rec IN (
        SELECT m.VIEW_NAME, m.ROOT_ENTITY_PATTERN, c.PRODUCT_KEY, c.CLD_DATABASE_NAME
        FROM BDC_L1_VIEW_MAP m
        JOIN BDC_PRODUCT_CATALOG c ON c.PRODUCT_KEY = m.PRODUCT_KEY
        WHERE c.CLD_DATABASE_NAME IS NOT NULL
    ) DO
        v_cld_name := rec.CLD_DATABASE_NAME;
        v_pattern := rec.ROOT_ENTITY_PATTERN;

        -- SHOW ... LIKE is case-insensitive and exact by default (no % needed
        -- for an exact entity name) — this is deliberately an exact-match
        -- attempt first, since several CLDs bundle similarly-named tables
        -- (e.g. CostCenter, CostCenterCategory, CostCenterHierarchy all live
        -- in the same CostCenter CLD).
        SHOW TABLES LIKE :v_pattern IN DATABASE IDENTIFIER(:v_cld_name);
        SELECT COUNT(*), MAX("schema_name" || '.' || "name")
          INTO :v_match_count, :v_matched_table
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

        IF (v_match_count <> 1) THEN
            INSERT INTO BDC_CLD_MOUNT_LOG (STAGE, PRODUCT_KEY, VIEW_NAME, STATUS, DETAIL)
            VALUES ('VIEW', rec.PRODUCT_KEY, rec.VIEW_NAME, 'SKIPPED',
                    'Expected exactly one table named ' || v_pattern || ' in ' || v_cld_name ||
                    ', found ' || v_match_count || '. Resolve manually: SHOW TABLES IN DATABASE ' ||
                    v_cld_name || ', then CREATE OR REPLACE VIEW L1.' || rec.VIEW_NAME ||
                    ' AS SELECT * FROM <the right table>.');
            CONTINUE;
        END IF;

        BEGIN
            v_sql := 'CREATE OR REPLACE VIEW L1.' || rec.VIEW_NAME ||
                     ' AS SELECT * FROM IDENTIFIER(''' || v_cld_name || '.' || v_matched_table || ''')';
            EXECUTE IMMEDIATE v_sql;

            UPDATE BDC_L1_VIEW_MAP
               SET MATCHED_TABLE_FQN = v_cld_name || '.' || v_matched_table,
                   LAST_REFRESHED_AT = CURRENT_TIMESTAMP()
             WHERE VIEW_NAME = rec.VIEW_NAME;

            INSERT INTO BDC_CLD_MOUNT_LOG (STAGE, PRODUCT_KEY, VIEW_NAME, STATUS, DETAIL)
            VALUES ('VIEW', rec.PRODUCT_KEY, rec.VIEW_NAME, 'CREATED',
                    'L1.' || rec.VIEW_NAME || ' -> ' || v_cld_name || '.' || v_matched_table);
        EXCEPTION
            WHEN OTHER THEN
                INSERT INTO BDC_CLD_MOUNT_LOG (STAGE, PRODUCT_KEY, VIEW_NAME, STATUS, DETAIL)
                VALUES ('VIEW', rec.PRODUCT_KEY, rec.VIEW_NAME, 'FAILED', SQLERRM);
        END;
    END FOR;

    RETURN 'L1 view phase complete — see BDC_CLD_MOUNT_LOG for per-view results.';
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Driver: run both phases, then show what happened.
-- ─────────────────────────────────────────────────────────────────────────────
CALL MOUNT_BDC_CLDS('<% connector_fqn %>');
CALL CREATE_BDC_L1_VIEWS();

SELECT * FROM BDC_CLD_MOUNT_LOG ORDER BY RAN_AT DESC;

SELECT
    (SELECT COUNT(*) FROM BDC_PRODUCT_CATALOG WHERE CLD_DATABASE_NAME IS NOT NULL) AS clds_mounted,
    (SELECT COUNT(*) FROM BDC_PRODUCT_CATALOG WHERE CONFIRMED_SHARE_NAME IS NOT NULL) AS shares_confirmed,
    (SELECT COUNT(*) FROM BDC_L1_VIEW_MAP WHERE MATCHED_TABLE_FQN IS NOT NULL) AS views_created,
    (SELECT COUNT(*) FROM BDC_L1_VIEW_MAP) AS views_planned;
