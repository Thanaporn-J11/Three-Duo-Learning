import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'guess_progress_service.dart' show GuessCoinResult;
import 'coin_balance.dart';
import 'user_account_preferences.dart';

/// Pairs shown together in one stage of "จับคู่เงา".
const int shadowItemsPerStage = 4;

/// An unfinished "จับคู่เงา" game in one category.
class ShadowRound {
  const ShadowRound({
    required this.order,
    required this.roundIndex,
    required this.matched,
    required this.mistakes,
    required this.coins,
    this.pending = 0,
  });

  /// Item ids in the (shuffled) order of this game; stage n = the n-th 4.
  final List<String> order;

  /// Current stage (0-based).
  final int roundIndex;

  /// Items already matched in the current stage.
  final List<String> matched;
  final int mistakes;
  final int coins;

  /// Matches made offline whose coin is still waiting to be sent.
  final int pending;

  int get stages => (order.length / shadowItemsPerStage).ceil();

  /// Pairs matched so far in the whole game.
  int get matchedTotal => roundIndex * shadowItemsPerStage + matched.length;

  Map<String, dynamic> toServer() => {
    'order': order,
    'roundIndex': roundIndex,
    'matched': matched,
    'mistakes': mistakes,
    'coins': coins,
  };

  static ShadowRound? fromJson(dynamic j, Set<String> validIds) {
    if (j is! Map) return null;
    final order = (j['order'] as List?)?.whereType<String>().toList();
    final roundIndex = j['roundIndex'];
    final matched = (j['matched'] as List?)?.whereType<String>().toList();
    final mistakes = j['mistakes'];
    final coins = j['coins'];
    final pending = j['pending'];
    if (order == null ||
        matched == null ||
        roundIndex is! int ||
        mistakes is! int ||
        coins is! int ||
        order.length != validIds.length ||
        order.toSet().length != order.length ||
        !order.every(validIds.contains)) {
      return null;
    }
    final stages = (order.length / shadowItemsPerStage).ceil();
    if (roundIndex < 0 || roundIndex >= stages) return null;
    final stage = order
        .skip(roundIndex * shadowItemsPerStage)
        .take(shadowItemsPerStage)
        .toList();
    if (matched.toSet().length != matched.length ||
        !matched.every(stage.contains) ||
        matched.length >= stage.length) {
      return null;
    }
    final done = roundIndex * shadowItemsPerStage + matched.length;
    if (done < 1 || mistakes < 0 || coins < 0 || coins > done * kGameCoinsPerWord) return null;
    return ShadowRound(
      order: order,
      roundIndex: roundIndex,
      matched: matched,
      mistakes: mistakes,
      coins: coins,
      pending: pending is int && pending >= 0 ? pending : 0,
    );
  }
}

/// Saves where the child is in each "จับคู่เงา" category (per account), on
/// the phone and on the server (/api/games/shadow/progress), so the game can
/// be continued, also on another phone, and finished categories get a tick.
class ShadowProgress {
  ShadowProgress._();

  static const Duration _timeout = Duration(seconds: 8);
  static Future<void>? _flushing;

  static Future<String?> _key(String base) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor(base, userId);
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static Future<ShadowRound?> load(String categoryKey, Set<String> validIds) async {
    try {
      final key = await _key('shadow_round_$categoryKey');
      if (key == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return ShadowRound.fromJson(jsonDecode(raw), validIds);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String categoryKey, ShadowRound round) async {
    final at = _now();
    try {
      final key = await _key('shadow_round_$categoryKey');
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
      final key = await _key('shadow_round_$categoryKey');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode({'cleared': true, 'updatedAt': at}));
    } catch (_) {}
    await _enqueue(categoryKey, {'round': null, 'updatedAt': at});
  }

  static Future<Map<String, int>> bestScores() async {
    try {
      final key = await _key('shadow_best');
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
    final key = await _key('shadow_best');
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
      final key = await _key('shadow_round_$categoryKey');
      if (key != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, jsonEncode({'cleared': true, 'updatedAt': at}));
      }
    } catch (_) {}
    await _enqueue(categoryKey, {'round': null, 'best': percent, 'updatedAt': at});
  }

  /// Unfinished games as categoryKey -> (stage, stages), for the badges.
  static Future<Map<String, ({int stage, int stages})>> unfinished(
    Map<String, Set<String>> idsByCategory,
  ) async {
    final result = <String, ({int stage, int stages})>{};
    for (final e in idsByCategory.entries) {
      final r = await load(e.key, e.value);
      if (r != null) result[e.key] = (stage: r.roundIndex + 1, stages: r.stages);
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
      final key = await _key('shadow_sync_queue');
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
      final key = await _key('shadow_sync_queue');
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
                      '${ApiConfig.api}/games/shadow/progress/${Uri.encodeComponent(entry.key)}',
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
      final queueKey = await _key('shadow_sync_queue');
      if (token == null || token.isEmpty || queueKey == null) return;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/games/shadow/progress'),
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
        final roundKey = await _key('shadow_round_$categoryKey');
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

/// Sends matches to the server (POST /api/games/shadow/match): 1 coin per
/// item per day. Offline matches are queued and sent later.
class ShadowCoins {
  ShadowCoins._();

  static const Duration _timeout = Duration(seconds: 5);
  static const int _maxQueued = 300;
  static Future<void>? _flushing;

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('shadow_coin_queue', userId);
  }

  static Future<http.Response> _post(String token, String body) => http
      .post(
        Uri.parse('${ApiConfig.api}/games/shadow/match'),
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
    required String itemId,
  }) async {
    final body = jsonEncode({
      'category': categoryKey,
      'item': itemId,
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
