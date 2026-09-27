/// Immutable runtime configuration consumed by [FlutterUmamiAnalytics].
///
/// Part of the domain layer (pure Dart, no Flutter, no http, no sqflite).
library;

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_queue_config.dart';

/// Per-call configuration override map. Supported keys: `websiteId`,
/// `hostname`, `language`, `userId`. Anything else is ignored. Endpoint,
/// queue, logger, and lifecycle flags cannot be overridden per call.
typedef UmamiConfigOverrides = Map<String, dynamic>;

/// Default URL attached to [FlutterUmamiAnalytics.trackEvent] calls that omit
/// the `url` argument. Matches the synthetic path historically emitted by the
/// SDK (`/event`) so existing Umami dashboards keep grouping events the same
/// way. Override at init time via [FlutterUmamiConfig.defaultEventUrl].
const String kDefaultEventUrl = '/event';

/// Represents the immutable runtime configuration for the [FlutterUmamiAnalytics]
/// facade. Composed by [createUmamiAnalytics] and threaded through the
/// concrete tracking collector; every field except [websiteId], [endpoint],
/// and [hostname] has a sensible default. Layer: domain (pure Dart).
class FlutterUmamiConfig {
  /// Umami website id the SDK reports to (required).
  final String websiteId;

  /// Base URL of the Umami instance (required), e.g.
  /// `https://umami.example.com`.
  final String endpoint;

  /// Hostname attached to every event (required); typically the app's domain.
  final String hostname;

  /// Optional ISO language tag (e.g. `en-US`); null means "use the device
  /// locale".
  final String? language;

  /// Master switch; when false all track calls are no-ops. Defaults to `true`.
  final bool enabled;

  /// Optional custom user id forwarded with each event.
  final String? userId;

  /// Optional IP override; null lets Umami infer the address from the request.
  final String? ipAddress;

  /// Offline queue strategy. Defaults to [UmamiQueueConfig.inMemory].
  final UmamiQueueConfig queueConfig;

  /// Logger sink used by adapters. Defaults to a plain [UmamiLogger].
  final UmamiLogger logger;

  /// Optional one-shot referrer attached to the first pageview and then
  /// cleared.
  final String? firstReferrer;

  /// HTTP request timeout for send / login calls. Defaults to 5 seconds.
  final Duration httpTimeout;

  /// Optional logical instance name used to namespace SQLite and secure
  /// storage keys for multi-instance setups. Null means the default instance.
  final String? instanceName;

  /// URL attached to `trackEvent` calls that do not pass an explicit `url`.
  /// Defaults to [kDefaultEventUrl] (`/event`). Override at init time when
  /// you want all events to report a different path (e.g. `/app/event`).
  /// Per-call `url` arguments always take precedence.
  final String defaultEventUrl;

  /// When `true`, named events (`trackEvent`) carry the coarse device
  /// details from [DeviceInfoData.toEventData] in their `data` map
  /// (`platform`, `os`, `os_version`, `device_model`, `app_version`,
  /// `app_build`, `browser`, `browser_version`). Keys the caller passes in
  /// `data` win. Pageviews and `identify` are not changed. Defaults to
  /// `false`. Not per-call overridable.
  final bool attachDeviceData;

  /// Builds the runtime config. [websiteId], [endpoint], and [hostname] are
  /// required; the rest have defaults documented on each field.
  const FlutterUmamiConfig({
    required this.websiteId,
    required this.endpoint,
    required this.hostname,
    this.language,
    this.enabled = true,
    this.userId,
    this.ipAddress,
    this.queueConfig = const UmamiQueueConfig.inMemory(),
    this.logger = const UmamiLogger(),
    this.firstReferrer,
    this.httpTimeout = const Duration(seconds: 5),
    this.instanceName,
    this.defaultEventUrl = kDefaultEventUrl,
    this.attachDeviceData = false,
  });

