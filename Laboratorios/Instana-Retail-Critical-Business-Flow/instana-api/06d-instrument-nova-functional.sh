#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
BACKUP_DIR="${BASE_DIR}/backup"

ASSET_ROOT="/opt/instana-demo/orchestration/assets/demoapps"
NOVA_HTML="${ASSET_ROOT}/app/src/main/resources/static/index.html"
SUMFILE="${ASSET_ROOT}/SHA256SUMS"

mkdir -p "${BACKUP_DIR}"

if [[ ! -f "${NOVA_HTML}" ]]; then
  echo "[ERROR] No existe ${NOVA_HTML}"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] python3 no está disponible"
  exit 1
fi

echo
echo "========================================================"
echo " INSTANA EUM | NOVA FUNCTIONAL INSTRUMENTATION"
echo "========================================================"
echo
echo " Frontend : ${NOVA_HTML}"
echo

if grep -q "INSTANA_EUM_FUNCTIONAL_V1_START" "${NOVA_HTML}"; then
  echo "[OK] Instrumentación funcional ya presente."
  echo "     No se realizarán cambios."
  exit 0
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
backup="${BACKUP_DIR}/index.html.functional.${timestamp}"

cp -a "${NOVA_HTML}" "${backup}"

echo "[OK] Backup"
echo "     ${backup}"

export NOVA_HTML

python3 <<'PY'
from pathlib import Path
import os
import sys

path = Path(os.environ["NOVA_HTML"])
text = path.read_text(encoding="utf-8")


def replace_once(text, old, new, label):
    count = text.count(old)

    if count != 1:
        print(
            f"[ERROR] {label}: patrón encontrado {count} veces; "
            "se esperaba exactamente 1."
        )
        sys.exit(10)

    return text.replace(old, new, 1)


# ============================================================
# Helpers EUM
# ============================================================

old = """async function loginAs(
  profileId
) {
"""

new = """/* INSTANA_EUM_FUNCTIONAL_V1_START */

function novaEum(
  command,
  ...args
) {

  try {

    if (
      typeof window.ineum ===
      "function"
    ) {

      window.ineum(
        command,
        ...args
      );

    }

  } catch (error) {

    console.debug(
      "Instana EUM command skipped",
      command,
      error
    );

  }

}


function novaEumSetUser(
  profile
) {

  if (!profile) {
    return;
  }

  novaEum(
    "user",
    String(profile.id),
    String(profile.name),
    null
  );

  novaEum(
    "meta",
    "membership",
    String(
      profile.tier ||
      "standard"
    )
  );

}


function novaEumClearUser() {

  novaEum(
    "user",
    null,
    null,
    null
  );

  novaEum(
    "meta",
    "membership",
    "none"
  );

}


function novaEumPage(
  pageName
) {

  novaEum(
    "page",
    pageName
  );

}


function novaEumEvent(
  eventName,
  options = {}
) {

  novaEum(
    "reportEvent",
    eventName,
    options
  );

}

/* INSTANA_EUM_FUNCTIONAL_V1_END */


async function loginAs(
  profileId
) {
"""

text = replace_once(
    text,
    old,
    new,
    "Insertar helpers EUM"
)


# ============================================================
# LOGIN
# ============================================================

old = """  localStorage.setItem(
    "nova-profile",
    activeProfile.id
  );


  loadCart();
"""

new = """  localStorage.setItem(
    "nova-profile",
    activeProfile.id
  );


  /*
   * Instana EUM
   *
   * Se registra antes de cargar catálogo para que
   * /api/catalog ya quede asociado al usuario.
   */
  novaEumSetUser(
    activeProfile
  );


  novaEumEvent(
    "NOVA Login",
    {
      meta: {
        profile:
          String(
            activeProfile.id
          ),

        membership:
          String(
            activeProfile.tier ||
            "standard"
          )
      }
    }
  );


  novaEumPage(
    "NOVA | Tienda"
  );


  loadCart();
"""

text = replace_once(
    text,
    old,
    new,
    "Instrumentar login"
)


# ============================================================
# LOGOUT
# ============================================================

old = """function logout() {

  activeProfile = null;
"""

new = """function logout() {

  if (activeProfile) {

    novaEumEvent(
      "NOVA Logout",
      {
        meta: {
          profile:
            String(
              activeProfile.id
            ),

          membership:
            String(
              activeProfile.tier ||
              "standard"
            )
        }
      }
    );

  }


  activeProfile = null;


  novaEumClearUser();
"""

text = replace_once(
    text,
    old,
    new,
    "Instrumentar logout"
)


old = """  loginScreen.classList.remove(
    "hidden"
  );


  location.hash =
    "login";
"""

