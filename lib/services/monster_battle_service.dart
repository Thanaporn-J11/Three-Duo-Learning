import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'coin_balance.dart';
import 'guess_progress_service.dart' show GuessCoinResult;
import 'profile_api_service.dart';
import 'user_account_preferences.dart';

/// The whole "สร้างมอนสเตอร์" game state (stars x 40, in-game gold, items,
/// stats, daily reward), per account, on the phone and on the server
/// (GET/PUT /api/games/monster/state), so it survives reinstalling the app
/// and follows the child to another phone. The newer copy wins.
class MonsterStateSync {
  MonsterStateSync._();

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
      final key = await _key('monster_state');
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
      final key = await _key('monster_state');
      final pendingKey = await _key('monster_state_pending');
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

  /// Progress saved by the old version (on the phone, for nobody in
  /// particular: 'mb_*') goes to the first account that opens the game here.
  static Future<Map<String, dynamic>?> claimOldProgress() async {
    final userId = await UserAccountPreferences.currentUserId();
    if (userId == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final doneKey = UserAccountPreferences.keyFor('monster_old_checked', userId);
    if (prefs.getBool(doneKey) ?? false) return null;
    await prefs.setBool(doneKey, true);
    final hasOld = prefs.getStringList('mb_stars') != null || prefs.getInt('mb_gold') != null;
    if (!hasOld) return null;
    if (!await UserAccountPreferences.claimLegacyData('monster_old_owner', userId)) return null;
    final stars = prefs.getStringList('mb_stars') ?? const <String>[];
    return {
      'stars': [for (int i = 0; i < 40; i++) i < stars.length ? (int.tryParse(stars[i]) ?? 0).clamp(0, 3) : 0],
      'gold': prefs.getInt('mb_gold') ?? 0,
      'items': {
        'hint': prefs.getInt('mb_item_hint') ?? 3,
        'freeze': prefs.getInt('mb_item_freeze') ?? 3,
        'smoke': prefs.getInt('mb_item_smoke') ?? 2,
        'shield': prefs.getInt('mb_item_shield') ?? 2,
      },
      'kills': prefs.getInt('mb_kills') ?? 0,
      'bossKills': prefs.getInt('mb_boss_kills') ?? 0,
      'bestCombo': prefs.getInt('mb_best_combo') ?? 0,
      'dailyStreak': prefs.getInt('mb_daily_streak') ?? 0,
      'lastDaily': prefs.getString('mb_last_daily') ?? '',
    };
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
      final key = await _key('monster_state');
      final pendingKey = await _key('monster_state_pending');
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
                  Uri.parse('${ApiConfig.api}/games/monster/state'),
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
      final key = await _key('monster_state');
      final pendingKey = await _key('monster_state_pending');
      final token = await _token();
      if (key == null || pendingKey == null || token == null) return null;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(pendingKey) ?? false) return null; // the phone's is newer
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/games/monster/state'),
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

/// Real coins of "สร้างมอนสเตอร์" (a harder game, so more than the others):
/// - right answer: 3 coins per word per day (POST /api/games/monster/answer)
/// - level passed: 5 coins per star, +10 for a boss level, once per level
///   per day (POST /api/games/monster/level-clear)
/// Offline ones are queued and sent later.
class MonsterCoins {
  MonsterCoins._();

  static const Duration _timeout = Duration(seconds: 5);
  static Future<void>? _flushing;

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('monster_coin_queue', userId);
  }

  static Future<http.Response> _post(String token, String path, String body) => http
      .post(
        Uri.parse('${ApiConfig.api}/games/monster/$path'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      )
      .timeout(_timeout);

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static Future<GuessCoinResult> submit(String word) =>
      _send('answer', {'word': word, 'answeredAt': _now()});

  static Future<GuessCoinResult> levelClear(int level, int stars) =>
      _send('level-clear', {'level': level, 'stars': stars, 'answeredAt': _now()});

  static Future<GuessCoinResult> _send(String path, Map<String, dynamic> data) async {
    final body = jsonEncode(data);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return const GuessCoinResult();
      final response = await _post(token, path, body);
      if (response.statusCode == 200) {
        final j = jsonDecode(utf8.decode(response.bodyBytes));
        final coins = j is Map && j['coinsAwarded'] is int ? j['coinsAwarded'] as int : 0;
        final already = j is Map && j['alreadyRewardedToday'] == true;
        if (j is Map) CoinBalance.set(j['balance']);
        unawaited(flush());
        return GuessCoinResult(coins: coins, alreadyToday: already);
      }
      if (response.statusCode >= 500) {
        await _enqueue(path, body);
        return const GuessCoinResult(pending: true);
      }
      return const GuessCoinResult();
    } catch (_) {
      await _enqueue(path, body);
      return const GuessCoinResult(pending: true);
    }
  }

  static Future<void> _enqueue(String path, String body) async {
    try {
      final key = await _queueKey();
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(key) ?? <String>[];
      queue.add(jsonEncode({'path': path, 'body': body}));
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
        int status = 400;
        try {
          final item = jsonDecode(queue.first);
          if (item is Map && item['path'] is String && item['body'] is String) {
            status = (await _post(token, item['path'] as String, item['body'] as String)).statusCode;
          }
        } on FormatException {
          status = 400; // broken entry: drop it
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

/// Buys "สร้างมอนสเตอร์" items with the account's real coins
/// (POST /api/games/monster/buy). Needs the internet: coins are on the server.
class MonsterShop {
  MonsterShop._();

  /// ok = bought; otherwise [error] is a message to show the child.
  static Future<({bool ok, String? error})> buy(String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
        return (ok: false, error: 'กรุณาเข้าสู่ระบบก่อนนะ');
      }
      final response = await http
          .post(
            Uri.parse('${ApiConfig.api}/games/monster/buy'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'item': itemId}),
          )
          .timeout(const Duration(seconds: 8));
      final j = jsonDecode(utf8.decode(response.bodyBytes));
      if (j is Map) CoinBalance.set(j['balance']);
      if (response.statusCode == 200) return (ok: true, error: null);
      if (response.statusCode == 409) return (ok: false, error: 'เหรียญยังไม่พอ ลองเล่นเก็บเหรียญเพิ่มนะ');
      return (ok: false, error: 'ซื้อไม่สำเร็จ ลองใหม่อีกครั้งนะ');
    } catch (_) {
      return (ok: false, error: 'ต้องต่ออินเทอร์เน็ตก่อนซื้อนะ');
    }
  }
}

/// The signed-in account's name (from the profile), used as the hero's name.
/// Kept on the phone per account so it shows at once and offline.
class AccountName {
  AccountName._();

  static Future<String?> _key() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor('account_name', userId);
  }

  /// Last known name on this phone, or null.
  static Future<String?> cached() async {
    try {
      final key = await _key();
      if (key == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(key);
      return name == null || name.trim().isEmpty ? null : name.trim();
    } catch (_) {
      return null;
    }
  }

  /// The name from the server (null when offline).
  static Future<String?> refresh() async {
    try {
      final profile = await ProfileApiService.getProfile();
      final key = await _key();
      if (key != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, profile.name);
      }
      return profile.name;
    } catch (_) {
      return null;
    }
  }
}

/// A "สร้างมอนสเตอร์" level left between two monsters.
class MonsterRound {
  const MonsterRound({
    required this.wave,
    required this.heroHp,
    required this.correct,
    required this.coins,
  });

