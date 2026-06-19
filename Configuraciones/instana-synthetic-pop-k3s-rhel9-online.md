# Despliegue de Instana Synthetic Private PoP sobre k3s en Red Hat Enterprise Linux 9

## 1. Objetivo

Documentar el procedimiento para desplegar un **Instana Synthetic Private PoP** sobre un servidor **Red Hat Enterprise Linux 9** usando **k3s single-node** y el **Helm chart oficial de Instana**.

Este documento está orientado a un escenario **online**, donde el servidor tiene salida a Internet para descargar paquetes, k3s, Helm e imágenes requeridas por el chart `synthetic-pop`.

## 2. Escenario validado

| Componente | Valor de referencia |
|---|---|
| Sistema operativo | Red Hat Enterprise Linux 9.x |
| Arquitectura | x86_64 |
| Kubernetes | k3s single-node |
| Despliegue Synthetic PoP | Helm chart `synthetic-pop` |
| Namespace sugerido | `synthetic-pop` |
| Servidor base | 4 vCPU / 16 GB RAM |
| Tipo de instalación | Online |

> **Nota de capacidad:** para un servidor de **4 vCPU / 16 GB RAM**, se recomienda usar este despliegue como **POC o piloto controlado**. Es razonable para API Simple y API Script, pero los tests Browser deben habilitarse de forma progresiva, iniciando con 1 o 2 pruebas y validando consumo antes de aumentar la carga.

## 3. Recomendación de arquitectura

Para este escenario se recomienda:

1. Preparar el servidor RHEL 9.
2. Instalar k3s manualmente.
3. Validar red, DNS y salida de pods.
4. Instalar Helm.
5. Usar el comando Helm generado desde la página de Instana.
6. Reemplazar los valores de credenciales y ubicación.
7. Validar el estado del PoP y su registro como Private Location.

Se recomienda **no usar `popctl --create-k3s-cluster`** en este caso, ya que el servidor tiene recursos limitados y es preferible controlar manualmente k3s, firewall, DNS y el despliegue Helm.

## 4. Prerrequisitos

### 4.1 Recursos mínimos sugeridos

| Recurso | Mínimo recomendado para este escenario |
|---|---:|
| CPU | 4 vCPU |
| RAM | 16 GB |
| Disco | 80 GB a 100 GB libres |
| Sistema operativo | Red Hat Enterprise Linux 9.x |
| Usuario | `root` o usuario con privilegios `sudo` |
| Acceso a Internet | Requerido |

### 4.2 Endpoints requeridos

El servidor debe poder resolver DNS y conectarse por HTTPS, al menos, a los siguientes endpoints:

```text
https://www.ibm.com
https://agents.instana.io
https://artifact-public.instana.io
https://get.helm.sh
https://get.k3s.io
https://synthetics-coral-saas.instana.io
```

> Ajustar el endpoint Synthetic según la región del tenant Instana. En este ejemplo se usa `https://synthetics-coral-saas.instana.io`.

## 5. Validación inicial del servidor

Ejecutar:

```bash
whoami
id
sudo -v
hostnamectl
cat /etc/redhat-release
lscpu | egrep 'CPU\(s\)|Model name'
free -h
df -h
```

### Evidencia de referencia

```text
[root@vm-1 ~]# whoami
root

[root@vm-1 ~]# id
uid=0(root) gid=0(root) groups=0(root)
```

## 6. Validación de conectividad online

Ejecutar:

```bash
curl -I https://www.ibm.com
curl -I https://agents.instana.io
curl -I https://artifact-public.instana.io
curl -I https://get.helm.sh
curl -I https://get.k3s.io
curl -I https://synthetics-coral-saas.instana.io
```

### Resultado esperado

Se esperan respuestas HTTP válidas como `200`, `303`, `401`, `403` o `404`, dependiendo del endpoint.

Lo importante en esta etapa es confirmar que:

- El DNS resuelve.
- Existe conectividad TCP/443.
- El certificado TLS es aceptado.
- No hay bloqueo de red hacia los endpoints requeridos.

