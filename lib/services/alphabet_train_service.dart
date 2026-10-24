import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'coin_balance.dart';
import 'guess_progress_service.dart' show GuessCoinResult;
import 'user_account_preferences.dart';

/// Stars per level of "งูน้อยฉลาดเลือก" (Alphabet Train, 50 levels), per
/// account, on the phone and on the server (/api/games/alphabet/...), so they
/// survive reinstalling the app and follow the child to another phone.
/// A level is passed when it has at least 1 star; the next one is unlocked.
class AlphabetLevels {
  AlphabetLevels._();

  static const int levelCount = 50;
  static const Duration _timeout = Duration(seconds: 6);
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

  /// Highest playable level: the one after the last passed level.
  static int unlockedLevel(List<int> stars) {
    int last = 0;
    for (int i = 0; i < stars.length; i++) {
      if (stars[i] > 0) last = i + 1;
    }
    return (last + 1).clamp(1, levelCount).toInt();
  }

  /// Stars of the 50 levels for the signed-in account.
  static Future<List<int>> load() async {
    try {
      await _claimOldStars();
      final key = await _key('alphabet_stars');
      if (key == null) return List<int>.filled(levelCount, 0);
      final prefs = await SharedPreferences.getInstance();
      return _parse(prefs.getString(key));
    } catch (_) {
      return List<int>.filled(levelCount, 0);
    }
  }

  static Future<void> _saveLocal(List<int> stars) async {
    final key = await _key('alphabet_stars');
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, stars.join(','));
  }

  /// Stars saved by the old version (on the phone, for nobody in particular:
  /// 'level_stars_N', 'unlocked_level') go to the first account that opens
  /// the game here, and are sent to the server as "imported".
  static Future<void> _claimOldStars() async {
    final userId = await UserAccountPreferences.currentUserId();
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final doneKey = UserAccountPreferences.keyFor('alphabet_old_stars_checked', userId);
    if (prefs.getBool(doneKey) ?? false) return;
    await prefs.setBool(doneKey, true);
    if (!await UserAccountPreferences.claimLegacyData('alphabet_old_stars_owner', userId)) {
      return;
    }
    final old = List<int>.generate(
      levelCount,
      (i) => (prefs.getInt('level_stars_${i + 1}') ?? 0).clamp(0, 3).toInt(),
    );
    // A level unlocked by the old version was passed (at least 1 star).
    final oldUnlocked = (prefs.getInt('unlocked_level') ?? 1).clamp(1, levelCount).toInt();
    for (int i = 0; i < oldUnlocked - 1; i++) {
      if (old[i] == 0) old[i] = 1;
    }
    if (old.every((s) => s == 0)) return;
    final key = UserAccountPreferences.keyFor('alphabet_stars', userId);
    final mine = _parse(prefs.getString(key));
    for (int i = 0; i < levelCount; i++) {
      if (old[i] > mine[i]) mine[i] = old[i];
    }
    await prefs.setString(key, mine.join(','));
    for (int i = 0; i < levelCount; i++) {
      if (old[i] > 0) {
        await _enqueue({'level': i + 1, 'stars': old[i], 'imported': true});
      }
    }
  }

  /// The level was passed with [stars]. Keeps the best, here and on the server.
  static Future<void> record(int level, int stars) async {
    final current = await load();
    if (stars > current[level - 1]) {
      current[level - 1] = stars;
      await _saveLocal(current);
    }
    final body = {'level': level, 'stars': stars};
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
        Uri.parse('${ApiConfig.api}/games/alphabet/level'),
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
      final key = await _key('alphabet_level_queue');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(key) ?? <String>[];
      queue.add(jsonEncode(body));
      await prefs.setStringList(key, queue.length > 300 ? queue.sublist(queue.length - 300) : queue);
    } catch (_) {}
  }

  /// Sends levels passed while offline.
  static Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    final future = _flush().whenComplete(() => _flushing = null);
    _flushing = future;
    return future;
  }

  static Future<void> _flush() async {
    try {
      final key = await _key('alphabet_level_queue');
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
            Uri.parse('${ApiConfig.api}/games/alphabet/levels'),
            headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final server = body is Map ? body['stars'] : null;
      if (server is! List) return;
      final local = await load();
      var changed = false;
      for (int i = 0; i < levelCount && i < server.length; i++) {
        final s = server[i];
        if (s is int && s > local[i] && s <= 3) {
          local[i] = s;
          changed = true;
        }
      }
      if (changed) await _saveLocal(local);
    } catch (_) {}
  }
}

/// Sends right letters to the server (POST /api/games/alphabet/answer):
/// coins once per letter per day, like the other games. Offline answers
/// are queued and sent later.
class AlphabetCoins {
  AlphabetCoins._();

