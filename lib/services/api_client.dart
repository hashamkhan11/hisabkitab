import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Thrown for any non-2xx response from the API. [statusCode] lets callers
/// special-case things like 401 (force logout) or 404 (treat as "not found")
/// the same way they already special-case FirebaseException codes.
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

/// Thrown when a request can't reach the server at all - timed out, or the
/// device has no usable connection. Distinct from [ApiException] (a real
/// HTTP error response) so callers/UI can tell "server said no" apart from
/// "never got an answer" and show a retry-able "you're offline" message.
class ApiConnectionException implements Exception {
  final String message;

  ApiConnectionException([this.message = 'No internet connection. Please try again.']);

  @override
  String toString() => message;
}

const _requestTimeout = Duration(seconds: 12);

/// Thin wrapper around `http` that points every call at the Laravel backend,
/// attaches the current Firebase ID token, and decodes JSON responses.
///
/// Callers keep the same `try { ... } catch (_) {}` resilience style already
/// used throughout the app for Firestore calls - this client throws
/// [ApiException] (or a network error) on failure rather than swallowing it
/// itself, so that existing call sites' own try/catch keeps working unchanged.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  /// Override at build/run time with `--dart-define=API_BASE_URL=http://...`.
  /// Defaults to the Android-emulator loopback alias for the local
  /// `php artisan serve` backend, since that's the only target reachable
  /// without device-specific configuration in this environment.
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  /// The public host that ledger-invite links and shared deep links point
  /// at - must match the backend's `APP_URL` (and the Android manifest's
  /// registered `https` intent-filter host) so an invite actually opens the
  /// app instead of a dead link. Override with `--dart-define=SHARE_LINK_BASE_URL=...`.
  static const String shareLinkBaseUrl = String.fromEnvironment(
    'SHARE_LINK_BASE_URL',
    defaultValue: 'https://hisabshare.projects.ranksol.net',
  );

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$normalized').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final response = await _guard(
      () async => http.get(_uri(path, query), headers: await _headers()),
    );
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final response = await _guard(
      () async => http.post(
        _uri(path),
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final response = await _guard(
      () async => http.patch(
        _uri(path),
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _guard(
      () async => http.delete(_uri(path), headers: await _headers()),
    );
    return _decode(response);
  }

  /// Applies a fixed timeout to every request and translates connection-level
  /// failures (timeout, DNS failure, socket error) into [ApiConnectionException]
  /// so callers can distinguish "couldn't reach the server" from a real HTTP
  /// error response, instead of an unhandled low-level exception.
  Future<http.Response> _guard(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiConnectionException();
    } on SocketException {
      throw ApiConnectionException();
    } on HttpException {
      throw ApiConnectionException();
    }
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = 'Request failed (${response.statusCode}).';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } catch (_) {
      // Non-JSON error body (e.g. a raw 500 HTML page) - keep the generic message.
    }
    throw ApiException(message, response.statusCode);
  }
}
