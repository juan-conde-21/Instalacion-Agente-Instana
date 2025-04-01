
### Desplegar Traceloop

1. Instalar traceloop

	pip install traceloop-sdk

2. En su clase importar traceloop y definir el nombre de servicio en instana app_name="nombre_servicio"

	from traceloop.sdk import Traceloop
	from traceloop.sdk.decorators import workflow, task

	Traceloop.init(app_name="openai-obs", disable_batch=True)

3. Colocar las variables de entorno

   Linux:

	set TRACELOOP_BASE_URL=https://otlp-coral-saas.instana.io:4318
	set TRACELOOP_HEADERS=x-instana-key=ORiJrir
	set OPENAI_API_KEY="xxx"

   PowerShell:

	$env:TRACELOOP_BASE_URL = "https://otlp-coral-saas.instana.io:4318"
    $env:TRACELOOP_HEADERS = "x-instana-key=ORiJrirMT"
    $env:OPENAI_API_KEY = "sk-proj-51HKSV_GDIomITGd-h"
