# lib/firewall.sh - Gerenciamento de firewall (UFW/iptables)

ensure_iptables_input_rule() {
    if iptables -C INPUT "$@" 2>/dev/null; then
        return 0
    fi
    local reject_line
    reject_line="$(iptables -L INPUT --line-numbers -n 2>/dev/null | awk '/REJECT|DROP/ {print $1; exit}')"
    if [[ -n "$reject_line" && "$reject_line" =~ ^[0-9]+$ ]]; then
        iptables -I INPUT "$reject_line" "$@"
    else
        iptables -A INPUT "$@"
    fi
}

ensure_ip6tables_input_rule() {
    if ip6tables -C INPUT "$@" 2>/dev/null; then
        return 0
    fi
    local reject_line
    reject_line="$(ip6tables -L INPUT --line-numbers -n 2>/dev/null | awk '/REJECT|DROP/ {print $1; exit}')"
    if [[ -n "$reject_line" && "$reject_line" =~ ^[0-9]+$ ]]; then
        ip6tables -I INPUT "$reject_line" "$@"
    else
        ip6tables -A INPUT "$@"
    fi
}

ask_firewall_choice() {
    echo ""

    if [ "$FW_ACTIVE" = "false" ]; then
        echo "  ${MSG_FW_NO_FIREWALL}"
        echo ""
        echo "    ${MSG_FW_INSTALL_UFW}"
        echo "    ${MSG_FW_USE_IPTABLES}"
        echo "    ${MSG_FW_DONT_CHANGE}"
        echo ""
        read -rp "  ${PROMPT_CHOICE}" fw_ch

        case "$fw_ch" in
            1)
                if ! apt-get install -y ufw >/dev/null 2>&1; then
                    warn "${MSG_FW_FAIL_INSTALL}"; return 1
                fi
                if ! ufw default deny incoming >/dev/null 2>&1; then
                    warn "${MSG_FW_FAIL_CONFIG}"; return 1
                fi
                ufw default allow outgoing >/dev/null 2>&1 || true
                ufw allow "${SSH_PORT}"/tcp comment "${MSG_FW_SSH_COMMENT}" >/dev/null 2>&1 || true
                if ! ufw --force enable >/dev/null 2>&1; then
                    warn "${MSG_FW_FAIL_ENABLE}"; return 1
                fi
                FW_TYPE="ufw"; FW_ACTIVE=true
                log "${MSG_FW_UFW_INSTALLED}"
                ;;
            2)
                FW_TYPE="iptables"; FW_ACTIVE=true
                ensure_iptables_input_rule -m state --state ESTABLISHED,RELATED -j ACCEPT
                ensure_iptables_input_rule -p tcp --dport "$SSH_PORT" -j ACCEPT
                log "${MSG_FW_IPTABLES_SET}"
                ;;
            *)
                info "${MSG_FW_CANCELLED}"
                return 1
                ;;
        esac
    fi

    read -rp "  ${MSG_FW_OPEN_PORT}" fw_go
    [[ "$fw_go" =~ ^[nN]$ ]] && return 1

    local alt_tool="iptables"; [ "$FW_TYPE" = "iptables" ] && alt_tool="ufw"
    if [ "$FW_ACTIVE" = "true" ] && command -v "$alt_tool" &>/dev/null; then
        echo ""
        echo "    [1] ${FW_TYPE}"
        echo "    [2] ${alt_tool}"
        echo ""
        read -rp "  ${MSG_FW_WHICH}" fw_pick
        if [ "$fw_pick" = "2" ]; then
            FW_TYPE="$alt_tool"
        fi
    fi

    return 0
}

open_port() {
    local port="$1" comment="${2:-WG-Shield}"

    # Extract port number and protocol (e.g., "51820/udp" -> "51820" + "udp")
    local port_num="${port%/*}"
    local protocol="${port#*/}"

    # Default to tcp if no protocol specified
    if [ "$protocol" = "$port_num" ]; then
        protocol="tcp"
    fi

    if [ "$FW_TYPE" = "ufw" ]; then
        ufw allow "$port_num/$protocol" comment "$comment" >/dev/null 2>&1 || warn "${MSG_FW_FAIL_OPEN_UFW}"
    elif [ "$FW_TYPE" = "iptables" ]; then
        ensure_iptables_input_rule -p "$protocol" --dport "$port_num" -j ACCEPT
    fi
}
