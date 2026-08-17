#!/usr/bin/env bash

# Este archivo debe ejecutarse con:
# source ./00-load-instana-env.sh

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: este script debe cargarse con:"
    echo
    echo "  source ./00-load-instana-env.sh"
    echo
    exit 1
fi


export INSTANA_URL="https://unit0-ibm.instana-0.ibmdte.local"

unset INSTANA_TOKEN


echo
IFS= read -r -s -p "Instana API Token: " INSTANA_TOKEN
printf '\n'

# Elimina únicamente CR accidental al pegar desde Windows.
INSTANA_TOKEN="${INSTANA_TOKEN//$'\r'/}"

if [[ -z "${INSTANA_TOKEN}" ]]; then
    echo "ERROR: API Token vacío"
    return 1
fi

export INSTANA_TOKEN


api_get() {

    local path="$1"
    local body="/tmp/instana-api-body.json"

    rm -f "${body}"

    local code

    code=$(curl -skS \
        -o "${body}" \
        -w '%{http_code}' \
        -H "Authorization: apiToken ${INSTANA_TOKEN}" \
        -H "Accept: application/json" \
        "${INSTANA_URL}${path}") || {
            echo "ERROR: fallo curl para ${path}"
            return 1
        }

    echo "HTTP=${code}"
    echo

    if [[ -s "${body}" ]]; then

        if jq . "${body}" >/dev/null 2>&1; then
            jq . "${body}"
        else
            cat "${body}"
            echo
        fi

    fi

    [[ "${code}" =~ ^2 ]]
}


echo
echo "Validando acceso a Instana..."

code=$(curl -skS \
    -o /tmp/instana-api-precheck.json \
    -w '%{http_code}' \
    -H "Authorization: apiToken ${INSTANA_TOKEN}" \
    -H "Accept: application/json" \
    "${INSTANA_URL}/api/application-monitoring/catalog/metrics")


if [[ "${code}" != "200" ]]; then

    echo "ERROR: Instana API respondió HTTP=${code}"

    if [[ -s /tmp/instana-api-precheck.json ]]; then
        cat /tmp/instana-api-precheck.json
        echo
    fi

    unset INSTANA_TOKEN
    return 1

fi

export DASHBOARD_API_TOKEN_NAME="${DASHBOARD_API_TOKEN_NAME:-demo}"

echo "Instana API: OK"
echo "URL: ${INSTANA_URL}"
echo "Token: cargado (${#INSTANA_TOKEN} caracteres)"
echo
