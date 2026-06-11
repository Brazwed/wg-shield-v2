# 18 - C5 IPv6 Firewall Test Report

## Contexto

- Data: 2026-06-11
- Branch/commit: fix/execution-queue-round-1 @ 694b7b1
- Objetivo: C5/F34 — regras IPv6 incompletas no mod_firewall_iptables()

## Problema

`mod_firewall_iptables()` tinha regras IPv6 incompletas. IPv4 abria 51821/tcp e (via C4) 3000/tcp, mas IPv6 não.

### IPv6 baseline VPS kobold antes da correção

```
Chain INPUT (policy DROP)
1    ACCEPT     all  --  ::/0  ::/0
2    ACCEPT     all  --  ::/0  ::/0  ctstate RELATED,ESTABLISHED
3    ACCEPT     ipv6-icmp --  ::/0  ::/0
4    ACCEPT     tcp  --  ::/0  ::/0  tcp dpt:22
5    ACCEPT     udp  --  ::/0  ::/0  udp dpt:51820
```

Faltavam: `51821/tcp` (WG-Easy) e `3000/tcp` (AdGuard).

## Mudança de código

| Commit | Descrição |
|---|---|
| 694b7b1 | fix: add missing IPv6 firewall ports |

### Arquivos alterados

| Arquivo | Mudança |
|---|---|
| `lib/hardening.sh` | `mod_firewall_iptables()`: adicionado `ensure_ip6tables_input_rule` para 51821/tcp e 3000/tcp |
| `lib/hardening.sh` | `mod_firewall_ufw()`: adicionado `ufw allow 3000/tcp comment "AdGuard"` |

## IPv6 rules — antes vs depois

| Porta | Protocolo | Antes (VPS real) | Depois (código) | Helper |
|---|---|---|---|---|
| lo | all | presente | presente | ensure_ip6tables_input_rule |
| conntrack | all | presente | presente | ensure_ip6tables_input_rule |
| ipv6-icmp | 58 | presente | presente | ensure_ip6tables_input_rule |
| SSH | tcp | presente (`$SSH_PORT`) | presente | ensure_ip6tables_input_rule |
| 51820 | udp | presente | presente | ensure_ip6tables_input_rule |
| **51821** | **tcp** | **faltava** | **presente** | ensure_ip6tables_input_rule |
| **3000** | **tcp** | **faltava** | **presente** | ensure_ip6tables_input_rule |

## UFW parity

| Porta | Antes | Depois |
|---|---|---|
| SSH | presente | presente |
| 51820/udp | presente | presente |
| 51821/tcp | presente | presente |
| **3000/tcp** | **faltava** | **presente** |

Nota: UFW aplica regras v4+v6 automaticamente, então a correção no caminho UFW beneficia ambos os protocolos.

## Testes

| Teste | Resultado | Log |
|---|---|---|
| bash -n syntax | 3/3 OK | VPS |
| shellcheck | 0 relevant warnings | Local |
| mock test 22 assertions | 22/22 PASS | `mock-test-results.txt` |
| IPv6 port parity source grep | 51821+3000 presentes | M1 assertions |
| UFW port parity source grep | 3000 adicionado | M2 assertions |
| open_port iptables mock | 51821+3000 PASS | M3 assertions |
| open_port ufw mock | 51821+3000 PASS | M4 assertions |
| open_port none mock | silent PASS | M5 assertions |
| No raw ip6tables -A | PASS | M6 assertions |
| VPS ip6tables baseline coletado | 5 rules, faltando 51821+3000 | `ip6tables-input-baseline.txt` |

## Segurança

| Item | Resultado |
|---|---|
| UFW real ativado | NÃO |
| iptables real alterado | NÃO |
| ip6tables real alterado | NÃO |
| InstanceServices tocado | NÃO |
| Docker tocado | NÃO |
| fail2ban tocado | NÃO |
| install full executado | NÃO |

## Resultado C5

- Status: **OK**
- Evidência: mock 22/22 PASS; VPS ip6tables baseline confirma 51821+3000 ausentes; código corrigido com helpers; VPS syntax OK
- Decisão: C5/F34 corrigido e validado

## Etapa 6 — status final

| Item | Status | Commit |
|---|---|---|
| C1/F01 | OK | 0c6a137 |
| C2/F03 | OK | 19f35f1 |
| C3/F33 | OK | f4c3066 |
| C4/F07 | OK | 2d7d69e |
| C5/F34 | OK | 694b7b1 |

**Etapa 6 completa.** Todos os 5 itens C estão OK.

## Riscos remanescentes

- UFW real Oracle: `ufw enable` pode destruir InstanceServices — requer snapshot + console/VNC
- LOG_RESTORED: padrão morto em backup.sh:214 — interpolação `$timestamp`
- firewalld/nftables D-tier: não detectados por `detect_firewall()`
- Unbound query logging: necessário para fail2ban dns-abuse matcher (C4)
- Duplicatas conntrack/state: IPv4 tem `conntrack` + `state` duplication (legado Oracle pré-C1)
- `mod_memory()` ainda escreve em `/etc/sysctl.conf` — D-tier

## Próximo passo recomendado

**Etapa 6 concluída.** Todos os itens C1-C5 estão validados. Próximo estágio seria Etapa 7 (D-tier / future cleanup) ou revisão final do projeto. Itens D são redesign/futuro e não requerem ação imediata.
