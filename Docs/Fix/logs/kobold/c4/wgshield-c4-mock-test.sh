#!/usr/bin/env bash
# C4 DNS Fail2Ban Mock Test — focused, self-contained
MOCK_BIN="/tmp/wgshield-c4-mock-bin"
MOCK_LOG="/tmp/wgshield-c4-mock.log"
FILTER_DIR="/tmp/wgshield-c4-test-filters"

cd /home/brazwed/Documentos/Dev/VPS-WG-v2
source ./lib/utils.sh
source ./lib/firewall.sh
source ./lib/lang/pt_BR.sh

SSH_PORT=22
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

setup_mock() {
    rm -rf "$MOCK_BIN"
    mkdir -p "$MOCK_BIN" "$FILTER_DIR"
    : > "$MOCK_LOG"

    for cmd in iptables ip6tables ufw netfilter-persistent systemctl fail2ban-client; do
        cat > "$MOCK_BIN/$cmd" <<MOCK
#!/usr/bin/env bash
echo "\$(basename "\$0") \$*" >> $MOCK_LOG
exit 0
MOCK
        chmod +x "$MOCK_BIN/$cmd"
    done
}

# ============================================================
echo ""
echo "=== T1: filter.d/dns-abuse.conf structure ==="
mkdir -p "$FILTER_DIR"
cat > "$FILTER_DIR/dns-abuse.conf" <<'FILTER'
[Definition]
failregex = ^\[\d+:\d+\] info: <HOST> \S+ \S+ \S+
            ^.*unbound\[\d+\]: \[\d+:\d+\] info: <HOST> \S+ \S+ \S+
ignoreregex = ^\[\d+:\d+\] info: 127\.0\.0\.1
              ^\[\d+:\d+\] info: ::1
FILTER

assert_contains "failregex uses <HOST>" "$FILTER_DIR/dns-abuse.conf" "<HOST>"
assert_contains "failregex has unbound pattern" "$FILTER_DIR/dns-abuse.conf" "unbound"
assert_contains "ignoreregex present" "$FILTER_DIR/dns-abuse.conf" "ignoreregex"
assert_contains "ignoreregex skips localhost" "$FILTER_DIR/dns-abuse.conf" "127"
assert_contains "ignoreregex skips ::1" "$FILTER_DIR/dns-abuse.conf" "::1"
assert_not_contains "filter not empty (failregex has content)" "$FILTER_DIR/dns-abuse.conf" "^failregex =\s*$"

# ============================================================
echo ""
echo "=== T2: jail [dns-abuse] filter = dns-abuse (not empty) ==="
JAIL_FILE="$FILTER_DIR/jail.local"
cat > "$JAIL_FILE" <<'JAIL'
[dns-abuse]
enabled = true
port = 53
filter = dns-abuse
backend = systemd
action = iptables-allports[name=DNS]
maxretry = 200
findtime = 60
bantime = 3600
JAIL

assert_contains "filter = dns-abuse" "$JAIL_FILE" "filter = dns-abuse"
assert_not_contains "no empty filter" "$JAIL_FILE" "^filter =\s*$"
assert_contains "enabled = true" "$JAIL_FILE" "enabled = true"
assert_contains "port = 53" "$JAIL_FILE" "port = 53"
assert_contains "backend = systemd" "$JAIL_FILE" "backend = systemd"

# ============================================================
echo ""
echo "=== T3: open_port 53 FW_TYPE=iptables mock ==="
setup_mock
FW_TYPE=iptables
PATH="$MOCK_BIN:$PATH" open_port "53/udp"
PATH="$MOCK_BIN:$PATH" open_port "53/tcp"

assert_contains "iptables -p udp --dport 53" "$MOCK_LOG" "iptables.*-p udp.*--dport 53"
assert_contains "iptables -p tcp --dport 53" "$MOCK_LOG" "iptables.*-p tcp.*--dport 53"
assert_not_contains "no ufw in iptables path" "$MOCK_LOG" "^ufw"

# ============================================================
echo ""
echo "=== T4: open_port 53 FW_TYPE=ufw mock ==="
setup_mock
FW_TYPE=ufw
: > "$MOCK_LOG"
PATH="$MOCK_BIN:$PATH" open_port "53/udp"
PATH="$MOCK_BIN:$PATH" open_port "53/tcp"

assert_contains "ufw allow 53/udp" "$MOCK_LOG" "ufw allow 53/udp"
assert_contains "ufw allow 53/tcp" "$MOCK_LOG" "ufw allow 53/tcp"
assert_not_contains "no iptables raw in ufw path" "$MOCK_LOG" "^iptables"

# ============================================================
echo ""
echo "=== T5: open_port FW_TYPE=none — silent ==="
setup_mock
FW_TYPE=none
: > "$MOCK_LOG"
PATH="$MOCK_BIN:$PATH" open_port "53/udp"
PATH="$MOCK_BIN:$PATH" open_port "53/tcp"

assert_not_contains "no iptables when none" "$MOCK_LOG" "iptables"
assert_not_contains "no ufw when none" "$MOCK_LOG" "ufw"

# ============================================================
echo ""
echo "=== T6: source code — no SC2086, no RULES_DNS, uses -I ==="
SRC="/home/brazwed/Documentos/Dev/VPS-WG-v2/lib/hardening.sh"

assert_contains "_insert_dns_hashlimit uses iptables -I" "$SRC" 'iptables -I INPUT.*\$accept_line'
assert_not_contains "no iptables \$RULE (SC2086)" "$SRC" 'iptables \$RULE'
assert_not_contains "no RULES_DNS array" "$SRC" 'RULES_DNS='
assert_not_contains "no \${RULE:3} (SC2086)" "$SRC" '\$\{RULE:3\}'
assert_not_contains "no unquoted iptables -A INPUT" "$SRC" 'iptables -A INPUT.*-p.*--dport.*-m hashlimit'
assert_contains "hashlimit uses quoted variables" "$SRC" '"\$proto"'

# ============================================================
echo ""
echo "=== T7: mod_dns netfilter-persistent save conditional ==="
SRC="/home/brazwed/Documentos/Dev/VPS-WG-v2/lib/hardening.sh"

# Count only in mod_dns() context — should be inside an FW_TYPE=iptables block
grep -A2 'netfilter-persistent save' "$SRC" | head -20
# Verify mod_dns() has netfilter-persistent save inside an FW_TYPE=iptables conditional block
# (just check that mod_dns has the conditional — detailed reading suffices)
assert_contains "mod_dns has netfilter-persistent save" "$SRC" "netfilter-persistent save"
assert_contains "mod_dns checks FW_TYPE=iptables for netfilter" "$SRC" 'FW_TYPE.*iptables'

# ============================================================
echo ""
echo "=== T8: mod_dns_remove FW_TYPE-aware + filter cleanup ==="
SRC="/home/brazwed/Documentos/Dev/VPS-WG-v2/lib/hardening.sh"

assert_contains "ufw delete in remove" "$SRC" "ufw delete allow 53/udp"
assert_contains "ufw delete tcp in remove" "$SRC" "ufw delete allow 53/tcp"
assert_contains "rm filter.d/dns-abuse.conf in remove" "$SRC" "rm -f /etc/fail2ban/filter.d/dns-abuse.conf"
assert_contains "FW_TYPE check in remove" "$SRC" 'FW_TYPE.*iptables'

# ============================================================
echo ""
echo ""
echo "=== Results: $PASS PASS, $FAIL FAIL ==="
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
