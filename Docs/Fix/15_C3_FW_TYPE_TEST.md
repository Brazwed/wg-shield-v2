# 15 - C3 FW_TYPE Test Report

## Contexto

- Data: 2026-06-11
- VPS: kobold / Oracle Cloud / Ubuntu 24.04.4 LTS (Noble) + Docker 29.1.3
- Branch/commit testado: fix/execution-queue-round-1 @ f4c3066
- Objetivo: C3/F33 somente — mod_firewall() respeitar FW_TYPE

## Problema

`mod_firewall()` ignorava `FW_TYPE` e sempre aplicava iptables raw, inclusive quando `FW_TYPE=ufw`. Isso causava:

1. Mistura UFW + iptables raw no mesmo sistema
2. Regras iptables contraditórias com regras UFW
3. Em Oracle Cloud: risco destruir InstanceServices ao aplicar iptables raw sobre UFW

## Mudança de código

| Commit | Descrição |
|---|---|
| f4c3066 | `fix: respect FW_TYPE in mod_firewall` |

### Resumo da mudança

**lib/hardening.sh:**
- Extraída lógica iptables atual para `mod_firewall_iptables()` — preserva C1 e C2
- Criada `mod_firewall_ufw()` — usa `ufw allow/default/enable`
- `mod_firewall()`: agora delega via `case "${FW_TYPE:-iptables}"`
  - `FW_TYPE=ufw` → `mod_firewall_ufw`
  - `FW_TYPE=iptables` → `mod_firewall_iptables`
  - fallback desconhecido → warn + `mod_firewall_iptables`
- `mod_firewall_ufw()` seta `FW_TYPE="ufw"` e `FW_ACTIVE=true` após executar

**lib/lang/pt_BR.sh:**
- Adicionado `HARDEN_FIREWALL_UNKNOWN_TYPE_WARN="FW_TYPE desconhecido — usando iptables como fallback"`

**lib/lang/en_US.sh:**
- Adicionado `HARDEN_FIREWALL_UNKNOWN_TYPE_WARN="Unknown FW_TYPE — falling back to iptables"`

## Validação

| Teste | Resultado | Evidência |
|---|---|---|
| shellcheck | PASS | Sem novos warnings; SC2034 (FW_ACTIVE), SC2086 (C4) e SC2148 pré-existentes |
| FW_TYPE=iptables mock | PASS | `iptables -P INPUT DROP` presente; nenhum `ufw` |
| FW_TYPE=ufw mock | PASS | `ufw allow/default/enable` presente; nenhum `iptables -P INPUT DROP` |
| FW_TYPE=ufw mock — sem ip6tables | PASS | Nenhum `ip6tables -P INPUT DROP` ou `ip6tables -P FORWARD DROP` |
| FW_TYPE=unknown mock | PASS | Fallback para `mod_firewall_iptables` |
| syntax check (bash -n) | PASS | Todos .sh passam |
| VPS deploy | PASS | Código sincronizado; `mod_firewall_iptables`/`mod_firewall_ufw`/`case FW_TYPE` verificados |
| UFW real ativado | NÃO | UFW não está instalado na VPS; não foi ativado |
| iptables real alterado | NÃO | Estado iptables da VPS inalterado pós-deploy |
| InstanceServices | OK | Chain intacta, 15 regras |
| Docker FORWARD | OK | FORWARD DROP com Docker preservado (C2) |

### Detalhe: Mock iptables

Executado com binários fake em `/tmp/wgshield-c3-mock-bin/` que logam comandos.

**FW_TYPE=iptables** — comandos executados:
- `iptables -C INPUT ...` (6 ensure_iptables_input_rule checks)
- `iptables -P INPUT DROP`
- `iptables -S DOCKER` (docker_firewall_present)
- `iptables -P OUTPUT ACCEPT`
- `ip6tables -C INPUT ...` (5 ensure_ip6tables_input_rule checks)
- `ip6tables -P INPUT DROP`
- `ip6tables -P OUTPUT ACCEPT`
- `netfilter-persistent save/enable`
- **Nenhum `ufw`**

**FW_TYPE=ufw** — comandos executados:
- `ufw default deny incoming`
- `ufw default allow outgoing`
- `ufw allow 22/tcp comment SSH`
- `ufw allow 51820/udp comment WireGuard`
- `ufw allow 51821/tcp comment WG-Easy`
- `ufw enable`
- **Nenhum `iptables -P`**

**FW_TYPE=weirdvalue** — comandos executados:
- Idêntico ao caminho iptables (fallback com warn)

## Preservação C1 e C2

| Item | Status |
|---|---|
| C1: `ensure_iptables_input_rule()` INSERT antes de REJECT/DROP | Preservado em `mod_firewall_iptables()` |
| C1: `-P INPUT DROP` após ACCEPT rules | Preservado |
| C2: `docker_firewall_present()` FORWARD check | Preservado |
| C2: DOCKER-FORWARD chain check | Preservado (microcorreção pós-C2) |
| C2: warn para FORWARD DROP | Preservado |

## mod_firewall_ufw() — notas

- Instala UFW se não disponível (`apt install -y ufw`)
- Aplica `default deny incoming` + `default allow outgoing`
- Abre portas SSH (via `${SSH_PORT}`), WireGuard (51820/udp), WG-Easy (51821/tcp)
- Ativa UFW com `echo "y" | ufw enable`
- Seta `FW_TYPE="ufw"` e `FW_ACTIVE=true`
- **Atenção em Oracle Cloud**: `ufw enable` pode reescrever iptables e destruir InstanceServices. Teste com UFW real requer snapshot + console/VNC.

## Resultado C3

- Status: **OK** (code + mock)
- Evidência: Mock tests 9/9 PASS; VPS syntax check PASS; iptables real inalterado; UFW não ativado
- Decisão: C3/F33 corrigido — `mod_firewall()` agora respeita `FW_TYPE`. Validação real com UFW ativo requer VPS separada ou snapshot + console.

## Riscos remanescentes

- C4/F07: dns-abuse filter=empty + SC2086 em mod_dns() (não alterado)
- C5/F34: IPv6 sem porta 51821/tcp e 3000/tcp (não alterado)
- UFW real em Oracle: `ufw enable` pode sobrescrever iptables e destruir InstanceServices. **Exige snapshot + console/VNC antes de testar.**
- `mod_firewall_ufw` não lida com Docker FORWARD explicitamente — UFW gerencia isso nativamente se habilitado, mas pode precisar de `ufw route allow` para containers com port mapping
- `mod_firewall_ufw` não abre IPv6 explicitamente — UFW por padrão aplica regras para ambos (v4+v6), mas isso deve ser validado
- Porta 3000/tcp (AdGuard) não está no `mod_firewall_ufw()` — atualmente não está em `mod_firewall_iptables()` também (C5/F34)

## Próximo passo recomendado

Pronto para **C4/F07** (fail2ban dns-abuse filter). C3 resolveu integração FW_TYPE. Para validação UFW real:
1. Snapshot da VPS
2. Console VNC acessível
3. Cron safety ativo
4. `FW_TYPE=ufw` + `mod_firewall` com monitoramento
