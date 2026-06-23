# Ruta de instalación online

[← Volver al índice principal](../README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/online/README.md`  
**Paso anterior:** [Preparación por sistema operativo](../sistemas-operativos/README.md)  
**Siguiente paso:** [Instalar k3s y Helm online](01-instalacion-k3s-helm-online.md)

## Cuándo usar esta ruta

Usar esta ruta cuando el servidor destino **sí tiene salida a Internet** y puede descargar:

- instalador de k3s;
- binario de Helm;
- chart `synthetic-pop`;
- imágenes requeridas por el Synthetic PoP;
- dependencias de sistema operativo desde repositorios permitidos.

## Flujo online

```text
1. Preparar sistema operativo.
2. Validar conectividad hacia endpoints requeridos.
3. Definir versiones a utilizar.
4. Instalar k3s.
5. Instalar Helm.
6. Agregar repositorio Helm de Instana.
7. Instalar Synthetic PoP mediante Helm.
8. Validar funcionamiento.
```

## Documentos de esta ruta

| Orden | Documento | Descripción |
|---:|---|---|
| 1 | [01-instalacion-k3s-helm-online.md](01-instalacion-k3s-helm-online.md) | Instala k3s, kubectl y Helm con Internet. |
| 2 | [02-instalacion-synthetic-pop-helm-online.md](02-instalacion-synthetic-pop-helm-online.md) | Instala Synthetic PoP con chart Helm remoto. |
| 3 | [Checklist post instalación](../validaciones/checklist-post-instalacion.md) | Valida pods, eventos, release Helm y operación general. |

## Validar conectividad antes de instalar

```bash
curl -I https://get.k3s.io
curl -I https://get.helm.sh
curl -I https://agents.instana.io/helm
```

Si alguno falla, no continuar hasta que el cliente habilite la salida requerida o se use la [ruta air-gapped](../airgap/README.md).

## Versiones

Antes de ejecutar, revisar [versionamiento](../validaciones/versionamiento.md).  
Luego usar:

```bash
cp ../templates/versiones.env ./versiones.env
vi ./versiones.env
source ./versiones.env
```

## Siguiente paso

Continuar con [01-instalacion-k3s-helm-online.md](01-instalacion-k3s-helm-online.md).
