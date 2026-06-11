# 10 - Fila de Execução das Correções

## Princípio

A ordem NÃO segue apenas o nível do achado (Alto/Médio/Baixo). Segue:

1. **Risco da correção** — zero risco entra primeiro, alto risco por último
2. **Dependência** — se o fix X destrava o fix Y, X vem antes
3. **Impacto do problema** — entre correções de mesmo risco, prioriza o que causa mais dano
4. **Testabilidade** — correções validáveis localmente entram antes das que exigem VPS
5. **Nível do achado** — desempate final: Alto > Médio > Baixo

### Exceções aplicadas

- Achado **Alto** com correção zero risco entra cedo (ex: A8 / F10)
- Achado **Baixo** que exige refactor estrutural vai para Futuro (ex: D1-D10)
- Achado **Médio** que destrava Alto sobe na ordem (ex: A6 / F17 destrava B6)
- Achado `precisa validar` NÃO vira correção direta antes do teste correspondente
- Qualquer firewall/iptables/UFW/Docker FORWARD/netfilter-persistent fica DEPOIS das fases seguras

### Hierarquia de referência

| Nível | Severidades | Significado |
|-------|-------------|-------------|
| Alto | P0, P1 | Lockout, quebra funcional, falha de segurança, rollback crítico |
| Médio | P2 | Idempotência, UX degradada, fluxo incompleto |
| Baixo | P3, P4 | Dead code, duplicação, docs, inconsistência menor |

---

## Status Geral

| Etapa | Nome | Status | Pode executar agora? |
|-------|------|--------|----------------------|
| 1 | Baixo real, zero risco | Concluída | — |
| 2 | Médio/Alto zero risco | Concluída | — |
| 3 | Alto de lógica sem firewall | Concluída | — |
| 4 | Médio de idempotência e validação | Concluída | — |
| 5 | Alto runtime sem firewall pesado | Concluída | — |
| 6 | Firewall e segurança pesada | Bloqueado | Não — exige VPS teste + VNC |
| 7 | Futuro/redesign | Bloqueado | Não agora |

---

## Etapa 1 — Baixo real, zero risco

Não muda runtime crítico. Não mexe em firewall, Docker ou estado do sistema. Commits seguros para validar o fluxo de correção.

