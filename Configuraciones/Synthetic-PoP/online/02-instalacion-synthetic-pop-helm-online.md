# Online - Instalación de Synthetic PoP mediante Helm

[← Volver a ruta online](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/online/02-instalacion-synthetic-pop-helm-online.md`  
**Paso anterior:** [Instalar k3s y Helm online](01-instalacion-k3s-helm-online.md)  
**Siguiente paso:** [Checklist post instalación](../validaciones/checklist-post-instalacion.md)

## Objetivo

Instalar **Synthetic Private PoP** usando el repositorio Helm oficial de Instana.

## Variables requeridas

```bash
source ./versiones.env

export POP_NAMESPACE="synthetic-pop"
export POP_RELEASE="synthetic-pop"
export INSTANA_DOWNLOAD_KEY="<download_key>"
export INSTANA_SYNTHETIC_ENDPOINT="<endpoint_synthetic>"
export INSTANA_SYNTHETIC_LOCATION="pop-online;PoP Online;Peru;Lima;0;0;PoP online k3s"
```

> Reemplazar los valores sensibles con los entregados desde Instana.

## Agregar repositorio Helm

```bash
helm repo add instana https://agents.instana.io/helm
helm repo update
```

Consultar versiones disponibles:

```bash
helm search repo instana/synthetic-pop --versions | head -20
```

## Instalar con versión específica

```bash
kubectl create namespace "${POP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm install "${POP_RELEASE}" instana/synthetic-pop \
  --namespace "${POP_NAMESPACE}" \
  --version "${POP_CHART_VERSION}" \
  --set downloadKey="${INSTANA_DOWNLOAD_KEY}" \
  --set controller.location="${INSTANA_SYNTHETIC_LOCATION}" \
  --set controller.instanaSyntheticEndpoint="${INSTANA_SYNTHETIC_ENDPOINT}"
```

## Validar release Helm

```bash
helm list -n "${POP_NAMESPACE}"
helm status "${POP_RELEASE}" -n "${POP_NAMESPACE}"
```

## Validar pods

```bash
kubectl get pods -n "${POP_NAMESPACE}" -o wide
kubectl get deploy -n "${POP_NAMESPACE}"
kubectl get svc -n "${POP_NAMESPACE}"
```

## Revisar logs principales

```bash
kubectl logs -n "${POP_NAMESPACE}" deploy/${POP_RELEASE}-controller --tail=100 || true
kubectl get events -n "${POP_NAMESPACE}" --sort-by=.lastTimestamp
```

## Siguiente paso

Continuar con [Checklist post instalación](../validaciones/checklist-post-instalacion.md).
