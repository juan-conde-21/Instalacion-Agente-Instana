# Despliegue air-gapped de IBM Instana Synthetic Private PoP sobre RHEL 9 + k3s + Helm

## 1. Objetivo

Documentar el procedimiento para instalar **IBM Instana Synthetic Private PoP** sobre **Red Hat Enterprise Linux 9** en modalidad **air-gapped de instalación**, utilizando **k3s single-node** y **Helm chart local**, sin utilizar `popctl`.

El procedimiento está redactado como una instalación nueva. Las evidencias de ejecución se colocan dentro de cada paso para que el manual pueda seguirse de forma secuencial.

---

## 2. Alcance

Este procedimiento cubre:

- Preparación del bundle air-gapped en una VM con salida a Internet.
- Descarga de k3s, Helm, chart `synthetic-pop` e imágenes requeridas.
- Exportación correcta de múltiples imágenes con Podman.
- Instalación offline de k3s en RHEL 9.
- Importación de imágenes en `containerd` de k3s.
- Despliegue del Synthetic Private PoP con Helm local.
- Validaciones post-instalación.

No cubre:

- Despliegue con `popctl`.
- Instalación de registry privado local.
- Instalación de Instana backend self-hosted.
- Configuración funcional de pruebas Synthetic desde la UI de Instana.

---

## 3. Consideraciones importantes antes de iniciar

### 3.1 Air-gapped de instalación vs. air-gapped operativo

En este procedimiento, **air-gapped** significa que el servidor destino no descarga binarios, charts ni imágenes desde Internet. Todo se prepara previamente en una VM con Internet y luego se transfiere al servidor aislado.

Para operar contra **Instana SaaS**, el servidor o los pods deben poder alcanzar el endpoint Synthetic correspondiente, por ejemplo:

```text
https://synthetics-coral-saas.instana.io
```

Si el servidor no tiene salida hacia Instana SaaS, se debe usar un endpoint Instana self-hosted/on-premises accesible desde la red interna.

### 3.2 Consideraciones incorporadas al procedimiento

Este manual ya incorpora las correcciones necesarias para evitar los siguientes problemas:

- `AIRGAP_DIR` apuntando a `/root` y generando rutas inválidas como `/root/manifests`.
- Archive de imágenes mal generado con Podman, donde varias imágenes quedan apuntando al mismo digest.
- Redis 8.x fallando por `loglevel "INFO"`, `loglevel "NOTICE"` o `loglevel ""`.
- Helm usando un kubeconfig incorrecto y fallando con `x509: certificate signed by unknown authority`.
- Falta de forwarding/masquerade para tráfico de pods en RHEL 9 con `firewalld`.

### 3.3 Seguridad de credenciales

No registrar claves reales en repositorios, capturas o evidencias. En este documento se utilizan placeholders:

```text
<INSTANA_DOWNLOAD_KEY>
<INSTANA_KEY>
<REDIS_PASSWORD_MIN_10_CHARS>
<INSTANA_SYNTHETIC_ENDPOINT>
```

---

## 4. Arquitectura de referencia

```text
+--------------------------------------+        +--------------------------------------+
| VM con salida a Internet             |        | Servidor RHEL 9 air-gapped           |
|--------------------------------------|        |--------------------------------------|
| Descarga k3s                         |        | Instala k3s offline                  |
| Descarga imágenes airgap de k3s      |        | Instala Helm offline                 |
| Descarga Helm                        |        | Importa imágenes a containerd        |
| Descarga chart synthetic-pop         |  --->  | Ejecuta Helm install con chart local |
| Descarga imágenes del PoP            |        | Valida pods Synthetic                |
| Genera bundle .tar.gz                |        |                                      |
+--------------------------------------+        +--------------------------------------+
```

---

## 5. Requisitos

### 5.1 VM con Internet

| Recurso | Valor recomendado |
|---|---:|
| Sistema operativo | RHEL 9, Rocky 9, AlmaLinux 9 o compatible |
| CPU | 2 vCPU o más |
| RAM | 4 GB o más |
| Disco libre | 20 GB o más |
| Herramientas | `curl`, `tar`, `jq`, `podman`, `helm` |
| Acceso requerido | GitHub, get.helm.sh, agents.instana.io, containers.instana.io |

### 5.2 Servidor RHEL 9 air-gapped

| Recurso | Valor recomendado |
|---|---:|
| Sistema operativo | Red Hat Enterprise Linux 9.x |
| CPU | 4 vCPU mínimo para POC controlado |
| RAM | 16 GB recomendado |
| Disco libre | 80 GB a 100 GB |
| Kubernetes | k3s single-node |
| Runtime | containerd incluido con k3s |
| Usuario | root o usuario con sudo |

> Para un servidor de **4 vCPU / 16 GB**, iniciar con baja concurrencia: `browserscript.maxConcurrentTests=1` y `javascript.maxConcurrentTests=2`. No comprometer 5 pruebas Browser concurrentes sin ampliar recursos.

---

# Parte A. Preparación del bundle en la VM con Internet

## 6. Crear estructura del bundle

Ejecutar desde una sesión limpia en la VM con salida a Internet:

```bash
cd ~
rm -rf instana-pop-airgap-bundle \
       instana-pop-airgap-bundle-rhel9-helm.tar.gz \
       instana-pop-airgap-bundle-rhel9-helm.sha256

mkdir -p ~/instana-pop-airgap-bundle/{bin,k3s,helm,charts,images,rpms,manifests,values}
cd ~/instana-pop-airgap-bundle

export AIRGAP_DIR="$PWD"
export K3S_VERSION="v1.35.5+k3s1"
export K3S_VERSION_URL="v1.35.5%2Bk3s1"
export HELM_VERSION="v3.21.1"
export POP_CHART_VERSION="1.2.47"
export POP_NAMESPACE="synthetic-pop"
export POP_RELEASE="synthetic-pop"
export INSTANA_DOWNLOAD_KEY="<INSTANA_DOWNLOAD_KEY>"
```

Validar que `AIRGAP_DIR` apunta al directorio correcto:

