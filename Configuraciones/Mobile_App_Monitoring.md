# Instrumentación de Aplicaciones Móviles con IBM Instana

## 1. Objetivo

El presente documento tiene como objetivo describir el procedimiento base para instrumentar aplicaciones móviles con **IBM Instana**, considerando aplicaciones nativas **Android**, **iOS**, así como aplicaciones multiplataforma desarrolladas con **React Native** y **Flutter**.

La documentación se divide en dos capas:

- **Capa base de instrumentación:** instalación del agente o SDK, configuración del `APP_KEY`, `REPORTING_URL` e inicialización de Instana dentro de la aplicación.
- **Capa de personalización funcional:** definición de vistas, usuarios, metadata, eventos custom, exclusión de URLs y redacción de información sensible mediante una clase utilitaria o capa centralizada de observabilidad.

La finalidad no es únicamente que Instana reconozca la aplicación móvil, sino que pueda asociar los datos técnicos a flujos funcionales entendibles para equipos técnicos, funcionales y de negocio.

---

## 2. Alcance

El alcance de esta guía considera los siguientes escenarios:

| Plataforma | Lenguaje principal | Tipo de integración |
|---|---|---|
| Android nativo | Kotlin / Java | SDK Android + plugin Gradle |
| iOS nativo | Swift | SDK iOS mediante Swift Package Manager o CocoaPods |
| React Native | TypeScript / JavaScript | Agente React Native |
| Flutter | Dart | Agente Flutter |

> **Nota:** Los ejemplos utilizan nombres genéricos como `YOUR_INSTANA_APP_KEY` y `YOUR_INSTANA_REPORTING_URL`. Estos valores deben obtenerse desde la configuración de Mobile App Monitoring en Instana.

---

## 3. Concepto de instrumentación móvil en Instana

IBM Instana permite monitorear aplicaciones móviles mediante agentes embebidos como dependencia dentro de la aplicación. A partir de esta integración, se puede obtener visibilidad sobre:

- Sesiones móviles.
- Tiempos de respuesta de llamadas HTTP.
- Errores y fallas.
- Crashes, según configuración.
- Vistas o pantallas lógicas.
- Eventos personalizados.
- Usuarios afectados.
- Metadata funcional o técnica.
- Correlación con backend, cuando se habilita trazabilidad compatible.

El valor de la instrumentación no se limita a capturar llamadas HTTP. La personalización permite responder preguntas como:

- ¿En qué flujo funcional ocurrió el error?
- ¿Qué vista estaba utilizando el usuario?
- ¿Qué versión de la aplicación estaba instalada?
- ¿Qué canal, feature flag o flujo estaba activo?
- ¿El problema ocurrió antes o después de confirmar una operación?
- ¿Qué llamadas backend estuvieron asociadas a la experiencia móvil?

La integración debe entenderse en dos niveles:

```text
Aplicación móvil
  ↓
SDK / agente de Instana
  ↓
Captura automática o manual de datos técnicos
  ↓
Personalización funcional con vistas, metadata y eventos
  ↓
Visualización en Instana Mobile App Monitoring
```

---

## 4. Consideraciones previas

Antes de implementar, se recomienda validar con el cliente:

- Plataforma de desarrollo utilizada: Android nativo, iOS nativo, React Native o Flutter.
- Lenguaje utilizado por cada equipo: Kotlin, Java, Swift, TypeScript, JavaScript o Dart.
- Cliente HTTP utilizado por la aplicación.
- Flujos críticos de negocio que se desean observar.
- Política de privacidad y tratamiento de datos personales.
- Ambientes donde se probará la instrumentación: desarrollo, QA, preproducción y producción.
- Definición de nombres funcionales para vistas y eventos.
- Necesidad de correlación con backend mediante headers de trazabilidad.
- URLs, dominios o endpoints que no deben ser capturados.
- Parámetros sensibles que deben ser redactados antes de enviarse a Instana.
- Headers permitidos para captura y headers que deben excluirse por seguridad.

---

# 5. Android Nativo

## 5.1. Capa base de instrumentación

En Android, el agente de Instana se compone de:

- Plugin Gradle de Instana.
- Librería runtime del agente Android.
- Inicialización dentro de la clase `Application`.

### 5.1.1. Agregar plugin en el `build.gradle` del proyecto

```groovy
buildscript {
    ext {
        instanaAgentVersion = "6.3.0" // Versión referencial. Validar última versión compatible.
    }

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath "com.instana:android-agent-plugin:$instanaAgentVersion"
    }
}
```

### 5.1.2. Agregar plugin y dependencia en el módulo app

```groovy
apply plugin: 'com.android.application'
apply plugin: 'com.instana.android-agent-plugin'

dependencies {
    implementation "com.instana:android-agent-runtime:$instanaAgentVersion"
}
```

### 5.1.3. Inicializar Instana en la clase `Application`

```kotlin
import android.app.Application
import com.instana.android.Instana
import com.instana.android.core.InstanaConfig

class MyApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        Instana.setup(
            this,
            InstanaConfig(
                key = BuildConfig.INSTANA_KEY,
                reportingURL = BuildConfig.INSTANA_REPORTING_URL
            )
        )
    }
}
```

