# lib/hardening.sh - Módulos de hardening (do script.sh original)
# Note: SSH_PORT is detected in wgshield.sh:88-90 and used here

mod_unattended() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_UNATTENDED_MSG}${NC}"
    if ! dpkg -l | grep -qw unattended-upgrades; then
        DEBIAN_FRONTEND=noninteractive apt install -y unattended-upgrades
    fi
    mkdir -p /etc/apt/apt.conf.d
    if ! grep -q '^APT::Periodic::Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null; then
        cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
    fi
    warn "${HARDEN_UNATTENDED_REBOOT_WARN}"
    sed -i 's|^.*Unattended-Upgrade::Automatic-Reboot .*|Unattended-Upgrade::Automatic-Reboot "true";|' /etc/apt/apt.conf.d/50unattended-upgrades
    sed -i 's|^.*Unattended-Upgrade::Automatic-Reboot-Time .*|Unattended-Upgrade::Automatic-Reboot-Time "04:00";|' /etc/apt/apt.conf.d/50unattended-upgrades
    log "${HARDEN_UNATTENDED_SUCCESS}"
}

mod_fail2ban() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_FAIL2BAN_MSG}${NC}"
    if ! dpkg -l | grep -qw fail2ban; then
        apt install -y fail2ban
    fi

    if [ ! -f /etc/fail2ban/jail.local ]; then
cat <<EOF | tee /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
bantime.increment = true
bantime.factor = 2
bantime.maxtime = 86400

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
backend = systemd
EOF
        systemctl restart fail2ban
    fi

    if ! systemctl is-active --quiet fail2ban; then
        systemctl enable fail2ban
        systemctl start fail2ban
    fi
    log "${HARDEN_FAIL2BAN_SUCCESS}"
}

mod_swap() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_SWAP_MSG}${NC}"
    SWAPFILE="/swapfile"
    if ! swapon --show | grep -q "$SWAPFILE"; then
        if [ ! -f "$SWAPFILE" ]; then
            local avail_mb
            avail_mb=$(df --output=avail / | tail -1 | tr -d ' ')
            if [ "$avail_mb" -lt 2300 ]; then
                warn "${HARDEN_SWAP_NOSPACE}"
                return 1
            fi
            dd if=/dev/zero of=$SWAPFILE bs=1M count=2048 status=progress
            chmod 600 $SWAPFILE
            mkswap $SWAPFILE
            grep -q "^$SWAPFILE " /etc/fstab || echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
        fi
        swapon $SWAPFILE
        log "${HARDEN_SWAP_SUCCESS}"
    else
        info "${HARDEN_SWAP_ALREADY}"
    fi
}

mod_memory() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_MEMORY_MSG}${NC}"
    if [ "$(sysctl -n vm.swappiness 2>/dev/null)" != "10" ]; then
        if grep -q "^vm.swappiness=" /etc/sysctl.conf; then
            sed -i 's/^vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf
        else
            echo "vm.swappiness=10" >> /etc/sysctl.conf
        fi
        sysctl -w vm.swappiness=10
    fi
    if [ "$(sysctl -n vm.vfs_cache_pressure 2>/dev/null)" != "50" ]; then
        if grep -q "^vm.vfs_cache_pressure=" /etc/sysctl.conf; then
            sed -i 's/^vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=50/' /etc/sysctl.conf
        else
            echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
        fi
        sysctl -w vm.vfs_cache_pressure=50
    fi
    log "${HARDEN_MEMORY_SUCCESS}"
}

