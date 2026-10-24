import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/coin_balance.dart';
import 'package:threeduo_learning/services/guess_progress_service.dart'
    show GuessCoinResult;
import 'package:threeduo_learning/services/riddle_progress_service.dart';
import 'package:threeduo_learning/services/shadow_progress_service.dart';
import 'package:threeduo_learning/services/word_search_progress_service.dart';

import 'test_helpers.dart';

/// The three word games below save their progress in exactly the same way
/// (on the phone, then to the server, with a queue for offline use), only the
/// shape of an unfinished round differs. This describes one game so the same
/// behaviour tests can run against each of them.
class Game {
  Game({
    required this.name,
    required this.valid,
    required this.makeRound,
    required this.coinsOf,
    required this.save,
    required this.load,
    required this.clear,
    required this.saveFinished,
    required this.bestScores,
    required this.flush,
    required this.sync,
    required this.submitCoin,
    required this.flushCoins,
    required this.coinPath,
    required this.serverShape,
  });

  /// Used in the storage keys and in the URLs.
  final String name;

  /// The words/ids of the test category.
  final Set<String> valid;

  /// A valid unfinished round that has earned [coins].
  final Object Function(int coins, {int pending}) makeRound;
  final int Function(Object round) coinsOf;
  final Future<void> Function(String category, Object round) save;
  final Future<Object?> Function(String category) load;
  final Future<void> Function(String category) clear;
  final Future<void> Function(String category, int percent) saveFinished;
  final Future<Map<String, int>> Function() bestScores;
  final Future<void> Function() flush;
  final Future<void> Function() sync;
  final Future<GuessCoinResult> Function() submitCoin;
  final Future<void> Function() flushCoins;
  final String coinPath;

  /// What the server stores for [makeRound]: the round as JSON.
  final Map<String, Object?> Function(int coins) serverShape;

  String get roundKey => '${name}_round_animals_user_1';
  String get queueKey => '${name}_sync_queue_user_1';
  String get coinQueueKey => '${name}_coin_queue_user_1';
  String get bestKey => '${name}_best_user_1';

  Future<void> settle() async {
    await flush();
    await flush();
  }

  Future<Map<String, dynamic>> queue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(queueKey);
    return raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<List<String>> coinQueue() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(coinQueueKey) ?? <String>[];
  }

  /// How a round of this game looks in the phone's storage.
  String localJson(int coins, {String updatedAt = '2020-01-01T00:00:00.000Z'}) =>
      jsonEncode(<String, Object?>{
        ...serverShape(coins),
        'pending': 0,
        'updatedAt': updatedAt,
      });
}

final Game riddle = Game(
  name: 'riddle',
  valid: <String>{'CAT', 'DOG', 'SUN'},
  makeRound: (coins, {pending = 0}) => RiddleRound(
    queue: const <String>['DOG', 'SUN'],
    done: 1,
    mistakes: 0,
    hints: 0,
    coins: coins,
    pending: pending,
  ),
  coinsOf: (r) => (r as RiddleRound).coins,
  save: (c, r) => RiddleProgress.save(c, r as RiddleRound),
  load: (c) => RiddleProgress.load(c, <String>{'CAT', 'DOG', 'SUN'}),
  clear: RiddleProgress.clear,
  saveFinished: RiddleProgress.saveFinished,
  bestScores: RiddleProgress.bestScores,
  flush: RiddleProgress.flush,
  sync: RiddleProgress.sync,
  submitCoin: () => RiddleCoins.submit(
    categoryKey: 'animals',
    answer: 'CAT',
    hintsUsed: 0,
  ),
  flushCoins: RiddleCoins.flush,
  coinPath: '/api/games/riddle/answer',
  serverShape: (coins) => <String, Object?>{
    'queue': <String>['DOG', 'SUN'],
    'done': 1,
    'mistakes': 0,
    'revealed': 0,
    'hints': 0,
    'coins': coins,
  },
);

