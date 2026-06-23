# Air-gapped - Descarga de bundle en máquina online

[← Volver a ruta air-gapped](README.md)  
[← Volver al índice principal](../README.md)

**Ubicación sugerida:** `Configuraciones/Synthetic-PoP/airgap/01-descarga-bundle-maquina-online.md`  
**Paso anterior:** [Ruta air-gapped](README.md)  
**Siguiente paso:** [Preparación por sistema operativo destino](../sistemas-operativos/README.md)

---

## 1. Objetivo

Construir un paquete portable con los binarios, charts, valores, imágenes y evidencias necesarias para instalar **IBM Instana Synthetic PoP** en un servidor destino sin salida a Internet.

Este paso se ejecuta en una **máquina online**, es decir, una máquina con acceso a Internet o con acceso controlado a los endpoints requeridos.

---

## 2. Enfoque recomendado

Para evitar confusiones, este documento separa los comandos por sistema operativo de la máquina online:

| Máquina online | Uso recomendado | Comentario |
|---|---|---|
| Linux | Recomendado | Es la opción más simple para preparar el bundle completo, incluyendo imágenes. |
| macOS | Válido para descarga | Puede usarse para descargar artefactos, pero se debe incluir binario Linux para el servidor destino. |
| Windows PowerShell | Válido con consideraciones | No usa `export`; se debe usar `$env:`. Para imágenes se requiere Docker Desktop, Podman o una herramienta equivalente. |

> **Importante:** El servidor destino será Linux. Aunque el bundle se prepare desde Windows o macOS, los binarios que se trasladan al servidor destino deben corresponder a Linux, por ejemplo `k3s` Linux AMD64 y Helm Linux AMD64.

---

## 3. Consideración sobre certificados TLS inspeccionados

En algunos clientes, el tráfico HTTPS puede ser inspeccionado por proxy corporativo. En ese caso, los comandos `curl`, `Invoke-WebRequest`, `helm repo update` o `docker pull` pueden fallar con errores de certificado.

El orden recomendado es:

1. **Preferido:** instalar la CA corporativa en la máquina online.
2. **Alternativo:** usar un archivo de CA corporativa con `curl --cacert`.
3. **Solo validación temporal:** usar `curl -k` o `curl --insecure`, dejando evidencia de que se está omitiendo la validación TLS.

> **No se recomienda usar `-k` como práctica estándar.** Debe usarse solo para una validación controlada, porque deshabilita la verificación del certificado del servidor.

### Linux/macOS con CA corporativa

```bash
curl --cacert /ruta/corporate-ca.pem -fL -o archivo.tar.gz "https://ejemplo/archivo.tar.gz"
```

También se puede declarar la CA para toda la sesión:

```bash
export CURL_CA_BUNDLE="/ruta/corporate-ca.pem"
```

### Linux/macOS con omisión temporal de validación TLS

```bash
curl -k -fL -o archivo.tar.gz "https://ejemplo/archivo.tar.gz"
```

### Windows PowerShell con CA corporativa

En Windows, lo recomendado es importar la CA corporativa al almacén de certificados de confianza del sistema operativo. Luego `Invoke-WebRequest` y las herramientas instaladas deberían validar correctamente.

### Windows PowerShell con omisión temporal de validación TLS

PowerShell 7 permite usar `-SkipCertificateCheck`:

```powershell
Invoke-WebRequest -Uri "https://ejemplo/archivo.tar.gz" -OutFile "archivo.tar.gz" -SkipCertificateCheck
```

Si se usa `curl` real en Windows, invocar `curl.exe` para evitar confusión con alias de PowerShell:

```powershell
curl.exe -k -fL -o archivo.tar.gz "https://ejemplo/archivo.tar.gz"
```

---

## 4. Definir versiones a descargar

Antes de descargar, revisar el criterio de versionamiento:

[Validación de versiones](../validaciones/versionamiento.md)

Para producción o ambientes de cliente, no se recomienda usar `latest`. Se debe trabajar con versiones específicas y dejar evidencia.

Variables mínimas:

```text
K3S_VERSION=<version_k3s>
HELM_VERSION=<version_helm>
POP_CHART_VERSION=<version_chart_synthetic_pop>
```

Ejemplo referencial:

```text
K3S_VERSION=v1.33.3+k3s1
HELM_VERSION=v3.18.4
POP_CHART_VERSION=1.2.47
```

> Ajustar las versiones según la validación vigente del proyecto, documentación oficial, compatibilidad del cliente y aprobación técnica.

---

## 5. Crear estructura del bundle

### Opción A: Linux/macOS - Bash

```bash
export AIRGAP_DIR="$HOME/synthetic-pop-airgap-bundle"

mkdir -p "$AIRGAP_DIR"/{binaries,charts,images,values,scripts,evidencias}
```

Validar:

```bash
find "$AIRGAP_DIR" -maxdepth 2 -type d | sort
```

### Opción B: Windows - PowerShell

```powershell
$AIRGAP_DIR = Join-Path $HOME "synthetic-pop-airgap-bundle"

New-Item -ItemType Directory -Force -Path `
  (Join-Path $AIRGAP_DIR "binaries"), `
  (Join-Path $AIRGAP_DIR "charts"), `
  (Join-Path $AIRGAP_DIR "images"), `
  (Join-Path $AIRGAP_DIR "values"), `
  (Join-Path $AIRGAP_DIR "scripts"), `
  (Join-Path $AIRGAP_DIR "evidencias")
```

Validar:

```powershell
Get-ChildItem $AIRGAP_DIR -Directory
```

---

## 6. Cargar versiones

### Opción A: Linux/macOS - Bash

Si existe el template `versiones.env`:

```bash
cp ../templates/versiones.env "$AIRGAP_DIR/versiones.env"
vi "$AIRGAP_DIR/versiones.env"
source "$AIRGAP_DIR/versiones.env"
```

Validar:

```bash
echo "K3S_VERSION=${K3S_VERSION}"
echo "HELM_VERSION=${HELM_VERSION}"
echo "POP_CHART_VERSION=${POP_CHART_VERSION}"
```

### Opción B: Windows - PowerShell

Windows PowerShell no usa `export` ni `source`. Definir variables de entorno así:

```powershell
$env:K3S_VERSION = "v1.33.3+k3s1"
$env:HELM_VERSION = "v3.18.4"
$env:POP_CHART_VERSION = "1.2.47"
```

Validar:

```powershell
Write-Host "K3S_VERSION=$env:K3S_VERSION"
Write-Host "HELM_VERSION=$env:HELM_VERSION"
Write-Host "POP_CHART_VERSION=$env:POP_CHART_VERSION"
```

Guardar evidencia:

```powershell
@"
K3S_VERSION=$env:K3S_VERSION
HELM_VERSION=$env:HELM_VERSION
POP_CHART_VERSION=$env:POP_CHART_VERSION
"@ | Set-Content -Path (Join-Path $AIRGAP_DIR "evidencias\versiones-seleccionadas.txt")
```

---

## 7. Descargar k3s

El binario `k3s` que se descarga debe ser Linux AMD64, porque será trasladado al servidor destino.

### Opción A: Linux/macOS - Bash

```bash
cd "$AIRGAP_DIR/binaries"

K3S_VERSION_URL="${K3S_VERSION/+/%2B}"

curl -fL --retry 3 -o install.sh "https://get.k3s.io"
chmod +x install.sh

curl -fL --retry 3 -o k3s "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION_URL}/k3s"
chmod +x k3s
```

Validar:

```bash
ls -lh "$AIRGAP_DIR/binaries/install.sh" "$AIRGAP_DIR/binaries/k3s"
```

### Opción B: Windows - PowerShell

```powershell
$K3S_VERSION_URL = $env:K3S_VERSION.Replace("+", "%2B")
$binariesDir = Join-Path $AIRGAP_DIR "binaries"

Invoke-WebRequest `
  -Uri "https://get.k3s.io" `
  -OutFile (Join-Path $binariesDir "install.sh")

Invoke-WebRequest `
  -Uri "https://github.com/k3s-io/k3s/releases/download/$K3S_VERSION_URL/k3s" `
  -OutFile (Join-Path $binariesDir "k3s")
```

Validar:

```powershell
Get-ChildItem $binariesDir | Where-Object Name -in "install.sh", "k3s"
```

---

## 8. Descargar imágenes air-gapped de k3s

### Opción A: Linux/macOS - Bash