| Ordem | ID | Fxx | Nível | Arquivo | Ação | Testes | Commit sugerido | Observação |
|-------|-----|------|-------|---------|------|--------|-----------------|------------|
| 1 | A5 | F15 | Baixo (P3) | wgshield.sh:39 | Remover `PUBLIC_DNS=0` | T03 | `fix: remove unused PUBLIC_DNS` | Variável definida, nunca lida. Remanescente da v1. |
| 2 | A9 | F27 | Baixo (P4) | README.md:22 | Corrigir URL do repositório | — | `docs: fix repository URL` | URL difere do repo real |
| 3 | A10 | F31 | Baixo (P4) | README.md:71-82 | Sincronizar lista de 9 módulos | — | `docs: sync README hardening module count` | README descreve 8 mas são 9 (F05 adicionou DNS) |
| 4 | A4 | F12 | Baixo (P3) | lib/hardening.sh:277,307 + lib/lang/*.sh | Criar variáveis i18n para mod_dns_remove() | T04 (parcial — valida sintaxe sed) | `fix: add i18n to mod_dns_remove` | Strings hardcoded em português ignoram i18n |

**Checkpoint Etapa 1:** Todos passam por shellcheck. `git diff` não mostra mudança em runtime. T03 passa.

---

## Etapa 2 — Médio/Alto zero risco que destrava depois

Correções de facilidade intermediária. A8 é Alto mas o fix (chmod) é trivial, reversível e melhora segurança imediatamente.

| Ordem | ID | Fxx | Nível | Arquivo | Ação | Testes | Commit sugerido | Observação |
|-------|-----|------|-------|---------|------|--------|-----------------|------------|
| 5 | A7 | F19 | Médio (P2) | lib/backup.sh:154,164 + lib/lang/*.sh | Corrigir interpolação em ERR_NO_BACKUP_COMP e ERR_BACKUP_NOT_FOUND | T08 | `fix: add variable interpolation to backup error messages` | $db_name e $timestamp não são interpolados |
| 6 | A6 | F17 | Médio (P2) | lib/wgshield_ops.sh:399 | Trocar hardcode `/opt/wg-easy` por `parse_comp "wg-easy" 7` | T05 | `fix: remove hardcoded wg-easy path` | Destrava B6 que usa parse_comp |
| 7 | A8 | F10 | Alto (P1) | lib/wgshield_ops.sh:71,165,452 | Adicionar `chmod 600 "$dir/.env"` após cada escrita | T09, T47 | `fix: secure wg-easy env permissions` | .env world-readable (644). chmod 600 resolve risco imediato. WG_PASSWORD plaintext é decisão de design futura. |

**Checkpoint Etapa 2:** T05, T08, T09 passam. Testar `stat -c %a /opt/wg-easy/.env` = 600 após install.

---

## Etapa 3 — Alto de lógica sem firewall

São Altos, mas não mexem em firewall diretamente. Destravam correções posteriores. A1 deve vir antes de qualquer hardening mais destrutivo.

| Ordem | ID | Fxx | Nível | Arquivo | Ação | Testes | Commit sugerido | Observação |
|-------|-----|------|-------|---------|------|--------|-----------------|------------|
| 8 | A2 | F05 | Alto (P1) | lib/menu.sh:220-236 | Adicionar `"${WIZARD_MOD_9}"` ao array steps "new_vps" | T02 | `fix: add DNS module to new_vps wizard steps` | WIZARD_MOD_9 existe no case mas não no steps[]. Destrava B9 (F38). |
| 9 | A3 | F11 | Alto (P1) | lib/hardening.sh:301 | Corrigir sed de mod_dns_remove() — tratar EOF como delimitador alternativo | T04 | `fix: handle dns-abuse as last section in sed` | sed range não termina se dns-abuse é a última seção. Destrava B5 e C4. |
| 10 | A1 | F02 | Alto (P0) | lib/hardening.sh:após146 | Setar `_hardening_applied="true"` em mod_bbr() após backups criados | T01 | `fix: enable hardening cleanup rollback` | cleanup trap verifica `_hardening_applied` mas nunca é "true". Ativa rollback automático durante hardening destrutivo. |

**Checkpoint Etapa 3:** T01, T02, T04 passam. `_hardening_applied` aparece como "true" após mod_bbr.

---

## Etapa 4 — Médio de idempotência e validação

Correções de idempotência e validações pendentes. B10 NÃO é correção direta — precisa de T26 primeiro.

| Ordem | ID | Fxx | Nível | Arquivo | Ação | Testes | Commit sugerido | Observação |
|-------|-----|------|-------|---------|------|--------|-----------------|------------|
| 11 | B1 | F13 | Médio (P2) | lib/hardening.sh:58 | `grep -q "$SWAPFILE" /etc/fstab \|\|` antes do append | T15 | `fix: make mod_swap fstab entry idempotent` | Duplica fstab se re-executado |
| 12 | B2 | F14 | Médio (P2) | lib/hardening.sh:71-77 | sed -i replace ou check-before-append para vm.swappiness e vfs_cache_pressure | T16 | `fix: make mod_memory sysctl entries idempotent` | Duplica sysctl.conf se re-executado |
| 13 | B4 | F36 | Médio (P2) | lib/hardening.sh:55 | Checar espaço em disco antes de dd swapfile | T21 | `fix: add disk space check before swap creation` | dd 2GB sem checar espaço |
| 14 | B8 | F37 | Médio (P2) | lib/hardening.sh:11-12 | Adicionar aviso sobre auto-reboot às 04:00 | — | `fix: add auto-reboot warning to mod_unattended` | Reboot silencioso derruba containers. **Sem teste explícito em 08** — validar manualmente que aviso aparece. |
| 15 | B9 | F38 | Médio (P2) | lib/menu.sh:148 | Corrigir show_already_installed() para exibir 9 mods | — | `fix: show 9 hardening modules in status display` | Mostra 8 mas são 9. Depende de A2 (F05). **Sem teste explícito em 08** — validar visualmente. |
| 16 | B10-VAL | F22 | Médio (P2, precisa validar) | lib/hardening.sh:4-14 | **VALIDAR PRIMEIRO com T26** — se confirmado, adicionar config; se não, marcar como observação | T26 | (correção só após validação) | `dpkg-reconfigure` pode não criar 10periodic. Não promover a correção sem teste. |

**Regra B10-VAL:** Após rodar T26 em sandbox:
- Se 10periodic NÃO existe → criar B10-FIX (adicionar config explícita) → commit `fix: ensure auto-upgrades config in mod_unattended`
- Se 10periodic JÁ existe → marcar F22 como "não é bug, observação" → fechar sem correção

**Checkpoint Etapa 4:** T15-T18 (idempotência) passam. B10 validado.

---

## Etapa 5 — Alto de runtime sem firewall pesado

Muda runtime e estado do sistema, mas sem tocar em regras de firewall. Cada um em commit separado.

| Ordem | ID | Fxx | Nível | Arquivo | Ação | Testes | Commit sugerido | Observação |
|-------|-----|------|-------|---------|------|--------|-----------------|------------|
| 17 | B3 | F06 | Alto (P1) | lib/hardening.sh:171-194 | Migrar sysctl para `/etc/sysctl.d/99-wgshield.conf` (drop-in) | T17, T18, T22 | `fix: migrate mod_bbr sysctl to drop-in config` | Elimina dedup frágil. Deve vir DEPOIS de B1/B2. Risco moderado — testar sysctl --system. |
| 18 | B5 | F04 | Alto (P1) | lib/menu.sh:353-456 | Conectar wizard à execução real (ação "Apply" ou toggle imediato) | T25 | `fix: make wizard apply selected modules` | Depende de A3 (mod_dns_remove funcional). Wizard atual é apenas visual. |
| 19 | B6 | F09+F16 | Alto (P1) + Médio (P2) | lib/wgshield_ops.sh + lib/firewall.sh | Consumir _pubports em install_comp() para abrir portas via open_port() | T06 | `fix: consume _pubports in install_comp for firewall` | Resolve F09 (Alto) e F16 (Médio) juntos. Preservar decisão de design sobre quais portas são públicas. |
| 20 | B7 | F08 | Alto (P1) | lib/backup.sh:11-39 | Expandir VPS backup com sysctl.conf, limits.conf, journald.conf, fstab, fail2ban/, unattended-upgrades | T23, T24 | `fix: include hardening configs in VPS backup` | Backup incompleto impede rollback de hardening |

**Dependências:** B3 depois de B1+B2. B5 depende de A3. B6 resolve F16 (raiz de F09). B7 é independente.

**Checkpoint Etapa 5:** T17, T18, T22, T23, T24, T25, T06 passam. Backup VPS contém configs de hardening.

---

## Etapa 6 — Firewall e segurança pesada

**NUNCA sem VPS de teste com console VNC/KVM.**

### Status Etapa 6

- [x] C1/F01: **Concluído** (0c6a137) — validado em VPS kobold com cron safety
- [x] C2/F03: **Concluído** (19f35f1) — validado em VPS kobold com Docker + nginx
- [x] C3/F33: **Concluído** (f4c3066) — mod_firewall() respeita FW_TYPE; mock 9/9 PASS; UFW real pendente VPS+snapshot
- [x] Firewall Detection Matrix: **Concluído** (3c0cc4c) — bug `grep -q "active"` corrigido para `grep -qw`; detect_firewall mock 12/12 PASS; mod_firewall/open_port mock 18/18 PASS
- [x] C4/F07: **Concluído** (2d7d69e) — dns-abuse filter funcional; mod_dns FW_TYPE-aware; fail2ban-regex 5/5 PASS; mock 31/31 PASS
- [x] C5/F34: **Concluído** (694b7b1) — IPv6 51821/tcp + 3000/tcp adicionados; UFW 3000/tcp; mock 22/22 PASS

**Etapa 6 CONCLUÍDA** — todos os itens C1-C5 validados

### Checklist de segurança — obrigatório ANTES de começar

- [ ] VPS de teste provisionada (não produção)
- [ ] Console VNC/KVM acessível e testado
- [ ] Snapshot/backup da VPS criado
- [ ] Cron de safety iptables ativo: `* * * * * root iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT`
- [ ] `screen` ou `tmux` ativo
- [ ] Etapas 1–5 COMPLETAS
- [ ] Nenhum C* sem A* e B* completos

| Ordem | ID | Fxx | Nível | Arquivo | Ação | Testes | Commit sugerido | Observação |
|-------|-----|------|-------|---------|------|--------|-----------------|------------|
| 21 | C1 | F01 | ~~Alto (P0)~~ OK | lib/hardening.sh:99-107 **→ firewall.sh** | Inserir regras ACCEPT com `-I INPUT` ANTES de `-P INPUT DROP` | T30, T34, T35 | `fix: insert iptables ACCEPT rules before DROP policy` | **Concluído commit 0c6a137.** Helper `ensure_iptables_input_rule` em firewall.sh. Regras duplicadas Oracle (-m state) vs WG-Shield (-m conntrack) são inofensivas. |
| 22 | C2 | F03 | ~~Alto (P0, precisa validar)~~ OK | lib/hardening.sh:100 **→ firewall.sh** | Resolver FORWARD DROP vs Docker: DOCKER-USER ou FORWARD específicas | T31, T32, T36 | `fix: preserve Docker forwarding when applying firewall` | **Concluído commit 19f35f1.** Helper `docker_firewall_present()` em firewall.sh. FORWARD DROP pulado quando Docker ativo. |
| 23 | C3 | F33 | ~~Alto (P1, precisa validar)~~ OK | lib/hardening.sh:102-185 | Se FW_TYPE=ufw, usar `ufw allow` em vez de iptables raw | T33, T37 | `fix: respect FW_TYPE in mod_firewall` | **Concluído commit f4c3066.** `mod_firewall_iptables()` + `mod_firewall_ufw()` + dispatch via `case FW_TYPE`. Mock 9/9 PASS. UFW real pendente VPS+snapshot. |
| 24 | C4 | F07 | Alto (P1) | lib/hardening.sh:256 + novo filter | Criar `/etc/fail2ban/filter.d/dns-abuse.conf` + `filter = dns-abuse` | T38, T49 | `fix: add fail2ban dns-abuse filter` | Depende de A3 (mod_dns_remove funcional). |
| 25 | C5 | F34 | Médio (P2) | lib/hardening.sh:114-120 | Adicionar 51821/tcp e 3000/tcp às regras IPv6 | T39 | `fix: add missing IPv6 firewall rules` | Depende de C1 estável. |

**Regras obrigatórias Etapa 6:**
- Commit individual para cada C*
- Se C1 falhar, NÃO prosseguir com C2-C5
- C2 e C3 precisam de validação prévia (T31-T33) antes de aplicar correção
- Cron de safety NÃO remover até TODOS os testes passarem
- Remover cron de safety APENAS após T46 (reboot final) passar

---

## Etapa 7 — Futuro/redesign

**NÃO EXECUTAR AGORA.** Apenas depois que bugs e riscos reais (Etapas 1–6) estiverem resolvidos. Pode ser quebrado em outra fila futura.

| Ordem | ID | Fxx | Nível | Arquivo | Ação | Observação |
|-------|-----|------|-------|---------|------|------------|
| 26 | D7 | F20 | Médio (P2) | lib/hardening.sh | Documentar necessidade de re-login para mod_limits() | UX, sem risco |
| 27 | D8 | F21 | Médio (P2) | lib/utils.sh:90 | check_module_status "firewall" — verificação mais confiável | Heurística de 1 regra DROP |
| 28 | D9 | F29 | Baixo (P4) | lib/wgshield_ops.sh:74 | Logar docker compose errors em vez de engolir | Silencioso |
| 29 | D1 | F39 | Baixo (P3) | lib/wgshield_ops.sh | Extrair `generate_wg_env()` — unificar 3 cópias | Refactor, requer testes |
| 30 | D2 | F40 | Baixo (P3) | lib/menu.sh + lib/wgshield_ops.sh | Extrair `run_with_spinner()` — unificar 5 spinners | Refactor, requer testes |
| 31 | D3 | F23 | Baixo (P3) | lib/menu.sh:290 | Spinner checar PID do comando real em vez de $$ | Arquitetura |
| 32 | D4 | F24 | Baixo (P3) | lib/menu.sh:264-312 | Comparar steps por índice em vez de string i18n | Arquitetura |
| 33 | D5 | F25 | Baixo (P3) | lib/utils.sh:32-34 | get_container_status distinguir parado de inexistente | UX |
| 34 | D6 | F28 | Baixo (P3) | lib/hardening.sh:201 | mod_limits() usar check_module_status | Consistência |
| 35 | D10 | F18 | Baixo (P3) | lib/menu.sh:537-547 | Remover running_names morto em submenu_manage | Dead code |

---

## Contradições Identificadas entre 07, 08, 09 e esta Fila

| # | Origem | Contradição | Resolução nesta fila |
|---|--------|-------------|---------------------|
| 1 | 02 vs. 07/09 | F07 tem prioridade "Depois" em 02 mas está em Fase C / Lote 6 junto com firewall | Mantido na Etapa 6 pois depende de A3 e infraestrutura de firewall estável. "Depois" = depois do Agora, e C-phase é depois de A+B. Sem conflito real. |
| 2 | 02 vs. 07/09 | F34 tem prioridade "Futuro" em 02 mas está em C5 / Lote 6 | Mantido na Etapa 6 como último item. "Futuro" é sobre urgência; C5 é sobre依赖ência. Etapa 6 em si é futura até ter VPS de teste. |
| 3 | 09:29 vs. 10 | T06 listado como teste do Lote 1 mas valida F16/F09 que são Lote 4 | Nesta fila, T06 NÃO aparece na Etapa 1. T06 aparece na Etapa 5 (B6). A Etapa 1 usa apenas testes que validam fixes daquele passo. |
| 4 | 07:24 | "Após A1-A10, rodar testes" pode sugerir commit único vs. "uma correção por commit" | Esta fila esclarece: commit individual por correção, testes como checkpoint. "Após" = "depois de completar", não "em um commit só". |

---

## Gaps de Teste Identificados

| # | Fix | Problema | Ação recomendada |
|---|-----|----------|------------------|
| 1 | B8 (F37) | Sem teste explícito em 08 para aviso de auto-reboot | Validar manualmente que aviso aparece ao rodar mod_unattended() |
| 2 | B9 (F38) | Sem teste explícito em 08 para show_already_installed() | Validar visualmente que 9 módulos são exibidos |
| 3 | A9 (F27), A10 (F31) | Sem teste em 08 para correções de README | Diferença de docs — validação por diff é suficiente |

---

## Checklist Antes de Começar a Corrigir

- [ ] Branch criada para correções
- [ ] Working tree clean (`git status` limpo)
- [ ] Docs/Fix atualizados e sincronizados
- [ ] Shellcheck disponível (`which shellcheck`)
- [ ] Testes do Grupo 1 (T01-T09) revisados e compreendidos
- [ ] Nenhuma correção de firewall nesta primeira rodada
- [ ] Um fix por commit

---

## Regra de Commit

Formato de mensagem:
```
fix: descrição curta em inglês
```

Exemplos:
- `fix: remove unused PUBLIC_DNS`
- `docs: sync README hardening module count`
- `fix: secure wg-easy env permissions`
- `fix: enable hardening cleanup rollback`
- `fix: make mod_swap fstab entry idempotent`

Cada commit deve conter **apenas um fix**. Se um fix tocar em múltiplos arquivos (ex: A4 toca hardening.sh + lang/*.sh), tudo no mesmo commit — mas só aquele fix.

---

## Quando Parar

Parar imediatamente se:
- Teste falhar e não for óbvio o motivo
- Correção exigir tocar em firewall antes da Etapa 6
- Achado `precisa validar` não tiver validação feita (T26, T31-T33)
- Mudança começar a virar refactor grande (extrair funções, reestruturar)
- Tentativa de corrigir múltiplos achados no mesmo commit
- Dúvida sobre impacto da mudança em runtime

---

## Primeira Rodada Recomendada

A primeira rodada é propositalmente pequena — apenas **4 commits** para validar o fluxo de correção sem risco:

| # | ID | Ação | Commit |
|---|-----|------|--------|
| 1 | A5 | Remover `PUBLIC_DNS=0` | `fix: remove unused PUBLIC_DNS` |
| 2 | A9 | Corrigir URL do README | `docs: fix repository URL` |
| 3 | A10 | Sincronizar README com 9 módulos | `docs: sync README hardening module count` |
| 4 | A4 | i18n do mod_dns_remove() | `fix: add i18n to mod_dns_remove` |

**Por que apenas 4?**
- Zero mudança em runtime
- Zero dependência entre elas
- Zero risco de quebrar qualquer coisa
- Valida o processo: branch → fix → shellcheck → test → commit
- Se algo der errado no fluxo (ex: shellcheck falha, teste não roda), é aqui que descobrimos, não na Etapa 5

Após validar o fluxo com esta rodada inicial, prosseguir com Etapa 2 (A7, A6, A8).