mod_firewall() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_FIREWALL_MSG}${NC}"
    if ! command -v iptables >/dev/null 2>&1; then
        err "${HARDEN_FIREWALL_IPTABLES}"
    fi

    echo -e "  ${BD}${C}${HARDEN_FIREWALL_IP4}${NC}"

    RULES=(
        "-A INPUT -i lo -j ACCEPT"
        "-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
        "-A INPUT -p icmp -j ACCEPT"
        "-A INPUT -p tcp --dport $SSH_PORT -j ACCEPT"
        "-A INPUT -p udp --dport 51820 -j ACCEPT"
        "-A INPUT -p tcp --dport 51821 -j ACCEPT"
    )

    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    for RULE in "${RULES[@]}"; do
        if ! iptables -C ${RULE:3} 2>/dev/null; then
            iptables $RULE
        fi
    done

    echo -e "  ${BD}${C}${HARDEN_FIREWALL_IP6}${NC}"
    ip6tables -P INPUT DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT ACCEPT

    RULES_IPV6=(
        "-A INPUT -i lo -j ACCEPT"
        "-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
        "-A INPUT -p ipv6-icmp -j ACCEPT"
        "-A INPUT -p tcp --dport $SSH_PORT -j ACCEPT"
        "-A INPUT -p udp --dport 51820 -j ACCEPT"
    )

    for RULE in "${RULES_IPV6[@]}"; do
        if ! ip6tables -C ${RULE:3} 2>/dev/null; then
            ip6tables $RULE
        fi
    done

    if ! dpkg -l | grep -qw iptables-persistent; then
        DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent
        netfilter-persistent save
        netfilter-persistent enable
    else
        netfilter-persistent save
    fi
    log "${HARDEN_FIREWALL_SUCCESS}"
}

mod_bbr() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_BBR_MSG}${NC}"
    for CONF in /etc/sysctl.conf /etc/sysctl.d/99-wgshield.conf /etc/security/limits.conf /etc/systemd/journald.conf; do
        if [ ! -f "${CONF}.bak" ]; then
            cp "$CONF" "${CONF}.bak"
            echo "    [✔] ${HARDEN_BBR_BACKUP}: ${CONF}.bak"
        fi
    done

    _hardening_applied="true"

    echo -e "  ${BD}${C}${HARDEN_BBR_MODULE}${NC}"
    if ! lsmod | grep -q tcp_bbr; then
        modprobe tcp_bbr
        if ! grep -q "tcp_bbr" /etc/modules-load.d/modules.conf 2>/dev/null; then
            echo "tcp_bbr" | tee -a /etc/modules-load.d/modules.conf
        fi
    fi

    echo -e "  ${BD}${C}${HARDEN_BBR_TUNING}${NC}"
    declare -A SYSCTL_VALUES=(
        ["net.ipv4.ip_forward"]="1"
        ["net.ipv6.conf.all.forwarding"]="1"
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["fs.file-max"]="100000"
        ["net.core.rmem_max"]="2500000"
        ["net.core.wmem_max"]="2500000"
        ["net.ipv4.conf.all.rp_filter"]="1"
        ["net.ipv4.conf.all.accept_redirects"]="0"
        ["net.ipv4.conf.all.accept_source_route"]="0"
        ["kernel.printk"]="3 3 3 3"
    )

    SYSCTL_DROPIN="/etc/sysctl.d/99-wgshield.conf"
    local dropin_tmp
    dropin_tmp=$(mktemp)
    for PARAM in "${!SYSCTL_VALUES[@]}"; do
        VALUE="${SYSCTL_VALUES[$PARAM]}"
        echo "$PARAM=$VALUE" >> "$dropin_tmp"
        sysctl -w "$PARAM=$VALUE" >/dev/null 2>&1 || true
    done
    mv "$dropin_tmp" "$SYSCTL_DROPIN"
    log "${HARDEN_BBR_SUCCESS}"
}

mod_limits() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_LIMITS_MSG}${NC}"
    if ! grep -q "nofile 65535" /etc/security/limits.conf; then
        echo "* soft nofile 65535" | tee -a /etc/security/limits.conf
        echo "* hard nofile 65535" | tee -a /etc/security/limits.conf
        log "${HARDEN_LIMITS_SUCCESS}"
    else
        info "${HARDEN_LIMITS_ALREADY}"
    fi
}

mod_logs() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_LOGS_MSG}${NC}"
    JOURNAL_CONF="/etc/systemd/journald.conf"
    if grep -q "^#\?SystemMaxUse=" $JOURNAL_CONF; then
        sed -i 's/^#\?SystemMaxUse=.*/SystemMaxUse=200M/' $JOURNAL_CONF
    else
        echo "SystemMaxUse=200M" | tee -a $JOURNAL_CONF
    fi
    systemctl restart systemd-journald
    log "${HARDEN_LOGS_SUCCESS}"
}

