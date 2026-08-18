# Arquitectura

Azure Functions isolated separa el Functions Host del proceso de aplicación. El Host descubre las Functions, administra invocaciones y supervisa al worker. El worker ejecuta el assembly .NET del laboratorio.

```mermaid
flowchart LR
    C[Cliente HTTP] --> H[Azure Functions Host]
    H --> W[dotnet isolated worker]
    P[CoreProfiler.so] -. instrumenta .-> W
    S[Instana startup hook] -. configura .-> W
    W -->|spans TCP 42699| A[Instana Host Agent]
    A --> B[Instana Backend]
```

## Componentes

- **Functions Host:** proceso padre que inicia y reinicia el worker isolated. El estado del contenedor por sí solo no describe siempre cómo terminó el child.
- **Isolated worker:** proceso `dotnet` que carga el assembly de la aplicación y sus metadatos de Functions.
- **Instana tracer:** paquetes .NET incorporados durante el build instrumentado.
- **CoreProfiler:** biblioteca nativa cargada mediante las variables CLR documentadas por IBM. En la combinación probada, `ldd` no reportó dependencias faltantes.
- **Host Agent:** receptor local de telemetría. El contenedor lo alcanzó mediante `host.docker.internal` y `host-gateway`, no mediante su propio `localhost`.
- **Backend:** destino del Host Agent. La visibilidad completa en UI no fue demostrada en esta etapa y no se usa como prueba de estabilidad.

## Flujo de inicio relevante

```mermaid
sequenceDiagram
    participant Docker
    participant Host as Functions Host
    participant Worker as Isolated worker
    participant Agent as Host Agent
    Docker->>Host: inicia contenedor
    Host->>Worker: inicia proceso dotnet
    Worker->>Worker: carga assembly, metadata y profiler
    Worker->>Agent: conexión 42699
    alt baseline de una Function
        Worker-->>Host: permanece disponible
    else segunda Function instrumentada
        Worker--xHost: termina durante idle
        Host->>Worker: intenta reinicio
    end
```
