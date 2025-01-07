# Implementacion Vault Community

## Instalación de Vault

1. Instalar Vault con permisos de root.

   Ubuntu:
   
       wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
       echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
       apt update && sudo apt install vault

   Red Hat / Centos:

       yum install -y yum-utils
       yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
       yum -y install vault


2. Ingresar a la ruta de configuracion de Vault, y verificar que la carpeta tls se encuentre creada, caso contrario proceder a crear como se muestra.

       cd /opt/vault/
       mkdir tls
       chown vault:vault tls

3. Generar un certificado autofirmado con los datos del servidor donde se instalo Vault.

   Ejecutar el siguiente comando modificando el nombre del {hostname}:

       openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /opt/vault/tls/vault.key \
        -out /opt/vault/tls/vault.crt \
        -subj "/C=US/ST=State/L=City/O=MyOrg/OU=VaultServer/CN={hostname}" \
        -addext "subjectAltName=DNS:{hostname}"

   Ejemplo de ejecucion modificando el hostname:

       openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
           -keyout /opt/vault/tls/vault.key \
           -out /opt/vault/tls/vault.crt \
           -subj "/C=US/ST=State/L=City/O=MyOrg/OU=VaultServer/CN=rh8-server" \
           -addext "subjectAltName=DNS:rh8-server"

4. Agregar la referencia del hostname en el archivo hosts del servidor.

       vi /etc/hosts

   Ejemplo de verificacion:

       192.168.68.61 rh8-server
   
5. Agregar permisos para el nuevo certificado creado.

       cd /opt/vault/tls/
       chown vault:vault vault.*
       chmod 644 vault.*

