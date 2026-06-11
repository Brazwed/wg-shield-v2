#!/usr/bin/env bash

# ============================================================
# WG-Shield v2.0 - por Brazwed
# https://github.com/Brazwed/wg-shield
# ============================================================

VERSION="2.0"
AUTHOR="Brazwed"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Bootstrap: if running without lib/ (curl | bash), clone repo and re-exec
_WG_SHIELD_REPO="https://github.com/Brazwed/wg-shield-v2.git"
_WG_SHIELD_DIR="/opt/wg-shield"
if [ ! -d "${SCRIPT_DIR}/lib" ]; then
    if [ "$(id -u)" -ne 0 ]; then
        echo "Run as root: sudo bash $0" >&2; exit 1
    fi
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y git >/dev/null 2>&1 || true
    if [ -d "$_WG_SHIELD_DIR/.git" ]; then
        git -C "$_WG_SHIELD_DIR" pull --quiet || true
    else
        rm -rf "$_WG_SHIELD_DIR"
        git clone --quiet "$_WG_SHIELD_REPO" "$_WG_SHIELD_DIR"
    fi
    exec bash "$_WG_SHIELD_DIR/wgshield.sh" "$@"
fi

# Flags
AUTO_YES=false

# Language detection
CONFIG_DIR="${HOME}/.wg-shield"
WS_LANG="en_US"
if [ -f "${CONFIG_DIR}/lang" ]; then
    WS_LANG=$(cat "${CONFIG_DIR}/lang")
else
    case "${LANG:-en_US}" in
        pt_*|br_*) WS_LANG="pt_BR" ;;
    esac
fi
source "${SCRIPT_DIR}/lib/lang/${WS_LANG}.sh" 2>/dev/null || source "${SCRIPT_DIR}/lib/lang/en_US.sh"

# Configuração
GITHUB_BASE="${GITHUB_BASE:-https://github.com/Brazwed}"
BACKUP_DIR="${HOME}/.wg-shield/backups"

COMPONENTS="vpn|wg-easy|WG-Easy|51820/udp,51821/tcp||wg-easy-v2|wg-easy|/opt/wg-easy
dns|adguard|AdGuard Home|3000/tcp|53/udp,53/tcp|adguard-v2|adguard|/opt/adguard
dns|unbound|Unbound DNS|53/udp||unbound-v2|unbound|/opt/unbound"

FW_TYPE="none"
FW_ACTIVE=false

SSH_PORT=22

# Load modules (order matters: utils first, then others)
source "$SCRIPT_DIR/lib/utils.sh"
for lib in "$SCRIPT_DIR"/lib/*.sh; do
    case "$lib" in
        */lang/*|*/utils.sh) ;; # Already loaded
        *) source "$lib" ;;
    esac
done

# ============================================================
# CLEANUP TRAP
# ============================================================

cleanup() {
    EXIT_CODE=$?
    if [ "$EXIT_CODE" -ne 0 ] && [ "$_hardening_applied" = "true" ]; then
        echo ""
        warn "${MSG_CLEANUP_SCRIPT_EXIT} $EXIT_CODE."
        info "${MSG_CLEANUP_RESTORING}"
        for BAK in /etc/sysctl.conf.bak /etc/security/limits.conf.bak /etc/systemd/journald.conf.bak; do
            if [ -f "$BAK" ]; then
                ORIGINAL="${BAK%.bak}"
                if [ -f "$ORIGINAL" ] && [ "$(stat -c %Y "$BAK" 2>/dev/null)" -gt "$(stat -c %Y "$ORIGINAL" 2>/dev/null)" ]; then
                    cp "$BAK" "$ORIGINAL"
                    log "${MSG_CLEANUP_RESTORED} $ORIGINAL"
                fi
            fi
        done
    fi
}
_hardening_applied="false"
trap cleanup EXIT

# ============================================================
# PRE-FLIGHT CHECKS
# ============================================================

preflight() {
    if [ "$(id -u)" -ne 0 ]; then
        err "${ERR_MUST_BE_ROOT}"
    fi

    info "${PREFLIGHT_CHECKING_NETWORK}"
    if ! curl -sf --connect-timeout 5 -o /dev/null https://1.1.1.1 2>/dev/null; then
        err "${ERR_NO_NETWORK}"
    fi

    info "${PREFLIGHT_DETECTING_SSH}"
    SSH_PORT=$(ss -tlnp 2>/dev/null | grep sshd | awk '{print $4}' | awk -F: '{print $NF}' | head -n 1 || true)
    [ -z "$SSH_PORT" ] && SSH_PORT=22
    log "${PREFLIGHT_SSH_PORT} $SSH_PORT"
}

