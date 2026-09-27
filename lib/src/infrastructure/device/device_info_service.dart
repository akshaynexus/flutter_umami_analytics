/// Default [DeviceInfoPort] adapter (infrastructure layer).
///
/// Reads locale and screen synchronously from Flutter (native) or from the
/// browser (web), and loads OS, device-model, app-version and browser
/// details asynchronously with [load].
///
/// Logical screen size and app-version collection ported from
/// `umami_flutter_sdk` (MIT, Copyright (c) 2026 Hamza Ejaz); see `NOTICE`.
library;

import 'dart:async';
import 'dart:ui' show Display, FlutterView, PlatformDispatcher;

import 'package:flutter/widgets.dart' show WidgetsBinding;

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/ports/device_info_port.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/device_details_loader.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/platform_detector.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/user_agent_service.dart';
import 'package:flutter_umami_analytics/src/infrastructure/platform/browser_environment.dart';
import 'package:flutter_umami_analytics/src/infrastructure/platform/host_environment.dart';

/// Default [DeviceInfoPort].
///
/// Responsibilities:
/// - [gather]: synchronous snapshot of locale (BCP-47), logical screen size
///   and platform, plus the details that [load] has read so far.
/// - [load]: one async read of OS / model / app / browser details, bounded
///   by a timeout, never throws, runs once.
/// - [userAgent]: the UA the HTTP adapter sends on native targets.
class DefaultDeviceInfoService implements DeviceInfoPort {
  static const _kUnknown = 'unknown';

  /// Optional logger for diagnostics.
  final UmamiLogger? logger;

  final PlatformKind _platform;
  final BrowserEnvironment? _browser;
  late final DeviceDetailsLoader _loader;

  DeviceInfoData? _base;
  DeviceDetails _details = DeviceDetails.empty;
  DeviceInfoData? _cached;
  Future<DeviceInfoData>? _loading;

  /// Builds the service.
  ///
  /// [platform], [browser] and [detailsLoader] are injectable for tests.
  /// By default they come from the host: `PlatformDetector.detect()`,
  /// `readBrowserEnvironment()` (web only) and `loadDeviceDetails`.
  DefaultDeviceInfoService({
    this.logger,
    PlatformKind? platform,
    BrowserEnvironment? browser,
    DeviceDetailsLoader? detailsLoader,
  })  : _platform = platform ?? PlatformDetector.detect(),
        _browser = browser ?? readBrowserEnvironment() {
    _loader =
        detailsLoader ?? () => loadDeviceDetails(_platform, browser: _browser);
  }

  @override
  DeviceInfoData gather() {
    final cached = _cached;
    if (cached != null) return cached;
    final base = _base ?? _readBase();
    final info = base.copyWith(
      osName: _details.osName,
      osVersion: _details.osVersion,
      deviceModel: _details.deviceModel,
      appVersion: _details.appVersion,
      appBuild: _details.appBuild,
      browserName: _details.browserName,
      browserVersion: _details.browserVersion,
    );
    // Cache only a complete snapshot, so an early call made before the
    // Flutter binding exists does not freeze `unknown` values.
    if (base.screenResolution != _kUnknown) _cached = info;
    return info;
  }

  /// Reads OS, device-model, app-version and browser details once.
  ///
  /// Call during start-up (the factory does this before building the HTTP
  /// adapter). Later calls return the same future. Completes within
  /// [timeout] (default 2 s) even when a plugin hangs, and never throws:
  /// fields that could not be read stay `null`.
  Future<DeviceInfoData> load({
    Duration timeout = const Duration(seconds: 2),
  }) =>
      _loading ??= _load(timeout);

  Future<DeviceInfoData> _load(Duration timeout) async {
    try {
      _details = await _loader().timeout(timeout);
    } on TimeoutException {
      logger?.warning('DefaultDeviceInfoService: details timed out');
    } catch (e) {
      logger?.debug('DefaultDeviceInfoService: details unavailable: $e');
    }
    _cached = null;
    return gather();
  }

  /// User-Agent for native requests: a browser-style UA with the real OS
  /// version once [load] has completed, the generic one before.
  ///
  /// On web this returns the browser's own UA for information only; the
  /// HTTP adapter never sends a `User-Agent` header there.
  String get userAgent {
    final browser = _browser;
    if (_platform == PlatformKind.web && browser != null) {
      return browser.userAgent;
    }
    return UserAgentService.build(
      _platform,
      osVersion: _details.osVersion,
      tablet: _details.tablet,
    );
  }

  DeviceInfoData _readBase() {
    final browser = _browser;
    final dispatcher = _safeDispatcher();
    final info = DeviceInfoData(
      locale: _nonEmpty(browser?.language) ?? _resolveLocale(dispatcher),
      screenResolution: browser?.screen ?? _resolveScreen(dispatcher),
      platform: _platform.wire,
    );
    if (info.screenResolution != _kUnknown) _base = info;
    return info;
  }

  String _resolveScreen(PlatformDispatcher? dispatcher) {
    if (dispatcher == null) return _kUnknown;
    try {
      final displays = dispatcher.displays;
      if (displays.isNotEmpty) {
        final size = _logicalDisplay(displays.first);
        if (size != null) return size;
      }
      final views = dispatcher.views;
      if (views.isNotEmpty) return _logicalView(views.first) ?? _kUnknown;
    } catch (e) {
      logger?.debug('DefaultDeviceInfoService: screen unavailable: $e');
    }
    return _kUnknown;
  }

  String? _logicalDisplay(Display display) => _format(
      display.size.width, display.size.height, display.devicePixelRatio);

  String? _logicalView(FlutterView view) => _format(
      view.physicalSize.width, view.physicalSize.height, view.devicePixelRatio);

  String? _format(double width, double height, double ratio) {
    if (width <= 0 || height <= 0 || ratio <= 0) return null;
    return '${(width / ratio).round()}x${(height / ratio).round()}';
  }

  String _resolveLocale(PlatformDispatcher? dispatcher) {
    if (dispatcher == null) return _kUnknown;
    return dispatcher.locale.toLanguageTag();
  }

  PlatformDispatcher? _safeDispatcher() {
    try {
      return WidgetsBinding.instance.platformDispatcher;
    } catch (e) {
      logger?.debug(
          'DefaultDeviceInfoService: platformDispatcher unavailable: $e');
      return null;
    }
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
