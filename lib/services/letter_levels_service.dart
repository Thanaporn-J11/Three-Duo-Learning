import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'coin_balance.dart';
import 'guess_progress_service.dart' show GuessCoinResult;
import 'user_account_preferences.dart';

/// Stars per level of the "พยัญชนะต้น" game, per account, on the phone and on
/// the server (/api/games/letter/...), so they survive reinstalling the app
/// and follow the child to another phone. Coins are given per word (see
/// [LetterCoins]), not per level.
class LetterLevels {
  LetterLevels._();

  static const int levelCount = 20;
  static const Duration _timeout = Duration(seconds: 6);
  static const List<String> folders = [
    'animals', 'fruits', 'careers', 'sports', 'vehicles', 'places',
  ];
  static Future<void>? _flushing;

  static Future<String?> _key(String base) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor(base, userId);
  }

  static List<int> _parse(String? raw) {
    final result = List<int>.filled(levelCount, 0);
    if (raw == null || raw.isEmpty) return result;
    final parts = raw.split(',');
    for (int i = 0; i < levelCount && i < parts.length; i++) {
      result[i] = (int.tryParse(parts[i]) ?? 0).clamp(0, 3).toInt();
    }
    return result;
  }

  /// Stars of the 20 levels of [folder] for the signed-in account.
  static Future<List<int>> load(String folder) async {
    try {
      await _claimOldStars();
      final key = await _key('letter_stars_$folder');
      if (key == null) return List<int>.filled(levelCount, 0);
      final prefs = await SharedPreferences.getInstance();
      return _parse(prefs.getString(key));
    } catch (_) {
      return List<int>.filled(levelCount, 0);
    }
  }

  static Future<void> _saveLocal(String folder, List<int> stars) async {
    final key = await _key('letter_stars_$folder');
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, stars.join(','));
  }

  /// Stars saved by the old version (on the phone, for nobody in particular)
  /// go to the first account that opens the game here, and are sent to the
  /// server as "imported" (recorded, no coins: they earned pretend coins).
  static Future<void> _claimOldStars() async {
    final userId = await UserAccountPreferences.currentUserId();
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final doneKey = UserAccountPreferences.keyFor('letter_old_stars_checked', userId);
    if (prefs.getBool(doneKey) ?? false) return;
    await prefs.setBool(doneKey, true);
    if (!await UserAccountPreferences.claimLegacyData('letter_old_stars_owner', userId)) {
      return;
    }
    for (final folder in folders) {
      final old = _parse(prefs.getString('letter_game_stars_$folder'));
      if (old.every((s) => s == 0)) continue;
      final key = UserAccountPreferences.keyFor('letter_stars_$folder', userId);
      final mine = _parse(prefs.getString(key));
      for (int i = 0; i < levelCount; i++) {
        if (old[i] > mine[i]) mine[i] = old[i];
      }
      await prefs.setString(key, mine.join(','));
      for (int i = 0; i < levelCount; i++) {
        if (old[i] > 0) {
          await _enqueue({
            'category': folder,
            'level': i + 1,
            'stars': old[i],
            'imported': true,
          });
        }
      }
    }
  }

  /// The level was played with [stars] (0 = not passed). Keeps the best
  /// stars, here and on the server.
  static Future<void> record(String folder, int level, int stars) async {
    final current = await load(folder);
    if (stars > current[level - 1]) {
      current[level - 1] = stars;
      await _saveLocal(folder, current);
    }
    final body = {'category': folder, 'level': level, 'stars': stars};
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return;
      final response = await _post(token, jsonEncode(body));
      if (response.statusCode == 200) {
        unawaited(flush());
      } else if (response.statusCode >= 500) {
        await _enqueue(body);
      }
    } catch (_) {
      await _enqueue(body); // offline: sent later
    }
  }

  static Future<http.Response> _post(String token, String body) => http
      .post(
        Uri.parse('${ApiConfig.api}/games/letter/level'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      )
      .timeout(_timeout);

  static Future<void> _enqueue(Map<String, dynamic> body) async {
    try {
      final key = await _key('letter_level_queue');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(key) ?? <String>[];
      queue.add(jsonEncode(body));
      await prefs.setStringList(key, queue.length > 500 ? queue.sublist(queue.length - 500) : queue);
    } catch (_) {}
  }

  /// Sends levels played while offline.
  static Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    final future = _flush().whenComplete(() => _flushing = null);
    _flushing = future;
    return future;
  }

  static Future<void> _flush() async {
    try {
      final key = await _key('letter_level_queue');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return;
      while (true) {
        final queue = List<String>.from(prefs.getStringList(key) ?? const []);
        if (queue.isEmpty) break;
        final int status;
        try {
          status = (await _post(token, queue.first)).statusCode;
        } catch (_) {
          break; // still offline
        }
        if (status == 200 || status == 400) {
          // Remove only what was sent (more may have been added meanwhile).
          final latest = List<String>.from(prefs.getStringList(key) ?? const []);
          latest.remove(queue.first);
          await prefs.setStringList(key, latest);
        } else {
          break;
        }
      }
    } catch (_) {}
  }

  /// Sends what is waiting, then takes the best stars from the server
  /// (e.g. played on another phone, or after reinstalling).
  static Future<void> sync() async {
    await _claimOldStars();
    await flush();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/games/letter/levels'),
            headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final cats = body is Map ? body['categories'] : null;
      if (cats is! Map) return;
      for (final folder in folders) {
        final server = cats[folder];
        if (server is! List) continue;
        final local = await load(folder);
        var changed = false;
        for (int i = 0; i < levelCount && i < server.length; i++) {
          final s = server[i];
          if (s is int && s > local[i] && s <= 3) {
            local[i] = s;
            changed = true;
          }
        }
        if (changed) await _saveLocal(folder, local);
      }
    } catch (_) {}
  }

  /// Also brings back levels left in the middle (see [LetterResume]).
  static Future<void> syncAll() async {
    await sync();
    await LetterResume.sync();
  }
}

