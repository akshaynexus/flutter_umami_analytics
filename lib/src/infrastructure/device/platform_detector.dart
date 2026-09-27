/// Host platform detection (infrastructure layer).
///
/// Works on every target: `kIsWeb` selects web, and the native family comes
/// from the conditional `host_environment` import, so this file never
/// imports `dart:io`.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter_umami_analytics/src/infrastructure/platform/host_environment.dart';
import 'package:flutter_umami_analytics/src/infrastructure/platform/platform_kind.dart';

export 'package:flutter_umami_analytics/src/infrastructure/platform/platform_kind.dart';

/// Detects and caches the [PlatformKind] of the running host.
class PlatformDetector {
  static PlatformKind? _cached;

  /// Returns the host [PlatformKind]. Synchronous, cached after the first
  /// call, never throws.
  static PlatformKind detect() {
    final cached = _cached;
    if (cached != null) return cached;
    return _cached = _resolve();
  }

  static PlatformKind _resolve() {
    if (kIsWeb) return PlatformKind.web;
    try {
      return nativePlatformKind() ?? PlatformKind.unknown;
    } catch (_) {
      return PlatformKind.unknown;
    }
  }
}
