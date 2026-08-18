# Estado

Laboratorio Docker completado y congelado para presentación.

# Qué demostramos

Azure Functions .NET 9 puede arrancar instrumentado con Instana en el baseline mínimo de una Function.

# Problema reproducido

Al agregar una segunda Function HTTP mínima, el worker isolated comienza a reiniciarse aun sin tráfico; la variante clean continúa estable.

# Qué NO demostramos

No se reprodujo `ExitCode 139` a nivel del contenedor y no se determinó una causa raíz.

# Compatibilidad

No existe evidencia del laboratorio para declarar incompatible la imagen base Microsoft con Instana.

# Diferencia con el ambiente original

- Laboratorio: Debian 12, glibc 2.36 e instrumentación manual 1.321.2.
- Ambiente original observado: Debian 11, glibc 2.31 y AutoTrace webhook 1.322.1.

El tag lógico era el mismo, pero no se demostró que el digest fuera igual.

# Próximo paso

Reproducir exactamente el digest, runtime y tracer del ambiente original antes de volver al orquestador.
