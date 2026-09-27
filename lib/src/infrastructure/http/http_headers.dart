/// HTTP header names, content types, status codes and base header sets
/// (infrastructure layer).
library;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter_umami_analytics/src/infrastructure/device/user_agent_service.dart';

class HttpHeaderNames {
  const HttpHeaderNames._();

  static const contentType = 'Content-Type';
  static const accept = 'Accept';
  static const userAgent = 'User-Agent';
  static const authorization = 'Authorization';
  static const cacheControl = 'x-umami-cache';
}

class HttpContentType {
  const HttpContentType._();

  static const json = 'application/json';
}

class HttpStatus {
  const HttpStatus._();

  static const ok = 200;
  static const created = 201;
  static const noContent = 204;
}

/// Builds the headers sent with every request.
///
/// [includeUserAgent] defaults to `true` on native targets and `false` on
/// Flutter web: browsers own the `User-Agent` header (a page cannot set
/// it) and a custom value would only add a CORS preflight header. On web
/// the result holds `Content-Type` and `Accept` only, which Umami's CORS
/// policy for `/api/send` accepts. [userAgent] overrides the default UA
/// from [UserAgentService.defaultUserAgent].
Map<String, String> buildBaseHeaders({
  String? userAgent,
  String contentType = HttpContentType.json,
  String accept = HttpContentType.json,
  bool includeUserAgent = !kIsWeb,
}) {
  return <String, String>{
    HttpHeaderNames.contentType: contentType,
    HttpHeaderNames.accept: accept,
    if (includeUserAgent)
      HttpHeaderNames.userAgent: userAgent ?? UserAgentService.defaultUserAgent,
  };
}

Map<String, String> composeAuthHeaders(
  Map<String, String> base,
  String? token,
) {
  if (token == null) return base;
  return <String, String>{
    ...base,
    HttpHeaderNames.authorization: 'Bearer $token',
  };
}
