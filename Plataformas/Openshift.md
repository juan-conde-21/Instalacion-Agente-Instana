# Instalacion Agente Instana Openshift

Instalar Operador Instana en cluster Openshift y desplegar la instancia de InstanaAgent

1. Buscar el operador de Instana en el operator hub de la consola de Openshift.

  ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/63ef820c-a888-41b8-b6d5-2824014fd8ee)

2. Seleccionar Install

  ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/09d89b0b-7fd5-41ce-8322-6be4ac05e2f9)


3. Seleccionar el namespace donde se desplegara el operador y proceder con la instalacion. 

  ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/60df4e0f-71b6-4946-84c9-2eeaa61aeb6b)


4. Se mostrará el progreso de la instalacion.

  ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/adf24413-eaf2-43d9-9883-742210d7d7a9)

5. Completada la instalacion procedemos a ingresar al operador.

  ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/fb37fb51-9279-481f-b2cb-a0c14247d39e)

6. Crear el namespace instana-agent  y asignar los privilegios para el service account utilizado por el agente, realizar estos pasos a nivel de linea de comandos. (Se muestran los resultados de los comandos ejecutados)

   Ejecutar el comando: "oc new-project instana-agent"

        λ oc new-project instana-agent
        Already on project "instana-agent" on server "https://api.663b9ca38a5bcb001ed3b58e.cloud.techzone.ibm.com:6443".
        
        You can add applications to this project with the 'new-app' command. For example, try:
        
            oc new-app rails-postgresql-example
        
        to build a new example application in Ruby. Or use kubectl to deploy a simple Kubernetes application:
        
            kubectl create deployment hello-node --image=registry.k8s.io/e2e-test-images/agnhost:2.43 -- /agnhost serve-hostname

   Ejecutar el comando: "oc adm policy add-scc-to-user privileged -z instana-agent"

        λ oc adm policy add-scc-to-user privileged -z instana-agent
        clusterrole.rbac.authorization.k8s.io/system:openshift:scc:privileged added: "instana-agent"

7. Crear la instancia de InstanaAgent seleccionando la opcion mostrada.

  ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/d9babf13-c4ef-4210-96e9-2dc9417f7041)

8. Completar los datos de acuerdo con la siguiente plantilla de ejemplo yaml.

  ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/0933afe2-9b95-4fed-9535-65b24230e045)

   Plantilla Ejemplo:

        apiVersion: instana.io/v1
        kind: InstanaAgent
        metadata:
          name: instana-agent
          namespace: instana-agent
        spec:
          zone:
            name: cp4i
          cluster:
            name: cp4i-demo
          agent:
            key: O4234JKSDFJKDSF234j
            endpointHost: ingress-coral-saas.instana.io
            endpointPort: "443"
            env:
              INSTANA_AGENT_TAGS: cp4i
            configuration_yaml: |
              # You can leave this empty, or use this to configure your instana agent.
              # See https://ibm.biz/monitoring-k8s
              com.instana.plugin.opentelemetry:
                 grpc:
                    enabled: true
                 http:
                    enabled: true


   Plantila base

        apiVersion: instana.io/v1
        kind: InstanaAgent
        metadata:
          name: instana-agent
          namespace: instana-agent
        spec:
          zone:
            name: my-zone # (optional) nombre de la zona del agente
          cluster:
            name: cluster-name # nombre del Kubernetes cluster
          agent:
            key: replace-me # colocar el Instana agent key
            endpointHost: ingress-red-saas.instana.io # colocar el ingress endpoint
            endpointPort: "443" # ingress endpoint port, en comillas dobles
            configuration_yaml: |
              # You can leave this empty, or use this to configure your instana agent.
              # See https://ibm.biz/monitoring-k8s
              com.instana.plugin.opentelemetry:
                 grpc:
                    enabled: true
                 http:
                    enabled: true

9. Se creará la instancia de InstanaAgent, luego ingresar a la instancia para ver los detalles.

  ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/8842e74b-edac-4581-8f25-7e811d04b3b3)


10. En la seccion Resources se mostrarán los recursos desplegados, donde validaremos que el estado de los pods sea running.

  ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/3739b905-fc8c-4d63-8d30-4e9e1728352c)

11. Validar en el modulo de Platform - Kubernetes de la consola de Instana.

  ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/9e2f3fbf-568a-4701-bf3f-75470e857e11)

  ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/931a6c93-991e-4023-95b2-c35305810c58)


12. Configuración adicional para exponer los puertos de opentelemtry a nivel del servicio de kubernetes.


    Comando para editar la configuración del servicio:

        oc edit svc instana-agent -n instana-agent

    Agregar la siguiente sección en los puertos expuestos:

        - name: otlp-grpc
          port: 4317
          protocol: TCP
          targetPort: otlp-grpc
        - name: otlp-http
          port: 4318
          protocol: TCP
          targetPort: otlp-http

    La configuración debe quedar de la siguiente manera:

    ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/926e59d4-389d-4af2-b044-e49ab230e82c)


13. Verificar los puertos expuestos a nivel de servicio de instana-agent.

    Ejecutar el siguiente comando:

        oc get svc -n instana-agent

    Verificar el resultado:

        λ oc get svc -n instana-agent
        NAME                     TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                       AGE
        instana-agent            ClusterIP   172.30.1.50   <none>        42699/TCP,4317/TCP,4318/TCP   9m
        instana-agent-headless   ClusterIP   None          <none>        42699/TCP                     9m





