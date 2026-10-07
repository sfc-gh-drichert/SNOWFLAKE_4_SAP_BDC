-- =============================================================================
-- 03_rbac.sql — Role Hierarchy, Row Access Policy, Object Grants
--
-- DESIGN PRINCIPLES
-- ─────────────────
-- 1. CLIENT_ID is the TENANT discriminator: 'RDANEEL', 'HENKEL', etc.
--    COMPANYCODE is R.Daneel's INTERNAL SAP entity (1000=Germany, 2000=NA, …).
--    These are two separate dimensions — do not conflate them.
--
-- 2. REGION is the second isolation axis.
--    Some roles see all of R.Daneel; regional sub-roles see only their territory.
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
--   SYSADMIN  ──►  S4_FIN_DEMO_GLOBAL_ROLE  ──►  S4_FIN_DEMO_ROLE
--                                                    │
--                              ┌────────────────────┼────────────────────┐
--                              ▼                    ▼                    ▼
--                   S4_FIN_EUROPE_DEMO_ROLE   S4_FIN_NA_DEMO_ROLE   S4_FIN_APAC_DEMO_ROLE
--
-- ─────────────────────────────────────────────────────────────────────────────
-- WHAT EACH ROLE SEES
-- ─────────────────────────────────────────────────────────────────────────────
--  ACCOUNTADMIN / SYSADMIN   All clients  All regions  (admin only, not for demos)
--  S4_FIN_DEMO_GLOBAL_ROLE      All clients  All regions  (multi-company exec demo)
--  S4_FIN_DEMO_ROLE             R.Daneel          All regions  (full R.Daneel PnL story)
--  S4_FIN_EUROPE_DEMO_ROLE      R.Daneel          DACH + W_EUROPE + E_EUROPE
--  S4_FIN_NA_DEMO_ROLE          R.Daneel          N_AMERICA
--  S4_FIN_APAC_DEMO_ROLE        R.Daneel          APAC + EMERGING
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
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
                    COMMENT 'REGION this role may see within the allowed client. NULL = all regions for that client',
    DESCRIPTION     VARCHAR(500)
                    COMMENT 'Human-readable purpose of this mapping row'
)
COMMENT = 'RAP data-access registry — one row per (role, client, region) permission. Insert here to onboard new companies or regional roles; no DDL changes required.';

-- S4_FIN_DEMO_GLOBAL_ROLE — all clients, all regions
INSERT INTO ROLE_ACCESS_MAPPING VALUES
    ('S4_FIN_DEMO_GLOBAL_ROLE', NULL, NULL,
     'Full access: all CLIENT_IDs and all regions. Use for multi-company exec demos.');

-- S4_FIN_DEMO_ROLE — all of R.Daneel, unrestricted by region
INSERT INTO ROLE_ACCESS_MAPPING VALUES
    ('S4_FIN_DEMO_ROLE', 'RDANEEL', NULL,
     'Full R.Daneel access: all six R.Daneel regions. Primary role for R.Daneel PnL demos.');

-- S4_FIN_EUROPE_DEMO_ROLE — R.Daneel Europe: DACH, Western Europe, Eastern Europe
INSERT INTO ROLE_ACCESS_MAPPING VALUES
    ('S4_FIN_EUROPE_DEMO_ROLE', 'RDANEEL', 'DACH',
     'R.Daneel Europe: Germany, Austria, Switzerland'),
    ('S4_FIN_EUROPE_DEMO_ROLE', 'RDANEEL', 'W_EUROPE',
     'R.Daneel Europe: France, UK, BeNeLux, Italy, Spain'),
    ('S4_FIN_EUROPE_DEMO_ROLE', 'RDANEEL', 'E_EUROPE',
     'R.Daneel Europe: Poland, Czech Republic, Romania');

-- S4_FIN_NA_DEMO_ROLE — North America only
INSERT INTO ROLE_ACCESS_MAPPING VALUES
    ('S4_FIN_NA_DEMO_ROLE', 'RDANEEL', 'N_AMERICA',
     'R.Daneel North America: US, Canada, Mexico. Thermador + Bosch focus.');

-- S4_FIN_APAC_DEMO_ROLE — Asia-Pacific and Emerging Markets
INSERT INTO ROLE_ACCESS_MAPPING VALUES
    ('S4_FIN_APAC_DEMO_ROLE', 'RDANEEL', 'APAC',
     'R.Daneel APAC: China (JD.com / Tmall e-comm growth story), Japan, Australia'),
    ('S4_FIN_APAC_DEMO_ROLE', 'RDANEEL', 'EMERGING',
     'R.Daneel Emerging Markets: Turkey, Brazil, India');

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
            FROM <% db_name %>.FIN.ROLE_ACCESS_MAPPING
            WHERE ROLE_NAME     = CURRENT_ROLE()
              AND (ALLOWED_CLIENT IS NULL OR ALLOWED_CLIENT = p_client_id)
              AND (ALLOWED_REGION IS NULL OR ALLOWED_REGION = p_region)
        )
COMMENT = 'Two-column Row Access Policy: enforces CLIENT_ID (tenant) + REGION isolation. Applied to S3_FINANCE_PNL. Inherited automatically by the Semantic View.';

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Create roles
-- ─────────────────────────────────────────────────────────────────────────────

-- Leaf roles (most restrictive — grant privileges here; hierarchy inherits up)
CREATE ROLE IF NOT EXISTS S4_FIN_EUROPE_DEMO_ROLE
    COMMENT = 'R.Daneel Europe analyst: DACH + W_EUROPE + E_EUROPE data only';
CREATE ROLE IF NOT EXISTS S4_FIN_NA_DEMO_ROLE
    COMMENT = 'R.Daneel North America analyst: N_AMERICA data only';