# ============================================================
# ARGS
# ============================================================

parse_args() {
    local action="${1:-}"
    shift 2>/dev/null || true
    local args="$*"

    case "$action" in
        install)
            if [ -z "$args" ]; then
                err "${MSG_USAGE_INSTALL}"
            fi
            for arg in $args; do
                case "$arg" in
                    docker) install_docker ;;
                    wg-easy|adguard|unbound) install_comp "$arg" ;;
                    all)
                        install_docker
                        install_comp wg-easy
                        install_comp adguard
                        install_comp unbound
                        ;;
                    *) warn "${ERR_UNKNOWN_COMP_SHORT}" ;;
                esac
            done
            ;;
        up)
            [ -z "$args" ] && err "${MSG_USAGE_UP}"
            for comp in $args; do
                if [ "$comp" = "all" ]; then
                    start_comp wg-easy; start_comp adguard; start_comp unbound
                else
                    start_comp "$comp"
                fi
            done
            ;;
        down)
            [ -z "$args" ] && err "${MSG_USAGE_DOWN}"
            for comp in $args; do
                if [ "$comp" = "all" ]; then
                    stop_comp wg-easy; stop_comp adguard; stop_comp unbound
                else
                    stop_comp "$comp"
                fi
            done
            ;;
        restart)
            [ -z "$args" ] && err "${MSG_USAGE_RESTART}"
            for comp in $args; do
                if [ "$comp" = "all" ]; then
                    restart_comp wg-easy; restart_comp adguard; restart_comp unbound
                else
                    restart_comp "$comp"
                fi
            done
            ;;
        update)
            [ -z "$args" ] && err "${MSG_USAGE_UPDATE}"
            for comp in $args; do
                if [ "$comp" = "all" ]; then
                    update_comp wg-easy; update_comp adguard; update_comp unbound
                else
                    update_comp "$comp"
                fi
            done
            ;;
        status)
            if [ -z "$args" ]; then
                while IFS='|' read -r _ name _; do
                    [ -n "$name" ] && comp_exists "$name" && status_comp "$name"
                done <<< "$COMPONENTS"
            else
                for comp in $args; do status_comp "$comp"; done
            fi
            ;;
        logs)
            [ -z "$args" ] && err "${MSG_USAGE_LOGS}"
            logs_comp "$args"
            ;;
        shell)
            [ -z "$args" ] && err "${MSG_USAGE_SHELL}"
            shell_comp "$args"
            ;;
        remove)
            [ -z "$args" ] && err "${MSG_USAGE_REMOVE}"
            for comp in $args; do
                if [ "$comp" = "all" ]; then
                    remove_comp wg-easy; remove_comp adguard; remove_comp unbound
                else
                    remove_comp "$comp"
                fi
            done
            ;;
        detect)
            detect_vps_state
            ;;
        lang)
            mkdir -p "$CONFIG_DIR"
            case "${args:-}" in
                pt|pt_BR) echo "pt_BR" > "${CONFIG_DIR}/lang"; log "${LOG_LANG_CHANGED}" ;;
                en|en_US) echo "en_US" > "${CONFIG_DIR}/lang"; log "${LOG_LANG_CHANGED}" ;;
                *) err "${MSG_USAGE_LANG}" ;;
            esac
            ;;
        backup)
            if [ -z "$args" ] || [ "$args" = "all" ]; then
                create_backup "vps" "manual"
                while IFS='|' read -r _ bn _; do
                    [ -n "$bn" ] && comp_exists "$bn" && create_backup "$bn" "manual"
                done <<< "$COMPONENTS"
            elif [ "$args" = "vps" ]; then
                create_backup "vps" "manual"
            else
                for comp in $args; do
                    comp_exists "$comp" && create_backup "$comp" "manual" || warn "${ERR_NOT_INSTALLED}"
                done
            fi
            ;;
        backups)
            list_backups "${args:-all}"
            ;;
        rollback)
            local rt="${args%% *}"
            local rts="${args#* }"
            [ "$rts" = "$rt" ] && rts=""
            [ -z "$rt" ] && err "${MSG_USAGE_ROLLBACK}"
            restore_backup "$rt" "$rts"
            ;;
        *)
            err "${MSG_HELP_USAGE}
  \$0                           ${MSG_HELP_INSTALL} (menu)
  \$0 install docker            ${MSG_HELP_INSTALL_DOCKER}
  \$0 install <comp>            ${MSG_HELP_INSTALL} component
  \$0 install all               ${MSG_HELP_INSTALL} all components
  \$0 up <comp>                 ${MSG_HELP_UP}
  \$0 down <comp>               ${MSG_HELP_DOWN}
  \$0 restart <comp>            ${MSG_HELP_RESTART}
  \$0 update <comp>             ${MSG_HELP_UPDATE}
  \$0 status [comp]             ${MSG_HELP_STATUS}
  \$0 logs <comp>               ${MSG_HELP_LOGS}
  \$0 shell <comp>              ${MSG_HELP_SHELL}
  \$0 remove <comp>             ${MSG_HELP_REMOVE}
  \$0 detect                    ${MSG_HELP_DETECT}
  \$0 backup [comp|vps|all]     ${MSG_HELP_BACKUP}
  \$0 backups [comp]            ${MSG_HELP_BACKUPS}
  \$0 rollback <comp> [ts]      ${MSG_HELP_ROLLBACK}
  \$0 lang <pt|en>              ${MSG_HELP_LANG}

