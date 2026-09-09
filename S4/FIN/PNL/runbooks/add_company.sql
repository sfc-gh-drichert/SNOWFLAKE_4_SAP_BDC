-- =============================================================================
-- add_company.sql — Onboard a New Demo Company
--
-- Run this to add a completely new company dataset alongside BSH in the
-- shared S3_FINANCE_PNL table. Zero DDL changes required to the base table,
-- Semantic View, or Row Access Policy.
--
-- Variable (passed by make add-company or snow sql --variable):
--   &{company_id}  — company identifier (e.g. HENKEL, BAYER, MIELE)
--
-- Usage:
--   snow sql -f runbooks/add_company.sql \
--     --connection EU_DEMO47 \
--     --variable db_name=S4 \
--     --variable company_id=HENKEL
--   -- or --
--   make add-company COMPANY=HENKEL
--
-- After running this script:
--   1. A new role <COMPANY>_DEMO_ROLE exists with full access to that company
--   2. The role mapping row is registered in ROLE_ACCESS_MAPPING
--   3. You can load company-specific data rows with CLIENT_ID='&{company_id}'
--   4. Create a company-specific agent pointing to BSH_PNL_ANALYTICS_SV
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('&{wh_name}');
USE DATABASE  IDENTIFIER('&{db_name}');
USE SCHEMA FIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Create company demo role
-- ─────────────────────────────────────────────────────────────────────────────
CREATE ROLE IF NOT EXISTS IDENTIFIER('&{company_id}_DEMO_ROLE')
    COMMENT = 'Demo role for &{company_id} — full access to all &{company_id} regions';

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Grant object access
-- ─────────────────────────────────────────────────────────────────────────────
GRANT USAGE ON WAREHOUSE IDENTIFIER('&{wh_name}')         TO ROLE IDENTIFIER('&{company_id}_DEMO_ROLE');
GRANT USAGE ON DATABASE  IDENTIFIER('&{db_name}')          TO ROLE IDENTIFIER('&{company_id}_DEMO_ROLE');
GRANT USAGE ON SCHEMA    IDENTIFIER('&{db_name}').FIN      TO ROLE IDENTIFIER('&{company_id}_DEMO_ROLE');
GRANT SELECT ON TABLE    IDENTIFIER('&{db_name}').FIN.S3_FINANCE_PNL     TO ROLE IDENTIFIER('&{company_id}_DEMO_ROLE');
GRANT SELECT ON TABLE    IDENTIFIER('&{db_name}').FIN.BSH_DOCUMENTS      TO ROLE IDENTIFIER('&{company_id}_DEMO_ROLE');
GRANT SELECT ON TABLE    IDENTIFIER('&{db_name}').FIN.DIM_GL_ACCOUNT     TO ROLE IDENTIFIER('&{company_id}_DEMO_ROLE');
GRANT SELECT ON TABLE    IDENTIFIER('&{db_name}').FIN.DIM_PRODUCT        TO ROLE IDENTIFIER('&{company_id}_DEMO_ROLE');
GRANT SELECT ON TABLE    IDENTIFIER('&{db_name}').FIN.DIM_CUSTOMER       TO ROLE IDENTIFIER('&{company_id}_DEMO_ROLE');
GRANT SELECT ON SEMANTIC VIEW IDENTIFIER('&{db_name}').FIN.BSH_PNL_ANALYTICS_SV TO ROLE IDENTIFIER('&{company_id}_DEMO_ROLE');
GRANT USAGE ON CORTEX AGENT   IDENTIFIER('&{db_name}').FIN.BSH_PNL_AGENT        TO ROLE IDENTIFIER('&{company_id}_DEMO_ROLE');

-- Add new role to global hierarchy
GRANT ROLE IDENTIFIER('&{company_id}_DEMO_ROLE') TO ROLE BSH_DEMO_GLOBAL_ROLE;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Register in ROLE_ACCESS_MAPPING
-- This is the ONLY change needed to the access control layer.
-- NULL for ALLOWED_REGION means the role can see all regions for this client.
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO IDENTIFIER('&{db_name}').FIN.ROLE_ACCESS_MAPPING
    (ROLE_NAME, ALLOWED_CLIENT, ALLOWED_REGION, DESCRIPTION)
SELECT
    '&{company_id}_DEMO_ROLE',
    '&{company_id}',
    NULL,
    'Full access to all &{company_id} regions. Created via add_company.sql.'
WHERE NOT EXISTS (
    SELECT 1 FROM IDENTIFIER('&{db_name}').FIN.ROLE_ACCESS_MAPPING
    WHERE ROLE_NAME = '&{company_id}_DEMO_ROLE'
      AND ALLOWED_CLIENT = '&{company_id}'
      AND ALLOWED_REGION IS NULL
);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Confirmation
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'Role &{company_id}_DEMO_ROLE registered.' AS status,
       '  → Load data: INSERT INTO S3_FINANCE_PNL ... WHERE CLIENT_ID = ''&{company_id}''' AS next_step_1,
       '  → Test RAP:  USE ROLE &{company_id}_DEMO_ROLE; SELECT DISTINCT REGION ...' AS next_step_2,
       '  → Agent:     CREATE CORTEX AGENT &{company_id}_PNL_AGENT ...' AS next_step_3;

-- Verify the mapping row was inserted
SELECT ROLE_NAME, ALLOWED_CLIENT, ALLOWED_REGION, DESCRIPTION
FROM IDENTIFIER('&{db_name}').FIN.ROLE_ACCESS_MAPPING
WHERE ROLE_NAME = '&{company_id}_DEMO_ROLE';
