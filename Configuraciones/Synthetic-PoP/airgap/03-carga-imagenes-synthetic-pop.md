# Air-gapped - Carga de imágenes Synthetic PoP

[← Volver a ruta air-gapped](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/airgap/03-carga-imagenes-synthetic-pop.md`  
**Paso anterior:** [Instalación de k3s air-gapped](02-instalacion-k3s-airgap.md)  
**Siguiente paso:** [Instalación Synthetic PoP air-gapped](04-instalacion-synthetic-pop-helm-airgap.md)

## Objetivo

Cargar las imágenes requeridas por Synthetic PoP en el containerd utilizado por k3s.

## Validar archivo de imágenes

```bash
cd /opt/instana/synthetic-pop-airgap-bundle
ls -lh images/
```

## Importar imágenes

```bash
sudo k3s ctr images import images/synthetic-pop-images.tar
```

## Validar imágenes cargadas

```bash
sudo k3s ctr images list | grep -i instana || true
sudo k3s ctr images list | grep -i synthetic || true
```

## Consideración sobre pullPolicy

En air-gapped, los pods deben usar imágenes ya presentes localmente. Si el chart o values permiten configurarlo, usar:

```yaml
imagePullPolicy: IfNotPresent
```

Evitar `Always` en servidores sin Internet, salvo que exista registry interno configurado.

## Siguiente paso

Continuar con [04-instalacion-synthetic-pop-helm-airgap.md](04-instalacion-synthetic-pop-helm-airgap.md).