> La inicialización debe ejecutarse al inicio de la aplicación, idealmente en `Application.onCreate()`, inmediatamente después de `super.onCreate()`.

---

## 5.2. Capa de personalización Android

Para evitar que cada desarrollador invoque directamente el SDK en distintas partes del código, se recomienda crear una clase utilitaria.

### 5.2.1. Catálogo de vistas

```kotlin
object AppViews {
    const val LOGIN = "Login"
    const val HOME = "Inicio"
    const val BALANCE = "Consulta de saldo"
    const val TRANSFER_FORM = "Formulario de transferencia"
    const val TRANSFER_CONFIRMATION = "Confirmación de transferencia"
    const val TRANSFER_RESULT = "Resultado de transferencia"
    const val PAYMENT_SELECTION = "Selección de pago"
    const val PAYMENT_CONFIRMATION = "Confirmación de pago"
    const val PAYMENT_RESULT = "Resultado de pago"
}
```

### 5.2.2. Catálogo de eventos

```kotlin
object AppEvents {
    const val LOGIN_ATTEMPT = "login_intento"
    const val LOGIN_SUCCESS = "login_exitoso"
    const val LOGIN_FAILED = "login_fallido"
    const val TRANSFER_STARTED = "transferencia_iniciada"
    const val TRANSFER_CONFIRMED = "transferencia_confirmada"
    const val TRANSFER_FAILED = "transferencia_fallida"
    const val PAYMENT_STARTED = "pago_iniciado"
    const val PAYMENT_CONFIRMED = "pago_confirmado"
    const val PAYMENT_FAILED = "pago_fallido"
}
```

### 5.2.3. Clase utilitaria en Kotlin

```kotlin
import com.instana.android.CustomEvent
import com.instana.android.Instana

object InstanaMobileTracker {

    fun setView(viewName: String) {
        Instana.view = viewName
    }

    fun identifyUser(
        userId: String?,
        userEmail: String? = null,
        userName: String? = null
    ) {
        Instana.userId = userId
        Instana.userEmail = userEmail
        Instana.userName = userName
    }

    fun addGlobalMeta(key: String, value: String) {
        Instana.meta.put(key, value)
    }

    fun addGlobalMetadata(metadata: Map<String, String>) {
        metadata.forEach { (key, value) ->
            Instana.meta.put(key, value)
        }
    }

    fun clearGlobalMeta(key: String) {
        Instana.meta.remove(key)
    }

    fun ignoreUrl(regex: Regex) {
        Instana.ignoreURLs.add(regex)
    }

    fun redactHttpQuery(regex: Regex) {
        Instana.redactHTTPQuery.add(regex)
    }

    fun captureHeader(regex: Regex) {
        Instana.captureHeaders.add(regex)
    }

    fun reportEvent(
        eventName: String,
        viewName: String? = null,
        durationMs: Long? = null,
        meta: Map<String, String> = emptyMap()
    ) {
        val event = CustomEvent(eventName).apply {
            if (viewName != null) {
                this.viewName = viewName
            }

            if (durationMs != null) {
                this.duration = durationMs
            }

            if (meta.isNotEmpty()) {
                this.meta = meta
            }
        }

        Instana.reportEvent(event)
    }
}
```

---

## 5.3. Ejemplos de uso en Android

### 5.3.1. Asignar nombre funcional de vista

```kotlin
class PaymentActivity : AppCompatActivity() {

    override fun onResume() {
        super.onResume()

        InstanaMobileTracker.setView(AppViews.PAYMENT_SELECTION)
    }
}
```

### 5.3.2. Registrar evento custom

```kotlin
fun onPayButtonClicked() {
    InstanaMobileTracker.reportEvent(
        eventName = AppEvents.PAYMENT_STARTED,
        viewName = AppViews.PAYMENT_SELECTION,
        meta = mapOf(
            "payment_method" to "card",
            "flow" to "checkout"
        )
    )
}
```

### 5.3.3. Agregar metadata global

```kotlin
InstanaMobileTracker.addGlobalMetadata(
    mapOf(
        "environment" to "production",
        "channel" to "mobile",
        "platform" to "android",
        "app_version" to BuildConfig.VERSION_NAME,
        "feature_flag_new_checkout" to "enabled"
    )
)
```

La metadata global se adjunta a los beacons que envía Instana. Es útil para identificar contexto técnico o funcional, por ejemplo ambiente, canal, versión, feature flag o tipo de flujo.

### 5.3.4. Identificar usuario

```kotlin
InstanaMobileTracker.identifyUser(
    userId = "hash_9f86d081884c7d659a2feaa0c55ad015",
    userEmail = null,
    userName = "Anonymous"
)
```

> Se recomienda utilizar identificadores internos o hasheados. No se recomienda enviar DNI, número de cuenta, número de tarjeta, token, correo personal o información sensible sin validación previa de privacidad.

### 5.3.5. Excluir URLs del monitoreo automático

