# 12 - VPS Test Report (Kobold - Oracle Cloud)

**Date:** 2026-06-11
**VPS:** kobold / Oracle Cloud / Ubuntu 24.04.4 LTS (Noble)
**Kernel:** 6.17.0-1011-oracle x86_64
**Private IP:** 10.0.0.223/24
**Public IP:** 136.248.69.230
**RAM:** ~954MB | Swap: 0 | Disk: 45GB (1GB used)
**Branch:** fix/execution-queue-round-1

---

## 1. Deploy

- Project rsync'd to `/opt/wg-shield-test/` on VPS
- Excluded: `.git`, `Docs/Fix`, `SSH kobold`
- Files verified: `wgshield.sh`, `lib/*.sh`, `lib/lang/*.sh`, `Docs/`, `README.md`

## 2. Safe CLI Tests

### `wgshield.sh -h`
- PASS: Usage text displayed correctly, all actions/options listed

### `wgshield.sh -v`
- PASS: `WG-Shield v2.0 v2.0 by Brazwed` (note: version string shows "v2.0" twice - cosmetic)

### `wgshield.sh detect`
- PASS: VPS detection completed
- Docker: not installed
- Containers: none
- Firewall: iptables (6 rules)
- Unbound DNS: port 53 in use by other (systemd-resolved on 127.0.0.53/127.0.0.54)

### `wgshield.sh status`
- PASS: SSH port detected (22), network check OK

## 3. Code Fix Validation (Remote Inspection)

| Fix | Finding | Status |
|-----|---------|--------|
| B3/F06 | sysctl.d drop-in `/etc/sysctl.d/99-wgshield.conf` | PASS (hardening.sh:194) |
| B7/F08 | Backup subdirs `vps/`, `${target}/` with `latest` symlink | PASS (backup.sh:12,54,72,103) |
| B5/F04 | `[A] Apply` via `MSG_WIZARD_APPLY` i18n key | PASS (menu.sh:411,453) |
| B6/F09+F16 | `silent` mode in wgshield_ops.sh | PASS (wgshield_ops.sh:5,32) |

## 4. Firewall Baseline (CRITICAL - Pre-Etapa 6)

### iptables-save summary
```
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT
:InstanceServices - [0:0]

# Core rules (Oracle Cloud default):
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited

# OUTPUT chain routes 169.254.0.0/16 to InstanceServices
# InstanceServices chain: Oracle metadata/iSCSI rules (16 rules)
#   - 169.254.0.2/3260 (iSCSI, root only)
#   - 169.254.169.254/53 (DNS)
#   - 169.254.169.254/80 (metadata)
#   - 169.254.0.3/80, 169.254.0.4/80
#   - 169.254.169.254/67,69,123 (DHCP/TFTP/NTP)
#   + catch-all REJECT for 169.254.0.0/16
```

### Persistent rules
- `/etc/iptables/rules.v4`: Oracle Cloud default (identical to runtime)
- `/etc/iptables/rules.v6`: Oracle Cloud default

### UFW
- NOT INSTALLED

### Docker
- NOT INSTALLED

### Listening ports
| Port | Service |
|------|---------|
| 22 | sshd (0.0.0.0 + [::]) |
| 111 | rpcbind (0.0.0.0 + [::]) |
| 53 | systemd-resolved (127.0.0.53, 127.0.0.54) |

## 5. Etapa 6 Risk Assessment (Firewall)

### Critical observations for `mod_firewall()` (C1-C5):

1. **INPUT REJECT already present**: Oracle Cloud default iptables has `INPUT REJECT --reject-with icmp-host-prohibited` as last rule. Running `iptables -P INPUT DROP` (as original code did) would ONLY affect traffic that somehow bypasses all rules - minimal security gain, maximum lockout risk.

2. **InstanceServices chain is Oracle-critical**: Any `iptables -F` (flush) in `mod_firewall()` would destroy the InstanceServices chain, potentially breaking:
   - iSCSI boot volumes (169.254.0.2:3260)
   - Cloud metadata (169.254.169.254:80)
   - DNS resolution via metadata (169.254.169.254:53)
   - This could make the instance UNRECOVERABLE

3. **UFW installation would conflict**: Oracle iptables-persistent + ufw would fight over rules. The `ask_firewall_choice()` option 1 (install UFW) runs `ufw default deny incoming` + `ufw --force enable` which rewrites iptables rules and could destroy InstanceServices chain.

4. **FORWARD REJECT already present**: The `FORWARD REJECT` rule already exists. Since Docker is not installed, the F03 (FORWARD DROP + Docker) issue is moot on this VPS.

5. **SSH port rule already exists**: `iptables -A INPUT -p tcp --dport 22 -j ACCEPT` is already present. If `mod_firewall()` appends a duplicate rule AFTER the REJECT, it would be unreachable and useless.

### Recommended safety measures for Etapa 6:
- **MUST** save `iptables-save` output before any modification
- **MUST NOT** use `iptables -F` or `iptables -X InstanceServices`
- **MUST** use `iptables -I` (insert) instead of `iptables -A` (append) to place rules before the REJECT
- **MUST** preserve InstanceServices chain and OUTPUT rule
- **MUST** have a cron safety net (`*/3 * * * * iptables-restore < /tmp/iptables-backup`) with auto-removal after 15 min
- **MUST** have VNC/console access verified before proceeding
- **MUST** have instance snapshot/backup via Oracle Cloud Console

## 6. Additional Findings

1. **rpcbind on port 111**: Unnecessary service on a VPN server. Potential security risk. Consider disabling.

2. **Version string duplication**: `wgshield.sh -v` outputs `WG-Shield v2.0 v2.0` - the "v2.0" appears twice. Minor cosmetic bug.

3. **Port 53 conflict**: systemd-resolved listens on 127.0.0.53:53. Installing Unbound DNS would require either stopping systemd-resolved or configuring it as stub listener.

## 7. Summary

| Phase | Result |
|-------|--------|
| Deploy | PASS |
| CLI tests | PASS (minor cosmetic version bug) |
| Code validation | PASS (B3, B7, B5, B6) |
| Baseline collection | PASS |
| Etapa 6 readiness | NOT READY - requires VNC, snapshot, cron safety |

**Deploy verification complete.** The project runs correctly in read-only/detection mode on the Oracle Cloud VPS. Etapa 6 (firewall modifications) requires additional safety infrastructure (VNC, snapshot, cron) before proceeding.
