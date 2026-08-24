#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/synthetic/browser-journey"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}"

HTML="/opt/instana-demo/orchestration/assets/demoapps/app/src/main/resources/static/index.html"
AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

[[ -f "${HTML}" ]] || {
  echo "[ERROR] No encuentro ${HTML}"
  exit 1
}

echo
echo "========================================================"
echo " INSTANA | BROWSER JOURNEY PREFLIGHT"
echo "========================================================"

echo
echo "1. Synthetic PoP / Browser capability"
echo "--------------------------------------------------------"

curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/synthetics/settings/locations" \
  > "${OUT_DIR}/locations.json"

jq '
  map({
    id: .id,
    label: .label,
    status: .status,
    popVersion: .popVersion,
    syntheticTypes: .playbackCapabilities.syntheticType,
    browsers: .playbackCapabilities.browserType
  })
' "${OUT_DIR}/locations.json"

echo
echo "2. Browser playback engine"
echo "--------------------------------------------------------"

kubectl get pods -n instana-synthetic \
  | grep -Ei 'browser|playback' \
  || echo "[WARN] No identifiqué pod por nombre; revisaremos el namespace."

echo
echo "3. Controles relevantes del frontend NOVA"
echo "--------------------------------------------------------"

grep -nEi \
  'Valeria|loginAs|logout|checkout|Confirmar|Comprar|Agregar|showProducts|showOrders|Mis compras|Tienda' \
  "${HTML}" \
  | tee "${OUT_DIR}/dom-relevant-lines.txt"

echo
echo "4. Elementos con onclick"
echo "--------------------------------------------------------"

grep -nEi \
  'onclick=' \
  "${HTML}" \
  | tee "${OUT_DIR}/onclick-elements.txt"

echo
echo "5. Implementación loginAs()"
echo "--------------------------------------------------------"

grep -nA35 -B5 \
  -E 'function[[:space:]]+loginAs|async[[:space:]]+function[[:space:]]+loginAs' \
  "${HTML}" \
  | tee "${OUT_DIR}/login-function.txt" \
  || true

echo
echo "6. Implementación checkout()"
echo "--------------------------------------------------------"

grep -nA70 -B10 \
  -E 'function[[:space:]]+checkout|async[[:space:]]+function[[:space:]]+checkout' \
  "${HTML}" \
  | tee "${OUT_DIR}/checkout-function.txt" \
  || true

echo
echo "7. Renderizado de productos"
echo "--------------------------------------------------------"

grep -nA100 -B10 \
  -E 'function[[:space:]]+showProducts|function[[:space:]]+loadCatalog|async[[:space:]]+function[[:space:]]+loadCatalog' \
  "${HTML}" \
  | tee "${OUT_DIR}/products-function.txt" \
  || true

echo
echo "8. IDs / clases / controles HTML"
echo "--------------------------------------------------------"

grep -nEi \
  '<(button|input|select|a|form)|id=|data-|class=' \
  "${HTML}" \
  | grep -Ei \
  'profile|user|login|product|catalog|cart|checkout|order|shop|tienda|compra|valeria' \
  | tee "${OUT_DIR}/controls.txt" \
  || true

echo
echo "Estado persistido"
echo "--------------------------------------------------------"
echo " ${OUT_DIR}/locations.json"
echo " ${OUT_DIR}/dom-relevant-lines.txt"
echo " ${OUT_DIR}/onclick-elements.txt"
echo " ${OUT_DIR}/login-function.txt"
echo " ${OUT_DIR}/checkout-function.txt"
echo " ${OUT_DIR}/products-function.txt"
echo " ${OUT_DIR}/controls.txt"

echo
echo "--------------------------------------------------------"
echo " BROWSER JOURNEY PREFLIGHT : READY"
echo "--------------------------------------------------------"
