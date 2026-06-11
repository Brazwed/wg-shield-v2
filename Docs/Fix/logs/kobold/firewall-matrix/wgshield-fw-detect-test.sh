#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="/home/brazwed/Documentos/Dev/VPS-WG-v2"
MOCK_BIN="/tmp/wgshield-fw-detect-mock-bin"

G='' R='' Y='' BD='' C='' NC='' DIM=''
FW_TYPE=""
FW_ACTIVE=false

MSG_FW_RULES="rules"
MSG_DETECT_NONE="none"

source "$SCRIPT_DIR/lib/detection.sh"

PASS=0
FAIL=0
TOTAL=0

check() {
    TOTAL=$((TOTAL + 1))
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $desc (=$actual)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc — expected='$expected' actual='$actual'"
        FAIL=$((FAIL + 1))
    fi
}

echo "=========================================="
echo "  D1: detect_firewall — UFW active"
echo "=========================================="
rm -rf "$MOCK_BIN" && mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/ufw" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "status" ]; then
    echo "Status: active"
    echo "To                         Action      From"
    echo "--                         ------      ----"
    echo "22/tcp                     ALLOW       Anywhere"
    echo "51820/udp                  ALLOW       Anywhere"
fi
exit 0
EOF
chmod +x "$MOCK_BIN/ufw"

cat > "$MOCK_BIN/iptables" <<'EOF'
#!/usr/bin/env bash
echo "Chain INPUT (policy ACCEPT)"
echo "target     prot opt source               destination"
exit 0
EOF
chmod +x "$MOCK_BIN/iptables"

export PATH="$MOCK_BIN:$PATH"
FW_TYPE="none"; FW_ACTIVE=false
detect_firewall >/dev/null 2>&1 || true
check "D1 FW_TYPE" "ufw" "$FW_TYPE"
check "D1 FW_ACTIVE" "true" "$FW_ACTIVE"

echo ""
echo "=========================================="
echo "  D2: detect_firewall — iptables >2 rules"
echo "=========================================="
rm -rf "$MOCK_BIN" && mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/ufw" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "status" ]; then
    echo "Status: inactive"
fi
exit 0
EOF
chmod +x "$MOCK_BIN/ufw"

cat > "$MOCK_BIN/iptables" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-L" ]; then
    echo "Chain INPUT (policy DROP)"
    echo "target     prot opt source               destination"
    echo "ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0"
    echo "ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:22"
    echo "ACCEPT     udp  --  0.0.0.0/0            0.0.0.0/0            udp dpt:51820"
    echo "REJECT     all  --  0.0.0.0/0            0.0.0.0/0            reject-with icmp-host-prohibited"
fi
exit 0
EOF
chmod +x "$MOCK_BIN/iptables"

export PATH="$MOCK_BIN:$PATH"
FW_TYPE="none"; FW_ACTIVE=false
detect_firewall >/dev/null 2>&1 || true
check "D2 FW_TYPE" "iptables" "$FW_TYPE"
check "D2 FW_ACTIVE" "true" "$FW_ACTIVE"

echo ""
echo "=========================================="
echo "  D3: detect_firewall — no firewall"
echo "=========================================="
rm -rf "$MOCK_BIN" && mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/ufw" <<'EOF'
#!/usr/bin/env bash
echo "Status: inactive"
exit 0
EOF
chmod +x "$MOCK_BIN/ufw"

cat > "$MOCK_BIN/iptables" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-L" ]; then
    echo "Chain INPUT (policy ACCEPT)"
    echo "target     prot opt source               destination"
fi
exit 0
EOF
chmod +x "$MOCK_BIN/iptables"

export PATH="$MOCK_BIN:$PATH"
FW_TYPE="none"; FW_ACTIVE=false
detect_firewall >/dev/null 2>&1 || true
check "D3 FW_TYPE" "none" "$FW_TYPE"
check "D3 FW_ACTIVE" "false" "$FW_ACTIVE"

echo ""
echo "=========================================="
echo "  D4: detect_firewall — UFW installed but inactive, iptables >=3 rules"
echo "=========================================="
rm -rf "$MOCK_BIN" && mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/ufw" <<'EOF'
#!/usr/bin/env bash
echo "Status: inactive"
exit 0
EOF
chmod +x "$MOCK_BIN/ufw"

cat > "$MOCK_BIN/iptables" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-L" ]; then
    echo "Chain INPUT (policy DROP)"
    echo "target     prot opt source               destination"
    echo "ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0"
    echo "ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:22"
    echo "ACCEPT     udp  --  0.0.0.0/0            0.0.0.0/0            udp dpt:51820"
    echo "REJECT     all  --  0.0.0.0/0            0.0.0.0/0            reject-with icmp-host-prohibited"
fi
exit 0
EOF
chmod +x "$MOCK_BIN/iptables"

export PATH="$MOCK_BIN:$PATH"
FW_TYPE="none"; FW_ACTIVE=false
detect_firewall >/dev/null 2>&1 || true
check "D4 FW_TYPE" "iptables" "$FW_TYPE"
check "D4 FW_ACTIVE" "true" "$FW_ACTIVE"

echo ""
echo "=========================================="
echo "  D5: detect_firewall — no ufw, no iptables"
echo "=========================================="
rm -rf "$MOCK_BIN" && mkdir -p "$MOCK_BIN"

export PATH="$MOCK_BIN:/usr/bin:/bin"
FW_TYPE="none"; FW_ACTIVE=false
detect_firewall >/dev/null 2>&1 || true
check "D5 FW_TYPE" "none" "$FW_TYPE"
check "D5 FW_ACTIVE" "false" "$FW_ACTIVE"

echo ""
echo "=========================================="
echo "  D6: detect_firewall — Oracle iptables (many rules)"
echo "=========================================="
rm -rf "$MOCK_BIN" && mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/ufw" <<'EOF'
#!/usr/bin/env bash
echo "command not found"
exit 1
EOF
chmod +x "$MOCK_BIN/ufw"

cat > "$MOCK_BIN/iptables" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-L" ]; then
    echo "Chain INPUT (policy ACCEPT)"
    echo "target     prot opt source               destination"
    echo "ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0            state RELATED,ESTABLISHED"
    echo "ACCEPT     icmp --  0.0.0.0/0            0.0.0.0/0"
    echo "ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0"
    echo "ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            state NEW tcp dpt:22"
    echo "REJECT     all  --  0.0.0.0/0            0.0.0.0/0            reject-with icmp-host-prohibited"
fi
exit 0
EOF
chmod +x "$MOCK_BIN/iptables"

export PATH="$MOCK_BIN:/usr/bin:/bin"
FW_TYPE="none"; FW_ACTIVE=false
detect_firewall >/dev/null 2>&1 || true
check "D6 FW_TYPE" "iptables" "$FW_TYPE"
check "D6 FW_ACTIVE" "true" "$FW_ACTIVE"

echo ""
echo "=========================================="
echo "  SUMMARY"
echo "=========================================="
echo "  PASS: $PASS / $TOTAL"
echo "  FAIL: $FAIL / $TOTAL"
[ "$FAIL" -eq 0 ] && echo "  ALL DETECT TESTS PASSED" || echo "  SOME DETECT TESTS FAILED"
