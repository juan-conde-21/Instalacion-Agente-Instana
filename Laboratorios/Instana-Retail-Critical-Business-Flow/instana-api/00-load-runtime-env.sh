#!/usr/bin/env bash

BASE_DIR="/opt/instana-demo"
SECRETS_DIR="${BASE_DIR}/secrets"

TOKEN_FILE="${SECRETS_DIR}/instana.token"
SYNTH_FILE="${SECRETS_DIR}/synthetic.env"

export INSTANA_URL="${INSTANA_URL:-https://unit0-ibm.instana-0.ibmdte.local}"


# ============================================================
# INSTANA TOKEN
# ============================================================

if [[ -z "${INSTANA_TOKEN:-}" ]]; then

    if [[ ! -r "${TOKEN_FILE}" ]]; then
        echo "ERROR: ${TOKEN_FILE} no existe o no es legible." >&2
        return 1 2>/dev/null || exit 1
    fi

    INSTANA_TOKEN=$(tr -d '\r\n' < "${TOKEN_FILE}")
    export INSTANA_TOKEN
fi


if [[ -z "${INSTANA_TOKEN}" ]]; then
    echo "ERROR: INSTANA_TOKEN vacío." >&2
    return 1 2>/dev/null || exit 1
fi


# ============================================================
# SYNTHETIC
# ============================================================

if [[ ! -r "${SYNTH_FILE}" ]]; then
    echo "ERROR: ${SYNTH_FILE} no existe o no es legible." >&2
    return 1 2>/dev/null || exit 1
fi


# shellcheck disable=SC1090
source "${SYNTH_FILE}"


for var in \
    SYNTHETIC_DOWNLOAD_KEY \
    SYNTHETIC_INSTANA_KEY \
    SYNTHETIC_ENDPOINT \
    SYNTHETIC_REDIS_PASSWORD
do

    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: ${var} no está definido." >&2
        return 1 2>/dev/null || exit 1
    fi

    export "${var}"

done


# ============================================================
# SECURITY VALIDATION
# ============================================================

TOKEN_MODE=$(stat -c '%a' "${TOKEN_FILE}" 2>/dev/null || echo "000")
SYNTH_MODE=$(stat -c '%a' "${SYNTH_FILE}" 2>/dev/null || echo "000")

if [[ "${TOKEN_MODE}" != "600" ]]; then
    echo "ERROR: instana.token debe tener permisos 600." >&2
    return 1 2>/dev/null || exit 1
fi

if [[ "${SYNTH_MODE}" != "600" ]]; then
    echo "ERROR: synthetic.env debe tener permisos 600." >&2
    return 1 2>/dev/null || exit 1
fi
