# Changelog

## 1.3.0-dev.1

Not published to pub.dev.

- Feat: **web support**. `web` is listed in `platforms`. No library in the web import graph uses `dart:io` or `sqflite`:
  - `host_environment.dart` selects an io, web (`package:web`) or stub implementation with conditional exports.
  - `UmamiQueueConfig.persisted()` uses a bounded `localStorage` queue on web (`KeyValueQueue`): survives reloads, never reuses ids, trims the oldest half on quota errors, falls back to memory in private mode.
  - The device ID uses `localStorage` on web and `flutter_secure_storage` on native.
  - `DefaultHttpClient` no longer imports `dart:io`; on web `http.Client()` is a `BrowserClient`. No `User-Agent` header is set on web (browsers own it). The `x-umami-cache` token is also read from the JSON response body, because cross-origin responses hide the header.
  - `UmamiNavigatorObserver` tracks unnamed page routes with the browser URL on web (hash and path strategies). New `useBrowserUrl` and `currentUri` parameters.
  - On web, the first pageview uses `document.referrer` when `firstReferrer` is not set and the referrer is another site.
- Feat: **device details**, ported from the ideas in `umami_flutter_sdk` 0.4.1 (MIT, see `NOTICE`). `DeviceInfoData` gains optional `osName`, `osVersion`, `deviceModel`, `appVersion`, `appBuild`, `browserName`, `browserVersion`, plus `copyWith` and `toEventData()`. `DefaultDeviceInfoService.load()` reads them with `device_info_plus` / `package_info_plus` (native) or from the browser UA (web), bounded by 2 s.
- Feat: `FlutterUmamiConfig.attachDeviceData` (default `false`) merges the device details into `trackEvent` data.
- Feat: `createUmamiAnalytics(collectDeviceDetails: true)` awaits the details before the first event; the native User-Agent then carries the real OS version (never the device model).
- Fix: `locale` is now BCP-47 (`en-US`, was `en_US`) and `screenResolution` is in logical pixels (was physical pixels), which is what Umami uses for its language and device-type panels.
- Fix: the Android User-Agent no longer embeds the kernel string from `Platform.operatingSystemVersion`.
- Change: `DefaultHttpClient` logs timeouts as `Timeout` warnings instead of `Request` errors.
- Deps: `web`, `device_info_plus` (`>=11.3.0 <14.0.0`), `package_info_plus` (`>=8.1.0 <11.0.0`). The Flutter `>=3.22.0` floor is unchanged.
- Example: web platform folder; persisted queue and `attachDeviceData` enabled.

## 1.2.0

- Feat: `FlutterUmamiConfig.defaultEventUrl` lets you define the URL assigned to `trackEvent` calls that omit the `url` argument at init time. Defaults to the new public constant `kDefaultEventUrl` (`/event`), preserving backwards compatibility with existing Umami dashboards. An explicit per-call `url` always takes precedence. `TrackingCollector` now reads the default from config instead of a hardcoded `/event` constant. The field is part of `copyWith`, value equality, and `hashCode`; it is not per-call overridable via `UmamiConfigOverrides` (same policy as `endpoint` and `httpTimeout`).
- Docs: `doc/{en,es}/1-initialization.md` document the new `defaultEventUrl` config field; `doc/{en,es}/3-tracking.md` clarify the `trackEvent` `url` default now resolves from `FlutterUmamiConfig.defaultEventUrl`.

## 1.1.0

- Feat: `createUmamiAnalytics` now accepts injected `httpClientPort` and `apiClient` (`UmamiApiPort`). Injected ports take precedence over `httpClient`/`enableApi` and are NOT disposed by the facade or collector (caller owns lifecycle). `TrackingCollector.ownsHttpClient` and `FlutterUmamiAnalytics.ownsApiClient` gate disposal (default `true` for backwards compatibility).
- Feat: `createUmamiAnalytics` now accepts an injected `UmamiQueue`, decoupling queue policy from adapter-selection. Lets callers plug custom storage (Hive, Isar, Realm, ObjectBox, SharedPreferences, etc.) without forking the package. Enqueue-on-failure and TTL-purge-on-flush policies are derived in `_policyFrom` from `UmamiQueueConfig`. The queue is only closed by the collector when it built it.
- Docs: new `doc/{en,es}/11-credentials-security.md` centralizing the secrets table, two pipelines (tracking vs REST), JWT lifecycle, non-persistence guarantees, best practices and production checklist. Cross-linked from `1-initialization.md` and `9-api-client.md`.
- Docs: README splits the Documentation section into `doc/en/` and `doc/es/` subsections, each listing all 11 guides.

## 1.0.1

- Fix: per-call `UmamiConfigOverrides` (`websiteId`, `hostname`, `language`, `userId`) now applied to the outgoing payload in `trackPageView`, `trackEvent`, and `identify`. Previously the merged config was computed but the payload was still built from the base config, so overrides had no effect on those fields.
- Docs: added dartdoc (`///`) to all public API symbols across `domain`, `application`, `infrastructure`, and `factory.dart`.
- Docs: added English documentation set under `doc/en/` (initialization, queue, tracking, observer, identify, overrides, device, logging, API client, advanced) and refreshed Spanish docs under `doc/es/`.

## 1.0.0

- Initial release.
- Pageview and event tracking with automatic device info (locale, screen, User-Agent per platform).
- Offline queue strategies: `disabled`, `inMemory`, `persisted` (SQLite with TTL, auto-flush).
- Persistent device ID via `flutter_secure_storage`, namespaced per instance.
- `UmamiNavigatorObserver` for auto-tracking route pushes, replaces, and pops (`routeFilter` and `routeNameMapper` hooks).
- Multi-instance support with isolated SQLite queue and secure storage keys per `instanceName`.
- Optional REST API client (`enableApi`): login, websites, stats, pageviews, metrics, active visitors, events, sessions, teams, users.
- Per-call config overrides (`websiteId`, `hostname`, `language`, `userId`).
- One-time `firstReferrer` consumed by the first `trackPageView`.
- Lazy `sessionId` generated on first `identify()`.
- Configurable `UmamiLogger` (six levels, custom sink callback).
- Hexagonal architecture: pure-Dart `domain` with swappable `port` adapters.
