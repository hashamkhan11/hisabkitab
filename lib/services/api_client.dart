import 'dart:convert';

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
    final response = await http.get(_uri(path, query), headers: await _headers());
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final response = await http.post(
      _uri(path),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final response = await http.patch(
      _uri(path),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(_uri(path), headers: await _headers());
    return _decode(response);
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
