import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/bridge_service.dart';
import 'package:threeduo_learning/services/coin_balance.dart';

import 'test_helpers.dart';

const String stateKey = 'bridge_state_user_1';
const String pendingKey = 'bridge_state_pending_user_1';
const String coinQueueKey = 'bridge_coin_queue_user_1';
const String resumeQueueKey = 'bridge_resume_queue_user_1';

String resumeKey(int level) => 'bridge_resume_${level}_user_1';

Future<List<String>> strings(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(key) ?? <String>[];
}

Map<String, Object?> roundJson({
  Object? questions = const <String>['a1', 'b2', 'c3'],
  Object? index = 1,
  Object? hp = 3,
  Object? wrong = 0,
  String? updatedAt,
}) => <String, Object?>{
  'questions': questions,
  'index': index,
  'hp': hp,
  'wrong': wrong,
  if (updatedAt != null) 'updatedAt': updatedAt,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    signIn();
    CoinBalance.clear();
  });

  group('bridgeQuestionId', () {
    test('matches the known FNV-1a values the server also uses', () {
      expect(bridgeQuestionId(''), '811c9dc5');
      expect(bridgeQuestionId('a'), 'e40c292c');
      expect(bridgeQuestionId('foobar'), 'bf9cf968');
    });

    test('is always 8 hex digits and the same for the same sentence', () {
      const sentence = 'ฉันชอบกินข้าว';

      final id = bridgeQuestionId(sentence);

      expect(id, matches(RegExp(r'^[0-9a-f]{8}$')));
      expect(bridgeQuestionId(sentence), id);
      expect(bridgeQuestionId('$sentence '), isNot(id));
    });
  });

  group('BridgeStateSync', () {
    final state = <String, dynamic>{
      'level': 4,
      'stars': <int>[3, 2],
    };

    Future<void> settle() async {
      await BridgeStateSync.flush();
      await pumpEventQueue();
    }

    Future<bool> pending() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(pendingKey) ?? false;
    }

    test('nothing is saved yet', () async {
      expect(await BridgeStateSync.loadLocal(), isNull);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await BridgeStateSync.loadLocal(), isNull);
    });

    test('ignores damaged saved state', () async {
      for (final raw in <String>['{{{', '[1]', '{"data": 5}']) {
        signIn(<String, Object>{stateKey: raw});
        expect(await BridgeStateSync.loadLocal(), isNull, reason: raw);
      }
    });

    test('state is saved on the phone and sent to the server', () async {
      http.Request? sent;

      await withServer(() async {
        await BridgeStateSync.save(state);
        await settle();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      expect(await BridgeStateSync.loadLocal(), state);
      expect(sent!.method, 'PUT');
      expect(sent!.url.path, '/api/games/bridge/state');
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
          await BridgeStateSync.save(state);
          await settle();
        }, handler);

        expect(await pending(), isTrue);
        expect(await BridgeStateSync.loadLocal(), state);
      }
    });

    test('state the server refuses is not sent again', () async {
      await withServer(() async {
        await BridgeStateSync.save(state);
        await settle();
      }, (_) async => jsonResponse(<String, Object?>{}, 400));

      expect(await pending(), isFalse);
    });

    test('signed out: nothing is stored or sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(() async {
        await BridgeStateSync.save(state);
        await settle();
      }, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
      expect(await BridgeStateSync.loadLocal(), isNull);
    });

    test('flush sends nothing when there is nothing pending', () async {
      var called = false;
      Future<http.Response> handler(http.Request _) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      }

      await withServer(BridgeStateSync.flush, handler);
      signIn(<String, Object>{pendingKey: true});
      await withServer(BridgeStateSync.flush, handler);

      expect(called, isFalse);
    });

    group('pull', () {
      Handler server(Object? body, {int status = 200}) =>
          (request) async => jsonResponse(body, status);

      Map<String, Object?> serverState({
        String updatedAt = '2030-01-01T00:00:00.000Z',
      }) => <String, Object?>{
        'data': <String, Object?>{'level': 9},
        'updatedAt': updatedAt,
      };

      test('takes a newer state from the server', () async {
        signIn(<String, Object>{
          stateKey: jsonEncode(<String, Object?>{
            'data': <String, Object?>{'level': 1},
            'updatedAt': '2020-01-01T00:00:00.000Z',
          }),
        });

        final data = await withServer(
          BridgeStateSync.pull,
          server(serverState()),
        );

        expect(data, <String, dynamic>{'level': 9});
        expect(await BridgeStateSync.loadLocal(), <String, dynamic>{
          'level': 9,
        });
      });

      test('takes the server state when there is none on the phone', () async {
        expect(
          await withServer(BridgeStateSync.pull, server(serverState())),
          isNotNull,
        );
      });

      test('keeps the phone when it is newer or the same age', () async {
        for (final at in <String>[
          '2031-01-01T00:00:00.000Z',
          '2030-01-01T00:00:00.000Z',
        ]) {
          signIn(<String, Object>{
            stateKey: jsonEncode(<String, Object?>{
              'data': <String, Object?>{'level': 1},
              'updatedAt': at,
            }),
          });

          final data = await withServer(
            BridgeStateSync.pull,
            server(serverState()),
          );

          expect(data, isNull, reason: at);
          expect(await BridgeStateSync.loadLocal(), <String, dynamic>{
            'level': 1,
          });
        }
      });

      test('keeps the phone when its changes could not be sent', () async {
        signIn(<String, Object>{
          stateKey: jsonEncode(<String, Object?>{
            'data': <String, Object?>{'level': 1},
            'updatedAt': '2020-01-01T00:00:00.000Z',
          }),
          pendingKey: true,
        });
        var gets = 0;

        final data = await withServer(BridgeStateSync.pull, (request) async {
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
          expect(await withServer(BridgeStateSync.pull, handler), isNull);
        }
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        final data = await withServer(BridgeStateSync.pull, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(data, isNull);
        expect(called, isFalse);
      });
    });
  });

  group('BridgeCoins', () {
    Future<dynamic> submit() => BridgeCoins.submit('a1b2c3d4');

    test('a right order gives coins and updates the balance', () async {
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
      expect(sent!.url.path, '/api/games/bridge/answer');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['q'], 'a1b2c3d4');
      expect(body['answeredAt'], isA<String>());
    });

    test('a sentence that already paid today gives nothing more', () async {
      final result = await withServer(
        submit,
        (_) async => jsonResponse(<String, Object?>{
          'alreadyRewardedToday': true,
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

      await withServer(BridgeCoins.flush, (request) async {
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
        await withServer(BridgeCoins.flush, handler);
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

      await withServer(BridgeCoins.flush, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });
  });

  group('BridgeRound', () {
    test('reads a valid round and writes it back the same', () {
      final round = BridgeRound.fromJson(roundJson())!;

      expect(round.questions, <String>['a1', 'b2', 'c3']);
      expect(round.index, 1);
      expect(round.hp, 3);
      expect(round.wrong, 0);
      expect(round.toJson(), <String, Object?>{
        'questions': <String>['a1', 'b2', 'c3'],
        'index': 1,
        'hp': 3,
        'wrong': 0,
      });
    });

    test('rejects a round that does not make sense', () {
      final bad = <String, Object?>{
        'not an object': 'x',
        'only one sentence': roundJson(questions: <String>['a1'], index: 1),
        'sentences that are not text': roundJson(
          questions: <Object?>['a1', 5],
        ),
        'nothing answered yet': roundJson(index: 0),
        'everything answered': roundJson(index: 3),
        'index is not a number': roundJson(index: 'x'),
        'no health left': roundJson(hp: 0),
        'too much health': roundJson(hp: 6),
        'hp is not a number': roundJson(hp: 'x'),
        'negative mistakes': roundJson(wrong: -1),
        'mistakes is not a number': roundJson(wrong: 'x'),
        'missing questions': <String, Object?>{'index': 1, 'hp': 3, 'wrong': 0},
      };

      for (final entry in bad.entries) {
        expect(BridgeRound.fromJson(entry.value), isNull, reason: entry.key);
      }
    });
  });

  group('BridgeResume', () {
    Future<void> settle() async {
      await BridgeResume.flush();
      await pumpEventQueue();
      await BridgeResume.flush();
      await pumpEventQueue();
    }

    const round = BridgeRound(
      questions: <String>['a1', 'b2', 'c3'],
      index: 1,
      hp: 3,
      wrong: 0,
    );

    test('a level left in the middle is saved and sent', () async {
      http.Request? sent;

      await withServer(() async {
        await BridgeResume.save(5, round);
        await settle();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      final loaded = await BridgeResume.load(5);
      expect(loaded!.index, 1);
      expect(loaded.questions, hasLength(3));
      expect(sent!.method, 'PUT');
      expect(sent!.url.path, '/api/games/bridge/resume/5');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['round']['hp'], 3);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(resumeQueueKey), '{}');
    });

    test('nothing is stored when signed out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await withServer(() async {
        await BridgeResume.save(5, round);
        await settle();
      }, offline);

      expect(await BridgeResume.load(5), isNull);
    });

    test('changes made offline wait to be sent', () async {
      await withServer(() async {
        await BridgeResume.save(5, round);
        await settle();
      }, offline);

      final prefs = await SharedPreferences.getInstance();
      final queue = jsonDecode(prefs.getString(resumeQueueKey)!) as Map;
      expect(queue.keys, <String>['5']);
    });

    test('clear leaves a mark and tells the server', () async {
      final bodies = <Map<String, dynamic>>[];

      await withServer(() async {
        await BridgeResume.save(5, round);
        await BridgeResume.clear(5);
        await settle();
      }, (request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return jsonResponse(<String, Object?>{});
      });

      expect(await BridgeResume.load(5), isNull);
      expect(bodies.last['round'], isNull);
    });

    test('a damaged saved level is ignored', () async {
      final bad = <String, Object>{
        'not json': '{{{',
        'not an object': jsonEncode(<int>[1]),
        'cleared': jsonEncode(<String, Object?>{'cleared': true}),
        'unusable round': jsonEncode(roundJson(index: 0)),
      };

      for (final entry in bad.entries) {
        signIn(<String, Object>{resumeKey(5): entry.value});
        expect(await BridgeResume.load(5), isNull, reason: entry.key);
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
        await withServer(BridgeResume.flush, handler);
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
        await withServer(BridgeResume.flush, handler);
        signIn(<String, Object>{resumeQueueKey: jsonEncode(<int>[1])});
        await withServer(BridgeResume.flush, handler);
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await withServer(BridgeResume.flush, handler);

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
        'round': round == 'use-valid' ? roundJson(wrong: 2) : round,
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
          BridgeResume.sync,
          server(<String, Object?>{'levels': <Object?>[serverLevel()]}),
        );

        expect((await BridgeResume.load(5))!.wrong, 2);
      });

      test('takes a level when there is none on the phone', () async {
        await withServer(
          BridgeResume.sync,
          server(<String, Object?>{'levels': <Object?>[serverLevel()]}),
        );

        expect(await BridgeResume.load(5), isNotNull);
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
          BridgeResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[serverLevel(), serverLevel(level: 6)],
          }),
        );

        expect((await BridgeResume.load(5))!.wrong, 0);
        expect((await BridgeResume.load(6))!.wrong, 0);
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
          BridgeResume.sync,
          server(
            <String, Object?>{'levels': <Object?>[serverLevel()]},
            putStatus: 500,
          ),
        );

        expect((await BridgeResume.load(5))!.wrong, 0);
      });

      test('a level finished on another phone is cleared here', () async {
        signIn(<String, Object>{resumeKey(5): jsonEncode(roundJson())});

        await withServer(
          BridgeResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[serverLevel(round: null)],
          }),
        );

        expect(await BridgeResume.load(5), isNull);
        expect((await stored(5))!['cleared'], isTrue);
      });

      test('skips entries it cannot use', () async {
        await withServer(
          BridgeResume.sync,
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
          BridgeResume.sync,
          server(<String, Object?>{}, status: 500),
        );
        await withServer(BridgeResume.sync, offline);
        await withServer(BridgeResume.sync, server(<int>[1]));
        await withServer(
          BridgeResume.sync,
          server(<String, Object?>{'levels': 'x'}),
        );

        expect(await stored(5), isNull);
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        await withServer(BridgeResume.sync, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
      });
    });
  });
}