new = """  loginScreen.classList.remove(
    "hidden"
  );


  novaEumPage(
    "NOVA | Inicio"
  );


  location.hash =
    "login";
"""

text = replace_once(
    text,
    old,
    new,
    "Página Inicio logout"
)


# ============================================================
# CHECKOUT START
# ============================================================

old = """  clearCheckoutMessage();


  const request = {
"""

new = """  clearCheckoutMessage();


  const novaCheckoutStartedAt =
    Date.now();


  novaEumEvent(
    "NOVA Checkout Started",
    {
      meta: {
        profile:
          String(
            activeProfile.id
          ),

        membership:
          String(
            activeProfile.tier ||
            "standard"
          ),

        cartLines:
          String(
            entries.length
          )
      }
    }
  );


  const request = {
"""

text = replace_once(
    text,
    old,
    new,
    "Instrumentar Checkout Started"
)


# ============================================================
# CHECKOUT FAILURE
# ============================================================

old = """    if (
      !response.ok ||
      payload.status !==
        "SUCCESS"
    ) {

      throw {
"""

new = """    if (
      !response.ok ||
      payload.status !==
        "SUCCESS"
    ) {

      novaEumEvent(
        "NOVA Checkout Failed",
        {
          duration:
            Date.now() -
            novaCheckoutStartedAt,

          meta: {
            profile:
              String(
                activeProfile.id
              ),

            membership:
              String(
                activeProfile.tier ||
                "standard"
              ),

            httpStatus:
              String(
                response.status
              ),

            businessStatus:
              String(
                payload.status ||
                "UNKNOWN"
              )
          }
        }
      );


      throw {
"""

text = replace_once(
    text,
    old,
    new,
    "Instrumentar Checkout Failed"
)


# ============================================================
# CHECKOUT SUCCESS
# ============================================================

old = """    const order =
      payload.order;


    checkoutMessage.className =
"""

new = """    const order =
      payload.order;


    novaEumEvent(
      "NOVA Checkout Success",
      {
        duration:
          Date.now() -
          novaCheckoutStartedAt,

        meta: {
          profile:
            String(
              activeProfile.id
            ),

          membership:
            String(
              activeProfile.tier ||
              "standard"
            ),

          orderId:
            String(
              order.orderId ||
              ""
            )
        },

        customMetric:
          Number(
            order.total ||
            0
          )
      }
    );


    checkoutMessage.className =
"""

text = replace_once(
    text,
    old,
    new,
    "Instrumentar Checkout Success"
)


# ============================================================
# PRODUCTS PAGE
# ============================================================

old = """  location.hash =
    "products";

}
"""

new = """  location.hash =
    "products";


  novaEumPage(
    "NOVA | Tienda"
  );

}
"""

text = replace_once(
    text,
    old,
    new,
    "Instrumentar página Tienda"
)


# ============================================================
# ORDERS PAGE
# ============================================================

old = """  location.hash =
    "orders";


  await loadOrders();
"""

new = """  location.hash =
    "orders";


  /*
   * Cambiar página antes del fetch para que
   * /api/orders se atribuya a Mis compras.
   */
  novaEumPage(
    "NOVA | Mis compras"
  );


  await loadOrders();
"""

text = replace_once(
    text,
    old,
    new,
    "Instrumentar página Mis compras"
)


path.write_text(
    text,
    encoding="utf-8"
)

print("[OK] Instrumentación JavaScript aplicada")
PY


# ============================================================
# SHA256
# ============================================================

if [[ -f "${SUMFILE}" ]]; then

  cp -a \
    "${SUMFILE}" \
    "${BACKUP_DIR}/SHA256SUMS.functional.${timestamp}"

  REL="./app/src/main/resources/static/index.html"

  HASH="$(
    sha256sum "${NOVA_HTML}" |
    awk '{print $1}'
  )"

  awk \
    -v hash="${HASH}" \
    -v target="${REL}" '
  {
    if ($2 == target) {
      print hash "  " target
    } else {
      print
    }
  }
  ' "${SUMFILE}" \
    > "${SUMFILE}.tmp"

  mv \
    "${SUMFILE}.tmp" \
    "${SUMFILE}"

  echo "[OK] SHA256SUMS actualizado"

else

  echo "[WARN] No existe ${SUMFILE}"

fi


echo
echo "Validación"
echo "--------------------------------------------------------"

grep -nE \
'INSTANA_EUM_FUNCTIONAL|NOVA Login|NOVA Logout|NOVA Checkout|NOVA \| Tienda|NOVA \| Mis compras' \
"${NOVA_HTML}"

echo
echo "--------------------------------------------------------"
echo " NOVA FUNCTIONAL EUM : READY"
echo "--------------------------------------------------------"
