import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/coin_balance.dart';
import 'package:threeduo_learning/services/guess_progress_service.dart';

import 'test_helpers.dart';

const String roundKey = 'guess_round_animals_user_1';
const String queueKey = 'guess_sync_queue_user_1';
const String bestKey = 'guess_best_user_1';
const String coinQueueKey = 'guess_coin_queue_user_1';
const Set<String> words = <String>{'a', 'b', 'c'};

GuessRound round({int index = 1, int correct = 1, int coins = 2, int pending = 0}) =>
    GuessRound(
      order: const <String>['a', 'b', 'c'],
      index: index,
      correct: correct,
      coins: coins,
      pending: pending,
    );

String roundJson({
  List<String> order = const <String>['a', 'b', 'c'],
  Object? index = 1,
  Object? correct = 1,
  Object? coins = 2,
  Object? pending,
  String updatedAt = '2020-01-01T00:00:00.000Z',
}) => jsonEncode(<String, Object?>{
  'order': order,
  'index': index,
  'correct': correct,
  'coins': coins,
  'pending': pending,
  'updatedAt': updatedAt,
});

/// Lets any background upload finish (twice, in case a change arrived while
/// the first one was running).
Future<void> settle() async {
  await GuessProgress.flush();
  await GuessProgress.flush();
}

