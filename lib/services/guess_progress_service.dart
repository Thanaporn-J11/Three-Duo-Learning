import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'coin_balance.dart';
import 'user_account_preferences.dart';

/// A "ทายภาพ" round that was left unfinished.
class GuessRound {
  const GuessRound({
    required this.order,
    required this.index,
    required this.correct,
    required this.coins,
    this.pending = 0,
  });

  /// Words in the (shuffled) order of this round.
  final List<String> order;

  /// Next question to answer (0-based).
  final int index;
  final int correct;

  /// Coins earned so far in this round.
  final int coins;

  /// Correct answers given offline whose coin is still waiting to be sent.
  final int pending;

  Map<String, dynamic> toJson() => {
    'order': order,
    'index': index,
    'correct': correct,
    'coins': coins,
    'pending': pending,
  };
}

/// Saves where the child is in each "ทายภาพ" category (per account), so an
/// unfinished round can be continued, and remembers finished categories for
/// the green tick. Kept on the phone and copied to the server
/// (/api/games/guess/progress), so another phone shows the same.
class GuessProgress {
  GuessProgress._();

  static const Duration _timeout = Duration(seconds: 8);
  static Future<void>? _flushing;

  static Future<String?> _key(String base) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor(base, userId);
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  /// The unfinished round of [categoryId], or null. [validWords] are the
  /// category's current words: a saved round that no longer matches them
  /// (words added/removed in an update) is dropped.
  static Future<GuessRound?> load(
    String categoryId,
    Set<String> validWords,
  ) async {
    try {
      final key = await _key('guess_round_$categoryId');
      if (key == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final order = (j['order'] as List?)?.whereType<String>().toList();
      final index = j['index'];
      final correct = j['correct'];
      final coins = j['coins'];
      final pending = j['pending'];
      if (order == null ||
          order.length != validWords.length ||
          !order.every(validWords.contains) ||
          index is! int ||
          correct is! int ||
          coins is! int ||
          index <= 0 ||
          index >= order.length ||
          correct < 0 ||
          correct > index) {
        return null;
      }
      return GuessRound(
        order: order,
        index: index,
        correct: correct,
        coins: coins,
        pending: pending is int && pending >= 0 ? pending : 0,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String categoryId, GuessRound round) async {
    final at = _now();
    try {
      final key = await _key('guess_round_$categoryId');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({...round.toJson(), 'updatedAt': at}),
      );
    } catch (_) {}
    await _enqueue(categoryId, {
      'round': {
        'order': round.order,
        'index': round.index,
        'correct': round.correct,
        'coins': round.coins,
      },
      'updatedAt': at,
    });
  }

  /// No unfinished round any more. Kept as a dated "cleared" mark (not just
  /// deleted), so an older round from the server doesn't come back.
  static Future<void> clear(String categoryId) async {
    final at = _now();
    try {
      final key = await _key('guess_round_$categoryId');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode({'cleared': true, 'updatedAt': at}));
    } catch (_) {}
    await _enqueue(categoryId, {'round': null, 'updatedAt': at});
  }

  /// Best score (%) of each finished category.
  static Future<Map<String, int>> bestScores() async {
    try {
      final key = await _key('guess_best');
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
    final key = await _key('guess_best');
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(best));
  }

  static Future<void> saveFinished(String categoryId, int percent) async {
    try {
      final best = await bestScores();
      if ((best[categoryId] ?? -1) < percent) {
        best[categoryId] = percent;
        await _setBest(best);
      }
    } catch (_) {}
    await _enqueue(categoryId, {
      'round': null,
      'best': percent,
      'updatedAt': _now(),
    });
  }

  /// Every saved unfinished round, as categoryId -> (index, total).
  static Future<Map<String, ({int index, int total})>> unfinished(
    Map<String, Set<String>> wordsByCategory,
  ) async {
    final result = <String, ({int index, int total})>{};
    for (final e in wordsByCategory.entries) {
      final r = await load(e.key, e.value);
      if (r != null) result[e.key] = (index: r.index, total: r.order.length);
    }
    return result;
  }

  // ---------- server copy ----------

  /// Latest change per category waiting to be sent (offline etc.).
  static Future<void> _enqueue(String categoryId, Map<String, dynamic> body) async {
    try {
      final key = await _key('guess_sync_queue');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final queue = _readQueue(prefs.getString(key));
      final old = queue[categoryId];
      // Never lose a best score that is still waiting to be sent.
      final oldBest = old?['best'];
      final newBest = body['best'];
      if (oldBest is int && (newBest is! int || oldBest > newBest)) {
        body = {...body, 'best': oldBest};
      }
      queue[categoryId] = body;
      await prefs.setString(key, jsonEncode(queue));
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
      final key = await _key('guess_sync_queue');
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
                      '${ApiConfig.api}/games/guess/progress/${Uri.encodeComponent(entry.key)}',
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
          return; // offline: try again later
        }
        if (status == 200 || status == 400) {
          // Sent (or never acceptable). Remove it unless it changed meanwhile.
          final now = _readQueue(prefs.getString(key));
          if (jsonEncode(now[entry.key]) == jsonEncode(entry.value)) {
            now.remove(entry.key);
            await prefs.setString(key, jsonEncode(now));
          }
        } else {
          return; // 401 / 5xx: keep for later
        }
      }
    } catch (_) {}
  }

  /// Sends local changes, then takes anything newer from the server (e.g.
  /// played on another phone). Call when the category list opens.
  static Future<void> sync() async {
    await flush();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final queueKey = await _key('guess_sync_queue');
      if (token == null || token.isEmpty || queueKey == null) return;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/games/guess/progress'),
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

      // Changes not sent yet are newer than the server: leave those alone.
      final unsent = _readQueue(prefs.getString(queueKey));
      final best = await bestScores();
      var bestChanged = false;
      for (final e in cats.entries) {
        final categoryId = e.key;
        final server = e.value;
        if (categoryId is! String || server is! Map) continue;

        final serverBest = server['best'];
        if (serverBest is int && serverBest > (best[categoryId] ?? -1)) {
          best[categoryId] = serverBest;
          bestChanged = true;
        }

        if (unsent.containsKey(categoryId)) continue;
        final serverAt = DateTime.tryParse(server['updatedAt']?.toString() ?? '');
        if (serverAt == null) continue;
        final roundKey = await _key('guess_round_$categoryId');
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
        if (round is Map) {
          await prefs.setString(
            roundKey,
            jsonEncode({
              'order': round['order'],
              'index': round['index'],
              'correct': round['correct'],
              'coins': round['coins'],
              'pending': 0,
              'updatedAt': serverAt.toUtc().toIso8601String(),
            }),
          );
        } else {
          await prefs.setString(
            roundKey,
            jsonEncode({
              'cleared': true,
              'updatedAt': serverAt.toUtc().toIso8601String(),
            }),
          );
        }
      }
      if (bestChanged) await _setBest(best);
    } catch (_) {}
  }
}

