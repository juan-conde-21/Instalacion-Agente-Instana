# Contexto y alcance

## Problema original

Una aplicación Azure Functions .NET 9 isolated dejó de iniciar después de habilitar instrumentación automática. El ambiente observado utilizaba AKS, la imagen lógica `mcr.microsoft.com/azure-functions/dotnet-isolated:4-dotnet-isolated9.0`, Debian 11, glibc 2.31 y AutoTrace webhook 1.322.1. El contenedor terminó con código 139, compatible con `SIGSEGV`.

El caso se presenta anonimizado: no se incluyen organización, nombres internos, direcciones, credenciales ni endpoints del backend.

## Pregunta técnica

¿Puede separarse el efecto de la imagen, .NET 9, las dependencias nativas, `CoreProfiler.so`, el tracer manual y el modelo host/worker antes de introducir variables del orquestador?

## Alcance realizado

- Docker local sobre Ubuntu.
- Azure Functions .NET 9 isolated.
- Imagen final Microsoft indicada por el caso.
- Escenarios clean e instrumentación manual Instana 1.321.2.
- Host Agent local 1.322.0 por TCP 42699.
- Inspección de runtime, profiler, dependencias, estabilidad y ciclo de vida del worker.

## Fuera de alcance de esta etapa

- Reproducir el digest histórico exacto.
- Kubernetes, AKS, OpenShift, Helm y AutoTrace.
- Comparación .NET 8.
- Application Insights y coexistencia de profilers.
- Confirmación en UI/backend como criterio final de tracing.
- Determinar una causa raíz definitiva para el reinicio de la segunda Function.

La investigación experimental quedó congelada antes de completar A1/A2. Sus fuentes se preservan para una fase futura, pero no forman parte de las conclusiones.
