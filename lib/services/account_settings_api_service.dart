
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AccountSettingsApiException implements Exception {
  const AccountSettingsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountSettingsApiService {
  AccountSettingsApiService._();

  static const Duration _timeout = Duration(seconds: 12);

  static final Uri _profileUri = Uri.parse(
    '${ApiConfig.api}/profile',
  );

  static final Uri _passwordUri = Uri.parse(
    '${ApiConfig.api}/profile/password',
  );

  // ดึงวันที่เปลี่ยนรหัสผ่านล่าสุดจาก Backend
  static Future<DateTime?> getPasswordChangedAt({
    http.Client? client,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      throw const AccountSettingsApiException(
        'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
      );
    }

    late final http.Response response;

    try {
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      if (client != null) {
        response = await client
            .get(_profileUri, headers: headers)
            .timeout(_timeout);
      } else {
        response = await http
            .get(_profileUri, headers: headers)
            .timeout(_timeout);
      }
    } on TimeoutException {
      throw const AccountSettingsApiException(
        'เซิร์ฟเวอร์ตอบสนองช้า กรุณาลองใหม่',
      );
    } on http.ClientException {
      throw const AccountSettingsApiException(
        'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบเครือข่าย',
      );
    }

    final payload = _decodeResponse(response);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      final profile = payload['profile'];

      if (profile is! Map) {
        throw const AccountSettingsApiException(
          'ไม่พบข้อมูลโปรไฟล์จากเซิร์ฟเวอร์',
        );
      }

      final value = profile['passwordChangedAt'];

      // NULL หมายถึงยังไม่มีข้อมูลวันที่เปลี่ยนรหัสผ่าน
      if (value == null) {
        return null;
      }

      if (value is! String) {
        throw const AccountSettingsApiException(
          'รูปแบบวันที่เปลี่ยนรหัสผ่านไม่ถูกต้อง',
        );
      }

      final parsedDate = DateTime.tryParse(value);

      if (parsedDate == null) {
        throw const AccountSettingsApiException(
          'ไม่สามารถอ่านวันที่เปลี่ยนรหัสผ่านได้',
        );
      }

      return parsedDate.toLocal();
    }

    _throwApiError(
      payload,
      response.statusCode,
      defaultMessage: 'โหลดข้อมูลโปรไฟล์ไม่สำเร็จ',
    );
  }

  // เปลี่ยนรหัสผ่าน
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    http.Client? client,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      throw const AccountSettingsApiException(
        'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
      );
    }

    late final http.Response response;

    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

      if (client != null) {
        response = await client
            .post(
              _passwordUri,
              headers: headers,
              body: body,
            )
            .timeout(_timeout);
      } else {
        response = await http
            .post(
              _passwordUri,
              headers: headers,
              body: body,
            )
            .timeout(_timeout);
      }
    } on TimeoutException {
      throw const AccountSettingsApiException(
        'เซิร์ฟเวอร์ตอบสนองช้า กรุณาลองใหม่',
      );
    } on http.ClientException {
      throw const AccountSettingsApiException(
        'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบเครือข่าย',
      );
    }

    final payload = _decodeResponse(response);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return;
    }

    _throwApiError(
      payload,
      response.statusCode,
      defaultMessage: 'เปลี่ยนรหัสผ่านไม่สำเร็จ',
    );
  }

  // แปลง JSON response และตรวจสอบรูปแบบข้อมูล
  static Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw AccountSettingsApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง '
        '(HTTP ${response.statusCode})',
      );
    }

    if (decoded is! Map) {
      throw AccountSettingsApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง '
        '(HTTP ${response.statusCode})',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  // แปลง Error จาก Backend เป็นข้อความภาษาไทย
  static Never _throwApiError(
    Map<String, dynamic> payload,
    int statusCode, {
    required String defaultMessage,
  }) {
    final error = payload['error'];
    final errorMap = error is Map
        ? Map<String, dynamic>.from(error)
        : null;

    final code = errorMap?['code']?.toString();

    if (statusCode == 401 && code == null) {
      throw const AccountSettingsApiException(
        'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
      );
    }

    throw AccountSettingsApiException(switch (code) {
      'CURRENT_PASSWORD_INVALID' =>
        'รหัสผ่านปัจจุบันไม่ถูกต้อง',
      'INVALID_NEW_PASSWORD' =>
        'รหัสผ่านใหม่ต้องมีตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก '
            'ตัวเลข และอักขระพิเศษ โดยไม่มีช่องว่าง',
      'PASSWORD_UNCHANGED' =>
        'รหัสผ่านใหม่ต้องแตกต่างจากรหัสผ่านปัจจุบัน',
      'UNAUTHENTICATED' || 'INVALID_TOKEN' =>
        'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
      'INVALID_PASSWORD_REQUEST' =>
        'กรุณากรอกรหัสผ่านให้ครบถ้วน',
      _ => '$defaultMessage (HTTP $statusCode)',
    });
  }
}