final Game wordSearch = Game(
  name: 'wordsearch',
  valid: <String>{'a', 'b', 'c', 'd', 'e'},
  makeRound: (coins, {pending = 0}) => WordSearchRound(
    order: const <String>['a', 'b', 'c', 'd', 'e'],
    found: const <String>['a'],
    hints: 0,
    coins: coins,
    pending: pending,
  ),
  coinsOf: (r) => (r as WordSearchRound).coins,
  save: (c, r) => WordSearchProgress.save(c, r as WordSearchRound),
  load: (c) =>
      WordSearchProgress.load(c, <String>{'a', 'b', 'c', 'd', 'e'}),
  clear: WordSearchProgress.clear,
  saveFinished: WordSearchProgress.saveFinished,
  bestScores: WordSearchProgress.bestScores,
  flush: WordSearchProgress.flush,
  sync: WordSearchProgress.sync,
  submitCoin: () => WordSearchCoins.submit(categoryKey: 'animals', word: 'a'),
  flushCoins: WordSearchCoins.flush,
  coinPath: '/api/games/wordsearch/found',
  serverShape: (coins) => <String, Object?>{
    'order': <String>['a', 'b', 'c', 'd', 'e'],
    'found': <String>['a'],
    'revealed': <String>[],
    'hints': 0,
    'coins': coins,
  },
);

