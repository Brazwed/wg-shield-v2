# 16 - Firewall Detection Matrix

## Contexto

- Data: 2026-06-11
- Branch/commit: fix/execution-queue-round-1 @ 3c0cc4c
- Objetivo: Validar detecção e decisão de firewall do WG-Shield em cenários de VPS limpa e VPS existente

## Estado real da VPS kobold

| Item | Resultado |
|---|---|
| Provider | Oracle Cloud (Ubuntu 24.04.4 LTS) |
| UFW | Não instalado |
| iptables | Ativo, policy INPUT DROP (C1) |
| iptables-persistent | Instalado |
| Docker | Instalado (v4.04.2 cliente / v29.1.3 engine) |
| InstanceServices | 15 regras presentes |
| SSH | Porta 22, acessível |
| Containers | nginx:alpine na porta 18080 (teste C2) |
| `detect` output | `Firewall: iptables (10 rules)` |

## Bug encontrado e corrigido

| Bug | Severidade | Correção | Commit |
|---|---|---|---|
| `detect_firewall()` usa `grep -q "active"` que matcheia "inactive" | Alto (P1) — UFW inativo era detectado como ativo | Trocar para `grep -qw "active"` (word boundary) | 3c0cc4c |

### Detalhe do bug

`lib/detection.sh:8`:
- Antes: `ufw status 2>/dev/null | head -1 | grep -q "active"`
- "Status: inactive" contém substring "active" → false positive
- Depois: `grep -qw "active"` — `-w` exige word boundary, "inactive" não matcheia

Impacto: Em VPS com UFW instalado mas inativo, o projeto detectaria `FW_TYPE=ufw` e `FW_ACTIVE=true`. Se o usuário rodasse `mod_firewall`, o caminho UFW seria escolhido indevidamente, ativando UFW em sistema com iptables raw (potencial lockout + InstanceServices destruída).

## Mapeamento da lógica de firewall

### Onde FW_TYPE nasce

1. `wgshield.sh:35` — `FW_TYPE="none"` (default)
2. `detect_firewall()` (`lib/detection.sh:3-30`) — detecta baseado no estado real:
   - UFW ativo → `FW_TYPE="ufw"`, `FW_ACTIVE=true`
   - iptables com >2 rules → `FW_TYPE="iptables"`, `FW_ACTIVE=true`
   - Nenhum → mantém `"none"`, `FW_ACTIVE=false`

### Quem chama detect_firewall

- `detect_vps_state()` (chamado por `install_comp()`, `install_new_vps()`, menu)
- Menu "Detect" direto

### Fluxo de decisão

```
wgshield.sh inicializa FW_TYPE="none"
     ↓
detect_firewall() ajusta FW_TYPE
     ↓
ask_firewall_choice() — interativo, pode alterar FW_TYPE
     ↓
mod_firewall() — executa baseado em FW_TYPE (C3 fix)
     ↓
open_port() — respeita FW_TYPE
```

## Matriz de cenários

| Cenário | Estado simulado | FW_TYPE esperado | FW_ACTIVE esperado | Ação esperada | Resultado observado | Status |
|---|---|---|---|---|---|---|
| S1 | VPS limpa sem ufw/firewalld, iptables Oracle padrão (>2 rules) | iptables | true | preservar iptables | D6: FW_TYPE=iptables, FW_ACTIVE=true | PASS |
| S2 | UFW instalado e ativo | ufw | true | usar UFW, não iptables raw | D1: FW_TYPE=ufw, FW_ACTIVE=true | PASS |
| S3 | UFW instalado mas inativo, iptables >=3 rules | iptables | true | usar iptables, não ativar UFW | D4: FW_TYPE=iptables, FW_ACTIVE=true | PASS |
| S4 | iptables-persistent ativo (>2 rules, sem UFW) | iptables | true | usar iptables helper | D6: FW_TYPE=iptables | PASS |
| S5 | Docker ativo + iptables | iptables | true | preservar Docker FORWARD | VPS kobold: detect=iptables(10) | PASS |
| S6 | Docker ativo + UFW ativo | ufw | true | não misturar iptables raw | Não testável sem UFW real | N/A |
| S7 | nftables/firewalld presente | none | false | FW_TYPE none, ask_firewall_choice oferece escolha | Não detectado (não suportado) | RISCO |
| S8 | Oracle InstanceServices presente | iptables | true | nunca flush, inserir antes REJECT | VPS kobold: InstanceServices intacta | PASS |

### Nota S7 (nftables/firewalld)

O projeto não detecta `nft` ou `firewalld`. Se o sistema usa `firewalld` (CentOS/RHEL/SUSE), `FW_TYPE` será:
- "iptables" se `iptables -L INPUT` mostra >2 regras (firewalld usa nft backend com compat layer)
- "none" se firewalld está ativo mas iptables backend retorna poucas regras

Cenário S7 é **D-tier** — requer detecção de firewalld/nftables, que está fora do escopo da Etapa 6.

## Testes mock — mod_firewall (18/18 PASS)

