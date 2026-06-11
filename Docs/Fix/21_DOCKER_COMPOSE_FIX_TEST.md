# 21 - Docker Compose Install/Start Fix Test

## Contexto

- Data: 2026-06-11
- Branch: `fix/execution-queue-round-1`
- Bug origem: Docker instalado sem Docker Compose; install pulava Compose; containers nunca subiam
- Relatório origem: `20_EXISTING_VPS_CONNECTIVITY_DIAG.md`

## Problema

| Bug | Detalhe |
|---|---|
| Docker detectado sem Compose | `docker.io` (Ubuntu) não inclui compose plugin |
| install pulava instalação do Docker | `has_docker` retornava true → `install_docker()` retornava 0 |
| `docker compose up -d` falhava silenciosamente | Output redirecionado para `/dev/null` |
| install reportava sucesso indevido | Nenhuma verificação de container rodando |

## Correção

| Arquivo | Mudança |
|---|---|
| `lib/docker.sh` | Adicionado `has_docker_compose()`, `docker_compose()`, `ensure_docker_compose()`, `ensure_container_running()` |
| `lib/docker.sh` | `install_docker()`: chama `ensure_docker_compose` quando Docker já existe E após fresh install |
| `lib/wgshield_ops.sh` | Todas as chamadas `docker compose` substituídas por `docker_compose` |
| `lib/wgshield_ops.sh` | Silent mode: `docker_compose up -d` verifica exit code; retorna 1 se falhar |
| `lib/wgshield_ops.sh` | Interactive mode: `docker_compose up -d` verifica exit code; mostra erro |
| `lib/wgshield_ops.sh` | `install_comp()`: chama `ensure_docker_compose` antes de subir containers |
| `lib/wgshield_ops.sh` | `install_comp()`: `ensure_container_running()` após start para validação |
| `lib/lang/pt_BR.sh` | 8 novas strings: `DOCKER_COMPOSE_INSTALLING`, `DOCKER_COMPOSE_READY`, `DOCKER_COMPOSE_MISSING`, etc. |
| `lib/lang/en_US.sh` | 8 novas strings correspondentes em inglês |

## Testes

| Teste | Resultado |
|---|---|
| `bash -n` docker.sh | PASS |
| `bash -n` wgshield_ops.sh | PASS |
| `bash -n` pt_BR.sh | PASS |
| `bash -n` en_US.sh | PASS |
| shellcheck | 0 novos warnings relevantes |
| VPS `has_docker_compose` antes do fix | FAIL (exit 1) |
| VPS `ensure_docker_compose` instalou `docker-compose-v2` | OK |
| VPS `has_docker_compose` depois do fix | PASS (exit 0) |
| VPS `docker compose version` | Docker Compose 2.40.3 |
| VPS `docker_compose` wrapper | PASS |
| VPS wg-easy container | UP (healthy) |
| VPS adguard container | UP |
| VPS unbound container | UP |
| VPS 127.0.0.1:51821 curl | HTTP 200 |
| VPS 136.248.69.230:51821 curl (externo) | HTTP 200 |

## Resultado na VPS existente

| Serviço | Container | Porta | Status |
|---|---|---|---|
| WG-Easy | wg-easy | 51820/udp, 51821/tcp | UP (healthy) |
| AdGuard Home | adguard | 53, 3000 (via VPN) | UP |
| Unbound DNS | unbound | 53 (via VPN) | UP |

## Diagnóstico pós-correção

- Causa resolvida? **Sim** — `ensure_docker_compose()` instala plugin quando ausente
- Containers sobem? **Sim** — todos os 3 rodando
- 51821 local responde? **Sim** — HTTP 200
- 51821 externo responde? **Sim** — HTTP 200 (Oracle NSG permite)
- Restam bloqueios externos Oracle? **Não** — porta já acessível

## Segurança

- Firewall alterado? **Não** — regras pré-existentes C1 já permitiam 51820/51821
- Docker volumes apagados? **Não** — nenhum dado perdido
- Senhas sanitizadas? **Sim** — logs contêm apenas REDACTED
- `docker run --rm` para password hashing? **Intacto** — não usa compose, não foi alterado
