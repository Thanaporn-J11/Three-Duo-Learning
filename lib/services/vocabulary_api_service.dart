import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vocabulary_category.dart';
import '../models/vocabulary_word.dart';
import '../config/api_config.dart';

class VocabularyApiException implements Exception {
  const VocabularyApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VocabularyApiService {
  VocabularyApiService._();

  static const Duration _timeout = Duration(seconds: 12);
  static final Uri _baseUri = Uri.parse(
    '${ApiConfig.api}/vocabulary/',
  );

  /// These public vocabulary endpoints do not require or receive a JWT.
  static Future<List<VocabularyCategory>> getCategories() async {
    final list = await _getList('categories', 'categories');
    try {
      return list.map(VocabularyCategory.fromJson).toList(growable: false);
    } on FormatException {
      throw const VocabularyApiException(
        'รูปแบบข้อมูลหมวดคำศัพท์จากเซิร์ฟเวอร์ไม่ถูกต้อง',
      );
    }
  }

  /// Fetches words for a category slug, preserving the API-provided order.
  static Future<List<VocabularyWord>> getWords(String slug) async {
    final path = 'categories/${Uri.encodeComponent(slug)}/words';
    final list = await _getList(path, 'words');
    try {
      return list.map(VocabularyWord.fromJson).toList(growable: false);
    } on FormatException {
      throw const VocabularyApiException(
        'รูปแบบข้อมูลคำศัพท์จากเซิร์ฟเวอร์ไม่ถูกต้อง',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> _getList(
    String path,
    String field,
  ) async {
    late final http.Response response;
    try {
      response = await http
          .get(
            _baseUri.resolve(path),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const VocabularyApiException(
        'การเชื่อมต่อใช้เวลานานเกินไป กรุณาลองอีกครั้ง',
      );
    } on http.ClientException {
      throw const VocabularyApiException(
        'เชื่อมต่อบริการคำศัพท์ไม่ได้ กรุณาตรวจสอบเครือข่าย',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VocabularyApiException(
          _serverMessage(response.body) ??
              'โหลดข้อมูลคำศัพท์ไม่สำเร็จ (HTTP ${response.statusCode})',
        );
      }
      throw const VocabularyApiException(
        'รูปแบบข้อมูลคำศัพท์จากเซิร์ฟเวอร์ไม่ถูกต้อง',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VocabularyApiException(
        _serverMessageFromJson(decoded) ??
            'โหลดข้อมูลคำศัพท์ไม่สำเร็จ (HTTP ${response.statusCode})',
      );
    }

    if (decoded is! Map<String, dynamic> || decoded[field] is! List) {
      throw VocabularyApiException(
        'รูปแบบข้อมูลคำศัพท์ไม่ถูกต้อง: ไม่พบรายการ "$field"',
      );
    }

    final values = decoded[field] as List<dynamic>;
    try {
      return values.map((value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('List item is not an object');
        }
        return value;
      }).toList(growable: false);
    } on FormatException {
      throw const VocabularyApiException(
        'รูปแบบรายการคำศัพท์จากเซิร์ฟเวอร์ไม่ถูกต้อง',
      );
    }
  }

  static String? _serverMessage(String body) {
    try {
      return _serverMessageFromJson(jsonDecode(body));
    } on FormatException {
      return null;
    }
  }

  static String? _serverMessageFromJson(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    return null;
  }
}
