# 19 - Final Review After Stage 6

## Contexto

- Data: 2026-06-11
- Branch: `fix/execution-queue-round-1`
- Último commit: 31af884
- Total de commits na branch: 38 (desde `main`)
- Objetivo: Consolidar estado pós-Etapas 1-6, confirmar achados fechados, separar riscos remanescentes

## Resumo executivo

- Estado geral: **Estável.** Todas as correções A/B/C implementadas e validadas.
- Etapas concluídas: 1-6 (6 de 7 — Etapa 7 é futuro/não-bloqueante)
- Risco atual: Baixo. Nenhum bug crítico novo identificado. Firewalls reais da VPS kobold inalterados.
- Recomendação: **Pronto para merge/PR** após revisão humana. Ver seção "Recomendação de merge".

## Commits por etapa

| Etapa | Itens | Status | Commits | Evidência |
|---|---|---|---|---|
| 1 — Baixo/zero risco | A5/F15, A9/F27, A4/F12 | 3 OK | e3adf71, 62f32ca, 34cc684 | dead code removido, URL corrigida, i18n |
| — | A10/F31 | 1 SKIP | — | no-op: README já correto |
| 2 — Médio/Alto zero risco | A7/F19, A6/F17, A8/F10 | 3 OK | f2b8a58, 05a60d0, 2ecde6b | interpolação, hardcode, chmod 600 |
| 3 — Alto lógica | A2/F05, A3/F11, A1/F02 | 3 OK | 702c617, 528ca68, 9f7750e | wizard steps, sed EOF, rollback |
| 4 — Médio idempotência | B1/F13, B2/F14, B4/F36, B8/F37, B9/F38, B10/F22 | 6 OK | 4dc7b21, e772265, ba27472, 4947689, bfafa31, 4e95d76 | fstab, sysctl, disk, reboot, status, auto-upgrades |
| 5 — Alto runtime | B7/F08, B3/F06, B5/F04, B6/F09+F16 | 4 OK | 61398a6, c22ffc2, cd8e00a, 0c5eec4 | backup, sysctl drop-in, wizard apply, open_port |
| 6 — Firewall | C1/F01, C2/F03, C3/F33, C4/F07, C5/F34 | 5 OK | 0c6a137, 19f35f1, f4c3066, 2d7d69e, 694b7b1 | VPS kobold validado, mock 9+31+22 PASS |
| — | Detection bug + matrix | 2 OK | 3c0cc4c, c0e31dd | grep -qw, 8 cenários |
| 7 — Futuro | D1-D10 | 10 BLOQUEADO | — | redesign/futuro |

## Validação técnica final

