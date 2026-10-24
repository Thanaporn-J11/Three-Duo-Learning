import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'user_account_preferences.dart';

/// Which phonics cards the child has practiced (flipped to hear the word, or
/// moved past). Kept on the phone per account for the ticks in the app, and
/// sent to the server (POST /api/phonics/progress) for the parent report.
/// A card is identified by its category id ('01'..'06') + sample word.
class PhonicsProgress {
  PhonicsProgress._();

  static const Duration _timeout = Duration(seconds: 12);
  static const int _batchSize = 50;
  static Future<void>? _flushing;

  static Future<String?> _key(String base) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor(base, userId);
  }

  static String _id(String categoryId, String word) => '$categoryId|$word';

  /// All practiced cards of the signed-in account, as 'categoryId|word'.
  static Future<Set<String>> practiced() async {
    try {
      final key = await _key('phonics_done');
      if (key == null) return <String>{};
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(key) ?? const <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static bool isDone(Set<String> practiced, String categoryId, String word) =>
      practiced.contains(_id(categoryId, word));

  static int countFor(Set<String> practiced, String categoryId) =>
      practiced.where((id) => id.startsWith('$categoryId|')).length;

  static Future<void> markPracticed(String categoryId, String word) async {
    try {
      final doneKey = await _key('phonics_done');
      final queueKey = await _key('phonics_queue');
      if (doneKey == null || queueKey == null) return; // not signed in
      final id = _id(categoryId, word);
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getStringList(doneKey) ?? <String>[];
      if (done.contains(id)) return; // already counted
      done.add(id);
      await prefs.setStringList(doneKey, done);
      final queue = prefs.getStringList(queueKey) ?? <String>[];
      if (!queue.contains(id)) queue.add(id);
      await prefs.setStringList(queueKey, queue);
    } catch (_) {}
    unawaited(flush());
  }

  /// Pulls the server's list (e.g. on a new phone) into the local ticks and
  /// sends anything still queued.
  static Future<void> sync() async {
    await flush();
    try {
      final doneKey = await _key('phonics_done');
      if (doneKey == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/phonics/progress'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final list = body is Map ? body['progress'] : null;
      if (list is! List) return;
      final done = (prefs.getStringList(doneKey) ?? <String>[]).toSet();
      for (final item in list) {
        if (item is Map &&
            item['categoryId'] is String &&
            item['word'] is String) {
          done.add(_id(item['categoryId'] as String, item['word'] as String));
        }
      }
      await prefs.setStringList(doneKey, done.toList());
    } catch (_) {}
  }

  static Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    final future = _flush().whenComplete(() => _flushing = null);
    _flushing = future;
    return future;
  }

  static Future<void> _flush() async {
    try {
      final queueKey = await _key('phonics_queue');
      if (queueKey == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return;
      var queue = List<String>.from(prefs.getStringList(queueKey) ?? const []);
      while (queue.isNotEmpty) {
        final batch = queue.take(_batchSize).toList();
        final items = <Map<String, String>>[];
        for (final id in batch) {
          final sep = id.indexOf('|');
          if (sep > 0) {
            items.add({
              'categoryId': id.substring(0, sep),
              'word': id.substring(sep + 1),
            });
          }
        }
        final int status;
        try {
          final response = await http
              .post(
                Uri.parse('${ApiConfig.api}/phonics/progress'),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({'items': items}),
              )
              .timeout(_timeout);
          status = response.statusCode;
        } catch (_) {
          break; // offline: try again next time
        }
        if (status == 200 || status == 400) {
          final current =
              List<String>.from(prefs.getStringList(queueKey) ?? const []);
          current.removeWhere(batch.contains);
          await prefs.setStringList(queueKey, current);
          queue = current;
        } else {
          break;
        }
      }
    } catch (_) {}
  }
}
