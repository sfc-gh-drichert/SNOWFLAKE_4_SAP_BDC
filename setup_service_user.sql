USE ROLE ACCOUNTADMIN;

-- ==============================================================================
-- setup_service_user.sql
-- Run ONCE on the target Snowflake account as ACCOUNTADMIN
-- before triggering any GitHub Actions workflow.
--
-- What this creates:
--   DEMO_GITHUB_ACTIONS      - dedicated CI/CD service user (not a personal account)
--   DEMO_DATA_DEPLOY_ROLE    - low-privilege role for ongoing data and verify runs
--   S4.ADMIN schema         - holds the authentication policy object
--   DEMO_SERVICE_AUTH_POLICY - restricts this user to key pair only (no password/SSO)
--
-- Privilege design:
--   Default role  : DEMO_DATA_DEPLOY_ROLE (low privilege, used for data-only/verify runs)
--   Elevated role : ACCOUNTADMIN (granted here; invoked explicitly by setup scripts)
--     Needed for: CREATE ROLE, MANAGE GRANTS, CREATE DATABASE, CREATE WAREHOUSE
--     Used by   : 01_setup.sql, 03_rbac.sql (first deploy only)
--     NOT used by: data-only and verify GitHub Actions runs
--
-- Object grants (warehouse, tables, demo roles) are applied automatically
-- during the main deploy in 03_rbac.sql, 04_fact_table.sql, 06_search.sql.
-- Run setup files 01-09 after this script.
--
-- After running this script, complete the key pair setup:
--   See README.md Steps 2-4 to generate the key, register the public key,
--   and add the GitHub Secrets to the repo.
-- ==============================================================================

-- Create the database and admin schema now so the authentication policy has
-- a home. CREATE IF NOT EXISTS is safe to run even after the main deploy.
CREATE DATABASE IF NOT EXISTS S4;
CREATE SCHEMA  IF NOT EXISTS S4.ADMIN;
USE DATABASE S4;
USE SCHEMA ADMIN;

-- ==============================================================================
-- 1. Low-privilege deployment role
--    Extra grants (INSERT on fact table, INSERT on documents) are added by
--    04_fact_table.sql and 06_search.sql during the main deploy.
--    All SELECT and USAGE privileges are inherited via S4_FIN_DEMO_GLOBAL_ROLE.
-- ==============================================================================
CREATE ROLE IF NOT EXISTS DEMO_DATA_DEPLOY_ROLE
    COMMENT = 'GitHub Actions ongoing runs: data refresh and verify. No DDL, no role management.';

-- ==============================================================================
-- 2. Service user
--    Default role is DEMO_DATA_DEPLOY_ROLE, not ACCOUNTADMIN.
--    ACCOUNTADMIN is granted below but is NOT the default - setup scripts
--    must explicitly USE ROLE ACCOUNTADMIN to invoke it.
-- ==============================================================================
CREATE USER IF NOT EXISTS DEMO_GITHUB_ACTIONS
    DISPLAY_NAME         = 'Demo GitHub Actions'
    COMMENT              = 'CI/CD service user for demo deployments. Key pair auth only.'
    DEFAULT_ROLE         = 'DEMO_DATA_DEPLOY_ROLE'
    MUST_CHANGE_PASSWORD = FALSE;

GRANT ROLE DEMO_DATA_DEPLOY_ROLE TO USER DEMO_GITHUB_ACTIONS;
GRANT ROLE ACCOUNTADMIN         TO USER DEMO_GITHUB_ACTIONS;

-- ==============================================================================
-- 3. Authentication policy - key pair only
--    Blocks password login and Okta/SSO for this user even if credentials leak.
-- ==============================================================================
CREATE OR REPLACE AUTHENTICATION POLICY S4.ADMIN.DEMO_SERVICE_AUTH_POLICY
    AUTHENTICATION_METHODS = ('KEYPAIR')
    COMMENT = 'Restricts DEMO_GITHUB_ACTIONS to key pair auth only. No password or SSO.';

ALTER USER DEMO_GITHUB_ACTIONS
    SET AUTHENTICATION POLICY S4.ADMIN.DEMO_SERVICE_AUTH_POLICY;

-- ==============================================================================
-- 4. Register the public key
--
-- Run this AFTER generating the key pair on your laptop (README.md Step 2).
--   a) Get the public key body (no PEM headers):
--        grep -v "BEGIN\|END" demo_cicd.pub | tr -d '\n'
--   b) Paste the output in place of the '...' below and run just this block.
-- ==============================================================================

-- ALTER USER DEMO_GITHUB_ACTIONS
--     ADD KEY PAIR demo_github_actions
--     PUBLIC_KEY = '...';

-- ==============================================================================
-- 5. Verify
-- ==============================================================================
DESC USER DEMO_GITHUB_ACTIONS;
SHOW USER KEY PAIRS FOR USER DEMO_GITHUB_ACTIONS;

SELECT 'Setup complete. Next: register public key (step 4 above), then run 01-09 setup scripts.' AS next_step;

-- ==============================================================================
-- OPTIONAL: Revoke ACCOUNTADMIN after the first successful full deploy.
-- Re-grant only when rebuilding infrastructure from scratch.
--
-- REVOKE ROLE ACCOUNTADMIN FROM USER DEMO_GITHUB_ACTIONS;
-- ==============================================================================
