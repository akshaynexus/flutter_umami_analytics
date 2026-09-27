/// Host access for Flutter web (infrastructure layer).
///
/// Reads the browser through `package:web`. Every access is wrapped in
/// `try/catch`: browsers can throw `SecurityError` for `localStorage` in
/// private mode or with blocked site data.
library;

import 'package:web/web.dart' as web;

import 'package:flutter_umami_analytics/src/infrastructure/platform/browser_environment.dart';
import 'package:flutter_umami_analytics/src/infrastructure/platform/platform_kind.dart';
import 'package:flutter_umami_analytics/src/infrastructure/storage/key_value_store.dart';

/// Always `null`: web is not a native platform.
PlatformKind? nativePlatformKind() => null;

/// Reads `navigator.userAgent`, `navigator.language`, `screen.width`,
/// `screen.height` and `document.referrer`. Returns `null` when the
/// browser APIs are unavailable (e.g. in a worker).
BrowserEnvironment? readBrowserEnvironment() {
  try {
    final window = web.window;
    final navigator = window.navigator;
    final screen = window.screen;
    return BrowserEnvironment(
      userAgent: navigator.userAgent,
      language: navigator.language,
      screenWidth: screen.width,
      screenHeight: screen.height,
      referrer: web.document.referrer,
    );
  } catch (_) {
    return null;
  }
}

/// Returns a store over `window.localStorage`, or `null` when the browser
/// blocks it (private mode, disabled cookies, sandboxed iframe).
KeyValueStore? openBrowserStorage() {
  try {
    final storage = web.window.localStorage;
    const probe = '__umami_probe__';
    storage.setItem(probe, '1');
    storage.removeItem(probe);
    return _LocalStorageStore(storage);
  } catch (_) {
    return null;
  }
}

class _LocalStorageStore implements KeyValueStore {
  final web.Storage _storage;

  _LocalStorageStore(this._storage);

  @override
  String? read(String key) {
    try {
      return _storage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  bool write(String key, String value) {
    try {
      _storage.setItem(key, value);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  bool remove(String key) {
    try {
      _storage.removeItem(key);
      return true;
    } catch (_) {
      return false;
    }
  }
}
