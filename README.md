# IBM Instana - Guías de Instalación, Configuración e Integración

Este repositorio contiene procedimientos técnicos, guías de configuración e integraciones relacionadas con IBM Instana, orientadas a facilitar la implementación, validación y operación de la plataforma en distintos entornos empresariales.

El objetivo principal es centralizar documentación práctica que pueda ser reutilizada en actividades de despliegue, integración, pruebas de concepto, habilitación técnica y soporte operativo.

> Este repositorio no reemplaza la documentación oficial de IBM Instana. Su finalidad es complementar dicha documentación con procedimientos prácticos, ejemplos de configuración y guías elaboradas en base a escenarios reales de implementación.

---

## Objetivo

Documentar de forma clara y ordenada los procedimientos necesarios para instalar, configurar e integrar IBM Instana en diferentes plataformas, sensores, servicios cloud, tecnologías empresariales y escenarios de observabilidad.

El contenido busca servir como referencia técnica para:

- Instalación de agentes Instana.
- Configuración avanzada del agente.
- Integración con sensores y plataformas.
- Instrumentación de aplicaciones.
- Integración con servicios cloud.
- Uso de OpenTelemetry.
- Configuración de monitoreo sintético.
- Automatización de alertas e integraciones externas.
- Validación y troubleshooting operativo.

---

## Alcance del repositorio

El repositorio incluye documentación para los siguientes frentes:

| Categoría | Descripción |
|---|---|
| Plataformas | Instalación del agente Instana en Linux, Windows, UNIX y OpenShift. |
| Configuraciones | Procedimientos de configuración avanzada del agente, proxy, Vault, Synthetic PoP y otros escenarios operativos. |
| Sensores | Integraciones con AWS, GCP, VMware, IBM iSeries, DataPower, SAP ABAP, Podman, Zabbix, StatsD, OpenTelemetry y otros componentes. |
| OpenTelemetry | Guías para instrumentación, trazabilidad, logs y escenarios específicos de observabilidad. |
| Log Monitoring | Configuración de recolección de logs mediante OpenTelemetry Filelog Receiver. |
| GitLab / GitOps | Procedimientos asociados a gestión basada en Git y automatización de configuración. |
| Laboratorios y ejemplos | Código de ejemplo, pruebas de instrumentación y componentes de referencia para validaciones técnicas. |

---

## Índice general

### 1. Instalación del agente Instana por plataforma

| Guía | Descripción |
|---|---|
| [Instalación en Linux](Plataformas/Linux.md) | Procedimiento para instalar y validar el agente Instana en servidores Linux. |
| [Instalación en Windows](Plataformas/Windows.md) | Guía de instalación del agente Instana en sistemas Windows. |
| [Instalación en UNIX](Plataformas/UNIX.md) | Procedimiento orientado a plataformas UNIX. |
| [Instalación en OpenShift](Plataformas/Openshift.md) | Guía para desplegar Instana en entornos OpenShift. |
| [Instana Kubernetes / OpenShift Legacy](Plataformas/Instana-kubernetes-Openshift-Legacy.md) | Procedimiento para escenarios OpenShift o Kubernetes legacy donde se requiere una configuración específica. |

---

### 2. Integraciones AWS y monitoreo serverless

| Guía | Descripción |
|---|---|
| [Sensor AWS](Sensores/AWS.md) | Guía de integración de IBM Instana con servicios AWS mediante el sensor correspondiente. |
| [AWS Lambda - Node.js](Plataformas/AWS/Lambda/nodejs.md) | Procedimiento para instrumentar funciones AWS Lambda desarrolladas en Node.js. |
| [AWS Lambda - Python](Plataformas/AWS/Lambda/python.md) | Procedimiento para instrumentar funciones AWS Lambda desarrolladas en Python. |
| [Ejemplo NodeJS para Lambda](Plataformas/AWS/Lambda/NodeJS) | Carpeta con ejemplo de implementación para pruebas con AWS Lambda y Node.js. |

---

### 3. Configuración avanzada del agente Instana

