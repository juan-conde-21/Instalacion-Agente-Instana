# IBM Instana - Guías de instalación, configuración, integración y validación

Este repositorio centraliza procedimientos técnicos, herramientas, laboratorios y ejemplos relacionados con IBM Instana. Su propósito es facilitar actividades de instalación, configuración, instrumentación, integración, validación y troubleshooting en distintos entornos empresariales.

El contenido está orientado a implementaciones, pruebas de concepto, habilitación técnica, demostraciones y soporte operativo.

> Este repositorio no reemplaza la documentación oficial de IBM Instana. Los procedimientos complementan dicha documentación con pasos prácticos y experiencias obtenidas en escenarios de implementación y laboratorio.

---

## Objetivo

Documentar de manera clara, ordenada y reutilizable los procedimientos necesarios para:

- Instalar agentes de IBM Instana.
- Validar compatibilidad tecnológica antes de una implementación.
- Configurar el agente y sus componentes.
- Instrumentar aplicaciones y servicios.
- Integrar plataformas, sensores y servicios cloud.
- Implementar OpenTelemetry.
- Configurar monitoreo de logs y Synthetic Monitoring.
- Ejecutar laboratorios reproducibles.
- Diagnosticar problemas técnicos y recopilar evidencia.

---

## Organización del repositorio

| Categoría | Contenido |
|---|---|
| `Plataformas` | Instalación del agente en Linux, Windows, UNIX, OpenShift y escenarios Kubernetes/OpenShift legacy. |
| `Instrumentacion` | AutoTrace, tracers, SDK y procedimientos de instrumentación de aplicaciones y runtimes. |
| `Herramientas` | Scripts de diagnóstico, validación y recopilación de evidencia técnica. |
| `Configuraciones` | Proxy, Vault, Synthetic Private PoP, monitoreo móvil e integraciones operativas. |
| `Sensores` | AWS, GCP, IBM i, DataPower, SAP ABAP, VMware, Podman, StatsD, Zabbix, OpenTelemetry y otros sensores. |
| `Opentelemetry` | Instrumentación y ejemplos específicos para PHP, LLM y otros escenarios. |
| `Log Monitoring` | Recolección y procesamiento de logs mediante OpenTelemetry. |
| `Laboratorios` | Aplicaciones y ambientes reproducibles para validar monitoreo y trazabilidad. |
| `Gitlab` | Procedimientos GitOps y automatización mediante hooks. |

---

# Índice general

## 1. Herramientas de diagnóstico y validación

| Recurso | Descripción |
|---|---|
| [Diagnóstico de compatibilidad para Windows](Herramientas/Diagnostico-Compatibilidad-Windows/README.md) | Script PowerShell de solo lectura que recopila evidencia y evalúa Windows Server, IIS, .NET Framework, .NET/.NET Core y SQL Server local. |
| [Script de diagnóstico](Herramientas/Diagnostico-Compatibilidad-Windows/Diagnostico-Compatibilidad-Instana-Windows.ps1) | Archivo ejecutable para generar el resumen y el ZIP de evidencia. |

---

## 2. Instalación del agente por plataforma

| Guía | Descripción |
|---|---|
| [Linux](Plataformas/Linux.md) | Instalación y validación del agente Instana en servidores Linux. |
| [Windows](Plataformas/Windows.md) | Instalación del agente en sistemas Windows. |
| [UNIX](Plataformas/UNIX.md) | Procedimiento orientado a plataformas UNIX. |
| [OpenShift](Plataformas/Openshift.md) | Despliegue del agente en entornos OpenShift. |
| [Kubernetes / OpenShift legacy](Plataformas/Instana-kubernetes-Openshift-Legacy.md) | Configuración para versiones o escenarios legacy que requieren tratamiento específico. |

---

## 3. Instrumentación de aplicaciones y trazas

