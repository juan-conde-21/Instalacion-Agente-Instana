# Consideraciones generales

[← Volver al índice principal](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/00-consideraciones-generales.md`  
**Siguiente paso:** [Preparación por sistema operativo](sistemas-operativos/README.md)

## Objetivo

Establecer los criterios generales para desplegar **IBM Instana Synthetic Private PoP** sobre **k3s** y **Helm**.

## Alcance

Este procedimiento cubre:

- preparación del servidor Linux destino;
- instalación de k3s, kubectl y Helm;
- descarga de artefactos cuando el escenario es online;
- preparación de bundle cuando el escenario es air-gapped;
- instalación del Synthetic PoP mediante Helm;
- validaciones posteriores a la instalación.

Este procedimiento no cubre:

- instalación del Instana Host Agent;
- configuración avanzada de Synthetic Tests en Instana;
- hardening corporativo del sistema operativo;
- administración productiva de Kubernetes fuera del alcance de k3s;
- sizing definitivo sin información de carga real.

## Conceptos básicos

| Componente | Explicación simple |
|---|---|
| Synthetic Private PoP | Componente que ejecuta pruebas sintéticas desde una ubicación privada del cliente. |
| k3s | Distribución liviana de Kubernetes usada como runtime para desplegar los pods del PoP. |
| kubectl | Comando para consultar y administrar Kubernetes. En k3s normalmente queda disponible como parte de la instalación. |
| Helm | Herramienta usada para instalar aplicaciones en Kubernetes mediante charts. |
| Chart | Paquete de instalación de Helm. En este caso, el chart `synthetic-pop`. |
| Air-gapped | Ambiente sin salida directa a Internet. Todo debe descargarse previamente. |

## Decisión inicial

Antes de ejecutar comandos, responder:

| Pregunta | Decisión |
|---|---|
| ¿El servidor destino tiene Internet? | Usar [ruta online](online/README.md). |
| ¿El servidor destino no tiene Internet? | Usar [ruta air-gapped](airgap/README.md). |
| ¿El servidor es RHEL, Ubuntu, CentOS, Rocky o Alma? | Revisar [sistemas operativos](sistemas-operativos/README.md). |
| ¿La instalación será productiva o para cliente? | Fijar versiones en [versionamiento](validaciones/versionamiento.md). |

## Criterio de versionamiento

El manual debe permitir dos formas de trabajo:

| Escenario | Criterio |
|---|---|
| Laboratorio | Se puede consultar la última versión estable disponible. |
| Cliente / producción | Se debe fijar una versión específica y validada. |
| Air-gapped | Es obligatorio fijar versiones específicas para que el bundle sea reproducible. |

No se recomienda usar `latest` en producción, porque dificulta repetir el despliegue y explicar qué versión fue instalada.

## Evidencia mínima a conservar

Guardar salida de estos comandos durante la instalación:

```bash
cat /etc/os-release
uname -r
kubectl version --client
kubectl get nodes -o wide
helm version
helm list -A
kubectl get pods -n synthetic-pop -o wide
kubectl get events -n synthetic-pop --sort-by=.lastTimestamp
```

## Siguiente paso

Continuar con [Preparación por sistema operativo](sistemas-operativos/README.md).
