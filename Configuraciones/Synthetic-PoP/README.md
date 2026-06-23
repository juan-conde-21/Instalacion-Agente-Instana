# IBM Instana Synthetic Private PoP sobre k3s y Helm

> **Ubicación sugerida en el repositorio:** `Configuraciones/Synthetic-PoP/README.md`  
> **Alcance:** despliegue de **IBM Instana Synthetic Private PoP** sobre **k3s** y **Helm**, en modalidad **online** o **air-gapped**.

Este manual está diseñado para ordenar la instalación del **Synthetic Private PoP** en servidores Linux, separando claramente lo que cambia por sistema operativo y lo que corresponde al despliegue común mediante Helm.

> Este procedimiento **no incluye la instalación del Instana Host Agent**. El alcance corresponde únicamente al despliegue del **Synthetic Private PoP**.

---

## Cómo usar esta documentación

Esta documentación puede revisarse directamente desde GitHub o descargarse en una máquina de trabajo. La forma de uso depende de lo que se necesite hacer.

### Opción 1: Revisar desde GitHub

Si solo necesitas leer el procedimiento, puedes navegar desde este índice principal y abrir los documentos en orden:

1. [Mapa de navegación](./MAPA_NAVEGACION.md)
2. [Consideraciones generales](./00-consideraciones-generales.md)
3. [Preparación por sistema operativo](./sistemas-operativos/README.md)
4. [Ruta online](./online/README.md) o [Ruta air-gapped](./airgap/README.md)
5. [Política de versionamiento](./validaciones/versionamiento.md)
6. [Checklist post instalación](./validaciones/checklist-post-instalacion.md)
7. [Troubleshooting](./troubleshooting/README.md)

Esta opción es útil para revisión, entendimiento del flujo o validación previa con el cliente.

### Opción 2: Clonar el repositorio

Si vas a ejecutar comandos, copiar plantillas, preparar un bundle air-gapped o trabajar directamente con los archivos del repositorio, se recomienda clonar el repositorio en una máquina de trabajo:

```bash
git clone https://github.com/juan-conde-21/Instalacion-Agente-Instana.git
cd Instalacion-Agente-Instana/Configuraciones/Synthetic-PoP
```

Luego valida que estás en la carpeta correcta:

```bash
pwd
ls -la
```

Deberías visualizar archivos y carpetas como:

```text
README.md
MAPA_NAVEGACION.md
00-consideraciones-generales.md
sistemas-operativos/
online/
airgap/
validaciones/
troubleshooting/
templates/
```

### Opción 3: Descargar como ZIP

Si no cuentas con Git instalado, puedes descargar el repositorio desde GitHub usando la opción:

```text
Code > Download ZIP
```

Luego descomprime el archivo y navega a la siguiente ruta:

```text
Instalacion-Agente-Instana-main/Configuraciones/Synthetic-PoP/
```

### Recomendación práctica

- Para una instalación **online**, puedes clonar o descargar el repositorio directamente en el servidor destino, siempre que tenga salida a Internet.
- Para una instalación **air-gapped**, clona o descarga el repositorio en una máquina con acceso a Internet. Desde esa máquina se prepara el bundle con binarios, charts, values e imágenes, y luego se traslada al servidor destino sin salida a Internet.

---

## Antes de empezar

Cada sección del manual indica:

- dónde se encuentra dentro del repositorio;
- qué documento debe revisarse antes;
- qué documento debe ejecutarse después;
- qué comandos permiten validar si se puede continuar.

Si es la primera vez que revisas esta documentación, empieza por el [Mapa de navegación](./MAPA_NAVEGACION.md).

---

## Cómo elegir la ruta correcta

| Pregunta | Ruta recomendada |
|---|---|
| ¿El servidor destino tiene salida a Internet? | Revisar [Instalación online](./online/README.md). |
| ¿El servidor destino no tiene salida a Internet? | Revisar [Instalación air-gapped](./airgap/README.md). |
| ¿Aún no sé qué sistema operativo usará el cliente? | Revisar [Preparación por sistema operativo](./sistemas-operativos/README.md). |
| ¿Necesito definir versiones de k3s, Helm o Synthetic PoP? | Revisar [Política de versionamiento](./validaciones/versionamiento.md). |
| ¿La instalación falló o un pod no levanta? | Revisar [Troubleshooting](./troubleshooting/README.md). |

---

## Flujo general del procedimiento

```text
1. Revisar consideraciones generales.
2. Definir la modalidad de instalación: online o air-gapped.
3. Preparar el sistema operativo del servidor destino.
4. Definir versiones de k3s, Helm y Synthetic PoP.
5. Instalar k3s, kubectl y Helm.
6. Instalar Synthetic PoP mediante Helm.
7. Validar funcionamiento.
```

---

## Documentos principales

