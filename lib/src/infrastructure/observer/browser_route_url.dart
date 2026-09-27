/// Route URL extraction from the browser location (infrastructure layer).
///
/// Pure Dart; used by [UmamiNavigatorObserver] on Flutter web when a route
/// has no name.
library;

/// Returns the app route for a browser location [uri].
///
/// - Hash strategy (`https://host/#/details?id=1`): returns the fragment,
///   `/details?id=1`.
/// - Path strategy (`https://host/details?id=1`): returns the path and the
///   query, `/details?id=1`.
///
/// Returns `/` for an empty path.
String routeUrlFromBrowserUri(Uri uri) {
  final fragment = uri.fragment;
  if (fragment.startsWith('/')) return fragment;
  final path = uri.path.isEmpty ? '/' : uri.path;
  return uri.hasQuery ? '$path?${uri.query}' : path;
}
