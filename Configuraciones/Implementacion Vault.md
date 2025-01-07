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






##Creacion del certificado autofirmado para vault
cd /opt/vault/tls/

