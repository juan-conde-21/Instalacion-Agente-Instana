#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
BACKUP_DIR="${BASE_DIR}/backup"

ASSET_ROOT="/opt/instana-demo/orchestration/assets/demoapps"
NOVA_HTML="${ASSET_ROOT}/app/src/main/resources/static/index.html"

source "${STATE_DIR}/eum.env"

mkdir -p "${BACKUP_DIR}"

: "${INSTANA_EUM_REPORTING_URL:?Falta INSTANA_EUM_REPORTING_URL}"
: "${INSTANA_EUM_JS_AGENT_URL:?Falta INSTANA_EUM_JS_AGENT_URL}"
: "${INSTANA_EUM_KEY:?Falta INSTANA_EUM_KEY}"

if [[ ! -f "${NOVA_HTML}" ]]; then
  echo "[ERROR] No existe:"
  echo "        ${NOVA_HTML}"
  exit 1
fi

echo
echo "========================================================"
echo " INSTANA EUM | INSTRUMENTACIÓN NOVA"
echo "========================================================"
echo
printf " Frontend       : %s\n" "${NOVA_HTML}"
printf " Reporting URL  : %s\n" "${INSTANA_EUM_REPORTING_URL}"
printf " JS Agent       : %s\n" "${INSTANA_EUM_JS_AGENT_URL}"
printf " Website Key    : %s\n" "${INSTANA_EUM_KEY}"
echo

timestamp="$(date +%Y%m%d-%H%M%S)"
backup="${BACKUP_DIR}/index.html.${timestamp}"

cp -a "${NOVA_HTML}" "${backup}"

echo "[OK] Backup"
echo "     ${backup}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

#
# Convertimos valores a literales JavaScript seguros.
#
REPORTING_JS="$(
  jq -Rn --arg v "${INSTANA_EUM_REPORTING_URL}" '$v'
)"

KEY_JS="$(
  jq -Rn --arg v "${INSTANA_EUM_KEY}" '$v'
)"

AGENT_JS="$(
  jq -Rn --arg v "${INSTANA_EUM_JS_AGENT_URL}" '$v'
)"

#
# Eliminar bloque anterior si el script se ejecuta nuevamente.
#
sed \
  '/<!-- INSTANA_EUM_START -->/,/<!-- INSTANA_EUM_END -->/d' \
  "${NOVA_HTML}" \
  > "${WORKDIR}/index.clean.html"

cat > "${WORKDIR}/eum-snippet.html" <<EOT
<!-- INSTANA_EUM_START -->
<script>
(function(s,t,a,n){
  s[t]||(s[t]=a,n=s[a]=function(){
    n.q.push(arguments)
  },n.q=[],n.v=2,n.l=Date.now());
})(window,"InstanaEumObject","ineum");

ineum('reportingUrl', ${REPORTING_JS});
ineum('key', ${KEY_JS});
ineum('trackSessions');

/*
 * NOVA controla sus vistas desde JavaScript.
 * Las páginas lógicas se informarán manualmente.
 */
ineum('autoPageDetection', false);

ineum('meta', 'application', 'nova-market');
ineum('meta', 'environment', 'demo');
ineum('meta', 'businessFlow', 'retail-critical-flow');
ineum('meta', 'frontendVersion', 'NOVA-V4');

/*
 * Debe ejecutarse después de metadata porque page
 * genera inmediatamente una transición lógica.
 */
ineum('page', 'NOVA | Inicio');
</script>

<script
  defer
  crossorigin="anonymous"
  src=${AGENT_JS}>
</script>
<!-- INSTANA_EUM_END -->
EOT

#
# Insertar antes de </head>
#
awk \
  -v snippet="${WORKDIR}/eum-snippet.html" '
BEGIN {
  while ((getline line < snippet) > 0) {
    block = block line ORS
  }
  close(snippet)
}

/<\/head>/ && !inserted {
  printf "%s", block
  inserted = 1
}

{
  print
}

END {
  if (!inserted) {
    exit 42
  }
}
' "${WORKDIR}/index.clean.html" \
  > "${WORKDIR}/index.new.html"

mv "${WORKDIR}/index.new.html" "${NOVA_HTML}"

echo "[OK] EUM insertado en NOVA"

#
# Refrescar SHA256SUMS si el asset está controlado
# por el mecanismo de integridad del laboratorio.
#
checksum_updated=0

while IFS= read -r sumfile; do

  [[ -f "${sumfile}" ]] || continue

  sumdir="$(dirname "${sumfile}")"
  rel="$(
    realpath --relative-to="${sumdir}" "${NOVA_HTML}"
  )"

  if awk -v target="${rel}" '
  {
    file=$2
    sub(/^\*/, "", file)
    sub(/^\.\//, "", file)

    t=target
    sub(/^\.\//, "", t)

    if (file == t) {
      found=1
    }
  }
  END {
    exit(found ? 0 : 1)
  }
  ' "${sumfile}"; then

    cp -a \
      "${sumfile}" \
      "${BACKUP_DIR}/$(basename "${sumfile}").${timestamp}"

    newhash="$(
      sha256sum "${NOVA_HTML}" |
      awk '{print $1}'
    )"

    awk \
      -v target="${rel}" \
      -v hash="${newhash}" '
    {
      raw=$2
      file=raw

      sub(/^\*/, "", file)
      sub(/^\.\//, "", file)

      t=target
      sub(/^\.\//, "", t)

      if (file == t) {

        if (substr(raw,1,1) == "*") {
          print hash " " raw
        } else {
          print hash "  " raw
        }

      } else {
        print
      }
    }
    ' "${sumfile}" \
      > "${WORKDIR}/SHA256SUMS"

    mv "${WORKDIR}/SHA256SUMS" "${sumfile}"

    echo "[OK] Checksum actualizado"
    echo "     ${sumfile}"

    checksum_updated=1
  fi

done < <(
  find "${ASSET_ROOT}" \
    -name SHA256SUMS \
    -type f 2>/dev/null
)

if [[ "${checksum_updated}" -eq 0 ]]; then
  echo "[INFO] No fue necesario actualizar SHA256SUMS"
fi

echo
echo "Instrumentación resultante"
echo "--------------------------------------------------------"

sed -n \
  '/INSTANA_EUM_START/,/INSTANA_EUM_END/p' \
  "${NOVA_HTML}"

echo
echo "--------------------------------------------------------"
echo " NOVA EUM : INSTRUMENTADO"
echo "--------------------------------------------------------"
