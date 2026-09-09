-- ==============================================================================
-- setup_service_user.sql
-- Run ONCE on the target Snowflake account as ACCOUNTADMIN
-- before triggering any GitHub Actions workflow.
--
-- What this creates:
--   BSH_GITHUB_ACTIONS      - dedicated CI/CD service user (not a personal account)
--   BSH_DATA_DEPLOY_ROLE    - low-privilege role for ongoing data and verify runs
--   S4.ADMIN schema         - holds the authentication policy object
--   BSH_SERVICE_AUTH_POLICY - restricts this user to key pair only (no password/SSO)
--
-- Privilege design:
--   Default role  : BSH_DATA_DEPLOY_ROLE (low privilege - used for data-only, verify)
--   Elevated role : ACCOUNTADMIN (granted here; invoked explicitly by setup scripts)
--     Needed for: CREATE ROLE, MANAGE GRANTS, CREATE DATABASE, CREATE WAREHOUSE
--     Used by   : 01_setup.sql, 03_rbac.sql (first deploy only)
--     NOT used by: data-only and verify GitHub Actions runs
--
-- Object grants (warehouse, tables, demo roles) are applied in 03_rbac.sql
-- as part of the main deploy. Run 01-09 setup scripts after this file.
--
-- After running this file, complete the key pair setup:
--   See README.md Steps 2-4 to generate the key, register the public key,
--   and add the three GitHub Secrets.
-- ==============================================================================

USE ROLE ACCOUNTADMIN;

-- Create the database and admin schema so the authentication policy has a home.
-- CREATE IF NOT EXISTS means this is safe to run even if S4 already exists.
CREATE DATABASE IF NOT EXISTS S4;
CREATE SCHEMA IF NOT EXISTS S4.ADMIN;
USE DATABASE S4;
USE SCHEMA ADMIN;

-- ==============================================================================
-- 1. Low-privilege deployment role
--    Object grants (warehouse, tables, demo roles) are added by 03_rbac.sql.
-- ==============================================================================
CREATE ROLE IF NOT EXISTS BSH_DATA_DEPLOY_ROLE
    COMMENT = 'GitHub Actions ongoing runs: data refresh and verify. No DDL, no role management.';

-- ==============================================================================
-- 2. Service user
--    Default role is BSH_DATA_DEPLOY_ROLE, not ACCOUNTADMIN.
--    ACCOUNTADMIN is granted below but is NOT the default — scripts must
--    explicitly USE ROLE ACCOUNTADMIN to invoke it.
-- ==============================================================================
CREATE USER IF NOT EXISTS BSH_GITHUB_ACTIONS
    DISPLAY_NAME         = 'BSH GitHub Actions'
    COMMENT              = 'CI/CD service user for BSH demo deployments. Key pair auth only.'
    DEFAULT_ROLE         = 'BSH_DATA_DEPLOY_ROLE'
    MUST_CHANGE_PASSWORD = FALSE;

GRANT ROLE BSH_DATA_DEPLOY_ROLE TO USER BSH_GITHUB_ACTIONS;
GRANT ROLE ACCOUNTADMIN         TO USER BSH_GITHUB_ACTIONS;

-- ==============================================================================
-- 3. Authentication policy - key pair only
--    Blocks password login and Okta/SSO for this user even if credentials leak.
-- ==============================================================================
CREATE OR REPLACE AUTHENTICATION POLICY S4.ADMIN.BSH_SERVICE_AUTH_POLICY
    AUTHENTICATION_METHODS = ('KEYPAIR')
    COMMENT = 'Restricts BSH_GITHUB_ACTIONS to key pair auth. No password or SSO.';

ALTER USER BSH_GITHUB_ACTIONS
    SET AUTHENTICATION POLICY S4.ADMIN.BSH_SERVICE_AUTH_POLICY;

-- ==============================================================================
-- 4. Register the public key
--
-- BEFORE running this section:
--   a) Generate the key pair on your laptop (README.md Step 2)
--   b) Get the public key body (no headers):
--        grep -v "BEGIN\|END" bsh_demo_cicd.pub | tr -d '\n'
--   c) Replace the placeholder '...' below with that output, then run this block
-- ==============================================================================

-- ALTER USER BSH_GITHUB_ACTIONS
--     ADD KEY PAIR bsh_demo_github_actions
--     PUBLIC_KEY = '...';

-- ==============================================================================
-- 5. Verify
-- ==============================================================================
DESC USER BSH_GITHUB_ACTIONS;
SHOW USER KEY PAIRS FOR USER BSH_GITHUB_ACTIONS;

SELECT 'Setup complete. Next: register public key (step 4 above), then run the deploy.' AS next_step;

-- ==============================================================================
-- OPTIONAL: Revoke ACCOUNTADMIN after the first successful full deploy.
-- Re-grant only when rebuilding infrastructure from scratch.
--
-- REVOKE ROLE ACCOUNTADMIN FROM USER BSH_GITHUB_ACTIONS;
-- ==============================================================================
