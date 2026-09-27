# Automatic tracking with NavigatorObserver

## `UmamiNavigatorObserver`

A [`NavigatorObserver`](https://api.flutter.dev/flutter/widgets/NavigatorObserver-class.html) that automatically sends a `trackPageView` on every relevant route change. Infrastructure layer; delegates actual sending to the injected [`UmamiCollector`](2-queue.md).

Pass the instance to the widget that builds `MaterialApp` (or `CupertinoApp`):

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.analytics});

  final FlutterUmamiAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [
        UmamiNavigatorObserver(
          collector: analytics.collector,
        ),
      ],
      // ...
    );
  }
}
```

> Use `analytics.collector` (public getter of the facade) so you don't couple to the internal implementation.

### Constructor

| Parameter         | Type                                | Default  | Description                                                                   |
| ----------------- | ----------------------------------- | -------- | ----------------------------------------------------------------------------- |
| `collector`       | `UmamiCollector`                    | required | Collector that receives the pageviews.                                        |
| `autoTrack`       | `bool`                              | `true`   | When `false`, the observer stays registered but emits no events.              |
| `routeFilter`     | `bool Function(Route<dynamic>)?`    | `null`   | Predicate that excludes routes (returns `false` → skipped).                   |
| `routeNameMapper` | `String? Function(Route<dynamic>)?` | `null`   | Resolves the URL sent to Umami from a `Route`. If it returns `null`, skipped. |
| `logger`          | `UmamiLogger?`                      | `null`   | Sink for tracking errors. If `null`, errors are discarded.                    |

### Observed events

Each hook applies `autoTrack` first, then `routeFilter`, then `routeNameMapper` (or fallback to `route.settings.name`). An event is emitted only if it survives the whole chain.

| Hook         | Tracked route                                        | Notes                                                                                                                             |
| ------------ | ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `didPush`    | freshly pushed `route`                               | As long as it passes the filter / mapper.                                                                                         |
| `didReplace` | `newRoute` (ignores `oldRoute`)                      | If `newRoute` is `null`, does nothing.                                                                                            |
| `didPop`     | `previousRoute` (the one that becomes visible again) | If `previousRoute` is `null`, does nothing. May duplicate the original `didPush` for that route; use `routeFilter` to avoid that. |

### URL and title resolution

- Without `routeNameMapper`: `url = route.settings.name`, `title = null`.
- With `routeNameMapper`:
  - `url = routeNameMapper(route)`.
  - `title = route.settings.name` (the original route name), useful to keep readability in the Umami dashboard even when you customize the URL.
  - If the mapper returns `null`, the route **is not tracked**.

### Web: browser URL fallback

On Flutter web (`useBrowserUrl` defaults to `kIsWeb`), a `PageRoute` without `settings.name` and without a `routeNameMapper` is tracked with the browser location, read after the next frame. Both URL strategies work: `https://host/#/details` and `https://host/details` report `/details` (the query string is kept). Dialogs and other non-page routes are not tracked this way. Pass `useBrowserUrl: false` to disable it.

### Fire-and-forget

Tracking is fire-and-forget: network errors do not propagate to the caller.

- If you pass `logger`, failures (with stacktrace) are reported there.
- If `logger` is `null`, errors are silently discarded.
- To capture failure metrics at the business level, implement a custom `UmamiCollector` or wrap the logger.

### Route filtering

Exclude routes from automatic tracking (useful for login, splash, modal dialogs):

```dart
UmamiNavigatorObserver(
  collector: analytics.collector,
  routeFilter: (route) => route.settings.name != '/login',
)
```

### URL mapping

Customize the URL sent to Umami (for example, prefixing internal routes):

```dart
UmamiNavigatorObserver(
  collector: analytics.collector,
  routeNameMapper: (route) {
    final name = route.settings.name;
    return name != null ? '/app$name' : null;
  },
)
```

Returning `null` skips tracking for that route.

### Pausing tracking (without unregistering)

`autoTrack: false` keeps the observer in the `Navigator`, but disables all emissions. Useful for reactive toggles without rebuilding the widget tree:

```dart
UmamiNavigatorObserver(
  collector: analytics.collector,
  autoTrack: false,
)
```

## See also

- Internally calls [`trackPageView`](3-tracking.md).
- For advanced error handling implement a custom collector: [10-advanced.md](10-advanced.md).
