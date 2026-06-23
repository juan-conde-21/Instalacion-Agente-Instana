# Errores comunes

[← Volver a Troubleshooting](README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/troubleshooting/errores-comunes.md`

## Kubernetes cluster unreachable

Validar kubeconfig:

```bash
export KUBECONFIG=~/.kube/config
kubectl get nodes
```

Si no existe:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

## Pods en ImagePullBackOff

En air-gapped, normalmente indica que la imagen no está cargada localmente o que `imagePullPolicy` fuerza descarga.

```bash
kubectl describe pod -n synthetic-pop <pod>
sudo k3s ctr images list | grep -i instana || true
```

Acciones:

- cargar imagen faltante;
- validar repositorio/tag esperado por el chart;
- usar `IfNotPresent` cuando aplique;
- confirmar si el cliente usa registry interno.

## Pods en CrashLoopBackOff

```bash
kubectl logs -n synthetic-pop <pod> --previous --tail=200
kubectl describe pod -n synthetic-pop <pod>
```

Revisar:

- valores del chart;
- endpoints de Instana;
- claves configuradas;
- conectividad saliente;
- recursos disponibles del nodo.

## Problemas de red en RHEL 8.1

Validar NetworkManager:

```bash
systemctl status NetworkManager --no-pager
systemctl status nm-cloud-setup.service --no-pager || true
systemctl status nm-cloud-setup.timer --no-pager || true
```

Si `nm-cloud-setup` está activo, coordinar con el administrador antes de deshabilitarlo.

## DNS dentro del cluster

```bash
kubectl get pods -n kube-system
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100 || true
```

## Falta de recursos

```bash
kubectl top nodes || true
kubectl describe node
free -h
df -h
```

Si no existe metrics-server o no responde, revisar uso de CPU/memoria desde el sistema operativo.
