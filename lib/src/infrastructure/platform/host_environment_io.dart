/// Host access for `dart:io` targets (infrastructure layer).
///
/// Only [nativePlatformKind] returns a value; the browser functions return
/// `null`.
library;

import 'dart:io' show Platform;

import 'package:flutter_umami_analytics/src/infrastructure/platform/browser_environment.dart';
import 'package:flutter_umami_analytics/src/infrastructure/platform/platform_kind.dart';
import 'package:flutter_umami_analytics/src/infrastructure/storage/key_value_store.dart';

/// Returns the native platform family from `dart:io` [Platform], or
/// [PlatformKind.unknown] for other operating systems (e.g. Fuchsia).
PlatformKind? nativePlatformKind() {
  if (Platform.isAndroid) return PlatformKind.android;
  if (Platform.isIOS) return PlatformKind.ios;
  if (Platform.isMacOS) return PlatformKind.macos;
  if (Platform.isWindows) return PlatformKind.windows;
  if (Platform.isLinux) return PlatformKind.linux;
  return PlatformKind.unknown;
}

/// Always `null`: there is no browser on `dart:io` targets.
BrowserEnvironment? readBrowserEnvironment() => null;

/// Always `null`: there is no `localStorage` on `dart:io` targets.
KeyValueStore? openBrowserStorage() => null;
