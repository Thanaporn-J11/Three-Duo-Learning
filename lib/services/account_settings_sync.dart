import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'lesson_progress.dart';
import 'parent_pin.dart';
import 'screen_time_guard.dart';
import 'user_account_preferences.dart';

/// Keeps the account's settings on the server (GET/PUT /api/settings) so
/// they come back after reinstalling the app or on another phone:
/// - parent controls (daily time limit, eye rest, downtime)
/// - check-in reminder (on/off + time)
/// - parent PIN (only its salted hash)
///
/// The phone keeps using its own copy (SharedPreferences), so everything
/// still works offline. A change made offline is marked "to send" and sent
/// on the next [pull]; the server copy is only taken when nothing is
/// waiting to be sent. A group the server has never received is uploaded
/// from the phone instead (settings made before this existed).
class AccountSettingsSync {
  AccountSettingsSync._();

  static const Duration _timeout = Duration(seconds: 8);
  static const String _controls = 'controls';
  static const String _reminder = 'reminder';
  static const String _pin = 'pin';
  static Future<void>? _pulling;

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return token == null || token.isEmpty ? null : token;
  }

  static Future<String?> _pendingKey(String group) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('settings_pending_$group', userId);
  }

  static Future<void> _setPending(String group, bool on) async {
    final key = await _pendingKey(group);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (on) {
      await prefs.setBool(key, true);
    } else {
      await prefs.remove(key);
    }
  }

  static Future<bool> _isPending(String group) async {
    final key = await _pendingKey(group);
    if (key == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  static String _hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  /// PUT the given fields; true when the server saved them.
  static Future<bool> _put(Map<String, dynamic> body) async {
    try {
      final token = await _token();
      if (token == null) return false;
      final response = await http
          .put(
            Uri.parse('${ApiConfig.api}/settings'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      // 400 = the server will never take it; don't keep retrying.
      return response.statusCode == 200 || response.statusCode == 400;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _push(String group, Map<String, dynamic> body) async {
    if (await UserAccountPreferences.currentUserId() == null) return;
    await _setPending(group, true);
    if (await _put(body)) await _setPending(group, false);
  }

  // ---------------- what is sent ----------------

  static Future<Map<String, dynamic>> _controlsBody() async {
    final p = await SharedPreferences.getInstance();
    final limit = p.getInt(ScreenTimeGuard.kLimitMinutes) ?? 30;
    return {
      'screenTimeEnabled': p.getBool(ScreenTimeGuard.kLimitEnabled) ?? false,
      'dailyTimeLimitMinutes': const [15, 30, 45, 60].contains(limit) ? limit : 30,
      'eyeRestReminderEnabled': p.getBool(ScreenTimeGuard.kEyeRestEnabled) ?? true,
      'downtimeEnabled': p.getBool(ScreenTimeGuard.kDowntimeEnabled) ?? false,
      'downtimeStart': _hhmm(
        p.getInt(ScreenTimeGuard.kDowntimeStartH) ?? 20,
        p.getInt(ScreenTimeGuard.kDowntimeStartM) ?? 0,
      ),
      'downtimeEnd': _hhmm(
        p.getInt(ScreenTimeGuard.kDowntimeEndH) ?? 7,
        p.getInt(ScreenTimeGuard.kDowntimeEndM) ?? 0,
      ),
    };
  }

  static Future<Map<String, dynamic>?> _reminderBody() async {
    final userId = await UserAccountPreferences.currentUserId();
    if (userId == null) return null;
    final p = await SharedPreferences.getInstance();
    String key(String base) => UserAccountPreferences.keyFor(base, userId);
    return {
      'notificationsEnabled':
          p.getBool(key('notif_enabled')) ?? p.getBool('notif_enabled') ?? true,
      'reminderHour': p.getInt(key('notif_hour')) ?? p.getInt('notif_hour') ?? 20,
      'reminderMinute':
          p.getInt(key('notif_minute')) ?? p.getInt('notif_minute') ?? 0,
    };
  }

  static Future<Map<String, dynamic>> _pinBody() async {
    final stored = await ParentPin.storedHash();
    return {'pinHash': stored?.hash, 'pinSalt': stored?.salt};
  }

  /// Call after the parent changed a time control.
  static Future<void> pushControls() async => _push(_controls, await _controlsBody());

  /// Call after the check-in reminder was changed.
  static Future<void> pushReminder() async {
    final body = await _reminderBody();
    if (body != null) await _push(_reminder, body);
  }

  /// Call after the PIN was set or removed.
  static Future<void> pushPin() async => _push(_pin, await _pinBody());

  // ---------------- what is taken from the server ----------------

  static int? _hour(String? t) => int.tryParse((t ?? '').split(':').first);
  static int? _minute(String? t) {
    final parts = (t ?? '').split(':');
    return parts.length > 1 ? int.tryParse(parts[1]) : null;
  }

  static Future<void> _applyControls(Map s) async {
    final p = await SharedPreferences.getInstance();
    if (s['screenTimeEnabled'] is bool) {
      await p.setBool(ScreenTimeGuard.kLimitEnabled, s['screenTimeEnabled'] as bool);
    }
    if (s['dailyTimeLimitMinutes'] is int) {
      await p.setInt(ScreenTimeGuard.kLimitMinutes, s['dailyTimeLimitMinutes'] as int);
    }
    if (s['eyeRestReminderEnabled'] is bool) {
      await p.setBool(ScreenTimeGuard.kEyeRestEnabled, s['eyeRestReminderEnabled'] as bool);
    }
    if (s['downtimeEnabled'] is bool) {
      await p.setBool(ScreenTimeGuard.kDowntimeEnabled, s['downtimeEnabled'] as bool);
    }
    final sh = _hour(s['downtimeStart']?.toString());
    final sm = _minute(s['downtimeStart']?.toString());
    final eh = _hour(s['downtimeEnd']?.toString());
    final em = _minute(s['downtimeEnd']?.toString());
    if (sh != null && sm != null) {
      await p.setInt(ScreenTimeGuard.kDowntimeStartH, sh);
      await p.setInt(ScreenTimeGuard.kDowntimeStartM, sm);
    }
    if (eh != null && em != null) {
      await p.setInt(ScreenTimeGuard.kDowntimeEndH, eh);
      await p.setInt(ScreenTimeGuard.kDowntimeEndM, em);
    }
  }

  static Future<void> _applyReminder(Map s) async {
    final userId = await UserAccountPreferences.currentUserId();
    if (userId == null) return;
    final p = await SharedPreferences.getInstance();
    String key(String base) => UserAccountPreferences.keyFor(base, userId);
    if (s['notificationsEnabled'] is bool) {
      await p.setBool(key('notif_enabled'), s['notificationsEnabled'] as bool);
    }
    if (s['reminderHour'] is int) await p.setInt(key('notif_hour'), s['reminderHour'] as int);
    if (s['reminderMinute'] is int) {
      await p.setInt(key('notif_minute'), s['reminderMinute'] as int);
    }
  }

  /// Sends what is waiting, then takes the server's settings. Also brings
  /// back where lessons were left off. Called at app start and after login.
  static Future<void> pull() {
    final running = _pulling;
    if (running != null) return running;
    final future = _pull().whenComplete(() => _pulling = null);
    _pulling = future;
    return future;
  }

  static Future<void> _pull() async {
    try {
      final token = await _token();
      if (token == null || await UserAccountPreferences.currentUserId() == null) return;

      if (await _isPending(_controls)) await pushControls();
      if (await _isPending(_reminder)) await pushReminder();
      if (await _isPending(_pin)) await pushPin();

      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/settings'),
            headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final s = body is Map ? body['settings'] : null;
        if (s is Map) {
          if (!await _isPending(_controls)) {
            if (s['controlsSaved'] == true) {
              await _applyControls(s);
            } else {
              await pushControls();
            }
          }
          if (!await _isPending(_reminder)) {
            if (s['reminderSaved'] == true) {
              await _applyReminder(s);
            } else {
              await pushReminder();
            }
          }
          if (!await _isPending(_pin)) {
            if (s['pinSaved'] == true) {
              final hash = s['pinHash'];
              final salt = s['pinSalt'];
              await ParentPin.applyFromServer(
                hash is String ? hash : null,
                salt is String ? salt : null,
              );
            } else if (await ParentPin.storedHash() != null) {
              await pushPin();
            }
          }
          unawaited(ScreenTimeGuard.instance.checkNow());
        }
      }
    } catch (_) {
      // Offline: the phone's copy keeps working.
    }
    await LessonProgress.sync();
  }
}