Future<Map<String, dynamic>> queue() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(queueKey);
  return raw == null
      ? <String, dynamic>{}
      : Map<String, dynamic>.from(jsonDecode(raw) as Map);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    signIn();
    CoinBalance.clear();
  });

  group('GuessProgress rounds', () {
    test('nothing saved means no round', () async {
      expect(await GuessProgress.load('animals', words), isNull);
      expect(await GuessProgress.bestScores(), isEmpty);
    });

    test('signed out: nothing is stored or sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final requests = <http.Request>[];

      await withServer(() async {
        await GuessProgress.save('animals', round());
        await GuessProgress.flush();
      }, (request) async {
        requests.add(request);
        return jsonResponse(<String, Object?>{});
      });

      expect(requests, isEmpty);
      expect(await GuessProgress.load('animals', words), isNull);
    });

    test('save keeps the round on the phone and sends it to the server',
        () async {
      final requests = <http.Request>[];

      await withServer(() async {
        await GuessProgress.save('animals', round(index: 2, correct: 1, coins: 4));
        await settle();
      }, (request) async {
        requests.add(request);
        return jsonResponse(<String, Object?>{});
      });

      expect(requests, hasLength(1));
      final sent = requests.single;
      expect(sent.method, 'PUT');
      expect(sent.url.path, '/api/games/guess/progress/animals');
      expect(sent.headers['authorization'], startsWith('Bearer '));
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['round'], <String, Object?>{
        'order': <String>['a', 'b', 'c'],
        'index': 2,
        'correct': 1,
        'coins': 4,
      });
      expect(body['updatedAt'], isA<String>());
      expect(await queue(), isEmpty);

      final loaded = await GuessProgress.load('animals', words);
      expect(loaded!.order, <String>['a', 'b', 'c']);
      expect(loaded.index, 2);
      expect(loaded.correct, 1);
      expect(loaded.coins, 4);
      expect(loaded.pending, 0);
    });

    test('a round keeps its pending offline coins', () async {
      await withServer(() async {
        await GuessProgress.save('animals', round(pending: 3));
        await settle();
      }, offline);

      final loaded = await GuessProgress.load('animals', words);
      expect(loaded!.pending, 3);
    });

    test('offline or refused changes wait in the queue', () async {
      for (final handler in <Handler>[
        offline,
        (_) async => jsonResponse(<String, Object?>{}, 500),
        (_) async => jsonResponse(<String, Object?>{}, 401),
      ]) {
        signIn();
        await withServer(() async {
          await GuessProgress.save('animals', round());
          await settle();
        }, handler);

        final waiting = await queue();
        expect(waiting.keys, <String>['animals']);
        expect((waiting['animals'] as Map)['round'], isA<Map>());
      }
    });

    test('a change the server will never accept is dropped from the queue',
        () async {
      await withServer(() async {
        await GuessProgress.save('animals', round());
        await settle();
      }, (_) async => jsonResponse(<String, Object?>{}, 400));

      expect(await queue(), isEmpty);
    });

    test('clear leaves a cleared mark and tells the server', () async {
      final bodies = <Map<String, dynamic>>[];

      await withServer(() async {
        await GuessProgress.save('animals', round());
        await GuessProgress.clear('animals');
        await settle();
      }, (request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return jsonResponse(<String, Object?>{});
      });

      expect(await GuessProgress.load('animals', words), isNull);
      final prefs = await SharedPreferences.getInstance();
      final mark = jsonDecode(prefs.getString(roundKey)!) as Map;
      expect(mark['cleared'], isTrue);
      expect(bodies.last['round'], isNull);
      expect(await queue(), isEmpty);
    });

    test('a saved round that no longer fits is dropped', () async {
      final bad = <String, String>{
        'other words': roundJson(order: <String>['a', 'b', 'x']),
        'too short': roundJson(order: <String>['a', 'b']),
        'index zero': roundJson(index: 0, correct: 0),
        'index at the end': roundJson(index: 3),
        'more right than asked': roundJson(index: 1, correct: 2),
        'negative right': roundJson(correct: -1),
        'index not a number': roundJson(index: 'x'),
        'coins not a number': roundJson(coins: 'x'),
        'not an object': jsonEncode(<int>[1]),
        'not json': '{{{',
      };

      for (final entry in bad.entries) {
        signIn(<String, Object>{roundKey: entry.value});
        expect(
          await GuessProgress.load('animals', words),
          isNull,
          reason: entry.key,
        );
      }
    });

    test('a negative pending count is read as zero', () async {
      signIn(<String, Object>{roundKey: roundJson(pending: -2)});

      expect((await GuessProgress.load('animals', words))!.pending, 0);
    });

    test('unfinished lists where each category stopped', () async {
      signIn(<String, Object>{
        roundKey: roundJson(index: 2, correct: 1),
        'guess_round_fruit_user_1': roundJson(index: 0, correct: 0),
      });

      final result = await GuessProgress.unfinished(<String, Set<String>>{
        'animals': words,
        'fruit': words,
        'colors': words,
      });

      expect(result.keys, <String>['animals']);
      expect(result['animals']!.index, 2);
      expect(result['animals']!.total, 3);
    });

    test('toJson lists every field', () {
      expect(round(pending: 1).toJson(), <String, Object?>{
        'order': <String>['a', 'b', 'c'],
        'index': 1,
        'correct': 1,
        'coins': 2,
        'pending': 1,
      });
    });
  });

  group('GuessProgress best scores', () {
    test('only a higher score replaces the best', () async {
      await withServer(() async {
        await GuessProgress.saveFinished('animals', 60);
        await GuessProgress.saveFinished('animals', 40);
        await GuessProgress.saveFinished('fruit', 100);
        await settle();
      }, (_) async => jsonResponse(<String, Object?>{}));

      expect(await GuessProgress.bestScores(), <String, int>{
        'animals': 60,
        'fruit': 100,
      });
    });

    test('a best score still waiting to be sent is never lost', () async {
      await withServer(() async {
        await GuessProgress.saveFinished('animals', 60);
        await GuessProgress.saveFinished('animals', 40);
        await settle();
      }, offline);

      final waiting = await queue();
      expect((waiting['animals'] as Map)['best'], 60);
      expect((waiting['animals'] as Map)['round'], isNull);
    });

    test('ignores a damaged best-score record', () async {
      signIn(<String, Object>{bestKey: '{{{'});
      expect(await GuessProgress.bestScores(), isEmpty);

      signIn(<String, Object>{bestKey: jsonEncode(<int>[1])});
      expect(await GuessProgress.bestScores(), isEmpty);

      signIn(<String, Object>{
        bestKey: jsonEncode(<String, Object>{'animals': 50, 'fruit': 'x'}),
      });
      expect(await GuessProgress.bestScores(), <String, int>{'animals': 50});
    });
  });

  group('GuessProgress.sync', () {
    Handler server({
      Object? categories,
      int putStatus = 200,
      int getStatus = 200,
      Object? getBody,
    }) {
      return (request) async {
        if (request.method == 'PUT') {
          return jsonResponse(<String, Object?>{}, putStatus);
        }
        expect(request.url.path, '/api/games/guess/progress');
        return jsonResponse(
          getBody ?? <String, Object?>{'categories': categories},
          getStatus,
        );
      };
    }

    Map<String, Object?> serverRound({
      String updatedAt = '2026-01-01T00:00:00.000Z',
      int index = 2,
    }) => <String, Object?>{
      'best': 80,
      'updatedAt': updatedAt,
      'round': <String, Object?>{
        'order': <String>['a', 'b', 'c'],
        'index': index,
        'correct': 2,
        'coins': 6,
      },
    };

    test('takes a better best score and a newer round from the server',
        () async {
      signIn(<String, Object>{
        bestKey: jsonEncode(<String, int>{'animals': 40}),
        roundKey: roundJson(index: 1, correct: 0),
      });

      await withServer(
        GuessProgress.sync,
        server(categories: <String, Object?>{'animals': serverRound()}),
      );

      expect(await GuessProgress.bestScores(), <String, int>{'animals': 80});
      final loaded = await GuessProgress.load('animals', words);
      expect(loaded!.index, 2);
      expect(loaded.correct, 2);
      expect(loaded.coins, 6);
    });

    test('keeps a local round that is newer than the server copy', () async {
      signIn(<String, Object>{
        roundKey: roundJson(
          index: 1,
          correct: 1,
          updatedAt: '2027-01-01T00:00:00.000Z',
        ),
      });

      await withServer(
        GuessProgress.sync,
        server(categories: <String, Object?>{'animals': serverRound()}),
      );

      expect((await GuessProgress.load('animals', words))!.index, 1);
    });

    test('does not overwrite a change that could not be sent yet', () async {
      signIn(<String, Object>{
        roundKey: roundJson(index: 1, correct: 1),
        queueKey: jsonEncode(<String, Object?>{
          'animals': <String, Object?>{
            'round': <String, Object?>{},
            'updatedAt': '2020-01-01T00:00:00.000Z',
          },
        }),
      });

      await withServer(
        GuessProgress.sync,
        server(
          categories: <String, Object?>{'animals': serverRound()},
          putStatus: 500,
        ),
      );

      expect((await GuessProgress.load('animals', words))!.index, 1);
      expect((await queue()).keys, <String>['animals']);
    });

    test('a round cleared on another phone is cleared here', () async {
      signIn(<String, Object>{roundKey: roundJson()});

      await withServer(
        GuessProgress.sync,
        server(
          categories: <String, Object?>{
            'animals': <String, Object?>{
              'updatedAt': '2026-01-01T00:00:00.000Z',
              'round': null,
            },
          },
        ),
      );

      expect(await GuessProgress.load('animals', words), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect((jsonDecode(prefs.getString(roundKey)!) as Map)['cleared'], isTrue);
    });

    test('skips entries it cannot use', () async {
      signIn(<String, Object>{roundKey: roundJson()});

      await withServer(
        GuessProgress.sync,
        server(
          categories: <String, Object?>{
            'animals': <String, Object?>{'round': null, 'updatedAt': 'never'},
            'fruit': 'x',
          },
        ),
      );

      expect((await GuessProgress.load('animals', words))!.index, 1);
    });

    test('does nothing when the server cannot answer', () async {
      signIn(<String, Object>{roundKey: roundJson()});

      await withServer(GuessProgress.sync, server(getStatus: 500));
      await withServer(GuessProgress.sync, offline);
      await withServer(
        GuessProgress.sync,
        server(getBody: <String, Object?>{'categories': 'x'}),
      );
      await withServer(GuessProgress.sync, server(getBody: <int>[1]));

      expect((await GuessProgress.load('animals', words))!.index, 1);
    });

    test('signed out: no request is made', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(GuessProgress.sync, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });
  });

  group('GuessCoins', () {
    Future<List<String>> coinQueue() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(coinQueueKey) ?? <String>[];
    }

    Future<GuessCoinResult> submit() => GuessCoins.submit(
      categoryId: 'animals',
      word: 'cat',
      choice: 'cat',
    );

    test('a new right answer gives coins and updates the balance', () async {
      http.Request? sent;

      final result = await withServer(submit, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{
          'coinsAwarded': 2,
          'balance': 52,
        });
      });

      expect(result.coins, 2);
      expect(result.pending, isFalse);
      expect(result.alreadyToday, isFalse);
      expect(CoinBalance.value.value, 52);
      expect(sent!.method, 'POST');
      expect(sent!.url.path, '/api/games/guess/answer');
      expect(sent!.headers['authorization'], startsWith('Bearer '));
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['category'], 'animals');
      expect(body['word'], 'cat');
      expect(body['choice'], 'cat');
      expect(body['answeredAt'], isA<String>());
    });

    test('a word that already paid today gives nothing more', () async {
      final result = await withServer(
        submit,
        (_) async => jsonResponse(<String, Object?>{
          'alreadyRewardedToday': true,
          'balance': 52,
        }),
      );

      expect(result.coins, 0);
      expect(result.alreadyToday, isTrue);
    });

    test('signed out: nothing is sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      final result = await withServer(submit, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
      expect(result.coins, 0);
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
        expect(await coinQueue(), hasLength(1));
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
        expect(result.coins, 0);
        expect(await coinQueue(), isEmpty);
      }
    });

    test('flush sends the saved answers and removes them', () async {
      signIn(<String, Object>{
        coinQueueKey: <String>['{"word":"one"}', '{"word":"two"}'],
      });
      final sentWords = <Object?>[];

      await withServer(GuessCoins.flush, (request) async {
        if (request.method == 'POST') {
          sentWords.add((jsonDecode(request.body) as Map)['word']);
          return jsonResponse(<String, Object?>{'coinsAwarded': 2});
        }
        return jsonResponse(<String, Object?>{'balance': 9});
      });
      await pumpEventQueue();

      expect(sentWords, <Object?>['one', 'two']);
      expect(await coinQueue(), isEmpty);
    });

    test('flush drops answers the server rejects and stops on errors',
        () async {
      signIn(<String, Object>{
        coinQueueKey: <String>['{"word":"one"}', '{"word":"two"}'],
      });
      await withServer(
        GuessCoins.flush,
        (_) async => jsonResponse(<String, Object?>{}, 400),
      );
      expect(await coinQueue(), isEmpty);

      signIn(<String, Object>{
        coinQueueKey: <String>['{"word":"one"}', '{"word":"two"}'],
      });
      await withServer(
        GuessCoins.flush,
        (_) async => jsonResponse(<String, Object?>{}, 500),
      );
      expect(await coinQueue(), hasLength(2));

      await withServer(GuessCoins.flush, offline);
      expect(await coinQueue(), hasLength(2));
    });

    test('flush does nothing when signed out or when the queue is empty',
        () async {
      var called = false;
      Future<http.Response> handler(http.Request _) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      }

      SharedPreferences.setMockInitialValues(<String, Object>{});
      await withServer(GuessCoins.flush, handler);

      signIn();
      await withServer(GuessCoins.flush, handler);

      expect(called, isFalse);
    });

    test('keeps only the newest 300 saved answers', () async {
      signIn(<String, Object>{
        coinQueueKey: <String>[
          for (var i = 0; i < 300; i++) '{"word":"old$i"}',
        ],
      });

      await withServer(submit, offline);

      final saved = await coinQueue();
      expect(saved, hasLength(300));
      expect(saved.first, '{"word":"old1"}');
      expect(saved.last, contains('"word":"cat"'));
    });

    test('the result holds its defaults', () {
      const result = GuessCoinResult();

      expect(result.coins, 0);
      expect(result.pending, isFalse);
      expect(result.alreadyToday, isFalse);
    });
  });
}
