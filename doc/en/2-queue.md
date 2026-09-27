# Offline Queue

When an event cannot be sent (no connection, timeout, HTTP error, or any `false` returned by the HTTP client), it is stored in a queue for later retry.

The queue follows the package's hexagonal pattern: the `UmamiQueue` port (`domain/ports/queue_port.dart`) defines the interface; three adapters in `infrastructure/queue/` implement it and `queue_factory.dart` selects one through an exhaustive `switch` over the `sealed class UmamiQueueConfig`.

## Strategies

`UmamiQueueConfig` exposes three `const` factory constructors. `maxSize` defaults to `kDefaultQueueMaxSize` (500).

### `UmamiQueueConfig.disabled()`

No queue (`NoopQueue`). Failed events are discarded.

```dart
queueConfig: const UmamiQueueConfig.disabled(),
```

### `UmamiQueueConfig.inMemory({maxSize})`

In-memory queue (`InMemoryQueue`, backed by `LinkedHashMap`). Lost when the app closes.

```dart
queueConfig: const UmamiQueueConfig.inMemory(maxSize: 500),
```

### `UmamiQueueConfig.persisted({maxSize, eventTtl, databasePath})`

SQLite queue (`PersistedQueue`, package `sqflite`). Survives restarts. Applies `eventTtl` (default `Duration(hours: 48)`) to discard old events during flushing.

```dart
queueConfig: const UmamiQueueConfig.persisted(
  maxSize: 500,
  eventTtl: Duration(hours: 48),
),
```

The database file is named `umami_queue.db` or `umami_queue_{instanceName}.db` when you set `instanceName` (multi-instance). The `databasePath` parameter overrides the **base directory** (default `getDatabasesPath()`); it is not the full file path — the `.db` name is always controlled by the SDK via `instanceSuffix(instanceName)`.

Internally it uses table `queued_events` (columns `id INTEGER PRIMARY KEY AUTOINCREMENT`, `payload TEXT NOT NULL`, `created_at INTEGER NOT NULL`) with index `idx_created_at`. Insertion runs inside a transaction that, upon reaching `maxSize`, atomically evicts the oldest events (`count - maxSize + 1` rows) before inserting the new one, preserving the limit.

### Web

On Flutter web, `UmamiQueueConfig.persisted()` uses `localStorage` instead of SQLite: one JSON value under `umami_queue[_instanceName]`, bounded by `maxSize`, pruned by `eventTtl` on flush. When the storage quota is full, the oldest half is dropped. When `localStorage` is blocked (private mode, blocked site data), the queue falls back to memory. `databasePath` is ignored. Tabs of the same origin share the queue.

## `UmamiQueue` Port

Contract implemented by the three adapters:

| Method               | Return                      | Description                                                                                |
| -------------------- | --------------------------- | ------------------------------------------------------------------------------------------ |
| `insert(payload)`    | `Future<void>`              | Adds an opaque JSON payload (output of `UmamiPayload.toJson`).                             |
| `getAll()`           | `Future<List<QueuedEvent>>` | Reads events in insertion order (`id ASC`).                                                |
| `delete(id)`         | `Future<void>`              | Deletes an event by row id after a successful send. No-op if the id doesn't exist.         |
| `deleteExpired(ttl)` | `Future<void>`              | Purges events with `created_at` earlier than `now - ttl`.                                  |
| `length`             | `Future<int>`               | Current depth (best-effort snapshot).                                                      |
| `close()`            | `Future<void>`              | Releases resources (closes the DB in `PersistedQueue`, clears the map in `InMemoryQueue`). |

The row model is `QueuedEvent` (`domain/models/queued_event.dart`): `{id?, payload, createdAt}`. `id` is `null` in memory and for non-inserted events; SQLite assigns it only in the persisted queue.

## Custom queue adapter (port injection)

The `UmamiQueue` port is public and pluggable: any class that implements the six methods above can replace the built-in queue via the `queue:` parameter of `createUmamiAnalytics`. The factory does not build a queue from `UmamiQueueConfig` when you inject one, and the facade does not close it on `dispose` — your queue outlives the analytics instance.

```dart
class MyHiveQueue implements UmamiQueue { /* ... */ }

final queue = MyHiveQueue();
final analytics = await createUmamiAnalytics(
  config,
  queue: queue,            // caller owns the lifecycle
);
```

Policy (enqueue on failure, TTL purge on flush) is still derived from `FlutterUmamiConfig.queueConfig` for backwards compatibility. Pair the injection with the right config:

| `queueConfig`                             | enqueue on failure | TTL purge on flush |
| ----------------------------------------- | ------------------ | ------------------ |
| `UmamiQueueConfig.disabled()`             | no (drop)          | no                 |
| `UmamiQueueConfig.inMemory(maxSize: n)`   | yes                | no                 |
| `UmamiQueueConfig.persisted(eventTtl: x)` | yes                | yes (TTL = `x`)    |

`persisted` is the right choice when your custom queue benefits from TTL eviction; `disabled` when you handle offline storage yourself and only want fire-and-forget semantics.

## Behavior

1. `trackPageView`, `trackEvent`, and `identify` build their `UmamiPayload` and pass it to `_send`.
2. `_send` attempts the send via HTTP. On failure → `_enqueue` serializes the payload to JSON (`jsonEncode`) and inserts it, gated on the `enqueueEnabled` policy. With `disabled()` (or any caller setting `enqueueEnabled: false`), `_enqueue` short-circuits with an early `return` — the event is discarded without ever touching the queue.
3. If the send succeeds → `_autoFlush()` runs, draining the pending queue (see below).
4. If the queue is full (`length >= maxSize`), the oldest events are removed **before** inserting:
   - `InMemoryQueue`: `while` loop that removes entries until below `maxSize`.
   - `PersistedQueue`: transaction that deletes `count - maxSize + 1` rows (usually 1; more only if count exceeds the limit).
5. Internal queue failures (insert, read, delete, send) are caught via `safeBool` / `safeAsync` and only logged: they never propagate to the caller (graceful degradation).

`flush()` and `_autoFlush()` share the `_flushing` flag, making them reentrant: nested or concurrent calls are discarded with an immediate `return`. `_autoFlush()` additionally short-circuits when `length == 0` (read prior to the send) and reuses the same `_doFlush()` as `flush()`.

## Manual flush

```dart
await analytics.flush();
```

`_doFlush()` sends all queued events in parallel (`Future.wait` over `_flushOne`) and, on completion, deletes from the queue only those that were sent successfully. Useful before closing the app, upon recovering connectivity, or during background tasks (`background fetch`).

Extra resilience: if a queued payload cannot be decoded as JSON (`QueuedEvent.decodedPayload == null`, e.g. a corrupted row), `_flushOne` deletes it directly and returns `false` — it is not retried indefinitely.

> The TTL purge during flushing only applies when the `flushPurgeTtl` policy is non-null. The factory sets it to `PersistedUmamiQueueConfig.eventTtl` for the `persisted` strategy and to `null` for `disabled` / `inMemory`. When you inject a custom queue, the same derivation applies unless you bypass it by constructing `TrackingCollector` directly (advanced).

## See also

- `dispose()` in [1-initialization.md](1-initialization.md) runs `flush()` (wrapped in `safeAsync`) and then `queue.close()`.
- Multi-instance and storage namespaces in [1-initialization.md](1-initialization.md#multiple-instances) and [7-device.md](7-device.md).
- Flow diagrams in [`../architecture.md`](../architecture.md).
