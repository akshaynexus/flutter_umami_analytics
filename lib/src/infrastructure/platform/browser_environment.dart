/// Snapshot of the browser values the SDK reads on Flutter web
/// (infrastructure layer).
///
/// Pure Dart value object so web-only logic (User-Agent parsing, URL
/// resolution) stays testable on the Dart VM.
library;

/// Represents the browser values read once from `window.navigator`,
/// `window.screen`, `window.location` and `document.referrer`.
///
/// Built only on Flutter web by `readBrowserEnvironment()`; every field is
/// best-effort and may be empty when the browser blocks the API.
class BrowserEnvironment {
  /// `navigator.userAgent`, e.g. `Mozilla/5.0 (...) Chrome/129.0.0.0 ...`.
  final String userAgent;

  /// `navigator.language` in BCP-47 form, e.g. `en-US`. Empty when unknown.
  final String language;

  /// `screen.width` in CSS pixels (the value the Umami web tracker sends).
  final int screenWidth;

  /// `screen.height` in CSS pixels.
  final int screenHeight;

  /// `document.referrer`; empty string when the page was opened directly.
  final String referrer;

  /// Builds a browser snapshot. All fields are required.
  const BrowserEnvironment({
    required this.userAgent,
    required this.language,
    required this.screenWidth,
    required this.screenHeight,
    required this.referrer,
  });

  /// Screen size in the Umami `WxH` format, or `null` when the browser
  /// reports a zero size.
  String? get screen => screenWidth > 0 && screenHeight > 0
      ? '${screenWidth}x$screenHeight'
      : null;
}
