/// Builds the adapter for `UmamiQueueConfig.persisted` per platform
/// (infrastructure layer).
///
/// Native targets get the SQLite [PersistedQueue]; Flutter web gets a
/// `localStorage`-backed [KeyValueQueue]. The conditional export keeps
/// `sqflite` out of the web build.
library;

export 'package:flutter_umami_analytics/src/infrastructure/queue/persisted_queue_builder_io.dart'
    if (dart.library.js_interop) 'package:flutter_umami_analytics/src/infrastructure/queue/persisted_queue_builder_web.dart';
