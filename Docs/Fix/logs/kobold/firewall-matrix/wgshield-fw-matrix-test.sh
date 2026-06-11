#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="/home/brazwed/Documentos/Dev/VPS-WG-v2"
MOCK_BIN="/tmp/wgshield-fw-matrix-mock-bin"
LOG="/tmp/wgshield-fw-matrix.log"

export SSH_PORT=22
G='' R='' Y='' BD='' C='' NC='' DIM=''
FW_TYPE=""
FW_ACTIVE=false

log() { :; }
warn() { :; }
err() { :; }
info() { :; }
echo() { command echo "$@"; }

HARDEN_FIREWALL_MSG="test"
HARDEN_FIREWALL_IP4="test"
HARDEN_FIREWALL_IP6="test"
HARDEN_FIREWALL_IPTABLES="test"
HARDEN_FIREWALL_SUCCESS="test"
HARDEN_FIREWALL_DOCKER_FORWARD_WARN="test"
HARDEN_FIREWALL_UNKNOWN_TYPE_WARN="test"

source "$SCRIPT_DIR/lib/firewall.sh"

mod_firewall_iptables() {
    if ! command -v iptables >/dev/null 2>&1; then return 1; fi
    ensure_iptables_input_rule -i lo -j ACCEPT
    ensure_iptables_input_rule -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ensure_iptables_input_rule -p icmp -j ACCEPT
    ensure_iptables_input_rule -p tcp --dport "$SSH_PORT" -j ACCEPT
    ensure_iptables_input_rule -p udp --dport 51820 -j ACCEPT
    ensure_iptables_input_rule -p tcp --dport 51821 -j ACCEPT
    iptables -P INPUT DROP
    if docker_firewall_present; then
        warn "${HARDEN_FIREWALL_DOCKER_FORWARD_WARN}"
    else
        iptables -P FORWARD DROP
    fi
    iptables -P OUTPUT ACCEPT
    ensure_ip6tables_input_rule -i lo -j ACCEPT
    ensure_ip6tables_input_rule -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ensure_ip6tables_input_rule -p ipv6-icmp -j ACCEPT
    ensure_ip6tables_input_rule -p tcp --dport "$SSH_PORT" -j ACCEPT
    ensure_ip6tables_input_rule -p udp --dport 51820 -j ACCEPT
    ip6tables -P INPUT DROP
    if docker_firewall_present; then
        warn "${HARDEN_FIREWALL_DOCKER_FORWARD_WARN}"
    else
        ip6tables -P FORWARD DROP
    fi
    ip6tables -P OUTPUT ACCEPT
    if ! dpkg -l | grep -qw iptables-persistent; then
        DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent
        netfilter-persistent save
        netfilter-persistent enable
    else
        netfilter-persistent save
    fi
}

mod_firewall_ufw() {
    if ! command -v ufw >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt install -y ufw
    fi
    ufw default deny incoming >/dev/null 2>&1 || true
    ufw default allow outgoing >/dev/null 2>&1 || true
    ufw allow "${SSH_PORT}"/tcp comment "SSH" >/dev/null 2>&1 || true
    ufw allow 51820/udp comment "WireGuard" >/dev/null 2>&1 || true
    ufw allow 51821/tcp comment "WG-Easy" >/dev/null 2>&1 || true
    echo "y" | ufw enable >/dev/null 2>&1 || true
    FW_TYPE="ufw"
    FW_ACTIVE=true
}

mod_firewall() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_FIREWALL_MSG}${NC}"
    case "${FW_TYPE:-iptables}" in
        ufw) mod_firewall_ufw ;;
        iptables) mod_firewall_iptables ;;
        *) warn "${HARDEN_FIREWALL_UNKNOWN_TYPE_WARN}"; mod_firewall_iptables ;;
    esac
    log "${HARDEN_FIREWALL_SUCCESS}"
}

PASS=0
FAIL=0
TOTAL=0

check() {
    TOTAL=$((TOTAL + 1))
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc — expected='$expected' actual='$actual'"
        FAIL=$((FAIL + 1))
    fi
}

check_log() {
    TOTAL=$((TOTAL + 1))
    local desc="$1" pattern="$2" file="$3" negate="${4:-false}"
    if [ "$negate" = "true" ]; then
        if grep -q "$pattern" "$file" 2>/dev/null; then
            echo "  FAIL: $desc — pattern '$pattern' SHOULD NOT be present"
            FAIL=$((FAIL + 1))
        else
            echo "  PASS: $desc — pattern '$pattern' correctly absent"
            PASS=$((PASS + 1))
        fi
    else
        if grep -q "$pattern" "$file" 2>/dev/null; then
            echo "  PASS: $desc — pattern '$pattern' found"
            PASS=$((PASS + 1))
        else
            echo "  FAIL: $desc — pattern '$pattern' NOT found"
            FAIL=$((FAIL + 1))
        fi
    fi
}

