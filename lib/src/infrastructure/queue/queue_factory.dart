/// Builds the [UmamiQueue] adapter for a [UmamiQueueConfig]
/// (infrastructure layer).
library;

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_queue_config.dart';
import 'package:flutter_umami_analytics/src/domain/ports/queue_port.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/in_memory_queue.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/noop_queue.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/persisted_queue_builder.dart';

/// Returns the adapter for [config]: [NoopQueue], [InMemoryQueue], or the
/// platform's persisted queue (SQLite on native, `localStorage` on web).
UmamiQueue createQueue(
  UmamiQueueConfig config, {
  String? instanceName,
  UmamiLogger? logger,
}) {
  return switch (config) {
    DisabledUmamiQueueConfig() => NoopQueue(),
    InMemoryUmamiQueueConfig(:final maxSize) => InMemoryQueue(maxSize: maxSize),
    PersistedUmamiQueueConfig(
      :final maxSize,
      :final eventTtl,
      :final databasePath
    ) =>
      buildPersistedQueue(
        maxSize: maxSize,
        eventTtl: eventTtl,
        databasePath: databasePath,
        instanceName: instanceName,
        logger: logger,
      ),
  };
}
