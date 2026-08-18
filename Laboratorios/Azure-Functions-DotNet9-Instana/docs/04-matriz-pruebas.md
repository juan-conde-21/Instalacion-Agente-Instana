# Matriz de pruebas

## Valid experiments

| Escenario | Aplicación | Clean | Instana idle | Tráfico requerido | Resultado |
|---|---|---:|---:|---:|---|
| Baseline histórico | Una Function `/api/health` | PASS, 3/3 | PASS | No | Baseline instrumentado estable |
| A, matriz v2 | Baseline histórico exacto | PASS | PASS, 30 s | No | Última variante estable |
| B, matriz v2 | A + `/api/test` constante | PASS | FAIL | No | Primera variante inestable |
| C, matriz v2 | B + `/api/error` HTTP 500 sin excepción | PASS | FAIL | No | Inestable |
| D, matriz v2 | C + excepción controlada | PASS | FAIL | No | Inestable |
| Escenario ampliado | Health, test y error | PASS | FAIL | No | Worker reinicia en idle |

En B/C/D, Functions Host inició tres workers, alcanzó el límite de reinicios y cerró de forma observable con código 0; `OOMKilled=false`. No se observó código 139 a nivel del contenedor.

Los endpoints de B/C/D no se invocaron después de detectar el fallo en idle, para no mezclar discovery/startup con ejecución.

## Frontera reproducible

- Última variante estable: **A**, una Azure Function HTTP.
- Primera variante inestable: **B**, A más una segunda Azure Function HTTP mínima.
- Primer cambio asociado reproduciblemente: segundo método con atributos `[Function]` y `[HttpTrigger]`, junto con la metadata de Function que genera el SDK.

Esta asociación no distingue todavía código IL, atributos, metadata generada, discovery, JIT ni rewriter.

## Invalid / not used for conclusions

Una matriz preliminar definió A de forma distinta al baseline histórico. Sus logs se conservan como auditoría, pero quedan excluidos de conclusiones. La matriz v2 reconstruyó A directamente desde Git y verificó SHA256 de `HealthFunction.cs`, `Program.cs`, el proyecto y `host.json`.

La fase 16 A0/A1/A2 quedó interrumpida. Sus PASS clean parciales no constituyen una corrida homogénea y tampoco se usan para conclusiones. Las imágenes fueron eliminadas al recuperar espacio; las fuentes permanecen en Git.

Véanse `evidencias/INVALID-EXPERIMENTS.md`, `evidencias/phase15-v2/summary.tsv` y los diffs seleccionados.