  /// Returns a new [FlutterUmamiConfig] with the supplied non-null fields
  /// overriding the current values. Passing null for a parameter preserves
  /// the current value.
  FlutterUmamiConfig copyWith({
    String? websiteId,
    String? endpoint,
    String? hostname,
    String? language,
    bool? enabled,
    String? userId,
    String? ipAddress,
    UmamiQueueConfig? queueConfig,
    UmamiLogger? logger,
    String? firstReferrer,
    Duration? httpTimeout,
    String? instanceName,
    String? defaultEventUrl,
    bool? attachDeviceData,
  }) {
    return FlutterUmamiConfig(
      websiteId: websiteId ?? this.websiteId,
      endpoint: endpoint ?? this.endpoint,
      hostname: hostname ?? this.hostname,
      language: language ?? this.language,
      enabled: enabled ?? this.enabled,
      userId: userId ?? this.userId,
      ipAddress: ipAddress ?? this.ipAddress,
      queueConfig: queueConfig ?? this.queueConfig,
      logger: logger ?? this.logger,
      firstReferrer: firstReferrer ?? this.firstReferrer,
      httpTimeout: httpTimeout ?? this.httpTimeout,
      instanceName: instanceName ?? this.instanceName,
      defaultEventUrl: defaultEventUrl ?? this.defaultEventUrl,
      attachDeviceData: attachDeviceData ?? this.attachDeviceData,
    );
  }

  /// Returns the same config when `overrides` is null or empty; otherwise
  /// returns a copy where only the supported keys (`websiteId`, `hostname`,
  /// `language`, `userId`) are overridden. Endpoint, [enabled], [queueConfig],
  /// [logger], [firstReferrer], [httpTimeout], [instanceName], [ipAddress],
  /// [defaultEventUrl], and [attachDeviceData] are not per-call overridable.
  FlutterUmamiConfig merge([UmamiConfigOverrides? overrides]) {
    if (overrides == null || overrides.isEmpty) return this;
    return FlutterUmamiConfig(
      websiteId: _overrideString(overrides, 'websiteId', websiteId),
      endpoint: endpoint,
      hostname: _overrideString(overrides, 'hostname', hostname),
      language: _overrideNullableString(overrides, 'language', language),
      userId: _overrideNullableString(overrides, 'userId', userId),
      enabled: enabled,
      queueConfig: queueConfig,
      logger: logger,
      firstReferrer: firstReferrer,
      httpTimeout: httpTimeout,
      instanceName: instanceName,
      ipAddress: ipAddress,
      defaultEventUrl: defaultEventUrl,
      attachDeviceData: attachDeviceData,
    );
  }

  static String _overrideString(
    Map<String, dynamic> overrides,
    String key,
    String current,
  ) {
    final value = overrides[key];
    return value is String ? value : current;
  }

  static String? _overrideNullableString(
    Map<String, dynamic> overrides,
    String key,
    String? current,
  ) {
    if (!overrides.containsKey(key)) return current;
    final value = overrides[key];
    return value is String ? value : current;
  }

  /// Value equality over every config field.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlutterUmamiConfig &&
          websiteId == other.websiteId &&
          endpoint == other.endpoint &&
          hostname == other.hostname &&
          language == other.language &&
          enabled == other.enabled &&
          userId == other.userId &&
          ipAddress == other.ipAddress &&
          queueConfig == other.queueConfig &&
          logger == other.logger &&
          firstReferrer == other.firstReferrer &&
          httpTimeout == other.httpTimeout &&
          instanceName == other.instanceName &&
          defaultEventUrl == other.defaultEventUrl &&
          attachDeviceData == other.attachDeviceData;

  /// Hash consistent with [operator==].
  @override
  int get hashCode => Object.hash(
        websiteId,
        endpoint,
        hostname,
        language,
        enabled,
        userId,
        ipAddress,
        queueConfig,
        logger,
        firstReferrer,
        httpTimeout,
        instanceName,
        defaultEventUrl,
        attachDeviceData,
      );
}