```bash
echo "$AIRGAP_DIR"
ls -ld "$AIRGAP_DIR" "$AIRGAP_DIR/manifests" "$AIRGAP_DIR/images" "$AIRGAP_DIR/values"
```

**Evidencia de ejecución:**

```text
[root@vm-1 ~]# mkdir -p ~/instana-pop-airgap-bundle/{bin,k3s,helm,charts,images,rpms,manifests,values}
cd ~/instana-pop-airgap-bundle
[root@vm-1 instana-pop-airgap-bundle]# export AIRGAP_DIR="$PWD"
export K3S_VERSION="v1.35.5+k3s1"
export K3S_VERSION_URL="v1.35.5%2Bk3s1"
export HELM_VERSION="v3.21.1"
export POP_CHART_VERSION="1.2.47"
export POP_NAMESPACE="synthetic-pop"
export POP_RELEASE="synthetic-pop"
export INSTANA_DOWNLOAD_KEY="<INSTANA_DOWNLOAD_KEY>"
```

**Control preventivo:** no continuar si `AIRGAP_DIR` está vacío o apunta a `/root`. Cuando no se define correctamente, se observan errores como estos:

```text
-bash: /root/manifests/rendered-synthetic-pop.yaml: No such file or directory
-bash: /root/images/images-pop.txt: No such file or directory
grep: /root/manifests/rendered-synthetic-pop.yaml: No such file or directory
cat: /root/images/images-pop.txt: No such file or directory
```

---

## 7. Descargar k3s y sus imágenes airgap

```bash
cd "$AIRGAP_DIR/k3s"

curl -L -o k3s \
  "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION_URL}/k3s"

curl -L -o k3s-airgap-images-amd64.tar.zst \
  "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION_URL}/k3s-airgap-images-amd64.tar.zst"

curl -L -o install.sh https://get.k3s.io

chmod +x k3s install.sh
```

Validar los archivos descargados:

```bash
ls -lh "$AIRGAP_DIR/k3s"
sha256sum "$AIRGAP_DIR/k3s"/* > "$AIRGAP_DIR/k3s/SHA256SUMS-k3s.txt"
```

**Evidencia de ejecución:**

```text
100 74.0M  100 74.0M    0     0   168M
100  232M  100  232M    0     0   109M
100 38305  100 38305    0     0   445k

[root@vm-1 k3s]# ls -lh "$AIRGAP_DIR/k3s"
total 307M
-rwx------ 1 root root  38K Jun 19 20:45 install.sh
-rwx------ 1 root root  75M Jun 19 20:45 k3s
-rw------- 1 root root 233M Jun 19 20:45 k3s-airgap-images-amd64.tar.zst
```

---

## 8. Descargar RPM de k3s-selinux para RHEL 9

```bash
cd "$AIRGAP_DIR/rpms"

curl -L -O \
  https://github.com/k3s-io/k3s-selinux/releases/download/v1.6.stable.1/k3s-selinux-1.6-1.el9.noarch.rpm

sha256sum ./*.rpm > SHA256SUMS-rpms.txt
```

**Evidencia de ejecución:**

```text
100 22123  100 22123    0     0  79579
```

---

## 9. Descargar Helm

```bash
cd "$AIRGAP_DIR/helm"

curl -L -o "helm-${HELM_VERSION}-linux-amd64.tar.gz" \
  "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"

sha256sum "helm-${HELM_VERSION}-linux-amd64.tar.gz" > SHA256SUMS-helm.txt
```

Instalar Helm temporalmente en la VM con Internet para descargar el chart:

```bash
tar -xzf "$AIRGAP_DIR/helm/helm-${HELM_VERSION}-linux-amd64.tar.gz" -C /tmp
sudo cp /tmp/linux-amd64/helm /usr/local/bin/helm
helm version
```

**Evidencia de ejecución:**

```text
100 16.9M  100 16.9M    0     0  44.2M

[root@vm-1 helm]# helm version
version.BuildInfo{Version:"v3.21.1", GitCommit:"c56dd0095fd76da5d7b30ecdf506103e7f26745e", GitTreeState:"clean", GoVersion:"go1.26.4"}
```

---

## 10. Descargar Helm chart `synthetic-pop`

```bash
helm repo add instana https://agents.instana.io/helm
helm repo update

helm search repo instana/synthetic-pop --versions | head

helm pull instana/synthetic-pop \
  --version "${POP_CHART_VERSION}" \
  --destination "$AIRGAP_DIR/charts"

helm show values "$AIRGAP_DIR/charts/synthetic-pop-${POP_CHART_VERSION}.tgz" \
  > "$AIRGAP_DIR/charts/values-default-synthetic-pop-${POP_CHART_VERSION}.yaml"
```

Validar:

```bash
ls -lh "$AIRGAP_DIR/charts"
sha256sum "$AIRGAP_DIR/charts/synthetic-pop-${POP_CHART_VERSION}.tgz" \
  > "$AIRGAP_DIR/charts/SHA256SUMS-chart.txt"
```

**Evidencia de ejecución:**

```text
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
instana/synthetic-pop   1.2.47          1.320.1         Helm chart to install Instana Synthetic PoP
instana/synthetic-pop   1.2.46          1.320.0         Helm chart to install Instana Synthetic PoP
instana/synthetic-pop   1.2.45          1.319.1         Helm chart to install Instana Synthetic PoP

[root@vm-1 helm]# ls -lh "$AIRGAP_DIR/charts"
total 36K
-rw-r--r-- 1 root root 14K Jun 19 22:07 synthetic-pop-1.2.47.tgz
-rw------- 1 root root 17K Jun 19 22:07 values-default-synthetic-pop-1.2.47.yaml
```

---

## 11. Renderizar el manifest temporal y extraer las imágenes

El manifest temporal se usa únicamente para identificar las imágenes requeridas por el chart local.

> En esta etapa se incluye `ism.enabled=true` para descargar también la imagen de ISM. Luego, en el despliegue inicial, ISM puede quedar deshabilitado si no se ejecutarán pruebas DNS o SSL Certificate.

