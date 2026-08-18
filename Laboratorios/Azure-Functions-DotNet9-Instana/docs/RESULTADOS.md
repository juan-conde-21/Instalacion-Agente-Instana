# Resultados consolidados

La presentación pública y la separación entre experimentos válidos e inválidos se encuentran en:

- [`04-matriz-pruebas.md`](04-matriz-pruebas.md)
- [`05-resultados.md`](05-resultados.md)
- [`06-conclusiones.md`](06-conclusiones.md)

## Resumen compacto

| Variante | Clean | Instana idle | Resultado |
|---|---|---|---|
| A — una Function | PASS | PASS | Última estable |
| B — segunda Function HTTP | PASS | FAIL antes de tráfico | Primera inestable |
| C | PASS | FAIL antes de tráfico | Inestable |
| D | PASS | FAIL antes de tráfico | Inestable |

No se reprodujo `ExitCode 139` a nivel del contenedor. La matriz preliminar y phase16 incompleta están excluidas de conclusiones.
