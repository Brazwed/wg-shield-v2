#!/usr/bin/env bash
set -e

MOCK_LOG="/tmp/wgshield-c4-mock.log"
FILTER_DIR="/tmp/wgshield-c4-test-filters"
JAIL_FILE="/tmp/wgshield-c4-test-jail.local"

cd /home/brazwed/Documentos/Dev/VPS-WG-v2
source ./lib/utils.sh
source ./lib/firewall.sh
source ./lib/lang/pt_BR.sh

FW_TYPE="${1:-iptables}"
SSH_PORT=22

: > "$MOCK_LOG"
rm -rf "$FILTER_DIR"
mkdir -p "$FILTER_DIR"

# Create a jail.local so the jail check finds it
: > "$JAIL_FILE"

mod_dns() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_DNS_MSG}${NC}"

    if [ ! -f "$FILTER_DIR/dns-abuse.conf" ]; then
        cat > "$FILTER_DIR/dns-abuse.conf <<'FILTER'
[Definition]
failregex = ^\[\d+:\d+\] info: <HOST> \S+ \S+ \S+
            ^.*unbound\[\d+\]: \[\d+:\d+\] info: <HOST> \S+ \S+ \S+
ignoreregex = ^\[\d+:\d+\] info: 127\.0\.0\.1
              ^\[\d+:\d+\] info: ::1
FILTER
    fi

    if [ "$FW_TYPE" = "none" ]; then
        warn "${HARDEN_DNS_NO_FIREWALL_WARN}"
    else
        open_port "53/udp"
        open_port "53/tcp"

        if [ "$FW_TYPE" = "iptables" ]; then
            if iptables -m hashlimit --help >/dev/null 2>&1; then
                _insert_dns_hashlimit udp dns_udp
                _insert_dns_hashlimit tcp dns_tcp
            else
                err "${HARDEN_DNS_IPTABLES}"
            fi
        fi
    fi

    echo -e "  ${BD}${C}${HARDEN_DNS_JAIL}${NC}"
    if [ -f "$JAIL_FILE" ]; then
        if ! grep -q "\[dns-abuse\]" "$JAIL_FILE"; then
            cat >> "$JAIL_FILE" <<EOF

[dns-abuse]
enabled = true
port = 53
filter = dns-abuse
backend = systemd
action = iptables-allports[name=DNS]
maxretry = 200
findtime = 60
bantime = 3600
EOF
            systemctl restart fail2ban
        else
            info "${HARDEN_DNS_JAIL_ALREADY}"
        fi
    else
        warn "${HARDEN_DNS_JAIL_ALREADY}"
    fi

    if [ "$FW_TYPE" = "iptables" ]; then
        netfilter-persistent save
    fi
    log "${HARDEN_DNS_SUCCESS}"
}

_insert_dns_hashlimit() {
    local proto="$1" hname="$2"

    if iptables -C INPUT -p "$proto" --dport 53 -m hashlimit \
        --hashlimit-above 30/sec --hashlimit-burst 50 \
        --hashlimit-mode srcip --hashlimit-name "$hname" \
        --hashlimit-htable-expire 30000 -j DROP 2>/dev/null; then
        return 0
    fi

    local accept_line
    accept_line=$(iptables -L INPUT --line-numbers -n 2>/dev/null | awk -v proto="$proto" '$2=="ACCEPT" && $3==proto && /dpt:53/ {print $1; exit}')

    if [ -n "$accept_line" ]; then
        iptables -I INPUT "$accept_line" -p "$proto" --dport 53 -m hashlimit \
            --hashlimit-above 30/sec --hashlimit-burst 50 \
            --hashlimit-mode srcip --hashlimit-name "$hname" \
            --hashlimit-htable-expire 30000 -j DROP
    else
        ensure_iptables_input_rule -p "$proto" --dport 53 -m hashlimit \
            --hashlimit-above 30/sec --hashlimit-burst 50 \
            --hashlimit-mode srcip --hashlimit-name "$hname" \
            --hashlimit-htable-expire 30000 -j DROP
    fi
}

echo "=== Test: FW_TYPE=$FW_TYPE ==="
mod_dns
