-- =============================================================================
-- 03_rbac.sql — Role Hierarchy, Row Access Policy, Object Grants
--
-- DESIGN PRINCIPLES
-- ─────────────────
-- 1. CLIENT_ID is the TENANT discriminator: 'BSH', 'HENKEL', etc.
--    COMPANYCODE is BSH's INTERNAL SAP entity (1000=Germany, 2000=NA, …).
--    These are two separate dimensions — do not conflate them.
--
-- 2. REGION is the second isolation axis.
--    Some roles see all of BSH; regional sub-roles see only their territory.
--
-- 3. The Row Access Policy (RAP) on (CLIENT_ID, REGION) enforces isolation
--    at the database level — not in a WHERE clause in a report or SV query.
--    A role that lacks access physically cannot retrieve those rows.
--
-- 4. The Semantic View inherits the RAP automatically — no FILTER clause
--    needs to be added to the SV DDL.
--
-- 5. Role HIERARCHY is used for PRIVILEGE inheritance only (fewer GRANT
--    statements). It does NOT affect the RAP — CURRENT_ROLE() returns the
--    active primary role, which is checked against ROLE_ACCESS_MAPPING.
--
-- ROLE HIERARCHY
-- ─────────────────────────────────────────────────────────────────────────────
--   SYSADMIN  ──►  BSH_DEMO_GLOBAL_ROLE  ──►  BSH_DEMO_ROLE
--                                                    │
--                              ┌────────────────────┼────────────────────┐
--                              ▼                    ▼                    ▼
--                   BSH_EUROPE_DEMO_ROLE   BSH_NA_DEMO_ROLE   BSH_APAC_DEMO_ROLE
--
-- ─────────────────────────────────────────────────────────────────────────────
-- WHAT EACH ROLE SEES
-- ─────────────────────────────────────────────────────────────────────────────
--  ACCOUNTADMIN / SYSADMIN   All clients  All regions  (admin only, not for demos)
--  BSH_DEMO_GLOBAL_ROLE      All clients  All regions  (multi-company exec demo)
--  BSH_DEMO_ROLE             BSH          All regions  (full BSH P&L story)
--  BSH_EUROPE_DEMO_ROLE      BSH          DACH + W_EUROPE + E_EUROPE
--  BSH_NA_DEMO_ROLE          BSH          N_AMERICA
--  BSH_APAC_DEMO_ROLE        BSH          APAC + EMERGING
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('&{wh_name}');
USE DATABASE  IDENTIFIER('&{db_name}');
USE SCHEMA FIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Role-to-access mapping table
--
-- This table is the single place to register what data each role can see.
-- Adding a new company: INSERT rows here + CREATE ROLE + load company data.
-- No DDL changes to S3_FINANCE_PNL, the RAP, or the Semantic View are needed.
--
-- SECURITY NOTE: Do NOT grant SELECT on this table to demo roles.
-- The RAP policy function runs as its OWNER (ACCOUNTADMIN), so demo roles
-- never need to query this table directly.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE ROLE_ACCESS_MAPPING (
    ROLE_NAME       VARCHAR(100)  NOT NULL
                    COMMENT 'Snowflake role name — matched against CURRENT_ROLE()',
    ALLOWED_CLIENT  VARCHAR(50)
                    COMMENT 'CLIENT_ID this role may see. NULL = all clients (global access)',
    ALLOWED_REGION  VARCHAR(30)
                    COMMENT 'REGION this role may see within the allowed client. '
                            'NULL = all regions for that client',
    DESCRIPTION     VARCHAR(500)
                    COMMENT 'Human-readable purpose of this mapping row'
)
COMMENT = 'RAP data-access registry — one row per (role, client, region) permission. '
          'Insert here to onboard new companies or regional roles; no DDL changes required.';

-- BSH_DEMO_GLOBAL_ROLE — all clients, all regions
INSERT INTO ROLE_ACCESS_MAPPING VALUES
    ('BSH_DEMO_GLOBAL_ROLE', NULL, NULL,
     'Full access: all CLIENT_IDs and all regions. Use for multi-company exec demos.');

-- BSH_DEMO_ROLE — all of BSH, unrestricted by region
INSERT INTO ROLE_ACCESS_MAPPING VALUES
    ('BSH_DEMO_ROLE', 'BSH', NULL,
     'Full BSH access: all six BSH regions. Primary role for BSH P&L demos.');

