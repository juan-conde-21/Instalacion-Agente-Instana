# Ruta de instalación air-gapped

[← Volver al índice principal](../README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/airgap/README.md`  
**Paso anterior:** [Consideraciones generales](../00-consideraciones-generales.md)  
**Siguiente paso:** [Descargar bundle en máquina online](01-descarga-bundle-maquina-online.md)

## Cuándo usar esta ruta

Usar esta ruta cuando el servidor destino **no tiene salida directa a Internet**.

En este escenario, primero se descarga todo lo necesario en una máquina online y luego se traslada el paquete al servidor destino.

## Flujo air-gapped

```text
1. En máquina online, definir versiones.
2. Descargar binario/script de k3s.
3. Descargar imágenes air-gapped de k3s.
4. Descargar Helm.
5. Descargar chart synthetic-pop.
6. Descargar o preparar imágenes del Synthetic PoP.
7. Empaquetar bundle.
8. Trasladar bundle al servidor destino.
9. Preparar sistema operativo destino.
10. Instalar k3s air-gapped.
11. Cargar imágenes.
12. Instalar Synthetic PoP con chart local.
13. Validar funcionamiento.
```

## Documentos de esta ruta

| Orden | Documento | Descripción |
|---:|---|---|
| 1 | [01-descarga-bundle-maquina-online.md](01-descarga-bundle-maquina-online.md) | Descarga todos los artefactos requeridos. |
| 2 | [Preparación por sistema operativo](../sistemas-operativos/README.md) | Prepara el servidor destino. |
| 3 | [02-instalacion-k3s-airgap.md](02-instalacion-k3s-airgap.md) | Instala k3s sin Internet. |
| 4 | [03-carga-imagenes-synthetic-pop.md](03-carga-imagenes-synthetic-pop.md) | Carga imágenes del PoP en containerd. |
| 5 | [04-instalacion-synthetic-pop-helm-airgap.md](04-instalacion-synthetic-pop-helm-airgap.md) | Instala el PoP usando chart local. |
| 6 | [Checklist post instalación](../validaciones/checklist-post-instalacion.md) | Valida operación general. |

## Regla principal

En air-gapped **no usar `latest`**. Todas las versiones deben quedar registradas en el bundle.

Revisar [versionamiento](../validaciones/versionamiento.md).

## Siguiente paso

Continuar con [01-descarga-bundle-maquina-online.md](01-descarga-bundle-maquina-online.md).
