import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'user_account_preferences.dart';

/// Sends results of the listening games to the server
/// (POST /api/listening/results). No coins; they show up in the parent
/// report. Results made while offline are queued on the device (per account)
/// and sent the next time, with the time they were played.
class ListeningResults {
  ListeningResults._();

  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxQueued = 500;
  static Future<void>? _flushing;

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('listening_results_queue', userId);
  }

  /// [game]: `minimal_pairs`, `fill_blank` (with [score]/[total]) or
  /// `karaoke` (with [durationSeconds]). [topic]: topic/song id.
  static Future<void> submit({
    required String game,
    String? topic,
    int? score,
    int? total,
    int? durationSeconds,
  }) async {
    try {
      final key = await _queueKey();
      if (key == null) return; // not signed in
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(key) ?? <String>[];
      queue.add(
        jsonEncode({
          'game': game,
          if (topic != null) 'topic': topic,
          if (score != null) 'score': score,
          if (total != null) 'total': total,
          if (durationSeconds != null) 'durationSeconds': durationSeconds,
          'playedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      // Keep the newest results if the device stays offline for a long time.
      final trimmed =
          queue.length > _maxQueued
              ? queue.sublist(queue.length - _maxQueued)
              : queue;
      await prefs.setStringList(key, trimmed);
    } catch (_) {}
    await flush();
  }

  /// Sends everything queued for the signed-in account.
  static Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    final future = _flush().whenComplete(() => _flushing = null);
    _flushing = future;
    return future;
  }

  static Future<void> _flush() async {
    try {
      final key = await _queueKey();
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return;
      while (true) {
        // Read the queue each time: a new result may be added while sending.
        final queue = List<String>.from(prefs.getStringList(key) ?? const []);
        if (queue.isEmpty) break;
        final int status;
        try {
          final response = await http
              .post(
                Uri.parse('${ApiConfig.api}/listening/results'),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: queue.first,
              )
              .timeout(_timeout);
          status = response.statusCode;
        } catch (_) {
          break; // offline / server down: try again next time
        }
        if (status == 201 || status == 400) {
          // 400 = the server will never accept it; don't retry forever.
          // Remove only the result that was sent, from the queue as it is now.
          final latest = List<String>.from(prefs.getStringList(key) ?? const []);
          latest.remove(queue.first);
          await prefs.setStringList(key, latest);
        } else {
          break; // 401 / 5xx: keep it for later
        }
      }
    } catch (_) {}
  }
}