-- BSH_EUROPE_DEMO_ROLE — BSH Europe: DACH, Western Europe, Eastern Europe
INSERT INTO ROLE_ACCESS_MAPPING VALUES
    ('BSH_EUROPE_DEMO_ROLE', 'BSH', 'DACH',
     'BSH Europe: Germany, Austria, Switzerland'),
    ('BSH_EUROPE_DEMO_ROLE', 'BSH', 'W_EUROPE',
     'BSH Europe: France, UK, BeNeLux, Italy, Spain'),
    ('BSH_EUROPE_DEMO_ROLE', 'BSH', 'E_EUROPE',
     'BSH Europe: Poland, Czech Republic, Romania');

-- BSH_NA_DEMO_ROLE — North America only
INSERT INTO ROLE_ACCESS_MAPPING VALUES
    ('BSH_NA_DEMO_ROLE', 'BSH', 'N_AMERICA',
     'BSH North America: US, Canada, Mexico. Thermador + Bosch focus.');

-- BSH_APAC_DEMO_ROLE — Asia-Pacific and Emerging Markets
INSERT INTO ROLE_ACCESS_MAPPING VALUES
    ('BSH_APAC_DEMO_ROLE', 'BSH', 'APAC',
     'BSH APAC: China (JD.com / Tmall e-comm growth story), Japan, Australia'),
    ('BSH_APAC_DEMO_ROLE', 'BSH', 'EMERGING',
     'BSH Emerging Markets: Turkey, Brazil, India');

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Row Access Policy on (CLIENT_ID, REGION)
--
-- The policy function receives the actual column VALUES from each candidate row.
-- It returns TRUE (row is visible) when:
--   a) The current role is ACCOUNTADMIN or SYSADMIN (full admin bypass), OR
--   b) There exists a row in ROLE_ACCESS_MAPPING where:
--        ROLE_NAME     = CURRENT_ROLE()
--        ALLOWED_CLIENT is NULL (global) OR equals this row's CLIENT_ID
--        ALLOWED_REGION is NULL (all regions) OR equals this row's REGION
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE ROW ACCESS POLICY PNL_CLIENT_ISOLATION_POLICY
    AS (p_client_id VARCHAR, p_region VARCHAR)
    RETURNS BOOLEAN ->
        -- Full admin bypass
        CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN')
        OR
        -- Check against mapping table (policy runs as ACCOUNTADMIN owner)
        EXISTS (
            SELECT 1
            FROM IDENTIFIER('&{db_name}').FIN.ROLE_ACCESS_MAPPING
            WHERE ROLE_NAME     = CURRENT_ROLE()
              AND (ALLOWED_CLIENT IS NULL OR ALLOWED_CLIENT = p_client_id)
              AND (ALLOWED_REGION IS NULL OR ALLOWED_REGION = p_region)
        )
COMMENT = 'Two-column Row Access Policy: enforces CLIENT_ID (tenant) + REGION isolation. '
          'Applied to S3_FINANCE_PNL. Inherited automatically by the Semantic View.';

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Create roles
-- ─────────────────────────────────────────────────────────────────────────────

-- Leaf roles (most restrictive — grant privileges here; hierarchy inherits up)
CREATE ROLE IF NOT EXISTS BSH_EUROPE_DEMO_ROLE
    COMMENT = 'BSH Europe analyst: DACH + W_EUROPE + E_EUROPE data only';
CREATE ROLE IF NOT EXISTS BSH_NA_DEMO_ROLE
    COMMENT = 'BSH North America analyst: N_AMERICA data only';
CREATE ROLE IF NOT EXISTS BSH_APAC_DEMO_ROLE
    COMMENT = 'BSH APAC/Emerging analyst: APAC + EMERGING data only';

-- Company-level role — all BSH regions
CREATE ROLE IF NOT EXISTS BSH_DEMO_ROLE
    COMMENT = 'Full BSH access: all regions, all BSH data. Primary demo role.';

-- Global role — all clients, all regions (multi-company demos)
CREATE ROLE IF NOT EXISTS BSH_DEMO_GLOBAL_ROLE
    COMMENT = 'Global access: all CLIENT_IDs and all regions. Use for executive demos.';

