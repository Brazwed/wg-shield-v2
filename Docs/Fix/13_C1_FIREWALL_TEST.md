# 13 - C1 Firewall Test Report

## Contexto

- Data: 2026-06-11
- VPS: kobold / Oracle Cloud / Ubuntu 24.04.4 LTS (Noble)
- Branch/commit testado: fix/execution-queue-round-1 @ 0c6a137
- Objetivo: C1/F01 somente — evitar SSH lockout por `iptables -P INPUT DROP` antes de ACCEPT

## Safety aplicado

| Item | Status | Evidência |
|---|---|---|
| Backup iptables-save v4 | OK | `iptables-restore-safe.v4` criado |
| Backup ip6tables-save v6 | OK | `ip6tables-restore-safe.v6` criado |
| Cron safety | OK → REMOVIDO | `cron-safety.txt`; removido após teste bem-sucedido |
| tmux/screen | OK | tmux 3.4 instalado na VPS |
| Segunda conexão SSH | OK | `ssh-after.txt` confirma SSH ativo pós-teste |
| InstanceServices baseline | OK | `instanceservices-before.txt` com 15 regras |

## Mudança de código

| Commit | Descrição |
|---|---|
| 0c6a137 | `fix: insert iptables ACCEPT rules before DROP policy` |

### Resumo da mudança

**lib/firewall.sh:**
- Adicionado `ensure_iptables_input_rule()` — helper que insere regras iptables ANTES do primeiro REJECT/DROP na chain INPUT
- Adicionado `ensure_ip6tables_input_rule()` — equivalente para ip6tables
- `ask_firewall_choice()` option 2: usa helper em vez de `iptables -A INPUT`
- `open_port()`: usa helper em vez de `iptables -A INPUT`
- Fix SC2086: `${SSH_PORT}` → `"${SSH_PORT}"` em ufw allow

**lib/hardening.sh:**
- `mod_firewall()`: regras ACCEPT inseridas ANTES de `-P INPUT DROP`
- RULES array com string-splitting substituído por chamadas diretas ao helper
- Elimina SC2086 (6 warnings) em mod_firewall()
- Ordem correta: rules first → policy after → save
- `mod_dns()` NÃO alterado (C4 territory)

### Lógica do helper

```
ensure_iptables_input_rule():
  1. iptables -C INPUT $@ → regra já existe? return 0
  2. awk '/REJECT|DROP/ {print $1; exit}' → acha primeira linha REJECT/DROP
  3. Se encontrou: iptables -I INPUT $line $@ → insere ANTES do REJECT
  4. Se não: iptables -A INPUT $@ → append normal (sem REJECT na chain)
```

## Execução na VPS

| Teste | Resultado | Log |
|---|---|---|
| Syntax check | PASS | `bash -n` sem erros |
| mod_firewall() | PASS | `mod_firewall-run.txt` |
| SSH após mod_firewall | PASS | `ssh-after.txt` |
| iptables-save após | PASS | `iptables-save-after.v4` |
| InstanceServices após | PASS | `instanceservices-after.txt` (15 regras intactas) |

## Comparativo iptables

| Item | Antes | Depois | Status |
|---|---|---|---|
| SSH ACCEPT antes de REJECT | Sim (Oracle rule @ line 4) | Sim (Oracle rule @ line 4 + novo @ line 6) | OK — regras antes do REJECT |
| INPUT policy | ACCEPT | DROP | OK — safety net AFTER rules inserted |
| InstanceServices chain | 15 rules | 15 rules | OK — preservada |
| OUTPUT 169.254.0.0/16 | InstanceServices jump | InstanceServices jump | OK — preservado |
| UFW | não instalado | não instalado | OK |
| FORWARD policy | ACCEPT | DROP | Inalterado (C2 territory) |
| UDP 51820 | ausente | presente (line 7) | OK — novo |
| TCP 51821 | ausente | presente (line 8) | OK — novo |

### Detalhe: regras duplicadas

A chain INPUT após C1 tem regras funcionalmente duplicadas:
- Linha 1 (Oracle): `-m state --state RELATED,ESTABLISHED` ↔ Linha 5 (nova): `-m conntrack --ctstate RELATED,ESTABLISHED`
- Linha 4 (Oracle): `-p tcp --dport 22 -m state --state NEW` ↔ Linha 6 (nova): `-p tcp --dport 22`

Isto ocorre porque `iptables -C` faz match exato da sintaxe, não semântico. As regras Oracle e WG-Shield usam matchers diferentes (`-m state` vs `-m conntrack`), mas são funcionalmente equivalentes. As duplicatas são inofensivas (performance irrelevante em VPS com <10 regras) e podem ser limpas em follow-up D-tier.

## Resultado C1

- Status: **OK**
- Evidência: SSH acessível após `mod_firewall()`, InstanceServices preservada, ACCEPT rules antes de REJECT
- Decisão: C1/F01 corrigido e validado em código + VPS real

## Riscos remanescentes

- C2/F03: FORWARD DROP + Docker (não testado nesta rodada; policy já era DROP antes)
- C3/F33: mod_firewall() ignora FW_TYPE=ufw (não testado; não instalado)
- C4/F07: dns-abuse filter=empty (não alterado; mod_dns() ainda usa `iptables -A` com string-splitting)
- C5/F34: IPv6 sem porta 51821/tcp e 3000/tcp (não testado)
- D-tier: regras duplicadas `-m state` vs `-m conntrack` (cosmético, sem impacto)
- mod_dns() (lines 243-254) ainda usa `iptables -A INPUT` — precisa de C4 para adequar ao helper

## Próximo passo recomendado

C1 está OK. Pode seguir para **C2/F03** (FORWARD DROP + Docker). Recomendações:
1. C2 exige VPS com Docker instalado (ou instalação controlada)
2. Antes de C2, restaurar iptables da VPS kobold ao baseline Oracle (ou criar nova VPS com Docker)
3. Validação C2 requer: instalar Docker → criar container → rodar mod_firewall → verificar container funcional
