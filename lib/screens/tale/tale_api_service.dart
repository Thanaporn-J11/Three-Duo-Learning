import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

/// API helper for tale reading progress and favorite tales.
/// Uses the JWT saved under SharedPreferences key `jwt_token`.
/// Backend address comes from ApiConfig (lib/config/api_config.dart).
class TaleApiService {
  TaleApiService._();

  static const String _baseUrl = '${ApiConfig.api}/tale';

  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      throw Exception('ไม่พบ Token กรุณาเข้าสู่ระบบใหม่');
    }
    return token;
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    final dynamic decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      throw Exception(
        decoded['message']?.toString() ??
            'เรียก API ไม่สำเร็จ (${response.statusCode})',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('เรียก API ไม่สำเร็จ (${response.statusCode})');
    }
    return <String, dynamic>{};
  }

  /// GET /api/tale/progress
  static Future<List<Map<String, dynamic>>> getProgress() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/progress'),
      headers: await _authHeaders(),
    );
    final data = _decodeResponse(response);
    final items = data['progress'];
    if (items is! List) return <Map<String, dynamic>>[];

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// POST /api/tale/progress. Sentence index is zero-based.
  static Future<void> saveProgress({
    required String taleId,
    required int currentSentenceIndex,
    int? currentVideoPositionMs,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/progress'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'taleId': taleId,
        'currentSentenceIndex': currentSentenceIndex,
        if (currentVideoPositionMs != null)
          'currentVideoPositionMs': currentVideoPositionMs,
      }),
    );
    _decodeResponse(response);
  }

  /// GET /api/tale/favorites
  static Future<Set<String>> getFavorites() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/favorites'),
      headers: await _authHeaders(),
    );
    final data = _decodeResponse(response);
    final items = data['favorites'];
    if (items is! List) return <String>{};

    return items
        .whereType<Map>()
        .map((item) => item['tale_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  /// POST /api/tale/favorites
  static Future<void> addFavorite(String taleId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/favorites'),
      headers: await _authHeaders(),
      body: jsonEncode({'taleId': taleId}),
    );
    _decodeResponse(response);
  }

  /// DELETE /api/tale/favorites/:taleId
  static Future<void> removeFavorite(String taleId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/favorites/${Uri.encodeComponent(taleId)}'),
      headers: await _authHeaders(),
    );
    _decodeResponse(response);
  }
}
