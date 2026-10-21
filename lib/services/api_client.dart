import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import '../config/app_configuration.dart';
import 'http_client_factory.dart';
import 'platform_credential_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? responseBody;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  ApiClient({
    http.Client? client,
    CredentialStore? credentials,
    AppConfiguration? configuration,
  }) : _client = client ?? createHttpClient(),
       _credentials = credentials ?? PlatformCredentialStore(),
       configuration = configuration ?? AppConfiguration.environment;

  final http.Client _client;
  final CredentialStore _credentials;
  final AppConfiguration configuration;
  String get apiBaseUrl => configuration.apiBaseUrl;
  static const _sessionCredentialKey = 'taiwan_brawl.session_id';
  String? _sessionCache;
  static const Duration _requestTimeout = Duration(seconds: 12);

  Uri _buildUri(String path) {
    return Uri.parse('$apiBaseUrl$path');
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (!kIsWeb) {
      final sessionId =
          _sessionCache ?? await _credentials.read(_sessionCredentialKey);
      if (sessionId != null && sessionId.isNotEmpty) {
        _sessionCache = sessionId;
      }
      if (sessionId != null && sessionId.isNotEmpty) {
        headers['Authorization'] = 'Bearer $sessionId';
      }
    }
    return headers;
  }

  Map<String, dynamic>? webSocketHeaders() {
    if (kIsWeb) {
      return null;
    }

    final sessionId = _sessionCache;
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }

    return {'Authorization': 'Bearer $sessionId'};
  }

  Future<Map<String, dynamic>?> loadWebSocketHeaders() async {
    if (!kIsWeb && _sessionCache == null) {
      final sessionId = await _credentials.read(_sessionCredentialKey);
      if (sessionId != null && sessionId.isNotEmpty) {
        _sessionCache = sessionId;
      }
    }
    return webSocketHeaders();
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _runWithTimeout(
      () async => _client.get(_buildUri(path), headers: await _headers()),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _runWithTimeout(
      () async => _client.post(
        _buildUri(path),
        headers: await _headers(),
        body: jsonEncode(body),
      ),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _runWithTimeout(
      () async => _client.put(
        _buildUri(path),
        headers: await _headers(),
        body: jsonEncode(body),
      ),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await _runWithTimeout(
      () async => _client.delete(_buildUri(path), headers: await _headers()),
    );
    return _parseResponse(response);
  }

  Future<void> postRaw(String path, String body) async {
    final response = await _runWithTimeout(
      () async =>
          _client.post(_buildUri(path), headers: await _headers(), body: body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Request failed', statusCode: response.statusCode);
    }
  }

  Future<String> getRaw(String path) async {
    final response = await _runWithTimeout(
      () async => _client.get(_buildUri(path), headers: await _headers()),
    );
    if (response.statusCode == 404) {
      throw ApiException('No data available', statusCode: 404);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Request failed', statusCode: response.statusCode);
    }
    return response.body;
  }

  /// Kept for source compatibility with older callers.
  ///
  /// Session state is now scoped to each [ApiClient] instance, so there is no
  /// process-wide cache to clear. Call [clearSession] on the owning client to
  /// clear both its memory cache and durable credential.
  @Deprecated('Session cache is instance-scoped; use clearSession() instead')
  static void clearMobileSession() {}

  Future<void> clearSession() async {
    _sessionCache = null;
    await _credentials.delete(_sessionCredentialKey);
  }

  Future<http.Response> _runWithTimeout(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiException('Request timed out');
    }
  }

  Future<Map<String, dynamic>> _parseResponse(http.Response response) async {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(response.body) as Map<String, dynamic>);

    if (!kIsWeb) {
      final sessionId = decoded['session_id'];
      if (sessionId is String && sessionId.isNotEmpty) {
        _sessionCache = sessionId;
        await _credentials.write(_sessionCredentialKey, sessionId);
      } else if (response.statusCode == 401) {
        await clearSession();
      }
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        decoded['error']?.toString() ?? 'Request failed',
        statusCode: response.statusCode,
        responseBody: decoded,
      );
    }
    return decoded;
  }
}
