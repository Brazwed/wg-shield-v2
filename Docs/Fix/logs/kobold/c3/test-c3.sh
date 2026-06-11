#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="/home/brazwed/Documentos/Dev/VPS-WG-v2"
MOCK_BIN="/tmp/wgshield-c3-mock-bin"
LOG="/tmp/wgshield-c3-mock.log"

export PATH="$MOCK_BIN:$PATH"
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
HARDEN_BBR_MSG="test"
HARDEN_BBR_BACKUP="test"
HARDEN_BBR_MODULE="test"
HARDEN_BBR_TUNING="test"
HARDEN_BBR_ALREADY="test"
HARDEN_BBR_SUCCESS="test"
HARDEN_UNATTENDED_MSG="test"
HARDEN_UNATTENDED_REBOOT_WARN="test"
HARDEN_UNATTENDED_SUCCESS="test"
HARDEN_FAIL2BAN_MSG="test"
HARDEN_FAIL2BAN_ALREADY="test"
HARDEN_FAIL2BAN_SUCCESS="test"
HARDEN_SWAP_MSG="test"
HARDEN_SWAP_NOSPACE="test"
HARDEN_SWAP_ALREADY="test"
HARDEN_SWAP_SUCCESS="test"
HARDEN_MEMORY_MSG="test"
HARDEN_MEMORY_ALREADY="test"
HARDEN_MEMORY_SUCCESS="test"
HARDEN_LIMITS_MSG="test"
HARDEN_LIMITS_ALREADY="test"
HARDEN_LIMITS_SUCCESS="test"
HARDEN_LOGS_MSG="test"
HARDEN_LOGS_ALREADY="test"
HARDEN_LOGS_SUCCESS="test"
HARDEN_DNS_MSG="test"
HARDEN_DNS_IPTABLES="test"
HARDEN_DNS_JAIL="test"
HARDEN_DNS_JAIL_ALREADY="test"
HARDEN_DNS_SUCCESS="test"
HARDEN_DNS_RATE="test"
HARDEN_DNS_REMOVE_MSG="test"
HARDEN_DNS_REMOVE_SUCCESS="test"
SWAPFILE="/swapfile"

source "$SCRIPT_DIR/lib/firewall.sh"

mod_firewall_iptables() {
    if ! command -v iptables >/dev/null 2>&1; then
        err "${HARDEN_FIREWALL_IPTABLES}"
        return 1
    fi

    echo -e "  ${BD}${C}${HARDEN_FIREWALL_IP4}${NC}"

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

    echo -e "  ${BD}${C}${HARDEN_FIREWALL_IP6}${NC}"

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
        ufw)
            mod_firewall_ufw
            ;;
        iptables)
            mod_firewall_iptables
            ;;
        *)
            warn "${HARDEN_FIREWALL_UNKNOWN_TYPE_WARN}"
            mod_firewall_iptables
            ;;
    esac

    log "${HARDEN_FIREWALL_SUCCESS}"
}

echo "=== Testing FW_TYPE=iptables ==="
: > "$LOG"
FW_TYPE=iptables
mod_firewall
cp "$LOG" /tmp/wgshield-c3-iptables-mock.log
echo "iptables mock log:"
cat /tmp/wgshield-c3-iptables-mock.log

echo ""
echo "=== Testing FW_TYPE=ufw ==="
: > "$LOG"
FW_TYPE=ufw
mod_firewall
cp "$LOG" /tmp/wgshield-c3-ufw-mock.log
echo "ufw mock log:"
cat /tmp/wgshield-c3-ufw-mock.log

echo ""
echo "=== Testing FW_TYPE=unknown ==="
: > "$LOG"
FW_TYPE=weirdvalue
mod_firewall
cp "$LOG" /tmp/wgshield-c3-unknown-mock.log
echo "unknown mock log:"
cat /tmp/wgshield-c3-unknown-mock.log

echo ""
echo "=== VALIDATION ==="

echo "--- iptables path ---"
if grep -q 'iptables.*-P INPUT DROP' /tmp/wgshield-c3-iptables-mock.log; then
    echo "PASS: iptables -P INPUT DROP present in iptables path"
else
    echo "FAIL: iptables -P INPUT DROP NOT in iptables path"
fi
if grep -q 'ufw' /tmp/wgshield-c3-iptables-mock.log; then
    echo "FAIL: ufw should NOT be in iptables path"
else
    echo "PASS: no ufw in iptables path"
fi
if grep -q 'netfilter-persistent' /tmp/wgshield-c3-iptables-mock.log; then
    echo "PASS: netfilter-persistent in iptables path"
else
    echo "FAIL: netfilter-persistent NOT in iptables path"
fi

echo "--- ufw path ---"
if grep -q 'ufw allow' /tmp/wgshield-c3-ufw-mock.log; then
    echo "PASS: ufw allow present in ufw path"
else
    echo "FAIL: ufw allow NOT in ufw path"
fi
if grep -q 'ufw default' /tmp/wgshield-c3-ufw-mock.log; then
    echo "PASS: ufw default present in ufw path"
else
    echo "FAIL: ufw default NOT in ufw path"
fi
if grep -q 'ufw enable' /tmp/wgshield-c3-ufw-mock.log; then
    echo "PASS: ufw enable in ufw path"
else
    echo "FAIL: ufw enable NOT in ufw path"
fi
if grep -q 'iptables.*-P INPUT DROP\|iptables.*-P FORWARD DROP' /tmp/wgshield-c3-ufw-mock.log; then
    echo "FAIL: iptables -P should NOT be in ufw path"
else
    echo "PASS: no iptables -P in ufw path"
fi
if grep -q 'ip6tables.*-P INPUT DROP\|ip6tables.*-P FORWARD DROP' /tmp/wgshield-c3-ufw-mock.log; then
    echo "FAIL: ip6tables -P should NOT be in ufw path"
else
    echo "PASS: no ip6tables -P in ufw path"
fi

echo "--- unknown path (fallback) ---"
if grep -q 'iptables.*-P INPUT DROP' /tmp/wgshield-c3-unknown-mock.log; then
    echo "PASS: fallback to iptables for unknown FW_TYPE"
else
    echo "FAIL: should fallback to iptables for unknown FW_TYPE"
fi

echo ""
echo "=== ALL MOCK TESTS COMPLETE ==="
