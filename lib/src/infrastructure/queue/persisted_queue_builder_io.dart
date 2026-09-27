/// Native builder for the persisted queue: SQLite via `sqflite`
/// (infrastructure layer).
library;

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/ports/queue_port.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/persisted_queue.dart';

/// Returns a SQLite-backed [PersistedQueue] stored at [databasePath] (or the
/// `sqflite` default directory) and namespaced by [instanceName].
UmamiQueue buildPersistedQueue({
  required int maxSize,
  required Duration eventTtl,
  String? databasePath,
  String? instanceName,
  UmamiLogger? logger,
}) =>
    PersistedQueue(
      maxSize: maxSize,
      eventTtl: eventTtl,
      databasePath: databasePath,
      instanceName: instanceName,
      logger: logger,
    );