```kotlin
class MyApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        Instana.setup(
            this,
            InstanaConfig(
                key = BuildConfig.INSTANA_KEY,
                reportingURL = BuildConfig.INSTANA_REPORTING_URL
            )
        )

        // Excluir URLs que contienen parámetros sensibles.
        Instana.ignoreURLs.add(".*([&?])password=.*".toRegex())

        // Excluir endpoint de autenticación, si por política no debe ser capturado.
        Instana.ignoreURLs.add(".*\/auth\/token.*".toRegex())

        // Excluir endpoints internos de health-check.
        Instana.ignoreURLs.add(".*\/health.*".toRegex())
    }
}
```

> La exclusión aplica sobre URLs monitoreadas automáticamente. Las capturas manuales deben gestionarse directamente en el código que reporta el request.

### 5.3.6. Redactar parámetros sensibles de URL

```kotlin
class MyApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        Instana.setup(
            this,
            InstanaConfig(
                key = BuildConfig.INSTANA_KEY,
                reportingURL = BuildConfig.INSTANA_REPORTING_URL
            )
        )

        // Redactar valores de parámetros sensibles.
        Instana.redactHTTPQuery.add("token".toRegex())
        Instana.redactHTTPQuery.add("secret".toRegex())
        Instana.redactHTTPQuery.add("password".toRegex())
        Instana.redactHTTPQuery.add("session_id".toRegex())
    }
}
```

Ejemplo esperado:

```text
URL original:
https://api.empresa.com/login?token=abc123&channel=mobile

URL visualizada:
https://api.empresa.com/login?token=<redacted>&channel=mobile
```

### 5.3.7. Capturar headers controlados

```kotlin
Instana.captureHeaders.add("X-Correlation-ID".toRegex())
Instana.captureHeaders.add("X-Request-ID".toRegex())
```

> Solo deben capturarse headers no sensibles. No capturar `Authorization`, `Cookie`, `Set-Cookie`, tokens o credenciales.

### 5.3.8. Uso desde un Fragment

```kotlin
class TransferFragment : Fragment() {

    override fun onResume() {
        super.onResume()

        InstanaMobileTracker.setView(AppViews.TRANSFER_FORM)
    }
}
```

---

## 5.4. Ejemplo equivalente en Java

En proyectos Android que todavía utilizan Java, se puede mantener el mismo enfoque.

```java
import com.instana.android.CustomEvent;
import com.instana.android.Instana;

import java.util.Map;
import java.util.concurrent.TimeUnit;

public final class InstanaMobileTracker {

    private InstanaMobileTracker() {
        // Utility class
    }

    public static void setView(String viewName) {
        Instana.setView(viewName);
    }

    public static void identifyUser(String userId, String email, String name) {
        Instana.setUserId(userId);
        Instana.setUserEmail(email);
        Instana.setUserName(name);
    }

    public static void addGlobalMeta(String key, String value) {
        Instana.getMeta().put(key, value);
    }

    public static void reportEvent(
            String eventName,
            String viewName,
            Long durationMs,
            Map<String, String> meta
    ) {
        CustomEvent event = new CustomEvent(eventName);

        if (viewName != null) {
            event.setViewName(viewName);
        }

        if (durationMs != null) {
            event.setDuration(durationMs, TimeUnit.MILLISECONDS);
        }

        if (meta != null && !meta.isEmpty()) {
            event.setMeta(meta);
        }

        Instana.reportEvent(event);
    }
}
```

Uso desde una `Activity`:

```java
public class LoginActivity extends AppCompatActivity {

    @Override
    protected void onResume() {
        super.onResume();

        InstanaMobileTracker.setView("Login");
    }
}
```

---

# 6. iOS Nativo

## 6.1. Capa base de instrumentación

En iOS, el agente puede agregarse mediante:

- Swift Package Manager.
- CocoaPods.

### 6.1.1. Opción Swift Package Manager

Desde Xcode:

```text
File > Add Package Dependencies
```

Agregar el repositorio del agente iOS de Instana:

```text
https://github.com/instana/iOSAgent
```

### 6.1.2. Opción CocoaPods

Agregar en el `Podfile`:

```ruby
pod 'InstanaAgent', '~> 1.8.9'
```

Luego ejecutar:

```bash
pod install
```

> La versión indicada es referencial. Se recomienda validar la versión más reciente compatible antes de implementar en producción.

### 6.1.3. Inicialización en `AppDelegate`

```swift
import UIKit
import InstanaAgent

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        Instana.setup(
            key: InstanaConfig.appKey,
            reportingURL: InstanaConfig.reportingURL
        )

        return true
    }
}
```

---

## 6.2. Capa de personalización iOS

En iOS, la vista debe asignarse cuando realmente se presenta al usuario. Para ello, se recomienda utilizar `viewDidAppear`.

### 6.2.1. Catálogo de vistas

```swift
enum AppViews {
    static let login = "Login"
    static let home = "Inicio"
    static let balance = "Consulta de saldo"
    static let transferForm = "Formulario de transferencia"
    static let transferConfirmation = "Confirmación de transferencia"
    static let transferResult = "Resultado de transferencia"
    static let paymentSelection = "Selección de pago"
    static let paymentConfirmation = "Confirmación de pago"
    static let paymentResult = "Resultado de pago"
}
```

### 6.2.2. Catálogo de eventos

