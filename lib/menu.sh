# lib/menu.sh - Menus interativos

select_installed_comp() {
    local prompt="$1"
    local installed_raw
    installed_raw=$(get_installed_list)

    if [ -z "$(echo "$installed_raw" | tr -d '[:space:]')" ]; then
        warn "${MSG_MGR_NONE_INSTALLED}" >&2; return 1
    fi

    echo "" >&2
    local idx=1 names=()
    while IFS='|' read -r name display _; do
        [ -z "$name" ] && continue
        echo "  [$idx] $display" >&2
        names+=("$name"); idx=$((idx + 1))
    done <<< "$installed_raw"
    echo "  [0] ${MSG_MENU_VOLTAR}" >&2
    echo "" >&2

    read -rp "  $prompt: " ch >&2
    [ "$ch" = "0" ] && return 1

    if [ "$ch" -ge 1 ] 2>/dev/null && [ "$ch" -le "${#names[@]}" ] 2>/dev/null; then
        echo "${names[$((ch - 1))]}"; return 0
    fi
    warn "${ERR_INVALID_OPTION}" >&2; return 1
}

# ─── Main Menu ───────────────────────────────────────────────
show_main_menu() {
    local installed_raw has_installed=false
    installed_raw=$(get_installed_list)
    [ -n "$(echo "$installed_raw" | tr -d '[:space:]')" ] && has_installed=true

    clear
    echo ""
    echo -e "  ${BD}${C}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${BD}${C}║                      ${MSG_MENU_TITLE}                          ║${NC}"
    echo -e "  ${BD}${C}║                      ${DIM}${MSG_MENU_AUTHOR}${NC}${BD}${C}                             ║${NC}"
    echo -e "  ${BD}${C}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${BD}${MSG_MENU_SISTEMA}${NC}"
    if has_docker; then
        local dver
        dver=$(docker --version 2>/dev/null | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -1)
        echo -e "    Docker:    ${G}● ${MSG_STATUS_INSTALLED}${NC} (v${dver})"
    else
        echo -e "    Docker:    ${R}● ${MSG_STATUS_NOT_INSTALLED}${NC}"
    fi
    if check_module_status dns; then
        echo -e "    DNS:       ${G}${BD}● ${MSG_DNS_STATUS_PUBLIC}${NC}  ${DIM}(${MSG_DNS_PORT_OPEN})${NC}"
    else
        echo -e "    DNS:       ${Y}${BD}○ ${MSG_DNS_STATUS_PRIVATE}${NC}   ${DIM}(${MSG_DNS_VPN_ONLY})${NC}"
    fi
    echo ""

    local SEP='━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    echo -e "  ${BD}${SEP}${NC}"
    echo ""

    echo -e "  📦 ${BD}${MSG_MAIN_CONTAINERS}${NC}"
    while IFS='|' read -r cat name display ports _; do
        [ -z "$name" ] && continue
        local st="${MSG_STATUS_NOT_INSTALLED}"
        local color="${BD}${Y}"
        if echo "$installed_raw" | grep -q "^${name}|"; then
            st=$(echo "$installed_raw" | grep "^${name}|" | cut -d'|' -f4)
            if [ "$st" = "running" ]; then
                color="${BD}${G}"; st="${MSG_STATUS_RUNNING}"
            else
                color="${BD}${R}"; st="${MSG_STATUS_STOPPED}"
            fi
        fi
        local first_port=$(echo "$ports" | cut -d',' -f1 | cut -d'/' -f1)
        echo -e "    ${display}   :${first_port}   ${color}● ${st}${NC}"
    done <<< "$COMPONENTS"
    echo ""

    echo -e "  ${BD}${SEP}${NC}"
    echo ""

    echo -e "  📋 ${BD}${MSG_MENU_COMANDOS}${NC}"
    echo ""
    echo "    [1] ${MSG_MENU_INSTALL}        ${MSG_MENU_ACTION_INSTALL}"
    echo "    [2] ${MSG_MENU_MANAGE}       ${MSG_MENU_ACTION_MANAGE}"
    echo "    [3] ${MSG_MENU_BACKUPS}         ${MSG_MENU_ACTION_BACKUPS}"
    echo "    [L] ${MSG_MENU_LANG}   (${WS_LANG})"
    echo "    [0] ${MSG_MENU_SAIR}"
    echo ""
}