```bash
cd "$AIRGAP_DIR"

helm template "${POP_RELEASE}" "$AIRGAP_DIR/charts/synthetic-pop-${POP_CHART_VERSION}.tgz" \
  --namespace "${POP_NAMESPACE}" \
  --set downloadKey="${INSTANA_DOWNLOAD_KEY}" \
  --set controller.location="pop-airgap;PoP Airgap;Peru;Lima;0;0;PoP airgap RHEL9" \
  --set controller.clusterName="k3s-airgap-rhel9" \
  --set controller.instanaKey="dummy-instana-key" \
  --set controller.instanaSyntheticEndpoint="https://synthetics-coral-saas.instana.io" \
  --set redis.tls.enabled=false \
  --set redis.password="ChangeMe12345" \
  --set redis.traceLevel="notice" \
  --set controller.image.pullPolicy="IfNotPresent" \
  --set http.image.pullPolicy="IfNotPresent" \
  --set javascript.image.pullPolicy="IfNotPresent" \
  --set browserscript.image.pullPolicy="IfNotPresent" \
  --set ism.enabled=true \
  --set ism.image.pullPolicy="IfNotPresent" \
  --set redis.image.pullPolicy="IfNotPresent" \
  > "$AIRGAP_DIR/manifests/rendered-synthetic-pop.yaml"
```

Extraer imágenes:

```bash
grep -E 'image: ' "$AIRGAP_DIR/manifests/rendered-synthetic-pop.yaml" \
  | awk '{print $2}' \
  | tr -d '"' \
  | sort -u \
  > "$AIRGAP_DIR/images/images-pop.txt"

cat "$AIRGAP_DIR/images/images-pop.txt"
```

**Evidencia de ejecución:**

```text
containers.instana.io/synthetic/redis:1.319.1
containers.instana.io/synthetic/synthetic-playback-browserscript:1.320.1
containers.instana.io/synthetic/synthetic-playback-http:1.319.2
containers.instana.io/synthetic/synthetic-playback-ism:1.319.3
containers.instana.io/synthetic/synthetic-playback-javascript:1.319.2
containers.instana.io/synthetic/synthetic-pop-controller:1.319.1
```

---

## 12. Descargar imágenes desde `containers.instana.io`

Instalar o validar Podman:

```bash
sudo dnf install -y podman
```

Autenticarse contra el registry de Instana:

```bash
podman login containers.instana.io \
  -u _ \
  -p "${INSTANA_DOWNLOAD_KEY}"
```

Descargar imágenes:

```bash
while read -r IMAGE; do
  echo "Pulling ${IMAGE}"
  podman pull "${IMAGE}"
done < "$AIRGAP_DIR/images/images-pop.txt"
```

**Evidencia de ejecución:**

```text
Package podman-6:5.8.2-3.el9_8.x86_64 is already installed.
Complete!

[root@vm-1 instana-pop-airgap-bundle]# podman login containers.instana.io \
  -u _ \
  -p "${INSTANA_DOWNLOAD_KEY}"
Login Succeeded!

Pulling containers.instana.io/synthetic/redis:1.319.1
Writing manifest to image destination
a394cc2b31a3e711420df6c4bbe7946fb6af85428f920610195e017160cf4801

Pulling containers.instana.io/synthetic/synthetic-playback-browserscript:1.320.1
Writing manifest to image destination
8c2b1c38fc9fe73e82ba4bd6ddb6a694eb8e1bb15d231429b5a301878610f7ab

Pulling containers.instana.io/synthetic/synthetic-playback-http:1.319.2
Writing manifest to image destination
2e39dcdf29127c3d8929e3ed983c43c148ee0e1cc4af5cd2d8a5d4ec14b7c1c1

Pulling containers.instana.io/synthetic/synthetic-playback-ism:1.319.3
Writing manifest to image destination
84b9b0f2fbc3d3631f98b2eaf58f20e816f263b6c9ae24ec216422e2d156bc51

Pulling containers.instana.io/synthetic/synthetic-pop-controller:1.319.1
Writing manifest to image destination
4b7450e9d18fe0026a4fd9413c27ce781afd5a25deb62e4a2e8c1fa28cb3e532
```

---

## 13. Exportar imágenes correctamente con Podman

Este paso es crítico.

Se debe utilizar `--multi-image-archive` para conservar varias imágenes reales dentro del mismo archivo `.tar`.

```bash
podman save \
  --multi-image-archive \
  -o "$AIRGAP_DIR/images/instana-synthetic-pop-images.tar" \
  $(cat "$AIRGAP_DIR/images/images-pop.txt")
```

Validar el archive generado:

```bash
tar -xOf "$AIRGAP_DIR/images/instana-synthetic-pop-images.tar" manifest.json \
  | jq -r '.[] | "\(.RepoTags | join(",")) -> \(.Config)"'
```

**Evidencia de ejecución:**

```text
Copying config a394cc2b31 done
Writing manifest to image destination
Copying config 8c2b1c38fc done
Writing manifest to image destination
Copying config 2e39dcdf29 done
Writing manifest to image destination
Copying config 84b9b0f2fb done
Writing manifest to image destination
Copying config 4b7450e9d1 done
Writing manifest to image destination

containers.instana.io/synthetic/redis:1.319.1 -> a394cc2b31a3e711420df6c4bbe7946fb6af85428f920610195e017160cf4801.json
containers.instana.io/synthetic/synthetic-playback-browserscript:1.320.1 -> 8c2b1c38fc9fe73e82ba4bd6ddb6a694eb8e1bb15d231429b5a301878610f7ab.json
containers.instana.io/synthetic/synthetic-playback-http:1.319.2,containers.instana.io/synthetic/synthetic-playback-javascript:1.319.2 -> 2e39dcdf29127c3d8929e3ed983c43c148ee0e1cc4af5cd2d8a5d4ec14b7c1c1.json
containers.instana.io/synthetic/synthetic-playback-ism:1.319.3 -> 84b9b0f2fbc3d3631f98b2eaf58f20e816f263b6c9ae24ec216422e2d156bc51.json
containers.instana.io/synthetic/synthetic-pop-controller:1.319.1 -> 4b7450e9d18fe0026a4fd9413c27ce781afd5a25deb62e4a2e8c1fa28cb3e532.json
```

