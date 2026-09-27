/// Device id stored in a [KeyValueStore] (infrastructure layer).
///
/// The default [DeviceIdPort] on Flutter web, where the store is
/// `window.localStorage`. The id is per browser profile and per origin: it
/// is lost when the user clears site data, and a private window gets a new
/// one. Pure Dart, so it is unit-tested on the Dart VM.
library;

import 'package:uuid/uuid.dart';

import 'package:flutter_umami_analytics/src/domain/ports/device_id_port.dart';
import 'package:flutter_umami_analytics/src/domain/utils/instance_suffix.dart';
import 'package:flutter_umami_analytics/src/infrastructure/storage/key_value_store.dart';

/// [DeviceIdPort] that keeps a random UUID v4 in a [KeyValueStore].
///
/// Uses the same keys as the secure-storage adapter
/// (`umami_device_id[_<instance>]`, `umami_first_launch[_<instance>]`).
/// When a write fails, the id is still cached in memory for this session.
class KeyValueDeviceIdService implements DeviceIdPort {
  static const _uuid = Uuid();
  static const _kDeviceIdKey = 'umami_device_id';
  static const _kFirstLaunchKey = 'umami_first_launch';
  static const _kFirstLaunchMarkValue = '1';

  final KeyValueStore _store;
  final String _key;
  final String _firstLaunchKey;
  String? _cachedId;

  /// Builds the service over [store]; [instanceName] namespaces the keys.
  KeyValueDeviceIdService({
    required KeyValueStore store,
    String? instanceName,
  })  : _store = store,
        _key = '$_kDeviceIdKey${instanceSuffix(instanceName)}',
        _firstLaunchKey = '$_kFirstLaunchKey${instanceSuffix(instanceName)}';

  @override
  Future<String> getId() async {
    final cached = _cachedId;
    if (cached != null) return cached;
    final stored = _store.read(_key);
    if (stored != null && stored.isNotEmpty) return _cachedId = stored;
    final newId = _uuid.v4();
    _store.write(_key, newId);
    return _cachedId = newId;
  }

  @override
  Future<bool> isFirstLaunch() async {
    if (_store.read(_firstLaunchKey) != null) return false;
    _store.write(_firstLaunchKey, _kFirstLaunchMarkValue);
    return true;
  }

  @override
  Future<void> reset() async {
    _cachedId = null;
    _store.remove(_key);
    _store.remove(_firstLaunchKey);
  }
}