final Game shadow = Game(
  name: 'shadow',
  valid: <String>{'a', 'b', 'c', 'd', 'e', 'f'},
  makeRound: (coins, {pending = 0}) => ShadowRound(
    order: const <String>['a', 'b', 'c', 'd', 'e', 'f'],
    roundIndex: 0,
    matched: const <String>['a'],
    mistakes: 0,
    coins: coins,
    pending: pending,
  ),
  coinsOf: (r) => (r as ShadowRound).coins,
  save: (c, r) => ShadowProgress.save(c, r as ShadowRound),
  load: (c) =>
      ShadowProgress.load(c, <String>{'a', 'b', 'c', 'd', 'e', 'f'}),
  clear: ShadowProgress.clear,
  saveFinished: ShadowProgress.saveFinished,
  bestScores: ShadowProgress.bestScores,
  flush: ShadowProgress.flush,
  sync: ShadowProgress.sync,
  submitCoin: () => ShadowCoins.submit(categoryKey: 'animals', itemId: 'a'),
  flushCoins: ShadowCoins.flush,
  coinPath: '/api/games/shadow/match',
  serverShape: (coins) => <String, Object?>{
    'order': <String>['a', 'b', 'c', 'd', 'e', 'f'],
    'roundIndex': 0,
    'matched': <String>['a'],
    'mistakes': 0,
    'coins': coins,
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    signIn();
    CoinBalance.clear();
  });

  for (final game in <Game>[riddle, wordSearch, shadow]) {
    group('${game.name} progress', () {
      test('saves the round on the phone and on the server', () async {
        final requests = <http.Request>[];

        await withServer(() async {
          await game.save('animals', game.makeRound(2));
          await game.settle();
        }, (request) async {
          requests.add(request);
          return jsonResponse(<String, Object?>{});
        });

        expect(requests, hasLength(1));
        expect(requests.single.method, 'PUT');
        expect(
          requests.single.url.path,
          '/api/games/${game.name}/progress/animals',
        );
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['round'], game.serverShape(2));
        expect(body['updatedAt'], isA<String>());
        expect(await game.queue(), isEmpty);

        final loaded = await game.load('animals');
        expect(loaded, isNotNull);
        expect(game.coinsOf(loaded!), 2);
      });

      test('nothing is stored or sent when signed out', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        await withServer(() async {
          await game.save('animals', game.makeRound(2));
          await game.settle();
        }, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
        expect(await game.load('animals'), isNull);
      });

      test('offline or refused changes wait in the queue', () async {
        for (final handler in <Handler>[
          offline,
          (_) async => jsonResponse(<String, Object?>{}, 500),
          (_) async => jsonResponse(<String, Object?>{}, 401),
        ]) {
          signIn();
          await withServer(() async {
            await game.save('animals', game.makeRound(2));
            await game.settle();
          }, handler);

          final waiting = await game.queue();
          expect(waiting.keys, <String>['animals']);
          expect((waiting['animals'] as Map)['round'], isA<Map>());
        }
      });

      test('a change the server will never accept is dropped', () async {
        await withServer(() async {
          await game.save('animals', game.makeRound(2));
          await game.settle();
        }, (_) async => jsonResponse(<String, Object?>{}, 400));

        expect(await game.queue(), isEmpty);
      });

      test('keeps the offline coin count of a round', () async {
        await withServer(() async {
          await game.save('animals', game.makeRound(2, pending: 3));
          await game.settle();
        }, offline);

        final prefs = await SharedPreferences.getInstance();
        final stored = jsonDecode(prefs.getString(game.roundKey)!) as Map;
        expect(stored['pending'], 3);
        expect(await game.load('animals'), isNotNull);
      });

      test('clear leaves a cleared mark and tells the server', () async {
        final bodies = <Map<String, dynamic>>[];

        await withServer(() async {
          await game.save('animals', game.makeRound(2));
          await game.clear('animals');
          await game.settle();
        }, (request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return jsonResponse(<String, Object?>{});
        });

        expect(await game.load('animals'), isNull);
        final prefs = await SharedPreferences.getInstance();
        expect((jsonDecode(prefs.getString(game.roundKey)!) as Map)['cleared'], isTrue);
        expect(bodies.last['round'], isNull);
        expect(await game.queue(), isEmpty);
      });

      test('finishing keeps the best score and clears the round', () async {
        final bodies = <Map<String, dynamic>>[];

        await withServer(() async {
          await game.save('animals', game.makeRound(2));
          await game.saveFinished('animals', 60);
          await game.saveFinished('animals', 40);
          await game.saveFinished('fruit', 100);
          await game.settle();
        }, (request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return jsonResponse(<String, Object?>{});
        });

        expect(await game.bestScores(), <String, int>{
          'animals': 60,
          'fruit': 100,
        });
        expect(await game.load('animals'), isNull);
        expect(bodies.any((b) => b['best'] == 100 && b['round'] == null), isTrue);
      });

      test('a best score waiting to be sent is never lost', () async {
        await withServer(() async {
          await game.saveFinished('animals', 60);
          await game.saveFinished('animals', 40);
          await game.settle();
        }, offline);

        final waiting = await game.queue();
        expect((waiting['animals'] as Map)['best'], 60);
        expect((waiting['animals'] as Map)['round'], isNull);
      });

      test('ignores a damaged best-score record', () async {
        signIn(<String, Object>{game.bestKey: '{{{'});
        expect(await game.bestScores(), isEmpty);

        signIn(<String, Object>{game.bestKey: jsonEncode(<int>[1])});
        expect(await game.bestScores(), isEmpty);

        signIn(<String, Object>{
          game.bestKey: jsonEncode(<String, Object>{'a': 50, 'b': 'x'}),
        });
        expect(await game.bestScores(), <String, int>{'a': 50});
      });

      group('sync', () {
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
            expect(request.url.path, '/api/games/${game.name}/progress');
            return jsonResponse(
              getBody ?? <String, Object?>{'categories': categories},
              getStatus,
            );
          };
        }

        Map<String, Object?> serverEntry({
          String updatedAt = '2026-01-01T00:00:00.000Z',
          Object? round = 'use-shape',
          int coins = 0,
        }) => <String, Object?>{
          'best': 80,
          'updatedAt': updatedAt,
          'round': round == 'use-shape' ? game.serverShape(coins) : round,
        };

        test('takes a better best score and a newer round', () async {
          signIn(<String, Object>{
            game.bestKey: jsonEncode(<String, int>{'animals': 40}),
            game.roundKey: game.localJson(2),
          });

          await withServer(
            game.sync,
            server(categories: <String, Object?>{'animals': serverEntry()}),
          );

          expect(await game.bestScores(), <String, int>{'animals': 80});
          expect(game.coinsOf((await game.load('animals'))!), 0);
        });

        test('keeps a local round that is newer than the server copy',
            () async {
          signIn(<String, Object>{
            game.roundKey: game.localJson(
              2,
              updatedAt: '2027-01-01T00:00:00.000Z',
            ),
          });

          await withServer(
            game.sync,
            server(categories: <String, Object?>{'animals': serverEntry()}),
          );

          expect(game.coinsOf((await game.load('animals'))!), 2);
        });

        test('does not overwrite a change that could not be sent yet',
            () async {
          signIn(<String, Object>{
            game.roundKey: game.localJson(2),
            game.queueKey: jsonEncode(<String, Object?>{
              'animals': <String, Object?>{
                'round': <String, Object?>{},
                'updatedAt': '2020-01-01T00:00:00.000Z',
              },
            }),
          });

          await withServer(
            game.sync,
            server(
              categories: <String, Object?>{'animals': serverEntry()},
              putStatus: 500,
            ),
          );

          expect(game.coinsOf((await game.load('animals'))!), 2);
          expect((await game.queue()).keys, <String>['animals']);
        });

        test('a round cleared on another phone is cleared here', () async {
          signIn(<String, Object>{game.roundKey: game.localJson(2)});

          await withServer(
            game.sync,
            server(
              categories: <String, Object?>{
                'animals': serverEntry(round: null),
              },
            ),
          );

          expect(await game.load('animals'), isNull);
        });

        test('takes a round when there is none on the phone', () async {
          await withServer(
            game.sync,
            server(
              categories: <String, Object?>{'animals': serverEntry(coins: 2)},
            ),
          );

          expect(game.coinsOf((await game.load('animals'))!), 2);
        });

        test('skips entries it cannot use', () async {
          signIn(<String, Object>{game.roundKey: game.localJson(2)});

          await withServer(
            game.sync,
            server(
              categories: <String, Object?>{
                'animals': <String, Object?>{
                  'round': null,
                  'updatedAt': 'never',
                },
                'fruit': 'x',
              },
            ),
          );

          expect(game.coinsOf((await game.load('animals'))!), 2);
        });

        test('does nothing when the server cannot answer', () async {
          signIn(<String, Object>{game.roundKey: game.localJson(2)});

          await withServer(game.sync, server(getStatus: 500));
          await withServer(game.sync, offline);
          await withServer(
            game.sync,
            server(getBody: <String, Object?>{'categories': 'x'}),
          );
          await withServer(game.sync, server(getBody: <int>[1]));

          expect(game.coinsOf((await game.load('animals'))!), 2);
        });

        test('signed out: no request is made', () async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          var called = false;

          await withServer(game.sync, (_) async {
            called = true;
            return jsonResponse(<String, Object?>{});
          });

          expect(called, isFalse);
        });
      });
    });

    group('${game.name} coins', () {
      test('a right answer gives coins and updates the balance', () async {
        http.Request? sent;

        final result = await withServer(game.submitCoin, (request) async {
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
        expect(sent!.url.path, game.coinPath);
        expect(sent!.headers['authorization'], startsWith('Bearer '));
        final body = jsonDecode(sent!.body) as Map<String, dynamic>;
        expect(body['category'], 'animals');
        expect(body['answeredAt'], isA<String>());
      });

      test('a word that already paid today gives nothing more', () async {
        final result = await withServer(
          game.submitCoin,
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

        final result = await withServer(game.submitCoin, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
        expect(result.coins, 0);
        expect(result.pending, isFalse);
      });

      test('a server error or no network saves the answer for later',
          () async {
        for (final handler in <Handler>[
          (_) async => jsonResponse(<String, Object?>{}, 503),
          offline,
        ]) {
          signIn();
          final result = await withServer(game.submitCoin, handler);

          expect(result.pending, isTrue);
          expect(await game.coinQueue(), hasLength(1));
        }
      });

      test('an answer the server refuses is not saved', () async {
        for (final status in <int>[400, 401]) {
          signIn();
          final result = await withServer(
            game.submitCoin,
            (_) async => jsonResponse(<String, Object?>{}, status),
          );

          expect(result.pending, isFalse);
          expect(result.coins, 0);
          expect(await game.coinQueue(), isEmpty);
        }
      });

      test('flush sends the saved answers and removes them', () async {
        signIn(<String, Object>{
          game.coinQueueKey: <String>['{"n":1}', '{"n":2}'],
        });
        final sent = <Object?>[];

        await withServer(game.flushCoins, (request) async {
          if (request.method == 'POST') {
            sent.add((jsonDecode(request.body) as Map)['n']);
            return jsonResponse(<String, Object?>{'coinsAwarded': 2});
          }
          return jsonResponse(<String, Object?>{'balance': 9});
        });
        await pumpEventQueue();

        expect(sent, <Object?>[1, 2]);
        expect(await game.coinQueue(), isEmpty);
      });

      test('flush drops rejected answers and stops on errors', () async {
        Future<void> run(Handler handler) async {
          signIn(<String, Object>{
            game.coinQueueKey: <String>['{"n":1}', '{"n":2}'],
          });
          await withServer(game.flushCoins, handler);
        }

        await run((_) async => jsonResponse(<String, Object?>{}, 400));
        expect(await game.coinQueue(), isEmpty);

        await run((_) async => jsonResponse(<String, Object?>{}, 500));
        expect(await game.coinQueue(), hasLength(2));

        await run(offline);
        expect(await game.coinQueue(), hasLength(2));
      });

      test('flush does nothing when signed out or with an empty queue',
          () async {
        var called = false;
        Future<http.Response> handler(http.Request _) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        }

        SharedPreferences.setMockInitialValues(<String, Object>{});
        await withServer(game.flushCoins, handler);

        signIn();
        await withServer(game.flushCoins, handler);

        expect(called, isFalse);
      });

      test('keeps only the newest 300 saved answers', () async {
        signIn(<String, Object>{
          game.coinQueueKey: <String>[
            for (var i = 0; i < 300; i++) '{"n":$i}',
          ],
        });

        await withServer(game.submitCoin, offline);

        final saved = await game.coinQueue();
        expect(saved, hasLength(300));
        expect(saved.first, '{"n":1}');
        expect(saved.last, contains('answeredAt'));
      });
    });
  }

  group('riddle specifics', () {
    const Set<String> answers = <String>{'CAT', 'DOG', 'SUN'};

    Map<String, Object?> json({
      Object? queue = const <String>['DOG', 'SUN'],
      Object? done = 1,
      Object? mistakes = 0,
      Object? revealed = 0,
      Object? hints = 0,
      Object? coins = 2,
      Object? pending,
    }) => <String, Object?>{
      'queue': queue,
      'done': done,
      'mistakes': mistakes,
      'revealed': revealed,
      'hints': hints,
      'coins': coins,
      'pending': pending,
    };

    test('the number of hints depends on the length of the answer', () {
      expect(riddleMaxHints('CAT'), 1);
      expect(riddleMaxHints('ABCD'), 1);
      expect(riddleMaxHints('ABCDE'), 2);
      expect(riddleMaxHints('ABCDEF'), 2);
      expect(riddleMaxHints('ABCDEFG'), 3);
      expect(riddleMaxHints('ICE CREAM'), 3);
      expect(riddleMaxHints('cat'), 1);
    });

    test('reads a valid round and counts its questions', () {
      final round = RiddleRound.fromJson(json(pending: 2), answers)!;

      expect(round.queue, <String>['DOG', 'SUN']);
      expect(round.done, 1);
      expect(round.total, 3);
      expect(round.pending, 2);
      expect(round.revealed, 0);
      expect(round.toServer(), <String, Object?>{
        'queue': <String>['DOG', 'SUN'],
        'done': 1,
        'mistakes': 0,
        'revealed': 0,
        'hints': 0,
        'coins': 2,
      });
    });

    test('revealed may be missing', () {
      final raw = json()..remove('revealed');

      expect(RiddleRound.fromJson(raw, answers)!.revealed, 0);
    });

    test('rejects a round that does not fit the category', () {
      final bad = <String, Object?>{
        'not an object': 'x',
        'empty queue': json(queue: <String>[], done: 3),
        'duplicate answers': json(queue: <String>['DOG', 'DOG']),
        'unknown answer': json(queue: <String>['DOG', 'FOX']),
        'nothing done': json(done: 0, queue: <String>['CAT', 'DOG', 'SUN']),
        'count mismatch': json(done: 2),
        'negative mistakes': json(mistakes: -1),
        'more revealed than done': json(revealed: 2),
        'negative hints': json(hints: -1),
        'too many coins': json(coins: 3),
        'coins for a revealed word': json(revealed: 1, coins: 1),
        'bad type': json(done: 'x'),
      };

      for (final entry in bad.entries) {
        expect(
          RiddleRound.fromJson(entry.value, answers),
          isNull,
          reason: entry.key,
        );
      }
    });

    test('unfinished lists how far each category is', () async {
      signIn(<String, Object>{
        'riddle_round_animals_user_1': jsonEncode(json()),
        'riddle_round_fruit_user_1': jsonEncode(json(done: 0)),
      });

      final result = await RiddleProgress.unfinished(<String, Set<String>>{
        'animals': answers,
        'fruit': answers,
        'colors': answers,
      });

      expect(result.keys, <String>['animals']);
      expect(result['animals']!.done, 1);
      expect(result['animals']!.total, 3);
    });

    test('load drops a round that is not valid JSON', () async {
      signIn(<String, Object>{'riddle_round_animals_user_1': '{{{'});

      expect(await RiddleProgress.load('animals', answers), isNull);
    });

    test('no coin is asked for when every hint was used', () async {
      var called = false;

      final result = await withServer(
        () => RiddleCoins.submit(
          categoryKey: 'animals',
          answer: 'CAT',
          hintsUsed: 1,
        ),
        (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        },
      );

      expect(called, isFalse);
      expect(result.coins, 0);
      expect(result.pending, isFalse);
    });

    test('the answer is sent with the number of hints used', () async {
      http.Request? sent;

      await withServer(
        () => RiddleCoins.submit(
          categoryKey: 'animals',
          answer: 'ELEPHANT',
          hintsUsed: 2,
        ),
        (request) async {
          sent = request;
          return jsonResponse(<String, Object?>{'coinsAwarded': 2});
        },
      );

      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['word'], 'ELEPHANT');
      expect(body['hintsUsed'], 2);
      expect(body['category'], 'animals');
    });
  });

  group('word search specifics', () {
    const Set<String> eight = <String>{'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'};
    const List<String> order = <String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

    Map<String, Object?> json({
      Object? ordered = order,
      Object? found = const <String>['a'],
      Object? revealed = const <String>[],
      Object? hints = 0,
      Object? coins = 2,
    }) => <String, Object?>{
      'order': ordered,
      'found': found,
      'revealed': revealed,
      'hints': hints,
      'coins': coins,
    };

    test('reads a valid round', () {
      final round = WordSearchRound.fromJson(
        json(
          found: <String>['a', 'b'],
          revealed: <String>['b'],
          coins: 2,
        ),
        eight,
      )!;

      expect(round.total, 8);
      expect(round.found, <String>['a', 'b']);
      expect(round.revealed, <String>['b']);
      expect(wordSearchWordsPerBoard, 4);
    });

    test('revealed may be missing and words may be found on the next board',
        () {
      final raw = json(found: <String>['a', 'b', 'c', 'd', 'e'])
        ..remove('revealed');
      final round = WordSearchRound.fromJson(raw, eight)!;

      expect(round.revealed, isEmpty);
      expect(round.found, hasLength(5));
    });

    test('rejects a round that does not fit the category', () {
      final bad = <String, Object?>{
        'not an object': 'x',
        'nothing found': json(found: <String>[], coins: 0),
        'everything found': json(found: order, coins: 0),
        'duplicate found': json(found: <String>['a', 'a']),
        'unknown found': json(found: <String>['z']),
        'wrong word count': json(ordered: <String>['a', 'b']),
        'duplicate order': json(
          ordered: <String>['a', 'a', 'c', 'd', 'e', 'f', 'g', 'h'],
        ),
        'unknown order': json(
          ordered: <String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'z'],
        ),
        'negative hints': json(hints: -1),
        'negative coins': json(coins: -1),
        'revealed not found': json(revealed: <String>['b']),
        'duplicate revealed': json(
          found: <String>['a', 'b'],
          revealed: <String>['b', 'b'],
        ),
        'too many coins': json(coins: 3),
        'found beyond the current board': json(found: <String>['a', 'f']),
        'bad type': json(hints: 'x'),
      };

      for (final entry in bad.entries) {
        expect(
          WordSearchRound.fromJson(entry.value, eight),
          isNull,
          reason: entry.key,
        );
      }
    });

    test('unfinished lists how many words were found', () async {
      signIn(<String, Object>{
        'wordsearch_round_animals_user_1': jsonEncode(
          json(found: <String>['a', 'b'], coins: 4),
        ),
        'wordsearch_round_fruit_user_1': jsonEncode(json(found: <String>[])),
      });

      final result = await WordSearchProgress.unfinished(<String, Set<String>>{
        'animals': eight,
        'fruit': eight,
        'colors': eight,
      });

      expect(result.keys, <String>['animals']);
      expect(result['animals']!.done, 2);
      expect(result['animals']!.total, 8);
    });

    test('load drops a round that is not valid JSON', () async {
      signIn(<String, Object>{'wordsearch_round_animals_user_1': '{{{'});

      expect(await WordSearchProgress.load('animals', eight), isNull);
    });

    test('the found word is sent with its category', () async {
      http.Request? sent;

      await withServer(
        () => WordSearchCoins.submit(categoryKey: 'fruit', word: 'apple'),
        (request) async {
          sent = request;
          return jsonResponse(<String, Object?>{'coinsAwarded': 2});
        },
      );

      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['category'], 'fruit');
      expect(body['word'], 'apple');
    });
  });

  group('shadow specifics', () {
    const Set<String> six = <String>{'a', 'b', 'c', 'd', 'e', 'f'};
    const List<String> order = <String>['a', 'b', 'c', 'd', 'e', 'f'];

    Map<String, Object?> json({
      Object? ordered = order,
      Object? roundIndex = 0,
      Object? matched = const <String>['a'],
      Object? mistakes = 0,
      Object? coins = 2,
    }) => <String, Object?>{
      'order': ordered,
      'roundIndex': roundIndex,
      'matched': matched,
      'mistakes': mistakes,
      'coins': coins,
    };

    test('reads a valid round and counts stages and matches', () {
      final round = ShadowRound.fromJson(
        json(roundIndex: 1, matched: <String>['e'], coins: 10),
        six,
      )!;

      expect(round.stages, 2);
      expect(round.roundIndex, 1);
      expect(round.matchedTotal, 5);
      expect(shadowItemsPerStage, 4);
    });

    test('rejects a round that does not fit the category', () {
      final bad = <String, Object?>{
        'not an object': 'x',
        'wrong item count': json(ordered: <String>['a', 'b']),
        'duplicate items': json(
          ordered: <String>['a', 'a', 'c', 'd', 'e', 'f'],
        ),
        'unknown items': json(
          ordered: <String>['a', 'b', 'c', 'd', 'e', 'z'],
        ),
        'stage below zero': json(roundIndex: -1),
        'stage past the end': json(roundIndex: 2),
        'matched from another stage': json(matched: <String>['e']),
        'duplicate matches': json(matched: <String>['a', 'a']),
        'whole stage matched': json(matched: <String>['a', 'b', 'c', 'd']),
        'nothing matched yet': json(matched: <String>[], coins: 0),
        'negative mistakes': json(mistakes: -1),
        'negative coins': json(coins: -1),
        'too many coins': json(coins: 3),
        'bad type': json(roundIndex: 'x'),
      };

      for (final entry in bad.entries) {
        expect(
          ShadowRound.fromJson(entry.value, six),
          isNull,
          reason: entry.key,
        );
      }
    });

    test('unfinished lists the stage each category is at', () async {
      signIn(<String, Object>{
        'shadow_round_animals_user_1': jsonEncode(json()),
        'shadow_round_fruit_user_1': jsonEncode(json(matched: <String>[])),
      });

      final result = await ShadowProgress.unfinished(<String, Set<String>>{
        'animals': six,
        'fruit': six,
        'colors': six,
      });

      expect(result.keys, <String>['animals']);
      expect(result['animals']!.stage, 1);
      expect(result['animals']!.stages, 2);
    });

    test('load drops a round that is not valid JSON', () async {
      signIn(<String, Object>{'shadow_round_animals_user_1': '{{{'});

      expect(await ShadowProgress.load('animals', six), isNull);
    });

    test('the matched item is sent with its category', () async {
      http.Request? sent;

      await withServer(
        () => ShadowCoins.submit(categoryKey: 'fruit', itemId: 'apple'),
        (request) async {
          sent = request;
          return jsonResponse(<String, Object?>{'coinsAwarded': 2});
        },
      );

      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['category'], 'fruit');
      expect(body['item'], 'apple');
    });
  });
}
