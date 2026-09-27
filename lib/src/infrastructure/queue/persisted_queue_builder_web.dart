/// Web builder for the persisted queue: `window.localStorage`
/// (infrastructure layer).
library;

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/ports/queue_port.dart';
import 'package:flutter_umami_analytics/src/infrastructure/platform/host_environment.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/key_value_queue.dart';
import 'package:flutter_umami_analytics/src/infrastructure/storage/key_value_store.dart';

/// Returns a [KeyValueQueue] over `window.localStorage`, namespaced by
/// [instanceName].
///
/// [databasePath] is ignored on web. [eventTtl] is applied by the collector
/// on flush. When the browser blocks `localStorage` (private mode, blocked
/// site data) the queue falls back to memory and logs a warning; queued
/// events are then lost on reload.
UmamiQueue buildPersistedQueue({
  required int maxSize,
  required Duration eventTtl,
  String? databasePath,
  String? instanceName,
  UmamiLogger? logger,
}) {
  final store = openBrowserStorage();
  if (store == null) {
    logger?.warning(
      'localStorage unavailable; persisted queue falls back to memory',
    );
  }
  return KeyValueQueue(
    store: store ?? InMemoryKeyValueStore(),
    maxSize: maxSize,
    instanceName: instanceName,
    logger: logger,
  );
}