```swift
enum AppEvents {
    static let loginAttempt = "login_intento"
    static let loginSuccess = "login_exitoso"
    static let loginFailed = "login_fallido"
    static let transferStarted = "transferencia_iniciada"
    static let transferConfirmed = "transferencia_confirmada"
    static let transferFailed = "transferencia_fallida"
    static let paymentStarted = "pago_iniciado"
    static let paymentConfirmed = "pago_confirmado"
    static let paymentFailed = "pago_fallido"
}
```

### 6.2.3. Clase utilitaria en Swift

```swift
import Foundation
import InstanaAgent

final class InstanaMobileTracker {

    static func setView(_ viewName: String) {
        Instana.setView(name: viewName)
    }

    static func identifyUser(
        id: String,
        email: String? = nil,
        name: String? = nil
    ) {
        Instana.setUser(id: id, email: email, name: name)
    }

    static func addGlobalMeta(key: String, value: String) {
        Instana.setMeta(value: value, key: key)
    }

    static func reportEvent(
        name: String,
        viewName: String? = nil,
        durationMs: Int64? = nil,
        meta: [String: String]? = nil
    ) {
        Instana.reportEvent(
            name: name,
            duration: durationMs,
            meta: meta,
            viewName: viewName
        )
    }

    static func redactHttpQuery(pattern: String) {
        if let regex = try? NSRegularExpression(pattern: pattern) {
            Instana.redactHTTPQuery(matching: [regex])
        }
    }

    static func captureHeader(pattern: String) {
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            Instana.setCaptureHeaders(matching: [regex])
        }
    }
}
```

---

## 6.3. Ejemplos de uso en iOS

### 6.3.1. Asignar nombre funcional de vista

```swift
class PaymentViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        InstanaMobileTracker.setView(AppViews.paymentSelection)
    }
}
```

### 6.3.2. Registrar evento custom

```swift
@IBAction func didTapPayButton(_ sender: UIButton) {
    InstanaMobileTracker.reportEvent(
        name: AppEvents.paymentStarted,
        viewName: AppViews.paymentSelection,
        meta: [
            "payment_method": "card",
            "flow": "checkout"
        ]
    )
}
```

### 6.3.3. Agregar metadata global

```swift
InstanaMobileTracker.addGlobalMeta(key: "environment", value: "production")
InstanaMobileTracker.addGlobalMeta(key: "channel", value: "mobile")
InstanaMobileTracker.addGlobalMeta(key: "platform", value: "ios")
InstanaMobileTracker.addGlobalMeta(key: "app_version", value: Bundle.main.releaseVersionNumber ?? "unknown")
InstanaMobileTracker.addGlobalMeta(key: "feature_flag_new_checkout", value: "enabled")
```

Ejemplo de extensión para obtener la versión de la app:

```swift
extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
```

### 6.3.4. Identificar usuario

```swift
InstanaMobileTracker.identifyUser(
    id: "hash_9f86d081884c7d659a2feaa0c55ad015",
    email: nil,
    name: "Anonymous"
)
```

### 6.3.5. Redactar parámetros sensibles

```swift
InstanaMobileTracker.redactHttpQuery(pattern: #"token"#)
InstanaMobileTracker.redactHttpQuery(pattern: #"secret"#)
InstanaMobileTracker.redactHttpQuery(pattern: #"password"#)
InstanaMobileTracker.redactHttpQuery(pattern: #"session_id"#)
```

Ejemplo esperado:

```text
URL original:
https://api.empresa.com/login?password=abc123&channel=mobile

URL visualizada:
https://api.empresa.com/login?password=<redacted>&channel=mobile
```

### 6.3.6. Capturar headers controlados

```swift
InstanaMobileTracker.captureHeader(pattern: #"X-Correlation-ID"#)
InstanaMobileTracker.captureHeader(pattern: #"X-Request-ID"#)
```

> Solo deben capturarse headers no sensibles. No capturar `Authorization`, `Cookie`, `Set-Cookie`, tokens o credenciales.

---

# 7. React Native

## 7.1. Capa base de instrumentación

React Native utiliza el paquete:

```bash
npm install @instana/react-native-agent --save
```

o:

```bash
yarn add @instana/react-native-agent
```

### 7.1.1. Inicialización en `App.tsx`

```typescript
import React, { useEffect } from 'react';
import Instana from '@instana/react-native-agent';

export default function App() {

  useEffect(() => {
    Instana.setup(
      'YOUR_INSTANA_APP_KEY',
      'YOUR_INSTANA_REPORTING_URL',
      null
    );

    Instana.setIgnoreURLsByRegex(['http://localhost:8081.*']);
  }, []);

  return null;
}
```

> Para evitar ruido en los datos, se recomienda excluir el tráfico hacia Metro Bundler durante el desarrollo local.

### 7.1.2. Consideración Android para React Native

Para habilitar el monitoreo HTTP automático en Android, el proyecto React Native debe tener configurado el plugin Android de Instana compatible con la versión de React Native utilizada.

Ejemplo referencial en `/android/build.gradle`:

```groovy
buildscript {
    ext {
        INSTANA_ANDROID_PLUGIN_VERSION = "6.2.5" // Versión referencial
    }

    dependencies {
        classpath "com.instana:android-agent-plugin:$INSTANA_ANDROID_PLUGIN_VERSION"
    }
}
```

Ejemplo referencial en `/android/app/build.gradle`:

```groovy
apply plugin: 'com.android.application'
apply plugin: 'com.instana.android-agent-plugin'
```

---

## 7.2. Capa de personalización React Native

### 7.2.1. Archivo `instanaTracker.ts`

```typescript
import Instana from '@instana/react-native-agent';

type EventMeta = Record<string, string>;

export const InstanaTracker = {

  setView(viewName: string): void {
    Instana.setView(viewName);
  },

  identifyUser(userId: string, email?: string, name?: string): void {
    Instana.setUserID(userId);

    if (email) {
      Instana.setUserEmail(email);
    }

    if (name) {
      Instana.setUserName(name);
    }
  },

  addGlobalMeta(key: string, value: string): void {
    Instana.setMeta(key, value);
  },

  async ignoreUrls(regexArray: string[]): Promise<void> {
    await Instana.setIgnoreURLsByRegex(regexArray);
  },

  async redactHttpQuery(regexArray: string[]): Promise<void> {
    await Instana.setRedactHTTPQueryByRegex(regexArray);
  },

  async captureHeaders(regexArray: string[]): Promise<void> {
    await Instana.setCaptureHeadersByRegex(regexArray);
  },

  reportEvent(
    eventName: string,
    viewName?: string,
    meta?: EventMeta,
    durationMs?: number
  ): void {
    Instana.reportEvent(eventName, {
      viewName,
      duration: durationMs,
      meta
    });
  }
};
```

### 7.2.2. Catálogo de vistas y eventos

```typescript
export const AppViews = {
  LOGIN: 'Login',
  HOME: 'Inicio',
  BALANCE: 'Consulta de saldo',
  TRANSFER_FORM: 'Formulario de transferencia',
  TRANSFER_CONFIRMATION: 'Confirmación de transferencia',
  TRANSFER_RESULT: 'Resultado de transferencia',
  PAYMENT_SELECTION: 'Selección de pago',
  PAYMENT_CONFIRMATION: 'Confirmación de pago',
  PAYMENT_RESULT: 'Resultado de pago',
} as const;

export const AppEvents = {
  LOGIN_ATTEMPT: 'login_intento',
  LOGIN_SUCCESS: 'login_exitoso',
  LOGIN_FAILED: 'login_fallido',
  TRANSFER_STARTED: 'transferencia_iniciada',
  TRANSFER_CONFIRMED: 'transferencia_confirmada',
  TRANSFER_FAILED: 'transferencia_fallida',
  PAYMENT_STARTED: 'pago_iniciado',
  PAYMENT_CONFIRMED: 'pago_confirmado',
  PAYMENT_FAILED: 'pago_fallido',
} as const;
```

### 7.2.3. Uso con React Navigation

```typescript
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { InstanaTracker } from './observability/instanaTracker';
import { AppViews } from './observability/appViews';

const routeNameRef = React.useRef<string | undefined>();
const navigationRef = React.useRef<any>();

function mapRouteToBusinessView(routeName?: string): string {
  const views: Record<string, string> = {
    LoginScreen: AppViews.LOGIN,
    HomeScreen: AppViews.HOME,
    BalanceScreen: AppViews.BALANCE,
    TransferScreen: AppViews.TRANSFER_FORM,
    TransferResultScreen: AppViews.TRANSFER_RESULT,
    PaymentScreen: AppViews.PAYMENT_SELECTION,
    PaymentResultScreen: AppViews.PAYMENT_RESULT,
  };

  return views[routeName ?? ''] ?? 'Vista no catalogada';
}

export function AppNavigation() {
  return (
    <NavigationContainer
      ref={navigationRef}
      onReady={() => {
        const currentRouteName = navigationRef.current?.getCurrentRoute()?.name;
        routeNameRef.current = currentRouteName;

        InstanaTracker.setView(mapRouteToBusinessView(currentRouteName));
      }}
      onStateChange={() => {
        const currentRouteName = navigationRef.current?.getCurrentRoute()?.name;

        if (routeNameRef.current !== currentRouteName) {
          routeNameRef.current = currentRouteName;

          InstanaTracker.setView(mapRouteToBusinessView(currentRouteName));
        }
      }}
    >
      {/* Stack / Tabs */}
    </NavigationContainer>
  );
}
```

### 7.2.4. Uso desde una pantalla

```typescript
import { InstanaTracker } from './observability/instanaTracker';
import { AppEvents, AppViews } from './observability/appCatalog';

function onPayButtonPressed() {
  InstanaTracker.reportEvent(
    AppEvents.PAYMENT_STARTED,
    AppViews.PAYMENT_SELECTION,
    {
      payment_method: 'card',
      flow: 'checkout'
    }
  );
}
```

### 7.2.5. Ejemplo de metadata global

```typescript
InstanaTracker.addGlobalMeta('environment', 'production');
InstanaTracker.addGlobalMeta('channel', 'mobile');
InstanaTracker.addGlobalMeta('platform', 'react-native');
InstanaTracker.addGlobalMeta('app_version', '3.2.1');
InstanaTracker.addGlobalMeta('feature_flag_new_checkout', 'enabled');
```