| Guía | Descripción |
|---|---|
| [IBM ACE - AutoTrace Webhook en OpenShift](Instrumentacion/IBM-ACE/README.md) | Corrección, habilitación controlada, instrumentación y troubleshooting del AutoTrace Webhook para IBM App Connect Enterprise. |
| [AWS Lambda - Node.js](Plataformas/AWS/Lambda/nodejs.md) | Instrumentación de funciones AWS Lambda desarrolladas en Node.js. |
| [AWS Lambda - Python](Plataformas/AWS/Lambda/python.md) | Instrumentación de funciones AWS Lambda desarrolladas en Python. |
| [Java Trace SDK](Sensores/Java_Trace_SDK/Java_Trace_SDK.md) | Instrumentación manual de aplicaciones Java mediante el SDK de trazas de Instana. |
| [PHP Tracing con OpenTelemetry](Opentelemetry/PHP/Tracing.md) | Trazabilidad de aplicaciones PHP mediante OpenTelemetry. |

---

## 4. AWS y monitoreo serverless

| Guía | Descripción |
|---|---|
| [Sensor AWS](Sensores/AWS.md) | Integración general con servicios de Amazon Web Services. |
| [AWS Lambda - Node.js](Plataformas/AWS/Lambda/nodejs.md) | Instrumentación de funciones Lambda desarrolladas en Node.js. |
| [AWS Lambda - Python](Plataformas/AWS/Lambda/python.md) | Instrumentación de funciones Lambda desarrolladas en Python. |
| [Ejemplo Node.js para Lambda](Plataformas/AWS/Lambda/NodeJS/) | Archivos de ejemplo para pruebas de implementación. |

---

## 5. Configuración avanzada e integraciones operativas

| Guía | Descripción |
|---|---|
| [Proxy del agente Instana](Configuraciones/Configuracion%20de%20Proxy%20en%20Agente%20Instana.md) | Configuración del agente cuando la salida se realiza mediante proxy. |
| [Squid Proxy](Configuraciones/Configurar%20Squid%20Proxy.md) | Implementación de un proxy Squid para escenarios controlados. |
| [Archivo squid.conf](Configuraciones/squid.conf) | Configuración de referencia para Squid. |
| [Convertir agente estático a dinámico](Configuraciones/Convertir%20Agente%20Instana%20Estatico%20a%20Dinamico.md) | Ajuste del comportamiento del agente. |
| [Implementación con Vault](Configuraciones/Implementacion%20Vault.md) | Integración y manejo de secretos mediante Vault. |
| [Mobile App Monitoring](Configuraciones/Mobile_App_Monitoring.md) | Configuración relacionada con monitoreo de aplicaciones móviles. |
| [OpenTelemetry Log Receiver](Configuraciones/Opentelemetry%20Log%20Receiver.md) | Configuración del receptor de logs mediante OpenTelemetry. |
| [Integración con Telegram](Configuraciones/Integracion%20Telegram/Configuracion.md) | Integración de eventos o alertas con Telegram. |

---

## 6. Synthetic Monitoring - Private PoP

La documentación de Synthetic Private PoP está organizada por modalidad de instalación, sistema operativo, validaciones y troubleshooting.

| Recurso | Descripción |
|---|---|
| [Manual principal de Synthetic Private PoP](Configuraciones/Synthetic-PoP/README.md) | Punto de entrada para instalaciones online y air-gapped sobre k3s y Helm. |
| [Mapa de navegación](Configuraciones/Synthetic-PoP/MAPA_NAVEGACION.md) | Secuencia recomendada de documentos y decisiones. |
| [Consideraciones generales](Configuraciones/Synthetic-PoP/00-consideraciones-generales.md) | Alcance, supuestos y criterios previos. |
| [Guía online anterior](Configuraciones/instana-synthetic-pop-k3s-rhel9-online.md) | Procedimiento conservado para mantener compatibilidad con referencias previas. |
| [Guía air-gapped anterior](Configuraciones/instana-synthetic-pop-k3s-rhel9-airgap.md) | Procedimiento anterior para instalaciones sin acceso directo a Internet. |

---

## 7. Sensores e integraciones tecnológicas

