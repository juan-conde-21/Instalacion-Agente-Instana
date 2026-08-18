# Evidencias seleccionadas

Este directorio conserva evidencia textual pequeña y útil para auditar las conclusiones. Los timestamps corresponden a las corridas originales. Se excluyeron binarios, dumps de memoria, inventarios de otros workloads, identificadores efímeros y logs redundantes.

| Fase | Contenido público seleccionado |
|---|---|
| phase01 | OS, glibc, arquitectura y runtime de la imagen actual |
| phase02 | build, health y estabilidad clean 3/3 |
| phase03 | inventario previo de paquetes e instrumentación |
| phase04 | carga, dependencias y versiones requeridas por CoreProfiler; health y logs |
| phase05-06 | status HTTP y conectividad contenedor → Agent 42699, sin datos del Agent |
| phase07-09 | configuración no secreta, health, tráfico controlado y reinicio idle |
| phase11 | baselines congelados e identificadores de imágenes de la corrida |
| phase12-14 | metadata de dumps, extractos de terminación y ciclo de vida del worker; no contiene dumps |
| phase15-v2 | matriz válida, manifiesto, diffs y logs por variante |
| phase15 | sólo auditoría del intento invalidado |
| phase16 | estado parcial y recuperación de espacio; no se usa para conclusiones |

## Integridad y límites

- `CoreProfiler.so` no se publica. Su SHA256 en la corrida fue el registrado en `phase04/profiler-sha256.txt`; se conservan `file`, `ldd`, `readelf` y símbolos requeridos.
- Los dumps de memoria fueron retirados del árbol y continúan excluidos por `.gitignore`; sólo quedan tamaño/hash y extractos no sensibles.
- `phase15-v2/summary.tsv` es la fuente compacta de la matriz válida.
- `INVALID-EXPERIMENTS.md` explica por qué la matriz preliminar y la corrida parcial de phase16 no sustentan conclusiones.
- Los IDs de contenedor e imagen prueban identidad dentro de la corrida, pero no permiten recuperar imágenes eliminadas.

Ningún archivo de esta carpeta debe contener agent keys, download keys, tokens, endpoints privados ni datos de una organización.
