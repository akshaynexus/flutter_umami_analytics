import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/device_details_loader.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/platform_detector.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/user_agent_parser.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/user_agent_service.dart';
import 'package:flutter_umami_analytics/src/infrastructure/http/http_headers.dart';

const _chromeWindows =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';
const _edgeWindows = '$_chromeWindows Edg/129.0.2792.52';
const _safariMac = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15';
const _firefoxLinux =
    'Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0';
const _safariIphone =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 '
    'Safari/604.1';
const _chromeIpad = 'Mozilla/5.0 (iPad; CPU OS 17_4 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/129.0.6668.46 '
    'Mobile/15E148 Safari/604.1';
const _chromeAndroid = 'Mozilla/5.0 (Linux; Android 14; K) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile '
    'Safari/537.36';
const _samsungAndroid = 'Mozilla/5.0 (Linux; Android 13; SM-S911B) '
    'AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/25.0 '
    'Chrome/121.0.0.0 Mobile Safari/537.36';
const _firefoxAndroid =
    'Mozilla/5.0 (Android 14; Mobile; rv:130.0) Gecko/130.0 Firefox/130.0';
const _operaMac = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 '
    'Safari/537.36 OPR/114.0.0.0';
const _chromeOs = 'Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';

void main() {
  group('UserAgentParser', () {
    void expectParsed(
      String ua, {
      String? browser,
      String? browserVersion,
      String? os,
      String? osVersion,
    }) {
      final parsed = UserAgentParser.parse(ua);
      expect(parsed.browserName, browser, reason: 'browser for $ua');
      expect(parsed.browserVersion, browserVersion, reason: 'version for $ua');
      expect(parsed.osName, os, reason: 'os for $ua');
      expect(parsed.osVersion, osVersion, reason: 'os version for $ua');
    }

    test('Chrome on Windows', () {
      expectParsed(_chromeWindows,
          browser: 'Chrome',
          browserVersion: '129.0.0.0',
          os: 'Windows',
          osVersion: '10.0');
    });

    test('Edge wins over Chrome', () {
      expectParsed(_edgeWindows,
          browser: 'Edge',
          browserVersion: '129.0.2792.52',
          os: 'Windows',
          osVersion: '10.0');
    });

    test('Safari on macOS', () {
      expectParsed(_safariMac,
          browser: 'Safari',
          browserVersion: '17.4',
          os: 'macOS',
          osVersion: '10.15.7');
    });

    test('Firefox on Linux', () {
      expectParsed(_firefoxLinux,
          browser: 'Firefox', browserVersion: '130.0', os: 'Linux');
    });

    test('Safari on iPhone', () {
      expectParsed(_safariIphone,
          browser: 'Safari',
          browserVersion: '17.4',
          os: 'iOS',
          osVersion: '17.4.1');
    });

    test('Chrome on iPad (CriOS)', () {
      expectParsed(_chromeIpad,
          browser: 'Chrome',
          browserVersion: '129.0.6668.46',
          os: 'iOS',
          osVersion: '17.4');
    });

    test('Chrome on Android', () {
      expectParsed(_chromeAndroid,
          browser: 'Chrome',
          browserVersion: '129.0.0.0',
          os: 'Android',
          osVersion: '14');
    });

    test('Samsung Internet wins over Chrome', () {
      expectParsed(_samsungAndroid,
          browser: 'Samsung Internet',
          browserVersion: '25.0',
          os: 'Android',
          osVersion: '13');
    });

    test('Firefox on Android', () {
      expectParsed(_firefoxAndroid,
          browser: 'Firefox',
          browserVersion: '130.0',
          os: 'Android',
          osVersion: '14');
    });

    test('Opera wins over Chrome', () {
      expectParsed(_operaMac,
          browser: 'Opera',
          browserVersion: '114.0.0.0',
          os: 'macOS',
          osVersion: '10.15.7');
    });

    test('ChromeOS', () {
      expectParsed(_chromeOs,
          browser: 'Chrome',
          browserVersion: '129.0.0.0',
          os: 'ChromeOS',
          osVersion: '14541.0.0');
    });

    test('empty and unknown strings give null fields', () {
      expectParsed('');
      expectParsed('curl/8.4.0');
    });

    test('detailsFromUserAgent maps the parse result', () {
      final details = detailsFromUserAgent(_safariIphone);
      expect(details.browserName, 'Safari');
      expect(details.osName, 'iOS');
      expect(details.deviceModel, isNull);
    });
  });

  group('UserAgentService.build', () {
    test('Android embeds the real OS version and no model', () {
      final ua = UserAgentService.build(PlatformKind.android, osVersion: '14');
      expect(ua, contains('Android 14; K)'));
      final parsed = UserAgentParser.parse(ua);
      expect(parsed.osName, 'Android');
      expect(parsed.osVersion, '14');
    });

    test('iOS uses underscores and the iPad form for tablets', () {
      final phone = UserAgentService.build(PlatformKind.ios, osVersion: '17.4');
      expect(phone, contains('iPhone OS 17_4 like Mac OS X'));
      final tablet = UserAgentService.build(PlatformKind.ios,
          osVersion: '17.4', tablet: true);
      expect(tablet, contains('iPad; CPU OS 17_4'));
      expect(UserAgentParser.parse(tablet).osVersion, '17.4');
    });

    test('macOS embeds the version', () {
      final ua =
          UserAgentService.build(PlatformKind.macos, osVersion: '14.5.0');
      expect(UserAgentParser.parse(ua).osVersion, '14.5.0');
    });

    test('Windows is frozen at NT 10.0', () {
      final ua =
          UserAgentService.build(PlatformKind.windows, osVersion: '10.0.22631');
      expect(ua, contains('Windows NT 10.0;'));
    });

    test('missing version falls back to a generic one', () {
      expect(UserAgentService.build(PlatformKind.android),
          contains('Android 10;'));
      expect(UserAgentService.build(PlatformKind.ios, osVersion: ''),
          contains('OS 17_0 '));
    });
  });

  group('buildBaseHeaders', () {
    test('includes User-Agent by default on native only', () {
      final headers = buildBaseHeaders(userAgent: 'UA');
      expect(headers[HttpHeaderNames.userAgent], kIsWeb ? isNull : 'UA');
    });

    test('includeUserAgent true forces the header', () {
      final headers = buildBaseHeaders(userAgent: 'UA', includeUserAgent: true);
      expect(headers[HttpHeaderNames.userAgent], 'UA');
    });

    test('omits User-Agent when includeUserAgent is false (web)', () {
      final headers = buildBaseHeaders(includeUserAgent: false);
      expect(headers.containsKey(HttpHeaderNames.userAgent), isFalse);
      expect(
          headers.keys,
          unorderedEquals(<String>[
            HttpHeaderNames.contentType,
            HttpHeaderNames.accept,
          ]));
    });
  });
}
