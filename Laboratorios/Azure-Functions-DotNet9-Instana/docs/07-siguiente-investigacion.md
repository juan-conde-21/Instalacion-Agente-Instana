# Siguiente investigación

La investigación está congelada para presentación. Al reabrirla, el orden recomendado es:

1. Obtener el digest exacto de la imagen usada originalmente y registrar su procedencia.
2. Recuperar o recrear de forma verificable Debian 11/glibc 2.31 con ese digest.
3. Identificar la versión exacta del tracer introducida por AutoTrace webhook 1.322.1; no inferirla por el número del chart.
4. Repetir primero en Docker con runtime, imagen y tracer exactos.
5. Completar la reducción A0/A1/A2/B para separar IL ordinario, estructura de clases y metadata/atributos Functions.
6. Sólo después trasladar el caso controlado a Kubernetes, OpenShift o AKS y reproducir AutoTrace.

Punto de reanudación del código actual: **Phase 16 — rebuild and execute A0/A1/A2/B matrix**, usando A0 como baseline exacto. Las imágenes de esa fase no existen y deben reconstruirse desde Git.