Validar repositorios y tags:

```bash
tar -xOf "$AIRGAP_DIR/images/instana-synthetic-pop-images.tar" repositories | jq .
```

**Evidencia de ejecución:**

```text
{
  "containers.instana.io/synthetic/redis": {
    "1.319.1": "1906ab40f480b31bb534dcb16e17a047c18e42d3d7d3146af55a1b7668591056"
  },
  "containers.instana.io/synthetic/synthetic-playback-browserscript": {
    "1.320.1": "8f543d9a0df1d8a279a1e32323c9074f7a6481b899b3a003f718cbb7c6b74aee"
  },
  "containers.instana.io/synthetic/synthetic-playback-http": {
    "1.319.2": "e0d51fa95b01d5bfbf2461559bf3160660f754fb21d27c35d127a6f81ea3c77c"
  },
  "containers.instana.io/synthetic/synthetic-playback-ism": {
    "1.319.3": "b483b21dbd955f45827e3064206371ac5313b41091ce15ee4eb340bfe5eff05f"
  },
  "containers.instana.io/synthetic/synthetic-playback-javascript": {
    "1.319.2": "e0d51fa95b01d5bfbf2461559bf3160660f754fb21d27c35d127a6f81ea3c77c"
  },
  "containers.instana.io/synthetic/synthetic-pop-controller": {
    "1.319.1": "80187b9e35c11e8941c5964e1c344f56cc54d7d0605573f852a881743516bfc8"
  }
}
```

Validación obligatoria:

```bash
CONFIG_COUNT=$(tar -xOf "$AIRGAP_DIR/images/instana-synthetic-pop-images.tar" manifest.json \
  | jq -r '.[].Config' \
  | sort -u \
  | wc -l)

echo "Cantidad de configs únicos: ${CONFIG_COUNT}"

if [ "${CONFIG_COUNT}" -lt 4 ]; then
  echo "ERROR: el archive de imágenes no conserva múltiples imágenes reales. Regenerar usando podman save --multi-image-archive."
  exit 1
fi
```

> Es aceptable que `synthetic-playback-http` y `synthetic-playback-javascript` compartan el mismo `Config`. Lo que no debe ocurrir es que Redis, Controller, BrowserScript y todos los motores apunten al mismo `Config`.

Validar tamaño y checksum:

```bash
ls -lh "$AIRGAP_DIR/images/instana-synthetic-pop-images.tar"
sha256sum "$AIRGAP_DIR/images/instana-synthetic-pop-images.tar" \
  > "$AIRGAP_DIR/images/SHA256SUMS-instana-images.txt"
```

**Evidencia de ejecución:**

```text
-rw-r--r-- 1 root root 5.5G Jun 19 22:10 /root/instana-pop-airgap-bundle/images/instana-synthetic-pop-images.tar
```

---

## 14. Crear `values-airgap-template.yaml`

Crear el archivo base de valores:

```bash
cat > "$AIRGAP_DIR/values/values-airgap-template.yaml" <<'EOF_VALUES'
# Valores base para IBM Instana Synthetic Private PoP en k3s air-gapped sin popctl.
# Reemplazar los placeholders antes de ejecutar helm install.

downloadKey: "<INSTANA_DOWNLOAD_KEY>"

controller:
  location: "<LOCATION_LABEL>;<LOCATION_DISPLAY_NAME>;<COUNTRY>;<CITY>;0;0;<DESCRIPTION>"
  clusterName: "<CLUSTER_NAME>"
  instanaKey: "<INSTANA_KEY>"
  instanaSyntheticEndpoint: "<INSTANA_SYNTHETIC_ENDPOINT>"
  image:
    pullPolicy: IfNotPresent
  resources:
    requests:
      cpu: 100m
      memory: 200Mi
    limits:
      cpu: 300m
      memory: 300Mi

redis:
  tls:
    enabled: false
  password: "<REDIS_PASSWORD_MIN_10_CHARS>"
  # Redis 8.x espera valores de loglevel en minúscula.
  traceLevel: "notice"
  image:
    pullPolicy: IfNotPresent
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
    limits:
      cpu: 300m
      memory: 200Mi

http:
  enabled: true
  replicas: 1
  image:
    pullPolicy: IfNotPresent
  resources:
    requests:
      cpu: 150m
      memory: 200Mi
    limits:
      cpu: 300m
      memory: 500Mi

javascript:
  enabled: true
  replicas: 1
  maxConcurrentTests: 2
  image:
    pullPolicy: IfNotPresent
  resources:
    requests:
      cpu: 300m
      memory: 200Mi
    limits:
      cpu: 700m
      memory: 500Mi

browserscript:
  enabled: true
  replicas: 1
  maxConcurrentTests: 1
  image:
    pullPolicy: IfNotPresent
  resources:
    requests:
      cpu: 1200m
      memory: 2Gi
    limits:
      cpu: 2500m
      memory: 3Gi

ism:
  enabled: false
  image:
    pullPolicy: IfNotPresent

networkPolicyEnabled: true
EOF_VALUES
```

Validar el bloque de Redis:

```bash
grep -n -A20 '^redis:' "$AIRGAP_DIR/values/values-airgap-template.yaml"
```

**Evidencia esperada:**

```yaml
redis:
  tls:
    enabled: false
  password: "<REDIS_PASSWORD_MIN_10_CHARS>"
  traceLevel: "notice"
  image:
    pullPolicy: IfNotPresent
```

---

## 15. Empaquetar el bundle air-gapped

```bash
cd ~
tar -czf instana-pop-airgap-bundle-rhel9-helm.tar.gz instana-pop-airgap-bundle
ls -lh instana-pop-airgap-bundle-rhel9-helm.tar.gz
sha256sum instana-pop-airgap-bundle-rhel9-helm.tar.gz > instana-pop-airgap-bundle-rhel9-helm.sha256
```

Transferir ambos archivos al servidor air-gapped:

```bash
scp instana-pop-airgap-bundle-rhel9-helm.tar.gz root@<SERVER_AIRGAP>:/opt/
scp instana-pop-airgap-bundle-rhel9-helm.sha256 root@<SERVER_AIRGAP>:/opt/
```

---

# Parte B. Instalación en el servidor RHEL 9 air-gapped

## 16. Validar y descomprimir bundle

```bash
cd /opt
sha256sum -c instana-pop-airgap-bundle-rhel9-helm.sha256

tar -xzf instana-pop-airgap-bundle-rhel9-helm.tar.gz
cd /opt/instana-pop-airgap-bundle
```

**Evidencia de ejecución:**

```text
[root@podman-server opt]# cd /opt
sha256sum -c instana-pop-airgap-bundle-rhel9-helm.sha256

tar -xzf instana-pop-airgap-bundle-rhel9-helm.tar.gz
cd /opt/instana-pop-airgap-bundle
instana-pop-airgap-bundle-rhel9-helm.tar.gz: OK
```

---

## 17. Validar recursos del servidor

```bash
whoami
id
hostnamectl
cat /etc/redhat-release
lscpu | egrep 'CPU\(s\)|Model name'
free -h
df -h
```

**Evidencia de ejecución:**

```text
root
uid=0(root) gid=0(root) groups=0(root)
Static hostname: podman-server
Operating System: Red Hat Enterprise Linux 9.2 (Plow)
Kernel: Linux 5.14.0-284.11.1.el9_2.x86_64
Architecture: x86-64
Red Hat Enterprise Linux release 9.2 (Plow)
CPU(s):                          4
Model name:                      AMD Ryzen 7 5800H with Radeon Graphics
Mem:            13Gi       1.9Gi       9.4Gi        22Mi       2.7Gi        11Gi
/dev/mapper/rhel-root   96G   28G   69G  29% /
```

---

## 18. Instalar `k3s-selinux`

```bash
cd /opt/instana-pop-airgap-bundle/rpms
sudo dnf install -y ./k3s-selinux-*.rpm
```

**Evidencia de ejecución:**

```text
Installed:
  k3s-selinux-1.6-1.el9.noarch

Complete!
```

> Si el sistema no está registrado contra Red Hat Subscription Management pero permite instalar el RPM local, el mensaje de suscripción puede ser informativo. Lo importante es que el paquete quede instalado correctamente.

---

## 19. Deshabilitar swap

```bash
swapon --show
sudo swapoff -a
swapon --show
```

**Evidencia de ejecución:**

```text
[root@podman-server rpms]# swapon --show
NAME      TYPE      SIZE USED PRIO
/dev/dm-1 partition   3G   0B   -2
```

Después de `swapoff -a`, `swapon --show` no debe devolver dispositivos activos.

Para hacerlo permanente, revisar `/etc/fstab` y comentar la entrada de swap si corresponde.

---

## 20. Preparar módulos y parámetros del kernel

```bash
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<'EOF' | sudo tee /etc/modules-load.d/k3s.conf
overlay
br_netfilter
EOF
```

Configurar sysctl:

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/99-k3s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

sudo sysctl --system
```

Validar:

```bash
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
```

**Evidencia de ejecución:**

```text
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
```

> En servidores con políticas de seguridad restrictivas, otra configuración del sistema puede volver a desactivar el reenvío de tráfico IP. Por ello, después de aplicar los cambios, validar que el valor final sea `net.ipv4.ip_forward=1`.

---

## 21. Configurar firewall para k3s

Validar estado de `firewalld`:

```bash
sudo firewall-cmd --state
sudo firewall-cmd --get-active-zones
```

Si no está activo y se usará firewall:

```bash
sudo systemctl start firewalld
sudo firewall-cmd --state
sudo firewall-cmd --get-active-zones
```

Agregar reglas mínimas:

```bash
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=8472/udp
sudo firewall-cmd --permanent --add-port=30000-32767/tcp

sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
sudo firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
sudo firewall-cmd --permanent --zone=public --add-masquerade

sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

**Evidencia de ejecución:**

```text
[root@podman-server rpms]# sudo firewall-cmd --state
not running
FirewallD is not running

[root@podman-server rpms]# systemctl start firewalld
[root@podman-server rpms]# sudo firewall-cmd --state
running

success
success
success
success
success
success
success

public (active)
  interfaces: enp0s3
  services: cockpit dhcpv6-client ssh
  ports: 8200/tcp 6443/tcp 10250/tcp 8472/udp 30000-32767/tcp
  forward: yes
  masquerade: yes
```

La evidencia clave es:

```text
forward: yes
masquerade: yes
```

---

## 22. Instalar k3s offline

Copiar binario e imágenes airgap de k3s:

```bash
sudo cp /opt/instana-pop-airgap-bundle/k3s/k3s /usr/local/bin/k3s
sudo chmod +x /usr/local/bin/k3s

sudo mkdir -p /var/lib/rancher/k3s/agent/images
sudo cp /opt/instana-pop-airgap-bundle/k3s/k3s-airgap-images-amd64.tar.zst \
  /var/lib/rancher/k3s/agent/images/
```

Ejecutar instalación:

```bash
cd /opt/instana-pop-airgap-bundle/k3s
chmod +x install.sh

sudo INSTALL_K3S_SKIP_DOWNLOAD=true \
  INSTALL_K3S_EXEC="server --disable traefik" \
  ./install.sh
```

**Evidencia de ejecución:**

```text
[INFO]  Skipping k3s download and verify
[INFO]  Skipping installation of SELinux RPM
[INFO]  Creating /usr/local/bin/kubectl symlink to k3s
[INFO]  Creating /usr/local/bin/crictl symlink to k3s
[INFO]  Creating /usr/local/bin/ctr symlink to k3s
[INFO]  Creating killall script /usr/local/bin/k3s-killall.sh
[INFO]  Creating uninstall script /usr/local/bin/k3s-uninstall.sh
[INFO]  systemd: Creating service file /etc/systemd/system/k3s.service
[INFO]  systemd: Enabling k3s unit
[INFO]  systemd: Starting k3s
```

