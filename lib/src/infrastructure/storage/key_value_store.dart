/// Minimal synchronous string key-value store (infrastructure layer).
///
/// Backs the web offline queue and the web device id with
/// `window.localStorage`, and lets tests swap in [InMemoryKeyValueStore].
library;

/// Synchronous string key-value store, modelled on `window.localStorage`.
///
/// Implementations must never throw: a failed read returns `null` and a
/// failed write returns `false` (quota exceeded, private mode, blocked
/// site data).
abstract class KeyValueStore {
  /// Returns the value stored under [key], or `null` when missing or
  /// unreadable.
  String? read(String key);

  /// Stores [value] under [key]. Returns `false` when the write failed.
  bool write(String key, String value);

  /// Removes [key]. Returns `false` when the removal failed.
  bool remove(String key);
}

/// Volatile [KeyValueStore] kept in a Dart map.
///
/// Used in tests and as the fallback when the browser blocks
/// `localStorage` (data is then lost on reload).
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = <String, String>{};

  /// Builds an empty store.
  InMemoryKeyValueStore();

  /// Read-only view of the stored entries (for tests and diagnostics).
  Map<String, String> get values => Map<String, String>.unmodifiable(_values);

  @override
  String? read(String key) => _values[key];

  @override
  bool write(String key, String value) {
    _values[key] = value;
    return true;
  }

  @override
  bool remove(String key) {
    _values.remove(key);
    return true;
  }
}
