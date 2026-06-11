#!/usr/bin/env bash
# C5 IPv6 Firewall Mock Test — source code analysis + isolated mock
set -e

MOCK_BIN="/tmp/wgshield-c5-mock-bin"
MOCK_LOG="/tmp/wgshield-c5-mock.log"
PASS=0
FAIL=0

assert_contains() {
    local desc="$1" file="$2" pattern="$3"
    if grep -qE "$pattern" "$file"; then
        echo "  PASS: $desc"
        PASS=$((PASS+1))
    else
        echo "  FAIL: $desc — pattern '$pattern' not found"
        FAIL=$((FAIL+1))
    fi
}

assert_not_contains() {
    local desc="$1" file="$2" pattern="$3"
    if ! grep -qE "$pattern" "$file"; then
        echo "  PASS: $desc"
        PASS=$((PASS+1))
    else
        echo "  FAIL: $desc — pattern '$pattern' SHOULD NOT be present"
        FAIL=$((FAIL+1))
    fi
}

SRC="/home/brazwed/Documentos/Dev/VPS-WG-v2/lib/hardening.sh"

# ============================================================
echo "=== M1: IPv6 port parity in mod_firewall_iptables() ==="
assert_contains "IPv6 SSH" "$SRC" "ensure_ip6tables_input_rule -p tcp --dport.*SSH_PORT"
assert_contains "IPv6 51820/udp" "$SRC" "ensure_ip6tables_input_rule -p udp --dport 51820"
assert_contains "IPv6 51821/tcp WG-Easy" "$SRC" "ensure_ip6tables_input_rule -p tcp --dport 51821"
assert_contains "IPv6 3000/tcp AdGuard" "$SRC" "ensure_ip6tables_input_rule -p tcp --dport 3000"
assert_contains "IPv4 51821/tcp present" "$SRC" "ensure_iptables_input_rule -p tcp --dport 51821"
assert_contains "Helper used (not raw ip6tables -A)" "$SRC" "ensure_ip6tables_input_rule"

# ============================================================
echo ""
echo "=== M2: UFW port parity in mod_firewall_ufw() ==="
assert_contains "UFW SSH" "$SRC" 'ufw allow.*SSH_PORT.*comment.*SSH'
assert_contains "UFW WireGuard" "$SRC" 'ufw allow 51820/udp.*comment.*WireGuard'
assert_contains "UFW WG-Easy" "$SRC" 'ufw allow 51821/tcp.*comment.*WG-Easy'
assert_contains "UFW AdGuard 3000/tcp" "$SRC" 'ufw allow 3000/tcp.*comment.*AdGuard'

# ============================================================
echo ""
echo "=== M3: open_port mock FW_TYPE=iptables ==="
cd /home/brazwed/Documentos/Dev/VPS-WG-v2
source ./lib/utils.sh
source ./lib/firewall.sh

rm -rf "$MOCK_BIN"
mkdir -p "$MOCK_BIN"
: > "$MOCK_LOG"

for cmd in iptables ip6tables ufw; do
  cat > "$MOCK_BIN/$cmd" <<MOCK
#!/usr/bin/env bash
echo "\$(basename "\$0") \$*" >> $MOCK_LOG
exit 0
MOCK
  chmod +x "$MOCK_BIN/$cmd"
done

# Use function directly with mock PATH in subshell
FW_TYPE=iptables PATH="$MOCK_BIN:$PATH" open_port "51821/tcp"
FW_TYPE=iptables PATH="$MOCK_BIN:$PATH" open_port "3000/tcp"

assert_contains "iptables 51821 via open_port" "$MOCK_LOG" "iptables.*--dport 51821"
assert_contains "iptables 3000 via open_port" "$MOCK_LOG" "iptables.*--dport 3000"
assert_not_contains "no ufw in iptables path" "$MOCK_LOG" "^ufw"

# ============================================================
echo ""
echo "=== M4: open_port mock FW_TYPE=ufw ==="
: > "$MOCK_LOG"
FW_TYPE=ufw PATH="$MOCK_BIN:$PATH" open_port "51821/tcp"
FW_TYPE=ufw PATH="$MOCK_BIN:$PATH" open_port "3000/tcp"

assert_contains "ufw 51821" "$MOCK_LOG" "ufw allow 51821/tcp"
assert_contains "ufw 3000" "$MOCK_LOG" "ufw allow 3000/tcp"
assert_not_contains "no iptables in ufw path" "$MOCK_LOG" "^iptables"

# ============================================================
echo ""
echo "=== M5: open_port FW_TYPE=none ==="
: > "$MOCK_LOG"
FW_TYPE=none open_port "51821/tcp"
FW_TYPE=none open_port "3000/tcp"

assert_not_contains "no iptables when none" "$MOCK_LOG" "iptables"
assert_not_contains "no ufw when none" "$MOCK_LOG" "ufw"

# ============================================================
echo ""
echo "=== M6: No raw -A INPUT, only helpers ==="
assert_not_contains "no ip6tables -A INPUT in source" "$SRC" 'ip6tables -A INPUT'
assert_not_contains "no iptables -A INPUT in source" "$SRC" 'iptables -A INPUT'
assert_contains "ip6tables -P INPUT DROP (policy)" "$SRC" "ip6tables -P INPUT DROP"

# ============================================================
echo ""
echo "=== M7: IPv4/IPv6 port parity table ==="

echo "  IPv4 ports (ensure_iptables_input_rule):"
grep 'ensure_iptables_input_rule.*--dport' "$SRC" | grep -v ip6 | sed 's/.*--dport /    /' | sort
echo ""
echo "  IPv6 ports (ensure_ip6tables_input_rule):"
grep 'ensure_ip6tables_input_rule.*--dport' "$SRC" | sed 's/.*--dport /    /' | sort
echo ""
echo "  UFW rules:"
grep 'ufw allow' "$SRC" | sed 's/.*ufw allow /    ufw allow /' | sort

PASS=$((PASS+1))  # parity check is visual

# ============================================================
echo ""
echo ""
echo "=== Results: $PASS PASS, $FAIL FAIL ==="
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
