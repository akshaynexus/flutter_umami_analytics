@TestOn('browser')
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_umami_analytics/flutter_umami_analytics.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/device_id_factory.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/device_info_service.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/key_value_device_id_service.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/platform_detector.dart';
import 'package:flutter_umami_analytics/src/infrastructure/http/http_headers.dart';
import 'package:flutter_umami_analytics/src/infrastructure/platform/host_environment.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/key_value_queue.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/queue_factory.dart';

void main() {
  test('runs as web', () {
    expect(kIsWeb, isTrue);
    expect(PlatformDetector.detect(), PlatformKind.web);
  });

  test('reads the browser environment', () {
    final env = readBrowserEnvironment();
    expect(env, isNotNull);
    expect(env!.userAgent, contains('Mozilla/5.0'));
    expect(env.screen, matches(RegExp(r'^\d+x\d+$')));
  });

  test('localStorage store round-trips values', () {
    final store = openBrowserStorage();
    expect(store, isNotNull);
    expect(store!.write('umami_test_key', 'v'), isTrue);
    expect(store.read('umami_test_key'), 'v');
    expect(store.remove('umami_test_key'), isTrue);
    expect(store.read('umami_test_key'), isNull);
  });

  test('persisted config builds a localStorage queue that survives', () async {
    const config = UmamiQueueConfig.persisted(maxSize: 2);
    final queue = createQueue(config, instanceName: 'webtest');
    expect(queue, isA<KeyValueQueue>());
    for (final p in <String>['a', 'b', 'c']) {
      await queue.insert(p);
    }
    await queue.close();
    final reopened = createQueue(config, instanceName: 'webtest');
    final events = await reopened.getAll();
    expect(events.map((e) => e.payload), <String>['b', 'c']);
    for (final e in events) {
      await reopened.delete(e.id!);
    }
  });

  test('default device id uses localStorage', () async {
    final service = createDefaultDeviceIdService(instanceName: 'webtest');
    expect(service, isA<KeyValueDeviceIdService>());
    final id = await service.getId();
    expect(await createDefaultDeviceIdService(instanceName: 'webtest').getId(),
        id);
    await service.reset();
  });

  test('device info uses the browser language, screen and UA', () async {
    final service = DefaultDeviceInfoService();
    final info = await service.load();
    expect(info.platform, 'web');
    expect(info.browserName, isNotNull);
    expect(info.osName, isNotNull);
    expect(service.userAgent, readBrowserEnvironment()!.userAgent);
  });

  test('no User-Agent header on web', () {
    expect(buildBaseHeaders().containsKey(HttpHeaderNames.userAgent), isFalse);
  });
}
