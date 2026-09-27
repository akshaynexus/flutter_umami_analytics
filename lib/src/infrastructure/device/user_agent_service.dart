/// Browser-style User-Agent strings for native targets
/// (infrastructure layer).
///
/// Umami derives the Browser / OS / Device panels from the `User-Agent`
/// request header, so native apps send a realistic browser UA that embeds
/// the real OS version when it is known. On Flutter web the browser sends
/// its own UA; browsers do not allow a page to set that header, so the SDK
/// never sets it there.
///
/// Idea of embedding the real OS version ported from `umami_flutter_sdk`
/// (MIT, Copyright (c) 2026 Hamza Ejaz); see `NOTICE`.
library;

import 'package:flutter_umami_analytics/src/infrastructure/device/platform_detector.dart';

/// Builds browser-style User-Agent strings per [PlatformKind].
class UserAgentService {
  const UserAgentService._();

  static const _chrome = 'Chrome/120.0.6099.230';
  static const _webKit = 'AppleWebKit/605.1.15 (KHTML, like Gecko)';
  static const _blink = 'AppleWebKit/537.36 (KHTML, like Gecko)';

  static final String _cached = build(PlatformDetector.detect());

  /// UA for the running host with a generic OS version. Used until the
  /// device-info service has read the real OS version.
  static String get defaultUserAgent => _cached;

  /// Returns a browser-style UA for [kind].
  ///
  /// [osVersion] is the dotted OS version (e.g. `14`, `17.4`, `14.5.0`);
  /// a generic version is used when it is `null` or empty. [tablet]
  /// selects the iPad form on iOS. Windows always reports `NT 10.0`
  /// because real browsers freeze it for Windows 10 and 11.
  static String build(
    PlatformKind kind, {
    String? osVersion,
    bool tablet = false,
  }) {
    final version = osVersion == null || osVersion.isEmpty ? null : osVersion;
    switch (kind) {
      case PlatformKind.android:
        return 'Mozilla/5.0 (Linux; Android ${version ?? '10'}; K) '
            '$_blink $_chrome Mobile Safari/537.36';
      case PlatformKind.ios:
        final v = (version ?? '17.0').replaceAll('.', '_');
        final device = tablet ? 'iPad; CPU OS' : 'iPhone; CPU iPhone OS';
        return 'Mozilla/5.0 ($device $v like Mac OS X) '
            '$_webKit Version/17.0 Mobile/15E148 Safari/604.1';
      case PlatformKind.macos:
        final v = (version ?? '10.15.7').replaceAll('.', '_');
        return 'Mozilla/5.0 (Macintosh; Intel Mac OS X $v) '
            '$_webKit Version/17.0 Safari/605.1.15';
      case PlatformKind.windows:
        return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            '$_blink $_chrome Safari/537.36';
      case PlatformKind.linux:
        return 'Mozilla/5.0 (X11; Linux x86_64) '
            '$_blink $_chrome Safari/537.36';
      case PlatformKind.web:
      case PlatformKind.unknown:
        return 'Mozilla/5.0 (compatible; FlutterUmami/1.0)';
    }
  }
}