### 7.2.6. Ejemplo de exclusión y redacción de URLs

```typescript
await InstanaTracker.ignoreUrls([
  'http://localhost:8081.*',
  '.*\/auth\/token.*',
  '.*\/health.*'
]);

await InstanaTracker.redactHttpQuery([
  'token',
  'secret',
  'password',
  'session_id'
]);

await InstanaTracker.captureHeaders([
  'X-Correlation-ID',
  'X-Request-ID'
]);
```

---

# 8. Flutter

## 8.1. Capa base de instrumentación

En Flutter, el agente se agrega como dependencia en `pubspec.yaml`.

```yaml
dependencies:
  instana_agent:
```

Luego ejecutar:

```bash
flutter pub get
```

### 8.1.1. Inicialización

```dart
import 'package:flutter/material.dart';
import 'package:instana_agent/instana_agent.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();

    setupInstana();
  }

  Future<void> setupInstana() async {
    await InstanaAgent.setup(
      key: 'YOUR_INSTANA_APP_KEY',
      reportingUrl: 'YOUR_INSTANA_REPORTING_URL',
    );
  }
}
```

> En Flutter, la captura HTTP requiere configuración adicional. No debe asumirse que todas las llamadas HTTP quedarán instrumentadas automáticamente.

---

## 8.2. Capa de personalización Flutter

### 8.2.1. Catálogo de vistas y eventos

```dart
class AppViews {
  static const login = 'Login';
  static const home = 'Inicio';
  static const balance = 'Consulta de saldo';
  static const transferForm = 'Formulario de transferencia';
  static const transferConfirmation = 'Confirmación de transferencia';
  static const transferResult = 'Resultado de transferencia';
  static const paymentSelection = 'Selección de pago';
  static const paymentConfirmation = 'Confirmación de pago';
  static const paymentResult = 'Resultado de pago';
}

class AppEvents {
  static const loginAttempt = 'login_intento';
  static const loginSuccess = 'login_exitoso';
  static const loginFailed = 'login_fallido';
  static const transferStarted = 'transferencia_iniciada';
  static const transferConfirmed = 'transferencia_confirmada';
  static const transferFailed = 'transferencia_fallida';
  static const paymentStarted = 'pago_iniciado';
  static const paymentConfirmed = 'pago_confirmado';
  static const paymentFailed = 'pago_fallido';
}
```

### 8.2.2. Clase utilitaria `instana_tracker.dart`

```dart
import 'package:instana_agent/instana_agent.dart';

class InstanaTracker {

  static Future<void> setView(String viewName) async {
    await InstanaAgent.setView(viewName);
  }

  static Future<void> identifyUser({
    required String userId,
    String? email,
    String? name,
  }) async {
    await InstanaAgent.setUserID(userId);

    if (email != null) {
      await InstanaAgent.setUserEmail(email);
    }

    if (name != null) {
      await InstanaAgent.setUserName(name);
    }
  }

  static Future<void> addGlobalMeta({
    required String key,
    required String value,
  }) async {
    await InstanaAgent.setMeta(key: key, value: value);
  }

  static Future<void> reportEvent({
    required String name,
    String? viewName,
    Map<String, String>? meta,
    int? durationMs,
  }) async {
    final options = EventOptions();

    if (viewName != null) {
      options.viewName = viewName;
    }

    if (meta != null) {
      options.meta = meta;
    }

    if (durationMs != null) {
      options.duration = durationMs;
    }

    await InstanaAgent.reportEvent(
      name: name,
      options: options,
    );
  }
}
```

### 8.2.3. Uso desde una pantalla Flutter

```dart
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {

  @override
  void initState() {
    super.initState();

    InstanaTracker.setView(AppViews.paymentSelection);
  }

  void onPayPressed() {
    InstanaTracker.reportEvent(
      name: AppEvents.paymentStarted,
      viewName: AppViews.paymentSelection,
      meta: {
        'payment_method': 'card',
        'flow': 'checkout',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
```

### 8.2.4. Ejemplo de metadata global

```dart
await InstanaTracker.addGlobalMeta(
  key: 'environment',
  value: 'production',
);

await InstanaTracker.addGlobalMeta(
  key: 'channel',
  value: 'mobile',
);

await InstanaTracker.addGlobalMeta(
  key: 'platform',
  value: 'flutter',
);

await InstanaTracker.addGlobalMeta(
  key: 'feature_flag_new_checkout',
  value: 'enabled',
);
```

### 8.2.5. Ejemplo de captura HTTP manual en Flutter

```dart
import 'package:http/http.dart';
import 'package:instana_agent/instana_agent.dart';

class InstrumentedHttpClient extends BaseClient {

  InstrumentedHttpClient(this._inner);

  final Client _inner;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final marker = await InstanaAgent.startCapture(
      url: request.url.toString(),
      method: request.method,
      viewName: InstanaAgent.currentViewName,
    );

    try {
      final response = await _inner.send(request);

      marker
        ..responseStatusCode = response.statusCode
        ..responseSizeBody = response.contentLength
        ..responseHeaders = response.headers;

      return response;
    } catch (error) {
      marker.errorMessage = error.toString();
      rethrow;
    } finally {
      await marker.finish();
    }
  }
}
```

