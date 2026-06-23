# Air-gapped - Instalación de Synthetic PoP mediante Helm local

[← Volver a ruta air-gapped](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/airgap/04-instalacion-synthetic-pop-helm-airgap.md`  
**Paso anterior:** [Carga de imágenes Synthetic PoP](03-carga-imagenes-synthetic-pop.md)  
**Siguiente paso:** [Checklist post instalación](../validaciones/checklist-post-instalacion.md)

## Objetivo

Instalar Synthetic Private PoP usando el chart local descargado en el bundle.

## Cargar variables

```bash
cd /opt/instana/synthetic-pop-airgap-bundle
source ./versiones.env

export POP_NAMESPACE="synthetic-pop"
export POP_RELEASE="synthetic-pop"
export INSTANA_DOWNLOAD_KEY="<download_key>"
export INSTANA_SYNTHETIC_ENDPOINT="<endpoint_synthetic>"
export INSTANA_SYNTHETIC_LOCATION="pop-airgap;PoP Airgap;Peru;Lima;0;0;PoP airgap k3s"
```

## Validar chart local

```bash
ls -lh "charts/synthetic-pop-${POP_CHART_VERSION}.tgz"
helm show chart "charts/synthetic-pop-${POP_CHART_VERSION}.tgz"
helm show values "charts/synthetic-pop-${POP_CHART_VERSION}.tgz" | head -80
```

## Crear namespace

```bash
kubectl create namespace "${POP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
```

## Instalar Synthetic PoP

```bash
helm install "${POP_RELEASE}" "charts/synthetic-pop-${POP_CHART_VERSION}.tgz" \
  --namespace "${POP_NAMESPACE}" \
  -f values/values-pop.yaml \
  --set downloadKey="${INSTANA_DOWNLOAD_KEY}" \
  --set controller.location="${INSTANA_SYNTHETIC_LOCATION}" \
  --set controller.instanaSyntheticEndpoint="${INSTANA_SYNTHETIC_ENDPOINT}"
```

## Validar instalación

```bash
helm list -n "${POP_NAMESPACE}"
helm status "${POP_RELEASE}" -n "${POP_NAMESPACE}"
kubectl get pods -n "${POP_NAMESPACE}" -o wide
kubectl get events -n "${POP_NAMESPACE}" --sort-by=.lastTimestamp
```

## Si los pods intentan descargar imágenes

Revisar:

```bash
kubectl describe pod -n "${POP_NAMESPACE}" <pod>
sudo k3s ctr images list | grep -i instana || true
```

Corregir `imagePullPolicy`, repositorio de imágenes o cargar las imágenes faltantes.

## Siguiente paso

Continuar con [Checklist post instalación](../validaciones/checklist-post-instalacion.md).