### Evidencia de referencia

```text
[root@vm-1 ~]# curl -I https://get.k3s.io
HTTP/2 200
content-type: text/plain;charset=UTF-8
server: cloudflare

[root@vm-1 ~]# curl -I https://synthetics-coral-saas.instana.io
HTTP/2 200
content-length: 0
strict-transport-security: max-age=63072000; includeSubDomains
```

## 7. Actualización del sistema operativo

Ejecutar:

```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf update -y
```

### Evidencia de referencia

```text
Complete!
```

## 8. Instalación de paquetes base

Ejecutar:

```bash
sudo dnf install -y \
  curl \
  wget \
  tar \
  gzip \
  jq \
  vim \
  git \
  openssl \
  ca-certificates \
  iproute-tc \
  bash-completion \
  yum-utils
```

### Evidencia de referencia

```text
Package curl is already installed.
Package jq is already installed.
Package openssl is already installed.
Complete!
```

## 9. Validación de fecha y hora

Ejecutar:

```bash
timedatectl
```

### Resultado esperado

El servidor debe tener sincronización horaria activa.

### Evidencia de referencia

```text
System clock synchronized: yes
NTP service: active
```

## 10. Deshabilitar swap

Kubernetes recomienda no utilizar swap para workloads productivos o controlados.

Ejecutar:

```bash
swapon --show
sudo swapoff -a
swapon --show
free -h
```

Si existe una entrada de swap en `/etc/fstab`, comentar la línea correspondiente para evitar que se active tras reinicio:

```bash
sudo cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d-%H%M%S)
sudo sed -i.bak '/swap/s/^/#/' /etc/fstab
```

### Evidencia de referencia

```text
Mem:            15Gi       3.2Gi       9.7Gi        44Mi       2.8Gi        12Gi
Swap:             0B          0B          0B
```

## 11. Configuración de módulos y sysctl para k3s

Ejecutar:

```bash
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<'EOF' | sudo tee /etc/modules-load.d/k3s.conf
overlay
br_netfilter
EOF

cat <<'EOF' | sudo tee /etc/sysctl.d/99-k3s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

sudo sysctl --system
```

Validar:

```bash
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
```

### Consideración importante

En algunos servidores con políticas de seguridad más restrictivas, otra configuración del sistema puede volver a desactivar el reenvío de tráfico IP. Por ello, después de aplicar los cambios, se debe validar que el valor final sea `net.ipv4.ip_forward=1`.

Validar siempre que el resultado final sea:

```text
net.ipv4.ip_forward = 1
```

Si queda en `0`, aplicar nuevamente:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

## 12. Consideración de firewall en RHEL 9

En Red Hat Enterprise Linux 9, `firewalld` puede bloquear la salida de los pods hacia DNS o Internet si no se habilita forwarding/masquerade para las redes internas de k3s.

El síntoma típico es que el host resuelve y llega a Internet, pero los pods no pueden resolver nombres externos.

### 12.1 Opción rápida para laboratorio: desactivar firewalld

Usar solo en ambientes de laboratorio, POC controlada o servidores aislados donde esté permitido por la política de seguridad.

```bash
sudo systemctl disable --now firewalld
```

Validar:

```bash
sudo systemctl status firewalld --no-pager
```

### 12.2 Opción recomendada: mantener firewalld y permitir salida de pods

Primero validar estado y zona activa:

```bash
sudo systemctl status firewalld --no-pager
sudo firewall-cmd --state
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all
```

Agregar puertos base usados por k3s:

```bash
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=8472/udp
sudo firewall-cmd --permanent --add-port=30000-32767/tcp
```

Permitir tráfico de las interfaces y redes internas de k3s:

```bash
sudo firewall-cmd --permanent --zone=trusted --add-interface=cni0
sudo firewall-cmd --permanent --zone=trusted --add-interface=flannel.1
sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
sudo firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
```

Habilitar masquerade en la zona de salida. En este ejemplo la zona activa es `public`:

