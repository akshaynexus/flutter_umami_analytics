/// Async reader for OS, device-model and app-version details
/// (infrastructure layer).
///
/// Native targets read `device_info_plus` and `package_info_plus`; Flutter
/// web parses `navigator.userAgent` and reads `package_info_plus` (which
/// fetches `version.json`). Only coarse fields are read: no advertising
/// ids, serials, `identifierForVendor`, Android id, machine id, computer
/// name or user name.
///
/// Idea ported from `umami_flutter_sdk` (MIT, Copyright (c) 2026 Hamza
/// Ejaz): collect the real OS version with `device_info_plus` and the app
/// version with `package_info_plus`. See `NOTICE`.
library;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter_umami_analytics/src/infrastructure/device/platform_detector.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/user_agent_parser.dart';
import 'package:flutter_umami_analytics/src/infrastructure/platform/browser_environment.dart';

/// Coarse device and app details read asynchronously at start-up.
class DeviceDetails {
  /// OS family, e.g. `Android`, `iOS`, `macOS`, `Windows`, `Linux`.
  final String? osName;

  /// OS version, e.g. `14`, `17.4`, `14.5.0`.
  final String? osVersion;

  /// Coarse hardware model (native only).
  final String? deviceModel;

  /// Host app version from `package_info_plus`.
  final String? appVersion;

  /// Host app build number from `package_info_plus`.
  final String? appBuild;

  /// Browser family (web only).
  final String? browserName;

  /// Browser version (web only).
  final String? browserVersion;

  /// `true` for iPad hardware; selects the iPad User-Agent form.
  final bool tablet;

  /// Builds a details record. Every field is optional.
  const DeviceDetails({
    this.osName,
    this.osVersion,
    this.deviceModel,
    this.appVersion,
    this.appBuild,
    this.browserName,
    this.browserVersion,
    this.tablet = false,
  });

  /// Empty result used when nothing could be read.
  static const empty = DeviceDetails();
}

/// Async function that reads [DeviceDetails]; injectable for tests.
typedef DeviceDetailsLoader = Future<DeviceDetails> Function();

/// Reads [DeviceDetails] for [kind]. Never throws: a failing plugin call
/// leaves its fields `null`.
///
/// [browser] is required on web to parse the User-Agent. [deviceInfo] and
/// [packageInfo] are injectable for tests.
Future<DeviceDetails> loadDeviceDetails(
  PlatformKind kind, {
  BrowserEnvironment? browser,
  DeviceInfoPlugin? deviceInfo,
  Future<PackageInfo> Function()? packageInfo,
}) async {
  final results = await Future.wait<Object?>(<Future<Object?>>[
    _readSystem(kind, browser, deviceInfo ?? DeviceInfoPlugin()),
    _readPackage(packageInfo ?? PackageInfo.fromPlatform),
  ]);
  final system = results[0] as DeviceDetails? ?? DeviceDetails.empty;
  final package = results[1] as PackageInfo?;
  return DeviceDetails(
    osName: system.osName,
    osVersion: system.osVersion,
    deviceModel: system.deviceModel,
    browserName: system.browserName,
    browserVersion: system.browserVersion,
    tablet: system.tablet,
    appVersion: _nonEmpty(package?.version),
    appBuild: _nonEmpty(package?.buildNumber),
  );
}

Future<PackageInfo?> _readPackage(Future<PackageInfo> Function() read) async {
  try {
    return await read();
  } catch (_) {
    return null;
  }
}

Future<DeviceDetails?> _readSystem(
  PlatformKind kind,
  BrowserEnvironment? browser,
  DeviceInfoPlugin plugin,
) async {
  try {
    switch (kind) {
      case PlatformKind.web:
        return browser == null ? null : detailsFromUserAgent(browser.userAgent);
      case PlatformKind.android:
        final info = await plugin.androidInfo;
        return DeviceDetails(
          osName: 'Android',
          osVersion: _nonEmpty(info.version.release),
          deviceModel: _nonEmpty(info.model),
        );
      case PlatformKind.ios:
        final info = await plugin.iosInfo;
        return DeviceDetails(
          osName: _nonEmpty(info.systemName) ?? 'iOS',
          osVersion: _nonEmpty(info.systemVersion),
          deviceModel: _nonEmpty(info.utsname.machine),
          tablet: info.model.toLowerCase().contains('ipad'),
        );
      case PlatformKind.macos:
        final info = await plugin.macOsInfo;
        return DeviceDetails(
          osName: 'macOS',
          osVersion:
              '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
          deviceModel: _nonEmpty(info.model),
        );
      case PlatformKind.windows:
        final info = await plugin.windowsInfo;
        return DeviceDetails(
          osName: 'Windows',
          osVersion:
              '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}',
        );
      case PlatformKind.linux:
        final info = await plugin.linuxInfo;
        return DeviceDetails(
          osName: _nonEmpty(info.name) ?? 'Linux',
          osVersion: _nonEmpty(info.versionId),
        );
      case PlatformKind.unknown:
        return null;
    }
  } catch (_) {
    return null;
  }
}

/// Maps a browser User-Agent to [DeviceDetails] (web). Pure; exposed for
/// tests.
DeviceDetails detailsFromUserAgent(String userAgent) {
  final parsed = UserAgentParser.parse(userAgent);
  return DeviceDetails(
    osName: parsed.osName,
    osVersion: parsed.osVersion,
    browserName: parsed.browserName,
    browserVersion: parsed.browserVersion,
  );
}

String? _nonEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
