-- ==============================================================================
-- add_company.sql - Onboard a New Demo Company
--
-- Adds a new company to the shared S3_FINANCE_PNL table with full data isolation.
-- Zero DDL changes required to the base table, Semantic View, or Row Access Policy.
--
-- Variables:
--   <% company_id %>  - company identifier (e.g. HENKEL, BAYER, MIELE)
--   <% db_name %>     - target database (default: S4)
--   <% wh_name %>     - warehouse name (default: SAP_BDC_PNL_WH)
--
-- Usage:
--   snow sql -f runbooks/add_company.sql \
--     --connection my_snowflake \
--     --variable db_name=S4 \
--     --variable wh_name=SAP_BDC_PNL_WH \
--     --variable company_id=HENKEL
--   -- or --
--   make add-company COMPANY=HENKEL
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

-- ==============================================================================
-- STEP 1: Create company demo role
-- Note: IDENTIFIER() is not supported in CREATE ROLE — the name is inlined directly.
-- The template variable <% company_id %> is substituted before SQL execution.
-- ==============================================================================
CREATE ROLE IF NOT EXISTS <% company_id %>_DEMO_ROLE
    COMMENT = 'Demo role for <% company_id %>. Full access to all <% company_id %> regions.';

-- ==============================================================================
-- STEP 2: Grant object access
-- IDENTIFIER() is supported in GRANT TO ROLE statements.
-- ==============================================================================
GRANT USAGE ON WAREHOUSE IDENTIFIER('<% wh_name %>')
    TO ROLE IDENTIFIER('<% company_id %>_DEMO_ROLE');
GRANT USAGE ON DATABASE  IDENTIFIER('<% db_name %>')
    TO ROLE IDENTIFIER('<% company_id %>_DEMO_ROLE');
GRANT USAGE ON SCHEMA    IDENTIFIER('<% db_name %>.FIN')
    TO ROLE IDENTIFIER('<% company_id %>_DEMO_ROLE');
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.S3_FINANCE_PNL')
    TO ROLE IDENTIFIER('<% company_id %>_DEMO_ROLE');
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.S4_FIN_DOCUMENTS')
    TO ROLE IDENTIFIER('<% company_id %>_DEMO_ROLE');
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_GL_ACCOUNT')
    TO ROLE IDENTIFIER('<% company_id %>_DEMO_ROLE');
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_PRODUCT')
    TO ROLE IDENTIFIER('<% company_id %>_DEMO_ROLE');
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_CUSTOMER')
    TO ROLE IDENTIFIER('<% company_id %>_DEMO_ROLE');
-- REFERENCES + SELECT both required for Cortex Agent usage of the semantic view
GRANT REFERENCES, SELECT ON SEMANTIC VIEW IDENTIFIER('<% db_name %>.FIN.S4_FIN_PNL_ANALYTICS_SV')
    TO ROLE IDENTIFIER('<% company_id %>_DEMO_ROLE');
GRANT USAGE ON AGENT IDENTIFIER('<% db_name %>.FIN.S4_FIN_PNL_AGENT')
    TO ROLE IDENTIFIER('<% company_id %>_DEMO_ROLE');

-- Add new role under S4_FIN_DEMO_GLOBAL_ROLE so multi-company execs see all data
GRANT ROLE IDENTIFIER('<% company_id %>_DEMO_ROLE') TO ROLE S4_FIN_DEMO_GLOBAL_ROLE;

-- ==============================================================================
-- STEP 3: Register in ROLE_ACCESS_MAPPING
-- This is the ONLY change to the access control layer.
-- NULL ALLOWED_REGION = the role can see all regions for this client.
-- ==============================================================================
INSERT INTO IDENTIFIER('<% db_name %>.FIN.ROLE_ACCESS_MAPPING')
    (ROLE_NAME, ALLOWED_CLIENT, ALLOWED_REGION, DESCRIPTION)
SELECT
    '<% company_id %>_DEMO_ROLE',
    '<% company_id %>',
    NULL,
    'Full access to all <% company_id %> regions. Created via add_company.sql.'
WHERE NOT EXISTS (
    SELECT 1 FROM IDENTIFIER('<% db_name %>.FIN.ROLE_ACCESS_MAPPING')
    WHERE ROLE_NAME    = '<% company_id %>_DEMO_ROLE'
      AND ALLOWED_CLIENT = '<% company_id %>'
      AND ALLOWED_REGION IS NULL
);

-- ==============================================================================
-- STEP 4: Confirmation and next steps
-- ==============================================================================
SELECT
    '<% company_id %>_DEMO_ROLE registered.' AS status,
    'Load data: INSERT INTO S3_FINANCE_PNL with CLIENT_ID = ''<% company_id %>''' AS next_step_1,
    'Test RAP: USE ROLE <% company_id %>_DEMO_ROLE; SELECT DISTINCT CLIENT_ID FROM S3_FINANCE_PNL' AS next_step_2,
    'Optional: CREATE OR REPLACE AGENT <% company_id %>_PNL_AGENT ...' AS next_step_3;

SELECT ROLE_NAME, ALLOWED_CLIENT, ALLOWED_REGION, DESCRIPTION
FROM IDENTIFIER('<% db_name %>.FIN.ROLE_ACCESS_MAPPING')
WHERE ROLE_NAME = '<% company_id %>_DEMO_ROLE';
