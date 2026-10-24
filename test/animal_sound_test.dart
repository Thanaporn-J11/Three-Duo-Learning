import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/animal_sound_service.dart';
import 'package:threeduo_learning/services/coin_balance.dart';

import 'test_helpers.dart';

const String roundKey = 'animalsound_round_user_1';
const String queueKey = 'animalsound_sync_queue_user_1';
const String bestKey = 'animalsound_best_user_1';
const String coinQueueKey = 'animalsound_coin_queue_user_1';

const Set<String> animals = <String>{'LION', 'COW', 'DOG', 'CAT'};

Future<List<String>> strings(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(key) ?? <String>[];
}

Future<String?> stringOf(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Map<String, Object?> roundJson({
  Object? order = const <String>['LION', 'COW', 'DOG', 'CAT'],
  Object? options = 'default',
  Object? index = 1,
  Object? correct = 1,
  Object? coins = 2,
}) => <String, Object?>{
  'order': order,
  'options': options == 'default'
      ? <List<String>>[
          <String>['LION', 'COW', 'DOG'],
          <String>['COW', 'LION', 'DOG'],
          <String>['DOG', 'LION', 'CAT'],
          <String>['CAT', 'COW', 'DOG'],
        ]
      : options,
  'index': index,
  'correct': correct,
  'coins': coins,
};

AnimalSoundRound validRound({int coins = 2}) =>
    AnimalSoundRound.fromJson(roundJson(coins: coins), animals)!;

Handler ok([int status = 200, Object? body]) =>
    (_) async => jsonResponse(body ?? <String, Object?>{}, status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    signIn();
    CoinBalance.clear();
  });

  group('AnimalSoundRound', () {
    test('reads a valid round and writes it back the same', () {
      final round = AnimalSoundRound.fromJson(roundJson(), animals)!;

      expect(round.order, <String>['LION', 'COW', 'DOG', 'CAT']);
      expect(round.options, hasLength(4));
      expect(round.index, 1);
      expect(round.correct, 1);
      expect(round.coins, 2);
      expect(round.toServer(), roundJson());
    });

    test('rejects a round that does not fit the game', () {
      List<List<String>> options(List<String> third) => <List<String>>[
        <String>['LION', 'COW', 'DOG'],
        <String>['COW', 'LION', 'DOG'],
        third,
        <String>['CAT', 'COW', 'DOG'],
      ];

      final bad = <String, Object?>{
        'not an object': 'x',
        'too few animals': roundJson(order: <String>['LION', 'COW']),
        'repeated animal': roundJson(
          order: <String>['LION', 'LION', 'DOG', 'CAT'],
        ),
        'unknown animal': roundJson(
          order: <String>['LION', 'COW', 'DOG', 'EMU'],
        ),
        'options is not a list': roundJson(options: 'x'),
        'wrong number of questions': roundJson(
          options: <List<String>>[
            <String>['LION', 'COW', 'DOG'],
          ],
        ),
        'a question that is not a list': roundJson(
          options: <Object?>[
            <String>['LION', 'COW', 'DOG'],
            <String>['COW', 'LION', 'DOG'],
            'x',
            <String>['CAT', 'COW', 'DOG'],
          ],
        ),
        'not three choices': roundJson(
          options: options(<String>['DOG', 'CAT']),
        ),
        'repeated choice': roundJson(
          options: options(<String>['DOG', 'DOG', 'CAT']),
        ),
        'unknown choice': roundJson(
          options: options(<String>['DOG', 'EMU', 'CAT']),
        ),
        'right answer missing': roundJson(
          options: options(<String>['LION', 'COW', 'CAT']),
        ),
        'nothing answered yet': roundJson(index: 0, correct: 0, coins: 0),
        'everything answered': roundJson(index: 4),
        'index is not a number': roundJson(index: 'x'),
        'more correct than answered': roundJson(correct: 2),
        'negative correct': roundJson(correct: -1),
        'too many coins': roundJson(coins: 3),
        'negative coins': roundJson(coins: -1),
        'coins is not a number': roundJson(coins: 'x'),
      };

      for (final entry in bad.entries) {
        expect(
          AnimalSoundRound.fromJson(entry.value, animals),
          isNull,
          reason: entry.key,
        );
      }
    });
  });

  group('AnimalSoundProgress', () {
    Future<void> settle() async {
      await AnimalSoundProgress.flush();
      await pumpEventQueue();
      await AnimalSoundProgress.flush();
      await pumpEventQueue();
    }

    test('nothing is saved yet', () async {
      expect(await AnimalSoundProgress.load(animals), isNull);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await AnimalSoundProgress.load(animals), isNull);
    });

    test('a game left in the middle is saved and sent', () async {
      http.Request? sent;

      await withServer(() async {
        await AnimalSoundProgress.save(validRound());
        await settle();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      final loaded = await AnimalSoundProgress.load(animals);
      expect(loaded!.index, 1);
      expect(loaded.coins, 2);
      expect(sent!.method, 'PUT');
      expect(sent!.url.path, '/api/games/animalsound/progress/all');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['round'], roundJson());
      expect(body['updatedAt'], isA<String>());
      expect(await stringOf(queueKey), isNull);
    });

    test('nothing is stored or sent when signed out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(() async {
        await AnimalSoundProgress.save(validRound());
        await settle();
      }, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
      expect(await AnimalSoundProgress.load(animals), isNull);
    });

    test('a damaged or cleared record is ignored', () async {
      for (final raw in <String>[
        '{{{',
        '[1]',
        jsonEncode(<String, Object?>{'cleared': true}),
      ]) {
        signIn(<String, Object>{roundKey: raw});
        expect(await AnimalSoundProgress.load(animals), isNull, reason: raw);
      }
    });

    test('changes that could not be sent wait in the queue', () async {
      for (final handler in <Handler>[offline, ok(500), ok(401)]) {
        signIn();
        await withServer(() async {
          await AnimalSoundProgress.save(validRound());
          await settle();
        }, handler);

        expect(await stringOf(queueKey), isNotNull);
      }
    });

    test('a change the server refuses is dropped', () async {
      await withServer(() async {
        await AnimalSoundProgress.save(validRound());
        await settle();
      }, ok(400));

      expect(await stringOf(queueKey), isNull);
    });

    test('clear leaves a mark and tells the server', () async {
      final bodies = <Map<String, dynamic>>[];

      await withServer(() async {
        await AnimalSoundProgress.save(validRound());
        await AnimalSoundProgress.clear();
        await settle();
      }, (request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return jsonResponse(<String, Object?>{});
      });

      expect(await AnimalSoundProgress.load(animals), isNull);
      expect(
        (jsonDecode((await stringOf(roundKey))!) as Map)['cleared'],
        isTrue,
      );
      expect(bodies.last['round'], isNull);
      expect(bodies.last.containsKey('best'), isFalse);
    });

    test('finishing keeps the best score', () async {
      final bodies = <Map<String, dynamic>>[];

      await withServer(() async {
        await AnimalSoundProgress.saveFinished(80);
        await AnimalSoundProgress.saveFinished(60);
        await settle();
      }, (request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return jsonResponse(<String, Object?>{});
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(bestKey), 80);
      expect(bodies.every((b) => b['round'] == null), isTrue);
      expect(bodies.map((b) => b['best']), contains(80));
    });

    test('a best score waiting to be sent is never lost', () async {
      await withServer(() async {
        await AnimalSoundProgress.saveFinished(90);
        await AnimalSoundProgress.saveFinished(50);
        await AnimalSoundProgress.save(validRound());
        await AnimalSoundProgress.clear();
        await settle();
      }, offline);

      final queued = jsonDecode((await stringOf(queueKey))!) as Map;
      expect(queued['best'], 90);
      expect(queued['round'], isNull);
    });

    test('flush sends nothing when signed out or with nothing waiting',
        () async {
      var called = false;
      Future<http.Response> handler(http.Request _) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      }

      await withServer(AnimalSoundProgress.flush, handler);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await withServer(AnimalSoundProgress.flush, handler);

      expect(called, isFalse);
    });

    group('sync', () {
      final newer = DateTime.utc(2030).toIso8601String();

      Handler server(Object? body, {int status = 200}) => (request) async {
        if (request.method == 'PUT') return jsonResponse(<String, Object?>{});
        return jsonResponse(body, status);
      };

      Map<String, Object?> serverCategory({
        Object? round = 'use-valid',
        Object? best = 70,
        String? updatedAt,
      }) => <String, Object?>{
        'categories': <String, Object?>{
          'all': <String, Object?>{
            'best': best,
            'updatedAt': updatedAt ?? newer,
            'round': round == 'use-valid' ? roundJson(coins: 0) : round,
          },
        },
      };

      String localRound({String updatedAt = '2020-01-01T00:00:00.000Z'}) =>
          jsonEncode(<String, Object?>{
            ...roundJson(),
            'updatedAt': updatedAt,
          });

      test('takes a newer game and a better best score', () async {
        signIn(<String, Object>{roundKey: localRound(), bestKey: 40});

        await withServer(AnimalSoundProgress.sync, server(serverCategory()));

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(bestKey), 70);
        expect((await AnimalSoundProgress.load(animals))!.coins, 0);
      });

      test('takes a game when there is none on the phone', () async {
        await withServer(AnimalSoundProgress.sync, server(serverCategory()));

        expect(await AnimalSoundProgress.load(animals), isNotNull);
      });

      test('a lower best score does not replace the phone\'s', () async {
        signIn(<String, Object>{bestKey: 99});

        await withServer(AnimalSoundProgress.sync, server(serverCategory()));

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(bestKey), 99);
      });

      test('keeps the phone\'s game when it is newer', () async {
        signIn(<String, Object>{
          roundKey: localRound(updatedAt: '2031-01-01T00:00:00.000Z'),
        });

        await withServer(AnimalSoundProgress.sync, server(serverCategory()));

        expect((await AnimalSoundProgress.load(animals))!.coins, 2);
      });

      test('does not overwrite a change that has not been sent yet', () async {
        signIn(<String, Object>{
          roundKey: localRound(),
          queueKey: jsonEncode(<String, Object?>{
            'round': roundJson(),
            'updatedAt': '2020-01-01T00:00:00.000Z',
          }),
        });

        await withServer(AnimalSoundProgress.sync, (request) async {
          if (request.method == 'PUT') {
            return jsonResponse(<String, Object?>{}, 500);
          }
          return jsonResponse(serverCategory());
        });

        expect((await AnimalSoundProgress.load(animals))!.coins, 2);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(bestKey), 70);
      });

      test('a game finished on another phone is cleared here', () async {
        signIn(<String, Object>{roundKey: localRound()});

        await withServer(
          AnimalSoundProgress.sync,
          server(serverCategory(round: null)),
        );

        expect(await AnimalSoundProgress.load(animals), isNull);
        expect(
          (jsonDecode((await stringOf(roundKey))!) as Map)['cleared'],
          isTrue,
        );
      });

      test('ignores a server that cannot answer or answers oddly', () async {
        signIn(<String, Object>{roundKey: localRound()});

        for (final handler in <Handler>[
          server(<String, Object?>{}, status: 500),
          offline,
          server(<int>[1]),
          server(<String, Object?>{'categories': 'x'}),
          server(<String, Object?>{'categories': <String, Object?>{}}),
          server(serverCategory(updatedAt: 'never')),
        ]) {
          await withServer(AnimalSoundProgress.sync, handler);
        }

        expect((await AnimalSoundProgress.load(animals))!.coins, 2);
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        await withServer(AnimalSoundProgress.sync, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
      });
    });
  });

  group('AnimalSoundCoins', () {
    Future<dynamic> submit() => AnimalSoundCoins.submit('LION');

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
      expect(sent!.url.path, '/api/games/animalsound/answer');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['word'], 'LION');
      expect(body['answeredAt'], isA<String>());
    });

    test('an animal that already paid today gives nothing more', () async {
      final result = await withServer(
        submit,
        ok(200, <String, Object?>{'alreadyRewardedToday': true}),
      );

      expect(result.coins, 0);
      expect(result.alreadyToday, isTrue);
    });

    test('a reply that is not an object gives nothing', () async {
      final result = await withServer(submit, ok(200, <int>[1]));

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
      for (final handler in <Handler>[ok(503), offline]) {
        signIn();
        final result = await withServer(submit, handler);

        expect(result.pending, isTrue);
        expect(await strings(coinQueueKey), hasLength(1));
      }
    });

    test('an answer the server refuses is not saved', () async {
      for (final status in <int>[400, 401]) {
        signIn();
        final result = await withServer(submit, ok(status));

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

      await withServer(AnimalSoundCoins.flush, (request) async {
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
        await withServer(AnimalSoundCoins.flush, handler);
      }

      await run(ok(400));
      expect(await strings(coinQueueKey), isEmpty);

      await run(ok(500));
      expect(await strings(coinQueueKey), hasLength(2));

      await run(offline);
      expect(await strings(coinQueueKey), hasLength(2));
    });

    test('flush does nothing when signed out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(AnimalSoundCoins.flush, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });
  });
}
