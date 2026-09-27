/// Default [HttpClientPort] adapter over `package:http`
/// (infrastructure layer).
///
/// Uses no `dart:io` API, so it runs on every platform. On Flutter web
/// `http.Client()` resolves to `BrowserClient` (a `fetch`/XHR POST that the
/// browser subjects to CORS); on native targets it resolves to `IOClient`.
library;

import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/ports/http_client_port.dart';
import 'package:flutter_umami_analytics/src/domain/utils/json_helpers.dart';
import 'package:flutter_umami_analytics/src/infrastructure/http/http_headers.dart';

/// Posts Umami payloads with `package:http` and keeps the `x-umami-cache`
/// session token between requests.
class DefaultHttpClient implements HttpClientPort {
  static const _kHttpOk = HttpStatus.ok;
  static const _kBodySnippetMax = 200;
  static const _kCacheHeader = HttpHeaderNames.cacheControl;
  static const _kCacheBodyField = 'cache';

  final http.Client _client;
  final bool _ownsClient;
  final UmamiLogger _logger;
  final Duration _timeout;
  final Map<String, String> _baseHeaders;
  String? _lastCacheToken;

  /// Builds the adapter.
  ///
  /// [client] is reused (and not closed on [dispose]) when given; otherwise
  /// the adapter creates and owns an `http.Client()`. [timeout] bounds each
  /// POST (default 5 s). [userAgent] replaces the default native UA; it is
  /// ignored on web, where the browser sends its own UA.
  DefaultHttpClient({
    http.Client? client,
    required UmamiLogger logger,
    Duration timeout = const Duration(seconds: 5),
    String? userAgent,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _logger = logger,
        _timeout = timeout,
        _baseHeaders = buildBaseHeaders(userAgent: userAgent);

  @override
  Future<bool> send(String endpoint, Map<String, dynamic> body) async {
    final stopwatch = Stopwatch()..start();
    try {
      final headers = _buildHeaders();
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode != _kHttpOk) {
        _logNon200(endpoint, response);
        return false;
      }

      _storeCacheToken(response);
      return true;
    } on http.ClientException catch (e) {
      _logError(endpoint, 'Network', e.message, stopwatch.elapsedMilliseconds);
      return false;
    } on TimeoutException catch (e) {
      _logError(endpoint, 'Timeout', '$e', stopwatch.elapsedMilliseconds);
      return false;
    } on Exception catch (e) {
      final kind = e is FormatException ? 'Encoding' : 'Request';
      _logError(endpoint, kind, '$e', stopwatch.elapsedMilliseconds,
          severe: true);
      return false;
    } finally {
      stopwatch.stop();
    }
  }

  @override
  String? get cacheToken => _lastCacheToken;

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  // Umami returns the session token in the `x-umami-cache` header (older
  // servers) or as `{"cache": "..."}` in the body (current servers). On web
  // the header is only visible when the server exposes it via CORS, so the
  // body is the reliable source there.
  void _storeCacheToken(http.Response response) {
    final header = response.headers[_kCacheHeader];
    if (header != null && header.isNotEmpty) {
      _lastCacheToken = header;
      return;
    }
    final body = decodeJsonObject(response.body);
    final fromBody = body?[_kCacheBodyField];
    if (fromBody is String && fromBody.isNotEmpty) _lastCacheToken = fromBody;
  }

  Map<String, String> _buildHeaders() {
    final token = _lastCacheToken;
    if (token == null) return _baseHeaders;
    return <String, String>{..._baseHeaders, _kCacheHeader: token};
  }

  void _logError(
    String endpoint,
    String kind,
    String message,
    int elapsedMs, {
    bool severe = false,
  }) {
    final formatted = '$kind error on $endpoint after ${elapsedMs}ms: $message';
    if (severe) {
      _logger.error(formatted);
    } else {
      _logger.warning(formatted);
    }
  }

  void _logNon200(String endpoint, http.Response response) {
    final body = response.body;
    final snippet = body.length > _kBodySnippetMax
        ? '${body.substring(0, _kBodySnippetMax)}…'
        : body;
    _logger.warning('POST $endpoint -> ${response.statusCode}: $snippet');
  }
}