# ─── Submenu Install ─────────────────────────────────────────
submenu_install() {
    while true; do
        clear
        echo ""
        echo -e "  ${BD}${C}${MSG_MENU_INSTALL}${NC}"
        echo ""
        echo "  ${MSG_MENU_WHAT_TO_INSTALL}"
        echo ""
        echo "    [1] ${MSG_INST_NEW_VPS}"
        echo "    [2] ${MSG_INST_WIZARD}"
        echo "    [3] ${MSG_INST_EXISTING_VPS}"
        echo ""
        echo "    [0] ← ${MSG_MENU_VOLTAR_MAIN}"
        echo ""

        flush_stdin
        read -rp "  ${MSG_MENU_CHOOSE}" choice

        case "$choice" in
            1)
                if all_already_installed; then
                    show_already_installed "new_vps"
                    continue
                fi
                confirm "${PROMPT_CONFIRM}" || continue
                run_install_animation "new_vps" ;;
            2)
                submenu_wizard ;;
            3)
                run_install_animation "existing_vps" ;;
            0) return ;;
            *) warn "${ERR_INVALID_OPTION}"; sleep 1 ;;
        esac
    done
}

# ─── Already Installed Message ──────────────────────────────
show_already_installed() {
    local mode="$1"
    local SEP='━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    local title="🛡️  ${MSG_MENU_TITLE}"

    clear
    echo ""
    echo -e "  ${BD}${C}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${BD}${C}║                    ${title}                          ║${NC}"
    echo -e "  ${BD}${C}║                    ${DIM}${MSG_MENU_STATUS_CHECK}${NC}${BD}${C}               ║${NC}"
    echo -e "  ${BD}${C}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Show hardening modules
    echo -e "  ${BD}${MSG_DETECT_SYSTEM}${NC}"
    local mods=("unattended" "fail2ban" "swap" "memory" "firewall" "bbr" "limits" "logs")
    local names=("${WIZARD_MOD_1}" "${WIZARD_MOD_2}" "${WIZARD_MOD_3}" "${WIZARD_MOD_4}" "${WIZARD_MOD_5}" "${WIZARD_MOD_6}" "${WIZARD_MOD_7}" "${WIZARD_MOD_8}")
    local all_ok=true
    for i in "${!mods[@]}"; do
        if check_module_status "${mods[$i]}"; then
            echo -e "    ${G}✓${NC} ${names[$i]}"
        else
            echo -e "    ${R}✗${NC} ${names[$i]}"
            all_ok=false
        fi
    done
    echo ""

    echo -e "  ${BD}${SEP}${NC}"
    echo ""

    # Show containers
    echo -e "  ${BD}${MSG_MENU_CONTAINERS}${NC}"
    local comp_names=("wg-easy" "adguard" "unbound")
    local comp_displays=("${MSG_COMP_WG_EASY}" "${MSG_COMP_ADGUARD}" "${MSG_COMP_UNBOUND}")
    local all_running=true
    for i in "${!comp_names[@]}"; do
        local st
        st=$(get_container_status "${comp_names[$i]}")
        if [ "$st" = "running" ]; then
            echo -e "    ${G}✓${NC} ${comp_displays[$i]}  ${G}● ${MSG_STATUS_RUNNING}${NC}"
        else
            echo -e "    ${R}✗${NC} ${comp_displays[$i]}  ${R}● ${MSG_STATUS_STOPPED}${NC}"
            all_running=false
        fi
    done
    echo ""

    echo -e "  ${BD}${SEP}${NC}"
    echo ""

    if $all_ok && $all_running; then
        echo -e "  ${G}${BD}✓ ${MSG_STATUS_COMPLETE}${NC}"
        echo ""
        echo -e "    ${MSG_STATUS_COMPLETE_DESC}"
        echo -e "    ${MSG_STATUS_MANAGE}"
    else
        echo -e "  ${Y}${BD}⚠ ${MSG_STATUS_PARTIAL}${NC}"
        echo ""
        echo -e "    ${MSG_STATUS_PARTIAL_DESC}"
        echo -e "    ${MSG_WIZARD_USE_FOR_CONFIG}"
    fi
    echo ""

    pause
}