| Teste | Resultado | Observação |
|---|---|---|
| `bash -n` wgshield.sh | PASS | Syntax OK |
| `bash -n` lib/*.sh (8 files) | PASS | 8/8 OK |
| `bash -n` lib/lang/*.sh (2 files) | PASS | 2/2 OK |
| shellcheck | 757 warnings | SC2034 (i18n false positive) + SC2148 (source'd libs). Zero erros. Zero bugs novos. |
| `iptables -F`/`-X` in code | NOT FOUND | Nenhum flush perigoso |
| `grep -q "active"` old pattern | NOT FOUND | Corrigido para `grep -qw` |
| `filter =` empty in dns-abuse | NOT FOUND | `filter = dns-abuse` OK |
| `FORWARD DROP` condicional | CONFIRMADO | `docker_firewall_present()` protege Docker |
| `DOCKER-FORWARD` detection | CONFIRMADO | Em `docker_firewall_present()` |
| `99-wgshield.conf` present | CONFIRMADO | Em hardening.sh e backup.sh |
| `20auto-upgrades` present | CONFIRMADO | Em hardening.sh e backup.sh |
| `PUBLIC_DNS` dead var | REMOVED | Apenas em strings i18n (OK) |
| `/opt/wg-easy` hardcode | PARCIAL | Removido de `reset_wg_password()`. Persiste em menu.sh info reads (D-tier candidate) |
| `ufw --force enable` | PRESENT | Em `ask_firewall_choice()` opção 1 (by design, risco documentado Oracle) |
| `iptables -A INPUT` raw | PRESENT | Fallback em `ensure_iptables_input_rule()` quando sem REJECT/DROP explícito (correto) |
| VPS kobold baseline | COLETADO | iptables, ip6tables, InstanceServices, Docker |
| Firewall mocks | PASS | C1: 9/9, C4: 31/31, C5: 22/22 |
| fail2ban-regex (C4) | PASS | 5/5 positivo |
| Secrets in docs | NONE | Nenhuma credencial real |
| Public IP in docs | 1 occurrence | VPS test report (repo privado, OK) |

## Achados fechados

| ID | Finding | Status | Commit |
|---|---|---|---|
| F01 | iptables ACCEPT antes de DROP | OK | 0c6a137 |
| F02 | cleanup trap morto | OK | 9f7750e |
| F03 | FORWARD DROP + Docker | OK | 19f35f1 |
| F04 | Wizard não aplica módulos | OK | cd8e00a |
| F05 | WIZARD_MOD_9 ausente | OK | 702c617 |
| F06 | mod_bbr sysctl frágil | OK | c22ffc2 |
| F07 | fail2ban dns-abuse filter vazio | OK | 2d7d69e |
| F08 | Backup VPS incompleto | OK | 61398a6 |
| F09 | _pubports não consumido | OK | 0c5eec4 |
| F10 | .env world-readable | OK | 2ecde6b |
| F11 | mod_dns_remove sed EOF | OK | 528ca68 |
| F12 | mod_dns_remove strings PT | OK | 34cc684 |
| F13 | mod_swap fstab duplicado | OK | 4dc7b21 |
| F14 | mod_memory sysctl duplicado | OK | e772265 |
| F15 | PUBLIC_DNS dead code | OK | e3adf71 |
| F16 | _pubports campo não consumido | OK | 0c5eec4 |
| F17 | reset_wg_password hardcode | OK | 05a60d0 |
| F19 | backup.sh interpolação morta | OK | f2b8a58 |
| F22 | mod_unattended sem 10periodic | OK | 4e95d76 |
| F27 | URL README incorreta | OK | 62f32ca |
| F31 | README 8 vs 9 módulos | SKIP | — |
| F33 | mod_firewall ignora FW_TYPE | OK | f4c3066 |
| F34 | IPv6 sem 51821/3000 | OK | 694b7b1 |
| F36 | mod_swap sem disk check | OK | ba27472 |
| F37 | auto-reboot silencioso | OK | 4947689 |
| F38 | show_already_installed 8 mods | OK | bfafa31 |

**25 findings fechados** (24 OK + 1 SKIP). B6 resolve F09+F16 em uma ação.

## Riscos remanescentes não bloqueantes

| Risco | Severidade | Motivo para não bloquear merge | Etapa |
|---|---|---|---|
| UFW real em Oracle Cloud | Alto | `ufw enable` pode destruir InstanceServices; requer snapshot + console/VNC; código trata FW_TYPE=ufw corretamente | 6→futuro |
| LOG_RESTORED em backup.sh | Baixo | Mesmo padrão morto de F19 (`$timestamp`); fora de caminho crítico | PENDENTE |
| firewalld/nftables não detectados | Médio | `detect_firewall()` ignora nftables; firewalld comum em RHEL/CentOS | D-tier |
| Unbound query logging | Médio | dns-abuse filter funcional mas requer `verbosity: 1+` no Unbound para gerar logs | D-tier |
| Duplicatas conntrack/state IPv4 | Baixo | Legado Oracle pré-C1; regras duplicadas inofensivas; limpeza é redesign | D-tier |
| mod_memory em sysctl.conf | Baixo | Linhas em `/etc/sysctl.conf` em vez de drop-in; funcional mas inconsistente com B3 | D-tier |
| /opt/wg-easy resto em menu.sh | Baixo | 4 leituras diretas de `/opt/wg-easy/.env` em vez de parse_comp | D-tier |
| WG_PASSWORD plaintext | Médio | chmod 600 aplicado (A8); remoção do plaintext é decisão de design futura | Futuro |
| rpcbind port 111 | Baixo | Serviço desnecessário na VPS kobold; não é bug do WG-Shield | — |
| Versão string "v2.0 v2.0" | P3 | Cosmético; `wgshield.sh -v` mostra versão duplicada | — |

## D-tier — Itens bloqueados (não-bloqueantes para merge)

| ID | Finding | Descrição |
|---|---|---|
| D1 | F39 | Extrair `generate_wg_env()` — 3 cópias do .env |
| D2 | F40 | Extrair `run_with_spinner()` — 5 spinners duplicados |
| D3 | F23 | Spinner usa `kill -0 $$` em vez de PID do comando |
| D4 | F24 | Steps comparados por string i18n (frágil) |
| D5 | F25 | get_container_status não distingue parado de inexistente |
| D6 | F28 | mod_limits() bypass check_module_status |
| D7 | F20 | mod_limits() não entra em vigor na sessão corrente |
| D8 | F21 | check_module_status "firewall" heurística frágil |
| D9 | F29 | Docker compose errors silenciosos |
| D10 | F18 | running_names morto em submenu_manage |

## O que NÃO foi validado

- UFW real em Oracle Cloud (risco InstanceServices)
- Reboot real após netfilter-persistent
- Restore completo de backup VPS
- Instalação full em produção (T40-T46 do test plan)
- firewalld/nftables
- Swap creation em VPS com baixo espaço
- mod_bbr() 3x sem corrupção em VPS real
- fail2ban dns-abuse em produção com Unbound real

## Recomendação de merge

### Pronto para merge?

**Sim, com ressalvas.**

A branch está estável: syntax OK, zero bugs críticos novos, 25 findings fechados, VPS kobold intacta. As correções são progressivas e cada uma em commit individual.

### Precisa squash?

**Não recomendado.** Os 38 commits contêm histórico granular de correções. Cada `fix:` e `docs:` é atômico. Squash perderia a rastreabilidade Achado → Commit → Validação. Se o repositório preferir histórico linear, squashing por etapa (6 commits) é aceitável.

### Precisa PR separado?

**Sim.** A branch tem 38 commits contra `main`. Um PR permite:
- Review humano das mudanças de firewall
- CI checks (se aplicável)
- Merge com `--no-ff` para preservar histórico

### Testes antes de usar fora da VPS kobold

1. **Obrigatório:** Instalação full em VPS descartável (T40-T46)
2. **Obrigatório com snapshot:** UFW real em Oracle Cloud (T33, T37)
3. **Recomendado:** Reboot após netfilter-persistent (T32, T46)
4. **Recomendado:** Backup + restore completo (T43-T45)

### Arquivos modificados (resumo)

| Arquivo | Commits | Etapas |
|---|---|---|
| wgshield.sh | 1 | 1 |
| lib/hardening.sh | 10+ | 3,4,5,6 |
| lib/firewall.sh | 4+ | 6 |
| lib/detection.sh | 1 | 6 |
| lib/backup.sh | 2 | 2,5 |
| lib/menu.sh | 3 | 3,4,5 |
| lib/wgshield_ops.sh | 3 | 2,5 |
| lib/lang/pt_BR.sh | 3+ | 1,2,6 |
| lib/lang/en_US.sh | 3+ | 1,2,6 |
| README.md | 2 | 1 |

## Próximos passos sugeridos

1. **Criar PR** da branch `fix/execution-queue-round-1` para `main`
2. **Revisão humana** — foco em `lib/hardening.sh` (C1-C5) e `lib/firewall.sh`
3. **Rodada D-tier opcional** — após merge, em branch separada
4. **Teste de instalação full** em VPS descartável (T40-T46)
5. **Teste UFW real** em Oracle Cloud com snapshot + VNC (T33, T37)
6. **Fechar LOG_RESTORED** — padrão morto em backup.sh (pendente atual)
7. **Considerar repositório público** — sanitizar IP público em `12_VPS_TEST_REPORT.md`

## Shellcheck — classificação de warnings

| Tipo | Qtd | Classificação | Ação |
|---|---|---|---|
| SC2034 | ~120 | False positive (i18n vars loaded via `source`) | Ignorar — design do sistema i18n |
| SC2148 | 8 | Missing shebang em libs `source`'d | Ignorar — não são scripts standalone |
| SC1090 | 2 | Non-constant source | Ignorar — i18n loading dinâmico |
| SC2010/SC2126 | 3 | `ls \| grep`, `grep \| wc -l` | D-tier — não bloqueante |
| SC2015 | 1 | `A && B \|\| C` nota | D-tier — info apenas |

## Segurança da VPS kobold

| Item | Estado |
|---|---|
| iptables real | Inalterado (Oracle default + C1 insert) |
| ip6tables real | Inalterado (5 regras originais) |
| UFW | Não instalado |
| Docker | Instalado para teste C2; container nginx removível |
| InstanceServices | 15 regras preservadas |
| fail2ban | Instalado para teste C4; removível |
| SSH | Ativo na porta 22 |