| Guía | Descripción |
|---|---|
| [Configuración de proxy en agente Instana](Configuraciones/Configuracion%20de%20Proxy%20en%20Agente%20Instana.md) | Procedimiento para configurar el agente Instana cuando requiere salida mediante proxy. |
| [Configuración de Squid Proxy](Configuraciones/Configurar%20Squid%20Proxy.md) | Guía para implementar Squid como proxy de salida para escenarios controlados. |
| [Archivo de configuración Squid](Configuraciones/squid.conf) | Archivo de referencia para la configuración de Squid Proxy. |
| [Convertir agente estático a dinámico](Configuraciones/Convertir%20Agente%20Instana%20Estatico%20a%20Dinamico.md) | Procedimiento para modificar el comportamiento de un agente Instana estático hacia un esquema dinámico. |
| [Implementación con Vault](Configuraciones/Implementacion%20Vault.md) | Guía para escenarios donde se requiere integración o manejo de secretos mediante Vault. |
| [OpenTelemetry Log Receiver](Configuraciones/Opentelemetry%20Log%20Receiver.md) | Configuración relacionada con recepción de logs utilizando OpenTelemetry. |

---

### 4. Synthetic Monitoring - Private PoP

| Guía | Descripción |
|---|---|
| [Instana Synthetic PoP en k3s RHEL9 - Online](Configuraciones/instana-synthetic-pop-k3s-rhel9-online.md) | Procedimiento para desplegar un Private PoP de Instana Synthetics en k3s sobre RHEL9 con conectividad online. |
| [Instana Synthetic PoP en k3s RHEL9 - Air-gapped](Configuraciones/instana-synthetic-pop-k3s-rhel9-airgap.md) | Procedimiento para desplegar un Private PoP en un escenario sin acceso directo a Internet. |

---

### 5. Integraciones y sensores

| Guía | Descripción |
|---|---|
| [AWS](Sensores/AWS.md) | Integración de Instana con servicios AWS. |
| [GCP](Sensores/GCP.md) | Integración de Instana con Google Cloud Platform. |
| [IBM DataPower](Sensores/IBM%20DataPower.md) | Configuración para monitoreo de IBM DataPower. |
| [IBM Secret Manager](Sensores/IBM%20Secret%20Manager.md) | Integración con IBM Secret Manager. |
| [IBM iSeries](Sensores/IBM-iSeries.md) | Guía para monitoreo de IBM iSeries. |
| [OpenTelemetry](Sensores/Opentelemetry.md) | Configuración de integración con OpenTelemetry. |
| [Podman](Sensores/Podman.md) | Monitoreo de entornos basados en Podman. |
| [SAP ABAP](Sensores/SAP%20ABAP.md) | Guía para integración con SAP ABAP. |
| [StatsD](Sensores/StatsD.md) | Integración mediante StatsD. |
| [VMware vSphere](Sensores/VMware-VSphere.md) | Configuración para monitoreo de VMware vSphere. |
| [Zabbix](Sensores/Zabbix.md) | Integración con Zabbix. |
| [Action Script](Sensores/Action%20Script.md) | Guía relacionada con scripts de acción o automatización. |

---

### 6. Java Trace SDK y laboratorios

| Guía / recurso | Descripción |
|---|---|
| [Java Trace SDK](Sensores/Java_Trace_SDK/Java_Trace_SDK.md) | Documentación para pruebas e instrumentación mediante Java Trace SDK. |
| [Hello Spring](Sensores/Java_Trace_SDK/hello-spring) | Aplicación de ejemplo para validaciones de instrumentación. |
| [Hello Spring - OpenTelemetry](Sensores/Java_Trace_SDK/hello-spring%20-%20OTEL) | Aplicación de ejemplo orientada a pruebas con OpenTelemetry. |

---

### 7. OpenTelemetry

| Guía / recurso | Descripción |
|---|---|
| [OpenTelemetry - LLM / Traceloop](Opentelemetry/LLM/Traceloop.md) | Guía relacionada con instrumentación de escenarios LLM mediante Traceloop. |
| [Ejemplo chaining.py](Opentelemetry/LLM/chaining.py) | Script de ejemplo para pruebas de instrumentación. |
| [OpenTelemetry - PHP Tracing](Opentelemetry/PHP/Tracing.md) | Procedimiento para trazabilidad en aplicaciones PHP mediante OpenTelemetry. |
| [OpenTelemetry Filelog Receiver](Log%20Monitoring/Opentelemetry%20Filelog%20Receiver.md) | Guía para recolección de logs mediante el receiver Filelog de OpenTelemetry. |