${MSG_HELP_CONTAINERS}: wg-easy, adguard, unbound"
            ;;
    esac
}

# ============================================================
# MAIN
# ============================================================

main() {
    # Handle flags before root check
    case "${1:-}" in
        -v|--version)
            echo "${MSG_MENU_TITLE} v${VERSION} ${MSG_MENU_AUTHOR}"
            echo "${GITHUB_BASE}/wg-shield"
            exit 0
            ;;
        -h|--help)
            echo "${MSG_HELP_USAGE}"
            echo ""
            echo "${MSG_HELP_ACTIONS}"
            echo "  install <comp>            ${MSG_HELP_INSTALL}"
            echo "  install docker            ${MSG_HELP_INSTALL_DOCKER}"
            echo "  install all               ${MSG_HELP_INSTALL} all"
            echo "  up <comp>                 ${MSG_HELP_UP}"
            echo "  down <comp>               ${MSG_HELP_DOWN}"
            echo "  restart <comp>            ${MSG_HELP_RESTART}"
            echo "  update <comp>             ${MSG_HELP_UPDATE}"
            echo "  status [comp]             ${MSG_HELP_STATUS}"
            echo "  logs <comp>               ${MSG_HELP_LOGS}"
            echo "  shell <comp>              ${MSG_HELP_SHELL}"
            echo "  remove <comp>             ${MSG_HELP_REMOVE}"
            echo "  detect                    ${MSG_HELP_DETECT}"
            echo "  backup [comp|vps|all]     ${MSG_HELP_BACKUP}"
            echo "  backups [comp]            ${MSG_HELP_BACKUPS}"
            echo "  rollback <comp> [ts]      ${MSG_HELP_ROLLBACK}"
            echo ""
            echo "${MSG_HELP_CONTAINERS}: wg-easy, adguard, unbound"
            echo ""
            echo "${MSG_HELP_OPTIONS}"
            echo "  -v, --version             ${MSG_HELP_SHOW_VERSION}"
            echo "  -h, --help                ${MSG_HELP_SHOW_HELP}"
            echo "  -y, --yes                 ${MSG_HELP_NON_INTERACTIVE}"
            echo "  lang <pt|en>              ${MSG_HELP_LANG}"
            exit 0
            ;;
    esac

    preflight
    mkdir -p "$BACKUP_DIR"

    # Parse --yes flag
    local clean_args=()
    for arg in "$@"; do
        if [ "$arg" = "-y" ] || [ "$arg" = "--yes" ]; then
            AUTO_YES=true
        else
            clean_args+=("$arg")
        fi
    done

    if [ ${#clean_args[@]} -gt 0 ]; then
        parse_args "${clean_args[@]}"
        exit 0
    fi

    interactive_menu
}

main "$@"