6. Editar el archivo de configuracion de Vault y modificar el nombre de los certificados generados en el paso 3, se muestra una imagen con un ejemplo de la configuración.

       vi /etc/vault.d/vault.hcl

   ![image](https://github.com/user-attachments/assets/8a830e88-70bd-4e0c-b7cb-9460b6354f2e)

  
       # HTTPS listener
       listener "tcp" {
         address       = "0.0.0.0:8200"
         tls_cert_file = "/opt/vault/tls/vault.crt"
         tls_key_file  = "/opt/vault/tls/vault.key"
       }


7. Exportar las variables de entorno para el acceso a Vault

   - Variable para especificar la ubicacion del certificado a utilizar.

         export VAULT_CACERT=/opt/vault/tls/vault.crt

   - Variable para especificar la URL de conexion a Vault, utilizar el hostname registrado en la configuracion del paso 3. (Para este ejemplo rh8-server)

         export VAULT_ADDR=https://rh8-server:8200

   **Nota:** Estas variables deben estar configuradas a nivel del perfil del usuario root para garantizar su disponibilidad en futuras sesiones. De lo contrario, será necesario exportarlas manualmente en la shell actual para acceder a Vault.

       vi ~/.bashrc
       export VAULT_CACERT=/opt/vault/tls/vault.crt
       export VAULT_ADDR=https://hostname:8200

9. Reiniciar los servicios de Vault y verificar su estado.

   Ejecutar los comandos:
   
       systemctl restart vault
       systemctl status vault

   Ejemplo de ejecución:

   ![image](https://github.com/user-attachments/assets/48c344c1-7a0a-4574-a00a-292404be4adb)

10. Verifique el estado de Vault, el cual mostrará, por defecto, que no está inicializado (Initialized: false) y que se encuentra sellado (Sealed: true).
   
    Ejecutar comando:

        vault status

    Ejemplo de ejecución:

    ![image](https://github.com/user-attachments/assets/af65c702-6a45-47ed-813b-5497fa198d5e)

    En este punto la instalación finalizó correctamente.
    
## Configuración de Vault

1. Después de confirmar que Vault no está inicializado (Initialized: false) y que se encuentra sellado (Sealed: true), procederemos a configurarlo utilizando el comando de inicialización.

   Ejecutar comando:

       vault operator init

   Ejemplo de ejecución:

   ![image](https://github.com/user-attachments/assets/83dcb740-306a-4558-92da-f3aa38e02ce9)

   Este comando genera las claves de desellado y el token raíz necesarios para operar Vault. La salida del comando incluye información crítica que debe ser almacenada de manera segura.

   - Claves de desellado (Unseal Keys):

     Vault genera varias claves de desellado (en este caso, 5) como parte del mecanismo de seguridad. Estas claves se comparten entre los administradores del sistema y se requieren al menos 3 de ellas (umbral configurado) para desellar Vault en caso        de reinicio o apagado.

   - Token raíz (Initial Root Token):

     Se genera un token raíz único que se utiliza para realizar operaciones administrativas iniciales en Vault.

2. Luego de generar y guardar las credenciales del punto anterior, procederemos a verificar nuevamente el estado de Vault.

   Ejecutar comando:

       vault status

   ![image](https://github.com/user-attachments/assets/cbd303b0-0b7d-42f7-aebc-9b91f8d50202)

   Verificamos que Vault se encuentra inicializado pero mantiene el estado sellado (Sealed true).

3. Procedemos a retirar el sello de Vault, para lo cual necesitaremos ingresar al menos 3 claves de desellado.

   Ejecutar comando:

       vault operator unseal

   Ejemplo de ejecución:

   ![image](https://github.com/user-attachments/assets/af9fb4e2-41c5-4402-be42-abf0dad1abff)

   Al ingresar el comando, se solicitará introducir una de las claves de desellado generadas en el paso 1. La clave ingresada no será visible en pantalla por motivos de seguridad. Una vez escrita la clave, presione la tecla Enter.

   Después de ingresar la clave, Vault mostrará el estado de sellado y el progreso del proceso de desellado en relación con el total de claves requeridas. En este ejemplo, se necesitan tres claves, por lo que deberá repetir este procedimiento hasta       completar el progreso, ingresando las claves restantes.

4. Completado el proceso de desellado se mostrara el estado Sealed false.

   ![image](https://github.com/user-attachments/assets/37cd04b4-d033-4ef1-8481-5b9e57cdb3b9)

5. Autenticase con el token raíz generado en el punto 1.

   Ejecutar comando:

       vault login

   Ejemplo de ejecución:

   ![image](https://github.com/user-attachments/assets/f34391de-0e02-495d-9702-283643839d4c)

6. Luego de realizar la configuración inicial procederemos a habilitar el motor de secretos KV version 2.

   Ejecutar comando:

       vault secrets enable -path=operaciones -version=2 kv

   Se está habilitando un motor de secretos KV (Key-Value) en la ruta personalizada operaciones, con la versión 2 del motor KV. Esto significa que todos los secretos almacenados en esta ruta estarán organizados bajo el path **operaciones**, lo que        facilita su gestión y acceso en entornos con múltiples equipos o aplicaciones.

   En resumen, el path actúa como un identificador lógico para agrupar y acceder a datos dentro de Vault de forma segura y estructurada.

   Ejemplo de ejecución:

   ![image](https://github.com/user-attachments/assets/345a8068-5910-41d2-81e3-d0a18dce696a)


8. Creacion de secreto utilizando el path creado en el punto anterior.

   Ejecutar comando:

       vault kv put operaciones/database password='P4ssw0rd$$'

   El secreto password='P4ssw0rd$$' quedará almacenado en Vault bajo la ruta operaciones/database. Este secreto podrá ser recuperado o gestionado posteriormente.

   Ejemplo de ejecución:

   ![image](https://github.com/user-attachments/assets/94505bb5-1b2a-4338-8cb8-dcee3d34b59c)

9. Creación de política para el acceso al secreto creado.

   - Definir el archivo con la estructura del path y nivel de acceso al secreto.

         vi politica.hcl

         path "operaciones/data/database" {
           capabilities = ["read"]
         }

   - Crear la politica ejecutando el siguiente comando.

         vault policy write bd-mysql politica.hcl

   Ejemplo de ejecución:

   ![image](https://github.com/user-attachments/assets/41e211c8-4da1-4a36-aeee-a58af98479eb)

10. Habilitar el método de autenticación de tipo AppRole, luego se utilizará para un servicio externo por ejemplo el agente Instana.

    Ejecutar comando:

        vault auth enable approle

    Ejemplo de ejecución:

    ![image](https://github.com/user-attachments/assets/88a1f103-8f8d-4c45-bc24-f147f8b34ccb)

11. Crear nuevo método de autenticación AppRole para el agente Instana con el nombre instana-mysql y asignar la politica bd-mysql, luego listar el approle creado.

    Ejecutar comando:

        vault write auth/approle/role/instana-mysql policies=bd-mysql
        vault list auth/approle/role

    Ejemplo de ejecución:

    ![image](https://github.com/user-attachments/assets/36dabdaf-b441-4a79-af04-3cbe9d5c6692)


12. Después de crear el AppRole para Instana, será necesario obtener el role-id y el secret-id generados para dicho AppRole. Estos valores serán utilizados posteriormente para configurar el acceso seguro a Vault.

    Ejecutar comando:

        vault read auth/approle/role/instana-mysql/role-id
        vault write -force auth/approle/role/instana-mysql/secret-id

    Ejemplo de ejecución:

    ![image](https://github.com/user-attachments/assets/8ef509cb-899b-4567-b5e5-3850785ebb95)

13. Se muestra un ejemplo de integración desde un agente Instana con el servidor Vault configurado en esta guía.

    Se debe copiar el certificado generado en el servidor vault "/opt/vault/tls/vault.crt" en el servidor donde se configurará el agente Instana y asignarle los permisos de lectura para el usuario que ejecuta el agente Instana.

    ![image](https://github.com/user-attachments/assets/bfffb94e-eef8-4257-ac3f-a2a5e6ccad1e)

    Ejemplo archivo de configuración:
   
        com.instana.configuration.integration.vault:
          connection_url: https://rh8-server:8200 # The address (URL) of the Vault server instance(e.g. http://127.0.0.1:8200 or https://exapmle.com:8200)
        #  prefix: <optional_prefix> # Optional prefix path required if kv_version 2 is used and the /data/ must be injected further down
        #  token: <vault_access_token> # Vault access token with assigned, at least, `read` access policy to relevant Vault paths, optional if other auth providers are present
        #  github: # Optional auth method if Vault access token is not provided, has higher priority than approle if present
        #    github_token: <github_token> # Personal Access Token, must provide at least read:org scope, must be present if github is used as an auth provider
        #    auth_mount: github # Optional mount path for GitHub Auth, defaults to github
          approle: # Optional auth method if Vault access token or github auth is not provided
            role_id: f307b292-2721-a06b-c8fb-6627a8a7bc4b # AppRole RoleId, must be present if approle is used as an auth provider
            secret_id: a90b9adf-9c9a-afae-a7c7-76fa2fcb93c9 # AppRole SecretId, must be present if approle is used as an auth provider
            auth_mount: approle # Optional mount path for AppRole Auth, defaults to approle
          path_to_pem_file: /home/juanconde/vault.crt # X.509 CA certificate (UTF8 encoded) in unencrypted PEM format, used by the Agent when communicating with Vault over HTTPS
        #  secret_refresh_rate: 24 # This configuration option allows you to account for rotating credentials, refresh rate in hours, default 24
          kv_version: 2 # The Key/Value secrets engine version, default is 2


    Evidencia en agente Instana:
   
    ![image](https://github.com/user-attachments/assets/5d4ebf89-ae9c-4f52-80b9-c1a93b35ae1d)

14. Ejemplo de sensor Instana utilizando el secreto creado en esta guía. (Se utiliza el sensor de Mysql)

    Ejemplo archivo de configuración:

        # Mysql
        com.instana.plugin.mysql:
          user: 'root'
          password:
             configuration_from:
               type: vault
               secret_key:
                 path: operaciones/database
                 key: password

    Evidencia en agente Instana:
    
    ![image](https://github.com/user-attachments/assets/cb0b3740-a62a-47dc-ba48-17deb6817a1a)

 

