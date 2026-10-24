import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Fields of the avatar the user is wearing. Keys match the backend
/// (`GET/PUT /api/profile/avatar`) and the fields of `AvatarProfile`.
class AvatarData {
  const AvatarData({
    required this.gender,
    required this.skinIndex,
    required this.hairStyle,
    required this.hairColorIndex,
    required this.outfitIndex,
    required this.glasses,
    required this.hat,
    required this.clip,
    required this.earring,
    required this.neck,
    required this.extra,
  });

  final String gender;
  final int skinIndex;
  final int hairStyle;
  final int hairColorIndex;
  final int outfitIndex;
  final int glasses;
  final int hat;
  final int clip;
  final int earring;
  final int neck;
  final int extra;

  Map<String, Object> toJson() => <String, Object>{
    'gender': gender,
    'skinIndex': skinIndex,
    'hairStyle': hairStyle,
    'hairColorIndex': hairColorIndex,
    'outfitIndex': outfitIndex,
    'glasses': glasses,
    'hat': hat,
    'clip': clip,
    'earring': earring,
    'neck': neck,
    'extra': extra,
  };

  factory AvatarData.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final value = json[key];
      if (value is int && value >= 0) return value;
      if (value is num && value >= 0 && value == value.roundToDouble()) {
        return value.toInt();
      }
      throw FormatException('Invalid avatar field $key');
    }

    final gender = json['gender'];
    if (gender != 'male' && gender != 'female') {
      throw const FormatException('Invalid avatar gender');
    }
    return AvatarData(
      gender: gender as String,
      skinIndex: readInt('skinIndex'),
      hairStyle: readInt('hairStyle'),
      hairColorIndex: readInt('hairColorIndex'),
      outfitIndex: readInt('outfitIndex'),
      glasses: readInt('glasses'),
      hat: readInt('hat'),
      clip: readInt('clip'),
      earring: readInt('earring'),
      neck: readInt('neck'),
      extra: readInt('extra'),
    );
  }
}

class AvatarApiException implements Exception {
  const AvatarApiException(this.message, {this.code, this.fields = const []});

  final String message;
  final String? code;

  /// For `AVATAR_ITEM_NOT_OWNED`: which avatar fields hold items the user
  /// has not bought (e.g. `outfitIndex`, `hat`).
  final List<String> fields;

  /// True when the request never got a usable answer (offline, timeout,
  /// server down). The change should be kept locally and retried later.
  bool get isRetryable =>
      code == 'NETWORK_ERROR' ||
      code == 'TIMEOUT' ||
      code == 'INVALID_RESPONSE' ||
      code == 'SERVER_ERROR';

  @override
  String toString() => message;
}

class AvatarApiService {
  AvatarApiService._();

  static const Duration _timeout = Duration(seconds: 12);
  static final Uri _avatarUri = Uri.parse(
    '${ApiConfig.api}/profile/avatar',
  );

  /// The avatar saved on the server, or `null` if this user never saved one.
  static Future<AvatarData?> getAvatar() async {
    final json = await _request('GET');
    final avatar = json['avatar'];
    if (avatar == null) return null;
    return _parse(avatar);
  }

  /// Saves [avatar] and returns what the server stored.
  static Future<AvatarData> saveAvatar(AvatarData avatar) async {
    final json = await _request('PUT', body: avatar.toJson());
    final saved = _parse(json['avatar']);
    if (saved == null) {
      throw const AvatarApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลอวตารไม่ถูกต้อง',
        code: 'INVALID_RESPONSE',
      );
    }
    return saved;
  }

  static AvatarData? _parse(dynamic value) {
    if (value is! Map) return null;
    try {
      return AvatarData.fromJson(Map<String, dynamic>.from(value));
    } on FormatException {
      throw const AvatarApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลอวตารไม่ถูกต้อง',
        code: 'INVALID_RESPONSE',
      );
    }
  }

  static Future<Map<String, dynamic>> _request(
    String method, {
    Map<String, Object>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      throw const AvatarApiException(
        'กรุณาเข้าสู่ระบบใหม่',
        code: 'UNAUTHENTICATED',
      );
    }

    late final http.Response response;
    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      if (body != null) headers['Content-Type'] = 'application/json';
      response =
          method == 'PUT'
              ? await http
                  .put(_avatarUri, headers: headers, body: jsonEncode(body))
                  .timeout(_timeout)
              : await http.get(_avatarUri, headers: headers).timeout(_timeout);
    } on TimeoutException {
      throw const AvatarApiException(
        'เชื่อมต่อใช้เวลานานเกินไป กรุณาลองอีกครั้ง',
        code: 'TIMEOUT',
      );
    } on http.ClientException {
      throw const AvatarApiException(
        'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบเครือข่าย',
        code: 'NETWORK_ERROR',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    final json =
        decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};

    if (response.statusCode == 401) {
      throw const AvatarApiException(
        'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
        code: 'UNAUTHENTICATED',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final errorMap = error is Map ? Map<String, dynamic>.from(error) : null;
      final code = errorMap?['code']?.toString();
      final rawFields = errorMap?['fields'];
      final fields =
          rawFields is List ? rawFields.whereType<String>().toList() : <String>[];
      throw AvatarApiException(
        switch (code) {
          'AVATAR_ITEM_NOT_OWNED' => 'คุณยังไม่ได้ปลดล็อกไอเทมบางชิ้น',
          _ => 'บันทึกอวตารไม่สำเร็จ (HTTP ${response.statusCode})',
        },
        code: response.statusCode >= 500 ? 'SERVER_ERROR' : code,
        fields: fields,
      );
    }
    if (decoded is! Map) {
      throw AvatarApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง (HTTP ${response.statusCode})',
        code: 'INVALID_RESPONSE',
      );
    }
    return json;
  }
}