```bash
cd "$AIRGAP_DIR/images"

K3S_VERSION_URL="${K3S_VERSION/+/%2B}"

curl -fL --retry 3 -o k3s-airgap-images-amd64.tar.zst \
  "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION_URL}/k3s-airgap-images-amd64.tar.zst"
```

Validar:

```bash
ls -lh "$AIRGAP_DIR/images/k3s-airgap-images-amd64.tar.zst"
```

### Opción B: Windows - PowerShell

```powershell
$K3S_VERSION_URL = $env:K3S_VERSION.Replace("+", "%2B")
$imagesDir = Join-Path $AIRGAP_DIR "images"

Invoke-WebRequest `
  -Uri "https://github.com/k3s-io/k3s/releases/download/$K3S_VERSION_URL/k3s-airgap-images-amd64.tar.zst" `
  -OutFile (Join-Path $imagesDir "k3s-airgap-images-amd64.tar.zst")
```

Validar:

```powershell
Get-ChildItem (Join-Path $imagesDir "k3s-airgap-images-amd64.tar.zst")
```

---

## 9. Descargar Helm para el servidor destino

Aunque el bundle se prepare en Windows o macOS, el servidor destino será Linux. Por ello se debe incluir Helm Linux AMD64 dentro del bundle.

### Opción A: Linux/macOS - Bash

```bash
cd "$AIRGAP_DIR/binaries"

curl -fL --retry 3 -o "helm-${HELM_VERSION}-linux-amd64.tar.gz" \
  "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"

tar -zxvf "helm-${HELM_VERSION}-linux-amd64.tar.gz"
cp linux-amd64/helm ./helm
chmod +x ./helm
```

Validar:

```bash
"$AIRGAP_DIR/binaries/helm" version --client
```

### Opción B: Windows - PowerShell

```powershell
$binariesDir = Join-Path $AIRGAP_DIR "binaries"
$helmArchive = "helm-$env:HELM_VERSION-linux-amd64.tar.gz"

Invoke-WebRequest `
  -Uri "https://get.helm.sh/$helmArchive" `
  -OutFile (Join-Path $binariesDir $helmArchive)

Set-Location $binariesDir
tar -xzf $helmArchive
Copy-Item ".\linux-amd64\helm" ".\helm" -Force
```

Validar que el archivo Linux quedó incluido en el bundle:

```powershell
Get-ChildItem (Join-Path $binariesDir "helm")
```

> En Windows, ese binario `helm` no se ejecuta porque es Linux. Para ejecutar comandos `helm repo`, `helm pull` o `helm show values` desde Windows, instalar Helm para Windows en la máquina online.

Instalación referencial de Helm para Windows:

```powershell
winget install Helm.Helm
```

Validar Helm local en Windows:

```powershell
helm version
```

---

## 10. Descargar chart Synthetic PoP

IBM Instana publica el chart oficial `synthetic-pop` en el repositorio Helm `https://agents.instana.io/helm`.

### Opción A: Linux/macOS - Bash

```bash
cd "$AIRGAP_DIR/charts"

HELM_BIN="$AIRGAP_DIR/binaries/helm"

"$HELM_BIN" repo add instana https://agents.instana.io/helm
"$HELM_BIN" repo update
"$HELM_BIN" search repo instana/synthetic-pop --versions | head

"$HELM_BIN" pull instana/synthetic-pop --version "${POP_CHART_VERSION}"
```

Validar:

```bash
ls -lh "$AIRGAP_DIR/charts/synthetic-pop-${POP_CHART_VERSION}.tgz"
```

### Opción B: Windows - PowerShell

> Requiere Helm para Windows instalado en la máquina online.

```powershell
$chartsDir = Join-Path $AIRGAP_DIR "charts"
Set-Location $chartsDir

helm repo add instana https://agents.instana.io/helm
helm repo update
helm search repo instana/synthetic-pop --versions

helm pull instana/synthetic-pop --version $env:POP_CHART_VERSION
```

Validar:

```powershell
Get-ChildItem (Join-Path $chartsDir "synthetic-pop-$env:POP_CHART_VERSION.tgz")
```

---

## 11. Guardar values base

### Opción A: Linux/macOS - Bash

