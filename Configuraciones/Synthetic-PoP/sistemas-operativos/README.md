# Preparación por sistema operativo

[← Volver al índice principal](../README.md)  
**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/sistemas-operativos/README.md`  
**Paso anterior:** [Consideraciones generales](../00-consideraciones-generales.md)  
**Siguiente paso:** elegir [ruta online](../online/README.md) o [ruta air-gapped](../airgap/README.md)

## Objetivo

Preparar el servidor Linux donde se instalará k3s, Helm y Synthetic PoP.

El sistema operativo impacta principalmente en:

- instalación de paquetes base;
- firewall;
- SELinux o UFW;
- NetworkManager;
- módulos del kernel;
- configuración de forwarding;
- validaciones previas a k3s.

Una vez que k3s y Helm quedan operativos, el despliegue del Synthetic PoP se realiza de manera similar en todos los sistemas operativos mediante Helm.

## Elegir documento

| Sistema operativo del cliente | Documento a revisar | Comentario |
|---|---|---|
| Red Hat Enterprise Linux 8.x | [rhel-8.md](rhel-8.md) | Incluir validación especial si es RHEL 8.1. |
| Red Hat Enterprise Linux 9.x | [rhel-9.md](rhel-9.md) | Base recomendada para despliegues RHEL actuales. |
| Red Hat Enterprise Linux 10.x | [rhel-10.md](rhel-10.md) | Requiere validaciones adicionales de módulos. |
| Ubuntu 22.04 / 24.04 | [ubuntu-22-24.md](ubuntu-22-24.md) | Usar cuando el cliente trabaja con Ubuntu LTS. |
| CentOS / Rocky / Alma | [centos-rocky-alma.md](centos-rocky-alma.md) | Similar a RHEL, sujeto a validación del cliente. |

## Comandos comunes de identificación

Ejecutar siempre al inicio:

```bash
cat /etc/os-release
uname -r
hostnamectl
ip addr
ip route
```

Guardar la salida como evidencia.

## Validación de salida de red

En instalación online, validar acceso a Internet:

```bash
curl -I https://get.k3s.io
curl -I https://get.helm.sh
curl -I https://agents.instana.io/helm
```

En instalación air-gapped, estos comandos no son obligatorios en el servidor destino, pero sí deben validarse en la máquina online donde se construirá el bundle.

## Siguiente paso

Después de preparar el sistema operativo:

- si el servidor tiene Internet, continuar con [Instalación online](../online/README.md);
- si el servidor no tiene Internet, continuar con [Instalación air-gapped](../airgap/README.md).
