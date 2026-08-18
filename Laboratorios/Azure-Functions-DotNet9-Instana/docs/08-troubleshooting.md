# Troubleshooting

## Runtime e imagen

```bash
docker exec <container> cat /etc/os-release
docker exec <container> ldd --version
docker exec <container> uname -m
docker exec <container> dotnet --info
docker image inspect mcr.microsoft.com/azure-functions/dotnet-isolated:4-dotnet-isolated9.0
```

Registre el digest, no sólo el tag.

## Estado de la aplicación

```bash
docker ps -a --filter name=instana-dotnet9
docker logs --timestamps <container>
docker inspect --format '{{json .State}}' <container>
docker top <container>
docker port <container> 80/tcp
curl -i http://127.0.0.1:<PUERTO>/api/health
```

Revise por separado `Running`, `OOMKilled`, `ExitCode`, `StartedAt` y `FinishedAt`. El exit code del contenedor puede ocultar reinicios de un worker child administrado por Functions Host.

## CoreProfiler

```bash
docker exec <container> find /home/site/wwwroot -name CoreProfiler.so -print
docker exec <container> file <RUTA_COREPROFILER>
docker exec <container> ldd <RUTA_COREPROFILER>
docker exec <container> readelf -d <RUTA_COREPROFILER>
docker exec <container> sh -c "strings <RUTA_COREPROFILER> | grep -o 'GLIBC_[0-9.]*' | sort -Vu"
```

Una distribución antigua no basta para declarar incompatibilidad: busque `not found`, símbolos requeridos y carga efectiva.

## Variables de instrumentación

```bash
docker exec <container> env | grep -Ei \
  'INSTANA|CORECLR|DOTNET_STARTUP_HOOKS|PROFILER|APPINSIGHTS|OTEL'
```

No copie valores sensibles a tickets ni evidencia pública.

## Host Agent 42699

Desde el host:

```bash
ss -lntp | grep 42699
curl -sS -o /dev/null -w 'HTTP=%{http_code}\n' \
  http://127.0.0.1:42699/status
```

Desde un contenedor Linux, `localhost` apunta al contenedor. Cuando la versión de Docker lo admita:

```bash
docker run --rm \
  --add-host host.docker.internal:host-gateway \
  curlimages/curl:latest \
  -sS -o /dev/null -w 'HTTP=%{http_code}\n' \
  http://host.docker.internal:42699/status
```

Use sólo imágenes aprobadas en el entorno. Un HTTP 200 prueba conectividad al Agent, no visibilidad final en el backend.