  static const Duration _timeout = Duration(seconds: 5);
  static Future<void>? _flushing;

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('alphabet_coin_queue', userId);
  }

  static Future<http.Response> _post(String token, String body) => http
      .post(
        Uri.parse('${ApiConfig.api}/games/alphabet/answer'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      )
      .timeout(_timeout);

  static Future<GuessCoinResult> submit(String letter) async {
    final body = jsonEncode({
      'letter': letter,
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

/// A level of "งูน้อยฉลาดเลือก" left in the middle.
class AlphabetRound {
  const AlphabetRound({
    required this.missing,
    required this.done,
    required this.remaining,
    required this.coins,
  });

  /// Board positions (0-25) that were hidden in this level, sorted.
  final List<int> missing;

  /// How many of them are filled in already (in order).
  final int done;

  /// Seconds left on the clock.
  final int remaining;

  /// Coins earned so far in this level.
  final int coins;

  Map<String, dynamic> toJson() => {
    'missing': missing,
    'done': done,
    'remaining': remaining,
    'coins': coins,
  };

  static AlphabetRound? fromJson(dynamic j, int expectedMissing) {
    if (j is! Map) return null;
    final missing = (j['missing'] as List?)?.whereType<int>().toList();
    final done = j['done'];
    final remaining = j['remaining'];
    final coins = j['coins'];
    if (missing == null ||
        missing.length != expectedMissing ||
        done is! int ||
        remaining is! int ||
        coins is! int) {
      return null;
    }
    for (int i = 0; i < missing.length; i++) {
      if (missing[i] < 0 || missing[i] > 25) return null;
      if (i > 0 && missing[i] <= missing[i - 1]) return null;
    }
    if (done < 1 || done >= missing.length) return null;
    if (remaining < 1 || remaining > 600) return null;
    if (coins < 0 || coins > done * kGameCoinsPerWord) return null;
    return AlphabetRound(missing: missing, done: done, remaining: remaining, coins: coins);
  }
}

/// Levels left in the middle, per account, on the phone and on the server
/// (/api/games/alphabet/resume), so the child can continue the same level
/// after reinstalling the app or on another phone. The newer change wins.
class AlphabetResume {
  AlphabetResume._();

  static const Duration _timeout = Duration(seconds: 8);
  static Future<void>? _flushing;

  static Future<String?> _key(int level) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('alphabet_resume_$level', userId);
  }

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('alphabet_resume_queue', userId);
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static Future<AlphabetRound?> load(int level, int expectedMissing) async {
    try {
      final key = await _key(level);
      if (key == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final j = jsonDecode(raw);
      if (j is! Map || j['cleared'] == true) return null;
      return AlphabetRound.fromJson(j, expectedMissing);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(int level, AlphabetRound round) => _write(level, round.toJson());

  /// Finished, time up or started again: nothing to continue (kept as a
  /// dated mark, so an older copy from the server doesn't come back).
  static Future<void> clear(int level) => _write(level, null);

  static Future<void> _write(int level, Map<String, dynamic>? round) async {
    final at = _now();
    try {
      final key = await _key(level);
      final queueKey = await _queueKey();
      if (key == null || queueKey == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode(round == null ? {'cleared': true, 'updatedAt': at} : {...round, 'updatedAt': at}),
      );
      final queue = _readQueue(prefs.getString(queueKey));
      queue['$level'] = {'round': round, 'updatedAt': at};
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
        final int status;
        try {
          status = (await http
                  .put(
                    Uri.parse('${ApiConfig.api}/games/alphabet/resume/${entry.key}'),
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final queueKey = await _queueKey();
      if (token == null || token.isEmpty || queueKey == null) return;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/games/alphabet/resume'),
            headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final levels = body is Map ? body['levels'] : null;
      if (levels is! List) return;
      final unsent = _readQueue(prefs.getString(queueKey));
      for (final e in levels) {
        if (e is! Map || e['level'] is! int) continue;
        final level = e['level'] as int;
        if (level < 1 || level > AlphabetLevels.levelCount) continue;
        if (unsent.containsKey('$level')) continue; // the phone's is newer
        final serverAt = DateTime.tryParse(e['updatedAt']?.toString() ?? '');
        if (serverAt == null) continue;
        final key = await _key(level);
        if (key == null) continue;
        DateTime? localAt;
        try {
          final local = jsonDecode(prefs.getString(key) ?? 'null');
          if (local is Map) localAt = DateTime.tryParse(local['updatedAt']?.toString() ?? '');
        } catch (_) {}
        if (localAt != null && !serverAt.isAfter(localAt)) continue;
        final round = e['round'];
        final at = serverAt.toUtc().toIso8601String();
        await prefs.setString(
          key,
          jsonEncode(round is Map
              ? {...Map<String, dynamic>.from(round), 'updatedAt': at}
              : {'cleared': true, 'updatedAt': at}),
        );
      }
    } catch (_) {}
  }
}

/// Levels with a game left in the middle (for the "ต่อ" marks).
Future<Set<int>> alphabetUnfinishedLevels(int Function(int level) missingCount) async {
  final result = <int>{};
  for (int level = 1; level <= AlphabetLevels.levelCount; level++) {
    if (await AlphabetResume.load(level, missingCount(level)) != null) result.add(level);
  }
  return result;
}
