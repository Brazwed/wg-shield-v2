#!/usr/bin/env bash
set -uo pipefail

export WS_LANG="pt_BR"
SCRIPT_DIR="/opt/wg-shield-test"

source "${SCRIPT_DIR}/lib/lang/${WS_LANG}.sh" 2>/dev/null || source "${SCRIPT_DIR}/lib/lang/en_US.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/firewall.sh"
source "${SCRIPT_DIR}/lib/hardening.sh"

SSH_PORT=22
BD=""; C=""; NC=""

echo "=== STARTING mod_firewall TEST ===" 
date -Iseconds

mod_firewall 2>&1

echo "=== mod_firewall COMPLETED ==="
date -Iseconds
