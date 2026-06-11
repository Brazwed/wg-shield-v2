#!/usr/bin/env bash
export WS_LANG="pt_BR"
SCRIPT_DIR="/opt/wg-shield-test"
source "${SCRIPT_DIR}/lib/lang/pt_BR.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/firewall.sh"
source "${SCRIPT_DIR}/lib/hardening.sh"
SSH_PORT=22
echo "=== C2 TEST START $(date -Iseconds) ==="
mod_firewall
echo "=== C2 TEST END $(date -Iseconds) ==="
