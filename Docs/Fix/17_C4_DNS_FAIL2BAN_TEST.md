# 17 - C4 DNS Fail2Ban Test Report

## Contexto

- Data: 2026-06-11
- Branch/commit: fix/execution-queue-round-1 @ 2d7d69e
- Objetivo: C4/F07 — dns-abuse filter funcional + mod_dns() FW_TYPE-aware

## Problema

`mod_dns()` tinha 7 bugs/deficiências:

| # | Bug | Severidade |
|---|---|---|
| 1 | `filter =` vazio no jail dns-abuse — fail2ban nunca detecta nada | P1 |
| 2 | `/etc/fail2ban/filter.d/dns-abuse.conf` nunca criado | P1 |
| 3 | `iptables $RULE` — SC2086 word splitting | P2 |
| 4 | `iptables -A INPUT` — regras anexadas após DROP/REJECT (C1 bug) | P1 |
| 5 | Sem FW_TYPE awareness — ignora UFW/none | P2 |
| 6 | `netfilter-persistent save` executado mesmo para UFW | P3 |
| 7 | `dpkg -l | grep -qw iptables-mod-hashlimit` — nome de pacote incorreto | P3 |

## Mudança de código

| Commit | Descrição |
|---|---|
| 2d7d69e | fix: add functional dns-abuse fail2ban filter |

### Arquivos alterados

| Arquivo | Mudança |
|---|---|
| `lib/hardening.sh` | `mod_dns()` reescrita: filter funcional, `open_port()`, `_insert_dns_hashlimit()`, FW_TYPE-aware |
| `lib/hardening.sh` | `mod_dns_remove()`: FW_TYPE-aware (ufw delete), remove filter file |
| `lib/hardening.sh` | `_insert_dns_hashlimit()`: novo helper, insere hashlimit DROP antes do ACCEPT |
| `lib/lang/pt_BR.sh` | `HARDEN_DNS_NO_FIREWALL_WARN` |
| `lib/lang/en_US.sh` | `HARDEN_DNS_NO_FIREWALL_WARN` |

## Filter dns-abuse

| Item | Resultado |
|---|---|
| filter.d/dns-abuse.conf criado | SIM — com `[Definition]` completo |
| failregex usa `<HOST>` | SIM — 2 padrões: Unbound direto + syslog-unbound |
| ignoreregex presente | SIM — ignora 127.0.0.1 e ::1 |
| jail dns-abuse aponta para filter | SIM — `filter = dns-abuse` |
| logpath documentado | backend=systemd (journal) — sem logpath necessário |
| fail2ban-regex positivo | 5/5 matched |
| fail2ban-regex negativo | 0/5 matched (2 ignorados, 3 missed = correto) |

### Filter failregex patterns

1. `^\[\d+:\d+\] info: <HOST> \S+ \S+ \S+` — Unbound query log direto
2. `^.*unbound\[\d+\]: \[\d+:\d+\] info: <HOST> \S+ \S+ \S+` — syslog com processo PID

### Filter ignoreregex patterns

1. `^\[\d+:\d+\] info: 127\.0\.0\.1` — ignora localhost IPv4
2. `^\[\d+:\d+\] info: ::1` — ignora localhost IPv6

### Limitação: requer Unbound query logging

O filter é funcional mas requer que Unbound tenha query logging habilitado (`verbosity: 1+` ou `log-queries: yes`). Sem isso, o journal não contém entradas para o filter corresponder. Isso é documentado mas não corrigido — habilitar query logging na configuração do Unbound está fora do escopo de `mod_dns()`.

## Firewall em mod_dns

| Item | Resultado |
|---|---|
| `iptables -A INPUT` direto removido | SIM — substituído por `open_port()` + `_insert_dns_hashlimit()` |
| `open_port()` / helper usado | SIM — `open_port "53/udp"`, `open_port "53/tcp"` |
| `FW_TYPE=iptables` | `ensure_iptables_input_rule()` via `open_port()` + hashlimit via `_insert_dns_hashlimit()` |
| `FW_TYPE=ufw` | `ufw allow 53/udp`, `ufw allow 53/tcp` via `open_port()` |
| `FW_TYPE=none` | Warn `HARDEN_DNS_NO_FIREWALL_WARN`, não abre porta |

### `_insert_dns_hashlimit()` — ordem de inserção

O helper insere regras hashlimit DROP **antes** da regra ACCEPT correspondente:

1. `open_port "53/udp"` → `ensure_iptables_input_rule -p udp --dport 53 -j ACCEPT`
2. `_insert_dns_hashlimit udp dns_udp` → encontra linha do ACCEPT, `iptables -I INPUT $line ... -j DROP`

Resultado na chain: `hashlimit DROP udp 53` → `ACCEPT udp 53` → ... → `REJECT`

Isso garante que tráfego com taxa excedida é DROPado antes de ser ACEITO.

## Testes

| Teste | Resultado | Log |
|---|---|---|
| bash -n syntax | 5/5 OK | `Docs/Fix/logs/kobold/c4/` |
| shellcheck (hardening.sh) | 0 relevant warnings | SC2086 eliminado |
| mock test 31 assertions | 31/31 PASS | `mock-test-results.txt` |
| fail2ban-regex positivo | 5/5 matched | `fail2ban-regex-positive.txt` |
| fail2ban-regex negativo | 0 matched, 2 ignored, 3 missed | `fail2ban-regex-negative.txt` |
| open_port iptables mock | PASS — `iptables -p udp/tcp --dport 53 -j ACCEPT` | `wgshield-c4-mock.log` |
| open_port ufw mock | PASS — `ufw allow 53/udp, 53/tcp` | `wgshield-c4-mock.log` |
| open_port none mock | PASS — nenhum comando | `wgshield-c4-mock.log` |
| VPS syntax check | 5/5 OK | Remoto |

## Segurança

| Item | Resultado |
|---|---|
| UFW real ativado | NÃO |
| iptables real alterado | NÃO — regras DNS não foram aplicadas na VPS |
| InstanceServices tocado | NÃO |
| Docker tocado | NÃO |
| C5 executado | NÃO |

## Resultado C4

- Status: **OK**
- Evidência: fail2ban-regex 5/5 positivo, 0 falso-negativo; mock 31/31 PASS; shellcheck limpo
- Decisão: C4/F07 corrigido e validado. Pronto para C5/F34.

## Riscos remanescentes

- C5/F34: IPv6 sem porta 51821/tcp e 3000/tcp
- UFW real Oracle: requer snapshot + console/VNC
- LOG_RESTORED: padrão morto em backup.sh:214
- firewalld/nftables D-tier: não detectado
- Unbound query logging: filter é funcional mas requer `verbosity: 1+` no Unbound para produzir logs

## Próximo passo recomendado

Pronto para **C5/F34** — adicionar 51821/tcp e 3000/tcp às regras IPv6 em `mod_firewall_iptables()`.
