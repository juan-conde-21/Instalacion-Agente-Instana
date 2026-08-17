#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

echo "========================================================"
echo " INSTANA RETAIL LAB - PUBLICATION VALIDATION"
echo "========================================================"

required=(
    "README.md"
    "instana-api/17-rebuild-instana.sh"
    "orchestration/00-precheck.sh"
    "orchestration/20-setup-bastion.sh"
    "orchestration/30-setup-bluebox.sh"
    "orchestration/40-setup-demoapps.sh"
    "orchestration/50-create-instana.sh"
    "orchestration/60-validate-all.sh"
    "orchestration/install-all.sh"
    "demo/demo.sh"
)

for item in "${required[@]}"; do
    if [[ -f "${LAB_DIR}/${item}" ]]; then
        echo "[OK]   ${item}"
    else
        echo "[FAIL] ${item}"
        FAIL=1
    fi
done

echo
echo "Validando sintaxis Shell..."

while IFS= read -r -d '' f; do
    if bash -n "$f"; then
        echo "[OK]   ${f#${LAB_DIR}/}"
    else
        FAIL=1
    fi
done < <(find "${LAB_DIR}" -type f -name '*.sh' -print0)

echo
echo "Buscando archivos que no deben publicarse..."

mapfile -t forbidden < <(
    find "${LAB_DIR}" -type f \
      \( -name '*.token' \
         -o -name 'synthetic.env' \
         -o -name '.env' \
         -o -name '*.key' \
      \) -print
)

if ((${#forbidden[@]} > 0)); then
    printf '[FAIL] %s\n' "${forbidden[@]}"
    FAIL=1
else
    echo "[OK]   No se detectaron archivos de secretos por nombre."
fi

echo

if ((FAIL == 0)); then
    echo "PUBLICATION VALIDATION = PASS"
else
    echo "PUBLICATION VALIDATION = FAILED"
    exit 1
fi
