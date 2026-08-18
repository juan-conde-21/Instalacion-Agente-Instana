# Fuentes oficiales

Fecha de consulta: 2026-08-18.

## IBM Instana

1. **.NET and .NET Core support information**
   https://www.ibm.com/docs/en/instana-observability?topic=core-support-information
   Referencia para runtimes y capacidades soportadas. Incluye instrumentación .NET 9 y notas separadas sobre limitaciones de profiling.

2. **Setting up .NET tracing for Docker**
   https://www.ibm.com/docs/en/instana-observability?topic=tracing-setting-up-net-docker
   Procedimiento oficial usado como base para paquetes, startup hook, CLR profiler y comunicación con el Agent.

3. **Monitoring Azure Functions**
   https://www.ibm.com/docs/en/instana-observability?topic=agents-azure-functions
   Alcance y configuración oficial para trazado de Azure Functions.

4. **Monitoring .NET and .NET Core**
   https://www.ibm.com/docs/en/instana-observability?topic=technologies-monitoring-net-net-core
   Arquitectura y operación del sensor .NET.

5. **.NET and .NET Core sensor releases**
   https://www.ibm.com/docs/en/instana-observability?topic=core-net-net-sensor-releases
   Historial oficial de versiones del sensor.

6. **CLR tracer releases**
   https://www.ibm.com/docs/en/instana-observability?topic=framework-clr-tracer-releases
   Historial oficial del tracer CLR y referencias de AutoTrace.

7. **Troubleshooting .NET tracing for Docker**
   https://www.ibm.com/docs/en/instana-observability?topic=tracing-troubleshooting-net-docker
   Diagnóstico de carga del profiler y conectividad con el Agent.

## Microsoft

1. **Guide for running C# Azure Functions in an isolated worker process**
   https://learn.microsoft.com/en-us/azure/azure-functions/dotnet-isolated-process-guide
   Modelo host/worker, versiones .NET admitidas y artefactos de publicación.

2. **Azure Functions container concepts**
   https://learn.microsoft.com/en-us/azure/azure-functions/container-concepts
   Soporte de contenedores, mantenimiento de imágenes y carácter actualizable de los tags.

## Criterio documental

Las fuentes explican soporte y configuración general; no prueban por sí solas que el digest histórico, AutoTrace 1.322.1 y el tracer manual 1.321.2 sean equivalentes. Esa equivalencia permanece abierta.
