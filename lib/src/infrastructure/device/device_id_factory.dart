/// Picks the default [DeviceIdPort] per platform (infrastructure layer).
library;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/ports/device_id_port.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/device_id_service.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/key_value_device_id_service.dart';
import 'package:flutter_umami_analytics/src/infrastructure/platform/host_environment.dart';
import 'package:flutter_umami_analytics/src/infrastructure/storage/key_value_store.dart';

/// Returns the default [DeviceIdPort] for the running platform.
///
/// - Native: [DefaultDeviceIdService] (Keychain / EncryptedSharedPreferences
///   through `flutter_secure_storage`).
/// - Web: [KeyValueDeviceIdService] over `window.localStorage`. The id is
///   per browser profile and cleared with site data. When `localStorage` is
///   blocked, the id lives in memory for this page load only.
DeviceIdPort createDefaultDeviceIdService({
  String? instanceName,
  UmamiLogger? logger,
}) {
  if (!kIsWeb) return DefaultDeviceIdService(instanceName: instanceName);
  final store = openBrowserStorage();
  if (store == null) {
    logger?.warning('localStorage unavailable; device id kept in memory');
  }
  return KeyValueDeviceIdService(
    store: store ?? InMemoryKeyValueStore(),
    instanceName: instanceName,
  );
}