mod_dns() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_DNS_MSG}${NC}"

    if ! command -v iptables >/dev/null 2>&1; then
        err "${HARDEN_FIREWALL_IPTABLES}"
    fi

    if ! dpkg -l | grep -qw iptables-mod-hashlimit 2>/dev/null && ! iptables -m hashlimit --help >/dev/null 2>&1; then
        err "${HARDEN_DNS_IPTABLES}"
    fi

    RULES_DNS=(
        "-A INPUT -p udp --dport 53 -m hashlimit --hashlimit-above 30/sec --hashlimit-burst 50 --hashlimit-mode srcip --hashlimit-name dns_udp --hashlimit-htable-expire 30000 -j DROP"
        "-A INPUT -p udp --dport 53 -j ACCEPT"
        "-A INPUT -p tcp --dport 53 -m hashlimit --hashlimit-above 30/sec --hashlimit-burst 50 --hashlimit-mode srcip --hashlimit-name dns_tcp --hashlimit-htable-expire 30000 -j DROP"
        "-A INPUT -p tcp --dport 53 -j ACCEPT"
    )

    for RULE in "${RULES_DNS[@]}"; do
        if ! iptables -C ${RULE:3} 2>/dev/null; then
            iptables $RULE
        fi
    done

    echo -e "  ${BD}${C}${HARDEN_DNS_JAIL}${NC}"
    if [ -f /etc/fail2ban/jail.local ]; then
        if ! grep -q "\[dns-abuse\]" /etc/fail2ban/jail.local; then
cat <<EOF | tee -a /etc/fail2ban/jail.local

[dns-abuse]
enabled = true
port = 53
filter =
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

    netfilter-persistent save
    log "${HARDEN_DNS_SUCCESS}"
}

mod_dns_remove() {
    echo ""
    echo -e "  ${BD}${C}${HARDEN_DNS_REMOVE_MSG}${NC}"
    echo ""

    # Remove iptables hashlimit rules for DNS
    while iptables -C INPUT -p udp --dport 53 -m hashlimit --hashlimit-above 30/sec --hashlimit-burst 50 --hashlimit-mode srcip --hashlimit-name dns_udp --hashlimit-htable-expire 30000 -j DROP 2>/dev/null; do
        iptables -D INPUT -p udp --dport 53 -m hashlimit --hashlimit-above 30/sec --hashlimit-burst 50 --hashlimit-mode srcip --hashlimit-name dns_udp --hashlimit-htable-expire 30000 -j DROP 2>/dev/null
    done

    while iptables -C INPUT -p tcp --dport 53 -m hashlimit --hashlimit-above 30/sec --hashlimit-burst 50 --hashlimit-mode srcip --hashlimit-name dns_tcp --hashlimit-htable-expire 30000 -j DROP 2>/dev/null; do
        iptables -D INPUT -p tcp --dport 53 -m hashlimit --hashlimit-above 30/sec --hashlimit-burst 50 --hashlimit-mode srcip --hashlimit-name dns_tcp --hashlimit-htable-expire 30000 -j DROP 2>/dev/null
    done

    while iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null; do
        iptables -D INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null
    done

    while iptables -C INPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null; do
        iptables -D INPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null
    done

    # Remove fail2ban DNS abuse jail
    if [ -f /etc/fail2ban/jail.local ]; then
        if grep -q "\[dns-abuse\]" /etc/fail2ban/jail.local; then
            local jail_tmp
            jail_tmp=$(mktemp)
            awk '/^\[dns-abuse\]/{skip=1; next} /^\[/{skip=0} !skip' /etc/fail2ban/jail.local > "$jail_tmp"
            mv "$jail_tmp" /etc/fail2ban/jail.local
            systemctl restart fail2ban
        fi
    fi

    netfilter-persistent save
    log "${HARDEN_DNS_REMOVE_SUCCESS}"
}

# Note: run_total_armor and run_wizard removed as dead code
# run_total_armor was never called (install animation uses individual mod_* calls)
# run_wizard was replaced by submenu_wizard in menu.sh
