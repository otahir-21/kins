import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/secure_storage_service.dart';

/// Thrown when the backend returns 401. Token is cleared; app should redirect to login.
class BackendUnauthorizedException implements Exception {
  BackendUnauthorizedException([this.message]);
  final String? message;
  @override
  String toString() => message ?? 'Unauthorized';
}

/// Thrown when the backend returns an error with a body message.
class BackendApiException implements Exception {
  BackendApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

/// Set by router/splash so that on 401 we can redirect to login.
bool shouldRedirectToLogin = false;

/// Set from main/app_router so that on 401 we immediately navigate to login (e.g. appRouter.go(routePhoneAuth)).
void Function()? onUnauthorized;

/// REST client for backend API (MongoDB). Base URL: [AppConstants.apiV1BaseUrl].
/// Adds Authorization: Bearer <JWT> for protected routes. On 401, clears token and sets [shouldRedirectToLogin].
class BackendApiClient {
  BackendApiClient._();

  static String get _baseUrl => AppConstants.apiV1BaseUrl;

  static String? get _token => SecureStorageService.getJwtTokenSync();

  static Map<String, String> _headers({bool auth = true}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final t = _token;
      if (t != null && t.isNotEmpty) {
        map['Authorization'] = 'Bearer $t';
      }
    }
    return map;
  }

  static Future<void> _on401() async {
    await SecureStorageService.deleteJwt();
    shouldRedirectToLogin = true;
    onUnauthorized?.call();
  }

  static Future<void> _checkResponse(http.Response response) async {
    if (response.statusCode == 401) {
      await _on401();
      throw BackendUnauthorizedException();
    }
    if (response.statusCode >= 400) {
      String msg = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          msg = (decoded['error'] ?? decoded['message'])?.toString() ?? msg;
        }
      } catch (_) {}
      throw BackendApiException(response.statusCode, msg);
    }
  }

  /// POST [path] with optional [body]. If [useAuth] is true (default), adds Bearer token.
  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool useAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final resp = await http.post(
      uri,
      headers: _headers(auth: useAuth),
      body: body != null ? jsonEncode(body) : null,
    );
    await _checkResponse(resp);
    if (resp.body.isEmpty) return {};
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// POST [path] with multipart/form-data. If [useAuth] is true (default), adds Bearer token.
  static Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
    bool useAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    
    // Add authorization header if needed
    if (useAuth) {
      final t = _token;
      if (t != null && t.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $t';
      }
    }
    
    // Add fields
    if (fields != null) {
      request.fields.addAll(fields);
    }
    
    // Add files if provided
    if (files != null) {
      request.files.addAll(files);
    }
    
    final streamedResponse = await request.send();
    final resp = await http.Response.fromStream(streamedResponse);
    
    await _checkResponse(resp);
    if (resp.body.isEmpty) return {};
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// GET [path]. If [useAuth] is true (default), adds Bearer token.
  static Future<Map<String, dynamic>> get(
    String path, {
    bool useAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final resp = await http.get(uri, headers: _headers(auth: useAuth));
    await _checkResponse(resp);
    if (resp.body.isEmpty) return {};
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// GET [path] returning a list.
  static Future<List<dynamic>> getList(
    String path, {
    bool useAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final resp = await http.get(uri, headers: _headers(auth: useAuth));
    await _checkResponse(resp);
    if (resp.body.isEmpty) return [];
    final decoded = jsonDecode(resp.body);
    if (decoded is List) return decoded;
    return [];
  }

  /// PUT [path] with [body].
  static Future<Map<String, dynamic>> put(
    String path, {
    required Map<String, dynamic> body,
    bool useAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final resp = await http.put(
      uri,
      headers: _headers(auth: useAuth),
      body: jsonEncode(body),
    );
    await _checkResponse(resp);
    if (resp.body.isEmpty) return {};
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// DELETE [path]. If [useAuth] is true (default), adds Bearer token.
  static Future<Map<String, dynamic>> delete(
    String path, {
    bool useAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final resp = await http.delete(uri, headers: _headers(auth: useAuth));
    await _checkResponse(resp);
    if (resp.body.isEmpty) return {};
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
