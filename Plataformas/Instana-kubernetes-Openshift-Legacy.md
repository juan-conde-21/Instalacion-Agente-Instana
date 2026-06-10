# Instalación legacy del agente Instana en Kubernetes y OpenShift

> Guía de instalación mediante manifiestos YAML estáticos para clústeres Kubernetes/OpenShift legacy donde no se utilizará el Instana Agent Operator.

## Índice

1. [Objetivo](#objetivo)
2. [Alcance y consideraciones](#alcance-y-consideraciones)
3. [Arquitectura del despliegue](#arquitectura-del-despliegue)
4. [Valores que deben modificarse en los YAML](#valores-que-deben-modificarse-en-los-yaml)
5. [Instalación con salida a Internet](#instalación-con-salida-a-internet)
   - [Kubernetes](#kubernetes)
   - [OpenShift](#openshift)
6. [Instalación con repositorio privado autenticado](#instalación-con-repositorio-privado-autenticado)
   - [Descarga, retag y carga de imágenes](#descarga-retag-y-carga-de-imágenes)
   - [Configuración de `imagePullSecret`](#configuración-de-imagepullsecret)
   - [Cambios en el YAML para repositorio privado](#cambios-en-el-yaml-para-repositorio-privado)
7. [Configuración de proxy](#configuración-de-proxy)
   - [Proxy del agente hacia Instana](#proxy-del-agente-hacia-instana)
   - [Proxy para descarga de artefactos del agente](#proxy-para-descarga-de-artefactos-del-agente)
   - [Proxy para `k8sensor`](#proxy-para-k8sensor)
8. [Validaciones posteriores](#validaciones-posteriores)
9. [Troubleshooting conocido](#troubleshooting-conocido)
10. [Manifiesto Kubernetes legacy](#manifiesto-kubernetes-legacy)
11. [Manifiesto OpenShift legacy](#manifiesto-openshift-legacy)
12. [Referencias](#referencias)

---

## Objetivo

Este documento describe el despliegue del agente Instana en Kubernetes y OpenShift usando manifiestos YAML estáticos. El objetivo es cubrir un escenario legacy donde el uso del Instana Agent Operator moderno no es viable por incompatibilidades con APIs disponibles en clústeres antiguos.

El procedimiento fue validado con un manifiesto que separa los siguientes componentes:

| Componente | Tipo | Función |
|---|---|---|
| `instana-agent` | `DaemonSet` | Ejecuta el agente Instana en cada nodo. |
| `instana-agent` | `Service` | Expone APIs internas del agente, OpenTelemetry y endpoint local de agente. |
| `instana-agent-headless` | `Service` headless | Resolución interna entre pods del agente. |
| `k8sensor` | `Deployment` | Recolecta metadata de Kubernetes/OpenShift. |
| `instana-agent` | `Secret` | Almacena `key` y `downloadKey` en base64. |
| `instana-agent` / `k8sensor` | `ServiceAccount` | Identidad usada por los pods. |
| `ClusterRole` / `ClusterRoleBinding` | RBAC | Permisos para lectura de recursos del clúster. |

---

## Alcance y consideraciones

Esta guía no instala el Instana Agent Operator ni el Helm chart. Se usa un YAML estático legacy.

### Consideraciones importantes

- El `k8sensor` **debe quedar pineado** a la imagen validada:

```yaml
image: "icr.io/instana/k8sensor:f8655ade0de93185ed65cc7e15ebdadb2bc075a7"
```

- No usar `k8sensor:latest` en clústeres legacy. En pruebas con Kubernetes 1.20, imágenes nuevas de `k8sensor` intentaban observar `CronJob` como `batch/v1`, API disponible desde Kubernetes 1.21.
- En Kubernetes 1.20/OpenShift 4.7 se deben evitar campos modernos como:
  - `spec.internalTrafficPolicy`
  - `policy/v1 PodDisruptionBudget`
  - `batch/v1 CronJob`
- El `agent key` y `downloadKey` no deben publicarse en texto claro. En los YAML del documento se dejan como placeholders base64.
- Si se publica este documento en un repositorio, se recomienda mantener los YAML como plantilla y documentar los valores que el cliente debe reemplazar.

---

## Arquitectura del despliegue

```text
+-----------------------------+
| Kubernetes / OpenShift      |
|                             |
|  Namespace: instana-agent   |
|                             |
|  +-----------------------+  |
|  | DaemonSet             |  |
|  | instana-agent         |  |
|  | - hostNetwork: true   |  |
|  | - privileged: true    |  |
|  +-----------------------+  |
|             |               |
|             | service       |
|             v               |
|  +-----------------------+  |
|  | Service               |  |
|  | instana-agent         |  |
|  | 42699 / 4317 / 4318   |  |
|  +-----------------------+  |
|                             |
|  +-----------------------+  |
|  | Deployment            |  |
|  | k8sensor              |  |
|  | image pineada         |  |
|  +-----------------------+  |
|                             |
+-----------------------------+
             |
             | HTTPS 443
             v
+-----------------------------+
| Instana Backend             |
| ingress-*-saas.instana.io   |
+-----------------------------+
```

---

## Valores que deben modificarse en los YAML

Las siguientes líneas son aproximadas y corresponden a los archivos base compartidos para esta guía.

| Campo | Descripción | Línea aprox. Kubernetes | Línea aprox. OpenShift |
|---|---|---:|---:|
| `Secret.data.key` / `downloadKey` | Agent key y download key en base64 | 98 | 98 |
| `ConfigMap.data.cluster_name` | Nombre visible del clúster en Instana | 110 | 110 |
| `configuration.yaml > availability-zone` | Zona del agente | 144 | 144 |
| `DaemonSet.spec.template.spec.containers[0].image` | Imagen del agente Instana | 194 | 194 |
| `INSTANA_ZONE` | Zona del agente | 199 | 199 |
| `INSTANA_AGENT_ENDPOINT` | Endpoint SaaS/Self-hosted de Instana | 206 | 206 |
| `INSTANA_AGENT_ENDPOINT_PORT` | Puerto del endpoint. Debe ir entre comillas | 208 | 208 |
| `ConfigMap/k8sensor.data.backend` | Endpoint usado por k8sensor | 390 | 371 |
| `Deployment/k8sensor.containers[0].image` | Imagen pineada de k8sensor validada | 423 | 404 |
| `AGENT_ZONE` | Zona usada por k8sensor | 438 | 419 |
| `ClusterRole/securitycontextconstraints` | Permiso SCC privileged en OpenShift | N/A | 341 |

### Valores mínimos a reemplazar

| Placeholder | Valor esperado | Ejemplo |
|---|---|---|
| `<BASE64_AGENT_KEY>` | Agent key codificado en base64 | `printf '%s' '<AGENT_KEY>' | base64 -w0` |
| `<BASE64_DOWNLOAD_KEY_OR_AGENT_KEY>` | Download key codificado en base64. Si no aplica, puede usarse el mismo agent key según el escenario | `printf '%s' '<DOWNLOAD_KEY>' | base64 -w0` |
| `<CLUSTER_NAME>` | Nombre visible del clúster | `ocp-produccion` |
| `<ZONE_NAME>` | Zona o agrupación lógica | `produccion` |
| `<INSTANA_ENDPOINT_HOST>` | Endpoint de Instana | `ingress-red-saas.instana.io` |
| `<INSTANA_ENDPOINT_PORT>` | Puerto del endpoint | `"443"` |

> Nota: los puertos usados como variables de entorno deben ir entre comillas, por ejemplo `"443"` o `"3128"`.

---

## Instalación con salida a Internet

Este escenario aplica cuando los nodos pueden descargar las imágenes directamente desde los registries públicos definidos en el YAML y pueden conectarse al backend de Instana por HTTPS.

### Kubernetes

1. Editar el manifiesto `instana-kubernetes-legacy.yaml` y reemplazar los valores indicados en la sección [Valores que deben modificarse en los YAML](#valores-que-deben-modificarse-en-los-yaml).

2. Aplicar el manifiesto:

```bash
kubectl apply -f instana-kubernetes-legacy.yaml
```

3. Validar recursos:

```bash
kubectl -n instana-agent get pods -o wide
kubectl -n instana-agent get ds,deploy,svc,cm,secret
```

4. Validar logs:

```bash
kubectl -n instana-agent logs ds/instana-agent --tail=100
kubectl -n instana-agent logs deploy/k8sensor --tail=100
```

### OpenShift

1. Editar el manifiesto `instana-openshift-legacy.yaml`.

2. Aplicar el manifiesto:

```bash
oc apply -f instana-openshift-legacy.yaml
```

3. En OpenShift, validar que el ServiceAccount del agente tenga permisos compatibles con ejecución privilegiada. El YAML incluye RBAC para `securitycontextconstraints/privileged`; si se prefiere asignarlo explícitamente:

```bash
oc adm policy add-scc-to-user privileged -z instana-agent -n instana-agent
```

4. Validar recursos:

```bash
oc -n instana-agent get pods -o wide
oc -n instana-agent get ds,deploy,svc,cm,secret
```

5. Validar logs:

```bash
oc -n instana-agent logs ds/instana-agent --tail=100
oc -n instana-agent logs deploy/k8sensor --tail=100
```

---

## Instalación con repositorio privado autenticado

Este escenario aplica cuando el cliente cargará las imágenes en un registry privado con autenticación.

La documentación de IBM para ambientes offline/air-gapped describe el patrón general: descargar imágenes necesarias, retagearlas, cargarlas en un registry privado y crear un pull secret en el namespace destino. En este procedimiento no se usa el operador, por lo que se omite la imagen `instana-agent-operator` y se conservan únicamente las imágenes del agente y de `k8sensor`.

### Descarga, retag y carga de imágenes

#### Opción con Docker/Podman

```bash
# Login al registry destino del cliente
podman login <REGISTRY_PRIVADO>

# Imagen del agente usada por el YAML
podman pull icr.io/instana/agent:latest
podman tag icr.io/instana/agent:latest <REGISTRY_PRIVADO>/<RUTA>/instana-agent:<TAG_AGENT>
podman push <REGISTRY_PRIVADO>/<RUTA>/instana-agent:<TAG_AGENT>

# Imagen validada de k8sensor para Kubernetes/OpenShift legacy
podman pull icr.io/instana/k8sensor:f8655ade0de93185ed65cc7e15ebdadb2bc075a7
podman tag icr.io/instana/k8sensor:f8655ade0de93185ed65cc7e15ebdadb2bc075a7 <REGISTRY_PRIVADO>/<RUTA>/k8sensor:f8655ade0de93185ed65cc7e15ebdadb2bc075a7
podman push <REGISTRY_PRIVADO>/<RUTA>/k8sensor:f8655ade0de93185ed65cc7e15ebdadb2bc075a7
```

#### Opción con `skopeo`

```bash
skopeo copy \
  docker://icr.io/instana/agent:latest \
  docker://<REGISTRY_PRIVADO>/<RUTA>/instana-agent:<TAG_AGENT>

skopeo copy \
  docker://icr.io/instana/k8sensor:f8655ade0de93185ed65cc7e15ebdadb2bc075a7 \
  docker://<REGISTRY_PRIVADO>/<RUTA>/k8sensor:f8655ade0de93185ed65cc7e15ebdadb2bc075a7
```

#### Nota sobre la imagen estática del agente

La documentación de IBM para instalaciones air-gapped también hace referencia a la imagen estática:

```bash
containers.instana.io/instana/release/agent/static:latest
```

Si el cliente decide usar esa imagen en lugar de `icr.io/instana/agent:latest`, debe iniciar sesión con el agent key y modificar la línea de imagen del `DaemonSet`:

```bash
docker login https://containers.instana.io/v2 -u _ -p <AGENT_KEY>
docker pull containers.instana.io/instana/release/agent/static:latest
```

Y luego en el YAML:

```yaml
image: "<REGISTRY_PRIVADO>/<RUTA>/instana-agent-static:<TAG_AGENT>"
```

---

## Configuración de `imagePullSecret`

### Kubernetes

Crear el secret en el namespace `instana-agent`:

```bash
kubectl -n instana-agent create secret docker-registry cliente-regcred \
  --docker-server=<REGISTRY_PRIVADO> \
  --docker-username=<USUARIO> \
  --docker-password=<PASSWORD_O_TOKEN> \
  --docker-email=dummy@example.com
```

Asociarlo a los dos ServiceAccount usados por el YAML:

```bash
kubectl -n instana-agent patch serviceaccount instana-agent \
  -p '{"imagePullSecrets":[{"name":"cliente-regcred"}]}'

kubectl -n instana-agent patch serviceaccount k8sensor \
  -p '{"imagePullSecrets":[{"name":"cliente-regcred"}]}'
```

También puede declararse directamente en el YAML:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: instana-agent
  namespace: instana-agent
imagePullSecrets:
  - name: cliente-regcred
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8sensor
  namespace: instana-agent
imagePullSecrets:
  - name: cliente-regcred
```

### OpenShift

Crear el secret:

```bash
oc -n instana-agent create secret docker-registry cliente-regcred \
  --docker-server=<REGISTRY_PRIVADO> \
  --docker-username=<USUARIO> \
  --docker-password=<PASSWORD_O_TOKEN> \
  --docker-email=dummy@example.com
```

Asociarlo a ambos ServiceAccount:

```bash
oc -n instana-agent secrets link instana-agent cliente-regcred --for=pull
oc -n instana-agent secrets link k8sensor cliente-regcred --for=pull
```

Validar:

```bash
oc -n instana-agent get sa instana-agent -o yaml | grep -A3 imagePullSecrets
oc -n instana-agent get sa k8sensor -o yaml | grep -A3 imagePullSecrets
```

### Cambios en el YAML para repositorio privado

Reemplazar las imágenes públicas:

```yaml
image: "icr.io/instana/agent:latest"
```

por:

```yaml
image: "<REGISTRY_PRIVADO>/<RUTA>/instana-agent:<TAG_AGENT>"
```

Y reemplazar:

```yaml
image: "icr.io/instana/k8sensor:f8655ade0de93185ed65cc7e15ebdadb2bc075a7"
```

por:

```yaml
image: "<REGISTRY_PRIVADO>/<RUTA>/k8sensor:f8655ade0de93185ed65cc7e15ebdadb2bc075a7"
```

Se recomienda usar tags fijos y evitar `latest` cuando el cliente controle el registry privado.

### Si el registry privado usa CA interna o certificado self-signed

En OpenShift, además del `imagePullSecret`, puede requerirse configurar confianza hacia la CA del registry:

```bash
oc create configmap registry-cas \
  -n openshift-config \
  --from-file=<REGISTRY_HOSTNAME>=/path/ca.crt

oc patch image.config.openshift.io/cluster \
  --type=merge \
  --patch '{"spec":{"additionalTrustedCA":{"name":"registry-cas"}}}'
```

Si el registry usa puerto, Red Hat documenta que el nombre de la llave del ConfigMap debe usar `..` en lugar de `:`. Ejemplo:

```bash
--from-file=registry.example.com..5000=/path/ca.crt
```

---

## Configuración de proxy

La configuración de proxy se debe separar en tres partes:

| Tráfico | Configuración |
|---|---|
| Pull de imágenes desde registry privado | No lo resuelve el proxy del contenedor. Lo maneja kubelet/OpenShift con `imagePullSecret`, trust CA y configuración de red del nodo. |
| Agente hacia backend Instana | Variables `INSTANA_AGENT_PROXY_*`. |
| Agente hacia repositorios de artefactos/sensores | Variables `INSTANA_REPOSITORY_PROXY_*`. |
| `k8sensor` hacia backend/API externos | Variables estándar `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`. |

> Los valores `192.168.0.57:3128` usados abajo son de ejemplo. Deben reemplazarse por el proxy real del cliente.

### Proxy del agente hacia Instana

Agregar en el `DaemonSet` del agente, dentro de `containers.env`:

```yaml
- name: INSTANA_AGENT_PROXY_HOST
  value: "192.168.0.57"
- name: INSTANA_AGENT_PROXY_PORT
  value: "3128"
- name: INSTANA_AGENT_PROXY_PROTOCOL
  value: "http"
- name: INSTANA_AGENT_PROXY_USE_DNS
  value: "true"
```

### Proxy para descarga de artefactos del agente

Agregar también en el `DaemonSet` del agente:

```yaml
- name: INSTANA_REPOSITORY_PROXY_ENABLED
  value: "true"
- name: INSTANA_REPOSITORY_PROXY_HOST
  value: "192.168.0.57"
- name: INSTANA_REPOSITORY_PROXY_PORT
  value: "3128"
- name: INSTANA_REPOSITORY_PROXY_PROTOCOL
  value: "http"
```

### Proxy para `k8sensor`

Agregar en el `Deployment` `k8sensor`, dentro de `containers.env`:

```yaml
- name: HTTPS_PROXY
  value: "http://192.168.0.57:3128"
- name: HTTP_PROXY
  value: "http://192.168.0.57:3128"
- name: NO_PROXY
  value: "localhost,127.0.0.1,.svc,.svc.cluster.local,kubernetes.default.svc,kubernetes.default.svc.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

`NO_PROXY` debe incluir los dominios y rangos internos del clúster para evitar que llamadas internas al API Server o servicios internos pasen por el proxy.

### Proxy con autenticación

No colocar usuario/password en el YAML principal. Crear un Secret:

```bash
kubectl -n instana-agent create secret generic instana-proxy-secret \
  --from-literal=HTTPS_PROXY='http://<USUARIO>:<PASSWORD>@192.168.0.57:3128' \
  --from-literal=HTTP_PROXY='http://<USUARIO>:<PASSWORD>@192.168.0.57:3128'
```

Y referenciarlo en `k8sensor`:

```yaml
- name: HTTPS_PROXY
  valueFrom:
    secretKeyRef:
      name: instana-proxy-secret
      key: HTTPS_PROXY
- name: HTTP_PROXY
  valueFrom:
    secretKeyRef:
      name: instana-proxy-secret
      key: HTTP_PROXY
- name: NO_PROXY
  value: "localhost,127.0.0.1,.svc,.svc.cluster.local,kubernetes.default.svc,kubernetes.default.svc.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

---

## Validaciones posteriores

### Kubernetes

```bash
kubectl -n instana-agent get pods -o wide
kubectl -n instana-agent get ds,deploy,svc,cm,secret
kubectl -n instana-agent describe ds instana-agent
kubectl -n instana-agent describe deploy k8sensor
kubectl -n instana-agent logs ds/instana-agent --tail=100
kubectl -n instana-agent logs deploy/k8sensor --tail=100
```

### OpenShift

```bash
oc -n instana-agent get pods -o wide
oc -n instana-agent get ds,deploy,svc,cm,secret
oc -n instana-agent describe ds instana-agent
oc -n instana-agent describe deploy k8sensor
oc -n instana-agent logs ds/instana-agent --tail=100
oc -n instana-agent logs deploy/k8sensor --tail=100
```

### Validar conectividad al backend de Instana

Con pod temporal:

```bash
kubectl -n instana-agent run curl-instana-test --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c 'curl -vk https://<INSTANA_ENDPOINT_HOST>'
```

Con proxy:

```bash
kubectl -n instana-agent run curl-proxy-test --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c 'HTTPS_PROXY=http://192.168.0.57:3128 curl -vk https://<INSTANA_ENDPOINT_HOST>'
```

---

## Troubleshooting conocido

| Error | Causa probable | Acción recomendada |
|---|---|---|
| `PodDisruptionBudget in version policy/v1` | Operator moderno incompatible con Kubernetes 1.20/OpenShift 4.7 | Usar YAML legacy o actualizar clúster. |
| `.spec.internalTrafficPolicy: field not declared in schema` | Campo no disponible en Kubernetes 1.20 | Eliminar `internalTrafficPolicy` del YAML. |
| `failed to list *v1.CronJob` | `k8sensor` moderno intenta usar `batch/v1` | Usar la imagen pineada validada de `k8sensor`. |
| `ImagePullBackOff` / `ErrImagePull` | Falta autenticación o trust CA hacia registry privado | Crear `imagePullSecret`, asociarlo al ServiceAccount y validar CA. |
| `backend=https://${agentEndpoint}` | Placeholders sin reemplazar | Reemplazar variables antes de aplicar. |
| `env.value expects string` | Puerto numérico sin comillas | Usar `"443"` o `"3128"`. |
| `RBAC does not allow monitoring CRD/CR` | Permisos limitados para CRDs | Evaluar si se requiere monitoreo CRD/CR y ampliar RBAC. |
| `DeploymentConfigs not found` en Kubernetes vanilla | Recurso exclusivo de OpenShift | Ignorable en Kubernetes vanilla. En OpenShift sí debería existir. |

---

## Manifiesto Kubernetes legacy

> Reemplazar los placeholders antes de aplicar. No publicar agent keys reales.

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: instana-agent
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
---
apiVersion: v1
kind: Service
metadata:
  name: instana-agent
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
spec:
  selector:
    app.kubernetes.io/name: instana-agent
  ports:
    # Prometheus remote_write, Trace Web SDK and other APIs
    - name: agent-apis
      protocol: TCP
      port: 42699
      targetPort: 42699
    
    # OpenTelemetry original default port
    - name: opentelemetry
      protocol: TCP
      port: 55680
      targetPort: 55680
    # OpenTelemetry as registered and reserved by IANA
    - name: opentelemetry-iana
      protocol: TCP
      port: 4317
      targetPort: 4317
    # OpenTelemetry HTTP port
    - name: opentelemetry-http
      protocol: TCP
      port: 4318
      targetPort: 4318
---
apiVersion: v1
kind: Service
metadata:
  name: instana-agent-headless
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
spec:
  clusterIP: None
  selector:
    app.kubernetes.io/name: instana-agent
  ports:
    # Prometheus remote_write, Trace Web SDK and other APIs
    - name: agent-apis
      protocol: TCP
      port: 42699
      targetPort: 42699
    
    # OpenTelemetry original default port
    - name: opentelemetry
      protocol: TCP
      port: 55680
      targetPort: 55680
    # OpenTelemetry as registered and reserved by IANA
    - name: opentelemetry-iana
      protocol: TCP
      port: 4317
      targetPort: 4317
    # OpenTelemetry HTTP port
    - name: opentelemetry-http
      protocol: TCP
      port: 4318
      targetPort: 4318
---
apiVersion: v1
kind: Secret
metadata:
  name: instana-agent
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
type: Opaque
data:
  key: "<BASE64_AGENT_KEY>" # Reemplazar por el agent key de Instana codificado en base64
  downloadKey: "<BASE64_DOWNLOAD_KEY_OR_AGENT_KEY>"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: instana-agent
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
data:
  cluster_name: "<CLUSTER_NAME>"
  configuration.yaml: |
  
    # Manual a-priori configuration. Configuration will be only used when the sensor
    # is actually installed by the agent.
    # The commented out example values represent example configuration and are not
    # necessarily defaults. Defaults are usually 'absent' or mentioned separately.
    # Changes are hot reloaded unless otherwise mentioned.
    
    # It is possible to create files called 'configuration-abc.yaml' which are
    # merged with this file in file system order. So 'configuration-cde.yaml' comes
    # after 'configuration-abc.yaml'. Only nested structures are merged, values are
    # overwritten by subsequent configurations.
    
    # Secrets
    # To filter sensitive data from collection by the agent, all sensors respect
    # the following secrets configuration. If a key collected by a sensor matches
    # an entry from the list, the value is redacted.
    #com.instana.secrets:
    #  matcher: 'contains-ignore-case' # 'contains-ignore-case', 'contains', 'regex'
    #  list:
    #    - 'key'
    #    - 'password'
    #    - 'secret'
    
    # Host
    #com.instana.plugin.host:
    #  tags:
    #    - 'dev'
    #    - 'app1'
    
    # Hardware & Zone
    com.instana.plugin.generic.hardware:
      enabled: true # disabled by default
      availability-zone: '<ZONE_NAME>'
    

  
  configuration-opentelemetry.yaml: |
    com.instana.plugin.opentelemetry: 
      grpc:
        enabled: true
      http:
        enabled: true
  
  configuration-disable-kubernetes-sensor.yaml: |
    com.instana.plugin.kubernetes:
      enabled: false
---
# TODO: Combine into single template with agent-daemonset-with-zones.yaml---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: instana-agent
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: instana-agent
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  minReadySeconds: 0
  template:
    metadata:
      labels:
        app.kubernetes.io/name: instana-agent
        app.kubernetes.io/version: 1.2.74
        instana/agent-mode: "APM"
      annotations:
        # To ensure that changes to agent.configuration_yaml or agent.additional_backends trigger a Pod recreation, we keep a SHA here
        # Unfortunately, we cannot use the lookup function to check on the values in the configmap, otherwise we break Helm < 3.2
        instana-configuration-hash: 70c6df6d7c1a99a22ee74d59fa7f300fe6432573
    spec:
      serviceAccountName: instana-agent
      hostNetwork: true
      hostPID: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: instana-agent
          image: "icr.io/instana/agent:latest"
          imagePullPolicy: Always
          env:
            - name: INSTANA_AGENT_LEADER_ELECTOR_PORT
              value: "42655"
            - name: INSTANA_ZONE
              value: "<ZONE_NAME>"
            - name: INSTANA_KUBERNETES_CLUSTER_NAME
              valueFrom:
                configMapKeyRef:
                  name: instana-agent
                  key: cluster_name
            - name: INSTANA_AGENT_ENDPOINT
              value: "<INSTANA_ENDPOINT_HOST>"
            - name: INSTANA_AGENT_ENDPOINT_PORT
              value: "443"
            - name: INSTANA_AGENT_KEY
              valueFrom:
                secretKeyRef:
                  name: instana-agent
                  key: key
            - name: INSTANA_DOWNLOAD_KEY
              valueFrom:
                secretKeyRef:
                  name: instana-agent
                  key: downloadKey
                  optional: true
            - name: INSTANA_MVN_REPOSITORY_URL
              value: "https://artifact-public.instana.io"
            - name: ENABLE_AGENT_SOCKET
              value: "true"
            - name: INSTANA_AGENT_POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
          securityContext:
            privileged: true
          volumeMounts:
            - name: dev
              mountPath: /dev
              mountPropagation: HostToContainer
            - name: run
              mountPath: /run
              mountPropagation: HostToContainer
            - name: var-run
              mountPath: /var/run
              mountPropagation: HostToContainer
            - name: var-run-kubo
              mountPath: /var/vcap/sys/run/docker
              mountPropagation: HostToContainer
            - name: var-run-containerd
              mountPath: /var/vcap/sys/run/containerd
              mountPropagation: HostToContainer
            - name: var-containerd-config
              mountPath: /var/vcap/jobs/containerd/config
              mountPropagation: HostToContainer
            - name: sys
              mountPath: /sys
              mountPropagation: HostToContainer
            - name: var-log
              mountPath: /var/log
              mountPropagation: HostToContainer
            - name: var-lib
              mountPath: /var/lib
              mountPropagation: HostToContainer
            - name: var-data
              mountPath: /var/data
              mountPropagation: HostToContainer
            - name: machine-id
              mountPath: /etc/machine-id
            - name: configuration
              subPath: configuration.yaml
              mountPath: /root/configuration.yaml
            
            - name: configuration # TODO: These shouldn't have the same name
              subPath: configuration-disable-kubernetes-sensor.yaml
              mountPath: /opt/instana/agent/etc/instana/configuration-disable-kubernetes-sensor.yaml
            - name: configuration
              subPath: configuration-opentelemetry.yaml
              mountPath: /opt/instana/agent/etc/instana/configuration-opentelemetry.yaml
          livenessProbe:
            httpGet:
              host: 127.0.0.1 # localhost because Pod has hostNetwork=true
              path: /status
              port: 42699
            initialDelaySeconds: 600 # startupProbe isnt available before K8s 1.16
            timeoutSeconds: 5
            periodSeconds: 10
            failureThreshold: 3
          resources:
            requests:
              memory: "768Mi"
              cpu: 0.5
            limits:
              memory: "768Mi"
              cpu: 1.5
          ports:
            - containerPort: 42699
      volumes:
        - name: dev
          hostPath:
            path: /dev
        - name: run
          hostPath:
            path: /run
        - name: var-run
          hostPath:
            path: /var/run
        # Systems based on the kubo BOSH release (that is, VMware TKGI and older PKS) do not keep the Docker
        # socket in /var/run/docker.sock , but rather in /var/vcap/sys/run/docker/docker.sock .
        # The Agent images will check if there is a Docker socket here and, if so, adjust the symlinking before
        # starting the Agent. See https://github.com/cloudfoundry-incubator/kubo-release/issues/329
        - name: var-run-kubo
          hostPath:
            path: /var/vcap/sys/run/docker
            type: DirectoryOrCreate
        - name: var-run-containerd
          hostPath:
            path: /var/vcap/sys/run/containerd
            type: DirectoryOrCreate
        - name: var-containerd-config
          hostPath:
            path: /var/vcap/jobs/containerd/config
            type: DirectoryOrCreate
        - name: sys
          hostPath:
            path: /sys
        - name: var-log
          hostPath:
            path: /var/log
        - name: var-lib
          hostPath:
            path: /var/lib
        - name: var-data
          hostPath:
            path: /var/data
            type: DirectoryOrCreate
        - name: machine-id
          hostPath:
            path: /etc/machine-id
        - name: configuration
          configMap:
            name: instana-agent
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
rules:
- nonResourceURLs:
    - "/version"
    - "/healthz"
    - "/metrics"
    - "/stats/summary"
    - "/metrics/cadvisor"
  verbs: ["get"]
- apiGroups: [""]
  resources:
    - "nodes"
    - "nodes/stats"
    - "nodes/metrics"
    - "pods"
  verbs: ["get", "list", "watch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
subjects:
- kind: ServiceAccount
  name: instana-agent
  namespace: instana-agent
roleRef:
  kind: ClusterRole
  name: instana-agent
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: k8sensor
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
data:
  backend: "<INSTANA_ENDPOINT_HOST>"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8sensor
  namespace: instana-agent
  labels:
    app: k8sensor
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
spec:
  replicas: 3
  selector:
    matchLabels:
      app: k8sensor
      app.kubernetes.io/name: instana-agent-k8s-sensor
  template:
    metadata:
      labels:
        
        app: k8sensor
        app.kubernetes.io/name: instana-agent-k8s-sensor
        app.kubernetes.io/version: 1.2.74
        instana/agent-mode: KUBERNETES
      annotations:
        # To ensure that changes to agent.configuration_yaml or agent.additional_backends trigger a Pod recreation, we keep a SHA here
        # Unfortunately, we cannot use the lookup function to check on the values in the configmap, otherwise we break Helm < 3.2
        instana-configuration-hash: da39a3ee5e6b4b0d3255bfef95601890afd80709
    spec:
      serviceAccountName: k8sensor
      containers:
        - name: instana-agent
          image: "icr.io/instana/k8sensor:f8655ade0de93185ed65cc7e15ebdadb2bc075a7"
          imagePullPolicy: Always
          env:
            - name: AGENT_KEY
              valueFrom:
                secretKeyRef:
                  name: instana-agent
                  key: key
            - name: BACKEND
              valueFrom:
                configMapKeyRef:
                  name: k8sensor
                  key: backend
            - name: BACKEND_URL
              value: "https://$(BACKEND)"
            - name: AGENT_ZONE
              value: "<ZONE_NAME>"
            - name: POD_UID
              valueFrom:
                fieldRef:
                  fieldPath: metadata.uid
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: CONFIG_PATH
              value: /root
            

          volumeMounts:
            - name: configuration
              subPath: configuration.yaml
              mountPath: /root/configuration.yaml
          resources:
            requests:
              memory: "128Mi"
              cpu: 120m
            limits:
              memory: "2048Mi"
              cpu: 500m
          ports:
            - containerPort: 42699
      volumes:
        - name: configuration
          configMap:
            name: instana-agent
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: instana/agent-mode
                  operator: In
                  values:
                  - KUBERNETES
              topologyKey: kubernetes.io/hostname
            weight: 100
  minReadySeconds: 0
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8sensor
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
rules:
  -
    nonResourceURLs:
      - /version
      - /healthz
    verbs:
      - get
  -
    apiGroups:
      - extensions
    resources:
      - deployments
      - replicasets
      - ingresses
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - ""
    resources:
      - configmaps
      - events
      - services
      - endpoints
      - namespaces
      - nodes
      - pods
      - replicationcontrollers
      - resourcequotas
      - persistentvolumes
      - persistentvolumeclaims
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - apps
    resources:
      - daemonsets
      - deployments
      - replicasets
      - statefulsets
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - batch
    resources:
      - cronjobs
      - jobs
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - networking.k8s.io
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - ""
    resources:
      - pods/log
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - autoscaling
    resources:
      - horizontalpodautoscalers
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - apps.openshift.io
    resources:
      - deploymentconfigs
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - security.openshift.io
    resourceNames:
      - privileged
    resources:
      - securitycontextconstraints
    verbs:
      - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8sensor
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
roleRef:
  kind: ClusterRole
  name: k8sensor
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: k8sensor
    namespace: instana-agent
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8sensor
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
```

---

## Manifiesto OpenShift legacy

> Reemplazar los placeholders antes de aplicar. No publicar agent keys reales.

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: instana-agent
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
---
apiVersion: v1
kind: Service
metadata:
  name: instana-agent
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
spec:
  selector:
    app.kubernetes.io/name: instana-agent
  ports:
    # Prometheus remote_write, Trace Web SDK and other APIs
    - name: agent-apis
      protocol: TCP
      port: 42699
      targetPort: 42699
    
    # OpenTelemetry original default port
    - name: opentelemetry
      protocol: TCP
      port: 55680
      targetPort: 55680
    # OpenTelemetry as registered and reserved by IANA
    - name: opentelemetry-iana
      protocol: TCP
      port: 4317
      targetPort: 4317
    # OpenTelemetry HTTP port
    - name: opentelemetry-http
      protocol: TCP
      port: 4318
      targetPort: 4318
---
apiVersion: v1
kind: Service
metadata:
  name: instana-agent-headless
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
spec:
  clusterIP: None
  selector:
    app.kubernetes.io/name: instana-agent
  ports:
    # Prometheus remote_write, Trace Web SDK and other APIs
    - name: agent-apis
      protocol: TCP
      port: 42699
      targetPort: 42699
    
    # OpenTelemetry original default port
    - name: opentelemetry
      protocol: TCP
      port: 55680
      targetPort: 55680
    # OpenTelemetry as registered and reserved by IANA
    - name: opentelemetry-iana
      protocol: TCP
      port: 4317
      targetPort: 4317
    # OpenTelemetry HTTP port
    - name: opentelemetry-http
      protocol: TCP
      port: 4318
      targetPort: 4318
---
apiVersion: v1
kind: Secret
metadata:
  name: instana-agent
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
type: Opaque
data:
  key: "<BASE64_AGENT_KEY>" # Reemplazar por el agent key de Instana codificado en base64
  downloadKey: "<BASE64_DOWNLOAD_KEY_OR_AGENT_KEY>"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: instana-agent
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
data:
  cluster_name: "<CLUSTER_NAME>"
  configuration.yaml: |
  
    # Manual a-priori configuration. Configuration will be only used when the sensor
    # is actually installed by the agent.
    # The commented out example values represent example configuration and are not
    # necessarily defaults. Defaults are usually 'absent' or mentioned separately.
    # Changes are hot reloaded unless otherwise mentioned.
    
    # It is possible to create files called 'configuration-abc.yaml' which are
    # merged with this file in file system order. So 'configuration-cde.yaml' comes
    # after 'configuration-abc.yaml'. Only nested structures are merged, values are
    # overwritten by subsequent configurations.
    
    # Secrets
    # To filter sensitive data from collection by the agent, all sensors respect
    # the following secrets configuration. If a key collected by a sensor matches
    # an entry from the list, the value is redacted.
    #com.instana.secrets:
    #  matcher: 'contains-ignore-case' # 'contains-ignore-case', 'contains', 'regex'
    #  list:
    #    - 'key'
    #    - 'password'
    #    - 'secret'
    
    # Host
    #com.instana.plugin.host:
    #  tags:
    #    - 'dev'
    #    - 'app1'
    
    # Hardware & Zone
    com.instana.plugin.generic.hardware:
      enabled: true # disabled by default
      availability-zone: '<ZONE_NAME>'
    

  
  configuration-opentelemetry.yaml: |
    com.instana.plugin.opentelemetry: 
      grpc:
        enabled: true
      http:
        enabled: true
  
  configuration-disable-kubernetes-sensor.yaml: |
    com.instana.plugin.kubernetes:
      enabled: false
---
# TODO: Combine into single template with agent-daemonset-with-zones.yaml---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: instana-agent
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: instana-agent
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  minReadySeconds: 0
  template:
    metadata:
      labels:
        app.kubernetes.io/name: instana-agent
        app.kubernetes.io/version: 1.2.74
        instana/agent-mode: "APM"
      annotations:
        # To ensure that changes to agent.configuration_yaml or agent.additional_backends trigger a Pod recreation, we keep a SHA here
        # Unfortunately, we cannot use the lookup function to check on the values in the configmap, otherwise we break Helm < 3.2
        instana-configuration-hash: 70c6df6d7c1a99a22ee74d59fa7f300fe6432573
    spec:
      serviceAccountName: instana-agent
      hostNetwork: true
      hostPID: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: instana-agent
          image: "icr.io/instana/agent:latest"
          imagePullPolicy: Always
          env:
            - name: INSTANA_AGENT_LEADER_ELECTOR_PORT
              value: "42655"
            - name: INSTANA_ZONE
              value: "<ZONE_NAME>"
            - name: INSTANA_KUBERNETES_CLUSTER_NAME
              valueFrom:
                configMapKeyRef:
                  name: instana-agent
                  key: cluster_name
            - name: INSTANA_AGENT_ENDPOINT
              value: "<INSTANA_ENDPOINT_HOST>"
            - name: INSTANA_AGENT_ENDPOINT_PORT
              value: "443"
            - name: INSTANA_AGENT_KEY
              valueFrom:
                secretKeyRef:
                  name: instana-agent
                  key: key
            - name: INSTANA_DOWNLOAD_KEY
              valueFrom:
                secretKeyRef:
                  name: instana-agent
                  key: downloadKey
                  optional: true
            - name: INSTANA_MVN_REPOSITORY_URL
              value: "https://artifact-public.instana.io"
            - name: ENABLE_AGENT_SOCKET
              value: "true"
            - name: INSTANA_AGENT_POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
          securityContext:
            privileged: true
          volumeMounts:
            - name: dev
              mountPath: /dev
              mountPropagation: HostToContainer
            - name: run
              mountPath: /run
              mountPropagation: HostToContainer
            - name: var-run
              mountPath: /var/run
              mountPropagation: HostToContainer
            - name: sys
              mountPath: /sys
              mountPropagation: HostToContainer
            - name: var-log
              mountPath: /var/log
              mountPropagation: HostToContainer
            - name: var-lib
              mountPath: /var/lib
              mountPropagation: HostToContainer
            - name: var-data
              mountPath: /var/data
              mountPropagation: HostToContainer
            - name: machine-id
              mountPath: /etc/machine-id
            - name: configuration
              subPath: configuration.yaml
              mountPath: /root/configuration.yaml
            
            - name: configuration # TODO: These shouldn't have the same name
              subPath: configuration-disable-kubernetes-sensor.yaml
              mountPath: /opt/instana/agent/etc/instana/configuration-disable-kubernetes-sensor.yaml
            - name: configuration
              subPath: configuration-opentelemetry.yaml
              mountPath: /opt/instana/agent/etc/instana/configuration-opentelemetry.yaml
          livenessProbe:
            httpGet:
              host: 127.0.0.1 # localhost because Pod has hostNetwork=true
              path: /status
              port: 42699
            initialDelaySeconds: 600 # startupProbe isnt available before K8s 1.16
            timeoutSeconds: 5
            periodSeconds: 10
            failureThreshold: 3
          resources:
            requests:
              memory: "768Mi"
              cpu: 0.5
            limits:
              memory: "768Mi"
              cpu: 1.5
          ports:
            - containerPort: 42699
      volumes:
        - name: dev
          hostPath:
            path: /dev
        - name: run
          hostPath:
            path: /run
        - name: var-run
          hostPath:
            path: /var/run
        - name: sys
          hostPath:
            path: /sys
        - name: var-log
          hostPath:
            path: /var/log
        - name: var-lib
          hostPath:
            path: /var/lib
        - name: var-data
          hostPath:
            path: /var/data
            type: DirectoryOrCreate
        - name: machine-id
          hostPath:
            path: /etc/machine-id
        - name: configuration
          configMap:
            name: instana-agent
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
rules:
- nonResourceURLs:
    - "/version"
    - "/healthz"
    - "/metrics"
    - "/stats/summary"
    - "/metrics/cadvisor"
  verbs: ["get"]
  apiGroups: []
  resources: []
- apiGroups: [""]
  resources:
    - "nodes"
    - "nodes/stats"
    - "nodes/metrics"
    - "pods"
  verbs: ["get", "list", "watch"]
- apiGroups: ["security.openshift.io"]
  resourceNames: ["privileged"]
  resources: ["securitycontextconstraints"]
  verbs: ["use"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
subjects:
- kind: ServiceAccount
  name: instana-agent
  namespace: instana-agent
roleRef:
  kind: ClusterRole
  name: instana-agent
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: k8sensor
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
data:
  backend: "<INSTANA_ENDPOINT_HOST>"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8sensor
  namespace: instana-agent
  labels:
    app: k8sensor
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
spec:
  replicas: 3
  selector:
    matchLabels:
      app: k8sensor
      app.kubernetes.io/name: instana-agent-k8s-sensor
  template:
    metadata:
      labels:
        
        app: k8sensor
        app.kubernetes.io/name: instana-agent-k8s-sensor
        app.kubernetes.io/version: 1.2.74
        instana/agent-mode: KUBERNETES
      annotations:
        # To ensure that changes to agent.configuration_yaml or agent.additional_backends trigger a Pod recreation, we keep a SHA here
        # Unfortunately, we cannot use the lookup function to check on the values in the configmap, otherwise we break Helm < 3.2
        instana-configuration-hash: da39a3ee5e6b4b0d3255bfef95601890afd80709
    spec:
      serviceAccountName: k8sensor
      containers:
        - name: instana-agent
          image: "icr.io/instana/k8sensor:f8655ade0de93185ed65cc7e15ebdadb2bc075a7"
          imagePullPolicy: Always
          env:
            - name: AGENT_KEY
              valueFrom:
                secretKeyRef:
                  name: instana-agent
                  key: key
            - name: BACKEND
              valueFrom:
                configMapKeyRef:
                  name: k8sensor
                  key: backend
            - name: BACKEND_URL
              value: "https://$(BACKEND)"
            - name: AGENT_ZONE
              value: "<ZONE_NAME>"
            - name: POD_UID
              valueFrom:
                fieldRef:
                  fieldPath: metadata.uid
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: CONFIG_PATH
              value: /root
            

          volumeMounts:
            - name: configuration
              subPath: configuration.yaml
              mountPath: /root/configuration.yaml
          resources:
            requests:
              memory: "128Mi"
              cpu: 120m
            limits:
              memory: "2048Mi"
              cpu: 500m
          ports:
            - containerPort: 42699
      volumes:
        - name: configuration
          configMap:
            name: instana-agent
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: instana/agent-mode
                  operator: In
                  values:
                  - KUBERNETES
              topologyKey: kubernetes.io/hostname
            weight: 100
  minReadySeconds: 0
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8sensor
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
rules:
  -
    nonResourceURLs:
      - /version
      - /healthz
    verbs:
      - get
  -
    apiGroups:
      - extensions
    resources:
      - deployments
      - replicasets
      - ingresses
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - ""
    resources:
      - configmaps
      - events
      - services
      - endpoints
      - namespaces
      - nodes
      - pods
      - replicationcontrollers
      - resourcequotas
      - persistentvolumes
      - persistentvolumeclaims
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - apps
    resources:
      - daemonsets
      - deployments
      - replicasets
      - statefulsets
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - batch
    resources:
      - cronjobs
      - jobs
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - networking.k8s.io
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - ""
    resources:
      - pods/log
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - autoscaling
    resources:
      - horizontalpodautoscalers
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - apps.openshift.io
    resources:
      - deploymentconfigs
    verbs:
      - get
      - list
      - watch
  -
    apiGroups:
      - security.openshift.io
    resourceNames:
      - privileged
    resources:
      - securitycontextconstraints
    verbs:
      - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8sensor
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
roleRef:
  kind: ClusterRole
  name: k8sensor
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: k8sensor
    namespace: instana-agent
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8sensor
  namespace: instana-agent
  labels:
    app.kubernetes.io/name: instana-agent
    app.kubernetes.io/version: 1.2.74
```

---

## Referencias

- IBM Instana Observability - Installing the agent on Kubernetes: https://www.ibm.com/docs/en/instana-observability?topic=kubernetes-installing-agent
- IBM/Instana Helm chart - Configuration reference: https://github.com/instana/helm-charts/tree/main/instana-agent
- Kubernetes - Pull an image from a private registry: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
- Kubernetes - Images and `imagePullSecrets`: https://kubernetes.io/docs/concepts/containers/images/
- Red Hat OpenShift - Pull secrets in workloads: https://docs.redhat.com/en/documentation/openshift_container_platform/4.16/html/images/managing-images
- Red Hat OpenShift - Additional trusted CA for image registries: https://docs.redhat.com/en/documentation/openshift_container_platform/4.9/html/images/image-configuration
