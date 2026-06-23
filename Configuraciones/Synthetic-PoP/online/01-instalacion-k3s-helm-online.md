# Online - Instalación de k3s, kubectl y Helm

[← Volver a ruta online](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/online/01-instalacion-k3s-helm-online.md`  
**Paso anterior:** [Preparación por sistema operativo](../sistemas-operativos/README.md)  
**Siguiente paso:** [Instalar Synthetic PoP online](02-instalacion-synthetic-pop-helm-online.md)

## Objetivo

Instalar k3s y Helm en un servidor con salida a Internet.

## Cargar variables

```bash
source ./versiones.env
```

Validar:

```bash
echo "K3S_VERSION=${K3S_VERSION}"
echo "HELM_VERSION=${HELM_VERSION}"
```

## Validar conectividad

```bash
curl -I https://get.k3s.io
curl -I https://get.helm.sh
```

## Instalar k3s

Para instalar una versión específica:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - server --disable traefik
```

> Si se trata de laboratorio y se ha autorizado usar la última versión estable, puede omitirse `INSTALL_K3S_VERSION`. Para cliente o producción, usar siempre versión específica.

## Configurar kubectl

```bash
sudo mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
```

Validar:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

## Instalar Helm

Descargar Helm según la versión definida:

```bash
cd /tmp
curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
tar -zxvf "helm-${HELM_VERSION}-linux-amd64.tar.gz"
sudo mv linux-amd64/helm /usr/local/bin/helm
helm version
```

## Validaciones finales

```bash
kubectl version --client
kubectl get nodes -o wide
helm version
```

## Siguiente paso

Continuar con [02-instalacion-synthetic-pop-helm-online.md](02-instalacion-synthetic-pop-helm-online.md).
