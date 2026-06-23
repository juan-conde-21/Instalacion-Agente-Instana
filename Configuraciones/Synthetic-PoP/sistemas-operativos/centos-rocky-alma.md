# Preparación del servidor - CentOS / Rocky / Alma

[← Volver a sistemas operativos](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/sistemas-operativos/centos-rocky-alma.md`  
**Siguiente paso:** [online](../online/README.md) o [air-gapped](../airgap/README.md)

## Objetivo

Preparar servidores basados en la familia RHEL, como **CentOS Stream**, **Rocky Linux** o **AlmaLinux**.

## Consideración

Aunque estos sistemas son similares a RHEL, no se debe asumir equivalencia total sin validar paquetes, kernel, firewall, SELinux y políticas del cliente.

## Identificar sistema

```bash
cat /etc/os-release
uname -r
```

## Paquetes base

```bash
sudo dnf install -y curl wget tar gzip unzip bash-completion iproute iptables socat conntrack || \
sudo yum install -y curl wget tar gzip unzip bash-completion iproute iptables socat conntrack
```

## SELinux y firewall

```bash
getenforce || true
sestatus || true
sudo systemctl status firewalld --no-pager || true
sudo firewall-cmd --list-all || true
```

## NetworkManager

```bash
systemctl status NetworkManager --no-pager || true
systemctl status nm-cloud-setup.service --no-pager || true
systemctl status nm-cloud-setup.timer --no-pager || true
```

## Forwarding

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/99-k3s.conf
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
sysctl net.ipv4.ip_forward
```

## Siguiente paso

- Si el servidor tiene Internet: [Instalación online](../online/README.md)
- Si el servidor no tiene Internet: [Instalación air-gapped](../airgap/README.md)
