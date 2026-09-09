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
# =============================================================================

CONNECTION ?= EU_DEMO47
DATABASE   ?= S4
WAREHOUSE  ?= BSH_DEMO_WH
DEMO       ?= S4/FIN/PNL

.PHONY: install verify teardown add-company help

help:
	@echo ""
	@echo "Usage:"
	@echo "  make install    [CONNECTION=...] [DATABASE=...] [WAREHOUSE=...] [DEMO=...]"
	@echo "  make verify     [CONNECTION=...] [DATABASE=...] [WAREHOUSE=...] [DEMO=...]"
	@echo "  make teardown   [CONNECTION=...] [DATABASE=...] [DEMO=...]"
	@echo "  make add-company COMPANY=<ID> [CONNECTION=...] [DATABASE=...] [DEMO=...]"
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
