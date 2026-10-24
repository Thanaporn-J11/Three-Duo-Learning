import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/alphabet_train_service.dart';
import 'package:threeduo_learning/services/coin_balance.dart';

import 'test_helpers.dart';

const String starsKey = 'alphabet_stars_user_1';
const String levelQueueKey = 'alphabet_level_queue_user_1';
const String coinQueueKey = 'alphabet_coin_queue_user_1';
const String resumeQueueKey = 'alphabet_resume_queue_user_1';

String resumeKey(int level) => 'alphabet_resume_${level}_user_1';

Future<List<String>> strings(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(key) ?? <String>[];
}

Map<String, Object?> roundJson({
  Object? missing = const <int>[1, 5, 9],
  Object? done = 1,
  Object? remaining = 30,
  Object? coins = 2,
  String? updatedAt,
}) => <String, Object?>{
  'missing': missing,
  'done': done,
  'remaining': remaining,
  'coins': coins,
  if (updatedAt != null) 'updatedAt': updatedAt,
};

AlphabetRound validRound({int coins = 2}) => AlphabetRound(
  missing: const <int>[1, 5, 9],
  done: 1,
  remaining: 30,
  coins: coins,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    signIn();
    CoinBalance.clear();
  });

  group('AlphabetLevels', () {
    test('the next level opens after the last passed one', () {
      expect(AlphabetLevels.unlockedLevel(List<int>.filled(50, 0)), 1);
      expect(AlphabetLevels.unlockedLevel(<int>[3, 0, 0]), 2);
      expect(AlphabetLevels.unlockedLevel(<int>[0, 0, 1, 0, 2, 0]), 6);
      expect(AlphabetLevels.unlockedLevel(List<int>.filled(50, 3)), 50);
    });

    test('stars start at zero and signed-out has none', () async {
      expect(await AlphabetLevels.load(), List<int>.filled(50, 0));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await AlphabetLevels.load(), List<int>.filled(50, 0));
    });

    test('reads saved stars and keeps them between 0 and 3', () async {
      signIn(<String, Object>{starsKey: '1,2,3,9,x,-4'});

      final stars = await AlphabetLevels.load();

      expect(stars.take(6).toList(), <int>[1, 2, 3, 3, 0, 0]);
      expect(stars, hasLength(50));
    });

    test('a passed level is saved and sent to the server', () async {
      http.Request? sent;

      await withServer(() async {
        await AlphabetLevels.record(4, 2);
        await AlphabetLevels.flush();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      expect((await AlphabetLevels.load())[3], 2);
      expect(sent!.url.path, '/api/games/alphabet/level');
      expect(jsonDecode(sent!.body), <String, Object?>{'level': 4, 'stars': 2});
      expect(await strings(levelQueueKey), isEmpty);
    });

    test('fewer stars never replace the best', () async {
      signIn(<String, Object>{starsKey: '0,0,3'});

      await withServer(
        () => AlphabetLevels.record(3, 1),
        (_) async => jsonResponse(<String, Object?>{}),
      );

      expect((await AlphabetLevels.load())[2], 3);
    });

    test('signed out: nothing is stored or sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(() => AlphabetLevels.record(1, 3), (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });

    test('a level that could not be sent waits in the queue', () async {
      for (final handler in <Handler>[
        offline,
        (_) async => jsonResponse(<String, Object?>{}, 503),
      ]) {
        signIn();
        await withServer(() => AlphabetLevels.record(1, 3), handler);

        expect(await strings(levelQueueKey), hasLength(1));
      }
    });

    test('a level the server refuses is not queued', () async {
      for (final status in <int>[400, 401]) {
        signIn();
        await withServer(
          () => AlphabetLevels.record(1, 3),
          (_) async => jsonResponse(<String, Object?>{}, status),
        );

        expect(await strings(levelQueueKey), isEmpty);
      }
    });

    test('keeps only the newest 300 waiting levels', () async {
      signIn(<String, Object>{
        levelQueueKey: <String>[for (var i = 0; i < 300; i++) '{"n":$i}'],
      });

      await withServer(() => AlphabetLevels.record(1, 3), offline);

      final queue = await strings(levelQueueKey);
      expect(queue, hasLength(300));
      expect(queue.first, '{"n":1}');
    });

    test('flush sends waiting levels and removes them', () async {
      signIn(<String, Object>{
        levelQueueKey: <String>['{"n":1}', '{"n":2}'],
      });
      final sent = <Object?>[];

      await withServer(AlphabetLevels.flush, (request) async {
        sent.add((jsonDecode(request.body) as Map)['n']);
        return jsonResponse(<String, Object?>{});
      });

      expect(sent, <Object?>[1, 2]);
      expect(await strings(levelQueueKey), isEmpty);
    });

    test('flush drops refused levels and stops on errors', () async {
      Future<void> run(Handler handler) async {
        signIn(<String, Object>{
          levelQueueKey: <String>['{"n":1}', '{"n":2}'],
        });
        await withServer(AlphabetLevels.flush, handler);
      }

      await run((_) async => jsonResponse(<String, Object?>{}, 400));
      expect(await strings(levelQueueKey), isEmpty);

      await run((_) async => jsonResponse(<String, Object?>{}, 500));
      expect(await strings(levelQueueKey), hasLength(2));

      await run(offline);
      expect(await strings(levelQueueKey), hasLength(2));
    });

    test('flush does nothing when signed out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(AlphabetLevels.flush, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });

    test('old stars from before accounts go to the first child', () async {
      signIn(<String, Object>{
        'level_stars_1': 2,
        'level_stars_5': 3,
        'unlocked_level': 4,
        starsKey: '1,0',
      });

      final stars = await AlphabetLevels.load();

      // Levels the old version unlocked count as passed with one star.
      expect(stars.take(6).toList(), <int>[2, 1, 1, 0, 3, 0]);
      final queue = (await strings(levelQueueKey))
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();
      expect(queue.map((q) => q['level']), <int>[1, 2, 3, 5]);
      expect(queue.every((q) => q['imported'] == true), isTrue);
    });

    test('nothing old to bring over leaves the queue empty', () async {
      await AlphabetLevels.load();

      expect(await strings(levelQueueKey), isEmpty);
    });

    test('old stars are not given to a second child', () async {
      signIn(<String, Object>{
        'level_stars_1': 3,
        'alphabet_old_stars_owner': '2',
      });

      expect(await AlphabetLevels.load(), List<int>.filled(50, 0));
      expect(await strings(levelQueueKey), isEmpty);
    });

    group('sync', () {
      Handler server(Object? body, {int status = 200}) => (request) async {
        if (request.url.path == '/api/games/alphabet/levels') {
          return jsonResponse(body, status);
        }
        return jsonResponse(<String, Object?>{});
      };

      test('takes better stars from the server', () async {
        signIn(<String, Object>{starsKey: '1,3'});

        await withServer(
          AlphabetLevels.sync,
          server(<String, Object?>{
            'stars': <Object?>[3, 2, 4, 'x', null, 1],
          }),
        );

        expect((await AlphabetLevels.load()).take(6).toList(), <int>[
          3,
          3,
          0,
          0,
          0,
          1,
        ]);
      });

      test('keeps the phone when the server has nothing better', () async {
        signIn(<String, Object>{starsKey: '3,3'});

        await withServer(
          AlphabetLevels.sync,
          server(<String, Object?>{
            'stars': <Object?>[1, 1],
          }),
        );

        expect((await AlphabetLevels.load()).take(2).toList(), <int>[3, 3]);
      });

      test('sends waiting levels first', () async {
        signIn(<String, Object>{
          levelQueueKey: <String>['{"n":1}'],
        });
        final calls = <String>[];

        await withServer(AlphabetLevels.sync, (request) async {
          calls.add('${request.method} ${request.url.path}');
          return jsonResponse(<String, Object?>{'stars': <Object?>[]});
        });

        expect(calls.first, 'POST /api/games/alphabet/level');
        expect(calls.last, 'GET /api/games/alphabet/levels');
      });

      test('ignores a server that cannot answer or answers oddly', () async {
        signIn(<String, Object>{starsKey: '1'});

        await withServer(
          AlphabetLevels.sync,
          server(<String, Object?>{}, status: 500),
        );
        await withServer(AlphabetLevels.sync, offline);
        await withServer(AlphabetLevels.sync, server(<int>[1]));
        await withServer(
          AlphabetLevels.sync,
          server(<String, Object?>{'stars': 'x'}),
        );

        expect((await AlphabetLevels.load())[0], 1);
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        await withServer(AlphabetLevels.sync, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
      });
    });
  });

  group('AlphabetCoins', () {
    Future<dynamic> submit() => AlphabetCoins.submit('A');

    test('a right letter gives coins and updates the balance', () async {
      http.Request? sent;

      final result = await withServer(submit, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{
          'coinsAwarded': 2,
          'balance': 40,
        });
      });

      expect(result.coins, 2);
      expect(result.alreadyToday, isFalse);
      expect(CoinBalance.value.value, 40);
      expect(sent!.url.path, '/api/games/alphabet/answer');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['letter'], 'A');
      expect(body['answeredAt'], isA<String>());
    });

    test('a letter that already paid today gives nothing more', () async {
      final result = await withServer(
        submit,
        (_) async => jsonResponse(<String, Object?>{
          'alreadyRewardedToday': true,
          'balance': 40,
        }),
      );

      expect(result.coins, 0);
      expect(result.alreadyToday, isTrue);
    });

    test('a reply that is not an object gives nothing', () async {
      final result = await withServer(submit, (_) async => jsonResponse(<int>[1]));

      expect(result.coins, 0);
      expect(result.pending, isFalse);
    });

    test('signed out: nothing is sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      final result = await withServer(submit, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
      expect(result.pending, isFalse);
    });

    test('a server error or no network saves the answer for later', () async {
      for (final handler in <Handler>[
        (_) async => jsonResponse(<String, Object?>{}, 503),
        offline,
      ]) {
        signIn();
        final result = await withServer(submit, handler);

        expect(result.pending, isTrue);
        expect(await strings(coinQueueKey), hasLength(1));
      }
    });

    test('an answer the server refuses is not saved', () async {
      for (final status in <int>[400, 401]) {
        signIn();
        final result = await withServer(
          submit,
          (_) async => jsonResponse(<String, Object?>{}, status),
        );

        expect(result.pending, isFalse);
        expect(await strings(coinQueueKey), isEmpty);
      }
    });

    test('keeps only the newest 300 saved answers', () async {
      signIn(<String, Object>{
        coinQueueKey: <String>[for (var i = 0; i < 300; i++) '{"n":$i}'],
      });

      await withServer(submit, offline);

      final saved = await strings(coinQueueKey);
      expect(saved, hasLength(300));
      expect(saved.first, '{"n":1}');
    });

    test('flush sends the saved answers and removes them', () async {
      signIn(<String, Object>{
        coinQueueKey: <String>['{"n":1}', '{"n":2}'],
      });
      final sent = <Object?>[];

      await withServer(AlphabetCoins.flush, (request) async {
        if (request.method == 'POST') {
          sent.add((jsonDecode(request.body) as Map)['n']);
          return jsonResponse(<String, Object?>{});
        }
        return jsonResponse(<String, Object?>{'balance': 9});
      });
      await pumpEventQueue();

      expect(sent, <Object?>[1, 2]);
      expect(await strings(coinQueueKey), isEmpty);
    });

    test('flush drops refused answers and stops on errors', () async {
      Future<void> run(Handler handler) async {
        signIn(<String, Object>{
          coinQueueKey: <String>['{"n":1}', '{"n":2}'],
        });
        await withServer(AlphabetCoins.flush, handler);
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

      await withServer(AlphabetCoins.flush, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });
  });

  group('AlphabetRound', () {
    test('reads a valid round and writes it back the same', () {
      final round = AlphabetRound.fromJson(roundJson(), 3)!;

      expect(round.missing, <int>[1, 5, 9]);
      expect(round.done, 1);
      expect(round.remaining, 30);
      expect(round.coins, 2);
      expect(round.toJson(), roundJson());
    });

    test('rejects a round that does not fit the level', () {
      final bad = <String, Object?>{
        'not an object': 'x',
        'wrong number of letters': roundJson(missing: <int>[1, 5]),
        'letter below the board': roundJson(missing: <int>[-1, 5, 9]),
        'letter past the board': roundJson(missing: <int>[1, 5, 26]),
        'not sorted': roundJson(missing: <int>[5, 1, 9]),
        'repeated letter': roundJson(missing: <int>[1, 1, 9]),
        'nothing filled in': roundJson(done: 0, coins: 0),
        'everything filled in': roundJson(done: 3, coins: 6),
        'done is not a number': roundJson(done: 'x'),
        'no time left': roundJson(remaining: 0),
        'too much time': roundJson(remaining: 601),
        'time is not a number': roundJson(remaining: 'x'),
        'negative coins': roundJson(coins: -1),
        'too many coins': roundJson(coins: 3),
        'coins is not a number': roundJson(coins: 'x'),
        'missing is absent': <String, Object?>{
          'done': 1,
          'remaining': 30,
          'coins': 2,
        },
      };

      for (final entry in bad.entries) {
        expect(
          AlphabetRound.fromJson(entry.value, 3),
          isNull,
          reason: entry.key,
        );
      }
    });
  });

  group('AlphabetResume', () {
    Future<void> settle() async {
      await AlphabetResume.flush();
      await pumpEventQueue();
      await AlphabetResume.flush();
      await pumpEventQueue();
    }

    test('a level left in the middle is saved and sent', () async {
      http.Request? sent;

      await withServer(() async {
        await AlphabetResume.save(5, validRound());
        await settle();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      final round = await AlphabetResume.load(5, 3);
      expect(round!.done, 1);
      expect(round.remaining, 30);
      expect(sent!.method, 'PUT');
      expect(sent!.url.path, '/api/games/alphabet/resume/5');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['round']['coins'], 2);
      expect(body['updatedAt'], isA<String>());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(resumeQueueKey), '{}');
    });

    test('a round for a different level size is not loaded', () async {
      await withServer(() => AlphabetResume.save(5, validRound()), offline);

      expect(await AlphabetResume.load(5, 4), isNull);
    });

    test('nothing is stored when signed out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await withServer(() async {
        await AlphabetResume.save(5, validRound());
        await settle();
      }, offline);

      expect(await AlphabetResume.load(5, 3), isNull);
    });

    test('changes made offline wait to be sent', () async {
      await withServer(() async {
        await AlphabetResume.save(5, validRound());
        await settle();
      }, offline);

      final prefs = await SharedPreferences.getInstance();
      final queue = jsonDecode(prefs.getString(resumeQueueKey)!) as Map;
      expect(queue.keys, <String>['5']);
    });

    test('clear leaves a mark and tells the server', () async {
      final bodies = <Map<String, dynamic>>[];

      await withServer(() async {
        await AlphabetResume.save(5, validRound());
        await AlphabetResume.clear(5);
        await settle();
      }, (request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return jsonResponse(<String, Object?>{});
      });

      expect(await AlphabetResume.load(5, 3), isNull);
      expect(bodies.last['round'], isNull);
    });

    test('a damaged saved level is ignored', () async {
      final bad = <String, Object>{
        'not json': '{{{',
        'not an object': jsonEncode(<int>[1]),
        'cleared': jsonEncode(<String, Object?>{'cleared': true}),
        'unusable round': jsonEncode(roundJson(done: 0)),
        'wrong type inside': jsonEncode(roundJson(missing: 'x')),
      };

      for (final entry in bad.entries) {
        signIn(<String, Object>{resumeKey(5): entry.value});
        expect(await AlphabetResume.load(5, 3), isNull, reason: entry.key);
      }
    });

    test('lists the levels that can be continued', () async {
      signIn(<String, Object>{
        resumeKey(2): jsonEncode(roundJson()),
        resumeKey(7): jsonEncode(roundJson()),
        resumeKey(8): jsonEncode(<String, Object?>{'cleared': true}),
        resumeKey(9): jsonEncode(roundJson(missing: <int>[1, 2])),
      });

      expect(await alphabetUnfinishedLevels((_) => 3), <int>{2, 7});
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
        await withServer(AlphabetResume.flush, handler);
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
        await withServer(AlphabetResume.flush, handler);
        signIn(<String, Object>{resumeQueueKey: jsonEncode(<int>[1])});
        await withServer(AlphabetResume.flush, handler);
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await withServer(AlphabetResume.flush, handler);

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
        'round': round == 'use-valid' ? roundJson(done: 2, coins: 4) : round,
      };

      Future<Map?> stored(int level) async {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(resumeKey(level));
        return raw == null ? null : jsonDecode(raw) as Map;
      }

      test('takes a newer level from the server', () async {
        signIn(<String, Object>{
          resumeKey(5): jsonEncode(
            roundJson(coins: 0, updatedAt: '2020-01-01T00:00:00.000Z'),
          ),
        });

        await withServer(
          AlphabetResume.sync,
          server(<String, Object?>{'levels': <Object?>[serverLevel()]}),
        );

        expect((await AlphabetResume.load(5, 3))!.coins, 4);
      });

      test('takes a level when there is none on the phone', () async {
        await withServer(
          AlphabetResume.sync,
          server(<String, Object?>{'levels': <Object?>[serverLevel()]}),
        );

        expect(await AlphabetResume.load(5, 3), isNotNull);
      });

      test('keeps the phone copy when it is newer or the same age', () async {
        signIn(<String, Object>{
          resumeKey(5): jsonEncode(
            roundJson(coins: 0, updatedAt: '2031-01-01T00:00:00.000Z'),
          ),
          resumeKey(6): jsonEncode(
            roundJson(coins: 0, updatedAt: '2030-01-01T00:00:00.000Z'),
          ),
        });

        await withServer(
          AlphabetResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[serverLevel(), serverLevel(level: 6)],
          }),
        );

        expect((await AlphabetResume.load(5, 3))!.coins, 0);
        expect((await AlphabetResume.load(6, 3))!.coins, 0);
      });

      test('does not overwrite a change that has not been sent yet', () async {
        signIn(<String, Object>{
          resumeKey(5): jsonEncode(
            roundJson(coins: 0, updatedAt: '2020-01-01T00:00:00.000Z'),
          ),
          resumeQueueKey: jsonEncode(<String, Object?>{
            '5': <String, Object?>{
              'round': roundJson(coins: 0),
              'updatedAt': '2020-01-01T00:00:00.000Z',
            },
          }),
        });

        await withServer(
          AlphabetResume.sync,
          server(
            <String, Object?>{'levels': <Object?>[serverLevel()]},
            putStatus: 500,
          ),
        );

        expect((await AlphabetResume.load(5, 3))!.coins, 0);
      });

      test('a level finished on another phone is cleared here', () async {
        signIn(<String, Object>{resumeKey(5): jsonEncode(roundJson())});

        await withServer(
          AlphabetResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[serverLevel(round: null)],
          }),
        );

        expect(await AlphabetResume.load(5, 3), isNull);
        expect((await stored(5))!['cleared'], isTrue);
      });

      test('skips entries it cannot use', () async {
        await withServer(
          AlphabetResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[
              'x',
              <String, Object?>{'level': 'x'},
              serverLevel(level: 0),
              serverLevel(level: 51),
              serverLevel(updatedAt: 'never'),
            ],
          }),
        );

        expect(await stored(5), isNull);
        expect(await stored(0), isNull);
        expect(await stored(51), isNull);
      });

      test('ignores a server that cannot answer or answers oddly', () async {
        await withServer(
          AlphabetResume.sync,
          server(<String, Object?>{}, status: 500),
        );
        await withServer(AlphabetResume.sync, offline);
        await withServer(AlphabetResume.sync, server(<int>[1]));
        await withServer(
          AlphabetResume.sync,
          server(<String, Object?>{'levels': 'x'}),
        );

        expect(await stored(5), isNull);
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        await withServer(AlphabetResume.sync, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
      });
    });
  });
}
