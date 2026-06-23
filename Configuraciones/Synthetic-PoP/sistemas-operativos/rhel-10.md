# Preparación del servidor - RHEL 10.x

[← Volver a sistemas operativos](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/sistemas-operativos/rhel-10.md`  
**Siguiente paso:** [online](../online/README.md) o [air-gapped](../airgap/README.md)

## Objetivo

Preparar un servidor **Red Hat Enterprise Linux 10.x** para instalar k3s, Helm y Synthetic PoP.

## Consideración principal

RHEL 10 puede requerir módulos adicionales del kernel para networking de contenedores. Validar con el equipo del sistema operativo la disponibilidad de paquetes como `kernel-modules-extra` según la imagen base utilizada.

## Identificar versión

```bash
cat /etc/redhat-release
cat /etc/os-release
uname -r
```

## Paquetes base

```bash
sudo dnf install -y curl wget tar gzip unzip bash-completion iproute iptables socat conntrack kernel-modules-extra
```

Si `kernel-modules-extra` no existe en el repositorio del cliente, escalar con el administrador del sistema operativo antes de continuar.

## Validar módulos

```bash
lsmod | egrep 'br_netfilter|overlay' || true
sudo modprobe br_netfilter || true
sudo modprobe overlay || true
```

## Forwarding

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/99-k3s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system
```

## Firewall y SELinux

```bash
getenforce || true
sudo systemctl status firewalld --no-pager || true
sudo firewall-cmd --list-all || true
```

## Siguiente paso

- Si el servidor tiene Internet: [Instalación online](../online/README.md)
- Si el servidor no tiene Internet: [Instalación air-gapped](../airgap/README.md)
