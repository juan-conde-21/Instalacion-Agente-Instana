# IBM Instana Synthetic Private PoP sobre k3s y Helm

> **Ubicación sugerida en el repositorio:** `Configuraciones/Synthetic-PoP/README.md`  
> **Alcance:** despliegue de **IBM Instana Synthetic Private PoP** sobre **k3s** y **Helm**, en modalidad **online** o **air-gapped**.

## Antes de empezar

Este manual está diseñado para que el lector no tenga que buscar archivos manualmente. Cada sección indica:

- dónde se encuentra dentro del repositorio;
- qué documento debe revisar antes;
- qué documento debe ejecutar después;
- qué comandos permiten validar si puede continuar.

> Este procedimiento **no incluye la instalación del Instana Host Agent**. El alcance corresponde únicamente al despliegue del **Synthetic Private PoP**.

## Cómo elegir la ruta correcta

| Pregunta | Ruta recomendada |
|---|---|
| ¿El servidor destino tiene salida a Internet? | Revisar [Instalación online](online/README.md). |
| ¿El servidor destino no tiene salida a Internet? | Revisar [Instalación air-gapped](airgap/README.md). |
| ¿Aún no sé qué sistema operativo usará el cliente? | Revisar [Preparación por sistema operativo](sistemas-operativos/README.md). |
| ¿Necesito definir versiones de k3s, Helm o Synthetic PoP? | Revisar [Política de versionamiento](validaciones/versionamiento.md). |
| ¿La instalación falló o un pod no levanta? | Revisar [Troubleshooting](troubleshooting/README.md). |

## Flujo general del procedimiento

```text
1. Revisar consideraciones generales.
2. Definir modalidad: online o air-gapped.
3. Preparar el sistema operativo del servidor destino.
4. Definir versiones a utilizar.
5. Instalar k3s, kubectl y Helm.
6. Instalar Synthetic PoP mediante Helm.
7. Validar funcionamiento.
```

## Documentos principales

| Orden | Documento | Uso |
|---:|---|---|
| 0 | [Consideraciones generales](00-consideraciones-generales.md) | Entender alcance, supuestos y criterios de instalación. |
| 1 | [Preparación por sistema operativo](sistemas-operativos/README.md) | Elegir la guía de RHEL, Ubuntu, CentOS, Rocky o Alma. |
| 2A | [Ruta online](online/README.md) | Instalar cuando el servidor tiene acceso a Internet. |
| 2B | [Ruta air-gapped](airgap/README.md) | Instalar cuando el servidor no tiene acceso a Internet. |
| 3 | [Versionamiento](validaciones/versionamiento.md) | Definir versiones de k3s, Helm y Synthetic PoP. |
| 4 | [Checklist post instalación](validaciones/checklist-post-instalacion.md) | Validar que el PoP quedó operativo. |
| 5 | [Troubleshooting](troubleshooting/README.md) | Revisar errores comunes y acciones correctivas. |

## Ruta rápida: instalación online

Seguir esta ruta cuando el servidor destino puede descargar dependencias desde Internet.

1. [Consideraciones generales](00-consideraciones-generales.md)
2. [Seleccionar sistema operativo](sistemas-operativos/README.md)
3. [Versionamiento](validaciones/versionamiento.md)
4. [Instalar k3s y Helm online](online/01-instalacion-k3s-helm-online.md)
5. [Instalar Synthetic PoP con Helm online](online/02-instalacion-synthetic-pop-helm-online.md)
6. [Checklist post instalación](validaciones/checklist-post-instalacion.md)

## Ruta rápida: instalación air-gapped

Seguir esta ruta cuando el servidor destino no puede descargar dependencias desde Internet.

1. [Consideraciones generales](00-consideraciones-generales.md)
2. [Versionamiento](validaciones/versionamiento.md)
3. [Descargar bundle en máquina online](airgap/01-descarga-bundle-maquina-online.md)
4. [Seleccionar sistema operativo del servidor destino](sistemas-operativos/README.md)
5. [Instalar k3s air-gapped](airgap/02-instalacion-k3s-airgap.md)
6. [Cargar imágenes Synthetic PoP](airgap/03-carga-imagenes-synthetic-pop.md)
7. [Instalar Synthetic PoP con Helm air-gapped](airgap/04-instalacion-synthetic-pop-helm-airgap.md)
8. [Checklist post instalación](validaciones/checklist-post-instalacion.md)

## Estructura de carpetas

```text
Synthetic-PoP/
├── README.md
├── 00-consideraciones-generales.md
├── sistemas-operativos/
├── online/
├── airgap/
├── validaciones/
├── troubleshooting/
├── templates/
└── MIGRACION_GUIAS_ACTUALES.md
```

## Regla de versionamiento

Para **laboratorio** se puede consultar la última versión disponible, pero para **cliente, producción o air-gapped** se debe trabajar con versiones específicas, registradas y validadas.

Ejemplo:

```bash
cp templates/versiones.env ./versiones.env
vi ./versiones.env
source ./versiones.env
```

Luego validar:

```bash
echo "K3S_VERSION=${K3S_VERSION}"
echo "HELM_VERSION=${HELM_VERSION}"
echo "POP_CHART_VERSION=${POP_CHART_VERSION}"
```

Revisar el detalle en [validaciones/versionamiento.md](validaciones/versionamiento.md).

## Referencias oficiales

- IBM Instana - Installing a private location: https://www.ibm.com/docs/en/instana-observability?topic=location-installing-private
- IBM Instana - Synthetic PoP capacity planning and scaling: https://www.ibm.com/docs/en/iofgs?topic=pop-capacity-planning-scaling
- K3s - Installation: https://docs.k3s.io/installation
- K3s - Requirements: https://docs.k3s.io/installation/requirements
- K3s - Air-Gap Install: https://docs.k3s.io/installation/airgap
- Helm - Installing Helm: https://helm.sh/docs/intro/install/
- Helm - Helm install command: https://helm.sh/docs/helm/helm_install/
- Artifact Hub - synthetic-pop chart: https://artifacthub.io/packages/helm/instana/synthetic-pop

## Guías anteriores

Si ya compartiste enlaces antiguos, no los elimines. Revisar [MIGRACION_GUIAS_ACTUALES.md](MIGRACION_GUIAS_ACTUALES.md) para mantener compatibilidad y evitar romper links del repositorio.
