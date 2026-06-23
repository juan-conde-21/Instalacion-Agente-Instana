# Air-gapped - Descarga de bundle en máquina online

[← Volver a ruta air-gapped](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/airgap/01-descarga-bundle-maquina-online.md`  
**Paso anterior:** [Ruta air-gapped](README.md)  
**Siguiente paso:** [Preparación por sistema operativo destino](../sistemas-operativos/README.md)

## Objetivo

Construir un paquete portable con todo lo necesario para instalar Synthetic PoP en un servidor sin Internet.

La máquina online puede ser Linux, Windows o macOS, siempre que permita descargar los artefactos y transferirlos al servidor destino. Para simplificar comandos, este procedimiento muestra ejemplo en Linux.

## Crear estructura del bundle

```bash
export AIRGAP_DIR="$HOME/synthetic-pop-airgap-bundle"
mkdir -p "$AIRGAP_DIR"/{binaries,charts,images,values,scripts,evidencias}
```

## Cargar versiones

```bash
cp ../templates/versiones.env "$AIRGAP_DIR/versiones.env"
vi "$AIRGAP_DIR/versiones.env"
source "$AIRGAP_DIR/versiones.env"
```

Validar:

```bash
echo "K3S_VERSION=${K3S_VERSION}"
echo "HELM_VERSION=${HELM_VERSION}"
echo "POP_CHART_VERSION=${POP_CHART_VERSION}"
```

## Descargar k3s

```bash
cd "$AIRGAP_DIR/binaries"

curl -LO https://get.k3s.io
mv get.k3s.io install.sh
chmod +x install.sh

curl -L -o k3s "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s"
chmod +x k3s
```

## Descargar imágenes air-gapped de k3s

```bash
cd "$AIRGAP_DIR/images"

curl -LO "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-airgap-images-amd64.tar.zst"
```

## Descargar Helm

```bash
cd "$AIRGAP_DIR/binaries"

curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
tar -zxvf "helm-${HELM_VERSION}-linux-amd64.tar.gz"
cp linux-amd64/helm ./helm
chmod +x ./helm
```

## Descargar chart Synthetic PoP

```bash
cd "$AIRGAP_DIR/charts"

helm repo add instana https://agents.instana.io/helm
helm repo update
helm pull instana/synthetic-pop --version "${POP_CHART_VERSION}"
```

## Guardar values base

```bash
helm show values "$AIRGAP_DIR/charts/synthetic-pop-${POP_CHART_VERSION}.tgz" > "$AIRGAP_DIR/values/values-default.yaml"
cp ../templates/values-pop.yaml "$AIRGAP_DIR/values/values-pop.yaml"
```

## Preparar imágenes Synthetic PoP

Dependiendo del procedimiento vigente de Instana, preparar las imágenes requeridas por el chart y guardarlas en:

```text
synthetic-pop-airgap-bundle/images/synthetic-pop-images.tar
```

Registrar evidencia de las imágenes incluidas:

```bash
tar -tf "$AIRGAP_DIR/images/synthetic-pop-images.tar" > "$AIRGAP_DIR/evidencias/listado-imagenes-synthetic-pop.txt" || true
```

## Generar manifiesto del bundle

```bash
cd "$AIRGAP_DIR"

find . -type f | sort > evidencias/manifest-files.txt
sha256sum $(find . -type f | sort) > evidencias/sha256sum.txt
```

## Empaquetar bundle

```bash
cd "$HOME"
tar -czvf synthetic-pop-airgap-bundle.tar.gz synthetic-pop-airgap-bundle
```

## Siguiente paso

Trasladar `synthetic-pop-airgap-bundle.tar.gz` al servidor destino y continuar con [Preparación por sistema operativo](../sistemas-operativos/README.md).
