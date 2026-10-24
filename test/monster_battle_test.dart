import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/coin_balance.dart';
import 'package:threeduo_learning/services/monster_battle_service.dart';

import 'test_helpers.dart';

const String stateKey = 'monster_state_user_1';
const String pendingKey = 'monster_state_pending_user_1';
const String coinQueueKey = 'monster_coin_queue_user_1';
const String resumeQueueKey = 'monster_resume_queue_user_1';

String resumeKey(int level) => 'monster_resume_${level}_user_1';

Future<List<String>> strings(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(key) ?? <String>[];
}

Map<String, Object?> roundJson({
  Object? wave = 2,
  Object? heroHp = 3,
  Object? correct = 2,
  Object? coins = 6,
  String? updatedAt,
}) => <String, Object?>{
  'wave': wave,
  'heroHp': heroHp,
  'correct': correct,
  'coins': coins,
  if (updatedAt != null) 'updatedAt': updatedAt,
};

Future<MonsterRound?> loadRound(int level) =>
    MonsterResume.load(level, waves: 5, maxHp: 3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    signIn();
    CoinBalance.clear();
  });

  group('MonsterStateSync', () {
    final state = <String, dynamic>{
      'gold': 50,
      'stars': <int>[3, 2],
    };

    Future<void> settle() async {
      await MonsterStateSync.flush();
      await pumpEventQueue();
    }

    Future<bool> pending() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(pendingKey) ?? false;
    }

    test('nothing is saved yet', () async {
      expect(await MonsterStateSync.loadLocal(), isNull);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await MonsterStateSync.loadLocal(), isNull);
    });

    test('ignores damaged saved state', () async {
      for (final raw in <String>['{{{', '[1]', '{"data": 5}']) {
        signIn(<String, Object>{stateKey: raw});
        expect(await MonsterStateSync.loadLocal(), isNull, reason: raw);
      }
    });

    test('state is saved on the phone and sent to the server', () async {
      http.Request? sent;

      await withServer(() async {
        await MonsterStateSync.save(state);
        await settle();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      expect(await MonsterStateSync.loadLocal(), state);
      expect(sent!.method, 'PUT');
      expect(sent!.url.path, '/api/games/monster/state');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['data'], state);
      expect(body['updatedAt'], isA<String>());
      expect(await pending(), isFalse);
    });

    test('state that could not be sent stays pending', () async {
      for (final handler in <Handler>[
        offline,
        (_) async => jsonResponse(<String, Object?>{}, 500),
      ]) {
        signIn();
        await withServer(() async {
          await MonsterStateSync.save(state);
          await settle();
        }, handler);

        expect(await pending(), isTrue);
        expect(await MonsterStateSync.loadLocal(), state);
      }
    });

    test('state the server refuses is not sent again', () async {
      await withServer(() async {
        await MonsterStateSync.save(state);
        await settle();
      }, (_) async => jsonResponse(<String, Object?>{}, 400));

      expect(await pending(), isFalse);
    });

    test('signed out: nothing is stored or sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(() async {
        await MonsterStateSync.save(state);
        await settle();
      }, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
      expect(await MonsterStateSync.loadLocal(), isNull);
    });

    test('flush sends nothing when there is nothing pending', () async {
      var called = false;
      Future<http.Response> handler(http.Request _) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      }

      await withServer(MonsterStateSync.flush, handler);
      signIn(<String, Object>{pendingKey: true});
      await withServer(MonsterStateSync.flush, handler);

      expect(called, isFalse);
    });

    group('claimOldProgress', () {
      test('nothing old to bring over', () async {
        expect(await MonsterStateSync.claimOldProgress(), isNull);
      });

      test('signed out brings nothing', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'mb_gold': 5,
        });

        expect(await MonsterStateSync.claimOldProgress(), isNull);
      });

      test('old progress goes to the first child, once', () async {
        signIn(<String, Object>{
          'mb_stars': <String>['3', 'x', '9', '2'],
          'mb_gold': 50,
          'mb_item_hint': 1,
          'mb_kills': 7,
          'mb_last_daily': '2026-01-01',
        });

        final old = await MonsterStateSync.claimOldProgress();

        expect(old!['gold'], 50);
        final stars = old['stars'] as List;
        expect(stars, hasLength(40));
        expect(stars.take(5).toList(), <int>[3, 0, 3, 2, 0]);
        expect(old['items'], <String, int>{
          'hint': 1,
          'freeze': 3,
          'smoke': 2,
          'shield': 2,
        });
        expect(old['kills'], 7);
        expect(old['bossKills'], 0);
        expect(old['bestCombo'], 0);
        expect(old['dailyStreak'], 0);
        expect(old['lastDaily'], '2026-01-01');
        expect(await MonsterStateSync.claimOldProgress(), isNull);
      });

      test('gold alone is enough to bring progress over', () async {
        signIn(<String, Object>{'mb_gold': 10});

        final old = await MonsterStateSync.claimOldProgress();

        expect(old!['gold'], 10);
        expect((old['stars'] as List).every((s) => s == 0), isTrue);
      });

      test('old progress is not given to a second child', () async {
        signIn(<String, Object>{'mb_gold': 10, 'monster_old_owner': '2'});

        expect(await MonsterStateSync.claimOldProgress(), isNull);
      });
    });

    group('pull', () {
      Handler server(Object? body, {int status = 200}) =>
          (request) async => jsonResponse(body, status);

      Map<String, Object?> serverState({
        String updatedAt = '2030-01-01T00:00:00.000Z',
      }) => <String, Object?>{
        'data': <String, Object?>{'gold': 99},
        'updatedAt': updatedAt,
      };

      test('takes a newer state from the server', () async {
        signIn(<String, Object>{
          stateKey: jsonEncode(<String, Object?>{
            'data': <String, Object?>{'gold': 1},
            'updatedAt': '2020-01-01T00:00:00.000Z',
          }),
        });

        final data = await withServer(
          MonsterStateSync.pull,
          server(serverState()),
        );

        expect(data, <String, dynamic>{'gold': 99});
        expect(await MonsterStateSync.loadLocal(), <String, dynamic>{
          'gold': 99,
        });
      });

      test('takes the server state when there is none on the phone', () async {
        final data = await withServer(
          MonsterStateSync.pull,
          server(serverState()),
        );

        expect(data, isNotNull);
      });

      test('keeps the phone when it is newer or the same age', () async {
        for (final at in <String>[
          '2031-01-01T00:00:00.000Z',
          '2030-01-01T00:00:00.000Z',
        ]) {
          signIn(<String, Object>{
            stateKey: jsonEncode(<String, Object?>{
              'data': <String, Object?>{'gold': 1},
              'updatedAt': at,
            }),
          });

          final data = await withServer(
            MonsterStateSync.pull,
            server(serverState()),
          );

          expect(data, isNull, reason: at);
          expect(await MonsterStateSync.loadLocal(), <String, dynamic>{
            'gold': 1,
          });
        }
      });

      test('keeps the phone when its changes could not be sent', () async {
        signIn(<String, Object>{
          stateKey: jsonEncode(<String, Object?>{
            'data': <String, Object?>{'gold': 1},
            'updatedAt': '2020-01-01T00:00:00.000Z',
          }),
          pendingKey: true,
        });
        var gets = 0;

        final data = await withServer(MonsterStateSync.pull, (request) async {
          if (request.method == 'GET') gets++;
          return jsonResponse(<String, Object?>{}, 500);
        });

        expect(data, isNull);
        expect(gets, 0);
      });

      test('ignores a server that cannot answer or answers oddly', () async {
        for (final handler in <Handler>[
          server(serverState(), status: 500),
          offline,
          server(<int>[1]),
          server(<String, Object?>{'data': 5, 'updatedAt': '2030-01-01'}),
          server(<String, Object?>{'data': <String, Object?>{}}),
          server(serverState(updatedAt: 'never')),
        ]) {
          signIn();
          expect(await withServer(MonsterStateSync.pull, handler), isNull);
        }
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        final data = await withServer(MonsterStateSync.pull, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(data, isNull);
        expect(called, isFalse);
      });
    });
  });

  group('MonsterCoins', () {
    test('a right word gives coins and updates the balance', () async {
      http.Request? sent;

      final result = await withServer(() => MonsterCoins.submit('cat'), (
        request,
      ) async {
        sent = request;
        return jsonResponse(<String, Object?>{
          'coinsAwarded': 3,
          'balance': 60,
        });
      });

      expect(result.coins, 3);
      expect(result.alreadyToday, isFalse);
      expect(CoinBalance.value.value, 60);
      expect(sent!.url.path, '/api/games/monster/answer');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['word'], 'cat');
      expect(body['answeredAt'], isA<String>());
    });

    test('a cleared level gives coins for its stars', () async {
      http.Request? sent;

      final result = await withServer(() => MonsterCoins.levelClear(4, 3), (
        request,
      ) async {
        sent = request;
        return jsonResponse(<String, Object?>{'coinsAwarded': 15});
      });

      expect(result.coins, 15);
      expect(sent!.url.path, '/api/games/monster/level-clear');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['level'], 4);
      expect(body['stars'], 3);
    });

    test('something that already paid today gives nothing more', () async {
      final result = await withServer(
        () => MonsterCoins.submit('cat'),
        (_) async => jsonResponse(<String, Object?>{
          'alreadyRewardedToday': true,
        }),
      );

      expect(result.coins, 0);
      expect(result.alreadyToday, isTrue);
    });

    test('a reply that is not an object gives nothing', () async {
      final result = await withServer(
        () => MonsterCoins.submit('cat'),
        (_) async => jsonResponse(<int>[1]),
      );

      expect(result.coins, 0);
      expect(result.pending, isFalse);
    });

    test('signed out: nothing is sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      final result = await withServer(() => MonsterCoins.submit('cat'), (
        _,
      ) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
      expect(result.pending, isFalse);
    });

    test('a server error or no network saves it for later', () async {
      for (final handler in <Handler>[
        (_) async => jsonResponse(<String, Object?>{}, 503),
        offline,
      ]) {
        signIn();
        final result = await withServer(
          () => MonsterCoins.levelClear(1, 2),
          handler,
        );

        expect(result.pending, isTrue);
        final queue = await strings(coinQueueKey);
        expect(queue, hasLength(1));
        final item = jsonDecode(queue.single) as Map<String, dynamic>;
        expect(item['path'], 'level-clear');
        expect(jsonDecode(item['body'] as String)['level'], 1);
      }
    });

    test('something the server refuses is not saved', () async {
      for (final status in <int>[400, 401]) {
        signIn();
        final result = await withServer(
          () => MonsterCoins.submit('cat'),
          (_) async => jsonResponse(<String, Object?>{}, status),
        );

        expect(result.pending, isFalse);
        expect(await strings(coinQueueKey), isEmpty);
      }
    });

    test('keeps only the newest 300 saved items', () async {
      signIn(<String, Object>{
        coinQueueKey: <String>[for (var i = 0; i < 300; i++) '{"n":$i}'],
      });

      await withServer(() => MonsterCoins.submit('cat'), offline);

      final saved = await strings(coinQueueKey);
      expect(saved, hasLength(300));
      expect(saved.first, '{"n":1}');
    });

    test('flush sends each saved item to its own address', () async {
      signIn(<String, Object>{
        coinQueueKey: <String>[
          jsonEncode(<String, String>{'path': 'answer', 'body': '{"n":1}'}),
          jsonEncode(<String, String>{'path': 'level-clear', 'body': '{"n":2}'}),
        ],
      });
      final sent = <String>[];

      await withServer(MonsterCoins.flush, (request) async {
        if (request.method == 'POST') {
          sent.add('${request.url.path} ${request.body}');
          return jsonResponse(<String, Object?>{});
        }
        return jsonResponse(<String, Object?>{'balance': 9});
      });
      await pumpEventQueue();

      expect(sent, <String>[
        '/api/games/monster/answer {"n":1}',
        '/api/games/monster/level-clear {"n":2}',
      ]);
      expect(await strings(coinQueueKey), isEmpty);
    });

    test('flush drops broken items without asking the server', () async {
      signIn(<String, Object>{
        coinQueueKey: <String>[
          'not json',
          jsonEncode(<String, Object?>{'path': 1, 'body': 2}),
          jsonEncode(<int>[1]),
        ],
      });
      var called = false;

      await withServer(MonsterCoins.flush, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
      expect(await strings(coinQueueKey), isEmpty);
    });

    test('flush drops refused items and stops on errors', () async {
      Future<void> run(Handler handler) async {
        signIn(<String, Object>{
          coinQueueKey: <String>[
            jsonEncode(<String, String>{'path': 'answer', 'body': '{}'}),
            jsonEncode(<String, String>{'path': 'answer', 'body': '{}'}),
          ],
        });
        await withServer(MonsterCoins.flush, handler);
      }

      await run((_) async => jsonResponse(<String, Object?>{}, 400));
      expect(await strings(coinQueueKey), isEmpty);

      await run((_) async => jsonResponse(<String, Object?>{}, 500));
      expect(await strings(coinQueueKey), hasLength(2));

      await run(offline);
      expect(await strings(coinQueueKey), hasLength(2));
    });

    test('flush does nothing when signed out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(MonsterCoins.flush, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });
  });

  group('MonsterShop', () {
    test('buying an item uses the server and updates the balance', () async {
      http.Request? sent;

      final result = await withServer(() => MonsterShop.buy('hint'), (
        request,
      ) async {
        sent = request;
        return jsonResponse(<String, Object?>{'balance': 20});
      });

      expect(result.ok, isTrue);
      expect(result.error, isNull);
      expect(CoinBalance.value.value, 20);
      expect(sent!.url.path, '/api/games/monster/buy');
      expect(jsonDecode(sent!.body), <String, Object?>{'item': 'hint'});
    });

    test('too few coins gets a friendly message', () async {
      final result = await withServer(
        () => MonsterShop.buy('hint'),
        (_) async => jsonResponse(<String, Object?>{'balance': 1}, 409),
      );

      expect(result.ok, isFalse);
      expect(result.error, contains('เหรียญยังไม่พอ'));
      expect(CoinBalance.value.value, 1);
    });

    test('other refusals get a retry message', () async {
      final result = await withServer(
        () => MonsterShop.buy('hint'),
        (_) async => jsonResponse(<String, Object?>{}, 500),
      );

      expect(result.ok, isFalse);
      expect(result.error, contains('ซื้อไม่สำเร็จ'));
    });

    test('no network asks to connect', () async {
      final result = await withServer(() => MonsterShop.buy('hint'), offline);

      expect(result.ok, isFalse);
      expect(result.error, contains('อินเทอร์เน็ต'));
    });

    test('signed out asks to sign in', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      final result = await withServer(() => MonsterShop.buy('hint'), (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
      expect(result.ok, isFalse);
      expect(result.error, contains('เข้าสู่ระบบ'));
    });
  });

  group('AccountName', () {
    test('no name is known at first', () async {
      expect(await AccountName.cached(), isNull);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await AccountName.cached(), isNull);
    });

    test('a saved name is trimmed, a blank one is ignored', () async {
      signIn(<String, Object>{'account_name_user_1': '  Mali '});
      expect(await AccountName.cached(), 'Mali');

      signIn(<String, Object>{'account_name_user_1': '   '});
      expect(await AccountName.cached(), isNull);
    });

    test('refresh takes the name from the profile and keeps it', () async {
      final name = await withServer(
        AccountName.refresh,
        (_) async => jsonResponse(<String, Object?>{
          'profile': <String, Object?>{'name': 'Mali', 'email': 'm@example.test'},
        }),
      );

      expect(name, 'Mali');
      expect(await AccountName.cached(), 'Mali');
    });

    test('refresh gives nothing when offline and keeps the old name', () async {
      signIn(<String, Object>{'account_name_user_1': 'Old'});

      expect(await withServer(AccountName.refresh, offline), isNull);
      expect(await AccountName.cached(), 'Old');
    });
  });

  group('MonsterRound', () {
    test('reads a valid round and writes it back the same', () {
      final round = MonsterRound.fromJson(roundJson(), waves: 5, maxHp: 3)!;

      expect(round.wave, 2);
      expect(round.heroHp, 3);
      expect(round.correct, 2);
      expect(round.coins, 6);
      expect(round.toJson(), <String, Object?>{
        'wave': 2,
        'heroHp': 3,
        'correct': 2,
        'coins': 6,
      });
    });

    test('rejects a round that does not fit the level', () {
      final bad = <String, Object?>{
        'not an object': 'x',
        'first monster': roundJson(wave: 1),
        'past the last monster': roundJson(wave: 6),
        'no hero health': roundJson(heroHp: 0),
        'too much hero health': roundJson(heroHp: 4),
        'negative correct': roundJson(correct: -1),
        'negative coins': roundJson(coins: -1),
        'too many coins': roundJson(coins: 7),
        'wave is not a number': roundJson(wave: 'x'),
        'coins is not a number': roundJson(coins: 'x'),
        'missing field': <String, Object?>{'wave': 2},
      };

      for (final entry in bad.entries) {
        expect(
          MonsterRound.fromJson(entry.value, waves: 5, maxHp: 3),
          isNull,
          reason: entry.key,
        );
      }
    });
  });

  group('MonsterResume', () {
    Future<void> settle() async {
      await MonsterResume.flush();
      await pumpEventQueue();
      await MonsterResume.flush();
      await pumpEventQueue();
    }

    const round = MonsterRound(wave: 2, heroHp: 3, correct: 2, coins: 6);

    test('a level left in the middle is saved and sent', () async {
      http.Request? sent;

      await withServer(() async {
        await MonsterResume.save(5, round);
        await settle();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      final loaded = await loadRound(5);
      expect(loaded!.wave, 2);
      expect(loaded.coins, 6);
      expect(sent!.method, 'PUT');
      expect(sent!.url.path, '/api/games/monster/resume/5');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['round']['heroHp'], 3);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(resumeQueueKey), '{}');
    });

    test('a round that does not fit the level is not loaded', () async {
      await withServer(() => MonsterResume.save(5, round), offline);

      expect(await MonsterResume.load(5, waves: 1, maxHp: 3), isNull);
    });

    test('nothing is stored when signed out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await withServer(() async {
        await MonsterResume.save(5, round);
        await settle();
      }, offline);

      expect(await loadRound(5), isNull);
    });

    test('changes made offline wait to be sent', () async {
      await withServer(() async {
        await MonsterResume.save(5, round);
        await settle();
      }, offline);

      final prefs = await SharedPreferences.getInstance();
      final queue = jsonDecode(prefs.getString(resumeQueueKey)!) as Map;
      expect(queue.keys, <String>['5']);
    });

    test('clear leaves a mark and tells the server', () async {
      final bodies = <Map<String, dynamic>>[];

      await withServer(() async {
        await MonsterResume.save(5, round);
        await MonsterResume.clear(5);
        await settle();
      }, (request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return jsonResponse(<String, Object?>{});
      });

      expect(await loadRound(5), isNull);
      expect(bodies.last['round'], isNull);
    });

    test('a damaged saved level is ignored', () async {
      final bad = <String, Object>{
        'not json': '{{{',
        'not an object': jsonEncode(<int>[1]),
        'cleared': jsonEncode(<String, Object?>{'cleared': true}),
        'unusable round': jsonEncode(roundJson(wave: 1)),
      };

      for (final entry in bad.entries) {
        signIn(<String, Object>{resumeKey(5): entry.value});
        expect(await loadRound(5), isNull, reason: entry.key);
      }
    });

    group('flush', () {
      final entry = <String, Object?>{
        '5': <String, Object?>{
          'round': null,
          'updatedAt': '2020-01-01T00:00:00.000Z',
        },
      };

      Future<Map> run(Handler handler, Object queue) async {
        signIn(<String, Object>{resumeQueueKey: jsonEncode(queue)});
        await withServer(MonsterResume.flush, handler);
        final prefs = await SharedPreferences.getInstance();
        return jsonDecode(prefs.getString(resumeQueueKey)!) as Map;
      }

      test('removes what the server accepted or refused', () async {
        expect(
          await run((_) async => jsonResponse(<String, Object?>{}), entry),
          isEmpty,
        );
        expect(
          await run((_) async => jsonResponse(<String, Object?>{}, 400), entry),
          isEmpty,
        );
      });

      test('keeps what could not be sent', () async {
        expect(
          await run((_) async => jsonResponse(<String, Object?>{}, 500), entry),
          hasLength(1),
        );
        expect(await run(offline, entry), hasLength(1));
      });

      test('an empty or damaged queue, or signed out, sends nothing', () async {
        var called = false;
        Future<http.Response> handler(http.Request _) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        }

        await run(handler, <String, Object?>{});
        signIn(<String, Object>{resumeQueueKey: '{{{'});
        await withServer(MonsterResume.flush, handler);
        signIn(<String, Object>{resumeQueueKey: jsonEncode(<int>[1])});
        await withServer(MonsterResume.flush, handler);
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await withServer(MonsterResume.flush, handler);

        expect(called, isFalse);
      });
    });

    group('sync', () {
      Handler server(Object? body, {int status = 200, int putStatus = 200}) =>
          (request) async {
            if (request.method == 'PUT') {
              return jsonResponse(<String, Object?>{}, putStatus);
            }
            return jsonResponse(body, status);
          };

      Map<String, Object?> serverLevel({
        Object? round = 'use-valid',
        String updatedAt = '2030-01-01T00:00:00.000Z',
        int level = 5,
      }) => <String, Object?>{
        'level': level,
        'updatedAt': updatedAt,
        'round': round == 'use-valid' ? roundJson(correct: 3, coins: 9) : round,
      };

      Future<Map?> stored(int level) async {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(resumeKey(level));
        return raw == null ? null : jsonDecode(raw) as Map;
      }

      test('takes a newer level from the server', () async {
        signIn(<String, Object>{
          resumeKey(5): jsonEncode(
            roundJson(updatedAt: '2020-01-01T00:00:00.000Z'),
          ),
        });

        await withServer(
          MonsterResume.sync,
          server(<String, Object?>{'levels': <Object?>[serverLevel()]}),
        );

        expect((await loadRound(5))!.coins, 9);
      });

      test('takes a level when there is none on the phone', () async {
        await withServer(
          MonsterResume.sync,
          server(<String, Object?>{'levels': <Object?>[serverLevel()]}),
        );

        expect(await loadRound(5), isNotNull);
      });

      test('keeps the phone copy when it is newer or the same age', () async {
        signIn(<String, Object>{
          resumeKey(5): jsonEncode(
            roundJson(updatedAt: '2031-01-01T00:00:00.000Z'),
          ),
          resumeKey(6): jsonEncode(
            roundJson(updatedAt: '2030-01-01T00:00:00.000Z'),
          ),
        });

        await withServer(
          MonsterResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[serverLevel(), serverLevel(level: 6)],
          }),
        );

        expect((await loadRound(5))!.coins, 6);
        expect((await loadRound(6))!.coins, 6);
      });

      test('does not overwrite a change that has not been sent yet', () async {
        signIn(<String, Object>{
          resumeKey(5): jsonEncode(
            roundJson(updatedAt: '2020-01-01T00:00:00.000Z'),
          ),
          resumeQueueKey: jsonEncode(<String, Object?>{
            '5': <String, Object?>{
              'round': roundJson(),
              'updatedAt': '2020-01-01T00:00:00.000Z',
            },
          }),
        });

        await withServer(
          MonsterResume.sync,
          server(
            <String, Object?>{'levels': <Object?>[serverLevel()]},
            putStatus: 500,
          ),
        );

        expect((await loadRound(5))!.coins, 6);
      });

      test('a level finished on another phone is cleared here', () async {
        signIn(<String, Object>{resumeKey(5): jsonEncode(roundJson())});

        await withServer(
          MonsterResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[serverLevel(round: null)],
          }),
        );

        expect(await loadRound(5), isNull);
        expect((await stored(5))!['cleared'], isTrue);
      });

      test('skips entries it cannot use', () async {
        await withServer(
          MonsterResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[
              'x',
              <String, Object?>{'level': 'x'},
              serverLevel(level: 0),
              serverLevel(level: 41),
              serverLevel(updatedAt: 'never'),
            ],
          }),
        );

        expect(await stored(5), isNull);
        expect(await stored(0), isNull);
        expect(await stored(41), isNull);
      });

      test('ignores a server that cannot answer or answers oddly', () async {
        await withServer(
          MonsterResume.sync,
          server(<String, Object?>{}, status: 500),
        );
        await withServer(MonsterResume.sync, offline);
        await withServer(MonsterResume.sync, server(<int>[1]));
        await withServer(
          MonsterResume.sync,
          server(<String, Object?>{'levels': 'x'}),
        );

        expect(await stored(5), isNull);
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        await withServer(MonsterResume.sync, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
      });
    });
  });
}
