import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/coin_balance.dart';
import 'package:threeduo_learning/services/letter_levels_service.dart';

import 'test_helpers.dart';

const String starsKey = 'letter_stars_animals_user_1';
const String levelQueueKey = 'letter_level_queue_user_1';
const String coinQueueKey = 'letter_coin_queue_user_1';
const String resumeQueueKey = 'letter_resume_queue_user_1';

Future<List<String>> strings(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(key) ?? <String>[];
}

Map<String, Object?> question(String word, int missing) => <String, Object?>{
  'fullWord': word,
  'missingIndex': missing,
  'correctLetter': word[missing],
  'options': <String>[word[missing], 'x', 'y'],
  'imagePath': 'assets/$word.png',
};

List<Map<String, Object?>> twoQuestions() => <Map<String, Object?>>[
  question('cat', 0),
  question('dog', 1),
];

Map<String, Object?> resumeJson({
  Object? questions,
  Object? index = 1,
  Object? score = 1,
  Object? coins = 2,
  String updatedAt = '2020-01-01T00:00:00.000Z',
}) => <String, Object?>{
  'questions': questions ?? twoQuestions(),
  'index': index,
  'score': score,
  'coins': coins,
  'updatedAt': updatedAt,
};

String resumeKey(String folder, int level) =>
    'letter_resume_${folder}_${level}_user_1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    signIn();
    CoinBalance.clear();
  });

  group('LetterLevels', () {
    test('stars start at zero and signed-out has none', () async {
      expect(await LetterLevels.load('animals'), List<int>.filled(20, 0));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await LetterLevels.load('animals'), List<int>.filled(20, 0));
    });

    test('reads saved stars and keeps them between 0 and 3', () async {
      signIn(<String, Object>{starsKey: '1,2,3,9,x,-4'});

      final stars = await LetterLevels.load('animals');

      expect(stars.take(6).toList(), <int>[1, 2, 3, 3, 0, 0]);
      expect(stars, hasLength(20));
    });

    test('a played level is saved and sent to the server', () async {
      http.Request? sent;

      await withServer(() async {
        await LetterLevels.record('animals', 3, 2);
        await LetterLevels.flush();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      expect((await LetterLevels.load('animals'))[2], 2);
      expect(sent!.method, 'POST');
      expect(sent!.url.path, '/api/games/letter/level');
      expect(jsonDecode(sent!.body), <String, Object?>{
        'category': 'animals',
        'level': 3,
        'stars': 2,
      });
      expect(await strings(levelQueueKey), isEmpty);
    });

    test('fewer stars never replace the best', () async {
      signIn(<String, Object>{starsKey: '0,0,3'});

      await withServer(
        () => LetterLevels.record('animals', 3, 1),
        (_) async => jsonResponse(<String, Object?>{}),
      );

      expect((await LetterLevels.load('animals'))[2], 3);
    });

    test('signed out: nothing is stored or sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(() => LetterLevels.record('animals', 1, 3), (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
      expect(await LetterLevels.load('animals'), List<int>.filled(20, 0));
    });

    test('a level that could not be sent waits in the queue', () async {
      for (final handler in <Handler>[
        offline,
        (_) async => jsonResponse(<String, Object?>{}, 503),
      ]) {
        signIn();
        await withServer(() => LetterLevels.record('animals', 1, 3), handler);

        final queue = await strings(levelQueueKey);
        expect(queue, hasLength(1));
        expect(jsonDecode(queue.single)['level'], 1);
      }
    });

    test('a level the server refuses is not queued', () async {
      for (final status in <int>[400, 401]) {
        signIn();
        await withServer(
          () => LetterLevels.record('animals', 1, 3),
          (_) async => jsonResponse(<String, Object?>{}, status),
        );

        expect(await strings(levelQueueKey), isEmpty);
      }
    });

    test('keeps only the newest 500 waiting levels', () async {
      signIn(<String, Object>{
        levelQueueKey: <String>[for (var i = 0; i < 500; i++) '{"n":$i}'],
      });

      await withServer(() => LetterLevels.record('animals', 1, 3), offline);

      final queue = await strings(levelQueueKey);
      expect(queue, hasLength(500));
      expect(queue.first, '{"n":1}');
    });

    test('flush sends waiting levels and removes them', () async {
      signIn(<String, Object>{
        levelQueueKey: <String>['{"n":1}', '{"n":2}'],
      });
      final sent = <Object?>[];

      await withServer(LetterLevels.flush, (request) async {
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
        await withServer(LetterLevels.flush, handler);
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

      await withServer(LetterLevels.flush, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });

    test('old stars from before accounts go to the first child', () async {
      signIn(<String, Object>{
        'letter_game_stars_animals': '3,2',
        'letter_game_stars_fruits': '0,0',
        starsKey: '1,0',
      });

      final stars = await LetterLevels.load('animals');

      expect(stars.take(2).toList(), <int>[3, 2]);
      final queue = (await strings(levelQueueKey))
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();
      expect(queue, hasLength(2));
      expect(queue.every((q) => q['imported'] == true), isTrue);
      expect(queue.map((q) => q['level']), <int>[1, 2]);
      expect(queue.map((q) => q['category']).toSet(), <String>{'animals'});
    });

    test('old stars are not given to a second child', () async {
      signIn(<String, Object>{
        'letter_game_stars_animals': '3,2',
        'letter_old_stars_owner': '2',
      });

      final stars = await LetterLevels.load('animals');

      expect(stars, List<int>.filled(20, 0));
      expect(await strings(levelQueueKey), isEmpty);
    });

    test('old stars are only looked at once', () async {
      signIn(<String, Object>{'letter_game_stars_animals': '3'});

      await LetterLevels.load('animals');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('letter_game_stars_animals', '3,3,3');
      await LetterLevels.load('animals');

      expect((await LetterLevels.load('animals')).take(3).toList(), <int>[
        3,
        0,
        0,
      ]);
    });

    group('sync', () {
      Handler server(Object? body, {int status = 200}) => (request) async {
        if (request.url.path == '/api/games/letter/levels') {
          return jsonResponse(body, status);
        }
        return jsonResponse(<String, Object?>{});
      };

      test('takes better stars from the server', () async {
        signIn(<String, Object>{starsKey: '1,3'});

        await withServer(
          LetterLevels.sync,
          server(<String, Object?>{
            'categories': <String, Object?>{
              'animals': <Object?>[3, 2, 4, 'x', null],
              'fruits': 'x',
            },
          }),
        );

        expect((await LetterLevels.load('animals')).take(5).toList(), <int>[
          3,
          3,
          0,
          0,
          0,
        ]);
        expect(await LetterLevels.load('fruits'), List<int>.filled(20, 0));
      });

      test('sends waiting levels first', () async {
        signIn(<String, Object>{
          levelQueueKey: <String>['{"n":1}'],
        });
        final methods = <String>[];

        await withServer(LetterLevels.sync, (request) async {
          methods.add('${request.method} ${request.url.path}');
          return jsonResponse(<String, Object?>{'categories': <String, Object?>{}});
        });

        expect(methods.first, 'POST /api/games/letter/level');
        expect(methods.last, 'GET /api/games/letter/levels');
      });

      test('ignores a server that cannot answer or answers oddly', () async {
        signIn(<String, Object>{starsKey: '1'});

        await withServer(LetterLevels.sync, server(<String, Object?>{}, status: 500));
        await withServer(LetterLevels.sync, offline);
        await withServer(LetterLevels.sync, server(<int>[1]));
        await withServer(
          LetterLevels.sync,
          server(<String, Object?>{'categories': 'x'}),
        );

        expect((await LetterLevels.load('animals'))[0], 1);
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        await withServer(LetterLevels.sync, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
      });

      test('syncAll also brings back levels left in the middle', () async {
        final paths = <String>[];

        await withServer(LetterLevels.syncAll, (request) async {
          paths.add(request.url.path);
          return jsonResponse(<String, Object?>{
            'categories': <String, Object?>{},
            'levels': <Object?>[],
          });
        });

        expect(paths, contains('/api/games/letter/levels'));
        expect(paths, contains('/api/games/letter/resume'));
      });
    });
  });

  group('LetterCoins', () {
    Future<dynamic> submit() =>
        LetterCoins.submit(categoryKey: 'animals', word: 'cat');

    test('a right answer gives coins and updates the balance', () async {
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
      expect(sent!.url.path, '/api/games/letter/answer');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['category'], 'animals');
      expect(body['word'], 'cat');
      expect(body['answeredAt'], isA<String>());
    });

    test('a word that already paid today gives nothing more', () async {
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
      final result = await withServer(
        submit,
        (_) async => jsonResponse(<int>[1]),
      );

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

      await withServer(LetterCoins.flush, (request) async {
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
        await withServer(LetterCoins.flush, handler);
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

      await withServer(LetterCoins.flush, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });
  });

  group('LetterResume', () {
    Future<void> settle() async {
      await LetterResume.flush();
      await pumpEventQueue();
      await LetterResume.flush();
      await pumpEventQueue();
    }

    Future<void> saveRound() => LetterResume.save(
      'animals',
      3,
      questions: twoQuestions(),
      index: 1,
      score: 1,
      coins: 2,
    );

    test('a level left in the middle is saved and sent', () async {
      http.Request? sent;

      await withServer(() async {
        await saveRound();
        await settle();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      final round = await LetterResume.load('animals', 3);
      expect(round!['index'], 1);
      expect(round['score'], 1);
      expect(round['coins'], 2);
      expect((round['questions'] as List), hasLength(2));
      expect(sent!.method, 'PUT');
      expect(sent!.url.path, '/api/games/letter/resume/animals/3');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['round']['index'], 1);
      expect(body['updatedAt'], isA<String>());
      expect(await SharedPreferences.getInstance().then(
        (p) => p.getString(resumeQueueKey),
      ), '{}');
    });

    test('nothing is stored when signed out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await withServer(() async {
        await saveRound();
        await settle();
      }, offline);

      expect(await LetterResume.load('animals', 3), isNull);
    });

    test('changes made offline wait to be sent', () async {
      await withServer(() async {
        await saveRound();
        await settle();
      }, offline);

      final prefs = await SharedPreferences.getInstance();
      final queue = jsonDecode(prefs.getString(resumeQueueKey)!) as Map;
      expect(queue.keys, <String>['animals|3']);
      expect(await LetterResume.load('animals', 3), isNotNull);
    });

    test('clear leaves a mark and tells the server', () async {
      final bodies = <Map<String, dynamic>>[];

      await withServer(() async {
        await saveRound();
        await LetterResume.clear('animals', 3);
        await settle();
      }, (request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return jsonResponse(<String, Object?>{});
      });

      expect(await LetterResume.load('animals', 3), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(prefs.getString(resumeKey('animals', 3))!) as Map)['cleared'],
        isTrue,
      );
      expect(bodies.last['round'], isNull);
    });

    test('a missing coin count counts as zero and bad options are dropped',
        () async {
      final q = question('cat', 0)..['options'] = <Object?>['c', 5, 'a'];
      final raw = resumeJson(
        questions: <Object?>[q, question('dog', 1)],
        coins: 'x',
      );
      signIn(<String, Object>{resumeKey('animals', 1): jsonEncode(raw)});

      final round = await LetterResume.load('animals', 1);

      expect(round!['coins'], 0);
      expect(((round['questions'] as List).first as Map)['options'], <String>[
        'c',
        'a',
      ]);
    });

    test('a damaged or unusable saved level is ignored', () async {
      Map<String, Object?> withQuestion(Map<String, Object?> change) => resumeJson(
        questions: <Object?>[
          <String, Object?>{...question('cat', 0), ...change},
          question('dog', 1),
        ],
      );

      final bad = <String, Object>{
        'not json': '{{{',
        'not an object': jsonEncode(<int>[1]),
        'cleared': jsonEncode(<String, Object?>{'cleared': true}),
        'no questions': jsonEncode(resumeJson(questions: <Object?>[])),
        'questions not a list': jsonEncode(resumeJson(questions: 'x')),
        'index zero': jsonEncode(resumeJson(index: 0, score: 0)),
        'index past the end': jsonEncode(resumeJson(index: 2)),
        'index not a number': jsonEncode(resumeJson(index: 'x')),
        'score above index': jsonEncode(resumeJson(score: 2)),
        'negative score': jsonEncode(resumeJson(score: -1)),
        'question not an object': jsonEncode(
          resumeJson(questions: <Object?>['x', question('dog', 1)]),
        ),
        'letter does not match': jsonEncode(
          withQuestion(<String, Object?>{'correctLetter': 'z'}),
        ),
        'missing index out of range': jsonEncode(
          withQuestion(<String, Object?>{'missingIndex': 9}),
        ),
        'negative missing index': jsonEncode(
          withQuestion(<String, Object?>{'missingIndex': -1}),
        ),
        'options not a list': jsonEncode(
          withQuestion(<String, Object?>{'options': 'x'}),
        ),
        'no image': jsonEncode(withQuestion(<String, Object?>{'imagePath': 1})),
        'word not text': jsonEncode(withQuestion(<String, Object?>{'fullWord': 1})),
      };

      for (final entry in bad.entries) {
        signIn(<String, Object>{resumeKey('animals', 1): entry.value});
        expect(
          await LetterResume.load('animals', 1),
          isNull,
          reason: entry.key,
        );
      }
    });

    test('unfinishedLevels lists the levels that can be continued', () async {
      signIn(<String, Object>{
        resumeKey('animals', 2): jsonEncode(resumeJson()),
        resumeKey('animals', 5): jsonEncode(resumeJson()),
        resumeKey('animals', 6): jsonEncode(<String, Object?>{'cleared': true}),
        resumeKey('fruits', 1): jsonEncode(resumeJson()),
      });

      expect(await LetterResume.unfinishedLevels('animals', 10), <int>{2, 5});
    });

    group('flush', () {
      Future<void> run(Handler handler, Map<String, Object?> queue) async {
        signIn(<String, Object>{resumeQueueKey: jsonEncode(queue)});
        await withServer(LetterResume.flush, handler);
      }

      final entry = <String, Object?>{
        'animals|1': <String, Object?>{
          'round': null,
          'updatedAt': '2020-01-01T00:00:00.000Z',
        },
      };

      Future<Map> queue() async {
        final prefs = await SharedPreferences.getInstance();
        return jsonDecode(prefs.getString(resumeQueueKey)!) as Map;
      }

      test('removes what the server accepted or refused', () async {
        await run((_) async => jsonResponse(<String, Object?>{}), entry);
        expect(await queue(), isEmpty);

        await run((_) async => jsonResponse(<String, Object?>{}, 400), entry);
        expect(await queue(), isEmpty);
      });

      test('keeps what could not be sent', () async {
        await run((_) async => jsonResponse(<String, Object?>{}, 500), entry);
        expect(await queue(), hasLength(1));

        await run(offline, entry);
        expect(await queue(), hasLength(1));
      });

      test('skips entries with a broken name and does nothing signed out',
          () async {
        var called = false;
        await run((_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        }, <String, Object?>{'broken': <String, Object?>{}});
        expect(called, isFalse);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        await withServer(LetterResume.flush, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });
        expect(called, isFalse);
      });

      test('an empty or damaged queue sends nothing', () async {
        var called = false;
        Future<http.Response> handler(http.Request _) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        }

        signIn(<String, Object>{resumeQueueKey: '{{{'});
        await withServer(LetterResume.flush, handler);
        signIn(<String, Object>{resumeQueueKey: jsonEncode(<int>[1])});
        await withServer(LetterResume.flush, handler);

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
        String category = 'animals',
        int level = 1,
      }) => <String, Object?>{
        'category': category,
        'level': level,
        'updatedAt': updatedAt,
        'round': round == 'use-valid' ? resumeJson(coins: 4) : round,
      };

      Future<Map?> stored(String folder, int level) async {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(resumeKey(folder, level));
        return raw == null ? null : jsonDecode(raw) as Map;
      }

      test('takes a newer level from the server', () async {
        signIn(<String, Object>{
          resumeKey('animals', 1): jsonEncode(resumeJson(coins: 0)),
        });

        await withServer(
          LetterResume.sync,
          server(<String, Object?>{'levels': <Object?>[serverLevel()]}),
        );

        expect((await LetterResume.load('animals', 1))!['coins'], 4);
      });

      test('takes a level when there is none on the phone', () async {
        await withServer(
          LetterResume.sync,
          server(<String, Object?>{'levels': <Object?>[serverLevel(level: 2)]}),
        );

        expect(await LetterResume.load('animals', 2), isNotNull);
      });

      test('keeps the phone copy when it is newer or the same age', () async {
        signIn(<String, Object>{
          resumeKey('animals', 1): jsonEncode(
            resumeJson(coins: 0, updatedAt: '2031-01-01T00:00:00.000Z'),
          ),
          resumeKey('animals', 2): jsonEncode(
            resumeJson(coins: 0, updatedAt: '2030-01-01T00:00:00.000Z'),
          ),
        });

        await withServer(
          LetterResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[serverLevel(), serverLevel(level: 2)],
          }),
        );

        expect((await LetterResume.load('animals', 1))!['coins'], 0);
        expect((await LetterResume.load('animals', 2))!['coins'], 0);
      });

      test('does not overwrite a change that has not been sent yet', () async {
        signIn(<String, Object>{
          resumeKey('animals', 1): jsonEncode(resumeJson(coins: 0)),
          resumeQueueKey: jsonEncode(<String, Object?>{
            'animals|1': <String, Object?>{
              'round': resumeJson(coins: 0),
              'updatedAt': '2020-01-01T00:00:00.000Z',
            },
          }),
        });

        await withServer(
          LetterResume.sync,
          server(
            <String, Object?>{'levels': <Object?>[serverLevel()]},
            putStatus: 500,
          ),
        );

        expect((await LetterResume.load('animals', 1))!['coins'], 0);
      });

      test('a level finished on another phone is cleared here', () async {
        signIn(<String, Object>{
          resumeKey('animals', 1): jsonEncode(resumeJson()),
        });

        await withServer(
          LetterResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[serverLevel(round: null)],
          }),
        );

        expect(await LetterResume.load('animals', 1), isNull);
        expect((await stored('animals', 1))!['cleared'], isTrue);
      });

      test('an unusable server round is treated as cleared', () async {
        await withServer(
          LetterResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[serverLevel(round: <String, Object?>{'x': 1})],
          }),
        );

        expect((await stored('animals', 1))!['cleared'], isTrue);
      });

      test('skips entries it cannot use', () async {
        await withServer(
          LetterResume.sync,
          server(<String, Object?>{
            'levels': <Object?>[
              'x',
              <String, Object?>{'category': 1, 'level': 1},
              <String, Object?>{'category': 'animals', 'level': 'x'},
              serverLevel(updatedAt: 'never'),
            ],
          }),
        );

        expect(await stored('animals', 1), isNull);
      });

      test('ignores a server that cannot answer or answers oddly', () async {
        await withServer(LetterResume.sync, server(<String, Object?>{}, status: 500));
        await withServer(LetterResume.sync, offline);
        await withServer(LetterResume.sync, server(<int>[1]));
        await withServer(
          LetterResume.sync,
          server(<String, Object?>{'levels': 'x'}),
        );

        expect(await stored('animals', 1), isNull);
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        await withServer(LetterResume.sync, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
      });
    });
  });
}