  /// The monster to fight next (2 = the second one).
  final int wave;
  final int heroHp;

  /// Words answered right so far in this level.
  final int correct;

  /// Coins earned so far in this level.
  final int coins;

  Map<String, dynamic> toJson() => {'wave': wave, 'heroHp': heroHp, 'correct': correct, 'coins': coins};

  static MonsterRound? fromJson(dynamic j, {required int waves, required int maxHp}) {
    if (j is! Map) return null;
    final wave = j['wave'];
    final hp = j['heroHp'];
    final correct = j['correct'];
    final coins = j['coins'];
    if (wave is! int || hp is! int || correct is! int || coins is! int) return null;
    if (wave < 2 || wave > waves || hp < 1 || hp > maxHp) return null;
    if (correct < 0 || coins < 0 || coins > correct * 3) return null;
    return MonsterRound(wave: wave, heroHp: hp, correct: correct, coins: coins);
  }
}

/// Levels left in the middle, per account, on the phone and on the server
/// (/api/games/monster/resume), so the child can go on after reinstalling the
/// app or on another phone. The newer change wins.
class MonsterResume {
  MonsterResume._();

  static const Duration _timeout = Duration(seconds: 8);
  static Future<void>? _flushing;

  static Future<String?> _key(int level) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor('monster_resume_$level', userId);
  }

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor('monster_resume_queue', userId);
  }

  static Future<MonsterRound?> load(int level, {required int waves, required int maxHp}) async {
    try {
      final key = await _key(level);
      if (key == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final j = jsonDecode(prefs.getString(key) ?? 'null');
      if (j is! Map || j['cleared'] == true) return null;
      return MonsterRound.fromJson(j, waves: waves, maxHp: maxHp);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(int level, MonsterRound round) => _write(level, round.toJson());

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
                    Uri.parse('${ApiConfig.api}/games/monster/resume/${entry.key}'),
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
            Uri.parse('${ApiConfig.api}/games/monster/resume'),
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
        if (level < 1 || level > 40 || unsent.containsKey('$level')) continue;
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