---

## 23. Validar k3s

```bash
sudo systemctl status k3s --no-pager
kubectl get nodes -o wide
kubectl get pods -A
```

**Evidencia de ejecución:**

```text
k3s.service - Lightweight Kubernetes
Active: active (running)

NAME            STATUS   ROLES           AGE   VERSION
podman-server   Ready    control-plane   17m   v1.35.5+k3s1

NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE
kube-system   coredns-8db54c48d-l7czf                   1/1     Running   0          17m
kube-system   local-path-provisioner-5d9d9885bc-blhx7   1/1     Running   0          17m
kube-system   metrics-server-786d997795-8ssm6           1/1     Running   0          17m
```

> Durante los primeros segundos pueden aparecer mensajes temporales de flannel como `failed to load flannel 'subnet.env'`. Se consideran transitorios si luego se observa que k3s está activo, el nodo está `Ready` y los pods de `kube-system` quedan en `Running`.

---

## 24. Instalar Helm offline en el servidor air-gapped

```bash
cd /opt/instana-pop-airgap-bundle/helm

tar -xzf "helm-${HELM_VERSION}-linux-amd64.tar.gz" -C /tmp
sudo cp /tmp/linux-amd64/helm /usr/local/bin/helm
sudo chmod +x /usr/local/bin/helm
helm version
```

Si la variable `HELM_VERSION` no está definida en la sesión del servidor, usar el archivo existente:

```bash
ls -lh /opt/instana-pop-airgap-bundle/helm
```

---

## 25. Importar imágenes del Synthetic PoP en containerd de k3s

Utilizar la ruta completa de k3s:

```bash
/usr/local/bin/k3s ctr -n k8s.io images import \
  /opt/instana-pop-airgap-bundle/images/instana-synthetic-pop-images.tar
```

**Evidencia de ejecución:**

```text
containers.instana.io/synthetic/redis:1.        saved
containers.instana.io/synthetic/syntheti        saved
containers.instana.io/synthetic/syntheti        saved
containers.instana.io/synthetic/syntheti        saved
containers.instana.io/synthetic/syntheti        saved
containers.instana.io/synthetic/syntheti        saved
application/vnd.docker.distribution.manifest.v2+json sha256:0e3dba1d38714e82145ae30444ca673a0372c1283839e2a2cda0f122068956fb
application/vnd.docker.distribution.manifest.v2+json sha256:dbee7f71da9ec5cf5c403f08e034c72a17fd3086a1669d15b6a6bbcf7e9b9cc0
application/vnd.docker.distribution.manifest.v2+json sha256:1517c0661fa86cac756b442ec4035f6ab5b4a1904f6bb74d589c7824f47021d4
application/vnd.docker.distribution.manifest.v2+json sha256:1517c0661fa86cac756b442ec4035f6ab5b4a1904f6bb74d589c7824f47021d4
application/vnd.docker.distribution.manifest.v2+json sha256:7b647de305cca18dde25ca130804c1d9604717625c8c1f0f4e5745f047d3f6b5
application/vnd.docker.distribution.manifest.v2+json sha256:2b9d34d74a5310b64c60e1d3329c8b7ff6dce7b0949274045ea83346f04c2bbc
```

Validar imágenes importadas:

```bash
/usr/local/bin/k3s ctr -n k8s.io images ls | grep -E 'synthetic|redis'
```

**Evidencia de ejecución:**

```text
containers.instana.io/synthetic/redis:1.319.1                              sha256:0e3dba1d... 356.3 MiB linux/amd64
containers.instana.io/synthetic/synthetic-playback-browserscript:1.320.1   sha256:dbee7f71... 3.1 GiB   linux/amd64
containers.instana.io/synthetic/synthetic-playback-http:1.319.2            sha256:1517c066... 917.9 MiB linux/amd64
containers.instana.io/synthetic/synthetic-playback-ism:1.319.3             sha256:7b647de3... 493.8 MiB linux/amd64
containers.instana.io/synthetic/synthetic-playback-javascript:1.319.2      sha256:1517c066... 917.9 MiB linux/amd64
containers.instana.io/synthetic/synthetic-pop-controller:1.319.1           sha256:2b9d34d7... 946.4 MiB linux/amd64
```

**Control preventivo:** no continuar si todas las imágenes muestran el mismo digest o el mismo tamaño de Redis. El patrón incorrecto se ve así:

```text
containers.instana.io/synthetic/redis:1.319.1                            sha256:99df627e... 356.3 MiB
containers.instana.io/synthetic/synthetic-playback-browserscript:1.320.1 sha256:99df627e... 356.3 MiB
containers.instana.io/synthetic/synthetic-playback-http:1.319.2          sha256:99df627e... 356.3 MiB
containers.instana.io/synthetic/synthetic-pop-controller:1.319.1         sha256:99df627e... 356.3 MiB
```

Ese patrón indica que el bundle de imágenes fue generado incorrectamente y debe regenerarse con `podman save --multi-image-archive`.

---

## 26. Preparar archivo de valores para Helm

```bash
cp /opt/instana-pop-airgap-bundle/values/values-airgap-template.yaml \
   /opt/instana-pop-airgap-bundle/values/values-airgap.yaml

vi /opt/instana-pop-airgap-bundle/values/values-airgap.yaml
```

Reemplazar placeholders:

```yaml
downloadKey: "<INSTANA_DOWNLOAD_KEY>"

controller:
  location: "K3SDemoPOP;K3SDemoPOP;Peru;Lima;0;0;K3SDemoPOP"
  clusterName: "K3SDemo"
  instanaKey: "<INSTANA_KEY>"
  instanaSyntheticEndpoint: "https://synthetics-coral-saas.instana.io"

redis:
  password: "<REDIS_PASSWORD_MIN_10_CHARS>"
  traceLevel: "notice"
```

Validar Redis:

```bash
grep -n -A25 '^redis:' /opt/instana-pop-airgap-bundle/values/values-airgap.yaml
```

**Evidencia esperada:**

