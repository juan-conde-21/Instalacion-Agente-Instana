#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="/opt/instana-demo"

[[ "$(id -u)" -eq 0 ]] || {
    echo "[FAIL] Ejecutar con sudo o como root."
    exit 1
}

for d in instana-api orchestration demo; do
    [[ -d "${LAB_DIR}/${d}" ]] || {
        echo "[FAIL] Falta ${LAB_DIR}/${d}"
        exit 1
    }
done

mkdir -p \
    "${DEST}/instana-api" \
    "${DEST}/orchestration" \
    "${DEST}/demo" \
    "${DEST}/secrets"

cp -a "${LAB_DIR}/instana-api/." "${DEST}/instana-api/"
cp -a "${LAB_DIR}/orchestration/." "${DEST}/orchestration/"
cp -a "${LAB_DIR}/demo/." "${DEST}/demo/"

chmod +x "${DEST}/instana-api/"*.sh
chmod +x "${DEST}/orchestration/"*.sh
chmod +x "${DEST}/demo/"*.sh
chmod 700 "${DEST}/secrets"

echo
echo "========================================================"
echo " INSTANA RETAIL LAB - REPOSITORY INSTALL = COMPLETE"
echo "========================================================"
echo
echo "Destino: ${DEST}"
echo
echo "Siguiente paso:"
echo "  configurar secretos locales"
echo "  cd ${DEST}/orchestration"
echo "  ./00-precheck.sh"
echo "  ./install-all.sh"
