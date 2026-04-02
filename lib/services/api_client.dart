import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'http_client_factory.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? createHttpClient();

  final http.Client _client;
  static String? _mobileSessionId;
  static const Duration _requestTimeout = Duration(seconds: 12);

  Uri _buildUri(String path) {
    return Uri.parse('${AppConstants.apiBaseUrl}$path');
  }

  Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (!kIsWeb) {
      final sessionId = _mobileSessionId;
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

    final sessionId = _mobileSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }

    return {'Authorization': 'Bearer $sessionId'};
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _runWithTimeout(
      () => _client.get(_buildUri(path), headers: _headers()),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _runWithTimeout(
      () => _client.post(
        _buildUri(path),
        headers: _headers(),
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
      () => _client.put(
        _buildUri(path),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await _runWithTimeout(
      () => _client.delete(_buildUri(path), headers: _headers()),
    );
    return _parseResponse(response);
  }

  static void clearMobileSession() {
    _mobileSessionId = null;
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

  Map<String, dynamic> _parseResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(response.body) as Map<String, dynamic>);

    if (!kIsWeb) {
      final sessionId = decoded['session_id'];
      if (sessionId is String && sessionId.isNotEmpty) {
        _mobileSessionId = sessionId;
      } else if (response.statusCode == 401) {
        _mobileSessionId = null;
      }
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        decoded['error']?.toString() ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}
