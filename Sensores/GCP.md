
### Procedimiento para Integrar Instana con Google Cloud Platform


1. Acceder a la consola de Google Cloud Platform e ingresar al modulo de Roles.

   ![image](https://github.com/user-attachments/assets/b29c45ee-f787-4696-bd7b-c5da86d81745)

2. Crear un rol dedicado para Instana y brindar los permisos para los servicios a consultar mediante la integracion.

   ![image](https://github.com/user-attachments/assets/382d0b80-da36-45ec-b071-0f6ba000adcf)

3. Acceder al módulo APIs & Services en la consola de Google Cloud Platform y, desde la opción Credentials, crear la cuenta de servicio (Service Account) que se utilizará para establecer la conexión entre el agente de Instana y GCP.

   ![image](https://github.com/user-attachments/assets/4405991b-beaf-4fa5-aee4-2911e6cecd56)

4. Seguir los siguiente pasos para crear el service account y asignar el rol creado en los pasos anteriores

   ![image](https://github.com/user-attachments/assets/44f2210c-0070-403f-a3b1-901571a2a535)

   ![image](https://github.com/user-attachments/assets/bdd3ac32-81cd-4ac1-8cf8-ddee19f78416)

   ![image](https://github.com/user-attachments/assets/7e397186-458a-4c5e-9ae2-0fdc8278ff88)

   ![image](https://github.com/user-attachments/assets/ae80d64c-fc73-48c7-b452-9b231b04c972)

   ![image](https://github.com/user-attachments/assets/1e39f54c-a80c-46b8-be0e-0e1771306622)

   ![image](https://github.com/user-attachments/assets/e9f59710-324b-488a-bd6a-4b67dec6d5f4)

5. Luego ingresar al service account creado en el paso anterior y generar una llave (Key) para el acceso desde el agente Instana.

   ![image](https://github.com/user-attachments/assets/f413cf92-6219-41ed-b8a3-278d04865275)

   ![image](https://github.com/user-attachments/assets/b6be1c41-1a9a-461d-a004-b9511080b3f2)

6. Se descargara el key en formato json que luego se subira al servidor donde se configurara el sensor de GCP.
   
   ![image](https://github.com/user-attachments/assets/65402f3b-a1a8-472d-8de8-a820d2d9ec8f)


7. Ingresar al archivo de configuracion del agente Instana y completar los campos segun corresponda, se utilizara el archivo json descargado en el paso anterior.

   ![image](https://github.com/user-attachments/assets/147052e3-5866-4494-bba6-fcf94ec4b1c4)

   *Es importante tener en cuenta que, para realizar consultas a los servicios de GCP mediante API, primero se debe habilitar la API correspondiente para cada servicio que se desea consultar, incluyendo la API "Cloud Resource Manager API".
   *Verificar a nivel de logs del agente Instana los errores a nivel de conexion via API con GCP.

8. Verificar en la consola de Instana los servicios integrados.

   ![image](https://github.com/user-attachments/assets/2a8dfd92-939e-4ccd-bdeb-4a8a99a548c8)

















