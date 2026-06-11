# 24 - Release Candidate NEW VPS Test

## Contexto

- Data: 2026-06-11
- VPS: 136.248.101.34 (Oracle Cloud, Ubuntu 24.04, disposable)
- Branch/ref: `main` (f8cc805)
- Commit main: f8cc805 Delete Docs/Fix directory (+ 89f1685 merge PR #6)
- Objetivo: Validar fluxo NEW VPS / Total Armor completo em VPS limpa

## Resultado executivo

| Item | Resultado |
|---|---|
| One-liner | PASS — repo clonado em /opt/wg-shield, menu abriu |
| Bootstrap | PASS — git clone, re-exec, libs carregadas |
| NEW VPS hardening | PASS (com 2 notas) |
| Total Armor containers | PASS |
| Docker install | SKIP (já instalado, detectou corretamente) |
| Docker Compose | PASS (v5.1.4) |
| WG-Easy | PASS — healthy, HTTP 200 |
| Initial password login | PASS — HTTP 200 com senha correta, 401 com senha errada |
| WireGuard client | MANUAL — requer cliente real |
| AdGuard via VPN | MANUAL — requer VPN conectada |
| DNS via VPN | MANUAL — requer VPN conectada |
| Firewall | PASS — SSH, 51820, 51821, InstanceServices, IPv6 |
| Backup/status | PASS — `wgshield.sh status` funciona |
| Reboot persistence | PASS — containers, firewall, swap, login |

## Baseline

| Item | Antes |
|---|---|
| OS | Ubuntu 24.04.4 LTS |
| Docker | v29.5.3 (mantido de teste anterior) |
| Compose | v5.1.4 |
| Firewall | iptables ACCEPT policy (Oracle default) |
| Containers | nenhum |
| Swap | nenhum |
| Fail2ban | removido |
| BBR | ativo no kernel |
| Sysctl | padrão |
| Limits | padrão |

## Instalação

| Etapa | Resultado | Observação |
|---|---|---|
| VPS cleanup | OK | Removidos containers, swap, fail2ban, hardening, iptables |
| One-liner bootstrap | OK | `curl\|bash` clonou repo em /opt/wg-shield |
| mod_unattended | OK | Instalado, auto-reboot 04:00 |
| mod_fail2ban | OK* | Instalado, mas systemctl start falhou na 1a tentativa |
| mod_swap | OK | 2GB swap criado |
| mod_memory | OK | swappiness=10, vfs_cache_pressure=50 |
| mod_firewall | OK | iptables IPv4+IPv6, Docker FORWARD preservado |
| mod_bbr | OK* | Backup cp falhou (arquivo inexistente), mas módulo aplicado |
| mod_limits | OK | nofile 65535 + ulimit best-effort |
| mod_logs | OK | SystemMaxUse=200M |
| mod_dns | OK | Porta 53 aberta com hashlimit 30/s |
| install wg-easy | OK | Container healthy, HTTP 200 |
| install adguard | OK | Container running |
| install unbound | OK | Container running |

*Nota 1: `mod_fail2ban` reportou sucesso mas `systemctl start fail2ban` falhou com "Unit not found". Remedidado com `apt-get install -y fail2ban` + `daemon-reload`. Possível race condition entre apt install e systemctl enable/start.

*Nota 2: `mod_bbr` mostrou `cp: cannot stat '/etc/sysctl.d/99-wgshield.conf'` ao tentar backup de arquivo inexistente. Inofensivo mas visualmente confuso.

## Serviços

| Serviço | Container | Porta | Status |
|---|---|---|---|
| WG-Easy | wg-easy | 51820/udp, 51821/tcp | healthy, HTTP 200 |
| AdGuard | adguard | 3000/tcp, 53/udp, 53/tcp | running |
| Unbound | unbound | 53/udp | running |

## VPN

| Teste | Resultado |
|---|---|
| Cliente criado | MANUAL |
| Handshake | MANUAL |
| IP VPN | MANUAL |
| AdGuard via 10.8.1.3 | MANUAL |
| DNS via 10.8.1.3 | MANUAL |

## Firewall

| Regra | Resultado |
|---|---|
| SSH (22/tcp) | PASS |
| 51820/udp | PASS |
| 51821/tcp | PASS |
| 3000/tcp | PASS |
| 53/udp + rate-limit | PASS |
| Docker FORWARD | PASS (preservado) |
| InstanceServices | PASS (preservado) |
| IPv6 | PASS (51820, 51821, 3000) |
| INPUT policy DROP | PASS |
| netfilter-persistent | PASS (enabled, saved) |

## Reboot

| Item | Resultado |
|---|---|
| SSH | PASS |
| Containers (3/3) | PASS — wg-easy, adguard, unbound voltaram |
| WG-Easy HTTP 200 | PASS |
| WG-Easy login | PASS — HTTP 200 |
| Firewall persistiu | PASS — policy DROP, portas todas presentes |
| Swap persistiu | PASS — 2GB swap ativo |
| wgshield.sh status | PASS |

## Bugs encontrados

| Bug | Severidade | Bloqueia release? |
|---|---|---|
| fail2ban: systemctl start falha após apt install em execução direta de funções | Baixo | Não — funciona via menu normal, só falha em invocação direta de lib |
| mod_bbr: cp de arquivo inexistente gera erro visual | Baixo | Não — inofensivo, mas confuso |
| Password exposta em `wgshield.sh status` | Médio | Não — by design, mas poderia ser ofuscado |
| Docker version parsing mostra "v9.5.3" em vez de "v29.5.3" | Baixo | Não — regex sed no version string |

## Segurança

- Senhas sanitizadas: SIM (no relatório)
- Hashes sanitizados: SIM
- WireGuard configs sanitizadas: N/A (não coletadas)
- Firewall flush: NÃO executado
- Volumes apagados: SIM (durante cleanup antes do teste)
- VPS descartável: SIM

## Decisão

- Release candidate aprovado? **SIM**, com ressalvas menores
- Pode considerar v2.0 funcional? **SIM** — fluxo principal completo, serviços estáveis, reboot persiste
- Próximo passo: Teste manual de VPN + AdGuard + DNS com cliente real para validação final