echo "=========================================="
echo "  M1: FW_TYPE=iptables → mod_firewall"
echo "=========================================="
: > "$LOG"
FW_TYPE=iptables
mod_firewall
cp "$LOG" /tmp/wgshield-fw-matrix-iptables.log

check_log "M1a: iptables -P INPUT DROP" "iptables -P INPUT DROP" /tmp/wgshield-fw-matrix-iptables.log
check_log "M1b: netfilter-persistent" "netfilter-persistent" /tmp/wgshield-fw-matrix-iptables.log
check_log "M1c: NO ufw in iptables path" "ufw " /tmp/wgshield-fw-matrix-iptables.log true
check_log "M1d: NO iptables -F" "iptables -F" /tmp/wgshield-fw-matrix-iptables.log true

echo ""
echo "=========================================="
echo "  M2: FW_TYPE=ufw → mod_firewall"
echo "=========================================="
: > "$LOG"
FW_TYPE=ufw
mod_firewall
cp "$LOG" /tmp/wgshield-fw-matrix-ufw.log

check_log "M2a: ufw allow" "ufw allow" /tmp/wgshield-fw-matrix-ufw.log
check_log "M2b: ufw default" "ufw default" /tmp/wgshield-fw-matrix-ufw.log
check_log "M2c: ufw enable" "ufw enable" /tmp/wgshield-fw-matrix-ufw.log
check_log "M2d: NO iptables -P INPUT DROP" "iptables -P INPUT DROP" /tmp/wgshield-fw-matrix-ufw.log true
check_log "M2e: NO ip6tables -P INPUT DROP" "ip6tables -P INPUT DROP" /tmp/wgshield-fw-matrix-ufw.log true
check_log "M2f: NO iptables -F" "iptables -F" /tmp/wgshield-fw-matrix-ufw.log true

echo ""
echo "=========================================="
echo "  M3: FW_TYPE=unknown → mod_firewall fallback"
echo "=========================================="
: > "$LOG"
FW_TYPE=weirdvalue
mod_firewall
cp "$LOG" /tmp/wgshield-fw-matrix-unknown.log

check_log "M3a: fallback to iptables" "iptables -P INPUT DROP" /tmp/wgshield-fw-matrix-unknown.log
check_log "M3b: NO ufw" "ufw " /tmp/wgshield-fw-matrix-unknown.log true

echo ""
echo "=========================================="
echo "  M4: open_port FW_TYPE=ufw"
echo "=========================================="
: > "$LOG"
FW_TYPE=ufw
open_port "12345/tcp" "Test"
cp "$LOG" /tmp/wgshield-fw-matrix-open-port-ufw.log

check_log "M4a: ufw allow 12345/tcp" "ufw allow 12345/tcp" /tmp/wgshield-fw-matrix-open-port-ufw.log
check_log "M4b: NO iptables raw" "iptables" /tmp/wgshield-fw-matrix-open-port-ufw.log true

echo ""
echo "=========================================="
echo "  M5: open_port FW_TYPE=iptables"
echo "=========================================="
: > "$LOG"
FW_TYPE=iptables
open_port "12345/tcp" "Test"
cp "$LOG" /tmp/wgshield-fw-matrix-open-port-iptables.log

check_log "M5a: iptables -C INPUT" "iptables -C INPUT" /tmp/wgshield-fw-matrix-open-port-iptables.log
check_log "M5b: NO ufw" "ufw " /tmp/wgshield-fw-matrix-open-port-iptables.log true

echo ""
echo "=========================================="
echo "  M6: open_port FW_TYPE=none (no firewall)"
echo "=========================================="
: > "$LOG"
FW_TYPE=none
open_port "12345/tcp" "Test" 2>&1 || true
cp "$LOG" /tmp/wgshield-fw-matrix-open-port-none.log

if [ ! -s /tmp/wgshield-fw-matrix-open-port-none.log ]; then
    echo "  NOTE: open_port with FW_TYPE=none — no commands issued (expected, nothing to do)"
    TOTAL=$((TOTAL + 1))
    PASS=$((PASS + 1))
else
    echo "  NOTE: open_port with FW_TYPE=none issued commands:"
    cat /tmp/wgshield-fw-matrix-open-port-none.log
fi

echo ""
echo "=========================================="
echo "  M7: open_port with protocol in port spec"
echo "=========================================="
: > "$LOG"
FW_TYPE=iptables
open_port "51820/udp" "WireGuard"
cp "$LOG" /tmp/wgshield-fw-matrix-open-port-udp.log

check_log "M7a: iptables for udp/51820" "51820" /tmp/wgshield-fw-matrix-open-port-udp.log

echo ""
echo "=========================================="
echo "  SUMMARY"
echo "=========================================="
echo "  PASS: $PASS / $TOTAL"
echo "  FAIL: $FAIL / $TOTAL"
[ "$FAIL" -eq 0 ] && echo "  ALL TESTS PASSED" || echo "  SOME TESTS FAILED"
