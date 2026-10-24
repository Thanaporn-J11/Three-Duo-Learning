import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'coin_balance.dart';
import 'guess_progress_service.dart' show GuessCoinResult;
import 'user_account_preferences.dart';

/// An unfinished "เสียงสัตว์" game.
class AnimalSoundRound {
  const AnimalSoundRound({
    required this.order,
    required this.options,
    required this.index,
    required this.correct,
    required this.coins,
  });

  /// Animals (e.g. 'LION') in the shuffled order of this game.
  final List<String> order;

  /// The 3 choices shown for each question (the right one included).
  final List<List<String>> options;

  /// Next question to play (0-based); questions before it are answered.
  final int index;
  final int correct;
  final int coins;

  Map<String, dynamic> toServer() => {
    'order': order,
    'options': options,
    'index': index,
    'correct': correct,
    'coins': coins,
  };

  static AnimalSoundRound? fromJson(dynamic j, Set<String> animals) {
    if (j is! Map) return null;
    final order = (j['order'] as List?)?.whereType<String>().toList();
    final rawOptions = j['options'];
    final index = j['index'];
    final correct = j['correct'];
    final coins = j['coins'];
    if (order == null ||
        rawOptions is! List ||
        index is! int ||
        correct is! int ||
        coins is! int ||
        order.length != animals.length ||
        order.toSet().length != order.length ||
        !order.every(animals.contains) ||
        rawOptions.length != order.length) {
      return null;
    }
    final options = <List<String>>[];
    for (int i = 0; i < rawOptions.length; i++) {
      final o = rawOptions[i];
      if (o is! List) return null;
      final list = o.whereType<String>().toList();
      if (list.length != 3 ||
          list.toSet().length != 3 ||
          !list.every(animals.contains) ||
          !list.contains(order[i])) {
        return null;
      }
      options.add(list);
    }
    if (index < 1 || index >= order.length) return null;
    if (correct < 0 || correct > index) return null;
    if (coins < 0 || coins > correct * kGameCoinsPerWord) return null;
    return AnimalSoundRound(
      order: order,
      options: options,
      index: index,
      correct: correct,
      coins: coins,
    );
  }
}

/// Where the child is in "เสียงสัตว์" (per account), on the phone and on the
/// server (/api/games/animalsound/progress), so the game can be continued
/// after reinstalling the app or on another phone. The newer change wins.
class AnimalSoundProgress {
  AnimalSoundProgress._();

  static const String category = 'all';
  static const Duration _timeout = Duration(seconds: 8);
  static Future<void>? _flushing;

  static Future<String?> _key(String base) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? null : UserAccountPreferences.keyFor(base, userId);
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static Future<AnimalSoundRound?> load(Set<String> animals) async {
    try {
      final key = await _key('animalsound_round');
      if (key == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return AnimalSoundRound.fromJson(jsonDecode(raw), animals);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(AnimalSoundRound round) async {
    final at = _now();
    try {
      final key = await _key('animalsound_round');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode({...round.toServer(), 'updatedAt': at}));
    } catch (_) {}
    await _enqueue({'round': round.toServer(), 'updatedAt': at});
  }

  /// No unfinished game (kept as a dated mark so an older server copy
  /// doesn't come back).
  static Future<void> clear() => _finish(null);

  /// The game was finished with [percent] right answers.
  static Future<void> saveFinished(int percent) => _finish(percent);

  static Future<void> _finish(int? percent) async {
    final at = _now();
    try {
      final key = await _key('animalsound_round');
      if (key != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, jsonEncode({'cleared': true, 'updatedAt': at}));
        if (percent != null) {
          final bestKey = await _key('animalsound_best');
          if (bestKey != null && (prefs.getInt(bestKey) ?? -1) < percent) {
            await prefs.setInt(bestKey, percent);
          }
        }
      }
    } catch (_) {}
    await _enqueue({
      'round': null,
      if (percent != null) 'best': percent,
      'updatedAt': at,
    });
  }

  static Future<void> _enqueue(Map<String, dynamic> body) async {
    try {
      final key = await _key('animalsound_sync_queue');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final old = prefs.getString(key);
      if (old != null) {
        final oldBest = (jsonDecode(old) as Map?)?['best'];
        final newBest = body['best'];
        if (oldBest is int && (newBest is! int || oldBest > newBest)) {
          body = {...body, 'best': oldBest}; // never lose an unsent best score
        }
      }
      await prefs.setString(key, jsonEncode(body));
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
      final key = await _key('animalsound_sync_queue');
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return;
      final sent = prefs.getString(key);
      if (sent == null) return;
      final int status;
      try {
        status = (await http
                .put(
                  Uri.parse('${ApiConfig.api}/games/animalsound/progress/$category'),
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
        return; // offline
      }
      // Remove only if nothing newer was saved while sending.
      if ((status == 200 || status == 400) && prefs.getString(key) == sent) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  /// Sends local changes, then takes the server copy if it is newer
  /// (e.g. after reinstalling the app or played on another phone).
  static Future<void> sync() async {
    await flush();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final queueKey = await _key('animalsound_sync_queue');
      final roundKey = await _key('animalsound_round');
      final bestKey = await _key('animalsound_best');
      if (token == null || token.isEmpty || queueKey == null || roundKey == null) return;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/games/animalsound/progress'),
            headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final cats = body is Map ? body['categories'] : null;
      final server = cats is Map ? cats[category] : null;
      if (server is! Map) return;
      final serverBest = server['best'];
      if (bestKey != null &&
          serverBest is int &&
          serverBest > (prefs.getInt(bestKey) ?? -1)) {
        await prefs.setInt(bestKey, serverBest);
      }
      if (prefs.getString(queueKey) != null) return; // the phone's copy is newer
      final serverAt = DateTime.tryParse(server['updatedAt']?.toString() ?? '');
      if (serverAt == null) return;
      DateTime? localAt;
      try {
        final local = jsonDecode(prefs.getString(roundKey) ?? 'null');
        if (local is Map) localAt = DateTime.tryParse(local['updatedAt']?.toString() ?? '');
      } catch (_) {}
      if (localAt != null && !serverAt.isAfter(localAt)) return;
      final round = server['round'];
      final at = serverAt.toUtc().toIso8601String();
      await prefs.setString(
        roundKey,
        jsonEncode(
          round is Map
              ? {...Map<String, dynamic>.from(round), 'updatedAt': at}
              : {'cleared': true, 'updatedAt': at},
        ),
      );
    } catch (_) {}
  }
}

/// Sends right answers to the server (POST /api/games/animalsound/answer):
/// coins once per animal per day, like the other word games. Answers given
/// offline are queued and sent later.
class AnimalSoundCoins {
  AnimalSoundCoins._();

  static const Duration _timeout = Duration(seconds: 5);
  static Future<void>? _flushing;

  static Future<String?> _queueKey() async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('animalsound_coin_queue', userId);
  }

  static Future<http.Response> _post(String token, String body) => http
      .post(
        Uri.parse('${ApiConfig.api}/games/animalsound/answer'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      )
      .timeout(_timeout);

  static Future<GuessCoinResult> submit(String word) async {
    final body = jsonEncode({
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