| Guía | Descripción |
|---|---|
| [AWS](Sensores/AWS.md) | Integración con servicios AWS. |
| [GCP](Sensores/GCP.md) | Integración con Google Cloud Platform. |
| [IBM DataPower](Sensores/IBM%20DataPower.md) | Monitoreo de appliances IBM DataPower. |
| [IBM Secret Manager](Sensores/IBM%20Secret%20Manager.md) | Integración con IBM Secret Manager. |
| [IBM i](Sensores/IBM-iSeries.md) | Monitoreo de IBM i / iSeries. |
| [OpenTelemetry](Sensores/Opentelemetry.md) | Integración general con OpenTelemetry. |
| [Podman](Sensores/Podman.md) | Monitoreo de entornos basados en Podman. |
| [SAP ABAP](Sensores/SAP%20ABAP.md) | Configuración del sensor SAP ABAP y SAP Java Connector. |
| [StatsD](Sensores/StatsD.md) | Integración de métricas mediante StatsD. |
| [VMware vSphere](Sensores/VMware-VSphere.md) | Monitoreo de infraestructura VMware. |
| [Zabbix](Sensores/Zabbix.md) | Integración con Zabbix. |
| [Action Script](Sensores/Action%20Script.md) | Scripts de acción y automatización. |
| [Java Trace SDK](Sensores/Java_Trace_SDK/Java_Trace_SDK.md) | Instrumentación manual mediante Java Trace SDK. |
| [Ejemplos Java Trace SDK](Sensores/Java_Trace_SDK/) | Aplicaciones de ejemplo con instrumentación Instana y OpenTelemetry. |

---

## 8. OpenTelemetry

| Recurso | Descripción |
|---|---|
| [LLM con Traceloop](Opentelemetry/LLM/Traceloop.md) | Instrumentación de aplicaciones LLM mediante OpenTelemetry y Traceloop. |
| [Ejemplo chaining.py](Opentelemetry/LLM/chaining.py) | Script de ejemplo para pruebas de trazabilidad. |
| [PHP Tracing](Opentelemetry/PHP/Tracing.md) | Trazabilidad de aplicaciones PHP mediante OpenTelemetry. |

---

## 9. Log Monitoring

| Recurso | Descripción |
|---|---|
| [Índice de Log Monitoring](Log%20Monitoring/README.md) | Punto de entrada para los procedimientos de recolección y envío de logs hacia Instana. |
| [OpenTelemetry Filelog Receiver](Log%20Monitoring/Opentelemetry%20Filelog%20Receiver.md) | Procedimiento general para leer archivos de log con OpenTelemetry Collector Contrib y enviarlos al agente Instana. |
| [NGINX Stream con OpenTelemetry Filelog e Instana](Log%20Monitoring/NGINX_Stream_OpenTelemetry_Filelog_Instana.md) | Procedimiento completo para recolectar logs de sesiones TCP/UDP de NGINX Stream, procesarlos con Filelog Receiver y enviarlos a Instana. |

---

## 10. GitLab y GitOps

| Recurso | Descripción |
|---|---|
| [GitOps](Gitlab/Gitops.md) | Procedimiento de gestión y automatización basada en Git. |
| [Hook post-receive](Gitlab/post-receive) | Script para automatizar acciones después de recibir cambios en GitLab. |

---

## 11. Laboratorios y ejemplos reproducibles

| Laboratorio | Descripción |
|---|---|
| [Apache HTTPD + Spring Boot + MySQL](Laboratorios/Apache-HTTPD-SpringBoot-MySQL/README.md) | Laboratorio para validar host, Apache, Java, Spring Boot, JDBC, MySQL, errores y latencia. |
| [Node.js 14 + PM2 + PostgreSQL en Ubuntu](Laboratorios/Node14-pm2-postgresql-Ubuntu/README.md) | Laboratorio controlado para Node.js legacy, PM2, PostgreSQL e instrumentación con Instana. |

> Los laboratorios pueden utilizar versiones heredadas con fines de reproducción técnica. Cada guía indica sus limitaciones y el alcance recomendado.

