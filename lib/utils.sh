# lib/utils.sh - Cores, logging, helpers

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
C='\033[0;36m'; BD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

log()  { echo -e "${G}[✔]${NC} $1"; }
warn() { echo -e "${Y}[!]${NC} $1"; }
err()  { echo -e "${R}[✘]${NC} $1"; exit 1; }
info() { echo -e "${B}[●]${NC} $1"; }

spinner() {
    local msg="$1" chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    for i in $(seq 1 8); do
        printf "\r  ${B}[●]${NC} ${chars:$((i % ${#chars})):1} ${msg}..."
        sleep 0.08
    done
    printf "\r  ${G}[✔]${NC} ${msg}... OK!          \n"
}

flush_stdin() {
    while read -r -t 0 2>/dev/null; do read -r -t 0.1 2>/dev/null; done
}

confirm() {
    if [ "$AUTO_YES" = "true" ]; then return 0; fi
    read -rp "${1:-${PROMPT_CONFIRM}} " c; [[ -z "$c" || "$c" =~ ^[yY]$ ]]
}
pause()   { if [ "$AUTO_YES" = "true" ]; then return; fi; read -rp "  ${PROMPT_ENTER}" _; }

has_docker() { command -v docker &>/dev/null && docker info &>/dev/null; }

get_container_status() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${1}$" && echo "running" || echo "stopped"
}

parse_comp() {
    local comp="$1" field="$2"
    [ -z "$comp" ] && return 1
    local _cat _name _display _ports _pubports _repo _container _dir
    while IFS='|' read -r _cat _name _display _ports _pubports _repo _container _dir; do
        [ -z "$_name" ] && continue
        if [ "$_name" = "$comp" ]; then
            case "$field" in
                1) echo "$_name" ;;
                2) echo "$_display" ;;
                3) echo "$_ports" ;;
                4) echo "$_pubports" ;;
                5) echo "$_repo" ;;
                6) echo "$_container" ;;
                7) echo "$_dir" ;;
                cat) echo "$_cat" ;;
            esac
            return 0
        fi
    done <<< "$COMPONENTS"
    return 1
}

comp_info_valid() {
    local dir
    dir=$(parse_comp "$1" 7)
    [ -n "$dir" ]
}

comp_exists() {
    local dir
    dir=$(parse_comp "$1" 7)
    [ -d "$dir" ] && ( [ -f "$dir/docker-compose.yml" ] || [ -f "$dir/compose.yml" ] )
}

get_installed_list() {
    local result=""
    while IFS='|' read -r _gi_cat _gi_name _gi_display _gi_ports _gi_pubports _gi_repo _gi_container _gi_dir; do
        [ -z "$_gi_name" ] && continue
        if [ -d "$_gi_dir" ] && ( [ -f "$_gi_dir/docker-compose.yml" ] || [ -f "$_gi_dir/compose.yml" ] ); then
            local st
            st=$(get_container_status "$_gi_container")
            result="${result}${_gi_name}|${_gi_display}|${_gi_ports}|${st}|${_gi_dir}\n"
        fi
    done <<< "$COMPONENTS"
    printf '%b' "$result"
}

check_module_status() {
    case "$1" in
        unattended) dpkg -l 2>/dev/null | grep -qw unattended-upgrades ;;
        fail2ban)    systemctl is-active --quiet fail2ban 2>/dev/null ;;
        swap)        swapon --show 2>/dev/null | grep -q swapfile ;;
        memory)      [ "$(sysctl -n vm.swappiness 2>/dev/null)" = "10" ] ;;
        firewall)    iptables -L INPUT -n 2>/dev/null | grep -q "DROP" ;;
        bbr)         sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr ;;
        limits)      grep -q "nofile 65535" /etc/security/limits.conf 2>/dev/null ;;
        logs)        grep -q "SystemMaxUse=200M" /etc/systemd/journald.conf 2>/dev/null ;;
        dns)         iptables -L INPUT -n 2>/dev/null | grep -q "limit:" ;;
        *)           return 1 ;;
    esac
}
