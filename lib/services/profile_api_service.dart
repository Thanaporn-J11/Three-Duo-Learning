import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ProfileApiException implements Exception {
  const ProfileApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileData {
  const ProfileData({
    required this.name,
    required this.email,
    this.phone,
    this.createdAt,
  });

  final String name;
  final String email;
  final String? phone;
  final DateTime? createdAt;

  factory ProfileData.fromResponse(Map<String, dynamic> json) {
    final profile = json['profile'];
    if (profile is! Map) {
      throw const FormatException('Missing profile object');
    }

    final data = Map<String, dynamic>.from(profile);
    final name = data['name'];
    final email = data['email'];
    final rawCreatedAt = data['createdAt'];
    final rawPhone = data['phone'];
    if (name is! String || name.trim().isEmpty ||
        email is! String || email.trim().isEmpty) {
      throw const FormatException('Invalid profile name or email');
    }

    DateTime? createdAt;
    if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreatedAt);
      if (createdAt == null) {
        throw const FormatException('Invalid profile createdAt');
      }
    } else if (rawCreatedAt != null) {
      throw const FormatException('Invalid profile createdAt');
    }

    return ProfileData(
      name: name.trim(),
      email: email.trim(),
      phone:
          rawPhone is String && rawPhone.trim().isNotEmpty
              ? rawPhone.trim()
              : null,
      createdAt: createdAt,
    );
  }
}

class ProfileApiService {
  ProfileApiService._();

  static const Duration _timeout = Duration(seconds: 12);
  static final Uri _profileUri =
      Uri.parse('${ApiConfig.api}/profile');

  static Future<ProfileData> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      throw const ProfileApiException('กรุณาเข้าสู่ระบบใหม่');
    }

    late final http.Response response;
    try {
      response = await http.get(
        _profileUri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);
    } on TimeoutException {
      throw const ProfileApiException('เชื่อมต่อใช้เวลานานเกินไป กรุณาลองอีกครั้ง');
    } on http.ClientException {
      throw const ProfileApiException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบเครือข่าย');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ProfileApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลโปรไฟล์ไม่ถูกต้อง (HTTP ${response.statusCode})',
      );
    }
    if (decoded is! Map) {
      throw ProfileApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลโปรไฟล์ไม่ถูกต้อง (HTTP ${response.statusCode})',
      );
    }

    final json = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final errorMap = error is Map ? Map<String, dynamic>.from(error) : null;
      final code = errorMap?['code']?.toString();
      final message = switch (code) {
        'PROFILE_NOT_FOUND' => 'ไม่พบข้อมูลโปรไฟล์ของบัญชีนี้',
        'UNAUTHENTICATED' || 'INVALID_TOKEN' => 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
        _ => 'โหลดข้อมูลโปรไฟล์ไม่สำเร็จ (HTTP ${response.statusCode})',
      };
      throw ProfileApiException(message);
    }

    try {
      return ProfileData.fromResponse(json);
    } on FormatException {
      throw const ProfileApiException('รูปแบบข้อมูลโปรไฟล์จากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }
  }

  /// Updates the signed-in user's name and phone (`PATCH /api/profile`).
  /// Pass `phone: null` to remove the phone number.
  static Future<ProfileData> updateProfile({
    required String name,
    required String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      throw const ProfileApiException('กรุณาเข้าสู่ระบบใหม่');
    }

    late final http.Response response;
    try {
      response = await http
          .patch(
            _profileUri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'name': name, 'phone': phone}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const ProfileApiException('เชื่อมต่อใช้เวลานานเกินไป กรุณาลองอีกครั้ง');
    } on http.ClientException {
      throw const ProfileApiException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบเครือข่าย');
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
      throw const ProfileApiException('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final code = error is Map ? error['code']?.toString() : null;
      throw ProfileApiException(switch (code) {
        'INVALID_NAME' => 'กรุณากรอกชื่อ',
        'INVALID_PHONE' => 'เบอร์โทรศัพท์ไม่ถูกต้อง',
        'PROFILE_NOT_FOUND' => 'ไม่พบข้อมูลโปรไฟล์ของบัญชีนี้',
        _ => 'บันทึกข้อมูลไม่สำเร็จ (HTTP ${response.statusCode})',
      });
    }

    try {
      return ProfileData.fromResponse(json);
    } on FormatException {
      throw const ProfileApiException('รูปแบบข้อมูลโปรไฟล์จากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }
  }
}