| Teste | Resultado | Detalhe |
|---|---|---|
| M1a: FW_TYPE=iptables → iptables -P INPUT DROP | PASS | Presente |
| M1b: FW_TYPE=iptables → netfilter-persistent | PASS | Presente |
| M1c: FW_TYPE=iptables → no ufw | PASS | Ausente |
| M1d: FW_TYPE=iptables → no iptables -F | PASS | Ausente |
| M2a: FW_TYPE=ufw → ufw allow | PASS | Presente |
| M2b: FW_TYPE=ufw → ufw default | PASS | Presente |
| M2c: FW_TYPE=ufw → ufw enable | PASS | Presente |
| M2d: FW_TYPE=ufw → no iptables -P INPUT DROP | PASS | Ausente |
| M2e: FW_TYPE=ufw → no ip6tables -P INPUT DROP | PASS | Ausente |
| M2f: FW_TYPE=ufw → no iptables -F | PASS | Ausente |
| M3a: FW_TYPE=unknown → fallback iptables | PASS | iptables -P INPUT DROP presente |
| M3b: FW_TYPE=unknown → no ufw | PASS | Ausente |
| M4a: open_port FW_TYPE=ufw | PASS | `ufw allow 12345/tcp` |
| M4b: open_port FW_TYPE=ufw → no iptables | PASS | Ausente |
| M5a: open_port FW_TYPE=iptables | PASS | `iptables -C INPUT` |
| M5b: open_port FW_TYPE=iptables → no ufw | PASS | Ausente |
| M6: open_port FW_TYPE=none | PASS | Nenhum comando (correto) |
| M7: open_port 51820/udp protocol spec | PASS | 51820 presente |

## Testes mock — detect_firewall (12/12 PASS)

| Teste | Resultado | Detalhe |
|---|---|---|
| D1: UFW ativo | PASS | FW_TYPE=ufw, FW_ACTIVE=true |
| D2: iptables >2 rules, UFW inativo | PASS | FW_TYPE=iptables, FW_ACTIVE=true |
| D3: nenhum firewall | PASS | FW_TYPE=none, FW_ACTIVE=false |
| D4: UFW inativo + iptables >=3 rules | PASS | FW_TYPE=iptables, FW_ACTIVE=true |
| D5: no ufw, no iptables | PASS | FW_TYPE=none, FW_ACTIVE=false |
| D6: Oracle iptables (muitas regras) | PASS | FW_TYPE=iptables, FW_ACTIVE=true |

## Testes VPS não-destrutivos

| Teste | Resultado |
|---|---|
| `detect` output | `Firewall: iptables (10 rules)` — correto |
| syntax check (bash -n) | PASS |
| iptables-save coletado | OK — InstanceServices intacta (15 regras) |
| Docker ps | OK — nginx:alpine rodando |
| UFW status | NÃO INSTALADO — detectado corretamente |
| iptables real alterado | NÃO |
| InstanceServices | Intacta |

## Respostas às 12 perguntas

| # | Pergunta | Resposta | Status |
|---|---|---|---|
| 1 | Onde FW_TYPE nasce? | `wgshield.sh:35` como `"none"`, ajustado por `detect_firewall()` | OK |
| 2 | Onde FW_ACTIVE nasce? | `wgshield.sh:36` como `false`, ajustado por `detect_firewall()` | OK |
| 3 | Quem detecta firewall existente? | `detect_firewall()` em `lib/detection.sh:3-30` | OK |
| 4 | detect altera estado global? | Sim — seta `FW_TYPE` e `FW_ACTIVE` como side effect | OK (by design) |
| 5 | ask_firewall_choice respeita firewall existente? | Sim — se `FW_ACTIVE=true`, oferece troca; se false, oferece instalar | OK |
| 6 | mod_firewall respeita FW_TYPE? | Sim — C3 fix com `case FW_TYPE` | OK |
| 7 | open_port respeita FW_TYPE? | Sim — `if FW_TYPE=ufw` → `ufw allow`, `elif FW_TYPE=iptables` → `ensure_iptables_input_rule` | OK |
| 8 | install_comp depende de FW_TYPE? | Sim — chama `ask_firewall_choice()` que pode alterar FW_TYPE, depois `open_port()` | OK |
| 9 | VPS com UFW ativo evita iptables raw? | Sim — `FW_TYPE=ufw` → `mod_firewall_ufw()` (sem iptables -P) | OK (mock) |
| 10 | VPS com iptables-persistent evita UFW? | Sim — `FW_TYPE=iptables` → `mod_firewall_iptables()` (sem ufw) | OK (mock) |
| 11 | VPS sem firewall escolhe algo previsível? | Sim — `FW_ACTIVE=false` → `ask_firewall_choice()` pergunta ao usuário | OK |
| 12 | Oracle InstanceServices reconhecido? | Não explicitamente — detectado genericamente como `iptables`. Sem warning específico | RISCO |

## Riscos remanescentes

| Risco | Severidade | Detalhe |
|---|---|---|
| UFW ativo em Oracle | Alto | `ufw enable` sobrescreve iptables incluindo InstanceServices. Exige snapshot + console/VNC. |
| firewalld/nftables não detectado | Baixo | FW_TYPE pode ser "iptables" (compat layer) ou "none" — sem suporte explícito |
| ask_firewall_choice permite troca para UFW sem warning Oracle | Médio | Usuário pode ativar UFW em Oracle sem saber que InstanceServices será destruída |
| open_port FW_TYPE=none não faz nada | Baixo | Se FW_TYPE não foi detectado (ex: script rodou sem detect), portas não são abertas silenciosamente |

## Decisão

- C3 está suficiente para seguir C4? **Sim.** C3 + bug fix grep validados.
- Existe pendência de detecção antes de C4? **Não.** Detecção validada para UFW/iptables/nenhum.
- Existe pendência de UFW real? **Sim.** UFW real em Oracle Cloud requer snapshot + console/VNC.
- Existe risco com Oracle InstanceServices? **Sim.** `ufw enable` pode destruir InstanceServices. O projeto não previne isso explicitamente — depende do usuário não ativar UFW em Oracle.

## Próximo passo recomendado

Pronto para **C4/F07** (fail2ban dns-abuse filter + SC2086). Detecção de firewall validada. Bug `grep -q "active"` corrigido. Risco Oracle/UFW documentado.