---

### 8. GitLab y GitOps

| Guía / recurso | Descripción |
|---|---|
| [GitOps](Gitlab/Gitops.md) | Procedimiento relacionado con gestión de configuración basada en GitOps. |
| [post-receive](Gitlab/post-receive) | Script de referencia para automatización mediante hook de GitLab. |

---

### 9. Integración con Telegram

| Guía / recurso | Descripción |
|---|---|
| [Configuración de integración con Telegram](Configuraciones/Integracion%20Telegram/Configuracion.md) | Guía para integrar alertas o eventos con Telegram. |
| [Aplicación Python](Configuraciones/Integracion%20Telegram/app.py) | Código de ejemplo para la integración. |
| [Dockerfile](Configuraciones/Integracion%20Telegram/Dockerfile) | Archivo para construir la imagen del servicio de integración. |
| [requirements.txt](Configuraciones/Integracion%20Telegram/requirements.txt) | Dependencias necesarias para ejecutar la integración. |

---

## Recomendaciones de uso

Para utilizar este repositorio de forma ordenada, se recomienda seguir el siguiente criterio:

1. Identificar primero la plataforma o tecnología que se desea monitorear.
2. Revisar la guía correspondiente en el índice.
3. Validar los prerrequisitos técnicos antes de ejecutar cualquier procedimiento.
4. Reemplazar las variables de ejemplo por valores propios del entorno.
5. Ejecutar los comandos de forma secuencial.
6. Validar el resultado desde el host, el clúster o el servicio correspondiente.
7. Confirmar la visibilidad de la entidad, métrica, traza o evento dentro de IBM Instana.
8. Documentar cualquier ajuste realizado durante la implementación.

---

## Estructura actual del repositorio

```text
Instalacion-Agente-Instana/
├── Configuraciones/
├── Gitlab/
├── Log Monitoring/
├── Opentelemetry/
├── Plataformas/
├── Sensores/
└── README.md
```

Esta estructura se mantiene para preservar los enlaces previamente compartidos y evitar cambios que puedan afectar referencias externas.

---

## Buenas prácticas consideradas

La documentación incluida en este repositorio busca mantener los siguientes criterios:

- Redacción técnica clara y directa.
- Procedimientos paso a paso.
- Separación por plataforma, sensor o caso de uso.
- Comandos listos para copiar y adaptar.
- Validaciones posteriores a la configuración.
- Consideraciones operativas cuando el escenario lo requiere.
- Uso de ejemplos prácticos para facilitar pruebas de concepto.
- Enlaces relativos para facilitar la navegación dentro del repositorio.

---

## Consideraciones importantes

- Los comandos y ejemplos deben ser adaptados a cada entorno.
- Las credenciales, tokens, claves o secretos no deben ser almacenados directamente en el repositorio.
- Algunos procedimientos pueden requerir permisos administrativos sobre servidores, clústeres, servicios cloud o consolas de IBM Instana.
- Las versiones de agentes, sensores o componentes pueden variar en el tiempo, por lo que se recomienda validar compatibilidad con la documentación oficial de IBM Instana antes de una implementación productiva.
- En escenarios de cliente, se recomienda validar previamente conectividad, proxy, certificados, permisos y alcance de monitoreo.

---

## Referencias oficiales

- IBM Instana Observability Documentation
- IBM Instana Agents
- IBM Instana Sensors
- IBM Instana OpenTelemetry
- IBM Instana Synthetic Monitoring
- OpenTelemetry Documentation
- GitHub Markdown Documentation

---

## Mantenedor

Juan Conde  
Observabilidad | IBM Instana | Cloud Native Monitoring | Integraciones técnicas

---

## Estado del repositorio

Repositorio en evolución continua.  
Se irán incorporando nuevas guías, ajustes y mejoras en función de nuevos escenarios de implementación, validaciones técnicas y casos de uso.
