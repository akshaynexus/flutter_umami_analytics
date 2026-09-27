import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_umami_analytics/flutter_umami_analytics.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/key_value_device_id_service.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/key_value_queue.dart';
import 'package:flutter_umami_analytics/src/infrastructure/storage/key_value_store.dart';

/// Store whose writes fail until [allowWrites] is set, or while the value
/// is longer than [maxLength] (simulates a quota).
class _LimitedStore extends InMemoryKeyValueStore {
  bool allowWrites;
  final int? maxLength;

  _LimitedStore({this.allowWrites = true, this.maxLength});

  @override
  bool write(String key, String value) {
    if (!allowWrites) return false;
    final limit = maxLength;
    if (limit != null && value.length > limit) return false;
    return super.write(key, value);
  }
}

void main() {
  group('KeyValueQueue', () {
    test('insert and getAll keep FIFO order with increasing ids', () async {
      final queue = KeyValueQueue(store: InMemoryKeyValueStore());
      await queue.insert('a');
      await queue.insert('b');
      final events = await queue.getAll();
      expect(events.map((e) => e.payload), <String>['a', 'b']);
      expect(events[0].id! < events[1].id!, isTrue);
      expect(await queue.length, 2);
    });

    test('bounded: evicts the oldest event at maxSize', () async {
      final queue = KeyValueQueue(store: InMemoryKeyValueStore(), maxSize: 3);
      for (final p in <String>['1', '2', '3', '4', '5']) {
        await queue.insert(p);
      }
      final events = await queue.getAll();
      expect(events.map((e) => e.payload), <String>['3', '4', '5']);
    });

    test('maxSize 0 stores nothing', () async {
      final queue = KeyValueQueue(store: InMemoryKeyValueStore(), maxSize: 0);
      await queue.insert('x');
      expect(await queue.length, 0);
    });

    test('survives a reload: a new instance reads the same store', () async {
      final store = InMemoryKeyValueStore();
      final first = KeyValueQueue(store: store);
      await first.insert('a');
      await first.close();

      final second = KeyValueQueue(store: store);
      await second.insert('b');
      final events = await second.getAll();
      expect(events.map((e) => e.payload), <String>['a', 'b']);
      expect(events.map((e) => e.id).toSet().length, 2);
    });

    test('ids never repeat after deleting the newest event', () async {
      final queue = KeyValueQueue(store: InMemoryKeyValueStore());
      await queue.insert('a');
      final firstId = (await queue.getAll()).single.id!;
      await queue.delete(firstId);
      await queue.insert('b');
      expect((await queue.getAll()).single.id, isNot(firstId));
    });

    test('delete removes one event; an empty queue keeps its id counter',
        () async {
      final store = InMemoryKeyValueStore();
      final queue = KeyValueQueue(store: store);
      await queue.insert('a');
      await queue.insert('b');
      final events = await queue.getAll();
      await queue.delete(events.first.id!);
      expect((await queue.getAll()).single.payload, 'b');
      await queue.delete(events.last.id!);
      expect(await queue.length, 0);
      expect(store.values[queue.storageKey], contains('"next":3'));
    });

    test('deleteExpired drops events older than the ttl', () async {
      var now = DateTime(2026, 1, 1, 12);
      final queue =
          KeyValueQueue(store: InMemoryKeyValueStore(), clock: () => now);
      await queue.insert('old');
      now = now.add(const Duration(hours: 3));
      await queue.insert('new');
      await queue.deleteExpired(const Duration(hours: 1));
      expect((await queue.getAll()).single.payload, 'new');
    });

    test('instanceName namespaces the storage key', () async {
      final store = InMemoryKeyValueStore();
      final a = KeyValueQueue(store: store, instanceName: 'a');
      final b = KeyValueQueue(store: store);
      await a.insert('x');
      expect(a.storageKey, 'umami_queue_a');
      expect(b.storageKey, 'umami_queue');
      expect(await b.length, 0);
    });

    test('corrupt stored value resets to empty and logs', () async {
      final store = InMemoryKeyValueStore()..write('umami_queue', '{oops');
      final (:logger, :logs) = _logger();
      final queue = KeyValueQueue(store: store, logger: logger);
      expect(await queue.getAll(), isEmpty);
      await queue.insert('a');
      expect((await queue.getAll()).single.payload, 'a');
      expect(logs.any((l) => l.contains('corrupt')), isTrue);
    });

    test('malformed rows are skipped', () async {
      final store = InMemoryKeyValueStore()
        ..write('umami_queue',
            '{"v":1,"next":5,"events":[[1,0,"ok"],["x",0,"bad"],[2]]}');
      final queue = KeyValueQueue(store: store);
      final events = await queue.getAll();
      expect(events.single.payload, 'ok');
      await queue.insert('n');
      expect((await queue.getAll()).last.id, 5);
    });

    test('quota exceeded: keeps the newest half', () async {
      final store = _LimitedStore(maxLength: 90);
      final (:logger, :logs) = _logger();
      final queue = KeyValueQueue(store: store, logger: logger);
      for (var i = 0; i < 6; i++) {
        await queue.insert('p$i');
      }
      final payloads = (await queue.getAll()).map((e) => e.payload).toList();
      expect(payloads, isNotEmpty);
      expect(payloads.last, 'p5');
      expect(payloads.length, lessThan(6));
      expect(logs.any((l) => l.contains('dropping')), isTrue);
    });

    test('blocked storage never throws', () async {
      final queue = KeyValueQueue(store: _LimitedStore(allowWrites: false));
      await queue.insert('a');
      expect(await queue.length, 0);
      await queue.deleteExpired(const Duration(seconds: 1));
      await queue.close();
    });
  });

  group('KeyValueDeviceIdService', () {
    test('creates, persists and reuses the id', () async {
      final store = InMemoryKeyValueStore();
      final id = await KeyValueDeviceIdService(store: store).getId();
      expect(id, isNotEmpty);
      expect(await KeyValueDeviceIdService(store: store).getId(), id);
      expect(store.values['umami_device_id'], id);
    });

    test('isFirstLaunch is true once per store', () async {
      final store = InMemoryKeyValueStore();
      expect(await KeyValueDeviceIdService(store: store).isFirstLaunch(), true);
      expect(
          await KeyValueDeviceIdService(store: store).isFirstLaunch(), false);
    });

    test('reset clears both keys and yields a new id', () async {
      final store = InMemoryKeyValueStore();
      final service = KeyValueDeviceIdService(store: store);
      final id = await service.getId();
      await service.isFirstLaunch();
      await service.reset();
      expect(store.values, isEmpty);
      expect(await service.getId(), isNot(id));
    });

    test('instanceName namespaces the keys', () async {
      final store = InMemoryKeyValueStore();
      await KeyValueDeviceIdService(store: store, instanceName: 'foo').getId();
      expect(store.values.keys, contains('umami_device_id_foo'));
    });

    test('keeps the id in memory when the store rejects writes', () async {
      final service =
          KeyValueDeviceIdService(store: _LimitedStore(allowWrites: false));
      final id = await service.getId();
      expect(await service.getId(), id);
    });
  });
}

({UmamiLogger logger, List<String> logs}) _logger() {
  final logs = <String>[];
  return (
    logger: UmamiLogger(
      customLogger: (level, msg) => logs.add(msg),
      minLevel: UmamiLogLevel.debug,
    ),
    logs: logs,
  );
}
