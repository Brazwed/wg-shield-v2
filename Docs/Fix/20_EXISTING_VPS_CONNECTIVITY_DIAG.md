# 20 - Existing VPS Connectivity Diagnosis

## Contexto

- Data: 2026-06-11
- VPS: kobold / Oracle Cloud / Ubuntu 24.04.4 LTS
- Branch/commit: `fix/execution-queue-round-1` (pós-merge local)
- Instalação testada: "Existing VPS - Safe Install" via menu
- URLs exibidas:
  - WG-Easy: `http://136.248.69.230:51821`
  - AdGuard Home: `http://10.8.1.3:3000` (via VPN)

## Resultado rápido

| Serviço | URL | Status | Diagnóstico |
|---|---|---|---|
| WG-Easy | http://136.248.69.230:51821 | FALHA | Container nunca iniciou — sem docker compose |
| WireGuard UDP | 136.248.69.230:51820 | FALHA | Sem container = sem VPN |
| AdGuard Home | http://10.8.1.3:3000 | FALHA | Container nunca iniciou |
| Unbound DNS | 10.8.1.4:53 | FALHA | Container nunca iniciou |

## Containers

| Container | Status | Portas | Observação |
|---|---|---|---|
| wg-easy | NÃO EXISTE | — | `docker compose` falhou silenciosamente |
| adguard | NÃO EXISTE | — | Depende de `wg-net` que nunca foi criada |
| unbound | NÃO EXISTE | — | Depende de `wg-net` que nunca foi criada |
| wgshield-c2-nginx | Up | 18080->80/tcp | Container de teste C2 (irrelevante) |

## Portas

| Porta | Local listener | Docker publish | Firewall local | Oracle ingress | Status |
|---|---|---|---|---|---|
| 51821/tcp | NENHUM | N/A | ACEITO (iptables rule 8) | Não testado | FALHA — sem container |
| 51820/udp | NENHUM | N/A | ACEITO (iptables rule 7) | Não testado | FALHA — sem container |
| 3000/tcp | NENHUM | N/A | Não aberto (VPN-only) | N/A | FALHA — sem container |
| 53/tcp | systemd-resolved | N/A | N/A | N/A | Ocupado por systemd-resolved |
| 53/udp | systemd-resolved | N/A | N/A | N/A | Ocupado por systemd-resolved |

## Diagnóstico — Causa Raiz

### Docker Compose NÃO está instalado

| Item | Resultado |
|---|---|
| `docker --version` | Docker 29.1.3 (docker.io, Ubuntu package) |
| `docker compose version` | **FALHA**: `unknown shorthand flag 'd' in -d` |
| `docker-compose --version` | **FALHA**: `command not found` |
| `docker-compose-plugin` (dpkg) | **NÃO INSTALADO** |

### Cadeia de eventos

1. VPS tinha Docker pré-instalado via `docker.io` (Ubuntu package, sem compose plugin)
2. Install "Existing VPS" detectou Docker → **pulou instalação do Docker**
3. `docker.io` NÃO inclui `docker-compose-plugin`
4. `lib/docker.sh:40` instalaria `docker-ce + docker-compose-plugin`, mas foi pulado
5. Todos os `docker compose up -d` em `lib/wgshield_ops.sh` falharam silenciosamente
6. Output redirecionado para `/dev/null` — erro engolido
7. Install reportou sucesso sem verificar estado dos containers

### Evidências

| Evidência | Log |
|---|---|
| `docker compose up -d` → "unknown shorthand flag 'd'" | `docker-compose-test.txt` |
| Apenas nginx de teste C2 em `docker ps -a` | `docker-ps-a.txt` |
| Nenhum container wg-easy/adguard/unbound | `docker-ports.txt` |
| `wg-net` network não existe | `docker-network-ls.txt` |
| 127.0.0.1:51821 connection refused | `curl-local-wg-easy.txt` |
| 136.248.69.230:51821 connection refused | teste externo |
| Imagem `wg-easy:latest` baixada mas container nunca criado via compose | `docker images` |
| Containers `stoic_saha` e `recursing_sinoussi` = `docker run --rm` para gerar PASSWORD_HASH | `docker events` |

### Detalhe dos containers efêmeros

Docker events mostram dois containers `ghcr.io/wg-easy/wg-easy` criados, iniciados, mortos (exitCode=0 after 2s) e destruídos. Nomes aleatórios (`stoic_saha`, `recursing_sinoussi`) = `docker run --rm` sem `--name`. Estes são os containers de hashing de senha em `lib/wgshield_ops.sh:58,160`:

