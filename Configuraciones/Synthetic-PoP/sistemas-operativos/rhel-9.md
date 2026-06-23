# Preparación del servidor - RHEL 9.x

[← Volver a sistemas operativos](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/sistemas-operativos/rhel-9.md`  
**Siguiente paso:** [online](../online/README.md) o [air-gapped](../airgap/README.md)

## Objetivo

Preparar un servidor **Red Hat Enterprise Linux 9.x** para instalar k3s, Helm y Synthetic PoP.

## Identificar versión

```bash
cat /etc/redhat-release
cat /etc/os-release
uname -r
```

## Paquetes base

```bash
sudo dnf install -y curl wget tar gzip unzip bash-completion iproute iptables socat conntrack
```

## SELinux

```bash
getenforce
sestatus
```

No desactivar SELinux sin autorización del cliente. En ambientes controlados, documentar la decisión de seguridad aplicada.

## firewalld

```bash
sudo systemctl status firewalld --no-pager
sudo firewall-cmd --state || true
sudo firewall-cmd --list-all || true
```

Si firewalld se mantiene activo, coordinar reglas requeridas para k3s y comunicación saliente hacia Instana.

## Forwarding

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/99-k3s.conf
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
sysctl net.ipv4.ip_forward
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