```bash
HELM_BIN="$AIRGAP_DIR/binaries/helm"

"$HELM_BIN" show values "$AIRGAP_DIR/charts/synthetic-pop-${POP_CHART_VERSION}.tgz" \
  > "$AIRGAP_DIR/values/values-default.yaml"

cp ../templates/values-pop.yaml "$AIRGAP_DIR/values/values-pop.yaml"
```

Validar:

```bash
ls -lh "$AIRGAP_DIR/values"
```

### Opción B: Windows - PowerShell

```powershell
$chartFile = Join-Path $AIRGAP_DIR "charts\synthetic-pop-$env:POP_CHART_VERSION.tgz"
$valuesDefault = Join-Path $AIRGAP_DIR "values\values-default.yaml"
$valuesPop = Join-Path $AIRGAP_DIR "values\values-pop.yaml"

helm show values $chartFile | Out-File -FilePath $valuesDefault -Encoding utf8
Copy-Item "..\templates\values-pop.yaml" $valuesPop -Force
```

Validar:

```powershell
Get-ChildItem (Join-Path $AIRGAP_DIR "values")
```

---

## 12. Renderizar manifiesto para identificar imágenes

Este paso permite obtener evidencia de los recursos que generará el chart y ayuda a listar las imágenes que deben incluirse en el bundle.

### Opción A: Linux/macOS - Bash

```bash
HELM_BIN="$AIRGAP_DIR/binaries/helm"

"$HELM_BIN" template synthetic-pop \
  "$AIRGAP_DIR/charts/synthetic-pop-${POP_CHART_VERSION}.tgz" \
  --namespace synthetic-pop \
  -f "$AIRGAP_DIR/values/values-pop.yaml" \
  > "$AIRGAP_DIR/evidencias/rendered-synthetic-pop.yaml"

grep -E 'image:[[:space:]]*' "$AIRGAP_DIR/evidencias/rendered-synthetic-pop.yaml" \
  | awk '{print $2}' \
  | tr -d '"' \
  | sort -u \
  > "$AIRGAP_DIR/evidencias/listado-imagenes-synthetic-pop.txt"
```

Validar:

```bash
cat "$AIRGAP_DIR/evidencias/listado-imagenes-synthetic-pop.txt"
```

### Opción B: Windows - PowerShell

```powershell
$chartFile = Join-Path $AIRGAP_DIR "charts\synthetic-pop-$env:POP_CHART_VERSION.tgz"
$valuesPop = Join-Path $AIRGAP_DIR "values\values-pop.yaml"
$renderedFile = Join-Path $AIRGAP_DIR "evidencias\rendered-synthetic-pop.yaml"
$imageListFile = Join-Path $AIRGAP_DIR "evidencias\listado-imagenes-synthetic-pop.txt"

helm template synthetic-pop $chartFile `
  --namespace synthetic-pop `
  -f $valuesPop | Out-File -FilePath $renderedFile -Encoding utf8

Select-String -Path $renderedFile -Pattern 'image:\s*(.+)' |
  ForEach-Object { $_.Matches.Groups[1].Value.Trim().Trim('"') } |
  Sort-Object -Unique |
  Set-Content -Path $imageListFile
```

Validar:

```powershell
Get-Content $imageListFile
```

---

## 13. Descargar y empaquetar imágenes Synthetic PoP

Para esta etapa se requiere una herramienta capaz de descargar y exportar imágenes de contenedor, por ejemplo Docker, Podman o una herramienta equivalente.

> Si se prepara el bundle desde Windows, validar que Docker Desktop o Podman estén usando contenedores Linux.

### Opción A: Linux/macOS con Docker

```bash
IMAGE_LIST="$AIRGAP_DIR/evidencias/listado-imagenes-synthetic-pop.txt"

while read -r image; do
  [ -z "$image" ] && continue
  docker pull "$image"
done < "$IMAGE_LIST"

docker save -o "$AIRGAP_DIR/images/synthetic-pop-images.tar" $(cat "$IMAGE_LIST")
```

Validar:

```bash
tar -tf "$AIRGAP_DIR/images/synthetic-pop-images.tar" \
  > "$AIRGAP_DIR/evidencias/listado-contenido-synthetic-pop-images.txt"

ls -lh "$AIRGAP_DIR/images/synthetic-pop-images.tar"
```

