# Preparación del servidor - RHEL 8.x

[← Volver a sistemas operativos](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/sistemas-operativos/rhel-8.md`  
**Siguiente paso:** [online](../online/README.md) o [air-gapped](../airgap/README.md)

## Objetivo

Preparar un servidor **Red Hat Enterprise Linux 8.x** para instalar k3s, Helm y Synthetic PoP.

## Nota para RHEL 8.1

Si el cliente usa **RHEL 8.1**, realizar una prevalidación adicional de NetworkManager y `nm-cloud-setup` antes de instalar k3s. En versiones antiguas de RHEL 8 puede presentarse interferencia con el networking de k3s.

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

Si el servidor usa repositorios internos del cliente, validar que estos paquetes estén disponibles.

## SELinux

Validar estado:

```bash
getenforce
sestatus
```

Para ambientes productivos, no desactivar SELinux sin autorización del cliente. Si SELinux está activo, considerar paquetes y políticas requeridas por k3s.

## firewalld

Validar estado:

```bash
sudo systemctl status firewalld --no-pager
```

Si el cliente mantiene firewall activo, coordinar apertura de reglas requeridas por k3s y por la comunicación hacia Instana.

Validaciones útiles:

```bash
sudo firewall-cmd --state || true
sudo firewall-cmd --list-all || true
```

## NetworkManager y RHEL 8.1

Validar:

```bash
systemctl status NetworkManager --no-pager
systemctl status nm-cloud-setup.service --no-pager || true
systemctl status nm-cloud-setup.timer --no-pager || true
```

Si `nm-cloud-setup` está presente y activo, coordinar con el administrador del sistema antes de deshabilitarlo:

```bash
sudo systemctl disable --now nm-cloud-setup.service nm-cloud-setup.timer
sudo reboot
```

## Forwarding

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/99-k3s.conf
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
sysctl net.ipv4.ip_forward
```

## Validación previa

Antes de continuar, validar:

```bash
curl --version
iptables --version
sestatus || true
sysctl net.ipv4.ip_forward
```

## Siguiente paso

- Si el servidor tiene Internet: [Instalación online](../online/README.md)
- Si el servidor no tiene Internet: [Instalación air-gapped](../airgap/README.md)
