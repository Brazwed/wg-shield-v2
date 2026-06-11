# 14 - C2 Docker Forward Test Report

## Contexto

- Data: 2026-06-11
- VPS: kobold / Oracle Cloud / Ubuntu 24.04.4 LTS (Noble) + Docker 29.1.3
- Branch/commit testado: fix/execution-queue-round-1 @ 19f35f1
- Objetivo: C2/F03 somente — FORWARD DROP + Docker

## Safety aplicado

| Item | Status | Evidência |
|---|---|---|
| Baseline Oracle restaurado | OK | iptables-restore de C1 backup; FORWARD ACCEPT+REJECT |
| Docker instalado | OK | docker.io 29.1.3-0ubuntu3~24.04.2 |
| Container teste criado | OK | nginx:alpine na porta 18080, HTTP 200 OK |
| Backup iptables-save v4 | OK | iptables-restore-safe-c2.v4 |
| Backup ip6tables-save v6 | OK | ip6tables-restore-safe-c2.v6 |
| Cron safety | OK → REMOVIDO | criado e removido após teste |
| tmux | OK | instalado em C1 |
| Segunda conexão SSH | OK | ssh-after-c2.txt confirma |

## Mudança de código

| Commit | Descrição |
|---|---|
| 19f35f1 | `fix: preserve Docker forwarding when applying firewall` |

### Resumo da mudança

**lib/firewall.sh:**
- Adicionado `docker_firewall_present()` — detecta Docker ativo ou chains Docker
- Verifica: `docker` command + `systemctl is-active docker`, ou chains `DOCKER`/`DOCKER-USER`/`DOCKER-FORWARD`

**lib/hardening.sh:**
- `mod_firewall()`: `iptables -P FORWARD DROP` condicional — só aplica se Docker NÃO está presente
- Se Docker ativo: emite `warn "${HARDEN_FIREWALL_DOCKER_FORWARD_WARN}"` em vez de DROP
- Mesma lógica para `ip6tables -P FORWARD DROP`
- i18n: `HARDEN_FIREWALL_DOCKER_FORWARD_WARN` adicionado em pt_BR e en_US

## Execução na VPS

| Teste | Resultado | Log |
|---|---|---|
| Baseline Oracle restore | PASS | iptables ACCEPT policy, FORWARD REJECT |
| Docker install | PASS | v29.1.3, DOCKER chains criados |
| nginx container | PASS | porta 18080, HTTP 200 |
| mod_firewall() com Docker | PASS | warn exibido, FORWARD DROP pulado |
| netfilter-persistent save | PASS | estado salvo sem quebrar Docker |
| SSH após mod_firewall | PASS | conexão SSH funcional |
| curl localhost:18080 após | PASS | HTTP/1.1 200 OK |

## Docker / FORWARD

| Item | Antes | Depois | Status |
|---|---|---|---|
| Docker ativo | sim | sim | OK |
| Container nginx | running | running | OK |
| curl localhost:18080 | HTTP 200 | HTTP 200 | OK |
| FORWARD policy | DROP (Docker) | DROP (Docker, untouched) | OK — não sobrescrito |
| DOCKER chain | existe | existe | OK |
| DOCKER-USER chain | existe | existe | OK |
| DOCKER-FORWARD chain | existe | existe | OK |

## Oracle Cloud

| Item | Antes | Depois | Status |
|---|---|---|---|
| InstanceServices chain | 15 rules | 15 rules | OK — preservada |
| OUTPUT 169.254 | InstanceServices jump | InstanceServices jump | OK — preservado |
| SSH | acessível | acessível | OK |

### Detalhe: FORWARD policy

Docker por padrão já seta `FORWARD DROP` policy e gerencia tráfego via chains `DOCKER-USER` → `DOCKER-FORWARD` → `REJECT`. A correção C2 NÃO tentou forçar `FORWARD DROP`, preservando assim o comportamento Docker.

Se Docker não estivesse instalado, `iptables -P FORWARD DROP` seria aplicado normalmente (funcionamento sem Docker).

## Resultado C2

- Status: **OK**
- Evidência: Docker container funcional após `mod_firewall()`, chains Docker preservadas, InstanceServices intacta, SSH ativo
- Decisão: C2/F03 corrigido e validado em código + VPS real com Docker

## Riscos remanescentes

- C3/F33: mod_firewall() ignora FW_TYPE=ufw (não testado; UFW não instalado)
- C4/F07: dns-abuse filter=empty (não alterado)
- C5/F34: IPv6 sem porta 51821/tcp e 3000/tcp (não testado)
- Docker removido com chains residuais: coberto por `docker_firewall_present()`, pois a função verifica chains `DOCKER`, `DOCKER-USER` e `DOCKER-FORWARD`. O risco remanescente seria apenas um ambiente sem Docker ativo e sem chains Docker, onde `FORWARD DROP` é esperado.

## Próximo passo recomendado

C2 está OK. Pode seguir para **C3/F33** (respeitar FW_TYPE em mod_firewall). C3 exige:
1. Verificar se mod_firewall() deve usar `ufw allow` quando FW_TYPE=ufw
2. Teste com UFW instalado (requer VPS teste nova ou snapshot antes de instalar UFW)
3. Atenção a conflito UFW + iptables + Oracle InstanceServices