CREATE ROLE IF NOT EXISTS S4_FIN_APAC_DEMO_ROLE
    COMMENT = 'R.Daneel APAC/Emerging analyst: APAC + EMERGING data only';

-- Company-level role — all R.Daneel regions
CREATE ROLE IF NOT EXISTS S4_FIN_DEMO_ROLE
    COMMENT = 'Full R.Daneel access: all regions, all R.Daneel data. Primary demo role.';

-- Global role — all clients, all regions (multi-company demos)
CREATE ROLE IF NOT EXISTS S4_FIN_DEMO_GLOBAL_ROLE
    COMMENT = 'Global access: all CLIENT_IDs and all regions. Use for executive demos.';

-- Service account role — created here as a safety net in case setup_service_user.sql
-- was not run before the main deploy. The role is also created in setup_service_user.sql.
CREATE ROLE IF NOT EXISTS DEMO_DATA_DEPLOY_ROLE
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
GRANT ROLE S4_FIN_EUROPE_DEMO_ROLE  TO ROLE S4_FIN_DEMO_ROLE;
GRANT ROLE S4_FIN_NA_DEMO_ROLE      TO ROLE S4_FIN_DEMO_ROLE;
GRANT ROLE S4_FIN_APAC_DEMO_ROLE    TO ROLE S4_FIN_DEMO_ROLE;
GRANT ROLE S4_FIN_DEMO_ROLE         TO ROLE S4_FIN_DEMO_GLOBAL_ROLE;
GRANT ROLE S4_FIN_DEMO_GLOBAL_ROLE  TO ROLE SYSADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5: Object grants
--
-- Grant to the leaf roles only; parent roles inherit via the hierarchy above.
-- Note: ROLE_ACCESS_MAPPING is intentionally excluded — demo roles must not
-- be able to read or modify the access control table directly.
-- ─────────────────────────────────────────────────────────────────────────────
-- Warehouse usage
GRANT USAGE ON WAREHOUSE IDENTIFIER('<% wh_name %>')
    TO ROLE S4_FIN_EUROPE_DEMO_ROLE;
GRANT USAGE ON WAREHOUSE IDENTIFIER('<% wh_name %>')
    TO ROLE S4_FIN_NA_DEMO_ROLE;
GRANT USAGE ON WAREHOUSE IDENTIFIER('<% wh_name %>')
    TO ROLE S4_FIN_APAC_DEMO_ROLE;

-- Database and schema usage
GRANT USAGE ON DATABASE  IDENTIFIER('<% db_name %>') TO ROLE S4_FIN_EUROPE_DEMO_ROLE;
GRANT USAGE ON DATABASE  IDENTIFIER('<% db_name %>') TO ROLE S4_FIN_NA_DEMO_ROLE;
GRANT USAGE ON DATABASE  IDENTIFIER('<% db_name %>') TO ROLE S4_FIN_APAC_DEMO_ROLE;
GRANT USAGE ON SCHEMA    IDENTIFIER('<% db_name %>.FIN') TO ROLE S4_FIN_EUROPE_DEMO_ROLE;
GRANT USAGE ON SCHEMA    IDENTIFIER('<% db_name %>.FIN') TO ROLE S4_FIN_NA_DEMO_ROLE;
GRANT USAGE ON SCHEMA    IDENTIFIER('<% db_name %>.FIN') TO ROLE S4_FIN_APAC_DEMO_ROLE;

-- Dimension tables (no RAP — safe to read by all demo roles)
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_GL_ACCOUNT')  TO ROLE S4_FIN_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_PRODUCT')     TO ROLE S4_FIN_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_CUSTOMER')    TO ROLE S4_FIN_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_COMPANY')     TO ROLE S4_FIN_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_PLANT')       TO ROLE S4_FIN_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_GL_ACCOUNT')  TO ROLE S4_FIN_NA_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_PRODUCT')     TO ROLE S4_FIN_NA_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_CUSTOMER')    TO ROLE S4_FIN_NA_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_COMPANY')     TO ROLE S4_FIN_NA_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_PLANT')       TO ROLE S4_FIN_NA_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_GL_ACCOUNT')  TO ROLE S4_FIN_APAC_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_PRODUCT')     TO ROLE S4_FIN_APAC_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_CUSTOMER')    TO ROLE S4_FIN_APAC_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_COMPANY')     TO ROLE S4_FIN_APAC_DEMO_ROLE;
GRANT SELECT ON TABLE IDENTIFIER('<% db_name %>.FIN.DIM_PLANT')       TO ROLE S4_FIN_APAC_DEMO_ROLE;

-- Fact table — RAP will be applied after 04_fact_table.sql creates it
-- (Run: GRANT SELECT ON TABLE S3_FINANCE_PNL is included in 04_fact_table.sql)

-- Documents table — granted in 06_search.sql after S4_FIN_DOCUMENTS is created

-- ==============================================================================
-- DEMO_DATA_DEPLOY_ROLE: role hierarchy grant only
-- SELECT/USAGE on all objects is inherited through S4_FIN_DEMO_GLOBAL_ROLE chain.
-- INSERT/TRUNCATE on S3_FINANCE_PNL and S4_FIN_DOCUMENTS are added in files 04
-- and 06 respectively, after those tables are created.
-- ==============================================================================
GRANT ROLE S4_FIN_DEMO_GLOBAL_ROLE TO ROLE DEMO_DATA_DEPLOY_ROLE;

-- ==============================================================================
-- Verification
-- ==============================================================================
SELECT ROLE_NAME, ALLOWED_CLIENT, ALLOWED_REGION, DESCRIPTION
FROM ROLE_ACCESS_MAPPING
ORDER BY ROLE_NAME, ALLOWED_CLIENT, ALLOWED_REGION;

SHOW ROLES LIKE 'S4_FIN%';