> La implementación exacta puede variar según la versión del agente Flutter utilizada. Se recomienda validar contra la documentación oficial del SDK.

---

# 9. Estrategia recomendada de carpetas

Se recomienda que la aplicación mantenga una capa común de observabilidad:

```text
/mobile
  /observability
    InstanaConfig
    InstanaTracker
    AppViews
    AppEvents
```

Esta estructura permite:

- Centralizar el uso del SDK.
- Evitar llamadas dispersas a Instana en toda la aplicación.
- Homologar nombres de vistas y eventos.
- Facilitar el mantenimiento.
- Reducir errores de nomenclatura.
- Facilitar auditoría y revisión con el cliente.

---

# 10. Catálogo funcional recomendado

## 10.1. Vistas funcionales

| Flujo | Vista sugerida |
|---|---|
| Autenticación | Login |
| Inicio | Inicio |
| Cuentas | Consulta de saldo |
| Transferencias | Formulario de transferencia |
| Transferencias | Confirmación de transferencia |
| Transferencias | Resultado de transferencia |
| Pagos | Selección de pago |
| Pagos | Confirmación de pago |
| Pagos | Resultado de pago |
| Perfil | Perfil de usuario |
| Error | Error funcional |

## 10.2. Eventos funcionales

| Evento | Cuándo utilizarlo |
|---|---|
| `login_intento` | Cuando el usuario inicia el proceso de autenticación |
| `login_exitoso` | Cuando la autenticación finaliza correctamente |
| `login_fallido` | Cuando la autenticación falla |
| `transferencia_iniciada` | Cuando el usuario inicia una transferencia |
| `transferencia_confirmada` | Cuando la transferencia se confirma |
| `transferencia_fallida` | Cuando la transferencia falla |
| `pago_iniciado` | Cuando el usuario inicia un pago |
| `pago_confirmado` | Cuando el pago se confirma |
| `pago_fallido` | Cuando el pago falla |
| `sesion_expirada` | Cuando la sesión del usuario expira |
| `error_funcional` | Cuando ocurre un error controlado dentro del flujo |

---

# 11. Buenas prácticas

## 11.1. Nombres de vistas

No se recomienda utilizar nombres técnicos como:

```text
PaymentActivity
LoginFragment
UserViewController
WebViewActivity
```

Se recomienda utilizar nombres funcionales como:

```text
Login
Selección de pago
Confirmación de transferencia
Resultado de operación
Consulta de saldo
```

Esto permite que los datos sean entendidos por equipos técnicos y no técnicos.

---

## 11.2. Uso de metadata

La metadata debe utilizarse para agregar contexto técnico o funcional.

Ejemplos recomendados:

```text
environment = production
channel = mobile
platform = android
app_version = 3.2.1
feature_flag_new_checkout = enabled
flow = checkout
```

No se recomienda enviar:

```text
DNI
número de tarjeta
número de cuenta
tokens
contraseñas
datos personales sensibles
valores financieros sensibles
```

---

## 11.3. Identificación de usuarios

Cuando se requiera asociar eventos a usuarios, se recomienda utilizar:

- ID interno no sensible.
- ID hasheado.
- Identificador funcional que no exponga información personal directa.

Ejemplo:

```text
userId = hash_9f86d081884c7d659a2feaa0c55ad015
userName = Anonymous
```

> Si el cliente no tiene autorización para enviar datos personales, no se debe enviar correo, nombre real, DNI u otros datos sensibles.

---

## 11.4. Eventos custom

Los eventos custom deben utilizarse para acciones relevantes del negocio, no para cada clic de la aplicación.

Buen uso:

```text
pago_iniciado
pago_confirmado
transferencia_fallida
login_fallido
sesion_expirada
```

Uso no recomendado:

```text
click_button_1
tap_icon
open_modal
close_popup
scroll_down
```

El exceso de eventos puede generar ruido y dificultar el análisis.

---

## 11.5. Lifecycle correcto

| Plataforma | Momento recomendado para `setView` |
|---|---|
| Android Activity | `onResume()` |
| Android Fragment | `onResume()` |
| iOS ViewController | `viewDidAppear()` |
| React Native | Cambio de ruta activa |
| Flutter | Presentación de la pantalla o navegación activa |

La vista debe asignarse cuando el usuario realmente visualiza la pantalla, no únicamente cuando la pantalla se crea.

---

## 11.6. Exclusión y redacción de URLs

En aplicaciones móviles, las URLs pueden contener parámetros sensibles. Por ello, se recomienda aplicar dos criterios:

| Criterio | Uso recomendado |
|---|---|
| Excluir URL | Cuando el endpoint completo no debe monitorearse |
| Redactar query parameter | Cuando se puede monitorear el endpoint, pero ocultando valores sensibles |

Ejemplo:

```text
Excluir:
https://api.empresa.com/auth/token

Redactar:
https://api.empresa.com/login?token=<redacted>&channel=mobile
```

No se recomienda exponer:

```text
password
token
secret
session_id
authorization_code
refresh_token
access_token
card_number
account_number
```

---

## 11.7. Captura de headers

La captura de headers debe ser excepcional y controlada. Puede ser útil para correlación técnica, pero también puede introducir riesgo de exposición de información sensible.

Headers recomendados:

```text
X-Correlation-ID
X-Request-ID
traceparent
tracestate
```

Headers no recomendados:

```text
Authorization
Cookie
Set-Cookie
X-Api-Key
Proxy-Authorization
```

---

# 12. Validaciones posteriores a la implementación

Después de implementar la instrumentación, se recomienda validar:

- La aplicación aparece en Instana Mobile App Monitoring.
- Se registran sesiones móviles.
- Las llamadas HTTP aparecen asociadas a la aplicación.
- Las vistas funcionales se visualizan correctamente.
- Los eventos custom se reciben con el nombre esperado.
- La metadata se adjunta correctamente.
- No se envían datos sensibles.
- Los errores y crashes se visualizan según configuración.
- El tráfico local o de desarrollo se encuentra excluido cuando corresponda.
- Las vistas tienen nombres homogéneos entre Android, iOS y frameworks híbridos.
- Los parámetros sensibles aparecen redactados.
- Los endpoints excluidos no aparecen en Instana.
- Los headers capturados son únicamente los aprobados.

---

# 13. Plan de implementación sugerido

La siguiente matriz permite ordenar la implementación por fases, manteniendo una separación clara entre instrumentación técnica y personalización funcional.

| Fase | Actividad | Resultado esperado |
|---|---|---|
| 1 | Instalar SDK/agente móvil | La aplicación queda preparada para enviar datos a Instana |
| 2 | Inicializar Instana con `APP_KEY` y `REPORTING_URL` | La app aparece en Mobile App Monitoring |
| 3 | Validar captura HTTP automática o manual | Se observan requests móviles |
| 4 | Crear capa utilitaria `InstanaMobileTracker` | El uso del SDK queda centralizado |
| 5 | Definir catálogo de vistas | Las pantallas se visualizan con nombres funcionales |
| 6 | Definir catálogo de eventos | Las acciones críticas quedan registradas |
| 7 | Agregar metadata global controlada | Los beacons tienen contexto técnico y funcional |
| 8 | Definir estrategia de usuario | Se identifica impacto por usuario sin exponer datos sensibles |
| 9 | Excluir URLs no permitidas | No se capturan endpoints restringidos |
| 10 | Redactar parámetros sensibles | Los secretos no llegan a Instana |
| 11 | Validar en ambiente QA | Se confirma el comportamiento antes de producción |
| 12 | Promover a producción | La observabilidad queda habilitada en operación real |

---

# 14. Enfoque recomendado de implementación

La instalación base del SDK permite que IBM Instana reconozca la aplicación móvil y capture información técnica como sesiones, llamadas HTTP, errores y comportamiento general de la app.

Sin embargo, para obtener mayor valor funcional, se recomienda implementar una capa utilitaria de observabilidad por plataforma.

Esta capa centraliza la asignación de vistas, usuarios, metadata, eventos custom, exclusión de URLs y redacción de parámetros sensibles. De esta manera, evitamos que cada desarrollador invoque directamente el SDK de Instana de forma dispersa, y logramos que los datos se visualicen con nombres funcionales entendibles, como `Login`, `Selección de pago`, `Confirmación de transferencia` o `Resultado de operación`.

Con este enfoque, Instana no solo muestra que una llamada fue lenta o que ocurrió un error, sino también en qué flujo funcional ocurrió, qué versión de la aplicación estaba involucrada y qué contexto técnico o funcional acompañó la experiencia del usuario.

---

# 15. Consideraciones finales

Para una implementación profesional, se recomienda abordar la instrumentación móvil en dos fases:

## Fase 1: Instrumentación base

- Instalar SDK.
- Configurar credenciales.
- Inicializar Instana.
- Validar sesiones, requests, errores y visibilidad básica.

## Fase 2: Personalización funcional

- Crear clase utilitaria.
- Definir catálogo de vistas.
- Definir catálogo de eventos.
- Agregar metadata controlada.
- Definir estrategia de identificación de usuario.
- Excluir URLs no permitidas.
- Redactar parámetros sensibles.
- Definir headers permitidos.
- Validar privacidad.
- Probar flujos críticos.

Este enfoque permite pasar de una integración técnica básica a una estrategia de observabilidad móvil alineada a la experiencia real del usuario.

---

# 16. Referencias oficiales

- IBM Instana - Monitoring mobile applications: https://www.ibm.com/docs/en/instana-observability?topic=instana-monitoring-mobile-applications
- IBM Instana - Android monitoring API: https://www.ibm.com/docs/en/instana-observability?topic=applications-android-api
- IBM Instana - iOS API: https://www.ibm.com/docs/en/instana-observability?topic=applications-ios-api
- IBM Instana - React Native API: https://www.ibm.com/docs/en/instana-observability?topic=applications-react-native-api
- IBM Instana - Flutter monitoring API: https://www.ibm.com/docs/en/instana-observability?topic=applications-flutter-monitoring-api
