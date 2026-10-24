import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'user_account_preferences.dart';

/// Remembers which vocabulary words the child has gone through and sends
/// them to the server (POST /api/vocabulary/progress/batch), so the parent
/// report can show "คำศัพท์ที่เรียนแล้ว". Words are identified by category
/// slug + English term, which works for both the server word list and the
/// built-in one. Offline words are queued per account and sent later.
class VocabularyProgress {
  VocabularyProgress._();

  static const Duration _timeout = Duration(seconds: 12);
  static const int _batchSize = 50;
  static const int _maxQueued = 600;
  static Future<void>? _flushing;

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('vocab_progress_queue', userId);
  }

  /// The child moved past [term] in [categorySlug] (e.g. 'fruit', 'Apple').
  static Future<void> markLearned(String categorySlug, String term) async {
    final cleanTerm = term.trim();
    if (cleanTerm.isEmpty) return;
    try {
      final key = await _queueKey();
      if (key == null) return; // not signed in
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(key) ?? <String>[];
      final entry = jsonEncode({'categorySlug': categorySlug, 'term': cleanTerm});
      if (!queue.contains(entry)) queue.add(entry);
      final trimmed =
          queue.length > _maxQueued
              ? queue.sublist(queue.length - _maxQueued)
              : queue;
      await prefs.setStringList(key, trimmed);
    } catch (_) {}
    unawaited(flush());
  }

  // ---------- category status (dots on the category list) ----------

  /// The child went through every word of [categorySlug] (on this phone).
  static Future<void> markCategoryDone(String categorySlug) async {
    try {
      final userId = await UserAccountPreferences.currentUserId();
      if (userId == null) return;
      final key = UserAccountPreferences.keyFor('vocab_done_categories', userId);
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getStringList(key) ?? <String>[];
      if (!done.contains(categorySlug)) {
        done.add(categorySlug);
        await prefs.setStringList(key, done);
      }
    } catch (_) {}
  }

  static Future<Set<String>> doneCategories() async {
    try {
      final userId = await UserAccountPreferences.currentUserId();
      if (userId == null) return {};
      final key = UserAccountPreferences.keyFor('vocab_done_categories', userId);
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(key) ?? const <String>[]).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Learned words per category from the server (GET /api/vocabulary/progress),
  /// so progress made on another phone counts too. Empty when offline.
  static Future<Map<String, int>> learnedCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return {};
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/vocabulary/progress'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return {};
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final rows = body is Map ? body['progress'] : null;
      if (rows is! List) return {};
      final counts = <String, int>{};
      for (final row in rows) {
        if (row is Map && row['status'] == 'learned' && row['category_slug'] is String) {
          final slug = row['category_slug'] as String;
          counts[slug] = (counts[slug] ?? 0) + 1;
        }
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  /// Sends everything queued for the signed-in account, 50 words at a time.
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
      var queue = List<String>.from(prefs.getStringList(key) ?? const []);
      while (queue.isNotEmpty) {
        final batch = queue.take(_batchSize).toList();
        final int status;
        try {
          final response = await http
              .post(
                Uri.parse('${ApiConfig.api}/vocabulary/progress/batch'),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({'items': batch.map(jsonDecode).toList()}),
              )
              .timeout(_timeout);
          status = response.statusCode;
        } catch (_) {
          break; // offline / server down: try again next time
        }
        if (status == 200 || status == 400) {
          // 400 = never accepted; drop it instead of retrying forever.
          // Re-read so words added meanwhile are kept.
          final current = List<String>.from(prefs.getStringList(key) ?? const []);
          current.removeWhere(batch.contains);
          await prefs.setStringList(key, current);
          queue = current;
        } else {
          break; // 401 / 5xx: keep for later
        }
      }
    } catch (_) {}
  }
}