```bash
sudo firewall-cmd --permanent --zone=public --add-masquerade
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

> Si la zona activa no es `public`, reemplazar `public` por la zona correspondiente.

### Evidencia de referencia del problema corregido

Antes de corregir firewall/DNS, CoreDNS intentaba consultar hacia DNS externos desde la red de pods `10.42.x.x` y fallaba:

```text
[ERROR] plugin/errors: 2 synthetics-coral-saas.instana.io. A: read udp 10.42.0.4:39191->10.10.10.1:53: i/o timeout
[ERROR] plugin/errors: 2 synthetics-coral-saas.instana.io. A: read udp 10.42.0.4:46460->172.31.0.10:53: read: no route to host
```

## 13. Instalación de k3s

Para este escenario se instala k3s sin Traefik, ya que el Synthetic PoP no requiere exponer un Ingress local para el despliegue base.

Ejecutar:

```bash
curl -sfL https://get.k3s.io | sudo sh -s - server \
  --disable traefik
```

Validar servicio:

```bash
sudo systemctl status k3s --no-pager
sudo journalctl -u k3s -n 100 --no-pager
```

Configurar acceso a `kubectl`:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
```

Validar clúster:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get storageclass
```

### Evidencia de referencia

```text
NAME   STATUS   ROLES           AGE   VERSION        INTERNAL-IP   OS-IMAGE                              CONTAINER-RUNTIME
vm-1   Ready    control-plane   80s   v1.35.5+k3s1   10.0.2.2      Red Hat Enterprise Linux 9.8 (Plow)   containerd://2.2.3-k3s1

NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE
kube-system   coredns-8db54c48d-dhd48                   1/1     Running   0          75s
kube-system   local-path-provisioner-5d9d9885bc-tx58q   1/1     Running   0          75s
kube-system   metrics-server-786d997795-sxvmz           1/1     Running   0          75s

NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false
```

## 14. Validación de DNS y salida desde pods

Antes de instalar Synthetic PoP, validar que los pods puedan resolver y salir por HTTPS.

Definir namespace de trabajo:

```bash
export POP_NAMESPACE="synthetic-pop"
kubectl create namespace "${POP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
```

Validar DNS desde un pod:

```bash
kubectl run dns-test \
  -n "${POP_NAMESPACE}" \
  --rm -it \
  --restart=Never \
  --image=busybox:1.36 \
  -- nslookup synthetics-coral-saas.instana.io
```

Validar HTTPS desde un pod:

```bash
kubectl run curl-test \
  -n "${POP_NAMESPACE}" \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl:8.10.1 \
  -- curl -vk https://synthetics-coral-saas.instana.io/synthetics/locations/
```

### Resultado esperado

- `nslookup` debe resolver el nombre.
- `curl` debe conectar por TLS.
- Un `HTTP/2 403` es aceptable en esta prueba, porque no se está enviando autenticación desde el pod de prueba.

### Troubleshooting DNS en CoreDNS

Si el host resuelve pero los pods no, revisar CoreDNS:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=200
kubectl get configmap coredns -n kube-system -o yaml
cat /etc/resolv.conf
nmcli dev show | grep -i dns
```

Si CoreDNS está reenviando a `/etc/resolv.conf` y uno de los DNS no es enrutable desde pods, se puede fijar temporalmente el DNS corporativo válido. Ejemplo:

```bash
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns.yaml
kubectl edit configmap coredns -n kube-system
```

Cambiar:

```text
forward . /etc/resolv.conf
```

por:

```text
forward . 10.10.10.1
```

Luego reiniciar CoreDNS:

```bash
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system
```

> Ajustar `10.10.10.1` al DNS real de la red del cliente.

## 15. Instalación de Helm

Ejecutar:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

Agregar repositorio Instana y validar chart:

```bash
helm repo add instana https://agents.instana.io/helm
helm repo update
helm search repo instana/synthetic-pop
```

### Evidencia de referencia

