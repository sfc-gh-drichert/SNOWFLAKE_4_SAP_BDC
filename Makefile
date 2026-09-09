# =============================================================================
# Makefile — Snowflake Demo Accelerators
#
# Usage:
#   make install                              # Deploy BSH PnL with defaults
#   make install DEMO=S4/FIN/PNL             # Explicit demo path
#   make install CONNECTION=MY_CONN          # Different Snowflake connection
#   make verify                              # Run verification queries
#   make teardown                            # Drop all demo objects
#   make add-company COMPANY=HENKEL          # Onboard a new company
#   make bdc-catalog                         # Create BDC product catalog + L1 schema
#   make bdc-discover CONNECTOR=DB.SCHEMA.CN # List real SAP BDC shares (read-only)
#   make bdc-confirm PRODUCT_KEY=CUSTOMER SHARE_NAME="Customer (...)"
#   make bdc-mount CONNECTOR=DB.SCHEMA.CN    # Create zzbdcL0_* CLDs + L1 views
#   make bdc-verify                          # Confirm CLDs/views/joins (read-only)
#   make bdc-teardown                        # Drop all mounted BDC CLDs and L1 views
# =============================================================================

CONNECTION ?= my_snowflake
DATABASE   ?= S4
WAREHOUSE  ?= BSH_DEMO_WH
DEMO       ?= S4/FIN/PNL

.PHONY: install verify teardown add-company help \
        bdc-catalog bdc-discover bdc-confirm bdc-mount bdc-verify bdc-teardown

help:
	@echo ""
	@echo "Usage:"
	@echo "  make install    [CONNECTION=...] [DATABASE=...] [WAREHOUSE=...] [DEMO=...]"
	@echo "  make verify     [CONNECTION=...] [DATABASE=...] [WAREHOUSE=...] [DEMO=...]"
	@echo "  make teardown   [CONNECTION=...] [DATABASE=...] [DEMO=...]"
	@echo "  make add-company COMPANY=<ID> [CONNECTION=...] [DATABASE=...] [DEMO=...]"
	@echo ""
	@echo "  SAP BDC CLD mapping (see README: 'Mapping SAP BDC Data Products into the Gold Layer'):"
	@echo "  make bdc-catalog                                    [CONNECTION=...] [DATABASE=...]"
	@echo "  make bdc-discover  CONNECTOR=<db.schema.connector>  [CONNECTION=...] [DATABASE=...]"
	@echo "  make bdc-confirm   PRODUCT_KEY=<key> SHARE_NAME=<name> [CONNECTION=...] [DATABASE=...]"
	@echo "  make bdc-mount     CONNECTOR=<db.schema.connector>  [CONNECTION=...] [DATABASE=...] [WAREHOUSE=...]"
	@echo "  make bdc-verify                                     [CONNECTION=...] [DATABASE=...] [WAREHOUSE=...]"
	@echo "  make bdc-teardown                                   [CONNECTION=...] [DATABASE=...] [WAREHOUSE=...]"
	@echo ""
	@echo "Defaults: CONNECTION=$(CONNECTION)  DATABASE=$(DATABASE)  WAREHOUSE=$(WAREHOUSE)  DEMO=$(DEMO)"
	@echo ""

## Deploy all SQL files in DEMO/setup/ in numbered order
install:
	@bash install.sh "$(CONNECTION)" "$(DATABASE)" "$(WAREHOUSE)" "$(DEMO)"

## Run verification queries (09_verify.sql) — read-only, safe to re-run
verify:
	snow sql -f "$(DEMO)/setup/09_verify.sql" \
		--connection "$(CONNECTION)" \
		--variable "db_name=$(DATABASE)" \
		--variable "wh_name=$(WAREHOUSE)"

## Drop all demo objects for this module (prompts for confirmation inside SQL)
teardown:
	snow sql -f "$(DEMO)/runbooks/teardown.sql" \
		--connection "$(CONNECTION)" \
		--variable "db_name=$(DATABASE)" \
		--variable "wh_name=$(WAREHOUSE)"

