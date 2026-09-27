/// Host platform families the SDK can run on (infrastructure layer).
///
/// Shared by the platform detector, the User-Agent builder and the
/// device-info service. Pure Dart: no `dart:io`, no `package:web`.
library;

/// Host platform family reported by [PlatformDetector].
enum PlatformKind {
  /// Flutter web (any browser).
  web,

  /// Android (native).
  android,

  /// iOS / iPadOS (native).
  ios,

  /// macOS (native).
  macos,

  /// Windows (native).
  windows,

  /// Linux (native).
  linux,

  /// Fuchsia or any runtime the SDK cannot classify.
  unknown,
}

/// Wire label for [PlatformKind] (the enum name, e.g. `android`).
extension PlatformKindLabel on PlatformKind {
  /// Lower-case label used in logs and in [DeviceInfoData.platform].
  String get wire => name;
}