all_already_installed() {
    # Check all hardening modules (excluding DNS - now optional via toggle)
    for mod in unattended fail2ban swap memory firewall bbr limits logs; do
        check_module_status "$mod" || return 1
    done
    # Check all containers
    get_container_status wg-easy | grep -q "running" || return 1
    get_container_status adguard | grep -q "running" || return 1
    get_container_status unbound | grep -q "running" || return 1
    return 0
}

# ─── Install Animation ──────────────────────────────────────
show_install_progress() {
    local mode="$1"
    local SEP='━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    local title="🛡️  WG-Shield v2.0"
    local subtitle=""
    local steps=()

    if [ "$mode" = "new_vps" ]; then
        subtitle="${MSG_TOTAL_ARMOR_FULL_STACK}"
        steps=(
            "${MSG_COMP_DOCKER_ENGINE}"
            "${WIZARD_MOD_1}"
            "${WIZARD_MOD_2}"
            "${WIZARD_MOD_3}"
            "${WIZARD_MOD_4}"
            "${WIZARD_MOD_5}"
            "${WIZARD_MOD_6}"
            "${WIZARD_MOD_7}"
            "${WIZARD_MOD_8}"
            "${MSG_SEPARATOR}"
            "${MSG_COMP_WG_EASY}"
            "${MSG_COMP_ADGUARD}"
            "${MSG_COMP_UNBOUND}"
        )
    elif [ "$mode" = "existing_vps" ]; then
        subtitle="${MSG_INST_EXISTING_SUBTITLE}"
        steps=(
            "${MSG_COMP_WG_EASY}"
            "${MSG_COMP_ADGUARD}"
            "${MSG_COMP_UNBOUND}"
        )
    fi

    clear
    echo ""
    echo -e "  ${BD}${C}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${BD}${C}║                    ${title}                        ║${NC}"
    echo -e "  ${BD}${C}║                    ${DIM}${subtitle}${NC}${BD}${C}               ║${NC}"
    echo -e "  ${BD}${C}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    for step in "${steps[@]}"; do
        if [ "$step" = "---" ]; then
            echo ""
            echo -e "  ${BD}${SEP}${NC}"
            echo ""
            continue
        fi

        # Check if step is already done
        local already_done=false
        case "$step" in
            "${MSG_COMP_DOCKER_ENGINE}") has_docker && already_done=true ;;
            "${WIZARD_MOD_1}") check_module_status unattended && already_done=true ;;
            "${WIZARD_MOD_2}") check_module_status fail2ban && already_done=true ;;
            "${WIZARD_MOD_3}") check_module_status swap && already_done=true ;;
            "${WIZARD_MOD_4}") check_module_status memory && already_done=true ;;
            "${WIZARD_MOD_5}") check_module_status firewall && already_done=true ;;
            "${WIZARD_MOD_6}") check_module_status bbr && already_done=true ;;
            "${WIZARD_MOD_7}") check_module_status limits && already_done=true ;;
            "${WIZARD_MOD_8}") check_module_status logs && already_done=true ;;
            "${WIZARD_MOD_9}") check_module_status dns && already_done=true ;;
            "${MSG_COMP_WG_EASY}") get_container_status wg-easy | grep -q "running" && already_done=true ;;
            "${MSG_COMP_ADGUARD}") get_container_status adguard | grep -q "running" && already_done=true ;;
            "${MSG_COMP_UNBOUND}") get_container_status unbound | grep -q "running" && already_done=true ;;
        esac

        if $already_done; then
            printf "  ${G}[✔]${NC} ${step} ${DIM}(${MSG_ALREADY_DONE})${NC}\n"
            continue
        fi

        # Show spinner with animation
        local pid
        (
            local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            local i=0
            while kill -0 $$ 2>/dev/null; do
                printf "\r  ${B}[●]${NC} ${chars:$((i % 10)):1} ${step}..."
                i=$((i + 1))
                sleep 0.1
            done
        ) &
        pid=$!

        # Run the actual command (redirect output)
        case "$step" in
            "${MSG_COMP_DOCKER_ENGINE}") has_docker || install_docker >/dev/null 2>&1 ;;
            "${WIZARD_MOD_1}") mod_unattended >/dev/null 2>&1 ;;
            "${WIZARD_MOD_2}") mod_fail2ban >/dev/null 2>&1 ;;
            "${WIZARD_MOD_3}") mod_swap >/dev/null 2>&1 ;;
            "${WIZARD_MOD_4}") mod_memory >/dev/null 2>&1 ;;
            "${WIZARD_MOD_5}") mod_firewall >/dev/null 2>&1 ;;
            "${WIZARD_MOD_6}") mod_bbr >/dev/null 2>&1 ;;
            "${WIZARD_MOD_7}") mod_limits >/dev/null 2>&1 ;;
            "${WIZARD_MOD_8}") mod_logs >/dev/null 2>&1 ;;
            "${WIZARD_MOD_9}") mod_dns >/dev/null 2>&1 ;;
            "${MSG_COMP_WG_EASY}") install_comp wg-easy true ;;
            "${MSG_COMP_ADGUARD}") install_comp adguard true ;;
            "${MSG_COMP_UNBOUND}") install_comp unbound true ;;
        esac

        # Kill spinner and show checkmark
        kill $pid 2>/dev/null
        wait $pid 2>/dev/null
        printf "\r  ${G}[✔]${NC} ${step}\n"
    done

    echo ""
    echo -e "  ${BD}${SEP}${NC}"
    echo ""
    log "${LOG_INSTALL_COMPLETE}"

    # Show credentials
    echo ""
    if [ -f "/opt/wg-easy/.env" ]; then
        local wg_host pass
        wg_host=$(curl -s4 ifconfig.me 2>/dev/null || echo "YOUR_IP")
        pass=$(grep -m1 "^WG_PASSWORD=" /opt/wg-easy/.env 2>/dev/null | cut -d= -f2)
        echo -e "  ${BD}${C}WG-Easy:${NC}"
        echo "    ${MSG_RESET_URL}  http://${wg_host}:${MSG_INFO_WG_EASY_PORT}"
        [ -n "$pass" ] && echo "    ${MSG_INFO_PASSWORD}  $pass"
        echo ""
    fi
    echo -e "  ${BD}${C}${MSG_COMP_ADGUARD}:${NC}"
    echo "    ${MSG_RESET_URL}  ${MSG_INFO_VPN_URL}"
    echo ""
}