---

## Cómo utilizar el repositorio

1. Identificar la plataforma, tecnología o escenario que se desea trabajar.
2. Abrir la guía correspondiente desde este índice.
3. Revisar el alcance y los prerrequisitos antes de ejecutar comandos.
4. Confirmar las versiones utilizadas y contrastarlas con la documentación oficial vigente.
5. Reemplazar los valores de referencia por los datos del entorno.
6. Ejecutar los pasos de manera secuencial.
7. Conservar evidencias de instalación, configuración y validación.
8. Confirmar en Instana la entidad, métrica, traza, evento o log esperado.

---

## Estructura actual

```text
Instalacion-Agente-Instana/
├── Configuraciones/
│   ├── Integracion Telegram/
│   └── Synthetic-PoP/
├── Gitlab/
├── Herramientas/
│   └── Diagnostico-Compatibilidad-Windows/
├── Instrumentacion/
│   └── IBM-ACE/
│       └── README.md
├── Laboratorios/
│   ├── Apache-HTTPD-SpringBoot-MySQL/
│   └── Node14-pm2-postgresql-Ubuntu/
├── Log Monitoring/
│   ├── README.md
│   ├── Opentelemetry Filelog Receiver.md
│   └── NGINX_Stream_OpenTelemetry_Filelog_Instana.md
├── Opentelemetry/
│   ├── LLM/
│   └── PHP/
├── Plataformas/
│   └── AWS/Lambda/
├── Sensores/
│   └── Java_Trace_SDK/
└── README.md
```

La estructura existente se conserva para no afectar enlaces previamente compartidos. Las nuevas herramientas y guías deben incorporarse en la categoría que corresponda, evitando mover archivos que ya puedan estar referenciados externamente.

---

## Criterios de documentación

Las contribuciones y actualizaciones deberían mantener:

- Redacción técnica clara y directa.
- Alcance y prerrequisitos explícitos.
- Comandos listos para copiar y adaptar.
- Separación entre instalación, configuración, validación y troubleshooting.
- Evidencia del resultado esperado.
- Advertencias para tecnologías legacy o fuera de ciclo de vida.
- Protección de credenciales, tokens y secretos.
- Enlaces relativos para facilitar la navegación.
- Referencias a documentación oficial cuando la compatibilidad pueda cambiar.
- Uso de nombres genéricos en las guías públicas, evitando publicar clientes, dominios internos, direcciones IP, registros privados o identificadores sensibles.

---

## Consideraciones importantes

- Validar siempre la matriz de soporte oficial antes de una implementación productiva.
- No almacenar credenciales, claves, tokens o certificados privados en el repositorio.
- No publicar nombres de clientes, dominios internos, direcciones IP, rutas privadas o identificadores propios de un ambiente.
- Algunas actividades requieren permisos administrativos o acceso a consolas de nube y clústeres.
- La compatibilidad de runtimes, librerías, agentes, sensores y componentes cambia con el tiempo.
- En ambientes de cliente, validar conectividad, proxy, inspección TLS, certificados, permisos y alcance antes del despliegue.
- Las herramientas de diagnóstico no reemplazan una prueba funcional de instrumentación.

---

## Referencias oficiales

- [IBM Instana Observability Documentation](https://www.ibm.com/docs/en/instana-observability)
- [Instana agents](https://www.ibm.com/docs/en/instana-observability?topic=instana-agents)
- [Instana sensors](https://www.ibm.com/docs/en/instana-observability?topic=instana-monitoring-supported-technologies)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [GitHub Markdown Documentation](https://docs.github.com/en/get-started/writing-on-github)

---

## Mantenedor

**Juan Conde**  
Observabilidad | IBM Instana | Cloud Native Monitoring | Integraciones técnicas

---

## Estado del repositorio

Repositorio en evolución continua. Se incorporan nuevas guías, laboratorios, herramientas y ajustes en función de escenarios de implementación, validaciones técnicas y casos de uso.