| Orden | Documento | Uso |
|---:|---|---|
| 0 | [Mapa de navegación](./MAPA_NAVEGACION.md) | Ver el flujo completo y entender qué documento seguir. |
| 1 | [Consideraciones generales](./00-consideraciones-generales.md) | Entender alcance, supuestos y criterios de instalación. |
| 2 | [Preparación por sistema operativo](./sistemas-operativos/README.md) | Elegir la guía de RHEL, Ubuntu, CentOS, Rocky o Alma. |
| 3A | [Ruta online](./online/README.md) | Instalar cuando el servidor tiene acceso a Internet. |
| 3B | [Ruta air-gapped](./airgap/README.md) | Instalar cuando el servidor no tiene acceso a Internet. |
| 4 | [Versionamiento](./validaciones/versionamiento.md) | Definir versiones de k3s, Helm y Synthetic PoP. |
| 5 | [Checklist post instalación](./validaciones/checklist-post-instalacion.md) | Validar que el PoP quedó operativo. |
| 6 | [Troubleshooting](./troubleshooting/README.md) | Revisar errores comunes y acciones correctivas. |
| 7 | [Migración de guías actuales](./MIGRACION_GUIAS_ACTUALES.md) | Mantener compatibilidad con enlaces anteriores del repositorio. |

---

## Ruta rápida: instalación online

Seguir esta ruta cuando el servidor destino puede descargar dependencias desde Internet.

1. [Consideraciones generales](./00-consideraciones-generales.md)
2. [Seleccionar sistema operativo](./sistemas-operativos/README.md)
3. [Versionamiento](./validaciones/versionamiento.md)
4. [Instalar k3s y Helm online](./online/01-instalacion-k3s-helm-online.md)
5. [Instalar Synthetic PoP con Helm online](./online/02-instalacion-synthetic-pop-helm-online.md)
6. [Checklist post instalación](./validaciones/checklist-post-instalacion.md)

---

## Ruta rápida: instalación air-gapped

Seguir esta ruta cuando el servidor destino no puede descargar dependencias desde Internet.

1. [Consideraciones generales](./00-consideraciones-generales.md)
2. [Versionamiento](./validaciones/versionamiento.md)
3. [Descargar bundle en máquina online](./airgap/01-descarga-bundle-maquina-online.md)
4. [Seleccionar sistema operativo del servidor destino](./sistemas-operativos/README.md)
5. [Instalar k3s air-gapped](./airgap/02-instalacion-k3s-airgap.md)
6. [Cargar imágenes Synthetic PoP](./airgap/03-carga-imagenes-synthetic-pop.md)
7. [Instalar Synthetic PoP con Helm air-gapped](./airgap/04-instalacion-synthetic-pop-helm-airgap.md)
8. [Checklist post instalación](./validaciones/checklist-post-instalacion.md)

---

## Estructura de carpetas

```text
Synthetic-PoP/
├── README.md
├── MAPA_NAVEGACION.md
├── 00-consideraciones-generales.md
├── sistemas-operativos/
├── online/
├── airgap/
├── validaciones/
├── troubleshooting/
├── templates/
└── MIGRACION_GUIAS_ACTUALES.md
```

---

## Regla de versionamiento

Para **laboratorio** se puede consultar la última versión disponible, previa validación.

Para **cliente, producción o air-gapped**, se debe trabajar con versiones específicas, registradas y validadas.

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

Revisar el detalle en [validaciones/versionamiento.md](./validaciones/versionamiento.md).

---

## Consideraciones importantes

- El sistema operativo impacta principalmente en la preparación del servidor, firewall, SELinux, paquetes base y configuración de red.
- Una vez que k3s, kubectl y Helm están operativos, la instalación del Synthetic PoP se realiza mediante Helm.
- En instalaciones air-gapped, el bundle debe ser reproducible. Por ello, se deben registrar las versiones usadas y conservar evidencias.
- No se recomienda usar `latest` en ambientes productivos o de cliente sin validación previa.
- Las guías anteriores del repositorio no deben eliminarse si ya fueron compartidas con clientes o equipos internos.

---

## Referencias oficiales

- IBM Instana - Installing a private location: https://www.ibm.com/docs/en/instana-observability?topic=location-installing-private
- IBM Instana - Synthetic PoP capacity planning and scaling: https://www.ibm.com/docs/en/iofgs?topic=pop-capacity-planning-scaling
- K3s - Installation: https://docs.k3s.io/installation
- K3s - Requirements: https://docs.k3s.io/installation/requirements
- K3s - Air-Gap Install: https://docs.k3s.io/installation/airgap
- Helm - Installing Helm: https://helm.sh/docs/intro/install/
- Helm - Helm install command: https://helm.sh/docs/helm/helm_install/
- Artifact Hub - synthetic-pop chart: https://artifacthub.io/packages/helm/instana/synthetic-pop

---

## Guías anteriores

Revisar [MIGRACION_GUIAS_ACTUALES.md](./MIGRACION_GUIAS_ACTUALES.md) para mantener compatibilidad y evitar romper links del repositorio.
