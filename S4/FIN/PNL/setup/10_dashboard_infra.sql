-- =============================================================================
-- 10_dashboard_infra.sql — Compute Pool and Image Registry for PnL Dashboard
--
-- Creates the SPCS prerequisites for the React PnL dashboard (Snowflake App
-- Runtime). This file is idempotent — safe to re-run at any time.
--
-- Variables:
--   <% db_name %>  — target database (default: S4)
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

-- Compute pool — single node, smallest CPU family, auto-suspends after 5 min
-- The dashboard app service will be scheduled onto this pool.
CREATE COMPUTE POOL IF NOT EXISTS PNL_DASHBOARD_CP
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_SUSPEND_SECS = 300
  COMMENT = 'Compute pool for PnL React dashboard (Snowflake App Runtime). One node, auto-suspends when idle.';

-- Image repository — stores the built Next.js container image
CREATE IMAGE REPOSITORY IF NOT EXISTS IDENTIFIER('<% db_name %>.FIN.DASHBOARD_REGISTRY')
  COMMENT = 'Container image registry for PnL dashboard app builds.';

-- Network rule: allow outbound HTTPS to the npm registry during build
CREATE NETWORK RULE IF NOT EXISTS PNL_NPM_NETWORK_RULE
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = ('registry.npmjs.org:443')
  COMMENT = 'Allows npm registry access during SAR app builds (npm ci step)';

-- External Access Integration: grants the SAR builder egress to npm
CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS PNL_BUILD_EAI
  ALLOWED_NETWORK_RULES = (PNL_NPM_NETWORK_RULE)
  ENABLED = TRUE
  COMMENT = 'EAI for npm ci during PnL dashboard SAR builds';

-- Grant the deploy role permission to reference the EAI
GRANT USAGE ON INTEGRATION PNL_BUILD_EAI TO ROLE DEMO_DATA_DEPLOY_ROLE;

-- Grant compute pool usage to the deploy role so GitHub Actions can deploy
GRANT USAGE ON COMPUTE POOL PNL_DASHBOARD_CP TO ROLE DEMO_DATA_DEPLOY_ROLE;

SELECT 'Dashboard infrastructure ready.' AS status,
       'Compute pool:  PNL_DASHBOARD_CP (CPU_X64_XS, 1 node, auto-suspend 300s)' AS compute_pool,
       'Image registry: ' || CURRENT_DATABASE() || '.FIN.DASHBOARD_REGISTRY' AS image_registry;
