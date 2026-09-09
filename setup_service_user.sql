-- =============================================================================
-- setup_service_user.sql — GitHub Actions Service User Setup
--
-- Run this ONCE on the target Snowflake account as ACCOUNTADMIN, BEFORE
-- triggering any GitHub Actions workflow.
--
-- What this creates:
--   BSH_GITHUB_ACTIONS       — dedicated service user for CI/CD
--   BSH_DATA_DEPLOY_ROLE     — low-privilege role for ongoing data runs
--   bsh_service_auth_policy  — authentication policy (key pair only)
--
-- After running this script:
--   1. Generate the key pair on your laptop (see README.md)
--   2. Paste the public key body into the ALTER USER statement at the bottom
--   3. Add the three GitHub Secrets to your repo (see README.md)
--
-- PRIVILEGE DESIGN
-- ─────────────────────────────────────────────────────────────────────────────
-- The service user has two roles:
--
--   BSH_DATA_DEPLOY_ROLE  — low privilege, used for ongoing runs
--     Can: use warehouse, select/insert on demo tables, run verification
--     Cannot: create roles, manage grants, create warehouses or databases
--
--   ACCOUNTADMIN — elevated, only invoked by scripts that explicitly USE it
--     Needed for: CREATE ROLE, MANAGE GRANTS, CREATE DATABASE, apply RAP
--     Used by: 01_setup.sql, 03_rbac.sql, 04_fact_table.sql (first deploy)
--     NOT used by: data-only and verify GitHub Actions runs
--
-- Once you have deployed the infrastructure once, you can revoke ACCOUNTADMIN
-- from this user and re-grant it only when rebuilding from scratch.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Create the low-privilege deployment role
-- ─────────────────────────────────────────────────────────────────────────────
CREATE ROLE IF NOT EXISTS BSH_DATA_DEPLOY_ROLE
    COMMENT = 'Low-privilege role for GitHub Actions ongoing runs (data refresh, verify). '
              'Does not have CREATE ROLE, MANAGE GRANTS, or DDL privileges.';

-- Grant object access (run AFTER the demo is deployed for the first time)
-- Uncomment these lines once S4.FIN objects exist:
-- GRANT USAGE  ON WAREHOUSE BSH_DEMO_WH              TO ROLE BSH_DATA_DEPLOY_ROLE;
-- GRANT USAGE  ON DATABASE  S4                        TO ROLE BSH_DATA_DEPLOY_ROLE;
-- GRANT USAGE  ON SCHEMA    S4.FIN                    TO ROLE BSH_DATA_DEPLOY_ROLE;
-- GRANT SELECT ON ALL TABLES IN SCHEMA S4.FIN         TO ROLE BSH_DATA_DEPLOY_ROLE;
-- GRANT INSERT, TRUNCATE ON TABLE S4.FIN.S3_FINANCE_PNL  TO ROLE BSH_DATA_DEPLOY_ROLE;
-- GRANT INSERT, TRUNCATE ON TABLE S4.FIN.BSH_DOCUMENTS   TO ROLE BSH_DATA_DEPLOY_ROLE;
-- Grant the five BSH demo roles so 09_verify.sql can USE ROLE them for isolation tests:
-- GRANT ROLE BSH_DEMO_GLOBAL_ROLE  TO ROLE BSH_DATA_DEPLOY_ROLE;
-- GRANT ROLE BSH_DEMO_ROLE         TO ROLE BSH_DATA_DEPLOY_ROLE;
-- GRANT ROLE BSH_EUROPE_DEMO_ROLE  TO ROLE BSH_DATA_DEPLOY_ROLE;
-- GRANT ROLE BSH_NA_DEMO_ROLE      TO ROLE BSH_DATA_DEPLOY_ROLE;
-- GRANT ROLE BSH_APAC_DEMO_ROLE    TO ROLE BSH_DATA_DEPLOY_ROLE;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Create the service user
-- ─────────────────────────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS BSH_GITHUB_ACTIONS
    DISPLAY_NAME         = 'BSH GitHub Actions'
    COMMENT              = 'Service user for GitHub Actions BSH demo deployments. '
                           'Authentication: key pair only (no password, no SSO). '
                           'Audit trail: all automated actions log under this identity.'
    DEFAULT_ROLE         = 'BSH_DATA_DEPLOY_ROLE'   -- low-privilege default
    DEFAULT_WAREHOUSE    = 'BSH_DEMO_WH'
    MUST_CHANGE_PASSWORD = FALSE;

-- Grant the low-privilege role for day-to-day operations
GRANT ROLE BSH_DATA_DEPLOY_ROLE TO USER BSH_GITHUB_ACTIONS;

-- Grant ACCOUNTADMIN for the initial full deploy (can be revoked after first run)
-- The scripts invoke it explicitly with USE ROLE ACCOUNTADMIN — it is not the default.
GRANT ROLE ACCOUNTADMIN TO USER BSH_GITHUB_ACTIONS;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Authentication Policy — key pair only
--
-- This prevents anyone from logging in as BSH_GITHUB_ACTIONS using a password
-- or Okta/SSO, even if credentials were somehow obtained.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE AUTHENTICATION POLICY bsh_service_auth_policy
    AUTHENTICATION_METHODS = ('KEYPAIR')
    COMMENT = 'BSH GitHub Actions service user: key pair auth only. '
              'Blocks password login and SSO for this user.';

ALTER USER BSH_GITHUB_ACTIONS
    SET AUTHENTICATION POLICY bsh_service_auth_policy;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Register the public key
--
-- Before running this step:
--   1. Generate the key pair on your laptop (see README.md Step 1)
--   2. Extract the public key body: grep -v "BEGIN\|END" bsh_demo_cicd.pub | tr -d '\n'
--   3. Paste the output (base64 only, no headers) in place of '...' below
-- ─────────────────────────────────────────────────────────────────────────────
-- ALTER USER BSH_GITHUB_ACTIONS
--     ADD KEY PAIR bsh_demo_github_actions
--     PUBLIC_KEY = 'MIIBIjAN...';   -- paste public key body here

-- ─────────────────────────────────────────────────────────────────────────────
-- Verify the user was created correctly
-- ─────────────────────────────────────────────────────────────────────────────
DESC USER BSH_GITHUB_ACTIONS;
SHOW USER KEY PAIRS FOR USER BSH_GITHUB_ACTIONS;

SELECT 'Service user setup complete.' AS status,
       'Next: generate key pair (README.md), then uncomment ALTER USER above.' AS next_step;

-- ─────────────────────────────────────────────────────────────────────────────
-- OPTIONAL: Revoke ACCOUNTADMIN after first deploy
--
-- Once the full infrastructure is deployed (action: all completed successfully),
-- run this to remove the elevated privilege. Re-grant it only when you need to
-- rebuild the infrastructure from scratch.
-- ─────────────────────────────────────────────────────────────────────────────
-- REVOKE ROLE ACCOUNTADMIN FROM USER BSH_GITHUB_ACTIONS;
-- SELECT 'ACCOUNTADMIN revoked. Service user now operates with BSH_DATA_DEPLOY_ROLE only.' AS status;
