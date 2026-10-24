import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/lesson_progress.dart';
import 'package:threeduo_learning/services/listening_results_service.dart';
import 'package:threeduo_learning/services/phonics_progress_service.dart';
import 'package:threeduo_learning/services/session_service.dart';
import 'package:threeduo_learning/services/user_account_preferences.dart';
import 'package:threeduo_learning/services/vocabulary_progress_service.dart';

import 'test_helpers.dart';

Future<List<String>> strings(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(key) ?? <String>[];
}

Future<String?> stringOf(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Handler ok([int status = 200, Object? body]) =>
    (_) async => jsonResponse(body ?? <String, Object?>{}, status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => signIn());

  group('VocabularyProgress', () {
    const queueKey = 'vocab_progress_queue_user_1';
    const doneKey = 'vocab_done_categories_user_1';

    String entry(String term, [String slug = 'fruit']) =>
        jsonEncode(<String, String>{'categorySlug': slug, 'term': term});

    test('a learned word is queued, trimmed, and not queued twice', () async {
      await withServer(() async {
        await VocabularyProgress.markLearned('fruit', '  Apple ');
        await VocabularyProgress.markLearned('fruit', 'Apple');
        await VocabularyProgress.markLearned('fruit', '   ');
        await VocabularyProgress.markLearned('color', 'Apple');
      }, offline);

      expect(await strings(queueKey), <String>[
        entry('Apple'),
        entry('Apple', 'color'),
      ]);
    });

    test('signed out: nothing is queued or sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(() async {
        await VocabularyProgress.markLearned('fruit', 'Apple');
        await VocabularyProgress.flush();
      }, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });

    test('a learned word is sent to the server and removed', () async {
      http.Request? sent;

      await withServer(() async {
        await VocabularyProgress.markLearned('fruit', 'Apple');
        await VocabularyProgress.flush();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      expect(sent!.url.path, '/api/vocabulary/progress/batch');
      expect(sent!.headers['authorization'], startsWith('Bearer '));
      expect(jsonDecode(sent!.body), <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'categorySlug': 'fruit', 'term': 'Apple'},
        ],
      });
      expect(await strings(queueKey), isEmpty);
    });

    test('words are sent 50 at a time', () async {
      signIn(<String, Object>{
        queueKey: <String>[for (var i = 0; i < 120; i++) entry('w$i')],
      });
      final sizes = <int>[];

      await withServer(VocabularyProgress.flush, (request) async {
        sizes.add(((jsonDecode(request.body) as Map)['items'] as List).length);
        return jsonResponse(<String, Object?>{});
      });

      expect(sizes, <int>[50, 50, 20]);
      expect(await strings(queueKey), isEmpty);
    });

    test('keeps only the newest 600 queued words', () async {
      signIn(<String, Object>{
        queueKey: <String>[for (var i = 0; i < 600; i++) entry('w$i')],
      });

      await withServer(
        () => VocabularyProgress.markLearned('fruit', 'new'),
        offline,
      );

      final queue = await strings(queueKey);
      expect(queue, hasLength(600));
      expect(queue.first, entry('w1'));
      expect(queue.last, entry('new'));
    });

    test('a refused batch is dropped, other failures are retried', () async {
      Future<List<String>> run(Handler handler) async {
        signIn(<String, Object>{queueKey: <String>[entry('a'), entry('b')]});
        await withServer(VocabularyProgress.flush, handler);
        return strings(queueKey);
      }

      expect(await run(ok(400)), isEmpty);
      expect(await run(ok(500)), hasLength(2));
      expect(await run(ok(401)), hasLength(2));
      expect(await run(offline), hasLength(2));
    });

    test('categories gone through are remembered once per child', () async {
      expect(await VocabularyProgress.doneCategories(), isEmpty);

      await VocabularyProgress.markCategoryDone('fruit');
      await VocabularyProgress.markCategoryDone('fruit');
      await VocabularyProgress.markCategoryDone('color');

      expect(await VocabularyProgress.doneCategories(), <String>{
        'fruit',
        'color',
      });
      expect(await strings(doneKey), hasLength(2));
    });

    test('signed out: no categories are remembered', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await VocabularyProgress.markCategoryDone('fruit');

      expect(await VocabularyProgress.doneCategories(), isEmpty);
    });

    group('learnedCounts', () {
      Map<String, Object?> row(String status, Object? slug) =>
          <String, Object?>{'status': status, 'category_slug': slug};

      test('counts learned words per category', () async {
        http.Request? sent;

        final counts = await withServer(VocabularyProgress.learnedCounts, (
          request,
        ) async {
          sent = request;
          return jsonResponse(<String, Object?>{
            'progress': <Object?>[
              row('learned', 'fruit'),
              row('learned', 'fruit'),
              row('learned', 'color'),
              row('seen', 'color'),
              row('learned', 5),
              'x',
            ],
          });
        });

        expect(counts, <String, int>{'fruit': 2, 'color': 1});
        expect(sent!.url.path, '/api/vocabulary/progress');
      });

      test('gives nothing when it cannot be read', () async {
        for (final handler in <Handler>[
          ok(500),
          offline,
          ok(200, <int>[1]),
          ok(200, <String, Object?>{'progress': 'x'}),
        ]) {
          expect(
            await withServer(VocabularyProgress.learnedCounts, handler),
            isEmpty,
          );
        }
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        final counts = await withServer(VocabularyProgress.learnedCounts, (
          _,
        ) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(counts, isEmpty);
        expect(called, isFalse);
      });
    });
  });

  group('PhonicsProgress', () {
    const doneKey = 'phonics_done_user_1';
    const queueKey = 'phonics_queue_user_1';

    test('no cards practiced at first, and signed out has none', () async {
      expect(await PhonicsProgress.practiced(), isEmpty);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await PhonicsProgress.practiced(), isEmpty);
    });

    test('helpers tell which cards are done and count per category', () {
      const practiced = <String>{'01|cat', '01|bat', '02|dog'};

      expect(PhonicsProgress.isDone(practiced, '01', 'cat'), isTrue);
      expect(PhonicsProgress.isDone(practiced, '02', 'cat'), isFalse);
      expect(PhonicsProgress.countFor(practiced, '01'), 2);
      expect(PhonicsProgress.countFor(practiced, '03'), 0);
    });

    test('a practiced card is kept once and queued once', () async {
      await withServer(() async {
        await PhonicsProgress.markPracticed('01', 'cat');
        await PhonicsProgress.markPracticed('01', 'cat');
        await PhonicsProgress.markPracticed('02', 'dog');
      }, offline);

      expect(await PhonicsProgress.practiced(), <String>{'01|cat', '02|dog'});
      expect(await strings(queueKey), <String>['01|cat', '02|dog']);
    });

    test('signed out: nothing is stored or sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(() async {
        await PhonicsProgress.markPracticed('01', 'cat');
        await PhonicsProgress.flush();
      }, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
      expect(await PhonicsProgress.practiced(), isEmpty);
    });

    test('cards are sent to the server and the queue is emptied', () async {
      http.Request? sent;

      await withServer(() async {
        await PhonicsProgress.markPracticed('01', 'cat');
        await PhonicsProgress.markPracticed('01', 'a|b');
        await PhonicsProgress.flush();
        await pumpEventQueue();
      }, offline);
      await withServer(PhonicsProgress.flush, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      expect(sent!.url.path, '/api/phonics/progress');
      expect(jsonDecode(sent!.body), <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'categoryId': '01', 'word': 'cat'},
          <String, Object?>{'categoryId': '01', 'word': 'a|b'},
        ],
      });
      expect(await strings(queueKey), isEmpty);
      expect(await PhonicsProgress.practiced(), hasLength(2));
    });

    test('broken queue entries are dropped, not sent', () async {
      signIn(<String, Object>{
        queueKey: <String>['broken', '|nocategory', '01|cat'],
      });
      List<Object?>? items;

      await withServer(PhonicsProgress.flush, (request) async {
        items = (jsonDecode(request.body) as Map)['items'] as List;
        return jsonResponse(<String, Object?>{});
      });

      expect(items, hasLength(1));
      expect(await strings(queueKey), isEmpty);
    });

    test('cards are sent 50 at a time', () async {
      signIn(<String, Object>{
        queueKey: <String>[for (var i = 0; i < 70; i++) '01|w$i'],
      });
      final sizes = <int>[];

      await withServer(PhonicsProgress.flush, (request) async {
        sizes.add(((jsonDecode(request.body) as Map)['items'] as List).length);
        return jsonResponse(<String, Object?>{});
      });

      expect(sizes, <int>[50, 20]);
    });

    test('a refused batch is dropped, other failures are retried', () async {
      Future<List<String>> run(Handler handler) async {
        signIn(<String, Object>{queueKey: <String>['01|a', '01|b']});
        await withServer(PhonicsProgress.flush, handler);
        return strings(queueKey);
      }

      expect(await run(ok(400)), isEmpty);
      expect(await run(ok(500)), hasLength(2));
      expect(await run(offline), hasLength(2));
    });

    group('sync', () {
      test('adds the server cards to the ones on the phone', () async {
        signIn(<String, Object>{
          doneKey: <String>['01|cat'],
        });

        await withServer(
          PhonicsProgress.sync,
          ok(200, <String, Object?>{
            'progress': <Object?>[
              <String, Object?>{'categoryId': '02', 'word': 'dog'},
              <String, Object?>{'categoryId': '01', 'word': 'cat'},
              <String, Object?>{'categoryId': 1, 'word': 'x'},
              'x',
            ],
          }),
        );

        expect(await PhonicsProgress.practiced(), <String>{
          '01|cat',
          '02|dog',
        });
      });

      test('sends what is waiting first', () async {
        signIn(<String, Object>{
          queueKey: <String>['01|cat'],
        });
        final calls = <String>[];

        await withServer(PhonicsProgress.sync, (request) async {
          calls.add(request.method);
          return jsonResponse(<String, Object?>{'progress': <Object?>[]});
        });

        expect(calls, <String>['POST', 'GET']);
      });

      test('ignores a server that cannot answer or answers oddly', () async {
        signIn(<String, Object>{
          doneKey: <String>['01|cat'],
        });

        for (final handler in <Handler>[
          ok(500),
          offline,
          ok(200, <int>[1]),
          ok(200, <String, Object?>{'progress': 'x'}),
        ]) {
          await withServer(PhonicsProgress.sync, handler);
        }

        expect(await PhonicsProgress.practiced(), <String>{'01|cat'});
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        await withServer(PhonicsProgress.sync, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
      });
    });
  });

  group('LessonProgress', () {
    const key = 'lesson_progress_t1_user_1';
    const queueKey = 'lesson_sync_queue_user_1';

    Future<void> settle() async {
      await LessonProgress.flush();
      await pumpEventQueue();
      await LessonProgress.flush();
      await pumpEventQueue();
    }

    test('nothing is saved yet', () async {
      expect(await LessonProgress.load('t1', 10), isNull);
    });

    test('a position is saved and read back', () async {
      await withServer(() async {
        await LessonProgress.save('t1', 3, 2);
        await settle();
      }, offline);

      final saved = await LessonProgress.load('t1', 10);
      expect(saved!.index, 3);
      expect(saved.correct, 2);
    });

    test('a position that no longer fits the lesson is ignored', () async {
      final cases = <String, String>{
        'not started': '0:0:5',
        'past the end': '10:2:5',
        'more correct than answered': '3:4:5',
        'negative correct': '3:-1:5',
        'finished': '-1:0:5',
        'not numbers': 'a:b:5',
        'bad time': '3:2:x',
        'too many parts': '3:2:5:6',
        'one part': '3',
      };

      for (final entry in cases.entries) {
        signIn(<String, Object>{key: entry.value});
        expect(
          await LessonProgress.load('t1', 10),
          isNull,
          reason: entry.key,
        );
      }
    });

    test('an old position without a time is still understood', () async {
      signIn(<String, Object>{key: '3:2'});

      final saved = await LessonProgress.load('t1', 10);

      expect(saved!.index, 3);
    });

    test('finishing a lesson clears the position', () async {
      await withServer(() async {
        await LessonProgress.save('t1', 3, 2);
        await LessonProgress.clear('t1');
        await settle();
      }, offline);

      expect(await LessonProgress.load('t1', 10), isNull);
      expect(await stringOf(key), startsWith('-1:0:'));
    });

    test('a position is sent to the server', () async {
      final requests = <http.Request>[];

      await withServer(() async {
        await LessonProgress.save('a b/c', 3, 2);
        await LessonProgress.clear('t1');
        await settle();
      }, (request) async {
        requests.add(request);
        return jsonResponse(<String, Object?>{});
      });

      expect(requests.map((r) => r.method).toSet(), <String>{'PUT'});
      expect(
        requests.map((r) => r.url.path),
        contains('/api/lesson-progress/a%20b%2Fc'),
      );
      final saved = requests.firstWhere(
        (r) => r.url.path.endsWith('a%20b%2Fc'),
      );
      final body = jsonDecode(saved.body) as Map<String, dynamic>;
      expect(body['index'], 3);
      expect(body['correct'], 2);
      expect(body['updatedAt'], isA<String>());
      final cleared = requests.firstWhere((r) => r.url.path.endsWith('/t1'));
      expect(jsonDecode(cleared.body)['index'], isNull);
      expect(await stringOf(queueKey), '{}');
    });

    test('changes made offline wait in the queue', () async {
      await withServer(() async {
        await LessonProgress.save('t1', 3, 2);
        await settle();
      }, offline);

      final queue = jsonDecode((await stringOf(queueKey))!) as Map;
      expect(queue.keys, <String>['t1']);
    });

    test('the position is kept on the phone even when signed out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(() async {
        await LessonProgress.save('t1', 3, 2);
        await settle();
      }, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
      expect(await stringOf('lesson_progress_t1'), isNotNull);
      expect((await LessonProgress.load('t1', 10))!.index, 3);
    });

    group('flush', () {
      final entry = <String, Object?>{
        't1': <String, Object?>{
          'index': 3,
          'correct': 2,
          'updatedAt': '2020-01-01T00:00:00.000Z',
        },
      };

      Future<Map> run(Handler handler, Object queue) async {
        signIn(<String, Object>{queueKey: jsonEncode(queue)});
        await withServer(LessonProgress.flush, handler);
        return jsonDecode((await stringOf(queueKey))!) as Map;
      }

      test('removes what the server accepted or refused', () async {
        expect(await run(ok(), entry), isEmpty);
        expect(await run(ok(400), entry), isEmpty);
      });

      test('keeps what could not be sent', () async {
        expect(await run(ok(500), entry), hasLength(1));
        expect(await run(offline, entry), hasLength(1));
      });

      test('an empty or damaged queue, or signed out, sends nothing', () async {
        var called = false;
        Future<http.Response> handler(http.Request _) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        }

        signIn(<String, Object>{queueKey: '{{{'});
        await withServer(LessonProgress.flush, handler);
        signIn(<String, Object>{queueKey: jsonEncode(<int>[1])});
        await withServer(LessonProgress.flush, handler);
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await withServer(LessonProgress.flush, handler);

        expect(called, isFalse);
      });
    });

    group('sync', () {
      final newer = DateTime.utc(2030).toIso8601String();
      final newerMs = DateTime.utc(2030).millisecondsSinceEpoch;

      Handler server(Object? body, {int status = 200, int putStatus = 200}) =>
          (request) async {
            if (request.method == 'PUT') {
              return jsonResponse(<String, Object?>{}, putStatus);
            }
            return jsonResponse(body, status);
          };

      Map<String, Object?> topics(Map<String, Object?> t) => <String, Object?>{
        'topics': t,
      };

      test('takes a newer position from the server', () async {
        signIn(<String, Object>{key: '2:1:1'});

        await withServer(
          LessonProgress.sync,
          server(topics(<String, Object?>{
            't1': <String, Object?>{
              'index': 5,
              'correct': 4,
              'updatedAt': newer,
            },
          })),
        );

        expect(await stringOf(key), '5:4:$newerMs');
        expect((await LessonProgress.load('t1', 10))!.index, 5);
      });

      test('takes a position when there is none on the phone', () async {
        await withServer(
          LessonProgress.sync,
          server(topics(<String, Object?>{
            't1': <String, Object?>{
              'index': 5,
              'correct': 4,
              'updatedAt': newer,
            },
          })),
        );

        expect(await stringOf(key), '5:4:$newerMs');
      });

      test('a lesson finished on another phone is finished here', () async {
        signIn(<String, Object>{key: '2:1:1'});

        await withServer(
          LessonProgress.sync,
          server(topics(<String, Object?>{
            't1': <String, Object?>{
              'index': null,
              'correct': null,
              'updatedAt': newer,
            },
          })),
        );

        expect(await stringOf(key), '-1:0:$newerMs');
        expect(await LessonProgress.load('t1', 10), isNull);
      });

      test('keeps the phone when it is newer or the same age', () async {
        signIn(<String, Object>{key: '2:1:$newerMs'});

        await withServer(
          LessonProgress.sync,
          server(topics(<String, Object?>{
            't1': <String, Object?>{
              'index': 5,
              'correct': 4,
              'updatedAt': newer,
            },
          })),
        );

        expect(await stringOf(key), '2:1:$newerMs');
      });

      test('does not overwrite a change that has not been sent yet', () async {
        signIn(<String, Object>{
          key: '2:1:1',
          queueKey: jsonEncode(<String, Object?>{
            't1': <String, Object?>{
              'index': 2,
              'correct': 1,
              'updatedAt': '2020-01-01T00:00:00.000Z',
            },
          }),
        });

        await withServer(
          LessonProgress.sync,
          server(
            topics(<String, Object?>{
              't1': <String, Object?>{
                'index': 5,
                'correct': 4,
                'updatedAt': newer,
              },
            }),
            putStatus: 500,
          ),
        );

        expect(await stringOf(key), '2:1:1');
      });

      test('skips entries it cannot use', () async {
        await withServer(
          LessonProgress.sync,
          server(topics(<String, Object?>{
            't1': 'x',
            't2': <String, Object?>{'index': 1, 'correct': 1},
            't3': <String, Object?>{'index': 1, 'updatedAt': 'never'},
          })),
        );

        expect(await stringOf(key), isNull);
        expect(await stringOf('lesson_progress_t2_user_1'), isNull);
        expect(await stringOf('lesson_progress_t3_user_1'), isNull);
      });

      test('ignores a server that cannot answer or answers oddly', () async {
        await withServer(LessonProgress.sync, server(<String, Object?>{}, status: 500));
        await withServer(LessonProgress.sync, offline);
        await withServer(LessonProgress.sync, server(<int>[1]));
        await withServer(
          LessonProgress.sync,
          server(<String, Object?>{'topics': 'x'}),
        );

        expect(await stringOf(key), isNull);
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        await withServer(LessonProgress.sync, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
      });
    });
  });

  group('ListeningResults', () {
    const queueKey = 'listening_results_queue_user_1';

    test('a result is sent with the time it was played', () async {
      http.Request? sent;

      await withServer(
        () => ListeningResults.submit(
          game: 'fill_blank',
          topic: 'animals',
          score: 4,
          total: 5,
        ),
        (request) async {
          sent = request;
          return jsonResponse(<String, Object?>{}, 201);
        },
      );

      expect(sent!.url.path, '/api/listening/results');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['game'], 'fill_blank');
      expect(body['topic'], 'animals');
      expect(body['score'], 4);
      expect(body['total'], 5);
      expect(body['playedAt'], isA<String>());
      expect(body.containsKey('durationSeconds'), isFalse);
      expect(await strings(queueKey), isEmpty);
    });

    test('fields that were not given are left out', () async {
      http.Request? sent;

      await withServer(
        () => ListeningResults.submit(game: 'karaoke', durationSeconds: 90),
        (request) async {
          sent = request;
          return jsonResponse(<String, Object?>{}, 201);
        },
      );

      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['durationSeconds'], 90);
      expect(body.keys.toSet(), <String>{'game', 'durationSeconds', 'playedAt'});
    });

    test('signed out: nothing is queued or sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(() => ListeningResults.submit(game: 'karaoke'), (
        _,
      ) async {
        called = true;
        return jsonResponse(<String, Object?>{}, 201);
      });

      expect(called, isFalse);
    });

    test('a result the server will never accept is dropped', () async {
      await withServer(
        () => ListeningResults.submit(game: 'karaoke'),
        ok(400),
      );

      expect(await strings(queueKey), isEmpty);
    });

    test('other answers and no network keep the result for later', () async {
      for (final handler in <Handler>[ok(200), ok(401), ok(500), offline]) {
        signIn();
        await withServer(
          () => ListeningResults.submit(game: 'karaoke'),
          handler,
        );

        expect(await strings(queueKey), hasLength(1));
      }
    });

    test('keeps only the newest 500 results', () async {
      signIn(<String, Object>{
        queueKey: <String>[for (var i = 0; i < 500; i++) '{"n":$i}'],
      });

      await withServer(() => ListeningResults.submit(game: 'karaoke'), offline);

      final queue = await strings(queueKey);
      expect(queue, hasLength(500));
      expect(queue.first, '{"n":1}');
    });

    test('flush sends the waiting results in order', () async {
      signIn(<String, Object>{
        queueKey: <String>['{"n":1}', '{"n":2}'],
      });
      final sent = <Object?>[];

      await withServer(ListeningResults.flush, (request) async {
        sent.add((jsonDecode(request.body) as Map)['n']);
        return jsonResponse(<String, Object?>{}, 201);
      });

      expect(sent, <Object?>[1, 2]);
      expect(await strings(queueKey), isEmpty);
    });

    test('flush stops at the first failure', () async {
      signIn(<String, Object>{
        queueKey: <String>['{"n":1}', '{"n":2}'],
      });
      var calls = 0;

      await withServer(ListeningResults.flush, (_) async {
        calls++;
        return jsonResponse(<String, Object?>{}, 500);
      });

      expect(calls, 1);
      expect(await strings(queueKey), hasLength(2));
    });

    test('flush does nothing when signed out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(ListeningResults.flush, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{}, 201);
      });

      expect(called, isFalse);
    });
  });

  group('SessionService', () {
    var resets = 0;
    var hooks = 0;

    setUpAll(() {
      UserAccountPreferences.registerMemoryResetter(() => resets++);
      UserAccountPreferences.registerLogoutHook(() async => hooks++);
    });

    setUp(() {
      resets = 0;
      hooks = 0;
    });

    test('no saved sign-in means signed out, without asking the server',
        () async {
      var called = false;
      Future<http.Response> handler(http.Request _) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      }

      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(
        await withServer(SessionService.restore, handler),
        SessionStatus.signedOut,
      );

      SharedPreferences.setMockInitialValues(<String, Object>{'jwt_token': ''});
      expect(
        await withServer(SessionService.restore, handler),
        SessionStatus.signedOut,
      );

      expect(called, isFalse);
    });

    test('a confirmed sign-in is renewed with the fresh token', () async {
      http.Request? sent;

      final status = await withServer(SessionService.restore, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{'token': 'fresh'});
      });

      expect(status, SessionStatus.signedIn);
      expect(sent!.method, 'POST');
      expect(sent!.url.path, '/api/session/refresh');
      expect(sent!.headers['authorization'], startsWith('Bearer '));
      expect(await stringOf('jwt_token'), 'fresh');
    });

    test('a reply without a new token keeps the old one', () async {
      final old = await stringOf('jwt_token');

      for (final handler in <Handler>[
        ok(200, <String, Object?>{'token': ''}),
        ok(200, <String, Object?>{}),
        ok(200, <int>[1]),
        (_) async => http.Response('not json', 200),
      ]) {
        expect(
          await withServer(SessionService.restore, handler),
          SessionStatus.signedIn,
        );
        expect(await stringOf('jwt_token'), old);
      }
    });

    test('a session the server ended signs the child out', () async {
      for (final status in <int>[401, 403]) {
        signIn();
        resets = 0;
        hooks = 0;

        final result = await withServer(SessionService.restore, ok(status));

        expect(result, SessionStatus.signedOut);
        expect(await stringOf('jwt_token'), isNull);
        expect(resets, 1);
        expect(hooks, 1);
      }
    });

    test('no network or a server problem lets the child in offline', () async {
      final old = await stringOf('jwt_token');

      expect(
        await withServer(SessionService.restore, offline),
        SessionStatus.offline,
      );
      expect(
        await withServer(SessionService.restore, ok(500)),
        SessionStatus.offline,
      );
      expect(await stringOf('jwt_token'), old);
      expect(resets, 0);
    });
  });
}
