import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'screen_time_guard.dart';
import 'user_account_preferences.dart';

/// Copies the app time counted on this phone to the server
/// (PUT /api/usage) and reads the total back (GET /api/usage), so the
/// "เวลาใช้งานแอป 7 วันล่าสุด" chart survives reinstalling the app and adds
/// up every phone the child uses.
class AppUsageSync {
  AppUsageSync._();

  static const Duration _timeout = Duration(seconds: 8);
  static const int _daysToSend = 14;
  static Future<void>? _flushing;

  /// Today's seconds on the account's other phones (from the server), with
  /// the day it is for. Used so the daily time limit counts every phone.
  static ({String day, int seconds})? _othersToday;

  /// Seconds the child used today on other phones (0 if unknown/offline).
  static int othersTodaySeconds([DateTime? now]) {
    final cached = _othersToday;
    if (cached == null || cached.day != _day(now ?? DateTime.now())) return 0;
    return cached.seconds;
  }

  /// A random id for this installation of the app (not per account).
  /// Reinstalling makes a new one, so the old phone's days stay counted.
  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_install_id');
    if (saved != null && saved.length >= 8) return saved;
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final id = List.generate(24, (_) => chars[random.nextInt(chars.length)]).join();
    await prefs.setString('app_install_id', id);
    return id;
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return token == null || token.isEmpty ? null : token;
  }

  /// Sends this phone's totals of the last two weeks (only days with use).
  static Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    final future = _flush().whenComplete(() => _flushing = null);
    _flushing = future;
    return future;
  }

  static Future<void> _flush() async {
    try {
      final token = await _token();
      if (token == null || await UserAccountPreferences.currentUserId() == null) return;
      final local = await ScreenTimeGuard.usageLastDays(_daysToSend);
      final days = {
        for (final u in local)
          if (u.seconds > 0) _day(u.day): u.seconds.clamp(0, 86400),
      };
      if (days.isNotEmpty) {
        await http
          .put(
            Uri.parse('${ApiConfig.api}/usage'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'deviceId': await deviceId(), 'days': days}),
          )
          .timeout(_timeout);
      }
      await _loadOthersToday(token);
    } catch (_) {
      // Offline: the phone keeps counting and sends again later.
    }
  }

  static Future<void> _loadOthersToday(String token) async {
    final today = _day(DateTime.now());
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.api}/usage/today-others?deviceId=${await deviceId()}',
          ),
          headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return;
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final seconds = body is Map ? body['seconds'] : null;
    if (seconds is int) _othersToday = (day: today, seconds: seconds);
  }

  /// Forget the other phones' time (another account signs in).
  static void reset() => _othersToday = null;

  /// Seconds per day for the last [days] days (oldest first, today last):
  /// all phones from the server, or this phone only when offline.
  static Future<List<({DateTime day, int seconds})>> lastDays(int days) async {
    final local = await ScreenTimeGuard.usageLastDays(days);
    try {
      await flush();
      final token = await _token();
      if (token == null) return local;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/usage?days=$days'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return local;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final list = body is Map ? body['days'] : null;
      if (list is! List) return local;
      final server = <String, int>{
        for (final e in list)
          if (e is Map && e['day'] is String && e['seconds'] is int)
            e['day'] as String: e['seconds'] as int,
      };
      // Server total, but never less than what this phone counted (in case
      // the last few minutes weren't sent yet).
      return [
        for (final u in local)
          (day: u.day, seconds: max(u.seconds, server[_day(u.day)] ?? 0)),
      ];
    } catch (_) {
      return local;
    }
  }
}
