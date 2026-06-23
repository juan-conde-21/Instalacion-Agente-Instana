# Checklist post instalación

[← Volver al índice principal](../README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/validaciones/checklist-post-instalacion.md`  
**Paso anterior:** instalación online o air-gapped  
**Siguiente paso:** [Troubleshooting](../troubleshooting/README.md), solo si hay errores

## Objetivo

Validar que k3s, Helm y Synthetic PoP quedaron operativos.

## Validar sistema operativo

```bash
cat /etc/os-release
uname -r
```

## Validar k3s

```bash
sudo systemctl status k3s --no-pager
k3s --version
kubectl get nodes -o wide
kubectl get pods -A
```

## Validar Helm

```bash
helm version
helm list -A
```

## Validar Synthetic PoP

```bash
export POP_NAMESPACE="synthetic-pop"
export POP_RELEASE="synthetic-pop"

helm list -n "${POP_NAMESPACE}"
helm status "${POP_RELEASE}" -n "${POP_NAMESPACE}"
kubectl get pods -n "${POP_NAMESPACE}" -o wide
kubectl get deploy -n "${POP_NAMESPACE}"
kubectl get svc -n "${POP_NAMESPACE}"
kubectl get events -n "${POP_NAMESPACE}" --sort-by=.lastTimestamp
```

## Validar logs

```bash
kubectl logs -n "${POP_NAMESPACE}" deploy/${POP_RELEASE}-controller --tail=100 || true
kubectl logs -n "${POP_NAMESPACE}" deploy/${POP_RELEASE}-http --tail=100 || true
kubectl logs -n "${POP_NAMESPACE}" deploy/${POP_RELEASE}-javascript --tail=100 || true
kubectl logs -n "${POP_NAMESPACE}" deploy/${POP_RELEASE}-browserscript --tail=100 || true
```

## Validación en Instana

Ingresar a Instana Synthetic Monitoring y confirmar que la private location aparece registrada.

## Criterio de cierre

La instalación se considera funcional cuando:

- el nodo k3s está en estado `Ready`;
- los pods del namespace `synthetic-pop` están `Running` o `Completed` según corresponda;
- no existen eventos críticos recientes;
- Helm muestra el release instalado;
- la private location aparece en Instana;
- una prueba sintética simple puede ejecutarse desde la ubicación privada.

## Si algo falla

Continuar con [Troubleshooting](../troubleshooting/README.md).
