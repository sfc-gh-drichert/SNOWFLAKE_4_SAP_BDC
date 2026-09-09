-- =============================================================================
-- 12_bdc_discover_shares.sql — Discover SAP BDC Shares (read-only)
--
-- Lists every data product currently shared with the given zero-copy
-- connector and fuzzy-matches them against BDC_PRODUCT_CATALOG so a human
-- can identify the exact share_name for each of the 14 products this gold
-- layer needs.
--
-- This script creates NO databases and NO CLDs. It only reads connector
-- state and prints suggestions. After reviewing the output, confirm each
-- match with runbooks/bdc_confirm_share.sql (or the GitHub Actions
-- 'confirm' action) before running 13_bdc_mount_clds.sql.
--
-- Prerequisite: a CONNECTED zero-copy connector to SAP BDC must already
-- exist in this account, and someone with SAP BDC catalog-admin rights
-- must have shared the relevant data products to this Snowflake account
-- from the BDC catalog. This script cannot trigger that share from here —
-- see the "No shares found" message below for the exact steps on the SAP side.
--
-- Variables:
--   <% db_name %>        — target database (default: S4)
--   <% connector_fqn %>  — fully-qualified zero-copy connector name,
--                          e.g. SAP_BDC_DB.SAP_SCHEMA.SAP_CONNECTOR
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

-- -----------------------------------------------------------------------------
-- STEP 1: Confirm the connector is CONNECTED before attempting discovery.
-- This does not hard-fail the script (snow sql runs statements sequentially
-- regardless), but the status is printed clearly for a human to check before
-- proceeding to the next steps.
-- -----------------------------------------------------------------------------
DESC ZEROCOPY CONNECTOR IDENTIFIER('<% connector_fqn %>');

SELECT
    "name"  AS connector_name,
    "state" AS connector_state,
    IFF("state" = 'CONNECTED',
        'OK — proceeding with discovery.',
        'WARNING: connector is not CONNECTED. Resolve this first — see the manage-zerocopy-sapbdc skill troubleshoot guide.'
    ) AS connector_status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- -----------------------------------------------------------------------------
-- STEP 2: List every share currently available on this connector.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TEMPORARY TABLE BDC_AVAILABLE_SHARES AS
WITH raw AS (
    SELECT PARSE_JSON(
        SYSTEM$ZEROCOPY_CONNECTOR_LIST_SHARES('<% connector_fqn %>')
    ) AS json_data
)
SELECT
    f.value:name::STRING         AS share_name,
    f.value:id::STRING           AS share_id,
    f.value:display_name::STRING AS display_name,
    f.value:comment::STRING      AS description
FROM raw,
LATERAL FLATTEN(INPUT => json_data) f;

-- If nothing has been shared yet, tell the user exactly what to do on the SAP side.
SELECT
    CASE WHEN COUNT(*) = 0 THEN
        'No data products have been shared with this connector yet. ' ||
        'In SAP BDC: open the central Business Data Cloud catalog, use Catalog & Marketplace to find each of the 14 products in BDC_PRODUCT_CATALOG, ' ||
        'select "Share", choose this Snowflake account as the Target System, and select "Update". ' ||
        'Requires SAP BDC roles: BDC Data Packages (read), Catalog Asset (read), Cloud Data Product (share). ' ||
        'Re-run this script after sharing. See: https://help.sap.com/docs/business-data-cloud/sap-business-data-cloud-connect/sharing-data-products-from-sap-business-data-cloud-trough-sap-bdc-connect'
    ELSE
        COUNT(*) || ' data product(s) currently shared with this connector.'
    END AS share_discovery_status
FROM BDC_AVAILABLE_SHARES;

-- -----------------------------------------------------------------------------
-- STEP 3: Fuzzy-match available shares against the 14 products this gold
-- layer needs. This is a SUGGESTION ONLY — SAP share display names include
-- tenant-specific technical suffixes (e.g. "Sales Order (BDF730,
-- sap.s4pce:apiResource:SalesOrder:v1)") that cannot be predicted from the
-- CSN alone. Review every row below before confirming.
-- -----------------------------------------------------------------------------
SELECT
    c.PRODUCT_KEY,
    c.SUGGESTED_SHARE_PATTERN,
    s.share_name          AS suggested_share_name,
    s.display_name,
    s.description,
    IFF(c.CONFIRMED_SHARE_NAME IS NOT NULL,
        'ALREADY CONFIRMED: ' || c.CONFIRMED_SHARE_NAME,
        'NOT YET CONFIRMED — review suggestion above, then run bdc_confirm_share.sql'
    ) AS confirmation_status
FROM BDC_PRODUCT_CATALOG c
LEFT JOIN BDC_AVAILABLE_SHARES s
    ON s.display_name ILIKE c.SUGGESTED_SHARE_PATTERN
ORDER BY c.PRODUCT_KEY, s.display_name;

-- Full raw list too, in case a product's real display name doesn't resemble
-- its CSN entity name closely enough for the pattern above to catch it.
SELECT * FROM BDC_AVAILABLE_SHARES ORDER BY display_name;

-- -----------------------------------------------------------------------------
-- STEP 4: Anything still unconfirmed after reviewing the above.
-- -----------------------------------------------------------------------------
SELECT PRODUCT_KEY, SUGGESTED_SHARE_PATTERN
FROM BDC_PRODUCT_CATALOG
WHERE CONFIRMED_SHARE_NAME IS NULL
ORDER BY PRODUCT_KEY;
