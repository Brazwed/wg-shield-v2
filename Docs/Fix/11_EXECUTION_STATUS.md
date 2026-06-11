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

| ID      | Fxx       | Status   | Commit | Observação                                  |
| ------- | --------- | -------- | ------ | ------------------------------------------- |
| B1      | F13       | PENDENTE | —      | mod_swap fstab idempotente                  |
| B2      | F14       | PENDENTE | —      | mod_memory sysctl idempotente               |
| B4      | F36       | PENDENTE | —      | Checar espaço antes de dd swap              |
| B8      | F37       | PENDENTE | —      | Aviso de auto-reboot                         |
| B9      | F38       | PENDENTE | —      | Mostrar 9 mods no status (destravado por A2) |
| B10-VAL | F22       | PENDENTE | —      | Precisa T26 em sandbox antes de corrigir     |

## Etapa 5 — Alto runtime sem firewall pesado

| ID | Fxx      | Status   | Commit | Observação                        |
| -- | -------- | -------- | ------ | --------------------------------- |
| B3 | F06      | PENDENTE | —      | Migrar sysctl.d drop-in          |
| B5 | F04      | PENDENTE | —      | Wizard aplica módulos            |
| B6 | F09+F16  | PENDENTE | —      | Consumir _pubports              |
| B7 | F08      | PENDENTE | —      | Expandir backup VPS             |

## Etapa 6 — Firewall e segurança pesada

| ID | Fxx | Status   | Commit | Observação                              |
| -- | --- | -------- | ------ | --------------------------------------- |
| C1 | F01 | BLOQUEADO | —     | P0; exige VPS teste + VNC               |
| C2 | F03 | BLOQUEADO | —     | Precisa validar; exige VPS teste + VNC  |
| C3 | F33 | BLOQUEADO | —     | Precisa validar; exige VPS teste + VNC  |
| C4 | F07 | BLOQUEADO | —     | Depende de A3 (OK); exige VPS teste     |
| C5 | F34 | BLOQUEADO | —     | Depende de C1 estável                   |

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

| Item         | Tipo               | Status   | Observação                                                          |
| ------------ | ------------------ | -------- | ------------------------------------------------------------------- |
| Shellcheck   | ferramenta         | PENDENTE | Não instalado; recomendado antes da Etapa 4                         |
| LOG_RESTORED  | possível follow-up | PENDENTE | Mesmo padrão morto de interpolação (`$timestamp`), fora do escopo de F19 |
| A10/F31      | no-op verificado   | OK       | README já correto; bug real (NEW VPS não instala WIZARD_MOD_9) corrigido em A2 |

---

## Resumo

| Status     | Qtd |
| ---------- | --- |
| OK         | 10  |
| SKIP       | 1   |
| PENDENTE   | 10  |
| BLOQUEADO  | 15  |

**Progresso:** 11/36 achados endereçados (10 corrigidos + 1 no-op verificado)
