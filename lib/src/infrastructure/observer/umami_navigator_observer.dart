/// [NavigatorObserver] that auto-emits pageviews on push / replace / pop.
///
/// Attach it to [Navigator.observers] (or pass it through `MaterialApp` /
/// `CupertinoApp`) to track navigation without manual calls to
/// [UmamiCollector.trackPageView]. The observer never throws; tracking
/// failures are routed to [logger] when provided.
///
/// On Flutter web, a page route without a name is tracked with the
/// browser's current path (path or hash URL strategy), so apps that use
/// `Router` / `go_router` pages without names still report pageviews.
///
/// Layer: infrastructure (observer adapter).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/ports/collector_port.dart';
import 'package:flutter_umami_analytics/src/infrastructure/observer/browser_route_url.dart';

/// [NavigatorObserver] that auto-emits pageviews on push / replace / pop.
///
/// Responsibilities:
/// - Listen to [NavigatorObserver.didPush] / [didReplace] / [didPop].
/// - Resolve a URL per route via [routeNameMapper] or `route.settings.name`.
/// - Delegate the actual pageview to the injected [UmamiCollector].
///
/// Layer: infrastructure.
class UmamiNavigatorObserver extends NavigatorObserver {
  final UmamiCollector _collector;

  /// When `false`, the observer still runs but no pageviews are emitted.
  ///
  /// Defaults to `true`.
  final bool autoTrack;

  /// Optional predicate that skips routes for which it returns `false`
  /// (e.g. ignore modal dialogs or splash routes).
  final bool Function(Route<dynamic> route)? routeFilter;

  /// Optional mapper that extracts the URL from a [Route].
  ///
  /// When `null`, falls back to `route.settings.name`. When the mapper
  /// returns `null`, the route is skipped.
  final String? Function(Route<dynamic> route)? routeNameMapper;

  /// Optional error sink for failed tracking calls.
  ///
  /// When `null`, tracking errors are silently dropped.
  final UmamiLogger? logger;

  /// When `true`, a [PageRoute] with no `settings.name` (and no
  /// [routeNameMapper]) is tracked with the browser's current location,
  /// read after the next frame so the router has updated the URL.
  ///
  /// Defaults to `true` on Flutter web and `false` elsewhere. Dialogs and
  /// other non-page routes are never tracked this way.
  final bool useBrowserUrl;

  final Uri Function() _currentUri;

  /// Builds an observer wired to a [collector].
  ///
  /// Required: [collector] (the [UmamiCollector] that receives pageviews).
  /// Optional: [autoTrack] (defaults to `true`), [routeFilter],
  /// [routeNameMapper], [logger], [useBrowserUrl] (defaults to `kIsWeb`)
  /// and [currentUri] (reads the browser location; defaults to
  /// [Uri.base], which is `window.location` on web).
  UmamiNavigatorObserver({
    required UmamiCollector collector,
    this.autoTrack = true,
    this.routeFilter,
    this.routeNameMapper,
    this.logger,
    bool? useBrowserUrl,
    Uri Function()? currentUri,
  })  : _collector = collector,
        useBrowserUrl = useBrowserUrl ?? kIsWeb,
        _currentUri = currentUri ?? (() => Uri.base);

  /// Tracks a pageview for the just-pushed [route] (after filter / mapper).
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackIfNeeded(route);
  }

  /// Tracks a pageview for [newRoute] when present (after filter / mapper).
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute == null) return;
    _trackIfNeeded(newRoute);
  }

  /// Tracks a pageview for the now-visible [previousRoute] when present
  /// (after filter / mapper).
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute == null) return;
    _trackIfNeeded(previousRoute);
  }

  void _trackIfNeeded(Route<dynamic> route) {
    if (!autoTrack) return;
    final filter = routeFilter;
    if (filter != null && !filter(route)) return;

    final mapper = routeNameMapper;
    final url = mapper != null ? mapper(route) : route.settings.name;
    if (url == null) {
      if (mapper == null && useBrowserUrl && route is PageRoute) {
        _trackBrowserUrlAfterFrame();
      }
      return;
    }

    final title = mapper != null ? route.settings.name : null;

    unawaited(_runTrack(url: url, title: title));
  }

  void _trackBrowserUrlAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The router reports the new URL to the browser in a post-frame
      // callback too; a zero timer runs after it.
      Timer.run(() {
        final String url;
        try {
          url = routeUrlFromBrowserUri(_currentUri());
        } catch (e) {
          logger?.warning('UmamiNavigatorObserver: browser URL unreadable: $e');
          return;
        }
        unawaited(_runTrack(url: url));
      });
    });
  }

  Future<void> _runTrack({required String url, String? title}) async {
    try {
      await _collector.trackPageView(url: url, title: title);
    } catch (e, st) {
      logger?.error('UmamiNavigatorObserver track failed: $e\n$st');
    }
  }
}
