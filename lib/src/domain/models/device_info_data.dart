/// Snapshot of device metadata attached to outbound Umami events.
///
/// Part of the domain layer (pure Dart, no Flutter, no http, no sqflite).
library;

/// Represents an immutable snapshot of the device metadata used when
/// building each event. Produced by the device-info service and consumed by
/// the concrete tracking collector. Layer: domain (pure Dart).
///
/// [locale], [screenResolution] and [platform] are always present. The
/// other fields are coarse, optional details (OS, app and browser versions,
/// device model) that stay `null` until the device-info service has loaded
/// them or when the platform does not report them. None of them identify a
/// person or a single device: there is no advertising id, serial number,
/// IP address or location.
class DeviceInfoData {
  /// Locale string in BCP-47 form (e.g. `en-US`) sourced from the host app.
  final String locale;

  /// Screen size in logical pixels, `WxH` format (e.g. `390x844`). On web
  /// this is `screen.width x screen.height`, the value the Umami web
  /// tracker sends.
  final String screenResolution;

  /// Platform name reported by the host runtime (e.g. `android`, `ios`,
  /// `macos`, `windows`, `linux`, `web`).
  final String platform;

  /// OS family, e.g. `Android`, `iOS`, `macOS`, `Windows`, `Linux`. On web
  /// it is parsed from the browser User-Agent. `null` when unknown.
  final String? osName;

  /// OS version, e.g. `14`, `17.4`, `14.5.0`. `null` when unknown.
  final String? osVersion;

  /// Coarse hardware model, e.g. `Pixel 8`, `iPhone15,2`, `MacBookPro18,3`.
  /// Never a serial number. `null` on web and when unknown.
  final String? deviceModel;

  /// Host app version (`version` from `pubspec.yaml`, e.g. `1.4.2`).
  final String? appVersion;

  /// Host app build number (e.g. `42`).
  final String? appBuild;

  /// Browser family on web (e.g. `Chrome`, `Safari`); `null` on native.
  final String? browserName;

  /// Browser version on web (e.g. `129.0.0.0`); `null` on native.
  final String? browserVersion;

  /// Builds a device-info snapshot. [locale], [screenResolution] and
  /// [platform] are required; the detail fields default to `null`.
  const DeviceInfoData({
    required this.locale,
    required this.screenResolution,
    required this.platform,
    this.osName,
    this.osVersion,
    this.deviceModel,
    this.appVersion,
    this.appBuild,
    this.browserName,
    this.browserVersion,
  });

  /// Returns a copy with the given fields replaced. A `null` argument keeps
  /// the current value.
  DeviceInfoData copyWith({
    String? locale,
    String? screenResolution,
    String? platform,
    String? osName,
    String? osVersion,
    String? deviceModel,
    String? appVersion,
    String? appBuild,
    String? browserName,
    String? browserVersion,
  }) =>
      DeviceInfoData(
        locale: locale ?? this.locale,
        screenResolution: screenResolution ?? this.screenResolution,
        platform: platform ?? this.platform,
        osName: osName ?? this.osName,
        osVersion: osVersion ?? this.osVersion,
        deviceModel: deviceModel ?? this.deviceModel,
        appVersion: appVersion ?? this.appVersion,
        appBuild: appBuild ?? this.appBuild,
        browserName: browserName ?? this.browserName,
        browserVersion: browserVersion ?? this.browserVersion,
      );

  /// Returns the non-null fields as Umami event data (snake_case keys).
  ///
  /// Keys: `platform`, `os`, `os_version`, `device_model`, `app_version`,
  /// `app_build`, `browser`, `browser_version`. Used by the collector when
  /// `FlutterUmamiConfig.attachDeviceData` is `true`. [locale] and
  /// [screenResolution] are left out because Umami already records them
  /// as `language` and `screen`.
  Map<String, String> toEventData() {
    final osName = this.osName;
    final osVersion = this.osVersion;
    final deviceModel = this.deviceModel;
    final appVersion = this.appVersion;
    final appBuild = this.appBuild;
    final browserName = this.browserName;
    final browserVersion = this.browserVersion;
    return <String, String>{
      'platform': platform,
      if (osName != null) 'os': osName,
      if (osVersion != null) 'os_version': osVersion,
      if (deviceModel != null) 'device_model': deviceModel,
      if (appVersion != null) 'app_version': appVersion,
      if (appBuild != null) 'app_build': appBuild,
      if (browserName != null) 'browser': browserName,
      if (browserVersion != null) 'browser_version': browserVersion,
    };
  }

  /// Value equality over every field.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfoData &&
          locale == other.locale &&
          screenResolution == other.screenResolution &&
          platform == other.platform &&
          osName == other.osName &&
          osVersion == other.osVersion &&
          deviceModel == other.deviceModel &&
          appVersion == other.appVersion &&
          appBuild == other.appBuild &&
          browserName == other.browserName &&
          browserVersion == other.browserVersion;

  /// Hash consistent with [operator==].
  @override
  int get hashCode => Object.hash(
        locale,
        screenResolution,
        platform,
        osName,
        osVersion,
        deviceModel,
        appVersion,
        appBuild,
        browserName,
        browserVersion,
      );

  /// Debug representation of the locale, screen and non-null details.
  @override
  String toString() => 'DeviceInfoData(locale: $locale, '
      'screen: $screenResolution, ${toEventData()})';
}
