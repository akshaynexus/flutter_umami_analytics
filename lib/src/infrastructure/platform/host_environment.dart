/// Platform-specific host access behind one import (infrastructure layer).
///
/// Selects the implementation at compile time:
/// - `dart:io` targets (Android, iOS, macOS, Windows, Linux): reads
///   `Platform`.
/// - web (`dart:js_interop`): reads `window.navigator`, `window.screen`,
///   `document.referrer` and `window.localStorage` through `package:web`.
/// - any other runtime: returns `null` everywhere.
///
/// Callers never import `dart:io` or `package:web` directly, so the rest of
/// the package compiles on every platform.
library;

export 'package:flutter_umami_analytics/src/infrastructure/platform/host_environment_stub.dart'
    if (dart.library.io) 'package:flutter_umami_analytics/src/infrastructure/platform/host_environment_io.dart'
    if (dart.library.js_interop) 'package:flutter_umami_analytics/src/infrastructure/platform/host_environment_web.dart';
