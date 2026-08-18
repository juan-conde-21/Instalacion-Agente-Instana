# Conclusiones

## ¿Se reprodujo ExitCode 139?

**No.** El contenedor del laboratorio no terminó con 139.

## ¿Se encontró un problema reproducible?

**Sí.** Con la instrumentación manual probada, agregar una segunda Azure Function HTTP mínima se asoció reproduciblemente con reinicios del worker isolated durante idle. La variante clean equivalente permaneció estable.

## ¿Instana soporta .NET 9?

La información oficial de soporte de IBM consultada incluye instrumentación para .NET 9. IBM distingue esa instrumentación de capacidades de profiling con limitaciones específicas; los términos no deben intercambiarse. La versión concreta, plataforma y método de despliegue siempre deben contrastarse con la documentación vigente.

## ¿Podemos declarar no soportada la imagen Microsoft?

**No.** El baseline instrumentado funcionó sobre la imagen actual. Un fallo al cruzar la frontera de una a dos Functions no demuestra incompatibilidad general de la imagen.

## Diferencia respecto del ambiente original

| Dimensión | Ambiente original observado | Laboratorio Docker |
|---|---|---|
| Plataforma | AKS | Docker local |
| Imagen lógica | `4-dotnet-isolated9.0` | `4-dotnet-isolated9.0` |
| OS/glibc | Debian 11 / 2.31 | Debian 12 / 2.36 |
| Instrumentación | AutoTrace webhook 1.322.1 | Manual tracer 1.321.2 |
| Resultado | ExitCode 139 | Reinicio del worker; sin 139 del contenedor |

Un tag de contenedor mutable no sustituye al digest histórico.

## Formulación técnica final

La instrumentación .NET 9 sobre la imagen actual fue validada en un escenario mínimo. Se identificó además una inestabilidad reproducible al aumentar de una a dos Azure Functions dentro del mismo worker isolated. El `ExitCode 139` exacto del ambiente original no fue reproducido y requiere reproducir el digest original Debian 11/glibc 2.31 y la instrumentación AutoTrace exacta.

No se presenta una RCA. No se atribuye todavía el reinicio al rewriter, JIT, Functions Host, metadata, glibc ni CoreProfiler.
