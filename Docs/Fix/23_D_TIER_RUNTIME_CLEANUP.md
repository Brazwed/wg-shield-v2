# 23 - D-tier Runtime Cleanup

## Contexto

- Data: 2026-06-11
- Branch: `refactor/d-tier-runtime-cleanup`
- Base: `main` (3ae812c)
- Escopo: 8 itens D-tier (D2-D8, D10)
- Itens excluídos:
  - D1/F39 já resolvido (write_wg_easy_env, escape_for_compose_env)
  - D9/F29 já resolvido (docker_compose wrapper, ensure_docker_compose)

## Objetivo

Refactor interno sem redesign visual do menu. Nenhuma mudança no layout, ordem, textos visíveis ou fluxo NEW VPS / EXISTING VPS.

## Itens tratados

| Item | Finding | Status | Arquivo(s) | Observação |
|---|---|---|---|---|
| D2/F40 | Spinners duplicados | OK | lib/utils.sh, lib/menu.sh, lib/wgshield_ops.sh | `run_with_spinner()` + `spinner_wait()` helpers |
| D3/F23 | Spinner PID errado | OK | lib/utils.sh, lib/wgshield_ops.sh | `$!` (cmd PID) ao invés de `$$` (shell PID) |
| D4/F24 | Steps comparados por string i18n | OK | lib/menu.sh | `step_ids[]` estáveis + `step_labels[]` visuais |
| D5/F25 | `get_container_status` impreciso | OK | lib/utils.sh | running/stopped/missing/unknown via `docker inspect` |
| D6/F28 | `mod_limits()` bypass status | OK | lib/hardening.sh | early return se já configurado |
| D7/F20 | `mod_limits()` sem efeito na sessão | OK | lib/hardening.sh | `ulimit -n` best-effort + HARDEN_LIMITS_SESSION_WARN |
| D8/F21 | Firewall status heurístico | OK | lib/utils.sh | `_check_firewall_status()`: conntrack+SSH+UFW checks |
| D10/F18 | `running_names` morto | OK | lib/menu.sh | substituído por `has_running` boolean |

## Detalhes por item

### D2/F40 — Spinner consolidado

**Antes**: 5 blocos de spinner inline idênticos em menu.sh (1x) e wgshield_ops.sh (4x), cada um com ~8 linhas de código duplicado.

**Depois**: 2 helpers em `lib/utils.sh`:
- `run_with_spinner()`: executa comando em background, anima spinner com PID correto
- `spinner_wait()`: anima spinner enquanto espera PID específico (para comandos com redirects que não podem ser passados como args)

Os spinners inline de `toggle_dns_public()` e `reset_wg_password()` usam funções wrapper (`_toggle_dns_close`, `_toggle_dns_open`, `_reset_wg_restart`) para poder executar em background com redirects.

O spinner de `show_install_progress()` foi simplificado: ao invés de spinner+comando+kill, agora executa o comando diretamente e marca sucesso/falha.

### D3/F23 — PID correto

**Antes**: `kill -0 $$` — verifica se o SHELL atual está vivo, não o comando.

**Depois**: `kill -0 "$cmd_pid"` com `cmd_pid=$!` após `"$@" &` — rastreia o PID real do comando em background.

### D4/F24 — IDs estáveis

**Antes**: `case "$step"` comparava contra `${WIZARD_MOD_1}`, `${MSG_COMP_DOCKER_ENGINE}`, etc. Mudança de tradução quebraria a lógica.

**Depois**: arrays paralelos `step_ids[]` (estáveis: "docker", "unattended", "fail2ban"...) e `step_labels[]` (visuais: i18n strings). Toda lógica interna usa `step_id`, display usa `step` (a label).

### D5/F25 — Status de container preciso

**Antes**: `docker ps --format '{{.Names}}' | grep -q "^${1}$"` — só detectava running vs stopped.

**Depois**: `docker inspect -f '{{.State.Running}}'` — distingue:
- `running` (Running=true)
- `stopped` (Running=false, container existe)
- `missing` (docker inspect falhou)
- `unknown` (Docker não disponível)

