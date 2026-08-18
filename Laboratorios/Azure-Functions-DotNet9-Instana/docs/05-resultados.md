# Resultados

## 1. Baseline

La Azure Function .NET 9 isolated con sólo `/api/health` fue estable en tres ejecuciones clean y reinicios controlados. La imagen final fue la referencia Microsoft requerida.

## 2. Instrumentación manual

Se construyó una imagen separada con Instana tracer 1.321.2. El baseline instrumentado inició, respondió health y mantuvo Functions Host e isolated worker operativos. Esto demuestra que la combinación mínima probada puede arrancar instrumentada.

## 3. CoreProfiler

`CoreProfiler.so` fue localizado y cargado. `file`, `ldd` y `readelf` no mostraron dependencias nativas faltantes en Debian 12/glibc 2.36. El binario no se conserva en Git; se preservan sus metadatos e inspecciones textuales.

## 4. Conexión con Host Agent

El Host Agent 1.322.0 escuchaba en TCP 42699. Usando el gateway del host, el contenedor obtuvo HTTP 200 del endpoint de status. Esto descarta inaccesibilidad del Agent como condición necesaria del reinicio observado.

La recepción completa en backend/UI quedó fuera de la evidencia final; infraestructura visible y application tracing no se declaran PASS sólo por la conectividad.

## 5. Assembly ampliado

Al ejecutar una aplicación con más endpoints bajo la misma instrumentación, el isolated worker comenzó a reiniciarse aun sin tráfico. Functions Host alcanzó su límite de reinicios. La variante clean equivalente permaneció estable.

## 6. Matriz A/B/C/D

La primera matriz se invalidó porque A no coincidía con el baseline. La matriz v2 reconstruida desde Git estableció:

- A: una Function, clean e Instana estables.
- B: segunda Function HTTP mínima, clean estable e Instana inestable en idle.
- C y D: clean estables e Instana inestables en idle.

## 7. Frontera identificada

B fue la primera variante inestable. El delta observable respecto de A añade el segundo método Function/HttpTrigger y su metadata generada. La reducción A0/A1/A2 diseñada para separar IL ordinario, segunda clase y atributos quedó pendiente y no se usa para atribución causal.

## Resultado negativo importante

El `ExitCode 139` del caso original no se reprodujo a nivel del contenedor. No hubo OOM. Evidencia posterior observó terminación del worker child por señal en una variante ampliada, pero eso no iguala por sí solo el fenómeno del entorno original ni establece su causa.
