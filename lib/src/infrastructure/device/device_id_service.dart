/// Device id stored with `flutter_secure_storage` (infrastructure layer).
///
/// The default [DeviceIdPort] on native targets. Flutter web uses
/// `KeyValueDeviceIdService` over `localStorage` instead (see
/// `createDefaultDeviceIdService`).
library;

import 'dart:async' show Completer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_umami_analytics/src/domain/ports/device_id_port.dart';
import 'package:flutter_umami_analytics/src/domain/utils/instance_suffix.dart';
import 'package:flutter_umami_analytics/src/domain/utils/safe_async.dart';

/// [DeviceIdPort] that keeps a random UUID v4 in secure storage.
class DefaultDeviceIdService implements DeviceIdPort {
  static const _uuid = Uuid();
  static const _kDeviceIdKey = 'umami_device_id';
  static const _kFirstLaunchKey = 'umami_first_launch';
  static const _kFirstLaunchMarkValue = '1';

  final String _key;
  final String _firstLaunchKey;
  final FlutterSecureStorage _storage;
  String? _cachedId;
  Future<void>? _resetting;

  DefaultDeviceIdService({
    FlutterSecureStorage? storage,
    String? instanceName,
  })  : _key = '$_kDeviceIdKey${instanceSuffix(instanceName)}',
        _firstLaunchKey = '$_kFirstLaunchKey${instanceSuffix(instanceName)}',
        _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String> getId() async {
    final cached = _cachedId;
    if (cached != null) return cached;

    final stored = await _readKey(_key);
    if (stored != null && stored.isNotEmpty) {
      _cachedId = stored;
      return stored;
    }

    final newId = _uuid.v4();
    final wrote = await _writeKey(_key, newId);
    if (wrote) _cachedId = newId;
    return newId;
  }

  @override
  Future<bool> isFirstLaunch() async {
    final value = await _readKey(_firstLaunchKey);
    if (value != null) return false;
    await _writeKey(_firstLaunchKey, _kFirstLaunchMarkValue);
    return true;
  }

  @override
  Future<void> reset() async {
    final pending = _resetting;
    if (pending != null) return pending;

    final completer = Completer<void>();
    _resetting = completer.future;
    try {
      _cachedId = null;
      await safeAsync(() => _storage.delete(key: _key));
      await safeAsync(() => _storage.delete(key: _firstLaunchKey));
    } finally {
      _resetting = null;
      completer.complete();
    }
  }

  Future<String?> _readKey(String key) =>
      safeAsync<String?>(() => _storage.read(key: key));

  Future<bool> _writeKey(String key, String value) =>
      safeBool(() => _storage.write(key: key, value: value));
}
