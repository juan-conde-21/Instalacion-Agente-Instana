# README del bundle air-gapped

Este archivo debe viajar dentro del paquete `synthetic-pop-airgap-bundle`.

## Contenido esperado

```text
synthetic-pop-airgap-bundle/
├── binaries/
├── charts/
├── images/
├── values/
├── scripts/
├── evidencias/
└── versiones.env
```

## Validación rápida

```bash
source ./versiones.env
find . -type f | sort
cat evidencias/manifest-files.txt
cat evidencias/sha256sum.txt
```

## Reglas

- No usar `latest`.
- No incluir secretos reales en archivos versionados.
- Registrar fecha, cliente, sistema operativo y versiones.
