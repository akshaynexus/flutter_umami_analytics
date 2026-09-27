/// Coarse browser / OS extraction from a User-Agent string
/// (infrastructure layer).
///
/// Pure Dart so it runs on the Dart VM in unit tests. Used on Flutter web
/// to turn `navigator.userAgent` into the browser name, browser version,
/// OS name and OS version that `DeviceInfoData` exposes.
library;

/// Coarse fields extracted from a User-Agent string by [UserAgentParser].
///
/// Every field is `null` when the parser does not recognise it.
class ParsedUserAgent {
  /// Browser family, e.g. `Chrome`, `Safari`, `Firefox`, `Edge`.
  final String? browserName;

  /// Browser version as reported, e.g. `129.0.0.0` or `17.4`.
  final String? browserVersion;

  /// OS family, e.g. `Android`, `iOS`, `macOS`, `Windows`, `ChromeOS`,
  /// `Linux`.
  final String? osName;

  /// OS version with dots, e.g. `14`, `17.4`, `10.15.7`. Windows reports
  /// the NT version (`10.0` for both Windows 10 and 11).
  final String? osVersion;

  /// Builds a parse result. All fields are optional.
  const ParsedUserAgent({
    this.browserName,
    this.browserVersion,
    this.osName,
    this.osVersion,
  });
}

/// Extracts coarse browser and OS fields from a User-Agent string.
///
/// Recognises the common engines only (Edge, Opera, Samsung Internet,
/// Firefox, Chrome, Safari and their iOS variants). It is not a full UA
/// database: unknown values stay `null`.
class UserAgentParser {
  const UserAgentParser._();

  // Order matters: Chromium-based browsers also carry `Chrome/` and
  // `Safari/`, and every iOS browser carries `Safari/`.
  static final List<(String, RegExp)> _browsers = <(String, RegExp)>[
    ('Edge', RegExp(r'(?:Edg|EdgA|EdgiOS|Edge)/([\d.]+)')),
    ('Opera', RegExp(r'(?:OPR|OPiOS|Opera)/([\d.]+)')),
    ('Samsung Internet', RegExp(r'SamsungBrowser/([\d.]+)')),
    ('Firefox', RegExp(r'(?:Firefox|FxiOS)/([\d.]+)')),
    ('Chrome', RegExp(r'(?:Chrome|CriOS)/([\d.]+)')),
    ('Safari', RegExp(r'Version/([\d.]+).*Safari/')),
  ];

  static final RegExp _android = RegExp(r'Android\s+([\d.]+)?');
  static final RegExp _ios = RegExp(r'(?:iPhone|iPad|iPod).*?OS\s+([\d_]+)');
  static final RegExp _mac = RegExp(r'Mac OS X\s+([\d_.]+)');
  static final RegExp _windows = RegExp(r'Windows NT\s+([\d.]+)');
  static final RegExp _chromeOs = RegExp(r'CrOS\s+\S+\s+([\d.]+)');

  /// Parses [userAgent]. Never throws; returns an empty result for an
  /// empty or unknown string.
  static ParsedUserAgent parse(String userAgent) {
    if (userAgent.isEmpty) return const ParsedUserAgent();
    final (browserName, browserVersion) = _browser(userAgent);
    final (osName, osVersion) = _os(userAgent);
    return ParsedUserAgent(
      browserName: browserName,
      browserVersion: browserVersion,
      osName: osName,
      osVersion: osVersion,
    );
  }

  static (String?, String?) _browser(String ua) {
    for (final (name, pattern) in _browsers) {
      final match = pattern.firstMatch(ua);
      if (match != null) return (name, match.group(1));
    }
    return (null, null);
  }

  static (String?, String?) _os(String ua) {
    final ios = _ios.firstMatch(ua);
    if (ios != null) return ('iOS', _dotted(ios.group(1)));
    final android = _android.firstMatch(ua);
    if (android != null) return ('Android', android.group(1));
    final windows = _windows.firstMatch(ua);
    if (windows != null) return ('Windows', windows.group(1));
    final chromeOs = _chromeOs.firstMatch(ua);
    if (chromeOs != null) return ('ChromeOS', chromeOs.group(1));
    if (ua.contains('CrOS')) return ('ChromeOS', null);
    final mac = _mac.firstMatch(ua);
    if (mac != null) return ('macOS', _dotted(mac.group(1)));
    if (ua.contains('Macintosh')) return ('macOS', null);
    if (ua.contains('Linux') || ua.contains('X11')) return ('Linux', null);
    return (null, null);
  }

  static String? _dotted(String? raw) => raw?.replaceAll('_', '.');
}
