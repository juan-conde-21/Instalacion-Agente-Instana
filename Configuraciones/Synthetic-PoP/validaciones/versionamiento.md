# Política de versionamiento

[← Volver al índice principal](../README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/validaciones/versionamiento.md`  
**Siguiente paso:** volver a [online](../online/README.md) o [air-gapped](../airgap/README.md)

## Objetivo

Definir cómo seleccionar, registrar y validar versiones de:

- k3s;
- Helm;
- chart `synthetic-pop`;
- imágenes Synthetic PoP.

## Regla principal

| Escenario | Criterio recomendado |
|---|---|
| Laboratorio interno | Puede consultarse la última versión estable disponible. |
| PoC con cliente | Usar versión específica y registrar evidencia. |
| Producción | Usar versión específica, aprobada y validada. |
| Air-gapped | Usar versión específica obligatoria. |

## Por qué no usar `latest` en cliente

No se recomienda usar `latest` en cliente porque:

- no permite repetir exactamente la instalación;
- dificulta sustentar qué versión se instaló;
- puede descargar una versión distinta en otra fecha;
- complica el troubleshooting con soporte;
- en air-gapped no existe descarga dinámica.

## Archivo recomendado de versiones

Usar el template [templates/versiones.env](../templates/versiones.env).

```bash
cp ../templates/versiones.env ./versiones.env
vi ./versiones.env
source ./versiones.env
```

Ejemplo:

```bash
echo "K3S_VERSION=${K3S_VERSION}"
echo "HELM_VERSION=${HELM_VERSION}"
echo "POP_CHART_VERSION=${POP_CHART_VERSION}"
```

## Cómo consultar versión de k3s

En máquina online:

```bash
curl -s https://api.github.com/repos/k3s-io/k3s/releases/latest | grep tag_name
```

Para cliente, copiar la versión seleccionada en `versiones.env`.

## Cómo validar versión de Helm

En máquina online:

```bash
helm version || true
```

También se puede validar desde la página oficial de releases de Helm antes de descargar el binario.

## Cómo consultar versión del chart Synthetic PoP

En máquina online:

```bash
helm repo add instana https://agents.instana.io/helm
helm repo update
helm search repo instana/synthetic-pop --versions | head -20
```

Para instalar una versión específica:

```bash
helm install synthetic-pop instana/synthetic-pop \
  --namespace synthetic-pop \
  --version "${POP_CHART_VERSION}"
```

Para descargar el chart en air-gapped:

```bash
helm pull instana/synthetic-pop --version "${POP_CHART_VERSION}"
```

## Matriz de versiones probadas

Completar esta tabla por cada cliente o laboratorio.

| Fecha | Cliente / entorno | SO | k3s | Helm | synthetic-pop chart | Resultado |
|---|---|---|---|---|---|---|
| YYYY-MM-DD | laboratorio | RHEL 9.x | `<version>` | `<version>` | `<version>` | Pendiente / OK / Observado |

## Evidencia de versiones instaladas

En el servidor destino:

```bash
k3s --version
kubectl version --client
helm version
helm list -n synthetic-pop
helm status synthetic-pop -n synthetic-pop
kubectl get pods -n synthetic-pop -o wide
```

Guardar la salida en una carpeta de evidencias del proyecto.

## Recomendación profesional

Para documentación de repositorio, usar variables y explicar cómo consultar versiones. Para documentación de ejecución con cliente, completar las variables con versiones específicas y conservar evidencia.