run_install_animation() {
    local mode="$1"

    if [ "$mode" = "new_vps" ] || [ "$mode" = "existing_vps" ]; then
        show_install_progress "$mode"
    fi

    pause
}

# ─── Submenu Wizard ──────────────────────────────────────────
submenu_wizard() {
    # Detect real system state
    local mod1=0 mod2=0 mod3=0 mod4=0 mod5=0 mod6=0 mod7=0 mod8=0 mod9=0
    check_module_status unattended && mod1=1
    check_module_status fail2ban && mod2=1
    check_module_status swap && mod3=1
    check_module_status memory && mod4=1
    check_module_status firewall && mod5=1
    check_module_status bbr && mod6=1
    check_module_status limits && mod7=1
    check_module_status logs && mod8=1
    check_module_status dns && mod9=1

    # Detect container state
    local conta=0 contb=0 contc=0 contd=0
    get_container_status wg-easy | grep -q "running" && conta=1
    get_container_status adguard | grep -q "running" && contb=1
    get_container_status unbound | grep -q "running" && contc=1
    [ "$conta" -eq 1 ] && [ "$contb" -eq 1 ] && [ "$contc" -eq 1 ] && contd=1

    local states=(mod1 mod2 mod3 mod4 mod5 mod6 mod7 mod8 mod9)
    local mod_names=("$WIZARD_MOD_1" "$WIZARD_MOD_2" "$WIZARD_MOD_3" "$WIZARD_MOD_4" "$WIZARD_MOD_5" "$WIZARD_MOD_6" "$WIZARD_MOD_7" "$WIZARD_MOD_8" "$WIZARD_MOD_9")

    while true; do
        clear
        echo ""
        echo -e "  ${BD}${C}${MSG_WIZARD_TITLE}${NC}"
        echo ""
        echo -e "  ${BD}${MSG_WIZARD_HARDENING_MODULES}${NC}"
        echo ""

        for i in 1 2 3 4 5 6 7 8 9; do
            local varname="${states[$((i-1))]}"
            local val="${!varname}"
            local icon
            if [ "$val" -eq 1 ]; then
                icon="${G}✓${NC}"
            else
                icon="${R}✗${NC}"
            fi
            echo -e "    [$i] $icon  ${mod_names[$((i-1))]}"
        done

        echo ""
        echo -e "  ${BD}${MSG_WIZARD_CONTAINERS}${NC}"
        echo ""

        local ca_icon; [ "$conta" -eq 1 ] && ca_icon="${G}✓${NC}" || ca_icon="${R}✗${NC}"
        local cb_icon; [ "$contb" -eq 1 ] && cb_icon="${G}✓${NC}" || cb_icon="${R}✗${NC}"
        local cc_icon; [ "$contc" -eq 1 ] && cc_icon="${G}✓${NC}" || cc_icon="${R}✗${NC}"
        local cd_icon; [ "$contd" -eq 1 ] && cd_icon="${G}✓${NC}" || cd_icon="${R}✗${NC}"

        echo -e "    [a] $ca_icon  ${MSG_INST_WG_EASY}"
        echo -e "    [b] $cb_icon  ${MSG_INST_ADGUARD}"
        echo -e "    [c] $cc_icon  ${MSG_INST_UNBOUND}"
        echo -e "    [d] $cd_icon  ${MSG_INST_FULL_STACK}"
        echo ""
        echo "    [0] ← ${MSG_MENU_VOLTAR_MAIN}"
        echo ""

        flush_stdin
        read -rp "  ${MSG_MENU_CHOOSE}" choice

        case "$choice" in
            [1-9])
                local varname="${states[$((choice-1))]}"
                local val="${!varname}"
                if [ "$val" -eq 1 ]; then
                    eval "$varname=0"
                    echo -e "  ${R}[✗]${NC} ${mod_names[$((choice-1))]} ${MSG_REMOVED}"
                else
                    eval "$varname=1"
                    echo -e "  ${G}[✔]${NC} ${mod_names[$((choice-1))]} ${MSG_APPLIED}"
                fi
                pause ;;
            a)
                if [ "$conta" -eq 1 ]; then conta=0; echo -e "  ${R}[✗]${NC} WG-Easy ${MSG_REMOVED}"
                else conta=1; echo -e "  ${G}[✔]${NC} WG-Easy ${MSG_SELECTED}"; fi
                pause ;;
            b)
                if [ "$contb" -eq 1 ]; then contb=0; echo -e "  ${R}[✗]${NC} ${MSG_COMP_ADGUARD} ${MSG_REMOVED}"
                else contb=1; echo -e "  ${G}[✔]${NC} ${MSG_COMP_ADGUARD} ${MSG_SELECTED}"; fi
                pause ;;
            c)
                if [ "$contc" -eq 1 ]; then contc=0; echo -e "  ${R}[✗]${NC} ${MSG_COMP_UNBOUND} ${MSG_REMOVED}"
                else contc=1; echo -e "  ${G}[✔]${NC} ${MSG_COMP_UNBOUND} ${MSG_SELECTED}"; fi
                pause ;;
            d)
                if [ "$contd" -eq 1 ]; then
                    contd=0; conta=0; contb=0; contc=0
                    echo -e "  ${R}[✗]${NC} ${MSG_COMP_FULL_STACK} ${MSG_REMOVED}"
                else
                    contd=1; conta=1; contb=1; contc=1
                    echo -e "  ${G}[✔]${NC} ${MSG_COMP_FULL_STACK} ${MSG_SELECTED}"
                fi
                pause ;;
            0)
                log "${LOG_WIZARD_COMPLETE}"
                return ;;
            *)
                warn "${ERR_INVALID_OPTION}"; sleep 1 ;;
        esac
    done
}

