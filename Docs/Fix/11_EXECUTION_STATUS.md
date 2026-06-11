# 11 - Status de Execução das Correções

Atualizado em: 11/06/2026

Branch: `fix/execution-queue-round-1`

---

## Etapa 1 — Baixo real, zero risco

| ID  | Fxx | Status | Commit  | Observação                                              |
| --- | --- | ------ | ------- | ------------------------------------------------------- |
| A5  | F15 | OK     | e3adf71 | `PUBLIC_DNS=0` removido                                 |
| A9  | F27 | OK     | 62f32ca | URL do README corrigida                                 |
| A10 | F31 | SKIP   | —       | README já tinha 9 módulos; bug real permanece em F05/A2 |
| A4  | F12 | OK     | 34cc684 | i18n adicionado ao mod_dns_remove                       |

## Etapa 2 — Médio/Alto zero risco

| ID | Fxx | Status | Commit  | Observação                                           |
| -- | --- | ------ | ------- | ---------------------------------------------------- |
| A7 | F19 | OK     | f2b8a58 | Placeholders `$db_name` e `$timestamp` nas mensagens |
| A6 | F17 | OK     | 05a60d0 | Hardcode `/opt/wg-easy` removido; usa `parse_comp`   |
| A8 | F10 | OK     | 2ecde6b | `chmod 600` nos 3 pontos de escrita do .env          |

## Etapa 3 — Alto de lógica sem firewall

| ID | Fxx | Status | Commit  | Observação                                                    |
| -- | --- | ------ | ------- | ------------------------------------------------------------- |
| A2 | F05 | OK     | 702c617 | `WIZARD_MOD_9` adicionado ao array steps de new_vps          |
| A3 | F11 | OK     | 528ca68 | sed→awk em mod_dns_remove; dns-abuse como última seção       |
| A1 | F02 | OK     | 9f7750e | `_hardening_applied="true"` em mod_bbr() após backups        |

## Etapa 4 — Médio de idempotência e validação

| ID      | Fxx       | Status | Commit   | Observação                                                                  |
| ------- | --------- | ------ | -------- | --------------------------------------------------------------------------- |
| B1      | F13       | OK     | 4dc7b21  | `grep -q` antes de append no fstab                                          |
| B2      | F14       | OK     | e772265  | sed replace ou append para swappiness e vfs_cache_pressure                  |
| B4      | F36       | OK     | ba27472  | `df --output=avail` checa 2300MB antes de dd; i18n `HARDEN_SWAP_NOSPACE`   |
| B8      | F37       | OK     | 4947689  | `warn` com i18n `HARDEN_UNATTENDED_REBOOT_WARN` antes dos sed              |
| B9      | F38       | OK     | bfafa31  | `"dns"` + `${WIZARD_MOD_9}` adicionados ao arrays em show_already_installed  |
| B10-VAL | F22       | OK     | 4e95d76  | Bug confirmado via VPS kobold; `20auto-upgrades` criado explicitamente; `dpkg-reconfigure` removido |

## Etapa 5 — Alto runtime sem firewall pesado

| ID | Fxx      | Status | Commit   | Observação                                                                |
| -- | -------- | ------ | -------- | ------------------------------------------------------------------------- |
| B7 | F08      | OK     | 61398a6  | Backup VPS inclui system/, fail2ban/, apt/ com configs de hardening         |
| B3 | F06      | OK     | c22ffc2  | sysctl.conf→99-wgshield.conf drop-in; lógica grep-v/frágil removida       |
| B5 | F04      | OK     | cd8e00a  | Wizard [A] Apply chama mod_* e install_comp; i18n MSG_WIZARD_APPLY        |
| B6 | F09+F16 | OK     | 0c5eec4  | `pubports` consumido em install_comp; portas públicas abertas via open_port |

## Etapa 6 — Firewall e segurança pesada

| ID | Fxx | Status   | Commit | Observação                              |
| -- | --- | -------- | ------ | --------------------------------------- |
| C1 | F01 | OK     | 0c6a137  | ensure_iptables_input_rule insere ACCEPT antes de DROP; VPS kobold OK |
| C2 | F03 | OK     | 19f35f1  | docker_firewall_present() preserva FORWARD; VPS kobold com Docker OK |
| C3 | F33 | OK     | f4c3066  | mod_firewall() respeita FW_TYPE; mock 9/9 PASS; UFW real pendente VPS+snapshot |
| C4 | F07 | OK     | 2d7d69e  | dns-abuse filter funcional; mod_dns FW_TYPE-aware; fail2ban-regex 5/5 PASS |
| C5 | F34 | BLOQUEADO | —     | Depende de C1 estável                                                   |

## Etapa 7 — Futuro/redesign

| ID       | Fxx              | Status   | Commit | Observação          |
| -------- | ---------------- | -------- | ------ | ------------------- |
| D7       | F20              | BLOQUEADO | —     | Futuro              |
| D8       | F21              | BLOQUEADO | —     | Futuro              |
| D9       | F29              | BLOQUEADO | —     | Futuro              |
| D1       | F39              | BLOQUEADO | —     | Futuro              |
| D2       | F40              | BLOQUEADO | —     | Futuro              |
| D3       | F23              | BLOQUEADO | —     | Futuro              |
| D4       | F24              | BLOQUEADO | —     | Futuro              |
| D5       | F25              | BLOQUEADO | —     | Futuro              |
| D6       | F28              | BLOQUEADO | —     | Futuro              |
| D10      | F18              | BLOQUEADO | —     | Futuro              |

---

## Pendências / follow-ups

| Item           | Tipo               | Status   | Observação                                                                  |
| -------------- | ------------------ | -------- | --------------------------------------------------------------------------- |
| Shellcheck     | ferramenta         | OK       | v0.11.0 instalado; SC2086 em mod_dns eliminado por C4                    |
| LOG_RESTORED   | possível follow-up | PENDENTE | Mesmo padrão morto de interpolação (`$timestamp`), fora do escopo de F19    |
| A10/F31        | no-op verificado   | OK       | README já correto; bug real corrigido em A2                                 |
| Firewall Matrix| validação          | OK       | Detecção UFW/iptables/none validada; bug grep -qw corrigido; UFW real pendente |

---

## Resumo

| Status     | Qtd |
| ---------- | --- |
| OK         | 22  |
| SKIP       | 1   |
| PENDENTE   | 1   |
| BLOQUEADO  | 13  |

**Progresso:** 23/36 achados endereçados (22 corrigidos + 1 no-op verificado)
