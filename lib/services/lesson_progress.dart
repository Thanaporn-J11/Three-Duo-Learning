import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'user_account_preferences.dart';

/// Where a child stopped in a lesson (a "ฟังเสียงเติมคำ" topic, the
/// "ฟังแยกเสียงคำศัพท์" game, a vocabulary category, ...), per account and
/// per lesson id, so they can continue from that question.
///
/// Saved on the phone and on the server (/api/lesson-progress), so the
/// place is kept after reinstalling the app or on another phone. The newer
/// change wins. Saved on the phone as "index:correct:updatedMs"; a finished
/// lesson is kept as "-1:0:updatedMs" so an older server copy can't bring
/// it back.
class LessonProgress {
  LessonProgress._();

  static const Duration _timeout = Duration(seconds: 8);
  static Future<void>? _flushing;

  static Future<String> _key(String topicId) async {
    final base = 'lesson_progress_$topicId';
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? base : UserAccountPreferences.keyFor(base, userId);
  }

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('lesson_sync_queue', userId);
  }

  /// (index, correct, updatedMs) from the phone, or null.
  static ({int index, int correct, int updatedMs})? _parse(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2 && parts.length != 3) return null;
    final index = int.tryParse(parts[0]);
    final correct = int.tryParse(parts[1]);
    final at = parts.length == 3 ? int.tryParse(parts[2]) : 0;
    if (index == null || correct == null || at == null) return null;
    return (index: index, correct: correct, updatedMs: at);
  }

  /// Saved position, or null when the topic hasn't been started (or was
  /// finished). [index] is the 0-based question to continue from.
  static Future<({int index, int correct})?> load(
    String topicId,
    int totalQuestions,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = _parse(prefs.getString(await _key(topicId)));
      if (saved == null) return null;
      final index = saved.index;
      final correct = saved.correct;
      // Ignore anything that no longer fits the topic (e.g. questions changed).
      if (index <= 0 || index >= totalQuestions) return null;
      if (correct < 0 || correct > index) return null;
      return (index: index, correct: correct);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String topicId, int index, int correct) =>
      _write(topicId, index, correct);

  /// The lesson was finished or restarted: nothing to continue.
  static Future<void> clear(String topicId) => _write(topicId, null, null);

  static Future<void> _write(String topicId, int? index, int? correct) async {
    final at = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        await _key(topicId),
        '${index ?? -1}:${correct ?? 0}:${at.millisecondsSinceEpoch}',
      );
      final queueKey = await _queueKey();
      if (queueKey == null) return;
      final queue = _readQueue(prefs.getString(queueKey));
      queue[topicId] = {
        'index': index,
        'correct': correct,
        'updatedAt': at.toUtc().toIso8601String(),
      };
      await prefs.setString(queueKey, jsonEncode(queue));
    } catch (_) {}
    unawaited(flush());
  }

  static Map<String, Map<String, dynamic>> _readQueue(String? raw) {
    if (raw == null) return {};
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return {};
      return {
        for (final e in j.entries)
          if (e.key is String && e.value is Map)
            e.key as String: Map<String, dynamic>.from(e.value as Map),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return token == null || token.isEmpty ? null : token;
  }

  /// Sends positions saved while offline.
  static Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    final future = _flush().whenComplete(() => _flushing = null);
    _flushing = future;
    return future;
  }

  static Future<void> _flush() async {
    try {
      final queueKey = await _queueKey();
      final token = await _token();
      if (queueKey == null || token == null) return;
      final prefs = await SharedPreferences.getInstance();
      final queue = _readQueue(prefs.getString(queueKey));
      for (final entry in queue.entries) {
        final int status;
        try {
          status = (await http
                  .put(
                    Uri.parse(
                      '${ApiConfig.api}/lesson-progress/${Uri.encodeComponent(entry.key)}',
                    ),
                    headers: {
                      'Accept': 'application/json',
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token',
                    },
                    body: jsonEncode(entry.value),
                  )
                  .timeout(_timeout))
              .statusCode;
        } catch (_) {
          return; // offline
        }
        if (status == 200 || status == 400) {
          final now = _readQueue(prefs.getString(queueKey));
          if (jsonEncode(now[entry.key]) == jsonEncode(entry.value)) {
            now.remove(entry.key);
            await prefs.setString(queueKey, jsonEncode(now));
          }
        } else {
          return;
        }
      }
    } catch (_) {}
  }

  /// Sends local changes, then takes anything newer from the server.
  static Future<void> sync() async {
    await flush();
    try {
      final token = await _token();
      final queueKey = await _queueKey();
      if (token == null || queueKey == null) return;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/lesson-progress'),
            headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final topics = body is Map ? body['topics'] : null;
      if (topics is! Map) return;
      final prefs = await SharedPreferences.getInstance();
      final unsent = _readQueue(prefs.getString(queueKey));
      for (final e in topics.entries) {
        final topicId = e.key;
        final server = e.value;
        if (topicId is! String || server is! Map) continue;
        if (unsent.containsKey(topicId)) continue; // the phone's change is newer
        final at = DateTime.tryParse(server['updatedAt']?.toString() ?? '');
        if (at == null) continue;
        final key = await _key(topicId);
        final local = _parse(prefs.getString(key));
        if (local != null && local.updatedMs >= at.millisecondsSinceEpoch) continue;
        final index = server['index'];
        final correct = server['correct'];
        await prefs.setString(
          key,
          index is int && correct is int
              ? '$index:$correct:${at.millisecondsSinceEpoch}'
              : '-1:0:${at.millisecondsSinceEpoch}',
        );
      }
    } catch (_) {}
  }
}