# ─── Submenu Manage ──────────────────────────────────────────
submenu_manage() {
    while true; do
        clear
        echo ""
        echo -e "  ${BD}${C}${MSG_MENU_MANAGE}${NC}"
        echo ""

        local installed_raw
        installed_raw=$(get_installed_list)

        if [ -z "$(echo "$installed_raw" | tr -d '[:space:]')" ]; then
            echo "  ${MSG_MGR_NONE_INSTALLED}."
            echo ""; pause; return
        fi

        echo -e "  ${BD}${MSG_MGR_INSTALLED}${NC}"
        echo ""
        local names=()
        while IFS='|' read -r _mn_name _mn_display _mn_ports _mn_status _mn_dir; do
            [ -z "$_mn_name" ] && continue
            if [ "$_mn_status" = "running" ]; then
                echo -e "    ${G}●${NC} $_mn_display :${_mn_ports} ${MSG_STATUS_RUNNING}"
            else
                echo -e "    ${R}●${NC} $_mn_display :${_mn_ports} ${MSG_STATUS_STOPPED}"
            fi
            names+=("$_mn_name")
        done <<< "$installed_raw"

        echo ""
        echo -e "  ${BD}${MSG_MENU_WHAT_TO_DO}${NC}"
        echo ""

        # Show DNS status
        if check_module_status dns; then
            echo -e "    DNS:  ${G}${BD}● ${MSG_DNS_STATUS_PUBLIC}${NC}  ${DIM}(${MSG_DNS_PORT_OPEN_RATELIMIT})${NC}"
        else
            echo -e "    DNS:  ${Y}${BD}○ ${MSG_DNS_STATUS_PRIVATE}${NC}   ${DIM}(${MSG_DNS_VPN_ONLY})${NC}"
        fi

        # Show WG-Easy credentials
        if [ -f "/opt/wg-easy/.env" ]; then
            local wg_host wg_pass
            wg_host=$(grep -m1 "^WG_HOST=" /opt/wg-easy/.env 2>/dev/null | cut -d= -f2)
            wg_pass=$(grep -m1 "^WG_PASSWORD=" /opt/wg-easy/.env 2>/dev/null | cut -d= -f2)
            if [ -n "$wg_host" ] || [ -n "$wg_pass" ]; then
                echo ""
                echo -e "  ${BD}🔑 ${MSG_COMP_WG_EASY}${NC}"
                [ -n "$wg_host" ] && echo "    ${MSG_RESET_URL}   http://${wg_host}:${MSG_INFO_WG_EASY_PORT}"
                [ -n "$wg_pass" ] && echo -e "    ${MSG_INFO_PASSWORD} ${BD}${wg_pass}${NC}"
            fi
        fi
        echo ""

        echo "    ${MSG_MGR_UPDATE}"
        echo "    ${MSG_MGR_STOP}"
        echo "    ${MSG_MGR_CONNECT}"
        echo "    ${MSG_MGR_STATUS}"
        echo "    ${MSG_MGR_LOGS}"
        echo "    ${MSG_MGR_BACKUP}"
        echo "    ${MSG_MGR_ROLLBACK}"
        echo "    ${MSG_MGR_REMOVE}"
        echo "    ${MSG_TOGGLE_DNS}"
        echo "    ${MSG_RESET_PASSWORD}"
        echo "    [0] ← ${MSG_MENU_VOLTAR_MAIN}"
        echo ""

        flush_stdin
        read -rp "  ${MSG_MENU_CHOOSE}" action
        [ "$action" = "0" ] && return
        action=$(echo "$action" | tr '[:upper:]' '[:lower:]')

        local comp_name
        case "$action" in
            u) comp_name=$(select_installed_comp "${PROMPT_WHICH_CONTAINER_UPDATE}") || continue
               update_comp "$comp_name"; pause ;;
            d) comp_name=$(select_installed_comp "${PROMPT_WHICH_CONTAINER_STOP}") || continue
               stop_comp "$comp_name"; pause ;;
            c)
                local running_names=()
                for n in "${names[@]}"; do
                    local st
                    st=$(get_container_status "$(parse_comp "$n" 6)")
                    [ "$st" = "running" ] && running_names+=("$n")
                done
                if [ ${#running_names[@]} -eq 0 ]; then
                    warn "${MSG_NO_CONTAINER_RUNNING} ${MSG_STATUS_RUNNING}"; pause; continue
                fi
                comp_name=$(select_installed_comp "${PROMPT_WHICH_CONTAINER_CONNECT}") || continue
                shell_comp "$comp_name" ;;
            s)
                for name in "${names[@]}"; do status_comp "$name"; done
                pause ;;
            l) comp_name=$(select_installed_comp "${PROMPT_WHICH_CONTAINER_LOGS}") || continue
               logs_comp "$comp_name" ;;
            b) comp_name=$(select_installed_comp "${PROMPT_WHICH_CONTAINER_BACKUP}") || continue
               create_backup "$comp_name" "manual"; pause ;;
            r) comp_name=$(select_installed_comp "${PROMPT_WHICH_CONTAINER_RESTORE}") || continue
               restore_backup "$comp_name"; pause ;;
            x) comp_name=$(select_installed_comp "${PROMPT_WHICH_CONTAINER_REMOVE}") || continue
               remove_comp "$comp_name"; pause ;;
            t) toggle_dns_public; pause ;;
            p) reset_wg_password; pause ;;
            *) warn "${ERR_INVALID_OPTION}" ;;
        esac
    done
}

