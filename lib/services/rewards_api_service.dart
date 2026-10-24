import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class RewardsApiException implements Exception {
  const RewardsApiException(
    this.message, {
    this.code,
    this.balance,
    this.price,
  });

  final String message;
  final String? code;
  final int? balance;
  final int? price;

  @override
  String toString() => message;
}

class AvatarPurchases {
  const AvatarPurchases({required this.balance, required this.itemKeys});

  final int balance;
  final Set<String> itemKeys;
}

class AvatarPurchaseResult {
  const AvatarPurchaseResult({
    required this.itemKey,
    required this.price,
    required this.balance,
    required this.itemKeys,
  });

  final String itemKey;
  final int price;
  final int balance;
  final Set<String> itemKeys;
}

class RewardsApiService {
  RewardsApiService._();

  static const Duration _timeout = Duration(seconds: 12);
  static const String _baseUrl = '${ApiConfig.api}/rewards';

  static Future<int> getBalance() async {
    final json = await _request('balance');
    return _readBalance(json['balance']);
  }

  static Future<AvatarPurchases> getAvatarPurchases() async {
    final json = await _request('avatar-purchases');
    final keys = _readItemKeys(json['itemKeys']);
    return AvatarPurchases(
      balance: _readBalance(json['balance']),
      itemKeys: keys,
    );
  }

  static Future<AvatarPurchaseResult> purchaseAvatar(String itemKey) async {
    final json = await _request(
      'avatar-purchases',
      method: 'POST',
      body: {'itemKey': itemKey},
    );
    final purchase = json['purchase'];
    if (purchase is! Map || purchase['itemKey'] != itemKey) {
      throw const RewardsApiException('รูปแบบผลการซื้อ Avatar จากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }
    return AvatarPurchaseResult(
      itemKey: itemKey,
      price: _readBalance(purchase['price']),
      balance: _readBalance(json['balance']),
      itemKeys: _readItemKeys(json['itemKeys']),
    );
  }

  static Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      throw const RewardsApiException(
        'ไม่พบข้อมูลเข้าสู่ระบบ กรุณาเข้าสู่ระบบใหม่',
        code: 'UNAUTHENTICATED',
      );
    }

    final uri = Uri.parse('$_baseUrl/$path');
    late final http.Response response;
    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      if (body != null) headers['Content-Type'] = 'application/json';
      final requestBody = body == null ? null : jsonEncode(body);
      response = method == 'POST'
          ? await http
              .post(uri, headers: headers, body: requestBody)
              .timeout(_timeout)
          : await http.get(uri, headers: headers).timeout(_timeout);
    } on TimeoutException {
      throw const RewardsApiException(
        'เชื่อมต่อใช้เวลานานเกินไป กรุณาลองอีกครั้ง',
        code: 'TIMEOUT',
      );
    } on http.ClientException {
      throw const RewardsApiException(
        'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบเครือข่าย',
        code: 'NETWORK_ERROR',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw RewardsApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง (HTTP ${response.statusCode})',
        code: 'INVALID_RESPONSE',
      );
    }
    if (decoded is! Map) {
      throw RewardsApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง (HTTP ${response.statusCode})',
        code: 'INVALID_RESPONSE',
      );
    }
    final json = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final errorMap = error is Map ? Map<String, dynamic>.from(error) : null;
      final code = errorMap?['code']?.toString();
      final balance = _tryReadInteger(errorMap?['balance']);
      final price = _tryReadInteger(errorMap?['price']);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const RewardsApiException(
          'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
          code: 'UNAUTHENTICATED',
        );
      }
      final message = switch (code) {
        'INSUFFICIENT_COINS' => 'Coins ไม่เพียงพอสำหรับไอเทมนี้',
        'AVATAR_ALREADY_OWNED' => 'คุณมี Avatar ชิ้นนี้แล้ว',
        'INVALID_AVATAR_ITEM' => 'ไม่พบ Avatar ที่เลือก',
        _ => 'ทำรายการไม่สำเร็จ (HTTP ${response.statusCode})',
      };
      throw RewardsApiException(
        message,
        code: code,
        balance: balance,
        price: price,
      );
    }
    return json;
  }

  static int _readBalance(dynamic value) {
    final balance = _tryReadInteger(value);
    if (balance == null || balance < 0) {
      throw const RewardsApiException(
        'รูปแบบยอด Coins จากเซิร์ฟเวอร์ไม่ถูกต้อง',
        code: 'INVALID_RESPONSE',
      );
    }
    return balance;
  }

  static int? _tryReadInteger(dynamic value) {
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Set<String> _readItemKeys(dynamic value) {
    if (value is! List || value.any((item) => item is! String)) {
      throw const RewardsApiException(
        'รูปแบบรายการ Avatar จากเซิร์ฟเวอร์ไม่ถูกต้อง',
        code: 'INVALID_RESPONSE',
      );
    }
    return value.cast<String>().toSet();
  }
}