```text
redis:
  tls:
    enabled: false
  password: "<REDIS_PASSWORD_MIN_10_CHARS>"
  traceLevel: "notice"
  image:
    pullPolicy: IfNotPresent
```

Validar render de Helm antes de instalar:

```bash
export POP_NAMESPACE="synthetic-pop"
export POP_RELEASE="synthetic-pop"
export POP_CHART="/opt/instana-pop-airgap-bundle/charts/synthetic-pop-1.2.47.tgz"
export POP_VALUES="/opt/instana-pop-airgap-bundle/values/values-airgap.yaml"

helm template "${POP_RELEASE}" "${POP_CHART}" \
  --namespace "${POP_NAMESPACE}" \
  -f "${POP_VALUES}" | grep -i -n -A4 -B4 "LOGLEVEL"
```

La parte de Redis debe renderizarse así:

```text
- name: LOGLEVEL
  value: "notice"
```

---

## 27. Configurar kubeconfig para Helm

Antes de ejecutar Helm, validar acceso al cluster:

```bash
/usr/local/bin/k3s kubectl get nodes
```

Configurar kubeconfig:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
kubectl get pods -A
helm list -A
```

Opcionalmente, dejar kubeconfig persistente para root:

```bash
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
chmod 600 /root/.kube/config
export KUBECONFIG=/root/.kube/config
```

**Evidencia de ejecución:**

```text
[root@podman-server helm]# helm install "${POP_RELEASE}" "${POP_CHART}" \
  --namespace "${POP_NAMESPACE}" \
  --create-namespace \
  -f "${POP_VALUES}"
Error: INSTALLATION FAILED: Kubernetes cluster unreachable: Get "https://127.0.0.1:6443/version": tls: failed to verify certificate: x509: certificate signed by unknown authority

[root@podman-server helm]# /usr/local/bin/k3s kubectl get nodes
NAME            STATUS   ROLES           AGE   VERSION
podman-server   Ready    control-plane   16m   v1.35.5+k3s1

[root@podman-server helm]# export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
[root@podman-server helm]# kubectl get nodes
NAME            STATUS   ROLES           AGE   VERSION
podman-server   Ready    control-plane   17m   v1.35.5+k3s1
```

---

## 28. Instalar Synthetic Private PoP con Helm

```bash
helm install "${POP_RELEASE}" "${POP_CHART}" \
  --kubeconfig /etc/rancher/k3s/k3s.yaml \
  --namespace "${POP_NAMESPACE}" \
  --create-namespace \
  -f "${POP_VALUES}"
```

**Evidencia de ejecución:**

```text
NAME: synthetic-pop
LAST DEPLOYED: Fri Jun 19 20:27:01 2026
NAMESPACE: synthetic-pop
STATUS: deployed
REVISION: 1
TEST SUITE: None
CHART NAME: synthetic-pop
CHART VERSION: 1.2.47
APP VERSION: 1.320.1
```

Validar release:

```bash
helm list -n "${POP_NAMESPACE}"
helm status "${POP_RELEASE}" -n "${POP_NAMESPACE}"
```

**Evidencia de ejecución:**

```text
NAME            NAMESPACE       REVISION  STATUS    CHART                 APP VERSION
synthetic-pop   synthetic-pop   1         deployed  synthetic-pop-1.2.47  1.320.1
```

---

## 29. Validar pods, servicios y eventos

```bash
kubectl get pods -n "${POP_NAMESPACE}" -o wide
kubectl get svc -n "${POP_NAMESPACE}"
kubectl get events -n "${POP_NAMESPACE}" --sort-by=.metadata.creationTimestamp | tail -50
```

**Evidencia inicial:**

```text
NAME                                                           READY   STATUS    RESTARTS   AGE
synthetic-pop-browserscript-playback-engine-6577864b94-z7sl8   0/1     Running   0          20s
synthetic-pop-controller-bdc79cf5c-br8kb                       0/1     Running   0          20s
synthetic-pop-http-playback-engine-769c4f8ddb-bmjdp            0/1     Running   0          20s
synthetic-pop-javascript-playback-engine-5d75b4b4d7-k55x4      0/1     Running   0          20s
synthetic-pop-redis-6978564c96-52swr                           0/1     Running   0          20s

NAME                       TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
synthetic-pop-controller   ClusterIP   10.43.184.19   <none>        8443/TCP   22s
synthetic-pop-redis        ClusterIP   10.43.11.109   <none>        6378/TCP   22s
```

**Evidencia posterior:**

```text
NAME                                                           READY   STATUS    RESTARTS   AGE
synthetic-pop-browserscript-playback-engine-6577864b94-z7sl8   1/1     Running   0          4m30s
synthetic-pop-controller-bdc79cf5c-br8kb                       1/1     Running   0          4m30s
synthetic-pop-http-playback-engine-769c4f8ddb-bmjdp            1/1     Running   0          4m30s
synthetic-pop-javascript-playback-engine-5d75b4b4d7-k55x4      1/1     Running   0          4m30s
synthetic-pop-redis-6978564c96-52swr                           1/1     Running   0          4m30s
```

---

## 30. Validar DNS desde un pod

```bash
kubectl run dns-test \
  -n "${POP_NAMESPACE}" \
  --rm -it \
  --restart=Never \
  --image=busybox:1.36 \
  -- nslookup synthetics-coral-saas.instana.io
```

**Evidencia de ejecución:**

```text
Server:         10.43.0.10
Address:        10.43.0.10:53

Non-authoritative answer:
synthetics-coral-saas.instana.io        canonical name = coral.instana.io.edgekey.net
coral.instana.io.edgekey.net            canonical name = e194383.dsca.akamaiedge.net
Name:   e194383.dsca.akamaiedge.net
Address: 190.98.160.147
Name:   e194383.dsca.akamaiedge.net
Address: 190.98.160.137

pod "dns-test" deleted from synthetic-pop namespace
```

---

## 31. Validar logs funcionales del PoP

```bash
kubectl logs -n "${POP_NAMESPACE}" \
  -l app.kubernetes.io/instance="${POP_RELEASE}" \
  --all-containers=true \
  --tail=300
