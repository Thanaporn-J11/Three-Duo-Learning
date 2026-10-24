import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/models/exercise_attempt.dart';
import 'package:threeduo_learning/services/device_api_service.dart';
import 'package:threeduo_learning/services/exercise_api_service.dart';

typedef Handler = Future<http.Response> Function(http.Request request);

Future<T> withServer<T>(Future<T> Function() body, Handler handler) {
  return http.runWithClient(body, () => MockClient(handler));
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

Map<String, Object?> option(int n) => <String, Object?>{
  'id': n,
  'label': 'option $n',
};

Map<String, Object?> question({
  Object? id = 1,
  String type = 'image_to_word',
  int options = 4,
  Object? targetWord,
  Object? feedback,
}) => <String, Object?>{
  'id': id,
  'prompt': 'What is this?',
  'type': type,
  'options': <Object?>[for (var i = 1; i <= options; i++) option(i)],
  if (targetWord != null) 'targetWord': targetWord,
  if (feedback != null) 'feedback': feedback,
};

Map<String, Object?> feedback({bool correct = true}) => <String, Object?>{
  'selectedOptionId': 2,
  'isCorrect': correct,
  'correctOption': <String, Object?>{
    'id': 3,
    'label': 'cat',
    'word': <String, Object?>{
      'term': 'cat',
      'translation': 'แมว',
      'thaiPronunciation': 'แคท',
      'imageUrl': 'assets/cat.png',
    },
  },
  'translation': 'แมว',
  'thaiPronunciation': 'แคท',
};

Map<String, Object?> attemptResponse({
  List<Object?>? questions,
  Map<String, Object?>? attempt,
}) => <String, Object?>{
  'attempt':
      attempt ??
      <String, Object?>{
        'id': 'a1',
        'exerciseId': 9,
        'categorySlug': 'animals',
        'status': 'in_progress',
        'questionCount': 1,
      },
  'questions': questions ?? <Object?>[question()],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExerciseAttempt models', () {
    test('reads an attempt with its questions', () {
      final attempt = ExerciseAttempt.fromResponse(
        attemptResponse(
          questions: <Object?>[
            question(
              targetWord: <String, Object?>{
                'imageUrl': 'assets/cat.png',
                'term': 'cat',
                'translation': 'แมว',
                'thaiPronunciation': 'แคท',
              },
            ),
            question(id: 2, type: 'word_to_image', feedback: feedback()),
          ],
          attempt: <String, Object?>{
            'id': 'a1',
            'exerciseId': 9,
            'categorySlug': 'animals',
            'status': 'submitted',
            'questionCount': 2,
            'score': 2,
            'totalQuestions': 2,
            'coinsAwarded': 10,
          },
        ),
      );

      expect(attempt.id, 'a1');
      expect(attempt.exerciseId, '9');
      expect(attempt.categorySlug, 'animals');
      expect(attempt.status, 'submitted');
      expect(attempt.questionCount, 2);
      expect(attempt.score, 2);
      expect(attempt.totalQuestions, 2);
      expect(attempt.coinsAwarded, 10);

      final first = attempt.questions.first;
      expect(first.id, '1');
      expect(first.usesImageOptions, isFalse);
      expect(first.options, hasLength(4));
      expect(first.options.first.label, 'option 1');
      expect(first.targetWord!.term, 'cat');
      expect(first.targetWord!.imageUrl, 'assets/cat.png');
      expect(first.feedback, isNull);

      final second = attempt.questions.last;
      expect(second.usesImageOptions, isTrue);
      expect(second.feedback!.isCorrect, isTrue);
      expect(second.feedback!.selectedOptionId, '2');
      expect(second.feedback!.correctOption.id, '3');
      expect(second.feedback!.correctOption.word!.term, 'cat');
      expect(second.feedback!.translation, 'แมว');
    });

    test('score fields are optional while the quiz is open', () {
      final attempt = ExerciseAttempt.fromResponse(attemptResponse());

      expect(attempt.score, isNull);
      expect(attempt.totalQuestions, isNull);
      expect(attempt.coinsAwarded, isNull);
    });

    test('rejects attempts that are not usable', () {
      expect(
        () => ExerciseAttempt.fromResponse(<String, dynamic>{}),
        throwsFormatException,
      );
      expect(
        () => ExerciseAttempt.fromResponse(
          <String, dynamic>{...attemptResponse()}..remove('questions'),
        ),
        throwsFormatException,
      );
      expect(
        () => ExerciseAttempt.fromResponse(
          attemptResponse(questions: <Object?>[]),
        ),
        throwsFormatException,
      );
      expect(
        () => ExerciseAttempt.fromResponse(
          attemptResponse(questions: <Object?>[question(options: 3)]),
        ),
        throwsFormatException,
      );
      expect(
        () => ExerciseAttempt.fromResponse(
          attemptResponse(questions: <Object?>[question(type: 'essay')]),
        ),
        throwsFormatException,
      );
      expect(
        () => ExerciseAttempt.fromResponse(
          attemptResponse(questions: <Object?>[question(id: 0)]),
        ),
        throwsFormatException,
      );
      expect(
        () => ExerciseAttempt.fromResponse(
          attemptResponse(
            attempt: <String, Object?>{
              'id': 'a1',
              'exerciseId': 1,
              'categorySlug': 'x',
              'status': 's',
              'questionCount': -1,
            },
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects feedback without a verdict or the right answer', () {
      expect(
        () => ExerciseAnswerFeedback.fromJson(<String, dynamic>{
          'isCorrect': 'yes',
          'correctOption': <String, Object?>{'id': 1, 'label': 'a'},
        }),
        throwsFormatException,
      );
      expect(
        () => ExerciseAnswerFeedback.fromJson(<String, dynamic>{
          'isCorrect': true,
        }),
        throwsFormatException,
      );
    });

    test('answer result reads the replayed flag', () {
      final fresh = ExerciseAnswerResult.fromJson(<String, dynamic>{
        'questionId': 5,
        'feedback': feedback(correct: false),
      });
      expect(fresh.questionId, '5');
      expect(fresh.feedback.isCorrect, isFalse);
      expect(fresh.replayed, isFalse);

      final replay = ExerciseAnswerResult.fromJson(<String, dynamic>{
        'questionId': 5,
        'feedback': feedback(),
        'replayed': true,
      });
      expect(replay.replayed, isTrue);
    });

    test('submit result accepts numbers sent as text', () {
      final result = ExerciseSubmitResult.fromJson(<String, dynamic>{
        'attempt': <String, Object?>{
          'id': 'a1',
          'score': '3',
          'totalQuestions': 5,
          'coinsAwarded': '0',
        },
      });

      expect(result.attemptId, 'a1');
      expect(result.score, 3);
      expect(result.totalQuestions, 5);
      expect(result.coinsAwarded, 0);

      expect(
        () => ExerciseSubmitResult.fromJson(<String, dynamic>{
          'attempt': <String, Object?>{'id': 'a1', 'score': 'x'},
        }),
        throwsFormatException,
      );
    });
  });

  group('ExerciseApiService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'test-jwt',
      });
    });

    Matcher exerciseError({String? code, int? status}) =>
        throwsA(
          isA<ExerciseApiException>()
              .having((e) => e.code, 'code', code)
              .having((e) => e.statusCode, 'statusCode', status),
        );

    test('makes version 4 style idempotency keys that differ every time', () {
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final keys = <String>{
        for (var i = 0; i < 20; i++) ExerciseApiService.newIdempotencyKey(),
      };

      expect(keys, hasLength(20));
      expect(keys.every(pattern.hasMatch), isTrue);
    });

    test('startAttempt posts the category and the idempotency key', () async {
      final attempt = await withServer(
        () => ExerciseApiService.startAttempt(
          categorySlug: 'animals',
          idempotencyKey: 'key-1',
        ),
        (request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/exercises/attempts');
          expect(request.headers['authorization'], 'Bearer test-jwt');
          expect(request.headers['content-type'], startsWith('application/json'));
          expect(jsonDecode(request.body), <String, String>{
            'idempotencyKey': 'key-1',
            'categorySlug': 'animals',
          });
          return jsonResponse(attemptResponse());
        },
      );

      expect(attempt.id, 'a1');
      expect(attempt.questions, hasLength(1));
    });

    test('getAttempt encodes the id in the path', () async {
      await withServer(() => ExerciseApiService.getAttempt('a/b'), (
        request,
      ) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/exercises/attempts/a%2Fb');
        expect(request.body, isEmpty);
        return jsonResponse(attemptResponse());
      });
    });

    test('submitAnswer sends the chosen option and reads the verdict',
        () async {
      final result = await withServer(
        () => ExerciseApiService.submitAnswer(
          attemptId: 'a1',
          questionId: 'q1',
          optionId: 'o2',
        ),
        (request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/exercises/attempts/a1/answers');
          expect(jsonDecode(request.body), <String, String>{
            'questionId': 'q1',
            'optionId': 'o2',
          });
          return jsonResponse(<String, Object?>{
            'questionId': 'q1',
            'feedback': feedback(),
          });
        },
      );

      expect(result.questionId, 'q1');
      expect(result.feedback.isCorrect, isTrue);
    });

    test('submitAttempt posts an empty body and reads the score', () async {
      final result = await withServer(
        () => ExerciseApiService.submitAttempt('a1'),
        (request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/exercises/attempts/a1/submit');
          expect(jsonDecode(request.body), isEmpty);
          return jsonResponse(<String, Object?>{
            'attempt': <String, Object?>{
              'id': 'a1',
              'score': 4,
              'totalQuestions': 5,
              'coinsAwarded': 8,
            },
          });
        },
      );

      expect(result.score, 4);
      expect(result.coinsAwarded, 8);
    });

    test('malformed success bodies become a friendly error', () async {
      await expectLater(
        withServer(
          () => ExerciseApiService.getAttempt('a1'),
          (_) async => jsonResponse(<String, Object?>{'attempt': 5}),
        ),
        throwsA(isA<ExerciseApiException>()),
      );
      await expectLater(
        withServer(
          () => ExerciseApiService.submitAnswer(
            attemptId: 'a1',
            questionId: 'q',
            optionId: 'o',
          ),
          (_) async => jsonResponse(<String, Object?>{'questionId': 1}),
        ),
        throwsA(isA<ExerciseApiException>()),
      );
      await expectLater(
        withServer(
          () => ExerciseApiService.submitAttempt('a1'),
          (_) async => http.Response('', 200),
        ),
        throwsA(isA<ExerciseApiException>()),
      );
    });

    test('asks to sign in again when there is no token', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await expectLater(
        withServer(() => ExerciseApiService.getAttempt('a1'), (_) async {
          called = true;
          return jsonResponse(attemptResponse());
        }),
        exerciseError(code: 'UNAUTHENTICATED', status: 401),
      );
      expect(called, isFalse);
    });

    test('maps known refusal codes', () async {
      for (final code in <String>[
        'QUIZ_NOT_AVAILABLE',
        'ATTEMPT_EXPIRED',
        'ANSWERS_INCOMPLETE',
        'ANSWER_ALREADY_RECORDED',
      ]) {
        await expectLater(
          withServer(
            () => ExerciseApiService.submitAttempt('a1'),
            (_) async => jsonResponse(<String, Object?>{
              'error': <String, Object?>{'code': code, 'message': 'ignored'},
            }, 409),
          ),
          exerciseError(code: code, status: 409),
        );
      }
    });

    test('uses the server message, then the status, for other refusals',
        () async {
      await expectLater(
        withServer(
          () => ExerciseApiService.getAttempt('a1'),
          (_) async => jsonResponse(<String, Object?>{
            'error': <String, Object?>{'message': 'custom'},
          }, 400),
        ),
        throwsA(
          isA<ExerciseApiException>()
              .having((e) => e.message, 'message', 'custom')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
      await expectLater(
        withServer(
          () => ExerciseApiService.getAttempt('a1'),
          (_) async => jsonResponse(<String, Object?>{'message': 'top'}, 400),
        ),
        throwsA(
          isA<ExerciseApiException>().having((e) => e.message, 'message', 'top'),
        ),
      );
      await expectLater(
        withServer(
          () => ExerciseApiService.getAttempt('a1'),
          (_) async => http.Response('', 500),
        ),
        throwsA(
          isA<ExerciseApiException>().having(
            (e) => e.message,
            'message',
            contains('500'),
          ),
        ),
      );
    });

    test('a 401 means the session is over', () async {
      await expectLater(
        withServer(
          () => ExerciseApiService.getAttempt('a1'),
          (_) async => jsonResponse(<String, Object?>{'error': 'x'}, 401),
        ),
        exerciseError(code: null, status: 401),
      );
    });

    test('rejects answers that are not a JSON object', () async {
      await expectLater(
        withServer(
          () => ExerciseApiService.getAttempt('a1'),
          (_) async => http.Response('<html></html>', 200),
        ),
        throwsA(
          isA<ExerciseApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            200,
          ),
        ),
      );
      await expectLater(
        withServer(
          () => ExerciseApiService.getAttempt('a1'),
          (_) async => jsonResponse(<int>[1]),
        ),
        throwsA(isA<ExerciseApiException>()),
      );
    });

    test('reports a network failure', () async {
      await expectLater(
        withServer(
          () => ExerciseApiService.getAttempt('a1'),
          (_) async => throw http.ClientException('offline'),
        ),
        throwsA(isA<ExerciseApiException>()),
      );
    });

    test('exception prints its message', () {
      expect(const ExerciseApiException('hi').toString(), 'hi');
    });
  });

  group('DeviceApiService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'test-jwt',
      });
    });

    Matcher deviceError([Object? message]) => throwsA(
      isA<DeviceApiException>().having(
        (e) => e.message,
        'message',
        message ?? isNotEmpty,
      ),
    );

    test('getDevices lists the devices and skips bad entries', () async {
      final devices = await withServer(DeviceApiService.getDevices, (
        request,
      ) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/devices');
        expect(request.headers['authorization'], 'Bearer test-jwt');
        return jsonResponse(<String, Object?>{
          'devices': <Object?>[
            <String, Object?>{'tokenId': 't1', 'current': true},
            'junk',
            <String, Object?>{'tokenId': 't2'},
          ],
        });
      });

      expect(devices.map((d) => d['tokenId']), <Object?>['t1', 't2']);
    });

    test('getDevices rejects a list that is not a list', () async {
      await expectLater(
        withServer(
          DeviceApiService.getDevices,
          (_) async => jsonResponse(<String, Object?>{'devices': 'x'}),
        ),
        deviceError(),
      );
    });

    test('logoutOtherDevices returns how many were signed out', () async {
      final count = await withServer(DeviceApiService.logoutOtherDevices, (
        request,
      ) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/devices/logout-others');
        return jsonResponse(<String, Object?>{'revokedCount': 3});
      });
      expect(count, 3);

      expect(
        await withServer(
          DeviceApiService.logoutOtherDevices,
          (_) async => jsonResponse(<String, Object?>{'revokedCount': 'x'}),
        ),
        0,
      );
    });

    test('logoutCurrentSession posts to the logout route', () async {
      var called = false;
      await withServer(DeviceApiService.logoutCurrentSession, (request) async {
        called = true;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/devices/logout');
        return jsonResponse(<String, Object?>{'ok': true});
      });
      expect(called, isTrue);
    });

    test('logoutDevice deletes one device by its encoded id', () async {
      var called = false;
      await withServer(() => DeviceApiService.logoutDevice('a b'), (
        request,
      ) async {
        called = true;
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/devices/a%20b');
        return jsonResponse(<String, Object?>{'ok': true});
      });
      expect(called, isTrue);
    });

    test('asks to sign in again when there is no token', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await expectLater(
        withServer(DeviceApiService.getDevices, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{'devices': <Object?>[]});
        }),
        deviceError(),
      );
      expect(called, isFalse);
    });

    test('maps refusals', () async {
      await expectLater(
        withServer(
          DeviceApiService.getDevices,
          (_) async => jsonResponse(<String, Object?>{'message': 'x'}, 401),
        ),
        deviceError(isNot('x')),
      );
      await expectLater(
        withServer(
          DeviceApiService.getDevices,
          (_) async => jsonResponse(<String, Object?>{'message': 'nope'}, 400),
        ),
        deviceError('nope'),
      );
      await expectLater(
        withServer(
          DeviceApiService.getDevices,
          (_) async => jsonResponse(<String, Object?>{}, 500),
        ),
        deviceError(contains('500')),
      );
    });

    test('rejects answers that are not a JSON object', () async {
      await expectLater(
        withServer(
          DeviceApiService.getDevices,
          (_) async => http.Response('<html></html>', 200),
        ),
        deviceError(contains('200')),
      );
      await expectLater(
        withServer(
          DeviceApiService.getDevices,
          (_) async => jsonResponse(<int>[1]),
        ),
        deviceError(contains('200')),
      );
    });

    test('reports a network failure', () async {
      await expectLater(
        withServer(
          DeviceApiService.getDevices,
          (_) async => throw http.ClientException('offline'),
        ),
        deviceError(),
      );
    });

    test('exception prints its message', () {
      expect(const DeviceApiException('hi').toString(), 'hi');
    });
  });
}
