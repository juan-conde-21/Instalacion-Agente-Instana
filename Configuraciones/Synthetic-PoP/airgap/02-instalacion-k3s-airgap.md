# Air-gapped - Instalación de k3s sin Internet

[← Volver a ruta air-gapped](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/airgap/02-instalacion-k3s-airgap.md`  
**Paso anterior:** [Preparación por sistema operativo](../sistemas-operativos/README.md)  
**Siguiente paso:** [Carga de imágenes Synthetic PoP](03-carga-imagenes-synthetic-pop.md)

## Objetivo

Instalar k3s en el servidor destino usando los archivos descargados previamente en la máquina online.

## Descomprimir bundle

```bash
sudo mkdir -p /opt/instana
sudo tar -xzvf synthetic-pop-airgap-bundle.tar.gz -C /opt/instana
cd /opt/instana/synthetic-pop-airgap-bundle
source ./versiones.env
```

## Instalar binario k3s

```bash
sudo cp binaries/k3s /usr/local/bin/k3s
sudo chmod +x /usr/local/bin/k3s
```

## Copiar imágenes air-gapped de k3s

```bash
sudo mkdir -p /var/lib/rancher/k3s/agent/images/
sudo cp images/k3s-airgap-images-amd64.tar.zst /var/lib/rancher/k3s/agent/images/
```

## Ejecutar instalación

```bash
sudo INSTALL_K3S_SKIP_DOWNLOAD=true \
  INSTALL_K3S_EXEC="server --disable traefik" \
  ./binaries/install.sh
```

## Configurar kubectl

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
```

## Validar k3s

```bash
sudo systemctl status k3s --no-pager
kubectl get nodes -o wide
kubectl get pods -A
```

## Instalar Helm local

```bash
sudo cp binaries/helm /usr/local/bin/helm
sudo chmod +x /usr/local/bin/helm
helm version
```

## Siguiente paso

Continuar con [03-carga-imagenes-synthetic-pop.md](03-carga-imagenes-synthetic-pop.md).
