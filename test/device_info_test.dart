import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_umami_analytics/flutter_umami_analytics.dart';
import 'package:flutter_umami_analytics/src/infrastructure/collector/tracking_collector.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/device_details_loader.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/device_info_service.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/platform_detector.dart';
import 'package:flutter_umami_analytics/src/infrastructure/http/default_http_client.dart';
import 'package:flutter_umami_analytics/src/infrastructure/http/http_headers.dart';
import 'package:flutter_umami_analytics/src/infrastructure/observer/browser_route_url.dart';
import 'package:flutter_umami_analytics/src/infrastructure/platform/browser_environment.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _browser = BrowserEnvironment(
  userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15',
  language: 'th-TH',
  screenWidth: 1440,
  screenHeight: 900,
  referrer: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceInfoData', () {
    const full = DeviceInfoData(
      locale: 'en-US',
      screenResolution: '390x844',
      platform: 'ios',
      osName: 'iOS',
      osVersion: '17.4',
      deviceModel: 'iPhone15,2',
      appVersion: '1.2.3',
      appBuild: '45',
    );

    test('toEventData keeps non-null details with snake_case keys', () {
      expect(full.toEventData(), <String, String>{
        'platform': 'ios',
        'os': 'iOS',
        'os_version': '17.4',
        'device_model': 'iPhone15,2',
        'app_version': '1.2.3',
        'app_build': '45',
      });
    });

    test('equality covers the detail fields', () {
      expect(full, full.copyWith());
      expect(full == full.copyWith(appVersion: '9.9.9'), isFalse);
      expect(full.hashCode, full.copyWith().hashCode);
    });
  });

  group('DefaultDeviceInfoService', () {
    test('web: locale and screen come from the browser', () async {
      final service = DefaultDeviceInfoService(
        platform: PlatformKind.web,
        browser: _browser,
        detailsLoader: () async => detailsFromUserAgent(_browser.userAgent),
      );
      final before = service.gather();
      expect(before.locale, 'th-TH');
      expect(before.screenResolution, '1440x900');
      expect(before.platform, 'web');
      expect(before.browserName, isNull);

      final after = await service.load();
      expect(after.browserName, 'Safari');
      expect(after.browserVersion, '17.4');
      expect(after.osName, 'macOS');
      expect(service.gather(), after);
      expect(service.userAgent, _browser.userAgent);
    });

    test('native: details merge in and the UA carries the OS version',
        () async {
      final service = DefaultDeviceInfoService(
        platform: PlatformKind.android,
        detailsLoader: () async => const DeviceDetails(
          osName: 'Android',
          osVersion: '14',
          deviceModel: 'Pixel 8',
          appVersion: '2.0.0',
          appBuild: '7',
        ),
      );
      expect(service.userAgent, contains('Android 10;'));
      final info = await service.load();
      expect(info.platform, 'android');
      expect(info.osVersion, '14');
      expect(info.deviceModel, 'Pixel 8');
      expect(info.appVersion, '2.0.0');
      expect(info.locale, contains('-'),
          reason: 'locale uses BCP-47 (en-US), not en_US');
      expect(info.screenResolution, matches(RegExp(r'^\d+x\d+$')));
      expect(service.userAgent, contains('Android 14; K)'));
    });

    test('load never throws and is bounded by the timeout', () async {
      final (:logger, :logs) = _logger();
      final failing = DefaultDeviceInfoService(
        logger: logger,
        platform: PlatformKind.linux,
        detailsLoader: () async => throw StateError('no plugin'),
      );
      final info = await failing.load();
      expect(info.osName, isNull);

      final hanging = DefaultDeviceInfoService(
        logger: logger,
        platform: PlatformKind.linux,
        detailsLoader: () => Completer<DeviceDetails>().future,
      );
      final result =
          await hanging.load(timeout: const Duration(milliseconds: 10));
      expect(result.platform, 'linux');
      expect(logs.any((l) => l.contains('timed out')), isTrue);
    });

    test('load runs the loader once', () async {
      var calls = 0;
      final service = DefaultDeviceInfoService(
        platform: PlatformKind.ios,
        detailsLoader: () async {
          calls++;
          return DeviceDetails.empty;
        },
      );
      await Future.wait(
          <Future<DeviceInfoData>>[service.load(), service.load()]);
      await service.load();
      expect(calls, 1);
    });
  });

  group('attachDeviceData', () {
    const device = DeviceInfoData(
      locale: 'en-US',
      screenResolution: '390x844',
      platform: 'android',
      osName: 'Android',
      osVersion: '14',
      appVersion: '1.0.0',
    );

    Future<Map<String, dynamic>> sendEvent({
      required bool attach,
      Map<String, dynamic>? data,
      String? name = 'click',
    }) async {
      final http = _RecordingHttp();
      final collector = TrackingCollector(
        config: FlutterUmamiConfig(
          websiteId: 'w',
          endpoint: 'https://example.com',
          hostname: 'app',
          attachDeviceData: attach,
        ),
        httpClient: http,
        queue: _NoQueue(),
        deviceInfo: _Fixed(device),
      );
      if (name == null) {
        await collector.trackPageView(url: '/home');
      } else {
        await collector.trackEvent(name: name, data: data);
      }
      return (http.bodies.single['payload'] as Map).cast<String, dynamic>();
    }

    test('off by default: event data is unchanged', () async {
      final payload = await sendEvent(attach: false, data: {'a': 1});
      expect(payload['data'], {'a': 1});
    });

    test('on: device details merge into event data, caller keys win', () async {
      final payload =
          await sendEvent(attach: true, data: {'a': 1, 'os': 'custom'});
      expect(payload['data'], <String, dynamic>{
        'platform': 'android',
        'os': 'custom',
        'os_version': '14',
        'app_version': '1.0.0',
        'a': 1,
      });
    });

    test('on: pageviews are not changed', () async {
      final payload = await sendEvent(attach: true, name: null);
      expect(payload.containsKey('data'), isFalse);
    });

    test('config equality and copyWith include attachDeviceData', () {
      const a =
          FlutterUmamiConfig(websiteId: 'w', endpoint: 'e', hostname: 'h');
      expect(a.attachDeviceData, isFalse);
      final b = a.copyWith(attachDeviceData: true);
      expect(b.attachDeviceData, isTrue);
      expect(a == b, isFalse);
      expect(
          b.merge(<String, dynamic>{'hostname': 'x'}).attachDeviceData, isTrue);
    });
  });

  group('DefaultHttpClient', () {
    test('sends the given User-Agent and reads the cache token from the body',
        () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'cache': 'tok-1'}), 200);
      });
      final adapter = DefaultHttpClient(
        client: client,
        logger: const UmamiLogger(),
        userAgent: 'Custom/1.0',
      );
      expect(await adapter.send('https://u.example/api/send', {'a': 1}), true);
      // Browsers own the User-Agent header, so the adapter never sets it
      // on web.
      expect(requests.single.headers[HttpHeaderNames.userAgent],
          kIsWeb ? isNull : 'Custom/1.0');
      expect(adapter.cacheToken, 'tok-1');

      await adapter.send('https://u.example/api/send', {'a': 2});
      expect(requests.last.headers[HttpHeaderNames.cacheControl], 'tok-1');
    });

    test('network errors return false without throwing', () async {
      final (:logger, :logs) = _logger();
      final adapter = DefaultHttpClient(
        client: MockClient((_) async => throw http.ClientException('offline')),
        logger: logger,
      );
      expect(await adapter.send('https://u.example/api/send', {}), false);
      expect(logs.single, contains('Network error'));
    });
  });

  group('routeUrlFromBrowserUri', () {
    test('hash strategy returns the fragment', () {
      expect(routeUrlFromBrowserUri(Uri.parse('https://a.com/#/details?id=1')),
          '/details?id=1');
    });

    test('path strategy returns path and query', () {
      expect(routeUrlFromBrowserUri(Uri.parse('https://a.com/shop/cart?x=2')),
          '/shop/cart?x=2');
      expect(routeUrlFromBrowserUri(Uri.parse('https://a.com')), '/');
    });

    test('non-route fragments are ignored', () {
      expect(routeUrlFromBrowserUri(Uri.parse('https://a.com/docs#intro')),
          '/docs');
    });
  });

  group('UmamiNavigatorObserver browser URL fallback', () {
    testWidgets('unnamed page route uses the browser URL', (tester) async {
      final collector = _RecordingCollector();
      final observer = UmamiNavigatorObserver(
        collector: collector,
        useBrowserUrl: true,
        currentUri: () => Uri.parse('https://a.com/#/profile'),
      );
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: <NavigatorObserver>[observer],
        home: const SizedBox(),
      ));
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
          nav.push(MaterialPageRoute<void>(builder: (_) => const SizedBox())));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(collector.urls, contains('/profile'));
    });

    testWidgets('disabled: unnamed routes are skipped', (tester) async {
      final collector = _RecordingCollector();
      final observer = UmamiNavigatorObserver(
        collector: collector,
        useBrowserUrl: false,
        currentUri: () => Uri.parse('https://a.com/#/profile'),
      );
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: <NavigatorObserver>[observer],
        home: const SizedBox(),
      ));
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
          nav.push(MaterialPageRoute<void>(builder: (_) => const SizedBox())));
      await tester.pumpAndSettle();
      expect(collector.urls, isNot(contains('/profile')));
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

class _Fixed implements DeviceInfoPort {
  final DeviceInfoData data;

  _Fixed(this.data);

  @override
  DeviceInfoData gather() => data;
}

class _RecordingHttp implements HttpClientPort {
  final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];

  @override
  Future<bool> send(String endpoint, Map<String, dynamic> body) async {
    bodies.add(body);
    return true;
  }

  @override
  String? get cacheToken => null;

  @override
  void dispose() {}
}

class _NoQueue implements UmamiQueue {
  @override
  Future<void> insert(String payload) async {}

  @override
  Future<List<QueuedEvent>> getAll() async => const <QueuedEvent>[];

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> deleteExpired(Duration ttl) async {}

  @override
  Future<int> get length async => 0;

  @override
  Future<void> close() async {}
}

class _RecordingCollector implements UmamiCollector {
  final List<String> urls = <String>[];

  @override
  Future<bool> trackPageView({
    required String url,
    String? title,
    String? referrer,
    String? hostname,
    String? language,
    String? screen,
    UmamiConfigOverrides? overrides,
  }) async {
    urls.add(url);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