```text
helm installed into /usr/local/bin/helm

[root@vm-1 ~]# helm version
version.BuildInfo{Version:"v3.21.1", GitCommit:"c56dd0095fd76da5d7b30ecdf506103e7f26745e", GitTreeState:"clean", GoVersion:"go1.26.4"}

[root@vm-1 ~]# helm search repo instana/synthetic-pop
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
instana/synthetic-pop   1.2.47          1.320.1         Helm chart to install Instana Synthetic PoP
```

## 16. Obtener comando Helm desde Instana

El comando Helm debe obtenerse desde la página de Instana, en la sección de creación de una **Private Location / Synthetic PoP**.

La página de Instana genera un comando similar al siguiente:

```bash
helm install synthetic-pop \
  --repo "https://agents.instana.io/helm" \
  --namespace <namespace> \
  --create-namespace \
  --set downloadKey="<downloadKey>" \
  --set controller.location="<yourLocationName>;<yourLocationDisplayName>;<yourLocationCountry>;<yourLocationCity>;0;0;<yourLocationDescription>" \
  --set controller.clusterName="<yourClusterName>" \
  --set controller.instanaKey="<instanaKey>" \
  --set controller.instanaSyntheticEndpoint="<instanaSyntheticEndpoint>" \
  --set redis.tls.enabled=false \
  --set redis.password="<redisPassword>" \
  synthetic-pop
```

### Valores que se deben reemplazar

| Parámetro | Descripción | Ejemplo referencial |
|---|---|---|
| `<namespace>` | Namespace donde se instalará el PoP | `synthetic-pop` |
| `<downloadKey>` | Download key provista por Instana | No publicar en GitHub |
| `<yourLocationName>` | Nombre técnico de la ubicación | `K3SDemoPOP` |
| `<yourLocationDisplayName>` | Nombre visible en Instana | `K3S Demo POP` |
| `<yourLocationCountry>` | País de la ubicación | `Peru` |
| `<yourLocationCity>` | Ciudad de la ubicación | `Lima` |
| `<yourLocationDescription>` | Descripción de la ubicación | `PoP privado sobre k3s en RHEL 9` |
| `<yourClusterName>` | Nombre del clúster o servidor | `k3s-rhel9-demo` |
| `<instanaKey>` | Instana agent key / key provista por Instana para el PoP | No publicar en GitHub |
| `<instanaSyntheticEndpoint>` | Endpoint Synthetic SaaS según región | `https://synthetics-coral-saas.instana.io` |
| `<redisPassword>` | Password interno para Redis del PoP | Generar uno fuerte |

> **Importante:** no subir credenciales reales al repositorio. En documentación pública usar placeholders como `<downloadKey>`, `<instanaKey>` y `<redisPassword>`.

## 17. Despliegue de Synthetic PoP con Helm

Ejecutar el comando generado desde Instana, reemplazando los valores necesarios.

Ejemplo sanitizado:

```bash
helm install synthetic-pop \
  --repo "https://agents.instana.io/helm" \
  --namespace "synthetic-pop" \
  --create-namespace \
  --set downloadKey="<INSTANA_DOWNLOAD_KEY>" \
  --set controller.location="K3SDemoPOP;K3S Demo POP;Peru;Lima;0;0;PoP privado sobre k3s en RHEL 9" \
  --set controller.clusterName="k3s-rhel9-demo" \
  --set controller.instanaKey="<INSTANA_KEY>" \
  --set controller.instanaSyntheticEndpoint="https://synthetics-coral-saas.instana.io" \
  --set redis.tls.enabled=false \
  --set redis.password="<REDIS_PASSWORD>" \
  synthetic-pop
```

### Evidencia de referencia

```text
NAME: synthetic-pop
LAST DEPLOYED: Fri Jun 19 13:17:18 2026
NAMESPACE: synthetic-pop
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
CHART NAME: synthetic-pop
CHART VERSION: 1.2.47
APP VERSION: 1.320.1
```

## 18. Validación de Helm release

