# lib/detection.sh - Detecção de VPS e firewall

detect_firewall() {
    FW_TYPE="none"
    FW_ACTIVE=false

    if command -v ufw &>/dev/null; then
        if ufw status 2>/dev/null | head -1 | grep -q "active"; then
            FW_TYPE="ufw"
            FW_ACTIVE=true
            local rules
            rules=$(ufw status 2>/dev/null | grep -c "ALLOW" || echo "0")
            echo -e "    Firewall:  ${G}UFW${NC} (${rules} ${MSG_FW_RULES})"
            return
        fi
    fi

    if command -v iptables &>/dev/null; then
        local ipt_rules
        ipt_rules=$(iptables -L INPUT -n 2>/dev/null | grep -c "^[A-Z]" || echo "0")
        if [ "$ipt_rules" -gt 2 ]; then
            FW_TYPE="iptables"
            FW_ACTIVE=true
            echo -e "    Firewall:  ${G}iptables${NC} (${ipt_rules} ${MSG_FW_RULES})"
            return
        fi
    fi

    echo -e "    Firewall:  ${Y}${MSG_DETECT_NONE}${NC}"
}

detect_vps_state() {
    local SEP='━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

    echo ""
    echo -e "  ${BD}${C}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${BD}${C}║                    ${MSG_DETECT_TITLE}                              ║${NC}"
    echo -e "  ${BD}${C}║                    ${DIM}${MSG_MENU_TITLE}${NC}${BD}${C}                      ║${NC}"
    echo -e "  ${BD}${C}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local conflicts=false
    local ports_in_use=()

    echo -e "  ${BD}${MSG_DETECT_SYSTEM}${NC}"

    if has_docker; then
        local dver
        dver=$(docker --version 2>/dev/null | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -1)
        echo -e "    Docker:     ${G}${BD}● ${MSG_STATUS_INSTALLED}${NC}${NC} (v${dver})"
    else
        echo -e "    Docker:     ${R}● ${DIM}${MSG_STATUS_NOT_INSTALLED}${NC}${NC}"
    fi

    local comp_containers=""
    while IFS='|' read -r _ _dc_name _ _ _ _dc_container _ _; do
        [ -z "$_dc_name" ] && continue
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$_dc_container"; then
            [ -n "$comp_containers" ] && comp_containers="${comp_containers}, "
            comp_containers="${comp_containers}${_dc_name}"
        fi
    done <<< "$COMPONENTS"
    echo "    Containers: ${comp_containers:-${MSG_DETECT_NONE}}"

    detect_firewall
    echo ""

    echo -e "  ${BD}${SEP}${NC}"
    echo ""

    echo -e "  📦 ${BD}${MSG_DETECT_CONTAINERS}${NC}"
    while IFS='|' read -r _dc_cat _dc_name _dc_display _dc_ports _dc_pubports _dc_repo _dc_container _dc_dir; do
        [ -z "$_dc_name" ] && continue
        local name="$_dc_name" display="$_dc_display" ports="$_dc_ports" container="$_dc_container" dir="$_dc_dir"

        local installed=false is_running=false port_used=false port_ours=false

        if [ -d "$dir" ] && [ -f "$dir/docker-compose.yml" ]; then
            installed=true
        fi

        # Check if container is running using docker ps
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
            is_running=true
        fi

        local first_port
        first_port=$(echo "$ports" | cut -d',' -f1 | cut -d'/' -f1)
        local pid=""
        pid=$(ss -tlnp 2>/dev/null | grep ":${first_port} " | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | head -1)
        if [ -n "$pid" ]; then
            port_used=true
            # Check if the port is used by our container
            if $is_running; then
                port_ours=true
            fi
        fi

        if $installed; then
            if $is_running; then
                if $port_used && $port_ours; then
                    printf "    %-18s :%-6s ${BD}${G}● ${MSG_STATUS_INSTALLED}${NC}  ${G}${MSG_STATUS_PORT_IN_USE}${NC}\n" "$display" "$first_port"
                else
                    printf "    %-18s :%-6s ${BD}${G}● ${MSG_STATUS_INSTALLED}${NC}  ${G}${MSG_STATUS_RUNNING}${NC}\n" "$display" "$first_port"
                fi
            else
                printf "    %-18s :%-6s ${BD}${Y}○ ${MSG_STATUS_INSTALLED}${NC}  ${MSG_STATUS_PORT_FREE}\n" "$display" "$first_port"
            fi
        else
            if $port_used; then
                printf "    %-18s :%-6s ${R}${MSG_STATUS_PORT_CONFLICT}${NC}\n" "$display" "$first_port"
                conflicts=true
                ports_in_use+=("$first_port")
            else
                printf "    %-18s :%-6s ${DIM}${MSG_STATUS_NOT_INSTALLED}${NC}\n" "$display" "$first_port"
            fi
        fi
    done <<< "$COMPONENTS"
    echo ""

    if [ ${#ports_in_use[@]} -gt 0 ]; then
        echo -e "  ${BD}${SEP}${NC}"
        echo ""
        local port_list
        port_list=$(IFS=', '; echo "${ports_in_use[*]}")
        echo -e "  ${Y}[!] ${#ports_in_use[@]} ${MSG_STATUS_PORT_CONFLICT}(s): ${port_list}${NC}"
        echo ""
    fi

    if [ "$conflicts" = "true" ]; then
        return 1
    fi
    return 0
}
