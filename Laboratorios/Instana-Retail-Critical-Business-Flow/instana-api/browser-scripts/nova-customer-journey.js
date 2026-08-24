const { assert } = require("chai");

const TIMEOUT = 30000;
const BASE_URL = "http://192.168.252.33:18083/";

async function waitStage(condition, name, timeout = TIMEOUT) {
  console.log(`[NOVA] Esperando: ${name}`);

  try {
    return await $browser.wait(
      condition,
      timeout
    );
  } catch (e) {
    throw new Error(
      `[NOVA STAGE TIMEOUT] ${name}: ${e.message}`
    );
  }
}


(async function () {

  console.log("========================================");
  console.log(" NOVA | CUSTOMER JOURNEY");
  console.log("========================================");


  /*
   * 1. Abrir NOVA
   */
  console.log("[NOVA] Abriendo aplicación");

  await $browser.get(BASE_URL);

  await $browser.executeScript(
    "window.localStorage.clear();"
  );

  await $browser.get(BASE_URL);


  /*
   * 2. Login Valeria
   */
  console.log("[NOVA] Esperando login");

  const valeria =
    await $browser.waitForAndFindElement(
      $driver.By.xpath(
        "//*[contains(@class,'profile-card')" +
        " and contains(.,'Valeria')]"
      ),
      TIMEOUT
    );

  console.log("[NOVA] Login como Valeria");

  await valeria.click();


  await waitStage(
    async function () {

      const users =
        await $browser.findElements(
          $driver.By.css(
            '[data-testid="user-profile"]'
          )
        );

      if (users.length === 0) {
        return false;
      }

      const text =
        await users[0].getText();

      return text.includes("Valeria");

    },
    "perfil Valeria activo"
  );

  console.log(
    "[NOVA] Perfil validado: Valeria"
  );


  /*
   * 3. Esperar que NOVA haya cargado catálogo
   *    y que addToCart esté disponible.
   */
  await waitStage(
    async function () {

      return await $browser.executeScript(
        "return (" +
        "typeof addToCart === 'function'" +
        ");"
      );

    },
    "función addToCart disponible"
  );


  /*
   * 4. Agregar producto usando la misma
   *    función que utiliza la UI.
   */
  console.log(
    "[NOVA] Agregando P00001 al carrito"
  );

  const addResult =
    await $browser.executeScript(
      "if (typeof addToCart !== 'function') {" +
      "  throw new Error('addToCart unavailable');" +
      "}" +
      "addToCart('P00001');" +
      "return true;"
    );

  assert.isTrue(
    addResult,
    "addToCart debe ejecutarse"
  );


  /*
   * 5. Confirmar que el carrito realmente cambió.
   */
  await waitStage(
    async function () {

      const checkout =
        await $browser.findElements(
          $driver.By.id(
            "checkoutButton"
          )
        );

      if (checkout.length === 0) {
        return false;
      }

      return await checkout[0].isEnabled();

    },
    "checkout habilitado después de agregar producto"
  );


  console.log(
    "[NOVA] Carrito preparado"
  );


  /*
   * 6. Checkout.
   *
   * Usamos DOM click para evitar la
   * inestabilidad observada con Actions/Selenium 113.
   */
  const checkout =
    await $browser.findElement(
      $driver.By.id(
        "checkoutButton"
      )
    );

  console.log(
    "[NOVA] Confirmando compra"
  );

  await $browser.executeScript(
    "arguments[0].click();",
    checkout
  );


  /*
   * 7. Esperar resultado real del negocio.
   */
  console.log(
    "[NOVA] Esperando resultado del checkout"
  );

  await waitStage(
    async function () {

      const success =
        await $browser.findElements(
          $driver.By.css(
            '[data-testid="checkout-success"]'
          )
        );

      const errors =
        await $browser.findElements(
          $driver.By.css(
            '[data-testid="checkout-error"]'
          )
        );

      return (
        success.length > 0 ||
        errors.length > 0
      );

    },
    "resultado checkout"
  );


  /*
   * 8. Business FAIL
   */
  const errors =
    await $browser.findElements(
      $driver.By.css(
        '[data-testid="checkout-error"]'
      )
    );

  if (errors.length > 0) {

    const message =
      await errors[0].getText();

    console.error(
      `[NOVA] CHECKOUT FAILED: ${message}`
    );

    throw new Error(
      `NOVA checkout failed: ${message}`
    );
  }


  /*
   * 9. Business PASS
   */
  const success =
    await $browser.findElements(
      $driver.By.css(
        '[data-testid="checkout-success"]'
      )
    );

  assert.isAbove(
    success.length,
    0,
    "Debe existir checkout-success"
  );


  const successText =
    await success[0].getText();

  assert.isNotEmpty(
    successText,
    "La confirmación no debe estar vacía"
  );


  console.log(
    "[NOVA] CHECKOUT SUCCESS"
  );

  console.log("========================================");
  console.log(" NOVA CUSTOMER JOURNEY : PASS");
  console.log("========================================");

})();
