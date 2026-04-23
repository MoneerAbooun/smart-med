import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_med/core/config/app_config.dart';

class ApiClientException implements Exception {
  const ApiClientException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Uri _buildUri(String path) {
    final baseUri = Uri.parse(AppConfig.apiBaseUrl);
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.resolve(normalizedPath);
  }

  Future<Map<String, dynamic>> postJson({
    required String path,
    required Map<String, dynamic> body,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await _httpClient.post(
      _buildUri(path),
      headers: <String, String>{
        'Content-Type': 'application/json',
        ...headers,
      },
      body: jsonEncode(body),
    );

    Map<String, dynamic>? parsedBody;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          parsedBody = decoded;
        } else if (decoded is Map) {
          parsedBody = Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        parsedBody = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail =
          parsedBody?['detail']?.toString() ??
          'Request failed with status ${response.statusCode}.';
      throw ApiClientException(detail, statusCode: response.statusCode);
    }

    if (parsedBody == null) {
      throw const ApiClientException('The API returned an empty response.');
    }

    return parsedBody;
  }
}
