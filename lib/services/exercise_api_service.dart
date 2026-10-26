import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_attempt.dart';
import '../config/api_config.dart';
import 'user_account_preferences.dart';

class ExerciseApiException implements Exception {
  const ExerciseApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class ExerciseApiService {
  ExerciseApiService._();

  static const Duration _timeout = Duration(seconds: 15);
  static final Uri _baseUri = Uri.parse('${ApiConfig.api}/exercises/');

  static String newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// How long the server keeps a started quiz open (15 minutes); a little
  /// less here so we never offer a quiz that has just expired.
  static const Duration pendingLifetime = Duration(minutes: 14);

  static Future<String> _pendingKey(String categorySlug) async {
    final base = 'quiz_pending_$categorySlug';
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? base : UserAccountPreferences.keyFor(base, userId);
  }

  /// The idempotency key of the quiz this account started for the category
  /// and has not finished. Starting with the same key gives back the same
  /// questions (with the answers already given), so a child who left in the
  /// middle can continue. A new key is made (and saved) when there is none
  /// or the saved one is too old.
  static Future<String> idempotencyKeyFor(String categorySlug) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _pendingKey(categorySlug);
    final saved = _parsePending(prefs.getString(key));
    if (saved != null &&
        DateTime.now().difference(saved.savedAt) < pendingLifetime) {
      return saved.idempotencyKey;
    }
    final fresh = newIdempotencyKey();
    await prefs.setString(
      key,
      '$fresh|${DateTime.now().millisecondsSinceEpoch}',
    );
    return fresh;
  }

  /// True when the account has a quiz for the category that was started
  /// recently and not finished.
  static Future<bool> hasPendingQuiz(String categorySlug) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _parsePending(prefs.getString(await _pendingKey(categorySlug)));
    return saved != null &&
        DateTime.now().difference(saved.savedAt) < pendingLifetime;
  }

  /// The quiz was finished, or has expired: nothing to continue.
  static Future<void> clearPendingQuiz(String categorySlug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _pendingKey(categorySlug));
  }

  static ({String idempotencyKey, DateTime savedAt})? _parsePending(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 2) return null;
    final ms = int.tryParse(parts[1]);
    if (ms == null || parts[0].isEmpty) return null;
    return (
      idempotencyKey: parts[0],
      savedAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  static Future<ExerciseAttempt> startAttempt({
    required String categorySlug,
    required String idempotencyKey,
  }) async {
    final json = await _request(
      'attempts',
      method: 'POST',
      body: {'idempotencyKey': idempotencyKey, 'categorySlug': categorySlug},
    );
    return _parseAttempt(json);
  }

  static Future<ExerciseAttempt> getAttempt(String attemptId) async {
    final json = await _request('attempts/${Uri.encodeComponent(attemptId)}');
    return _parseAttempt(json);
  }

  static Future<ExerciseAnswerResult> submitAnswer({
    required String attemptId,
    required String questionId,
    required String optionId,
  }) async {
    final json = await _request(
      'attempts/${Uri.encodeComponent(attemptId)}/answers',
      method: 'POST',
      body: {'questionId': questionId, 'optionId': optionId},
    );
    try {
      return ExerciseAnswerResult.fromJson(json);
    } on FormatException {
      throw const ExerciseApiException('รูปแบบผลตรวจคำตอบจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }
  }

  static Future<ExerciseSubmitResult> submitAttempt(String attemptId) async {
    final json = await _request(
      'attempts/${Uri.encodeComponent(attemptId)}/submit',
      method: 'POST',
      body: const {},
    );
    try {
      return ExerciseSubmitResult.fromJson(json);
    } on FormatException {
      throw const ExerciseApiException('รูปแบบผลคะแนนจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }
  }

  static ExerciseAttempt _parseAttempt(Map<String, dynamic> json) {
    try {
      return ExerciseAttempt.fromResponse(json);
    } on FormatException {
      throw const ExerciseApiException('รูปแบบข้อมูลแบบทดสอบจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }
  }

  static Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      throw const ExerciseApiException(
        'ไม่พบ Token กรุณาเข้าสู่ระบบใหม่',
        code: 'UNAUTHENTICATED',
        statusCode: 401,
      );
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    late final http.Response response;
    try {
      final uri = _baseUri.resolve(path);
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(await request.send()).timeout(_timeout);
    } on TimeoutException {
      throw const ExerciseApiException('การเชื่อมต่อใช้เวลานานเกินไป กรุณาลองอีกครั้ง');
    } on http.ClientException {
      throw const ExerciseApiException('เชื่อมต่อบริการแบบทดสอบไม่ได้ กรุณาตรวจสอบเครือข่าย');
    }

    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } on FormatException {
      throw ExerciseApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map) {
      throw ExerciseApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    final json = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final errorMap = error is Map ? Map<String, dynamic>.from(error) : null;
      final code = errorMap?['code']?.toString();
      final message = switch (code) {
        'QUIZ_NOT_AVAILABLE' => 'หมวดนี้ยังไม่มีแบบทดสอบที่พร้อมใช้งาน',
        'ATTEMPT_EXPIRED' => 'แบบทดสอบหมดเวลาแล้ว กรุณาเริ่มใหม่',
        'ANSWERS_INCOMPLETE' => 'ยังตอบคำถามไม่ครบทุกข้อ',
        'ANSWER_ALREADY_RECORDED' => 'คำตอบข้อนี้ถูกบันทึกไปแล้ว',
        _ when response.statusCode == 401 => 'เซสชันหมดอายุหรือไม่ถูกต้อง กรุณาเข้าสู่ระบบใหม่',
        _ => errorMap?['message']?.toString() ??
            json['message']?.toString() ??
            'เรียก API ไม่สำเร็จ (${response.statusCode})',
      };
      throw ExerciseApiException(
        message,
        code: code,
        statusCode: response.statusCode,
      );
    }
    return json;
  }
}