```bash
raw_output=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$wg_pass" 2>/dev/null)
```

Estes NÃO são containers de serviço — são one-shot password hashers. Funcionaram corretamente. O problema é que os containers de serviço via `docker compose up -d` nunca foram iniciados.

## .env do WG-Easy (sanitizado)

| Variável | Valor | Correto? |
|---|---|---|
| WG_HOST | 136.248.69.230 | SIM |
| PASSWORD_HASH | REDACTED | SIM |
| WG_PASSWORD | REDACTED | SIM |
| WG_DEFAULT_DNS | 10.8.1.3 | SIM (AdGuard VPN IP) |
| WG_PORT_UDP | 51820 | SIM |
| WG_PORT_TCP | 51821 | SIM |

## Firewall

iptables INPUT chain tem as regras corretas (C1 fix ativo):
- `-A INPUT -p udp -m udp --dport 51820 -j ACCEPT` (rule 7)
- `-A INPUT -p tcp -m tcp --dport 51821 -j ACCEPT` (rule 8)
- FORWARD via DOCKER-USER + DOCKER-FORWARD (Docker ativo, C2 safe)
- InstanceServices: 15 regras preservadas

**Firewall NÃO é o problema.** O problema é que não há nada escutando nas portas.

## IPv6

ip6tables INPUT chain:
- lo: ACCEPT
- conntrack: ACCEPT
- ipv6-icmp: ACCEPT
- SSH 22: ACCEPT
- 51820/udp: ACCEPT
- **51821/tcp: AUSENTE** (regra IPv6 do C5 não aplicada na VPS — apenas código corrigido)
- **3000/tcp: AUSENTE**

Nota: As correções C5 não foram aplicadas na VPS real (apenas código), mas isso é irrelevante enquanto não há containers.

## Oracle Cloud Security List / NSG

Não verificadas — irrelevante enquanto containers não estão rodando. Portas 51820/51821 precisarão de ingress rules no Oracle quando containers estiverem ativos.

## Diagnóstico final

- **Causa provável**: `docker-compose-plugin` não instalado → `docker compose up -d` falha silenciosamente → containers nunca iniciam
- **Evidência**: `docker compose` retorna erro; 0 containers de serviço; `wg-net` network não existe
- **Código afetado**:
  - `lib/docker.sh:40` — instalação do Docker pula se já instalado, sem verificar compose
  - `lib/wgshield_ops.sh:76,185,214` — `docker compose up -d` com output suprimido
  - `lib/wgshield_ops.sh:58,160,450` — `docker run --rm` funciona (separado de compose)

## É bug do WG-Shield?

**Sim.** Dois bugs:

1. **Bug de detecção**: Install "Existing VPS" detecta que Docker está instalado mas NÃO verifica se `docker compose` está disponível. VPS com `docker.io` (Ubuntu package) não tem compose.
2. **Bug de silenciamento**: `docker compose up -d 2>&1 >/dev/null` engole erros. Install reporta sucesso sem verificar que containers estão rodando.

## Ação imediata sugerida (NÃO executar agora — documentar)

### Workaround na VPS (sem alterar código):

```bash
sudo apt-get install -y docker-compose-v2
# ou
sudo apt-get install -y docker-compose-plugin

cd /opt/wg-easy && sudo docker compose up -d
cd /opt/adguard && sudo docker compose up -d
cd /opt/unbound && sudo docker compose up -d
```

### Correção de código (futuro commit):

1. `lib/docker.sh`: após detectar Docker instalado, verificar `docker compose version` ou `docker-compose --version`
2. Se compose não disponível: instalar `docker-compose-plugin` (ou `docker-compose-v2`)
3. `lib/wgshield_ops.sh`: `docker compose up -d` deve verificar exit code e/ou confirmar container rodando após start
4. Não suprimir saída de erro de compose em flows críticos

### Possíveis configurações do Oracle Cloud:

- Verificar/adicionar ingress rules para 51820/udp e 51821/tcp no Security List da VCN
- 3000/tcp (AdGuard) e 53 (DNS) são VPN-only — não precisam ser públicos

## Segurança

- Nenhum firewall alterado durante diagnóstico
- Nenhum container destruído
- Nenhum serviço modificado
- Senhas sanitizadas em todos os logs
- .env lido apenas com REDACTED