/// What the server said about one answer.
class GuessCoinResult {
  const GuessCoinResult({
    this.coins = 0,
    this.pending = false,
    this.alreadyToday = false,
  });

  /// Coins added to the account now.
  final int coins;

  /// No internet: saved on the phone, the coin is added when back online.
  final bool pending;

  /// This word already gave a coin today (each word: 1 coin per day).
  final bool alreadyToday;
}

/// Sends correct answers to the server (POST /api/games/guess/answer), which
/// checks them and adds 1 coin per word per day. Offline answers are queued
/// per account and sent later with the time they were answered.
class GuessCoins {
  GuessCoins._();

  static const Duration _timeout = Duration(seconds: 5);
  static const int _maxQueued = 300;
  static Future<void>? _flushing;

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('guess_coin_queue', userId);
  }

  static Future<http.Response> _post(String token, String body) => http
      .post(
        Uri.parse('${ApiConfig.api}/games/guess/answer'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      )
      .timeout(_timeout);

  /// Call for a correct answer ([word] = the picture, [choice] = tapped).
  static Future<GuessCoinResult> submit({
    required String categoryId,
    required String word,
    required String choice,
  }) async {
    final body = jsonEncode({
      'category': categoryId,
      'word': word,
      'choice': choice,
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
        if (j is Map) CoinBalance.set(j['balance']); // update the coins at the top
        unawaited(flush()); // online again: send anything left from before
        return GuessCoinResult(coins: coins, alreadyToday: already);
      }
      if (response.statusCode >= 500) {
        await _enqueue(body);
        return const GuessCoinResult(pending: true);
      }
      return const GuessCoinResult(); // 400/401: not accepted
    } catch (_) {
      await _enqueue(body); // offline / timeout
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
          return; // still offline
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
