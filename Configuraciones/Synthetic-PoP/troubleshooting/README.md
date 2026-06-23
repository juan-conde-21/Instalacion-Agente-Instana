# Troubleshooting

[← Volver al índice principal](../README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/troubleshooting/README.md`  
**Documento relacionado:** [Errores comunes](errores-comunes.md)

## Objetivo

Centralizar comandos de diagnóstico para problemas durante la instalación de k3s, Helm o Synthetic PoP.

## Primeros comandos a ejecutar

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get pods -n synthetic-pop -o wide
kubectl get events -n synthetic-pop --sort-by=.lastTimestamp
helm list -A
helm status synthetic-pop -n synthetic-pop
```

## Diagnóstico de un pod

```bash
kubectl describe pod -n synthetic-pop <pod>
kubectl logs -n synthetic-pop <pod> --tail=200
kubectl logs -n synthetic-pop <pod> --previous --tail=200 || true
```

## Diagnóstico de k3s

```bash
sudo systemctl status k3s --no-pager
sudo journalctl -u k3s -n 200 --no-pager
sudo k3s ctr images list | head
```

## Problemas comunes

Revisar [errores-comunes.md](errores-comunes.md).