-- Service account role — created here as a safety net in case setup_service_user.sql
-- was not run before the main deploy. The role is also created in setup_service_user.sql.
CREATE ROLE IF NOT EXISTS BSH_DATA_DEPLOY_ROLE
    COMMENT = 'GitHub Actions service user role: data refresh and verify runs. No DDL.';

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Role hierarchy grants (for privilege inheritance only)
--
-- When you GRANT ROLE child TO ROLE parent, the parent inherits all privileges
-- granted to the child. This means you only need to GRANT SELECT on tables
-- to the leaf roles — parent roles pick it up automatically.
--
-- This does NOT affect the RAP. CURRENT_ROLE() returns the active primary role,
-- not the chain. Each role is independently validated against ROLE_ACCESS_MAPPING.
-- ─────────────────────────────────────────────────────────────────────────────
GRANT ROLE BSH_EUROPE_DEMO_ROLE  TO ROLE BSH_DEMO_ROLE;
GRANT ROLE BSH_NA_DEMO_ROLE      TO ROLE BSH_DEMO_ROLE;
GRANT ROLE BSH_APAC_DEMO_ROLE    TO ROLE BSH_DEMO_ROLE;
GRANT ROLE BSH_DEMO_ROLE         TO ROLE BSH_DEMO_GLOBAL_ROLE;
GRANT ROLE BSH_DEMO_GLOBAL_ROLE  TO ROLE SYSADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5: Object grants
--
-- Grant to the leaf roles only; parent roles inherit via the hierarchy above.
-- Note: ROLE_ACCESS_MAPPING is intentionally excluded — demo roles must not
-- be able to read or modify the access control table directly.
-- ─────────────────────────────────────────────────────────────────────────────
-- Warehouse usage
GRANT USAGE ON WAREHOUSE IDENTIFIER('&{wh_name}')
    TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT USAGE ON WAREHOUSE IDENTIFIER('&{wh_name}')
    TO ROLE BSH_NA_DEMO_ROLE;
GRANT USAGE ON WAREHOUSE IDENTIFIER('&{wh_name}')
    TO ROLE BSH_APAC_DEMO_ROLE;

-- Database and schema usage
GRANT USAGE ON DATABASE  IDENTIFIER('&{db_name}') TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT USAGE ON DATABASE  IDENTIFIER('&{db_name}') TO ROLE BSH_NA_DEMO_ROLE;
GRANT USAGE ON DATABASE  IDENTIFIER('&{db_name}') TO ROLE BSH_APAC_DEMO_ROLE;
GRANT USAGE ON SCHEMA    IDENTIFIER('&{db_name}').FIN TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT USAGE ON SCHEMA    IDENTIFIER('&{db_name}').FIN TO ROLE BSH_NA_DEMO_ROLE;
GRANT USAGE ON SCHEMA    IDENTIFIER('&{db_name}').FIN TO ROLE BSH_APAC_DEMO_ROLE;

-- Dimension tables (no RAP — safe to read by all demo roles)
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_GL_ACCOUNT  TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_PRODUCT     TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_CUSTOMER    TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_COMPANY     TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_PLANT       TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_GL_ACCOUNT  TO ROLE BSH_NA_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_PRODUCT     TO ROLE BSH_NA_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_CUSTOMER    TO ROLE BSH_NA_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_COMPANY     TO ROLE BSH_NA_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_PLANT       TO ROLE BSH_NA_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_GL_ACCOUNT  TO ROLE BSH_APAC_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_PRODUCT     TO ROLE BSH_APAC_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_CUSTOMER    TO ROLE BSH_APAC_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_COMPANY     TO ROLE BSH_APAC_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('&{db_name}').FIN.DIM_PLANT       TO ROLE BSH_APAC_DEMO_ROLE;

-- Fact table — RAP will be applied after 04_fact_table.sql creates it
-- (Run: GRANT SELECT ON TABLE S3_FINANCE_PNL is included in 04_fact_table.sql)

-- Documents table — granted in 06_search.sql after BSH_DOCUMENTS is created

-- ==============================================================================
-- BSH_DATA_DEPLOY_ROLE: role hierarchy grant only
-- SELECT/USAGE on all objects is inherited through BSH_DEMO_GLOBAL_ROLE chain.
-- INSERT/TRUNCATE on S3_FINANCE_PNL and BSH_DOCUMENTS are added in files 04
-- and 06 respectively, after those tables are created.
-- ==============================================================================
GRANT ROLE BSH_DEMO_GLOBAL_ROLE TO ROLE BSH_DATA_DEPLOY_ROLE;

-- ==============================================================================
-- Verification
-- ==============================================================================
SELECT ROLE_NAME, ALLOWED_CLIENT, ALLOWED_REGION, DESCRIPTION
FROM ROLE_ACCESS_MAPPING
ORDER BY ROLE_NAME, ALLOWED_CLIENT, ALLOWED_REGION;

SHOW ROLES LIKE 'BSH%';
