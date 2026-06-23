# Preparación del servidor - Ubuntu 22.04 / 24.04 LTS

[← Volver a sistemas operativos](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/sistemas-operativos/ubuntu-22-24.md`  
**Siguiente paso:** [online](../online/README.md) o [air-gapped](../airgap/README.md)

## Objetivo

Preparar un servidor **Ubuntu LTS** para instalar k3s, Helm y Synthetic PoP.

## Identificar versión

```bash
cat /etc/os-release
lsb_release -a || true
uname -r
```

## Paquetes base

```bash
sudo apt-get update
sudo apt-get install -y curl wget tar gzip unzip ca-certificates apt-transport-https bash-completion iproute2 iptables socat conntrack
```

## UFW

Validar si el firewall está activo:

```bash
sudo ufw status verbose || true
```

Si UFW está activo, coordinar reglas requeridas por k3s y comunicación saliente hacia Instana.

## Módulos y forwarding

```bash
sudo modprobe br_netfilter || true
sudo modprobe overlay || true

cat <<'EOF' | sudo tee /etc/sysctl.d/99-k3s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system
```

## Validación previa

```bash
curl --version
iptables --version
sysctl net.ipv4.ip_forward
```

## Siguiente paso

- Si el servidor tiene Internet: [Instalación online](../online/README.md)
- Si el servidor no tiene Internet: [Instalación air-gapped](../airgap/README.md)
