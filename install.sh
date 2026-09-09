#!/usr/bin/env bash
# =============================================================================
# install.sh — Generic Snowflake demo installer
#
# Usage:
#   ./install.sh [CONNECTION] [DATABASE] [WAREHOUSE] [DEMO_PATH]
#
# Arguments (all optional, defaults shown):
#   CONNECTION   Snowflake CLI connection name    (default: my_snowflake)
#   DATABASE     Target Snowflake database        (default: S4)
#   WAREHOUSE    Warehouse to use/create          (default: BSH_DEMO_WH)
#   DEMO_PATH    Path to demo setup/ folder       (default: S4/FIN/PNL)
#
# Examples:
#   ./install.sh                                        # defaults
#   ./install.sh my_snowflake S4 BSH_DEMO_WH S4/FIN/PNL  # explicit
#   ./install.sh MY_CONN S4 DEMO_WH S4/FIN/AP          # different demo
#
# Prerequisites:
#   - Snowflake CLI (snow) installed and on PATH
#   - ~/.snowflake/config.toml configured with the target connection
#     (copy .snowflake/config.toml.example as a starting point)
# =============================================================================

set -euo pipefail

CONNECTION="${1:-my_snowflake}"
DATABASE="${2:-S4}"
WAREHOUSE="${3:-BSH_DEMO_WH}"
DEMO_PATH="${4:-S4/FIN/PNL}"
SETUP_DIR="${DEMO_PATH}/setup"

# ─── Validate ────────────────────────────────────────────────────────────────
if [[ ! -d "${SETUP_DIR}" ]]; then
  echo "ERROR: Setup directory not found: ${SETUP_DIR}" >&2
  exit 1
fi

SQL_FILES=( "${SETUP_DIR}"/[0-9][0-9]_*.sql )
if [[ ${#SQL_FILES[@]} -eq 0 ]]; then
  echo "ERROR: No numbered SQL files found in ${SETUP_DIR}" >&2
  exit 1
fi

# ─── Header ──────────────────────────────────────────────────────────────────
echo "=============================================="
echo " Snowflake Demo Installer"
echo "=============================================="
echo " Demo        : ${DEMO_PATH}"
echo " Connection  : ${CONNECTION}"
echo " Database    : ${DATABASE}"
echo " Warehouse   : ${WAREHOUSE}"
echo " SQL files   : ${#SQL_FILES[@]}"
echo "=============================================="
echo ""

# ─── Run each numbered SQL file in order ─────────────────────────────────────
for f in "${SQL_FILES[@]}"; do
  echo "--> $(basename "${f}")"
  snow sql -f "${f}" \
    --connection "${CONNECTION}" \
    --variable "db_name=${DATABASE}" \
    --variable "wh_name=${WAREHOUSE}"
  echo "    OK"
done

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo " Deployment complete!"
echo ""
echo " Verify:   make verify CONNECTION=${CONNECTION} DEMO=${DEMO_PATH}"
echo " Teardown: make teardown CONNECTION=${CONNECTION} DEMO=${DEMO_PATH}"
echo "=============================================="
