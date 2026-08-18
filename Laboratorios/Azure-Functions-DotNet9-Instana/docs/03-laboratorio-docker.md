# Laboratorio Docker reproducible

## Requisitos

- Host Linux con Docker y espacio suficiente.
- Git y `curl`.
- Acceso autorizado a las imágenes Microsoft y paquetes NuGet.
- Para telemetría, Host Agent Instana ya operativo y accesible en TCP 42699.

No se necesitan Kubernetes, OpenShift, AKS ni AutoTrace para este procedimiento.

## Preparación

```bash
git clone <URL>
cd instana-dotnet9-functions-lab
cp .env.example .env
```

`.env` está ignorado. Los scripts del baseline no requieren una agent key; el Host Agent administra sus propias credenciales fuera de este repositorio.

## Escenario clean

```bash
./scripts/02-build-clean.sh
./scripts/03-run-clean.sh
```

El build usa `mcr.microsoft.com/dotnet/sdk:9.0` y la imagen final exacta declarada en `docker/Dockerfile.clean`. El script de corrida hace tres ejecuciones y reinicios controlados, guardando evidencia local.

Validación manual mínima:

```bash
docker ps --filter name=instana-dotnet9-clean
docker port instana-dotnet9-clean-1 80/tcp
curl http://127.0.0.1:<PUERTO>/api/health
docker logs instana-dotnet9-clean-1
```

## Escenario Instana manual

```bash
docker build --progress=plain \
  -f docker/Dockerfile.instana \
  -t instana-dotnet9-lab:instana .
curl -sS -o /dev/null -w 'HTTP=%{http_code}\n' \
  http://127.0.0.1:42699/status
./scripts/07-run-instana.sh
```

`07-run-instana.sh` agrega `host.docker.internal:host-gateway` y configura únicamente host/puerto no secretos. Si el Agent no escucha en el host local, ajuste la red explícitamente y no publique credenciales.

## Validaciones

```bash
docker inspect instana-dotnet9-manual
docker logs --timestamps instana-dotnet9-manual
docker top instana-dotnet9-manual
docker exec instana-dotnet9-manual cat /etc/os-release
docker exec instana-dotnet9-manual ldd --version
docker exec instana-dotnet9-manual dotnet --info
```

Para localizar e inspeccionar el profiler sin asumir su ruta:

```bash
docker exec instana-dotnet9-manual find /home/site/wwwroot -name CoreProfiler.so -print
docker exec instana-dotnet9-manual file /home/site/wwwroot/instana_tracing/CoreProfiler.so
docker exec instana-dotnet9-manual ldd /home/site/wwwroot/instana_tracing/CoreProfiler.so
docker exec instana-dotnet9-manual readelf -d /home/site/wwwroot/instana_tracing/CoreProfiler.so
```

## Tráfico de laboratorio

`09-generate-traffic.sh` existe para una fase end-to-end, pero no es necesario para reproducir la inestabilidad en idle. La matriz válida demostró que B reinicia antes de recibir tráfico. No use carga para diagnosticar un fallo ya presente durante startup/idle.

## Limpieza acotada

Los scripts usan nombres `instana-dotnet9-*`. Antes de repetir, inspeccione y elimine sólo contenedores e imágenes de este laboratorio. No use `docker system prune` en hosts compartidos.
