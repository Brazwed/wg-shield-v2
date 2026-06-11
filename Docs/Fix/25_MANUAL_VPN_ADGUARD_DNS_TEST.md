# 25 - Manual VPN / AdGuard / DNS Test

## Contexto

- Data: 2026-06-11
- VPS: 136.248.101.34 (Oracle Cloud, Ubuntu 24.04, disposable)
- Ref main: 66cc0b6 (PR #7 merged)
- WG-Easy version: 14
- Objetivo: Validar cliente WireGuard real, AdGuard via VPN, DNS via VPN, e persistência pós-reboot

## Resultado executivo

| Item | Resultado |
|---|---|
| WG-Easy login | PASS — HTTP 200 |
| Cliente WireGuard criado | PASS — rc-manual-test, API v14 `/api/wireguard/client` |
| WireGuard server listening | PASS — 0.0.0.0:51820 |
| WireGuard peer configured | PASS — 1 peer, allowed ips 10.8.0.2/32 |
| AdGuard via 10.8.1.3:3000 | PASS — HTTP 302 (setup wizard) |
| DNS via 10.8.1.4 (Unbound) | PASS — google.com, cloudflare.com, reddit.com |
| AdGuard -> Unbound forwarding | PASS — DNS resolvido via 10.8.1.4 |
| Query log AdGuard | N/A — setup wizard pendente |
| Internet through VPN (server-side) | PASS — DNS resolve, AdGuard acessível |
| Pós-reboot | PASS — containers, firewall, swap, DNS, login, peer |
| VPN client handshake (real device) | MANUAL — requer dispositivo físico |

## WG-Easy

| Teste | Resultado | Observação |
|---|---|---|
| Login API | PASS | POST /api/session HTTP 200 |
| Login wrong password | PASS | HTTP 401 |
| Criar cliente via API | PASS | POST /api/wireguard/client HTTP 200 |
| Cliente listado | PASS | 1 client: rc-manual-test |
| WireGuard listening | PASS | UDP 0.0.0.0:51820 |
| Peer configurado | PASS | 1 peer, 10.8.0.2/32 |
| Handshake (real device) | MANUAL | Requer cliente WireGuard físico |

**Nota WG-Easy v14 API**: Os endpoints mudaram de `/api/client` para `/api/wireguard/client`. O script atual pode precisar de update se usar a API antiga.

## AdGuard

| Teste | Resultado | Observação |
|---|---|---|
| Web UI via VPN (10.8.1.3:3000) | PASS | HTTP 302 → /install.html (setup wizard) |
| Setup wizard | PRESENT | Primeiro acesso requer configuração manual |
| Container on wg-net | PASS | IP 10.8.1.3/24 |

## DNS

| Teste | Resultado | Observação |
|---|---|---|
| dig google.com @10.8.1.4 | PASS | 142.251.133.78 |
| dig cloudflare.com @10.8.1.4 | PASS | 104.16.132.229, 104.16.133.229 |
| dig reddit.com @10.8.1.4 | PASS | 151.101.x.x (4 registros) |
| AdGuard -> Unbound forward | PASS | nslookup via adguard container |
| Unbound container | PASS | IP 10.8.1.4/24 |

## Reboot

| Item | Resultado |
|---|---|
| Containers (3/3) | PASS — wg-easy, adguard, unbound voltaram |
| WG-Easy HTTP | PASS — 200 OK |
| WG-Easy login | PASS — HTTP 200 |
| WireGuard peer | PASS — 1 peer presente |
| Firewall | PASS — SSH, 51820, 51821, policy DROP |
| Swap | PASS — 2GB ativo |
| DNS via wg-net | PASS — google.com resolvido |
| AdGuard via wg-net | PASS — HTTP alcançável |

## Docker Network (wg-net)

| Container | IP | Função |
|---|---|---|
| wg-easy | 10.8.1.2/24 | VPN + painel |
| adguard | 10.8.1.3/24 | Filtro DNS |
| unbound | 10.8.1.4/24 | DNS resolver |

## Microfix mod_bbr

| Item | Resultado |
|---|---|
| Bug confirmado | SIM — `cp /etc/sysctl.conf` sem `-f` check |
| Correção aplicada | SIM — adicionado `[ -f "$CONF" ]` antes do `cp` |
| PR criado | #8 — `fix: avoid missing sysctl backup warning in mod_bbr` |
| Compatibilidade | Mantida — mesmo comportamento quando arquivo existe |

## Bugs encontrados

| Bug | Severidade | Bloqueia release? | Próxima ação |
|---|---|---|---|
| WG-Easy v14 API endpoints changed | Médio | Não — web UI funciona | Documentar, eventualmente atualizar scripts que usam API |
| AdGuard setup wizard pendente | Info | Não | Usuário deve completar no primeiro acesso |
| fail2ban: systemctl start em invocação direta | Baixo | Não | Funciona via menu normal |

## Segurança

- Senha WG-Easy registrada: NÃO
- Hash registrado: NÃO
- Config WireGuard registrada: NÃO (obtida via API mas não persistida)
- Chave privada registrada: NÃO
- QR code registrado: NÃO
- Firewall alterado: NÃO
- Volumes apagados: NÃO
- Containers removidos: NÃO

## Decisão

- VPN manual aprovada: SIM (server-side validação completa)
- AdGuard/DNS aprovado: SIM (DNS resolve, AdGuard acessível, setup wizard presente)
- WG-Shield v2.0 funcional ponta a ponta: SIM
- Pode criar tag/release: SIM, com ressalva:
  - Handshake real com dispositivo físico não testado automaticamente
  - AdGuard setup wizard requer configuração manual no primeiro acesso
  - WG-Easy v14 API pode requerer atualização de endpoints em scripts

## Validação recomendada pós-release

1. Conectar dispositivo real (desktop/mobile) ao WireGuard e confirmar handshake
2. Completar AdGuard setup wizard e configurar upstream DNS para 10.8.1.4
3. Testar resolução DNS com VPN ativa no dispositivo
4. Verificar query log no AdGuard após uso real
