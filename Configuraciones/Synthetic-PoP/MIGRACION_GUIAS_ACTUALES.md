# Migración de guías actuales

[← Volver al índice principal](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/MIGRACION_GUIAS_ACTUALES.md`

## Objetivo

Ordenar la transición desde las guías actuales hacia la nueva estructura modular, sin romper enlaces ya compartidos.

## Guías actuales identificadas

Mantener estos archivos en su ubicación actual si ya fueron compartidos:

- `Configuraciones/instana-synthetic-pop-k3s-rhel9-online.md`
- `Configuraciones/instana-synthetic-pop-k3s-rhel9-airgap.md`

## Recomendación

No eliminar los documentos actuales. Agregar una nota al inicio de cada uno:

```markdown
> Esta guía corresponde a una instalación validada en RHEL 9.
> Para nuevas implementaciones, revisar la guía modular:
> [Synthetic-PoP](Synthetic-PoP/README.md)
```

## Nueva ubicación sugerida

```text
Configuraciones/Synthetic-PoP/
```

## Criterio de uso

| Caso | Documento recomendado |
|---|---|
| Cliente nuevo online | `Synthetic-PoP/online/README.md` |
| Cliente nuevo air-gapped | `Synthetic-PoP/airgap/README.md` |
| Consulta histórica RHEL 9 online | Mantener guía actual online. |
| Consulta histórica RHEL 9 air-gapped | Mantener guía actual air-gapped. |
```
