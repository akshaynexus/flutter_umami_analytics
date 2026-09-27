/// Offline queue stored as one JSON document in a [KeyValueStore]
/// (infrastructure layer).
///
/// The persisted queue on Flutter web: the store is `window.localStorage`,
/// so events survive page reloads. Pure Dart, so it is unit-tested on the
/// Dart VM with [InMemoryKeyValueStore].
library;

import 'dart:convert';

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_queue_config.dart';
import 'package:flutter_umami_analytics/src/domain/ports/queue_port.dart';
import 'package:flutter_umami_analytics/src/domain/utils/instance_suffix.dart';
import 'package:flutter_umami_analytics/src/domain/utils/json_helpers.dart';
import 'package:flutter_umami_analytics/src/infrastructure/storage/key_value_store.dart';

/// [UmamiQueue] that keeps every event in one JSON value of a
/// [KeyValueStore].
///
/// Responsibilities:
/// - Bound the queue to [maxSize] events (the oldest event is dropped
///   first, same as the SQLite queue).
/// - Keep ids unique and increasing across reloads.
/// - Re-read the store on every call, so two browser tabs that share
///   `localStorage` do not overwrite each other's ids.
/// - Degrade instead of throw: a corrupt value is reset, and a full store
///   (quota exceeded) drops the oldest half of the queue and retries once.
class KeyValueQueue implements UmamiQueue {
  static const _kKeyPrefix = 'umami_queue';
  static const _kVersion = 1;

  /// Maximum number of queued events. Older events are evicted first.
  final int maxSize;

  final KeyValueStore _store;
  final String _key;
  final UmamiLogger? _logger;
  final DateTime Function() _clock;

  /// Builds a queue over [store].
  ///
  /// [instanceName] namespaces the storage key (`umami_queue` or
  /// `umami_queue_<name>`). [clock] is injectable for tests and defaults to
  /// [DateTime.now]. [logger] receives storage warnings.
  KeyValueQueue({
    required KeyValueStore store,
    this.maxSize = kDefaultQueueMaxSize,
    String? instanceName,
    UmamiLogger? logger,
    DateTime Function()? clock,
  })  : _store = store,
        _key = '$_kKeyPrefix${instanceSuffix(instanceName)}',
        _logger = logger,
        _clock = clock ?? DateTime.now;

  /// Storage key that holds the queue document.
  String get storageKey => _key;

  @override
  Future<void> insert(String payload) async {
    if (maxSize <= 0) return;
    final state = _load();
    final rows = state.rows;
    while (rows.length >= maxSize) {
      rows.removeAt(0);
    }
    rows.add(QueuedEvent(
      id: state.nextId,
      payload: payload,
      createdAt: _clock(),
    ));
    _save(_QueueState(state.nextId + 1, rows));
  }

  @override
  Future<List<QueuedEvent>> getAll() async =>
      List<QueuedEvent>.unmodifiable(_load().rows);

  @override
  Future<void> delete(int id) async {
    final state = _load();
    final before = state.rows.length;
    state.rows.removeWhere((e) => e.id == id);
    if (state.rows.length != before) _save(state);
  }

  @override
  Future<void> deleteExpired(Duration ttl) async {
    final state = _load();
    final cutoff = _clock().subtract(ttl);
    final before = state.rows.length;
    state.rows.removeWhere((e) => e.createdAt.isBefore(cutoff));
    if (state.rows.length != before) _save(state);
  }

  @override
  Future<int> get length async => _load().rows.length;

  /// No-op: the store has no handle to release, and queued events must
  /// stay in storage for the next page load.
  @override
  Future<void> close() async {}

  _QueueState _load() {
    final raw = _store.read(_key);
    if (raw == null || raw.isEmpty) return _QueueState(1, <QueuedEvent>[]);
    final doc = decodeJsonObject(raw);
    final events = doc?['events'];
    if (doc == null || events is! List) {
      _logger?.warning('KeyValueQueue: corrupt queue in "$_key"; resetting');
      return _QueueState(1, <QueuedEvent>[]);
    }
    final rows = <QueuedEvent>[];
    var maxId = 0;
    for (final entry in events) {
      final row = _decodeRow(entry);
      if (row == null) continue;
      rows.add(row);
      if (row.id! > maxId) maxId = row.id!;
    }
    final storedNext = doc['next'];
    final next =
        storedNext is int && storedNext > maxId ? storedNext : maxId + 1;
    return _QueueState(next, rows);
  }

  QueuedEvent? _decodeRow(Object? entry) {
    if (entry is! List || entry.length != 3) return null;
    final id = entry[0];
    final createdAt = entry[1];
    final payload = entry[2];
    if (id is! int || createdAt is! int || payload is! String) return null;
    return QueuedEvent(
      id: id,
      payload: payload,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );
  }

  // An empty queue still stores `next`, so ids are never reused (another
  // tab may still hold an old id it is about to delete).
  void _save(_QueueState state) {
    if (_store.write(_key, _encode(state))) return;
    if (state.rows.isEmpty) return;

    // Quota exceeded or storage blocked: keep the newest half and retry.
    final keep = state.rows.length ~/ 2;
    final trimmed = state.rows.sublist(state.rows.length - keep);
    _logger?.warning(
      'KeyValueQueue: write to "$_key" failed; '
      'dropping ${state.rows.length - keep} oldest events',
    );
    if (trimmed.isEmpty ||
        !_store.write(_key, _encode(_QueueState(state.nextId, trimmed)))) {
      _logger?.warning('KeyValueQueue: storage unavailable; queue not saved');
    }
  }

  String _encode(_QueueState state) => jsonEncode(<String, Object>{
        'v': _kVersion,
        'next': state.nextId,
        'events': [
          for (final e in state.rows)
            [e.id, e.createdAt.millisecondsSinceEpoch, e.payload],
        ],
      });
}

class _QueueState {
  final int nextId;
  final List<QueuedEvent> rows;

  _QueueState(this.nextId, this.rows);
}
