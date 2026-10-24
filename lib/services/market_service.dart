import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'coin_balance.dart';
import 'guess_progress_service.dart' show GuessCoinResult;
import 'user_account_preferences.dart';

/// The whole "มินิมาร์เก็ต" game state (stars x 28, unlocked level,
/// collected items), per account, on the phone and on the server
/// (GET/PUT /api/games/market/state), so it survives reinstalling the app
/// and follows the child to another phone. The newer copy wins.
class MarketStateSync {
  MarketStateSync._();

  static const Duration _timeout = Duration(seconds: 8);
  static Future<void>? _flushing;

  static Future<String?> _key(String base) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor(base, userId);
  }

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return token == null || token.isEmpty ? null : token;
  }

  /// The signed-in account's state on this phone, or null.
  static Future<Map<String, dynamic>?> loadLocal() async {
    try {
      final key = await _key('market_state');
      if (key == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final j = jsonDecode(prefs.getString(key) ?? 'null');
      if (j is! Map || j['data'] is! Map) return null;
      return Map<String, dynamic>.from(j['data'] as Map);
    } catch (_) {
      return null;
    }
  }

  /// Saves on the phone and sends to the server (later if offline).
  static Future<void> save(Map<String, dynamic> data) async {
    try {
      final key = await _key('market_state');
      final pendingKey = await _key('market_state_pending');
      if (key == null || pendingKey == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({'data': data, 'updatedAt': DateTime.now().toUtc().toIso8601String()}),
      );
      await prefs.setBool(pendingKey, true);
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
      final key = await _key('market_state');
      final pendingKey = await _key('market_state_pending');
      final token = await _token();
      if (key == null || pendingKey == null || token == null) return;
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(pendingKey) ?? false)) return;
      final sent = prefs.getString(key);
      if (sent == null) return;
      final int status;
      try {
        status = (await http
                .put(
                  Uri.parse('${ApiConfig.api}/games/market/state'),
                  headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: sent,
                )
                .timeout(_timeout))
            .statusCode;
      } catch (_) {
        return; // offline: sent later
      }
      // Done unless something newer was saved while sending.
      if ((status == 200 || status == 400) && prefs.getString(key) == sent) {
        await prefs.setBool(pendingKey, false);
      }
    } catch (_) {}
  }

  /// Sends what is waiting, then returns the server's state when it is
  /// newer than the phone's (null = keep the phone's).
  static Future<Map<String, dynamic>?> pull() async {
    await flush();
    try {
      final key = await _key('market_state');
      final pendingKey = await _key('market_state_pending');
      final token = await _token();
      if (key == null || pendingKey == null || token == null) return null;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(pendingKey) ?? false) return null; // the phone's is newer
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/games/market/state'),
            headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map || body['data'] is! Map) return null;
      final serverAt = DateTime.tryParse(body['updatedAt']?.toString() ?? '');
      if (serverAt == null) return null;
      DateTime? localAt;
      try {
        final local = jsonDecode(prefs.getString(key) ?? 'null');
        if (local is Map) localAt = DateTime.tryParse(local['updatedAt']?.toString() ?? '');
      } catch (_) {}
      if (localAt != null && !serverAt.isAfter(localAt)) return null;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      await prefs.setString(
        key,
        jsonEncode({'data': data, 'updatedAt': serverAt.toUtc().toIso8601String()}),
      );
      return data;
    } catch (_) {
      return null;
    }
  }
}

/// Sends items of orders delivered right (POST /api/games/market/answer):
/// 2 coins per item per day, like the other games. Offline ones are queued.
class MarketCoins {
  MarketCoins._();

  static const Duration _timeout = Duration(seconds: 5);
  static Future<void>? _flushing;

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor('market_coin_queue', userId);
  }

  static Future<http.Response> _post(String token, String body) => http
      .post(
        Uri.parse('${ApiConfig.api}/games/market/answer'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      )
      .timeout(_timeout);

  static Future<GuessCoinResult> submit(String itemId) async {
    final body = jsonEncode({'item': itemId, 'answeredAt': DateTime.now().toUtc().toIso8601String()});
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
      await prefs.setStringList(key, queue.length > 300 ? queue.sublist(queue.length - 300) : queue);
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

/// A "มินิมาร์เก็ต" level left in the middle (between two customers).
class MarketRound {
  const MarketRound({
    required this.served,
    required this.successes,
    required this.mistakes,
    required this.collected,
  });

  /// Customers already served (the next one comes when going on).
  final int served;
  final int successes;
  final int mistakes;

  /// New stickers collected in this level so far.
  final int collected;

  Map<String, dynamic> toJson() =>
      {'served': served, 'successes': successes, 'mistakes': mistakes, 'collected': collected};

  static MarketRound? fromJson(dynamic j, {required int customers}) {
    if (j is! Map) return null;
    final served = j['served'];
    final successes = j['successes'];
    final mistakes = j['mistakes'];
    final collected = j['collected'];
    if (served is! int || successes is! int || mistakes is! int || collected is! int) return null;
    if (served < 1 || served >= customers || successes < 0 || successes > served) return null;
    if (mistakes < 0 || collected < 0) return null;
    return MarketRound(served: served, successes: successes, mistakes: mistakes, collected: collected);
  }
}

/// Levels left in the middle, per account, on the phone and on the server
/// (/api/games/market/resume), so the child can go on after reinstalling the
/// app or on another phone. The newer change wins.
class MarketResume {
  MarketResume._();

  static const Duration _timeout = Duration(seconds: 8);
  static Future<void>? _flushing;

  static Future<String?> _key(int level) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor('market_resume_$level', userId);
  }

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor('market_resume_queue', userId);
  }

  static Future<MarketRound?> load(int level, {required int customers}) async {
    try {
      final key = await _key(level);
      if (key == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final j = jsonDecode(prefs.getString(key) ?? 'null');
      if (j is! Map || j['cleared'] == true) return null;
      return MarketRound.fromJson(j, customers: customers);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(int level, MarketRound round) => _write(level, round.toJson());

  /// Finished, lost or started again: nothing to continue.
  static Future<void> clear(int level) => _write(level, null);

  static Future<void> _write(int level, Map<String, dynamic>? round) async {
    final at = DateTime.now().toUtc().toIso8601String();
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
          if (e.key is String && e.value is Map) e.key as String: Map<String, dynamic>.from(e.value as Map),
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
                    Uri.parse('${ApiConfig.api}/games/market/resume/${entry.key}'),
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
            Uri.parse('${ApiConfig.api}/games/market/resume'),
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
        if (level < 1 || level > 28 || unsent.containsKey('$level')) continue;
        final serverAt = DateTime.tryParse(e['updatedAt']?.toString() ?? '');
        final key = await _key(level);
        if (serverAt == null || key == null) continue;
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
