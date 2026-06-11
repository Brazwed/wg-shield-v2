# 22 - WG-Easy Initial Password Fix

## Contexto

- Data: 2026-06-11
- Branch: `fix/execution-queue-round-1`
- Bug origem: senha inicial do WG-Easy exibida pelo install era inválida; reset pelo manager gerava senha válida
- Relacionado: `21_DOCKER_COMPOSE_FIX_TEST.md`

## Problema

| Sintoma | Detalhe |
|---|---|
| WG-Easy sobe healthy | HTTP 200 em :51821 |
| Login com senha inicial falha | API retorna 401 Unauthorized |
| Reset password funciona | Gera nova senha e login passa |

## Causa raiz

**Docker Compose interpola `$` em valores de arquivos `.env`**, tratando-os como referências de variáveis.

O hash bcrypt gerado por `wgpw` tem formato `$2a$12$xxxxx...` com múltiplos `$`. Quando escrito no `.env` como:

```
PASSWORD_HASH=$2a$12$xxxxx...
```

Docker Compose interpreta `$2a`, `$12`, `$xxxxx` como variáveis (todas vazias), corrompendo o hash para:

```
PASSWORD_HASH=$2a$12
```

### Evidência

Teste direto na VPS:

```
.env com:    TEST_HASH=$2a$12$n05vPGNoR9test
docker compose config mostra: TEST_HASH: $$2a$$12
container recebe: TEST_HASH=$2a$12   (hash truncado, 3º segmento perdido)
```

Com escape `$$`:

```
.env com:    TEST_HASH=$$2a$$12$$n05vPGNoR9test
docker compose config mostra: TEST_HASH: $$2a$$12$$n05vPGNoR9test
container recebe: TEST_HASH=$2a$12$n05vPGNoR9test  (hash correto)
```

### Padrão de código corrompido

O install e reset usavam a mesma lógica duplicada:

```bash
raw_output=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$wg_pass" 2>/dev/null)
raw_hash=$(echo "$raw_output" | sed "s|PASSWORD_HASH=||" | tr -d "'" | tr -d '\r' | tr -d '\n')
cat > "$dir/.env" << ENVEOF
PASSWORD_HASH=${raw_hash}
ENVEOF
```

Problemas:
1. `wgpw` output tem `2>/dev/null` — erros silenciados
2. `sed "s|PASSWORD_HASH=||"` não remove aspas simples corretamente (parser frágil)
3. Hash com `$` gravado sem escape `$$` no `.env`
4. Lógica duplicada 3 vezes (install silencioso, install interativo, reset)

## Correção

| Arquivo | Mudança |
|---|---|
| `lib/wgshield_ops.sh` | `escape_for_compose_env()`: substitui `$` por `$$` para Docker Compose |
| `lib/wgshield_ops.sh` | `generate_wg_password_hash()`: wrapper único para `wgpw` com parser robusto e error propagation |
| `lib/wgshield_ops.sh` | `write_wg_easy_env()`: grava `.env` com `chmod 600`, hash escapado com `$$` |
| `lib/wgshield_ops.sh` | install (silent): usa helpers compartilhados |
| `lib/wgshield_ops.sh` | install (interactive): usa helpers compartilhados |
| `lib/wgshield_ops.sh` | `reset_wg_password()`: usa helpers compartilhados |
| `lib/lang/pt_BR.sh` | `WG_PASSWORD_HASH_FAILED` |
| `lib/lang/en_US.sh` | `WG_PASSWORD_HASH_FAILED` |

### Design

- `wgpw` chamado em apenas 1 lugar (`generate_wg_password_hash`)
- `escape_for_compose_env()` é genérica — pode ser reutilizada para outros valores com `$`
- `write_wg_easy_env()` centraliza gravação do `.env` — elimina 3 duplicações de heredoc
- Parser usa `sed -n "s/^PASSWORD_HASH=//p" | tr -d "'"` — mais robusto

## Validação

| Teste | Resultado |
|---|---|
| `bash -n` wgshield_ops.sh | PASS |
| `bash -n` pt_BR.sh, en_US.sh | PASS |
| shellcheck (0 novos warnings) | PASS |
| `wgpw` só chamado em `generate_wg_password_hash` | PASS (grep confirma 1 ocorrência) |
| VPS: hash_len=60, dollars=3 | PASS (bcrypt correto) |
| VPS: .env dollars=6 (3×2 escaped) | PASS |
| VPS: container hash dollars=3 | PASS (`$$` → `$` no container) |
| VPS: login senha correta | HTTP 200 PASS |
| VPS: login senha errada | HTTP 401 PASS |
| VPS: HTTP 200 externo | PASS |

## Segurança

- Senha real logada? **Não** — apenas len/starts/ends
- Hash real logado? **Não** — apenas contagem de `$` e len
- `.env` chmod 600? **Sim** — `write_wg_easy_env` aplica chmod 600
- `wgpw` erros propagados? **Sim** — `2>&1` + `|| return 1`
- Volumes apagados? **Test only** — dados de teste limpos, produção preservada
- Firewall alterado? **Não**
- Duplicação de código eliminada? **Sim** — 3 blocos → 3 chamadas a 3 helpers

## Resultado

- Bug corrigido? **Sim** — login com senha inicial funciona
- Reset continua funcionando? **Sim** — usa mesmos helpers
- PR atualizado? **Pendente** — commits a seguir
