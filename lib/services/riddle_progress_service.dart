import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'guess_progress_service.dart' show GuessCoinResult;
import 'coin_balance.dart';
import 'user_account_preferences.dart';

/// Hints a "ปริศนาทายคำ" question allows, by letter count (the server uses
/// the same rule). Using all of them means no coin for that word.
int riddleMaxHints(String answer) {
  final letters = answer.replaceAll(RegExp(r'[^A-Z]'), '').length;
  if (letters <= 4) return 1;
  if (letters <= 6) return 2;
  return 3;
}

/// An unfinished "ปริศนาทายคำ" game in one category.
class RiddleRound {
  const RiddleRound({
    required this.queue,
    required this.done,
    required this.mistakes,
    this.revealed = 0,
    required this.hints,
    required this.coins,
    this.pending = 0,
  });

  /// Answers still to do, the current question first (skipped ones go last).
  final List<String> queue;

  /// Questions answered correctly so far.
  final int done;
  final int mistakes;

  /// Questions where "ดูเฉลย" was used (part of [done], never a coin).
  final int revealed;

  /// Hints used so far in this game.
  final int hints;
  final int coins;

  /// Correct answers given offline whose coin is still waiting to be sent.
  final int pending;

  int get total => done + queue.length;

  Map<String, dynamic> toServer() => {
    'queue': queue,
    'done': done,
    'mistakes': mistakes,
    'revealed': revealed,
    'hints': hints,
    'coins': coins,
  };

  static RiddleRound? fromJson(dynamic j, Set<String> validAnswers) {
    if (j is! Map) return null;
    final queue = (j['queue'] as List?)?.whereType<String>().toList();
    final done = j['done'];
    final mistakes = j['mistakes'];
    final revealed = j['revealed'] ?? 0;
    final hints = j['hints'];
    final coins = j['coins'];
    final pending = j['pending'];
    if (queue == null ||
        done is! int ||
        mistakes is! int ||
        revealed is! int ||
        hints is! int ||
        coins is! int ||
        queue.isEmpty ||
        queue.toSet().length != queue.length ||
        !queue.every(validAnswers.contains) ||
        done < 1 ||
        done + queue.length != validAnswers.length ||
        mistakes < 0 ||
        revealed < 0 ||
        revealed > done ||
        hints < 0 ||
        coins < 0 ||
        coins > (done - revealed) * kGameCoinsPerWord) {
      return null;
    }
    return RiddleRound(
      queue: queue,
      done: done,
      mistakes: mistakes,
      revealed: revealed,
      hints: hints,
      coins: coins,
      pending: pending is int && pending >= 0 ? pending : 0,
    );
  }
}

/// Saves where the child is in each "ปริศนาทายคำ" category (per account), on
/// the phone and on the server (/api/games/riddle/progress), so the game can
/// be continued, also on another phone, and finished categories get a tick.
class RiddleProgress {
  RiddleProgress._();

  static const Duration _timeout = Duration(seconds: 8);
  static Future<void>? _flushing;

  static Future<String?> _key(String base) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor(base, userId);
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static Future<RiddleRound?> load(String categoryKey, Set<String> validAnswers) async {
    try {
      final key = await _key('riddle_round_$categoryKey');
      if (key == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return RiddleRound.fromJson(jsonDecode(raw), validAnswers);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String categoryKey, RiddleRound round) async {
    final at = _now();
    try {
      final key = await _key('riddle_round_$categoryKey');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({...round.toServer(), 'pending': round.pending, 'updatedAt': at}),
      );
    } catch (_) {}
    await _enqueue(categoryKey, {'round': round.toServer(), 'updatedAt': at});
  }

  /// No unfinished game any more (kept as a dated mark so an older copy from
  /// the server doesn't come back).
  static Future<void> clear(String categoryKey) async {
    final at = _now();
    try {
      final key = await _key('riddle_round_$categoryKey');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode({'cleared': true, 'updatedAt': at}));
    } catch (_) {}
    await _enqueue(categoryKey, {'round': null, 'updatedAt': at});
  }

