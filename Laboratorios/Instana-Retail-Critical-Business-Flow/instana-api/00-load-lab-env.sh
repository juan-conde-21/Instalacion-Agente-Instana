#!/usr/bin/env bash

# Debe cargarse con:
#   source ./00-load-lab-env.sh

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: este archivo debe cargarse con:"
    echo
    echo "  source ./00-load-lab-env.sh"
    exit 1
fi


# ============================================================
# LAB - BLUEBOX
# ============================================================

export LAB_BLUEBOX_HOST="bluebox"
export LAB_BLUEBOX_USER="jammer"

# Llave provista/existente en el laboratorio.
# No se copia ni se modifica.
export LAB_SSH_KEY="/home/admin/.ssh/id_rsa"


if [[ ! -r "${LAB_SSH_KEY}" ]]; then
    echo "ERROR: no se puede leer la llave SSH:"
    echo "  ${LAB_SSH_KEY}"
    return 1
fi


LAB_SSH_OPTS=(
    -i "${LAB_SSH_KEY}"
    -o IdentitiesOnly=yes
    -o BatchMode=yes
    -o ConnectTimeout=10
    -o StrictHostKeyChecking=accept-new
)


# ============================================================
# HELPERS
# ============================================================

bluebox_exec() {
    ssh \
      "${LAB_SSH_OPTS[@]}" \
      "${LAB_BLUEBOX_USER}@${LAB_BLUEBOX_HOST}" \
      "$@"
}


bluebox_sudo() {
    local remote_cmd

    printf -v remote_cmd '%q ' "$@"

    ssh \
      "${LAB_SSH_OPTS[@]}" \
      "${LAB_BLUEBOX_USER}@${LAB_BLUEBOX_HOST}" \
      "sudo -n -- ${remote_cmd}"
}


# ============================================================
# PRECHECK
# ============================================================

echo
echo "Validando acceso al laboratorio..."

if ! bluebox_exec \
    'printf "SSH=OK HOST=%s USER=%s\n" "$(hostname)" "$(whoami)"'
then
    echo
    echo "ERROR: acceso SSH a Bluebox falló."
    return 1
fi


if ! bluebox_exec 'sudo -n true'; then
    echo
    echo "ERROR: sudo remoto requiere interacción."
    return 1
fi


echo "SUDO=OK"
echo
echo "Lab environment: READY"