# ─── Submenu Language ─────────────────────────────────────────
submenu_language() {
    while true; do
        clear
        echo ""
        echo -e "  ${BD}${C}${MSG_MENU_LANG}${NC}"
        echo ""
        printf "  %s ${Y}%s${NC}\n" "${MSG_LANG_CURRENT}" "$WS_LANG"
        echo ""
        echo "  [1] ${MSG_LANG_PORTUGUESE}"
        echo "  [2] ${MSG_LANG_ENGLISH}"
        echo ""
        echo "  [0] ${MSG_MENU_VOLTAR_MAIN}"
        echo ""

        read -rp "  ${MSG_MENU_CHOOSE}" ch

        case "$ch" in
            1)
                if [ "$WS_LANG" = "pt_BR" ]; then
                    info "Já está em ${MSG_LANG_PORTUGUESE}."
                else
                    echo "pt_BR" > "${CONFIG_DIR}/lang"
                    log "${LOG_LANG_CHANGED}"
                    echo ""
                    warn "${MSG_LANG_RESTART}"
                fi
                pause
                ;;
            2)
                if [ "$WS_LANG" = "en_US" ]; then
                    info "Already in ${MSG_LANG_ENGLISH}."
                else
                    echo "en_US" > "${CONFIG_DIR}/lang"
                    log "${LOG_LANG_CHANGED}"
                    echo ""
                    warn "${MSG_LANG_RESTART}"
                fi
                pause
                ;;
            0) break ;;
            *) warn "${ERR_INVALID_OPTION}" ;;
        esac
    done
}

