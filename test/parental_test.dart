import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/parental_api_service.dart';

typedef Handler = Future<http.Response> Function(http.Request request);

Future<T> withServer<T>(Future<T> Function() body, Handler handler) {
  return http.runWithClient(body, () => MockClient(handler));
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

Map<String, Object?> fullReport() => <String, Object?>{
  'words': <String, Object?>{'learned': 10, 'learning': 5, 'total': 100},
  'exercises': <String, Object?>{
    'passed': 3,
    'total': 8,
    'attempts': 12,
    'averageScore': 75,
    'passPercent': 70,
  },
  'categories': <Object?>[
    <String, Object?>{
      'name': 'Animals',
      'wordsLearned': 4,
      'wordsTotal': 10,
      'attempts': 2,
      'averageScore': 80,
    },
    <String, Object?>{
      'name': 'Fruit',
      'wordsLearned': 0,
      'wordsTotal': 8,
      'attempts': 0,
      'averageScore': null,
    },
  ],
  'weakCategories': <Object?>[
    <String, Object?>{
      'name': 'Fruit',
      'wordsLearned': 0,
      'wordsTotal': 8,
      'attempts': 1,
      'averageScore': 20,
    },
  ],
  'weakWords': <Object?>[
    <String, Object?>{'term': 'cat', 'translation': 'แมว', 'wrongCount': 3},
  ],
  'streak': <String, Object?>{
    'current': 2,
    'longest': 5,
    'checkinDaysLast7': 4,
  },
  'listening': <String, Object?>{
    'minimalPairs': <String, Object?>{
      'plays': 3,
      'averageScore': 80,
      'bestScore': 100,
      'lastPlayedAt': '2026-10-01',
    },
    'fillBlank': <String, Object?>{
      'plays': 2,
      'averageScore': 50,
      'bestScore': 70,
      'topics': <Object?>[
        <String, Object?>{
          'topic': 'Animals',
          'plays': 2,
          'bestScore': 70,
          'lastScore': 50,
        },
        'junk',
      ],
    },
    'karaoke': <String, Object?>{
      'recordings': 1,
      'songs': 1,
      'totalSeconds': 90,
    },
    'animalSounds': <String, Object?>{
      'plays': 4,
      'averageScore': 10,
      'bestScore': 14,
    },
  },
  'phonics': <String, Object?>{
    'practiced': 5,
    'total': 20,
    'completedCategories': 1,
    'lastPracticedAt': '2026-10-02T10:00:00Z',
    'categories': <Object?>[
      <String, Object?>{'title': '01', 'practiced': 5, 'total': 10},
    ],
  },
  'alphabetTrain': <String, Object?>{'levelsPassed': 5, 'stars': 12},
  'monsterBattle': <String, Object?>{
    'levelsPassed': 4,
    'stars': 9,
    'monstersBeaten': 3,
  },
  'miniMarket': <String, Object?>{
    'levelsPassed': 6,
    'stars': 14,
    'itemsCollected': 7,
  },
  'bridgeBuilder': <String, Object?>{
    'levelsPassed': 8,
    'stars': 20,
    'stickers': 2,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LearningReport.fromJson', () {
    test('reads every part of the report', () {
      final report = LearningReport.fromJson(fullReport());

      expect(report.wordsLearned, 10);
      expect(report.wordsLearning, 5);
      expect(report.wordsTotal, 100);
      expect(report.exercisesPassed, 3);
      expect(report.exercisesTotal, 8);
      expect(report.exerciseAttempts, 12);
      expect(report.averageScore, 75);
      expect(report.passPercent, 70);

      expect(report.categories, hasLength(2));
      expect(report.categories.first.name, 'Animals');
      expect(report.categories.first.wordsLearned, 4);
      expect(report.categories.first.averageScore, 80);
      expect(report.categories.last.averageScore, isNull);
      expect(report.weakCategories.single.averageScore, 20);
      expect(report.weakWords.single.term, 'cat');
      expect(report.weakWords.single.translation, 'แมว');
      expect(report.weakWords.single.wrongCount, 3);

      expect(report.currentStreak, 2);
      expect(report.longestStreak, 5);
      expect(report.checkinDaysLast7, 4);

      expect(report.alphabetLevelsPassed, 5);
      expect(report.alphabetStars, 12);
      expect(report.monsterLevelsPassed, 4);
      expect(report.monsterStars, 9);
      expect(report.monstersBeaten, 3);
      expect(report.marketLevelsPassed, 6);
      expect(report.marketStars, 14);
      expect(report.marketItemsCollected, 7);
      expect(report.bridgeLevelsPassed, 8);
      expect(report.bridgeStars, 20);
      expect(report.bridgeStickers, 2);
    });

    test('reads the listening part', () {
      final listening = LearningReport.fromJson(fullReport()).listening;

      expect(listening.isEmpty, isFalse);
      expect(listening.minimalPairs.plays, 3);
      expect(listening.minimalPairs.averageScore, 80);
      expect(listening.minimalPairs.bestScore, 100);
      expect(listening.minimalPairs.lastPlayedAt, '2026-10-01');
      expect(listening.fillBlank.plays, 2);
      expect(listening.fillBlankTopics, hasLength(1));
      expect(listening.fillBlankTopics.single.topic, 'Animals');
      expect(listening.fillBlankTopics.single.plays, 2);
      expect(listening.fillBlankTopics.single.bestScore, 70);
      expect(listening.fillBlankTopics.single.lastScore, 50);
      expect(listening.karaokeRecordings, 1);
      expect(listening.karaokeSongs, 1);
      expect(listening.karaokeSeconds, 90);
      expect(listening.animalSounds.plays, 4);
      expect(listening.animalSounds.bestScore, 14);
    });

    test('reads the phonics part', () {
      final phonics = LearningReport.fromJson(fullReport()).phonics;

      expect(phonics.practiced, 5);
      expect(phonics.total, 20);
      expect(phonics.completedCategories, 1);
      expect(phonics.lastPracticedAt, DateTime.utc(2026, 10, 2, 10));
      expect(phonics.categories.single.title, '01');
      expect(phonics.categories.single.practiced, 5);
      expect(phonics.categories.single.total, 10);
    });

    test('an empty report falls back to zeros and defaults', () {
      final report = LearningReport.fromJson(<String, dynamic>{});

      expect(report.wordsLearned, 0);
      expect(report.wordsTotal, 0);
      expect(report.averageScore, isNull);
      expect(report.passPercent, 60);
      expect(report.categories, isEmpty);
      expect(report.weakCategories, isEmpty);
      expect(report.weakWords, isEmpty);
      expect(report.currentStreak, 0);
      expect(report.listening.isEmpty, isTrue);
      expect(report.listening.fillBlankTopics, isEmpty);
      expect(report.listening.minimalPairs.averageScore, isNull);
      expect(report.phonics.lastPracticedAt, isNull);
      expect(report.phonics.categories, isEmpty);
      expect(report.bridgeStickers, 0);
    });

    test('ignores parts that have the wrong shape', () {
      final report = LearningReport.fromJson(<String, dynamic>{
        'words': 'x',
        'categories': 'x',
        'weakWords': <Object?>[5, null],
        'listening': 5,
        'phonics': <String, Object?>{'categories': 'x', 'lastPracticedAt': 5},
      });

      expect(report.wordsLearned, 0);
      expect(report.categories, isEmpty);
      expect(report.weakWords, isEmpty);
      expect(report.listening.isEmpty, isTrue);
      expect(report.phonics.categories, isEmpty);
      expect(report.phonics.lastPracticedAt, isNull);
    });

    test('numbers may arrive as text or decimals, missing names become "-"',
        () {
      final progress = CategoryProgress.fromJson(<String, dynamic>{
        'wordsLearned': '5',
        'wordsTotal': 2.6,
        'attempts': 'abc',
        'averageScore': '40',
      });

      expect(progress.name, '-');
      expect(progress.wordsLearned, 5);
      expect(progress.wordsTotal, 3);
      expect(progress.attempts, 0);
      expect(progress.averageScore, 40);

      final word = LearningReport.fromJson(<String, dynamic>{
        'weakWords': <Object?>[<String, Object?>{}],
      }).weakWords.single;
      expect(word.term, '-');
      expect(word.translation, '');
      expect(word.wrongCount, 0);
    });

    test('listening is not empty when only one game was played', () {
      for (final key in <String>['minimalPairs', 'animalSounds']) {
        final listening = LearningReport.fromJson(<String, dynamic>{
          'listening': <String, Object?>{
            key: <String, Object?>{'plays': 1},
          },
        }).listening;
        expect(listening.isEmpty, isFalse, reason: key);
      }
      final karaoke = LearningReport.fromJson(<String, dynamic>{
        'listening': <String, Object?>{
          'karaoke': <String, Object?>{'recordings': 2},
        },
      }).listening;
      expect(karaoke.isEmpty, isFalse);
    });
  });

  group('ParentalApiService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'test-jwt',
      });
    });

    Matcher parentalError(String? code, [Object? message]) => throwsA(
      isA<ParentalApiException>()
          .having((e) => e.code, 'code', code)
          .having((e) => e.message, 'message', message ?? isNotEmpty),
    );

    Map<String, Object?> errorBody(String code) => <String, Object?>{
      'error': <String, Object?>{'code': code},
    };

    test('getReport sends the token and reads the report', () async {
      final report = await withServer(ParentalApiService.getReport, (
        request,
      ) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/parent/report');
        expect(request.headers['authorization'], 'Bearer test-jwt');
        return jsonResponse(fullReport());
      });

      expect(report.wordsLearned, 10);
    });

    test('verifyPassword posts the password', () async {
      var called = false;

      await withServer(() => ParentalApiService.verifyPassword('Secret1!'), (
        request,
      ) async {
        called = true;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/profile/verify-password');
        expect(request.headers['authorization'], 'Bearer test-jwt');
        expect(jsonDecode(request.body), <String, String>{
          'password': 'Secret1!',
        });
        return jsonResponse(<String, Object?>{'ok': true});
      });

      expect(called, isTrue);
    });

    test('asks to sign in again without a token', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await expectLater(
        withServer(ParentalApiService.getReport, (_) async {
          called = true;
          return jsonResponse(fullReport());
        }),
        parentalError('UNAUTHENTICATED'),
      );
      expect(called, isFalse);
    });

    test('a 401 means the session is over', () async {
      await expectLater(
        withServer(
          ParentalApiService.getReport,
          (_) async => jsonResponse(<String, Object?>{}, 401),
        ),
        parentalError('UNAUTHENTICATED'),
      );
    });

    test('maps the refusal codes of the password check', () async {
      await expectLater(
        withServer(
          () => ParentalApiService.verifyPassword('x'),
          (_) async => jsonResponse(errorBody('WRONG_PASSWORD'), 403),
        ),
        parentalError('WRONG_PASSWORD', contains('รหัสผ่านไม่ถูกต้อง')),
      );
      await expectLater(
        withServer(
          () => ParentalApiService.verifyPassword('x'),
          (_) async => jsonResponse(errorBody('TOO_MANY_ATTEMPTS'), 429),
        ),
        parentalError('TOO_MANY_ATTEMPTS', contains('15 นาที')),
      );
    });

    test('maps a report failure and unknown refusals', () async {
      await expectLater(
        withServer(
          ParentalApiService.getReport,
          (_) async => jsonResponse(errorBody('REPORT_LOAD_FAILED'), 500),
        ),
        parentalError('REPORT_LOAD_FAILED', contains('โหลดรายงานไม่สำเร็จ')),
      );
      await expectLater(
        withServer(
          ParentalApiService.getReport,
          (_) async => jsonResponse(<String, Object?>{}, 500),
        ),
        parentalError(null, contains('HTTP 500')),
      );
      await expectLater(
        withServer(
          ParentalApiService.getReport,
          (_) async => http.Response('oops', 502),
        ),
        parentalError(null, contains('HTTP 502')),
      );
    });

    test('rejects a success answer that is not a JSON object', () async {
      await expectLater(
        withServer(
          ParentalApiService.getReport,
          (_) async => http.Response('<html></html>', 200),
        ),
        parentalError('INVALID_RESPONSE'),
      );
      await expectLater(
        withServer(
          ParentalApiService.getReport,
          (_) async => jsonResponse(<int>[1]),
        ),
        parentalError('INVALID_RESPONSE'),
      );
    });

    test('reports a network failure', () async {
      await expectLater(
        withServer(
          ParentalApiService.getReport,
          (_) async => throw http.ClientException('offline'),
        ),
        parentalError('NETWORK_ERROR'),
      );
    });

    test('exception prints its message', () {
      expect(const ParentalApiException('hi').toString(), 'hi');
    });
  });
}
