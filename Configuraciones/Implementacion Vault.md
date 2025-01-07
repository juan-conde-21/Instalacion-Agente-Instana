# Implementacion Vault Community

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

   Ejemplo de ejecucion:

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

6. Editar el archivo de configuracion de Vault.

       vi /etc/vault.d/vault.hcl




##Creacion del certificado autofirmado para vault
cd /opt/vault/tls/

