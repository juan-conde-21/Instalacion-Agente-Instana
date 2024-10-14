
## Gestión de Configuración para Agentes Instana con GitLab

## Prerrequisitos

1. Agente Instana Desplegado.
2. Repositorio GitLab creado.
3. Creadenciales para el acceso al repositorio GitLab (usuario/Personal Access Token)
4. Instana Api Token con permiso "Configuration of agents".


## Creación de Repositorio en GitLab

Crear el repositorio con la siguiente estructura.

    repository-root/
    ├── instana/
    │   ├── configuration.yaml


## Configuración de Repositorio Privado en GitLab

1. Ingresar a la ruta de las variables de entorno del agente Instana.

       cd /opt/instana/agent/bin
       vi setenv

2. Agregar las siguientes variables de entorno. (Ajustar los valores dependiendo del ambiente GitLab)

       export INSTANA_GIT_REMOTE_REPOSITORY=http://192.168.168.1/instana/instana-config-linux.git
       export INSTANA_GIT_REMOTE_BRANCH=main
       export INSTANA_GIT_REMOTE_USERNAME=instana
       export INSTANA_GIT_REMOTE_PASSWORD=glpat-3U1-7RxC25xfovAr_rvr

3. Reiniciar el agente Instana.

   Linux
   
       systemctl restart instana-agent


## Configurar Hooks en GitLab

1. Ingresar a la ruta correspondiente al repositorio git dentro del servidor Gitlab.

   Ejecutar el comando de busqueda del repositorio mediante el comando grep utilizando el commit SHA del repositorio.

       grep -lr "3fa668a6aa686413d0d8ac8d6cff2874e400" /var/opt/gitlab/

   Ingresar a la ruta del repositorio, ejemplo:

       cd /var/opt/gitlab/git-data/repositories/@hashed/d4/73/d4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35.git

2. Crear el archivo para la conexión al backend de Instana.

       vi instana-backend

   Agregar el siguiente contenido al archivo modificando de acuerdo con los datos del tenant Instana a utilizar.

       INSTANA_API_ENDPOINT=https://tenant-unit.instana.io
       INSTANA_API_TOKEN=bdkro6SEOcINqc6S8wQg
       INSTANA_AGENT_ZONE='Linux Produccion'
       
3. Crear la carpeta "custom_hooks"

       mkdir custom_hooks
       cd custom_hooks

5. Descargar el script ([Descargar](https://github.com/juan-conde-21/Instalacion-Agente-Instana/blob/main/Gitlab/post-receive)) que realizará la invocación al API de Instana cada vez que se realice un commit en el repositorio.

       







