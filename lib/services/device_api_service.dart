
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class DeviceApiException implements Exception {
  const DeviceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeviceApiService {
  DeviceApiService._();

  static const Duration _timeout = Duration(seconds: 12);

  static const String _baseUrl = '${ApiConfig.api}/devices';

  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      throw const DeviceApiException(
        'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
      );
    }

    return token;
  }

  static Future<Map<String, dynamic>> _sendRequest({
    required String method,
    required Uri uri,
    required String token,
  }) async {
    late final http.Response response;

    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      switch (method) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(_timeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers)
              .timeout(_timeout);
          break;
        default:
          throw const DeviceApiException('ไม่รองรับคำขอนี้');
      }
    } on TimeoutException {
      throw const DeviceApiException(
        'เซิร์ฟเวอร์ตอบสนองช้า กรุณาลองใหม่',
      );
    } on http.ClientException {
      throw const DeviceApiException(
        'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบเครือข่าย',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw DeviceApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง (HTTP ${response.statusCode})',
      );
    }

    if (decoded is! Map) {
      throw DeviceApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง (HTTP ${response.statusCode})',
      );
    }

    final data = Map<String, dynamic>.from(decoded);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401) {
      throw const DeviceApiException(
        'เซสชันหมดอายุหรือถูกยกเลิก กรุณาเข้าสู่ระบบใหม่',
      );
    }

    throw DeviceApiException(
      data['message']?.toString() ??
          'ดำเนินการไม่สำเร็จ (HTTP ${response.statusCode})',
    );
  }

  static Future<List<Map<String, dynamic>>> getDevices() async {
    final token = await _getToken();

    final data = await _sendRequest(
      method: 'GET',
      uri: Uri.parse(_baseUrl),
      token: token,
    );

    final devicesData = data['devices'];

    if (devicesData is! List) {
      throw const DeviceApiException(
        'รูปแบบข้อมูลอุปกรณ์ไม่ถูกต้อง',
      );
    }

    return devicesData
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Ends the session of every other device. This device stays signed in.
  /// Returns how many devices were signed out.
  static Future<int> logoutOtherDevices() async {
    final token = await _getToken();

    final data = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('$_baseUrl/logout-others'),
      token: token,
    );

    final count = data['revokedCount'];
    return count is int ? count : 0;
  }

  /// Ends this device's session on the server (used when logging out).
  static Future<void> logoutCurrentSession() async {
    final token = await _getToken();

    await _sendRequest(
      method: 'POST',
      uri: Uri.parse('$_baseUrl/logout'),
      token: token,
    );
  }

  static Future<void> logoutDevice(String tokenId) async {
    final token = await _getToken();

    await _sendRequest(
      method: 'DELETE',
      uri: Uri.parse(
        '$_baseUrl/${Uri.encodeComponent(tokenId)}',
      ),
      token: token,
    );
  }
}