/// Sends right answers to the server (POST /api/games/letter/answer):
/// 1 coin per word per day, like the other word games. Answers given
/// offline are queued and sent later.
class LetterCoins {
  LetterCoins._();

  static const Duration _timeout = Duration(seconds: 5);
  static Future<void>? _flushing;

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('letter_coin_queue', userId);
  }

  static Future<http.Response> _post(String token, String body) => http
      .post(
        Uri.parse('${ApiConfig.api}/games/letter/answer'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      )
      .timeout(_timeout);

  static Future<GuessCoinResult> submit({
    required String categoryKey,
    required String word,
  }) async {
    final body = jsonEncode({
      'category': categoryKey,
      'word': word,
      'answeredAt': DateTime.now().toUtc().toIso8601String(),
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return const GuessCoinResult();
      final response = await _post(token, body);
      if (response.statusCode == 200) {
        final j = jsonDecode(utf8.decode(response.bodyBytes));
        final coins = j is Map && j['coinsAwarded'] is int ? j['coinsAwarded'] as int : 0;
        final already = j is Map && j['alreadyRewardedToday'] == true;
        if (j is Map) CoinBalance.set(j['balance']);
        unawaited(flush());
        return GuessCoinResult(coins: coins, alreadyToday: already);
      }
      if (response.statusCode >= 500) {
        await _enqueue(body);
        return const GuessCoinResult(pending: true);
      }
      return const GuessCoinResult();
    } catch (_) {
      await _enqueue(body);
      return const GuessCoinResult(pending: true);
    }
  }

  static Future<void> _enqueue(String body) async {
    try {
      final key = await _queueKey();
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(key) ?? <String>[];
      queue.add(body);
      await prefs.setStringList(
        key,
        queue.length > 300 ? queue.sublist(queue.length - 300) : queue,
      );
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
      final key = await _queueKey();
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return;
      while (true) {
        final queue = List<String>.from(prefs.getStringList(key) ?? const []);
        if (queue.isEmpty) return;
        final int status;
        try {
          status = (await _post(token, queue.first)).statusCode;
        } catch (_) {
          return; // still offline
        }
        if (status == 200 || status == 400) {
          // Remove only what was sent (more may have been added meanwhile).
          final latest = List<String>.from(prefs.getStringList(key) ?? const []);
          latest.remove(queue.first);
          await prefs.setStringList(key, latest);
          if (status == 200 && latest.isEmpty) unawaited(CoinBalance.refresh());
        } else {
          return;
        }
      }
    } catch (_) {}
  }
}

/// A level of "พยัญชนะต้น" left in the middle, so it can be continued from
/// the same question (same words and letters). Per account, on the phone
/// and on the server (/api/games/letter/resume), so it is kept after
/// reinstalling the app or on another phone. The newer change wins.
class LetterResume {
  LetterResume._();

  static const Duration _timeout = Duration(seconds: 8);
  static Future<void>? _flushing;

  static Future<String?> _key(String folder, int level) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('letter_resume_${folder}_$level', userId);
  }

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('letter_resume_queue', userId);
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  /// Checks a saved round (from the phone or the server); null if unusable.
  static Map<String, dynamic>? _clean(dynamic j) {
    if (j is! Map) return null;
    final questions = j['questions'];
    final index = j['index'];
    final score = j['score'];
    if (questions is! List || questions.isEmpty || index is! int || score is! int) {
      return null;
    }
    if (index < 1 || index >= questions.length || score < 0 || score > index) {
      return null;
    }
    final cleaned = <Map<String, dynamic>>[];
    for (final q in questions) {
      if (q is! Map) return null;
      final word = q['fullWord'];
      final missing = q['missingIndex'];
      final letter = q['correctLetter'];
      final options = q['options'];
      final image = q['imagePath'];
      if (word is! String || missing is! int || letter is! String ||
          options is! List || image is! String ||
          missing < 0 || missing >= word.length || word[missing] != letter) {
        return null;
      }
      cleaned.add({
        'fullWord': word,
        'missingIndex': missing,
        'correctLetter': letter,
        'options': options.whereType<String>().toList(),
        'imagePath': image,
      });
    }
    return {
      'questions': cleaned,
      'index': index,
      'score': score,
      'coins': j['coins'] is int ? j['coins'] as int : 0,
    };
  }

  /// { questions, index, score, coins } or null.
  static Future<Map<String, dynamic>?> load(String folder, int level) async {
    try {
      final key = await _key(folder, level);
      if (key == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final j = jsonDecode(raw);
      if (j is! Map || j['cleared'] == true) return null;
      return _clean(j);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(
    String folder,
    int level, {
    required List<Map<String, dynamic>> questions,
    required int index,
    required int score,
    required int coins,
  }) async {
    final round = {
      'questions': questions,
      'index': index,
      'score': score,
      'coins': coins,
    };
    await _write(folder, level, round);
  }

  /// Finished or started again: nothing to continue (kept as a dated mark,
  /// so an older copy from the server doesn't come back).
  static Future<void> clear(String folder, int level) => _write(folder, level, null);

  static Future<void> _write(String folder, int level, Map<String, dynamic>? round) async {
    final at = _now();
    try {
      final key = await _key(folder, level);
      final queueKey = await _queueKey();
      if (key == null || queueKey == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode(round == null
            ? {'cleared': true, 'updatedAt': at}
            : {...round, 'updatedAt': at}),
      );
      final queue = _readQueue(prefs.getString(queueKey));
      queue['$folder|$level'] = {'round': round, 'updatedAt': at};
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

  /// Sends changes made while offline.
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
      if (queueKey == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return;
      final queue = _readQueue(prefs.getString(queueKey));
      for (final entry in queue.entries) {
        final parts = entry.key.split('|');
        if (parts.length != 2) continue;
        final int status;
        try {
          status = (await http
                  .put(
                    Uri.parse(
                      '${ApiConfig.api}/games/letter/resume/${Uri.encodeComponent(parts[0])}/${parts[1]}',
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

  /// Sends local changes, then takes anything newer from the server
  /// (e.g. a level left in the middle on another phone).
  static Future<void> sync() async {
    await flush();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final queueKey = await _queueKey();
      if (token == null || token.isEmpty || queueKey == null) return;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/games/letter/resume'),
            headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final levels = body is Map ? body['levels'] : null;
      if (levels is! List) return;
      final unsent = _readQueue(prefs.getString(queueKey));
      for (final e in levels) {
        if (e is! Map || e['category'] is! String || e['level'] is! int) continue;
        final folder = e['category'] as String;
        final level = e['level'] as int;
        if (unsent.containsKey('$folder|$level')) continue; // the phone's is newer
        final serverAt = DateTime.tryParse(e['updatedAt']?.toString() ?? '');
        if (serverAt == null) continue;
        final key = await _key(folder, level);
        if (key == null) continue;
        DateTime? localAt;
        try {
          final local = jsonDecode(prefs.getString(key) ?? 'null');
          if (local is Map) localAt = DateTime.tryParse(local['updatedAt']?.toString() ?? '');
        } catch (_) {}
        if (localAt != null && !serverAt.isAfter(localAt)) continue;
        final round = _clean(e['round']);
        final at = serverAt.toUtc().toIso8601String();
        await prefs.setString(
          key,
          jsonEncode(round == null
              ? {'cleared': true, 'updatedAt': at}
              : {...round, 'updatedAt': at}),
        );
      }
    } catch (_) {}
  }

  /// Levels of [folder] left in the middle (for the "เล่นต่อ" marks).
  static Future<Set<int>> unfinishedLevels(String folder, int levelCount) async {
    final result = <int>{};
    for (int level = 1; level <= levelCount; level++) {
      if (await load(folder, level) != null) result.add(level);
    }
    return result;
  }
}
