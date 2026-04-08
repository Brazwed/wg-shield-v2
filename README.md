# 🛡️ WG-Shield v2.0

> Repositório de desenvolvimento. Versão em produção: [WG-Shield](https://github.com/Brazwed/WG-Shield)

---

## Status: 🚧 Em Desenvolvimento

Este repositório contém a versão 2.0 do WG-Shield em construção.

### Funcionalidades being implemented:

- ✅ Modular architecture (lib/*.sh)
- ✅ i18n support (pt_BR, en_US)
- ✅ Menu interativo completo
- ✅ Docker + Docker Compose integration
- ✅ Hardening modules (9 módulos)
- ✅ Backup/Restore system
- ✅ Firewall (UFW + iptables)
- ✅ DNS Toggle (public/private)

---

## Uso

```bash
# Clone
git clone https://github.com/Brazwed/wG-Shield-v2.git /opt/wg-shield

# Executar
cd /opt/wg-shield
sudo ./wgshield.sh

# Comandos CLI
sudo ./wgshield.sh install docker
sudo ./wgshield.sh install wg-easy
sudo ./wgshield.sh status
sudo ./wgshield.sh lang pt
```

---

## By Brazwed