## Onboard a new company into the shared data model (zero DDL changes required)
## Usage: make add-company COMPANY=HENKEL
add-company:
	@test -n "$(COMPANY)" || (echo "ERROR: set COMPANY=<id>  e.g.  make add-company COMPANY=HENKEL"; exit 1)
	snow sql -f "$(DEMO)/runbooks/add_company.sql" \
		--connection "$(CONNECTION)" \
		--variable "db_name=$(DATABASE)" \
		--variable "company_id=$(COMPANY)"

## -----------------------------------------------------------------------------
## SAP BDC CLD mapping — see README: "Mapping SAP BDC Data Products into the
## Gold Layer" for the full walkthrough. Prerequisite: a CONNECTED zero-copy
## connector to SAP BDC must already exist in the target account.
## -----------------------------------------------------------------------------

## Step 1 (once): create S4.L1 schema + BDC_PRODUCT_CATALOG + BDC_L1_VIEW_MAP
bdc-catalog:
	snow sql -f "$(DEMO)/setup/11_bdc_l1_schema_and_catalog.sql" \
		--connection "$(CONNECTION)" \
		--variable "db_name=$(DATABASE)"

## Step 2: list real SAP BDC shares and suggest matches (read-only)
## Usage: make bdc-discover CONNECTOR=SAP_BDC_DB.SAP_SCHEMA.SAP_CONNECTOR
bdc-discover:
	@test -n "$(CONNECTOR)" || (echo "ERROR: set CONNECTOR=<db.schema.connector>"; exit 1)
	snow sql -f "$(DEMO)/setup/12_bdc_discover_shares.sql" \
		--connection "$(CONNECTION)" \
		--variable "db_name=$(DATABASE)" \
		--variable "connector_fqn=$(CONNECTOR)"

## Step 3: record a confirmed real share_name for one product
## Usage: make bdc-confirm PRODUCT_KEY=CUSTOMER SHARE_NAME="Customer (BDF730, ...)"
bdc-confirm:
	@test -n "$(PRODUCT_KEY)" || (echo "ERROR: set PRODUCT_KEY=<key>"; exit 1)
	@test -n "$(SHARE_NAME)" || (echo "ERROR: set SHARE_NAME=<exact share_name>"; exit 1)
	snow sql -f "$(DEMO)/runbooks/bdc_confirm_share.sql" \
		--connection "$(CONNECTION)" \
		--variable "db_name=$(DATABASE)" \
		--variable "product_key=$(PRODUCT_KEY)" \
		--variable "share_name=$(SHARE_NAME)"

## Step 4: mount zzbdcL0_* CLDs and create L1 views
## Usage: make bdc-mount CONNECTOR=SAP_BDC_DB.SAP_SCHEMA.SAP_CONNECTOR
bdc-mount:
	@test -n "$(CONNECTOR)" || (echo "ERROR: set CONNECTOR=<db.schema.connector>"; exit 1)
	snow sql -f "$(DEMO)/setup/13_bdc_mount_clds.sql" \
		--connection "$(CONNECTION)" \
		--variable "db_name=$(DATABASE)" \
		--variable "wh_name=$(WAREHOUSE)" \
		--variable "connector_fqn=$(CONNECTOR)"

## Step 5: verify CLDs, L1 views, and gold-layer FK joins (read-only)
bdc-verify:
	snow sql -f "$(DEMO)/setup/14_bdc_verify_clds.sql" \
		--connection "$(CONNECTION)" \
		--variable "db_name=$(DATABASE)" \
		--variable "wh_name=$(WAREHOUSE)"

## Drop all mounted BDC CLDs and L1 views (keeps CONFIRMED_SHARE_NAME)
bdc-teardown:
	snow sql -f "$(DEMO)/runbooks/teardown_bdc_clds.sql" \
		--connection "$(CONNECTION)" \
		--variable "db_name=$(DATABASE)" \
		--variable "wh_name=$(WAREHOUSE)"
