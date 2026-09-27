# Device

## Persistent device ID

`DefaultDeviceIdService` generates a UUID v4 per installation on the first call to `getId()` and persists it with `flutter_secure_storage` (Keychain on iOS/macOS, EncryptedSharedPreferences on Android). On web the ID is stored in `localStorage` instead (see [Web storage](#web-storage)).

- iOS/macOS: survives reinstalls (Keychain persists).
- Android: lost on reinstall or when app data is cleared.

> **Important:** the persistent ID **is not automatically attached to events**. It is used exclusively to detect the first launch and emit the synthetic `first_open` event when you pass `recordFirstOpen: true` to [`createUmamiAnalytics()`](1-initialization.md). To include a stable identifier on every event, set `userId` in `FlutterUmamiConfig` or call `identify()` (the spayload's `id` field is filled with `config.userId ?? sessionId`).

Secure storage keys are namespaced with `instanceName` via `instanceSuffix()`:

```text
# without instanceName
umami_device_id
umami_first_launch

# with instanceName = "foo"
umami_device_id_foo
umami_first_launch_foo
```

### `DeviceIdPort`

Domain contract for the persistent identifier. The factory builds `DefaultDeviceIdService` **only when `recordFirstOpen: true`**; otherwise the adapter is not instantiated and the `deviceId` parameter of [`createUmamiAnalytics()`](1-initialization.md) is ignored.

Custom implementation (the default adapter is not exported; inject your own `DeviceIdPort`):

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

Inject it via `deviceId` in [`createUmamiAnalytics()`](1-initialization.md) **together with `recordFirstOpen: true`**; otherwise it has no effect.

## Device information

`DefaultDeviceInfoService` produces an immutable [`DeviceInfoData`] snapshot that `TrackingCollector` reads when building each payload.

- `gather()` is synchronous. It returns the locale, the screen size, the platform and every detail that `load()` has read so far.
- `load()` reads the OS, device-model, app and browser details once. It is bounded by a 2 s timeout and never throws: fields that could not be read stay `null`. `createUmamiAnalytics()` awaits it unless you pass `collectDeviceDetails: false`.

| Field                            | Native source                                                             | Web source                          | Sent to Umami                     |
| -------------------------------- | ------------------------------------------------------------------------- | ----------------------------------- | --------------------------------- |
| `locale`                         | `PlatformDispatcher.locale.toLanguageTag()` (`en-US`)                     | `navigator.language`                | yes (`language`)                  |
| `screenResolution`               | first display size / device pixel ratio (logical px)                      | `screen.width x screen.height`      | yes (`screen`)                    |
| `platform`                       | `PlatformDetector` (`android`, `ios`, `macos`, `windows`, `linux`)        | `web`                               | only with `attachDeviceData`      |
| `osName` / `osVersion`           | `device_info_plus` (`version.release`, `systemVersion`, ...)              | parsed from `navigator.userAgent`   | only with `attachDeviceData`      |
| `deviceModel`                    | `device_info_plus` (`model`, `utsname.machine`); not on Windows / Linux   | —                                   | only with `attachDeviceData`      |
| `appVersion` / `appBuild`        | `package_info_plus`                                                       | `package_info_plus` (`version.json`) | only with `attachDeviceData`      |
| `browserName` / `browserVersion` | —                                                                         | parsed from `navigator.userAgent`   | only with `attachDeviceData`      |

With `FlutterUmamiConfig(attachDeviceData: true)`, `trackEvent` merges `DeviceInfoData.toEventData()` into the event `data` (keys `platform`, `os`, `os_version`, `device_model`, `app_version`, `app_build`, `browser`, `browser_version`). Keys you pass in `data` win. Pageviews and `identify` are not changed.

Privacy: the service never reads advertising IDs, `identifierForVendor`, the Android ID, serials, the Linux machine ID, the Windows computer or user name, the IP address or the location.

If the Flutter binding is not available yet (e.g. outside the Flutter zone), `screenResolution` and `locale` fall back to `"unknown"` and the snapshot is not cached, so a later call can read the real values.

Inject your own implementation by passing `deviceInfo` to [`createUmamiAnalytics()`](1-initialization.md):

```dart
class CustomDeviceInfo implements DeviceInfoPort {
  @override
  DeviceInfoData gather() => const DeviceInfoData(
    locale: 'es-ES',
    screenResolution: '390x844',
    platform: 'android',
    appVersion: '2.1.0',
  );
}
```

## User-Agent

Umami derives the Browser, OS and Device panels from the `User-Agent` request header.

- **Native:** `DefaultHttpClient` sends a browser-style UA from `UserAgentService.build()`. After `load()`, it carries the real OS version (for example `Android 14; K`, `iPhone OS 17_4`, `iPad; CPU OS 17_4`, `Mac OS X 14_5_0`). It never contains the device model. Windows always reports `Windows NT 10.0`, like real browsers. Before `load()` (or with `collectDeviceDetails: false`) a generic OS version is used.
- **Web:** the browser sends its own UA. Browsers do not allow a page to set this header, so the SDK never adds it (`buildBaseHeaders(includeUserAgent: false)`).

To use a different User-Agent on native, inject your own `HttpClientPort` via `httpClientPort` in [`createUmamiAnalytics()`](1-initialization.md). See [10-advanced.md](10-advanced.md).

## Web storage

On web, the default device ID service stores the ID in `localStorage` (`umami_device_id[_instanceName]`, `umami_first_launch[_instanceName]`). The ID is per browser profile and per origin; it is deleted when the user clears site data, and a private window gets a new one. If `localStorage` is blocked, the ID lives in memory for the current page load.