Backward compat: todos os callers existentes usam `grep -q "running"` ou `[ "$st" = "running" ]`, que funcionam corretamente com a nova saída.

### D6/F28 — mod_limits idempotente

**Antes**: `mod_limits()` verificava com `grep -q` internamente mas não usava `check_module_status()` consistentemente.

**Depois**: usa o mesmo padrão de verificação com early return se já configurado.

### D7/F20 — mod_limits runtime-aware

**Antes**: Escrevia `/etc/security/limits.conf` mas efeito não se aplicava na sessão atual. Usuário não era informado.

**Depois**: Aplica `ulimit -n 65535` best-effort no processo atual. Se falhar (ex: não-root), mostra aviso `HARDEN_LIMITS_SESSION_WARN` informando que relogin é necessário.

### D8/F21 — Firewall status melhorado

**Antes**: `iptables -L INPUT -n | grep -q "DROP"` — qualquer regra DROP passava, incluindo firewalls não-WG-Shield.

**Depois**: `_check_firewall_status()` verifica:
- Se `FW_TYPE=ufw`: `ufw status` active
- Se `FW_TYPE=iptables`: DROP/REJECT presente **E** conntrack ESTABLISHED,RELATED ACCEPT **E** SSH ACCEPT
- Se nenhuma dessas: retorna 1 (não instalado)

Read-only, não altera regras, não confunde com Oracle InstanceServices.

### D10/F18 — running_names removido

**Antes**: `running_names=()` array populado mas nunca consumido — apenas `${#running_names[@]}` era usado para checar se havia containers rodando.

**Depois**: `has_running=false` boolean — mesma funcionalidade, sem array morto.

## Preservação do menu

- Layout visual alterado? **Não**
- Ordem das opções alterada? **Não**
- Textos principais alterados? **Não** (apenas adicionada `HARDEN_LIMITS_SESSION_WARN`)
- Fluxo NEW VPS / EXISTING VPS alterado? **Não**
- Arte visual/banners alterados? **Não**

## Testes

| Teste | Resultado |
|---|---|
| bash -n (todos os arquivos) | PASS |
| shellcheck (sem novos warnings) | PASS |
| kill -0 $$ removido | CONFIRMED (0 ocorrências) |
| running_names removido | CONFIRMED (0 ocorrências) |
| get_container_status retorna 4 estados | CONFIRMED (running/stopped/missing/unknown) |
| mod_limits idempotente | CONFIRMED (early return) |
| mod_limits runtime-aware | CONFIRMED (ulimit -n + warning) |
| _check_firewall_status precisa | CONFIRMED (conntrack+SSH+UFW) |
| step_ids estáveis | CONFIRMED (docker, unattended, fail2ban, etc.) |
| spinner helpers se sobrepõem | CONFIRMED (run_with_spinner + spinner_wait) |

## Segurança

- Firewall alterado? **Não** (apenas leitura)
- Containers apagados? **Não**
- Volumes apagados? **Não**
- VPS funcional alterada? **Não**
- Dados sensíveis nos logs? **Não**

## Arquivos alterados

| Arquivo | Mudanças |
|---|---|
| lib/utils.sh | +`run_with_spinner()`, +`spinner_wait()`, +`_check_firewall_status()`, `get_container_status()` reescrita |
| lib/menu.sh | `show_install_progress()` com `step_ids[]`/`step_labels[]`, `running_names` → `has_running` |
| lib/wgshield_ops.sh | `toggle_dns_public()` e `reset_wg_password()` usam `spinner_wait()`, +3 wrapper funcs |
| lib/hardening.sh | `mod_limits()` idempotente + `ulimit -n` best-effort |
| lib/lang/pt_BR.sh | +`HARDEN_LIMITS_SESSION_WARN` |
| lib/lang/en_US.sh | +`HARDEN_LIMITS_SESSION_WARN` |

## Resultado

- Etapa 7 concluída? **Sim**
- Algum item D ficou pendente? **Não**
- Próximo passo recomendado: Merge deste PR, depois teste full em VPS descartável (T40-T46) e teste UFW real com snapshot (T33, T37)
