/// Fallback host access for runtimes with neither `dart:io` nor
/// `dart:js_interop` (infrastructure layer). Every function returns `null`.
library;

import 'package:flutter_umami_analytics/src/infrastructure/platform/browser_environment.dart';
import 'package:flutter_umami_analytics/src/infrastructure/platform/platform_kind.dart';
import 'package:flutter_umami_analytics/src/infrastructure/storage/key_value_store.dart';

/// Returns the native platform family, or `null` when not on a `dart:io`
/// target.
PlatformKind? nativePlatformKind() => null;

/// Returns the browser snapshot, or `null` when not running in a browser.
BrowserEnvironment? readBrowserEnvironment() => null;

/// Returns a `localStorage`-backed store, or `null` when not running in a
/// browser or when the browser blocks storage.
KeyValueStore? openBrowserStorage() => null;
