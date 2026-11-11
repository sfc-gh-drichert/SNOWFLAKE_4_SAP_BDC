-- ==============================================================================
-- bdc_confirm_share.sql — Confirm a Real SAP BDC Share Name
--
-- Records the exact share_name a human confirmed after reviewing the output
-- of setup/12_bdc_discover_shares.sql. Run once per product you're ready to
-- mount. This is the ONLY place CONFIRMED_SHARE_NAME gets written — no
-- script auto-confirms a fuzzy match.
--
-- Variables:
--   <% db_name %>      — target database (default: S4)
--   <% product_key %>  — one of the PRODUCT_KEY values in BDC_PRODUCT_CATALOG
--                         (e.g. CUSTOMER, COST_CENTER, ENTRY_VIEW_JOURNAL_ENTRY)
--   <% share_name %>   — the exact share_name string from the discovery output
--
-- Usage:
--   snow sql -f runbooks/bdc_confirm_share.sql \
--     --connection my_snowflake \
--     --variable db_name=S4 \
--     --variable product_key=CUSTOMER \
--     --variable share_name="Customer (BDF730, sap.s4com:apiResource:Customer:v1)"
--   -- or --
--   make bdc-confirm PRODUCT_KEY=CUSTOMER SHARE_NAME="Customer (...)"
--
-- CAUTION: if the real share_name contains a single quote ('), escape it by
-- doubling it (e.g. O'Brien -> O''Brien) before passing --variable share_name,
-- since it is inlined directly into a quoted SQL string literal.
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

UPDATE BDC_PRODUCT_CATALOG
SET CONFIRMED_SHARE_NAME = '<% share_name %>'
WHERE PRODUCT_KEY = '<% product_key %>';

SELECT PRODUCT_KEY, CONFIRMED_SHARE_NAME, CLD_DATABASE_NAME, LAST_MOUNTED_AT
FROM BDC_PRODUCT_CATALOG
WHERE PRODUCT_KEY = '<% product_key %>';

-- Remaining unconfirmed products, for convenience.
SELECT PRODUCT_KEY, SUGGESTED_SHARE_PATTERN
FROM BDC_PRODUCT_CATALOG
WHERE CONFIRMED_SHARE_NAME IS NULL
ORDER BY PRODUCT_KEY;