Ejecutar:

```bash
export POP_NAMESPACE="synthetic-pop"
export POP_RELEASE="synthetic-pop"

helm list -n "${POP_NAMESPACE}"
helm status "${POP_RELEASE}" -n "${POP_NAMESPACE}"
helm get values "${POP_RELEASE}" -n "${POP_NAMESPACE}"
```

### Evidencia de referencia

```text
NAME            NAMESPACE       REVISION        STATUS      CHART                   APP VERSION
synthetic-pop   synthetic-pop   1               deployed    synthetic-pop-1.2.47    1.320.1

NAME: synthetic-pop
NAMESPACE: synthetic-pop
STATUS: deployed
REVISION: 1
```

> Si se ejecuta `helm get values`, revisar y sanitizar la salida antes de compartirla, ya que puede mostrar claves o passwords.

## 19. Validación de recursos Kubernetes

Ejecutar:

```bash
kubectl get all -n "${POP_NAMESPACE}" -o wide
kubectl get pods -n "${POP_NAMESPACE}" -o wide
kubectl get events -n "${POP_NAMESPACE}" --sort-by=.lastTimestamp
```

Durante los primeros minutos es normal observar pods en `ContainerCreating`.

### Evidencia inicial de referencia

```text
NAME                                                               READY   STATUS              RESTARTS   AGE
pod/synthetic-pop-browserscript-playback-engine-69cc94b754-429vj   0/1     ContainerCreating   0          37s
pod/synthetic-pop-controller-5d868cc999-g7qbk                      0/1     ContainerCreating   0          37s
pod/synthetic-pop-http-playback-engine-689b9f45c6-8drtk            0/1     ContainerCreating   0          37s
pod/synthetic-pop-ism-playback-engine-674d74548-vdg9d              0/1     ContainerCreating   0          37s
pod/synthetic-pop-javascript-playback-engine-5697fc7c49-nshqk      0/1     ContainerCreating   0          37s
pod/synthetic-pop-redis-79c49c7d44-phxcp                           0/1     ContainerCreating   0          37s
```

## 20. Validación final del PoP

Ejecutar:

```bash
kubectl get nodes
kubectl get pods -A
```

### Resultado esperado

Todos los pods del namespace `synthetic-pop` deben quedar en `1/1 Running`.

### Evidencia final de referencia

```text
NAME   STATUS   ROLES           AGE   VERSION
vm-1   Ready    control-plane   27m   v1.35.5+k3s1

NAMESPACE       NAME                                                           READY   STATUS    RESTARTS      AGE
kube-system     coredns-54f5f4c755-dxp4w                                       1/1     Running   0             86s
kube-system     local-path-provisioner-5d9d9885bc-tx58q                        1/1     Running   0             27m
kube-system     metrics-server-786d997795-sxvmz                                1/1     Running   0             27m
synthetic-pop   synthetic-pop-browserscript-playback-engine-69cc94b754-429vj   1/1     Running   0             18m
synthetic-pop   synthetic-pop-controller-5d868cc999-g7qbk                      1/1     Running   0             18m
synthetic-pop   synthetic-pop-http-playback-engine-689b9f45c6-8drtk            1/1     Running   0             18m
synthetic-pop   synthetic-pop-ism-playback-engine-674d74548-vdg9d              1/1     Running   4 (17m ago)   18m
synthetic-pop   synthetic-pop-javascript-playback-engine-5697fc7c49-nshqk      1/1     Running   0             18m
synthetic-pop   synthetic-pop-redis-79c49c7d44-phxcp                           1/1     Running   0             18m
```

## 21. Validación de consumo

Ejecutar:

```bash
kubectl top node
kubectl top pods -n "${POP_NAMESPACE}"
```

### Evidencia de referencia