# ─── Submenu Backups ─────────────────────────────────────────
submenu_backups() {
    while true; do
        clear
        echo ""
        echo -e "  ${BD}${C}${MSG_MENU_BACKUPS}${NC}"
        echo ""

        echo "    [1] ${MSG_BK_LIST_ALL}"
        echo "    [2] ${MSG_BK_LIST_BY_COMP}"
        echo "    [3] ${MSG_BK_CREATE}"
        echo "    [4] ${MSG_BK_RESTORE}"
        echo "    [0] ← ${MSG_MENU_VOLTAR_MAIN}"
        echo ""

        flush_stdin
        read -rp "  ${MSG_MENU_CHOOSE}" choice

        case "$choice" in
            1) list_backups "all"; pause ;;
            2)
                echo ""
                echo "  ${MSG_INST_CONTAINERS}"
                local idx=1 comp_names=()
                while IFS='|' read -r cat name display _; do
                    [ -z "$name" ] && continue
                    echo "    [$idx] $display"
                    comp_names+=("$name"); idx=$((idx + 1))
                done <<< "$COMPONENTS"
                echo "    [0] ${MSG_MENU_VOLTAR}"
                echo ""
                flush_stdin
                read -rp "  ${MSG_MENU_CHOOSE}" ch
                [ "$ch" = "0" ] && continue
                if [ "$ch" -ge 1 ] 2>/dev/null && [ "$ch" -le "${#comp_names[@]}" ] 2>/dev/null; then
                    list_backups "${comp_names[$((ch - 1))]}"
                fi
                pause
                ;;
            3)
                echo ""
                echo "  ${MSG_BK_WHAT_BACKUP}"
                echo "    [1] ${MSG_BK_COMP_SPECIFIC}"
                echo "    [2] ${MSG_BK_VPS_STATE}"
                echo "    [0] ${MSG_MENU_VOLTAR}"
                echo ""
                flush_stdin
                read -rp "  ${MSG_MENU_CHOOSE}" bk_ch
                case "$bk_ch" in
                    1)
                        local comp_name
                        comp_name=$(select_installed_comp "${PROMPT_WHICH_CONTAINER}") || continue
                        create_backup "$comp_name" "manual"; pause
                        ;;
                    2) create_backup "vps" "manual"; pause ;;
                esac
                ;;
            4)
                local comp_name
                comp_name=$(select_installed_comp "${PROMPT_WHICH_CONTAINER_RESTORE}") || continue

                local bk_path="${BACKUP_DIR}/${comp_name}"
                if [ ! -d "$bk_path" ]; then
                    warn  "${ERR_NO_BACKUP_COMP} $comp_name"; pause; continue
                fi

                echo ""
                local bk_idx=1 bk_timestamps=()
                for bk in $(ls -1r "$bk_path" 2>/dev/null | grep -v "^latest$"); do
                    local reason=""
                    [ -f "$bk_path/$bk/meta.json" ] && reason=$(grep '"reason"' "$bk_path/$bk/meta.json" | cut -d'"' -f4)
                    local bk_size
                    bk_size=$(du -sh "$bk_path/$bk" 2>/dev/null | cut -f1)
                    echo "    [$bk_idx] $bk  ($reason, $bk_size)"
                    bk_timestamps+=("$bk")
                    bk_idx=$((bk_idx + 1))
                done

                if [ "$bk_idx" -eq 1 ]; then
                    warn "${ERR_NO_BACKUP}"; pause; continue
                fi

                echo "    [0] ${MSG_MENU_VOLTAR}"
                echo ""
                flush_stdin
                read -rp "  ${MSG_MENU_CHOOSE}" bk_ch
                [ "$bk_ch" = "0" ] && continue

                if [ "$bk_ch" -ge 1 ] 2>/dev/null && [ "$bk_ch" -lt "$bk_idx" ] 2>/dev/null; then
                    restore_backup "$comp_name" "${bk_timestamps[$((bk_ch - 1))]}"
                fi
                pause
                ;;
            0) return ;;
            *) warn "${ERR_INVALID_OPTION}" ;;
        esac
    done
}

# ─── Interactive Menu Loop ───────────────────────────────────
interactive_menu() {
    while true; do
        show_main_menu
        flush_stdin
        read -rp "  ${MSG_MENU_CHOOSE}" choice

        case "$choice" in
            1) submenu_install ;;
            2)
                local installed_raw
                installed_raw=$(get_installed_list)
                if [ -n "$(echo "$installed_raw" | tr -d '[:space:]')" ]; then
                    submenu_manage
                else
                    warn "${MSG_MGR_NONE_INSTALLED} [1] ${MSG_MENU_INSTALL}."
                    pause
                fi
                ;;
            3) submenu_backups ;;
            l|L) submenu_language ;;
            0) echo ""; log "${LOG_GOODBYE}"; exit 0 ;;
            *) warn "${ERR_INVALID_OPTION}: $choice" ;;
        esac
    done
}