### Opción B: Windows PowerShell con Docker Desktop

```powershell
$imageListFile = Join-Path $AIRGAP_DIR "evidencias\listado-imagenes-synthetic-pop.txt"
$imageTar = Join-Path $AIRGAP_DIR "images\synthetic-pop-images.tar"
$images = Get-Content $imageListFile | Where-Object { $_ -and $_.Trim() -ne "" }

foreach ($image in $images) {
  docker pull $image
}

docker save -o $imageTar $images
```

Validar:

```powershell
tar -tf $imageTar | Set-Content (Join-Path $AIRGAP_DIR "evidencias\listado-contenido-synthetic-pop-images.txt")
Get-ChildItem $imageTar
```

> Si el registro de imágenes requiere autenticación, realizar previamente el login correspondiente según el procedimiento aprobado por el cliente y la información generada desde Instana.

---

## 14. Generar manifiesto del bundle

### Opción A: Linux/macOS - Bash

```bash
cd "$AIRGAP_DIR"

find . -type f | sort > evidencias/manifest-files.txt
sha256sum $(find . -type f | sort) > evidencias/sha256sum.txt
```

Validar:

```bash
head evidencias/manifest-files.txt
head evidencias/sha256sum.txt
```

### Opción B: Windows - PowerShell

```powershell
Set-Location $AIRGAP_DIR

Get-ChildItem -Recurse -File |
  ForEach-Object { $_.FullName.Replace($AIRGAP_DIR, ".") } |
  Sort-Object |
  Set-Content "evidencias\manifest-files.txt"

Get-ChildItem -Recurse -File |
  Get-FileHash -Algorithm SHA256 |
  ForEach-Object { "$($_.Hash)  $($_.Path.Replace($AIRGAP_DIR, '.'))" } |
  Set-Content "evidencias\sha256sum.txt"
```

Validar:

```powershell
Get-Content "evidencias\manifest-files.txt" -TotalCount 10
Get-Content "evidencias\sha256sum.txt" -TotalCount 10
```

---

## 15. Empaquetar bundle

### Opción A: Linux/macOS - Bash

```bash
cd "$HOME"
tar -czvf synthetic-pop-airgap-bundle.tar.gz synthetic-pop-airgap-bundle
```

Validar:

```bash
ls -lh "$HOME/synthetic-pop-airgap-bundle.tar.gz"
```

### Opción B: Windows - PowerShell

```powershell
Set-Location $HOME
tar -czvf synthetic-pop-airgap-bundle.tar.gz synthetic-pop-airgap-bundle
```

Validar:

```powershell
Get-ChildItem (Join-Path $HOME "synthetic-pop-airgap-bundle.tar.gz")
```

---

## 16. Evidencias mínimas esperadas

Al finalizar, el bundle debe contener como mínimo:

```text
synthetic-pop-airgap-bundle/
├── binaries/
│   ├── install.sh
│   ├── k3s
│   └── helm
├── charts/
│   └── synthetic-pop-<version>.tgz
├── images/
│   ├── k3s-airgap-images-amd64.tar.zst
│   └── synthetic-pop-images.tar
├── values/
│   ├── values-default.yaml
│   └── values-pop.yaml
├── scripts/
└── evidencias/
    ├── versiones-seleccionadas.txt
    ├── rendered-synthetic-pop.yaml
    ├── listado-imagenes-synthetic-pop.txt
    ├── listado-contenido-synthetic-pop-images.txt
    ├── manifest-files.txt
    └── sha256sum.txt
```

---

## 17. Siguiente paso

Trasladar el archivo:

```text
synthetic-pop-airgap-bundle.tar.gz
```

al servidor destino y continuar con:

[Preparación por sistema operativo destino](../sistemas-operativos/README.md)

---

## 18. Notas finales

- No mezclar comandos Bash con PowerShell.
- En Linux/macOS se usa `export`, `source`, `mkdir -p`, `chmod` y `echo`.
- En Windows PowerShell se usa `$env:`, `New-Item`, `Invoke-WebRequest`, `Set-Content` y `Write-Host`.
- En Windows, usar `curl.exe` si se requiere el binario real de curl.
- Evitar `curl -k` salvo validación temporal y controlada.
- En producción o cliente, siempre fijar versiones y dejar evidencia del bundle generado.