```text
NAME   CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
vm-1   138m         3%       3917Mi          24%

NAME                                                           CPU(cores)   MEMORY(bytes)
synthetic-pop-browserscript-playback-engine-69cc94b754-429vj   6m           142Mi
synthetic-pop-controller-5d868cc999-g7qbk                      7m           107Mi
synthetic-pop-http-playback-engine-689b9f45c6-8drtk            6m           72Mi
synthetic-pop-ism-playback-engine-674d74548-vdg9d              1m           28Mi
synthetic-pop-javascript-playback-engine-5697fc7c49-nshqk      5m           68Mi
synthetic-pop-redis-79c49c7d44-phxcp                           7m           3Mi
```

> Esta evidencia corresponde a una etapa inicial sin carga real de pruebas. El consumo aumentará cuando se programen ejecuciones, especialmente con Browser tests.

## 22. Validación de logs

Ejecutar:

```bash
kubectl logs -n "${POP_NAMESPACE}" \
  -l app.kubernetes.io/instance="${POP_RELEASE}" \
  --all-containers=true \
  --tail=300
```

Buscar mensajes de arranque de los playback engines y conexión a Redis.

### Evidencia de referencia: HTTP playback engine

```text
Playback engine container starting ....
Synthetic Javascript Playback Engine Version: 1.319.2
[index.js] [Cluster] Playback runner running on host: 0.0.0.0, port: 8080
[executor.js] [Executor][run] playback mode is:http
redis use password to connect
[Executor][restart] playback engine http starting, all redis connection ready, start execute tasks.
[Executor][restart] playback engine http started, {"ready":true,"msg":"Playback engine is ready"}
```

### Evidencia de referencia: Browser playback engine

```text
Redis host: synthetic-pop-redis
Redis port: 6378
No TLS requirements. Use password authentication in redis client.
Parse redis password from file.
Connected to redis host: synthetic-pop-redis. Use connection pool: true
Jetty started on port 8080 (http/1.1) with context path '/'
Started ExecutorEngineApplication
```

## 23. Troubleshooting: el host resuelve DNS, pero los pods no

### Síntoma

El host resuelve correctamente:

```bash
nslookup synthetics-coral-saas.instana.io
curl -vk https://synthetics-coral-saas.instana.io/synthetics/locations/
```

pero desde un pod falla:

```text
;; connection timed out; no servers could be reached
curl: (6) Could not resolve host: synthetics-coral-saas.instana.io
```

### Evidencia de referencia

```text
Server:         10.43.0.10
Address:        10.43.0.10:53

;; connection timed out; no servers could be reached

curl: (6) Could not resolve host: synthetics-coral-saas.instana.io
```

### Causa probable

`firewalld`, forwarding o masquerade impiden que la red de pods `10.42.0.0/16` salga hacia los DNS configurados en el host.

### Corrección

Aplicar las reglas indicadas en la sección **12.2** o, para laboratorio, desactivar temporalmente `firewalld` según la sección **12.1**.

Luego reiniciar CoreDNS y validar nuevamente:

```bash
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system

kubectl run dns-test \
  -n "${POP_NAMESPACE}" \
  --rm -it \
  --restart=Never \
  --image=busybox:1.36 \
  -- nslookup synthetics-coral-saas.instana.io

kubectl run curl-test \
  -n "${POP_NAMESPACE}" \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl:8.10.1 \
  -- curl -vk https://synthetics-coral-saas.instana.io/synthetics/locations/
```

## 24. Troubleshooting: `Register Location Failed`

### Síntoma

El controller del Synthetic PoP no logra registrar la ubicación privada:

```text
Register Location Failed
UnknownHostException: synthetics-coral-saas.instana.io
Name or service not known
```

### Evidencia de referencia

```text
LocationRegister:createUpdateLocation - registerLocation to: https://synthetics-coral-saas.instana.io/synthetics/locations/
Request to https://synthetics-coral-saas.instana.io/synthetics/locations/ failed with IOException: synthetics-coral-saas.instana.io: Name or service not known
Register Location Failed
Caused by: java.net.UnknownHostException: synthetics-coral-saas.instana.io
```

### Interpretación