```

**Evidencia de Redis operativo:**

```text
Synthetic Redis is running
Redis version=8.2.2
Configuration loaded
Running mode=standalone, port=6379.
Server initialized
Ready to accept connections tcp
```

**Evidencia de BrowserScript operativo:**

```text
Synthetic Browserscript Playback Engine Version: 1.320.1
Starting executor
The log level of Synthetic browser engine will be set as: INFO
```

**Evidencia de controller registrado y listo:**

```text
LocationRegister:createUpdateLocation - Location is updated successfully, id: K3SDemoPOP, type: PRIVATE
PoPController:start - PoP readiness file created.
PoPRestController:start - PoP Rest Server is ready on port : 8443
```

**Evidencia de consulta exitosa hacia Instana Synthetic:**

```text
TestListLoader:pagedQueryConfig - Downloaded tests successfully from : https://synthetics-coral-saas.instana.io/synthetics/tests?locationId=K3SDemoPOP&offset=0&limit=500
Retrieved tests count: 0
Totally 0 test(s) will run
```

**Evidencia de motor HTTP/HTTPScript listo:**

```text
playback engine httpscript starting, all redis connection ready, start execute tasks.
playback engine httpscript started, {"ready":true,"msg":"Playback engine is ready"}
```

---

## 32. Validación final

Ejecutar:

```bash
kubectl get pods -n "${POP_NAMESPACE}"
helm status "${POP_RELEASE}" -n "${POP_NAMESPACE}"
/usr/local/bin/k3s ctr -n k8s.io images ls | grep -E 'synthetic|redis'
```

La instalación puede considerarse válida cuando se cumpla lo siguiente:

- El release Helm está en `STATUS: deployed`.
- Los pods del namespace `synthetic-pop` están `1/1 Running`.
- Redis muestra `Ready to accept connections tcp`.
- El controller registra o actualiza la location.
- El controller puede descargar configuraciones desde el endpoint Synthetic configurado.
- Las imágenes importadas no comparten todas el mismo digest.

---

## 33. Troubleshooting rápido

### 33.1 Todas las imágenes tienen el mismo digest

Síntoma:

```text
containers.instana.io/synthetic/redis:1.319.1                            sha256:99df627e... 356.3 MiB
containers.instana.io/synthetic/synthetic-playback-browserscript:1.320.1 sha256:99df627e... 356.3 MiB
containers.instana.io/synthetic/synthetic-playback-http:1.319.2          sha256:99df627e... 356.3 MiB
containers.instana.io/synthetic/synthetic-pop-controller:1.319.1         sha256:99df627e... 356.3 MiB
```

Causa probable:

```bash
podman save -o instana-synthetic-pop-images.tar $(cat images-pop.txt)
```

sin `--multi-image-archive`.

Corrección:

```bash
podman save \
  --multi-image-archive \
  -o "$AIRGAP_DIR/images/instana-synthetic-pop-images.tar" \
  $(cat "$AIRGAP_DIR/images/images-pop.txt")
```

### 33.2 Pods arrancan como Redis y caen en CrashLoopBackOff

Síntoma:

```text
Synthetic Redis is running
The log level of Synthetic Redis will be set as: INFO

*** FATAL CONFIG FILE ERROR (Redis 8.2.2) ***
Reading the configuration file, at line 3
>>> 'loglevel "INFO"'
argument(s) must be one of the following: debug, verbose, notice, warning, nothing
```

Causas probables:

- Archive de imágenes mal generado: varios tags apuntan a la imagen de Redis.
- `redis.traceLevel` no fue configurado en minúscula.

Validaciones:

```bash
/usr/local/bin/k3s ctr -n k8s.io images ls | grep -E 'synthetic|redis'
helm template "${POP_RELEASE}" "${POP_CHART}" -n "${POP_NAMESPACE}" -f "${POP_VALUES}" | grep -i -n -A4 -B4 "LOGLEVEL"
```

Corrección esperada:

```yaml
redis:
  traceLevel: "notice"
```

### 33.3 Helm no puede alcanzar el cluster

Síntoma:

```text
Error: INSTALLATION FAILED: Kubernetes cluster unreachable: Get "https://127.0.0.1:6443/version": tls: failed to verify certificate: x509: certificate signed by unknown authority
```

Corrección:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
helm list -A
```

O ejecutar Helm indicando explícitamente kubeconfig:

```bash
helm install "${POP_RELEASE}" "${POP_CHART}" \
  --kubeconfig /etc/rancher/k3s/k3s.yaml \
  --namespace "${POP_NAMESPACE}" \
  --create-namespace \
  -f "${POP_VALUES}"
```

### 33.4 Pods no resuelven DNS o no salen de la red de pods

Validar:

```bash
kubectl logs -n kube-system deploy/coredns --tail=100
sysctl net.ipv4.ip_forward
sudo firewall-cmd --list-all
```

Corregir reglas de firewall:

```bash
sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
sudo firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
sudo firewall-cmd --permanent --zone=public --add-masquerade
sudo firewall-cmd --reload
```

Validar que se observe:

```text
forward: yes
masquerade: yes
```

---

## 34. Resumen de comandos críticos que no deben omitirse

```bash
# VM con Internet: guardar varias imágenes correctamente
podman save --multi-image-archive \
  -o "$AIRGAP_DIR/images/instana-synthetic-pop-images.tar" \
  $(cat "$AIRGAP_DIR/images/images-pop.txt")

# VM con Internet: validar que no todas las imágenes apunten al mismo Config
tar -xOf "$AIRGAP_DIR/images/instana-synthetic-pop-images.tar" manifest.json \
  | jq -r '.[] | "\(.RepoTags | join(",")) -> \(.Config)"'

# Servidor air-gapped: usar ruta completa de k3s
/usr/local/bin/k3s ctr -n k8s.io images import \
  /opt/instana-pop-airgap-bundle/images/instana-synthetic-pop-images.tar

# Servidor air-gapped: asegurar kubeconfig para Helm
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# values.yaml: Redis con loglevel compatible
redis:
  traceLevel: "notice"
```
