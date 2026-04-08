# 🛡️ WG-Shield v2.0

> **WG-Shield v2.0** - VPN WireGuard Manager com containers Docker (AdGuard, Unbound)

---

## 🚀 Novidades na v2.0

- **Arquitetura modular** - arquivos separados em `lib/`
- **i18n completo** - Português e Inglês
- **Menu interativo** - navegação intuitiva
- **Módulo DNS Toggle** - alternar DNS público/privado
- **Sistema de Backup** - backup/restore manual
- **CLI completo** - `$ ./wgshield.sh install wg-easy`

---

## 📋 Installation

```bash
# Clone
git clone https://github.com/Brazwed/WG-Shield-v2.git /opt/wg-shield

# Executar
cd /opt/wg-shield
sudo ./wgshield.sh
```

---

## 💻 Comandos CLI

```bash
# Menu interativo
sudo ./wgshield.sh

# Instalação
sudo ./wgshield.sh install docker
sudo ./wgshield.sh install wg-easy
sudo ./wgshield.sh install adguard
sudo ./wgshield.sh install unbound
sudo ./wgshield.sh install all

# Gerenciamento
sudo ./wgshield.sh up wg-easy
sudo ./wgshield.sh down wg-easy
sudo ./wgshield.sh status
sudo ./wgshield.sh update wg-easy
sudo ./wgshield.sh logs wg-easy
sudo ./wgshield.sh remove wg-easy

# Idioma
sudo ./wgshield.sh lang pt
sudo ./wgshield.sh lang en
```

---

## 🌐 VPN + DNS Stack

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   wg-easy    │───▶│   AdGuard    │───▶│   Unbound    │
│  10.8.1.2    │     │  10.8.1.3    │     │  10.8.1.4    │
│  VPN + Panel │     │  DNS Filter  │     │  Recursive   │
└──────────────┘     └──────────────┘     └──────────────┘
```

---

## 🛡️ Hardening Modules (9 módulos)

1. Unattended-upgrades + auto-reboot
2. Fail2Ban (SSH + DNS abuse)
3. 2GB Swap
4. Memory tuning (swappiness)
5. Firewall IPv4 + IPv6
6. BBR + Network tuning
7. File limits (ulimit)
8. Log optimization (journald 200MB)
9. DNS Protection (port 53 with rate-limit)

---

## 🔧 Requisitos

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU | 1 vCPU | 1 vCPU |
| RAM | 512MB | 1GB+ |
| Disco | 10GB | 20GB |
| OS | Ubuntu 22.04/24.04 LTS | Ubuntu 24.04 LTS |

---

## By Brazwed