Este error no necesariamente indica problema de credenciales. En el caso validado, el problema era que los pods no podían resolver DNS externo.

### Acciones

1. Validar DNS desde el host.
2. Validar DNS desde pod.
3. Revisar CoreDNS.
4. Revisar `firewalld`.
5. Corregir salida de pods.
6. Reiniciar CoreDNS.
7. Reiniciar deployments del PoP.

```bash
kubectl rollout restart deployment -n "${POP_NAMESPACE}" \
  -l app.kubernetes.io/instance="${POP_RELEASE}"

kubectl get pods -n "${POP_NAMESPACE}"
```

## 25. Captura de evidencias

Ejecutar al finalizar la instalación:

```bash
export POP_NAMESPACE="synthetic-pop"
export POP_RELEASE="synthetic-pop"
export EVIDENCE_DIR="$HOME/instana-synthetic-pop-evidencias-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${EVIDENCE_DIR}"

{
  echo "### Fecha"
  date
  echo
  echo "### Sistema operativo"
  cat /etc/redhat-release || true
  hostnamectl || true
  echo
  echo "### Recursos"
  lscpu || true
  free -h || true
  df -h || true
  echo
  echo "### k3s"
  k3s --version || true
  systemctl status k3s --no-pager || true
  echo
  echo "### Helm"
  helm version || true
  helm list -n "${POP_NAMESPACE}" || true
  helm status "${POP_RELEASE}" -n "${POP_NAMESPACE}" || true
  echo
  echo "### Kubernetes"
  kubectl get nodes -o wide || true
  kubectl get pods -A -o wide || true
  kubectl get svc -A || true
  kubectl get storageclass || true
  echo
  echo "### Synthetic PoP"
  kubectl get all -n "${POP_NAMESPACE}" -o wide || true
  kubectl get events -n "${POP_NAMESPACE}" --sort-by=.lastTimestamp || true
  echo
  echo "### Consumo"
  kubectl top node || true
  kubectl top pods -n "${POP_NAMESPACE}" || true
  echo
  echo "### CoreDNS"
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide || true
  kubectl logs -n kube-system -l k8s-app=kube-dns --tail=200 || true
  kubectl get configmap coredns -n kube-system -o yaml || true
  echo
  echo "### Logs Synthetic PoP"
  kubectl logs -n "${POP_NAMESPACE}" -l app.kubernetes.io/instance="${POP_RELEASE}" --all-containers=true --tail=500 || true
} | tee "${EVIDENCE_DIR}/evidencia-general.log"

tar -czf "${EVIDENCE_DIR}.tar.gz" -C "$(dirname "${EVIDENCE_DIR}")" "$(basename "${EVIDENCE_DIR}")"
echo "Evidencias generadas en: ${EVIDENCE_DIR}.tar.gz"
```

> Antes de compartir evidencias, revisar y sanitizar cualquier credencial visible en salidas de Helm, variables o logs.

## 26. Recomendaciones operativas

- No publicar `downloadKey`, `controller.instanaKey` ni `redis.password` en GitHub.
- Validar DNS desde pods antes de desplegar el PoP.
- Para RHEL 9, revisar `firewalld` desde el inicio.
- Para POC con 4 vCPU / 16 GB, iniciar con pocos Browser tests.
- Monitorear CPU y memoria con `kubectl top`.
- Validar que el PoP aparezca en Instana como Private Location antes de crear pruebas masivas.
- Si se agregan más pruebas Browser, validar consumo y tiempos de ejecución.

## 27. Limpieza del despliegue

Si se requiere eliminar el Synthetic PoP:

```bash
helm uninstall synthetic-pop -n synthetic-pop
kubectl delete namespace synthetic-pop
```

Si se requiere eliminar k3s completamente:

```bash
/usr/local/bin/k3s-uninstall.sh
```

## 28. Referencias

- IBM Instana Synthetic Monitoring - Private PoP / Self-hosted PoP.
- Helm chart oficial: `https://agents.instana.io/helm`.
- k3s: `https://get.k3s.io`.