  static Future<Map<String, int>> bestScores() async {
    try {
      final key = await _key('riddle_best');
      if (key == null) return {};
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return {};
      final j = jsonDecode(raw);
      if (j is! Map) return {};
      return {
        for (final e in j.entries)
          if (e.key is String && e.value is int) e.key as String: e.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> _setBest(Map<String, int> best) async {
    final key = await _key('riddle_best');
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(best));
  }

  /// The category was finished with [percent] accuracy.
  static Future<void> saveFinished(String categoryKey, int percent) async {
    final at = _now();
    try {
      final best = await bestScores();
      if ((best[categoryKey] ?? -1) < percent) {
        best[categoryKey] = percent;
        await _setBest(best);
      }
      final key = await _key('riddle_round_$categoryKey');
      if (key != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, jsonEncode({'cleared': true, 'updatedAt': at}));
      }
    } catch (_) {}
    await _enqueue(categoryKey, {'round': null, 'best': percent, 'updatedAt': at});
  }

  /// Unfinished games as categoryKey -> (done, total), for the badges.
  static Future<Map<String, ({int done, int total})>> unfinished(
    Map<String, Set<String>> answersByCategory,
  ) async {
    final result = <String, ({int done, int total})>{};
    for (final e in answersByCategory.entries) {
      final r = await load(e.key, e.value);
      if (r != null) result[e.key] = (done: r.done, total: r.total);
    }
    return result;
  }

  // ---------- server copy ----------

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

  static Future<void> _enqueue(String categoryKey, Map<String, dynamic> body) async {
    try {
      final key = await _key('riddle_sync_queue');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final queue = _readQueue(prefs.getString(key));
      final oldBest = queue[categoryKey]?['best'];
      final newBest = body['best'];
      if (oldBest is int && (newBest is! int || oldBest > newBest)) {
        body = {...body, 'best': oldBest}; // never lose an unsent best score
      }
      queue[categoryKey] = body;
      await prefs.setString(key, jsonEncode(queue));
    } catch (_) {}
    unawaited(flush());
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
      final key = await _key('riddle_sync_queue');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return;
      final queue = _readQueue(prefs.getString(key));
      for (final entry in queue.entries) {
        final int status;
        try {
          status = (await http
                  .put(
                    Uri.parse(
                      '${ApiConfig.api}/games/riddle/progress/${Uri.encodeComponent(entry.key)}',
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
          final now = _readQueue(prefs.getString(key));
          if (jsonEncode(now[entry.key]) == jsonEncode(entry.value)) {
            now.remove(entry.key);
            await prefs.setString(key, jsonEncode(now));
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
      final queueKey = await _key('riddle_sync_queue');
      if (token == null || token.isEmpty || queueKey == null) return;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/games/riddle/progress'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final cats = body is Map ? body['categories'] : null;
      if (cats is! Map) return;

      final unsent = _readQueue(prefs.getString(queueKey));
      final best = await bestScores();
      var bestChanged = false;
      for (final e in cats.entries) {
        final categoryKey = e.key;
        final server = e.value;
        if (categoryKey is! String || server is! Map) continue;
        final serverBest = server['best'];
        if (serverBest is int && serverBest > (best[categoryKey] ?? -1)) {
          best[categoryKey] = serverBest;
          bestChanged = true;
        }
        if (unsent.containsKey(categoryKey)) continue; // local is newer
        final serverAt = DateTime.tryParse(server['updatedAt']?.toString() ?? '');
        if (serverAt == null) continue;
        final roundKey = await _key('riddle_round_$categoryKey');
        if (roundKey == null) continue;
        DateTime? localAt;
        try {
          final local = jsonDecode(prefs.getString(roundKey) ?? 'null');
          if (local is Map) {
            localAt = DateTime.tryParse(local['updatedAt']?.toString() ?? '');
          }
        } catch (_) {}
        if (localAt != null && !serverAt.isAfter(localAt)) continue;
        final round = server['round'];
        final at = serverAt.toUtc().toIso8601String();
        await prefs.setString(
          roundKey,
          jsonEncode(
            round is Map
                ? {...Map<String, dynamic>.from(round), 'pending': 0, 'updatedAt': at}
                : {'cleared': true, 'updatedAt': at},
          ),
        );
      }
      if (bestChanged) await _setBest(best);
    } catch (_) {}
  }
}

/// Sends correct answers to the server (POST /api/games/riddle/answer):
/// 1 coin per word per day, none when every hint of the question was used.
/// Answers given offline are queued and sent later.
class RiddleCoins {
  RiddleCoins._();

  static const Duration _timeout = Duration(seconds: 5);
  static const int _maxQueued = 300;
  static Future<void>? _flushing;

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('riddle_coin_queue', userId);
  }

  static Future<http.Response> _post(String token, String body) => http
      .post(
        Uri.parse('${ApiConfig.api}/games/riddle/answer'),
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
    required String answer,
    required int hintsUsed,
  }) async {
    // All hints used: the app spelled the word, so there's no coin to ask for.
    if (hintsUsed >= riddleMaxHints(answer)) return const GuessCoinResult();
    final body = jsonEncode({
      'category': categoryKey,
      'word': answer,
      'hintsUsed': hintsUsed,
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
        if (j is Map && j['balance'] != null) CoinBalance.set(j['balance']);
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
        queue.length > _maxQueued ? queue.sublist(queue.length - _maxQueued) : queue,
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
          return;
        }
        if (status == 200 || status == 400) {
          // Remove only the item that was sent (read the queue again: more may
          // have been added while it was being sent). 400 = never accepted.
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
