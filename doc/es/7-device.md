# Dispositivo

## ID de dispositivo persistente

`DefaultDeviceIdService` genera un UUID v4 por instalación en la primera llamada a `getId()` y lo persiste con `flutter_secure_storage` (Keychain en iOS/macOS, EncryptedSharedPreferences en Android).

- iOS/macOS: sobrevive a la reinstalación (Keychain persiste).
- Android: se pierde al reinstalar o limpiar los datos de la app.

> **Importante:** el ID persistente **no se adjunta automáticamente a los eventos**. Se usa exclusivamente para detectar la primera ejecución y emitir el evento sintético `first_open` cuando pasas `recordFirstOpen: true` a [`createUmamiAnalytics()`](1-initialization.md). Para incluir un identificador estable en cada evento, fija `userId` en `FlutterUmamiConfig` o invoca `identify()` (el campo `id` del payload se rellena con `config.userId ?? sessionId`).

Las claves de secure storage se namespacen con `instanceName` mediante `instanceSuffix()`:

```text
# sin instanceName
umami_device_id
umami_first_launch

# con instanceName = "foo"
umami_device_id_foo
umami_first_launch_foo
```

### `DeviceIdPort`

Contrato del dominio para el identificador persistente. El factory construye `DefaultDeviceIdService` **sólo cuando `recordFirstOpen: true`**; fuera de ese caso el adapter no se instancia y el parámetro `deviceId` de [`createUmamiAnalytics()`](1-initialization.md) se ignora.

Implementación personalizada (el adapter por defecto no se exporta; inyecta tu propio `DeviceIdPort`):

```dart
class CustomDeviceId implements DeviceIdPort {
  @override
  Future<String> getId() async => 'my-stable-id';

  @override
  Future<bool> isFirstLaunch() async => false;

  @override
  Future<void> reset() async {/* ... */}
}
```

Inyéctalo vía `deviceId` en [`createUmamiAnalytics()`](1-initialization.md) **junto con `recordFirstOpen: true`**; de lo contrario no tendrá efecto.

## Información del dispositivo

`DefaultDeviceInfoService.gather()` produce un snapshot [`DeviceInfoData`] inmutable que el `TrackingCollector` lee al construir cada payload:

| Campo              | Origen                                                                | Enviado a Umami | Ejemplo                  |
| ------------------ | --------------------------------------------------------------------- | --------------- | ------------------------ |
| `screenResolution` | `WidgetsBinding.instance.platformDispatcher.views.first.physicalSize` | sí (`screen`)   | `1920x1080` (px físicos) |
| `locale`           | `WidgetsBinding.instance.platformDispatcher.locale.toString()`        | sí (`language`) | `en_US`                  |
| `platform`         | `PlatformDetector.detect()` (`dart:io` Platform / `kIsWeb`)           | no              | `ios`/`android`/`web`    |

> `platform` se recolecta pero **no forma parte del payload**; lo emplea internamente `UserAgentService` para elegir el User-Agent.

El resultado se cachea en memoria tras la primera llamada; invocar `gather()` de nuevo no vuelve a consultar `WidgetsBinding`. Si `platformDispatcher` no está disponible (p. ej. fuera de la zona de Flutter), `screenResolution` y `locale` caen a `"unknown"`.

Inyecta tu propia implementación pasando `deviceInfo` a [`createUmamiAnalytics()`](1-initialization.md):

```dart
class CustomDeviceInfo implements DeviceInfoPort {
  @override
  DeviceInfoData gather() => const DeviceInfoData(
    locale: 'es-ES',
    screenResolution: '1080x1920',
    platform: 'android',
  );
}
```

## User-Agent

`DefaultHttpClient` fija un User-Agent realista por plataforma vía `UserAgentService.defaultUserAgent`:

| Plataforma        | User-Agent emulado                                            |
| ----------------- | ------------------------------------------------------------- |
| Android           | Chrome 120 Mobile (inyecta `Platform.operatingSystemVersion`) |
| iOS               | Safari 17 Mobile                                              |
| macOS             | Safari 17 Desktop                                             |
| Windows           | Chrome 120 Desktop                                            |
| Linux             | Chrome 120 Desktop                                            |
| Web / desconocida | `Mozilla/5.0 (compatible; FlutterUmami/1.0)`                  |

El valor se selecciona una sola vez (cacheado en `UserAgentService._cached`) y se reutiliza durante toda la vida del proceso.

Para usar un User-Agent distinto, inyecta tu propio `http.Client` con el parámetro `httpClient` de [`createUmamiAnalytics()`](1-initialization.md) e impón la cabecera `User-Agent` en cada petición `POST` (el adapter interno siempre añade la suya, por lo que tu cliente debe sobrescribirla). Ver [10-advanced.md](10-advanced.md).

## Web y detalles del dispositivo (1.3.0)

- En web, el ID de dispositivo se guarda en `localStorage` (`umami_device_id[_instanceName]`). Es por perfil de navegador y por origen, y se borra al limpiar los datos del sitio.
- En web, el navegador envía su propio User-Agent; el SDK nunca define esa cabecera.
- `DefaultDeviceInfoService.load()` lee `osName`, `osVersion`, `deviceModel`, `appVersion`, `appBuild`, `browserName` y `browserVersion` (`device_info_plus`, `package_info_plus`, o el User-Agent del navegador en web). En nativo, el User-Agent incluye la versión real del sistema operativo.
- `locale` usa BCP-47 (`en-US`) y `screenResolution` usa píxeles lógicos.
- Con `FlutterUmamiConfig(attachDeviceData: true)`, `trackEvent` añade estos campos a `data`.

Detalles completos en la versión inglesa: [doc/en/7-device.md](../en/7-device.md).
