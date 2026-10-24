import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'user_account_preferences.dart';

enum SessionStatus {
  /// Signed in and the server confirmed it (token renewed).
  signedIn,

  /// Signed in on this phone, but the server couldn't be reached
  /// (no internet / server down). The app opens anyway.
  offline,

  /// Not signed in, or the server ended the session.
  signedOut,
}

/// Keeps the child signed in between app launches.
class SessionService {
  SessionService._();

  static const Duration _timeout = Duration(seconds: 8);

  /// Called when the app opens. Uses the token saved at sign-in and asks the
  /// server for a renewed one (POST /api/session/refresh), so the sign-in
  /// lasts as long as the app is used at least once every 60 days.
  static Future<SessionStatus> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return SessionStatus.signedOut;

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${ApiConfig.api}/session/refresh'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
    } catch (_) {
      return SessionStatus.offline;
    }

    if (response.statusCode == 200) {
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final fresh = body is Map ? body['token'] : null;
        if (fresh is String && fresh.isNotEmpty) {
          await prefs.setString('jwt_token', fresh);
        }
      } catch (_) {}
      return SessionStatus.signedIn;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      // Expired, or "ออกจากระบบในอุปกรณ์อื่นทั้งหมด" was used elsewhere.
      await UserAccountPreferences.clearLocalSession();
      return SessionStatus.signedOut;
    }

    // 5xx etc.: the server has a problem, not the sign-in. Let them in.
    return SessionStatus.offline;
  }
}
