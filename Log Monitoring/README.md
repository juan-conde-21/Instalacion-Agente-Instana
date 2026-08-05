# Log Monitoring con IBM Instana y OpenTelemetry

Esta carpeta reúne procedimientos para recolectar logs desde archivos, procesarlos con OpenTelemetry Collector y enviarlos al agente de IBM Instana mediante OTLP.

## Guías disponibles

| Guía | Cuándo utilizarla |
|---|---|
| [OpenTelemetry Filelog Receiver](Opentelemetry%20Filelog%20Receiver.md) | Caso general para leer uno o varios archivos de log y enviarlos a Instana. |
| [NGINX Stream con OpenTelemetry Filelog e Instana](NGINX_Stream_OpenTelemetry_Filelog_Instana.md) | Caso específico para logs de sesiones TCP/UDP de NGINX Stream, incluido el formato de log, permisos, configuración, validaciones y escenarios adicionales. |

## Ruta recomendada

Para un caso nuevo, revisar primero la guía general de Filelog Receiver. Cuando el origen sea NGINX Stream, utilizar el procedimiento específico, ya que incluye el formato de los registros de capa 4 y las validaciones necesarias.

## Consideraciones

- Confirmar que el agente Instana tenga habilitado el receptor OTLP.
- Validar que el usuario de OpenTelemetry Collector tenga permisos de lectura sobre los archivos.
- Probar la configuración del Collector antes de reiniciar el servicio.
- Evitar publicar dominios, direcciones IP, tokens o rutas sensibles de clientes.
- Validar la sintaxis contra la versión instalada de OpenTelemetry Collector Contrib.

## Regreso al índice principal

[Volver al README principal](../README.md)
