import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/rewards_api_service.dart';
import 'package:threeduo_learning/services/vocabulary_api_service.dart';

typedef Handler = Future<http.Response> Function(http.Request request);

/// Runs [body] with every `http.get/post` answered by [handler].
Future<T> withServer<T>(Future<T> Function() body, Handler handler) {
  return http.runWithClient(body, () => MockClient(handler));
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

Matcher rewardsError(String code) => throwsA(
  isA<RewardsApiException>().having((e) => e.code, 'code', code),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RewardsApiService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'test-jwt',
      });
    });

    test('getBalance sends the token and reads the balance', () async {
      final balance = await withServer(RewardsApiService.getBalance, (
        request,
      ) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/rewards/balance');
        expect(request.headers['authorization'], 'Bearer test-jwt');
        return jsonResponse(<String, Object>{'balance': 125});
      });

      expect(balance, 125);
    });

    test('accepts a balance sent as a whole number or a numeric string',
        () async {
      expect(
        await withServer(
          RewardsApiService.getBalance,
          (_) async => jsonResponse(<String, Object>{'balance': 12.0}),
        ),
        12,
      );
      expect(
        await withServer(
          RewardsApiService.getBalance,
          (_) async => jsonResponse(<String, Object>{'balance': '7'}),
        ),
        7,
      );
    });

    test('rejects a negative or malformed balance', () async {
      for (final value in <Object?>[-1, 'abc', null, 1.5]) {
        await expectLater(
          withServer(
            RewardsApiService.getBalance,
            (_) async => jsonResponse(<String, Object?>{'balance': value}),
          ),
          rewardsError('INVALID_RESPONSE'),
          reason: '$value',
        );
      }
    });

    test('asks to sign in again when there is no token', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await expectLater(
        withServer(RewardsApiService.getBalance, (_) async {
          called = true;
          return jsonResponse(<String, Object>{'balance': 1});
        }),
        rewardsError('UNAUTHENTICATED'),
      );
      expect(called, isFalse);
    });

    test('getAvatarPurchases returns the balance and the owned items',
        () async {
      final result = await withServer(
        RewardsApiService.getAvatarPurchases,
        (request) async {
          expect(request.url.path, '/api/rewards/avatar-purchases');
          return jsonResponse(<String, Object>{
            'balance': 40,
            'itemKeys': <String>['hat', 'glasses', 'hat'],
          });
        },
      );

      expect(result.balance, 40);
      expect(result.itemKeys, <String>{'hat', 'glasses'});
    });

    test('getAvatarPurchases rejects a bad item list', () async {
      for (final keys in <Object?>[
        'hat',
        <Object>['hat', 3],
        null,
      ]) {
        await expectLater(
          withServer(
            RewardsApiService.getAvatarPurchases,
            (_) async => jsonResponse(<String, Object?>{
              'balance': 1,
              'itemKeys': keys,
            }),
          ),
          rewardsError('INVALID_RESPONSE'),
        );
      }
    });

    test('purchaseAvatar posts the item and reads the result', () async {
      final result = await withServer(
        () => RewardsApiService.purchaseAvatar('hat'),
        (request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/rewards/avatar-purchases');
          expect(request.headers['content-type'], startsWith('application/json'));
          expect(jsonDecode(request.body), <String, String>{'itemKey': 'hat'});
          return jsonResponse(<String, Object>{
            'purchase': <String, Object>{'itemKey': 'hat', 'price': 50},
            'balance': 150,
            'itemKeys': <String>['hat'],
          });
        },
      );

      expect(result.itemKey, 'hat');
      expect(result.price, 50);
      expect(result.balance, 150);
      expect(result.itemKeys, <String>{'hat'});
    });

    test('purchaseAvatar rejects a result for a different item', () async {
      await expectLater(
        withServer(
          () => RewardsApiService.purchaseAvatar('hat'),
          (_) async => jsonResponse(<String, Object>{
            'purchase': <String, Object>{'itemKey': 'crown', 'price': 50},
            'balance': 1,
            'itemKeys': <String>['crown'],
          }),
        ),
        throwsA(isA<RewardsApiException>()),
      );
      await expectLater(
        withServer(
          () => RewardsApiService.purchaseAvatar('hat'),
          (_) async => jsonResponse(<String, Object>{
            'balance': 1,
            'itemKeys': <String>[],
          }),
        ),
        throwsA(isA<RewardsApiException>()),
      );
    });

    test('maps a server refusal to a specific error with the numbers',
        () async {
      await expectLater(
        withServer(
          () => RewardsApiService.purchaseAvatar('hat'),
          (_) async => jsonResponse(<String, Object>{
            'error': <String, Object>{
              'code': 'INSUFFICIENT_COINS',
              'balance': '5',
              'price': 50,
            },
          }, 400),
        ),
        throwsA(
          isA<RewardsApiException>()
              .having((e) => e.code, 'code', 'INSUFFICIENT_COINS')
              .having((e) => e.balance, 'balance', 5)
              .having((e) => e.price, 'price', 50),
        ),
      );

      for (final code in <String>['AVATAR_ALREADY_OWNED', 'INVALID_AVATAR_ITEM']) {
        await expectLater(
          withServer(
            () => RewardsApiService.purchaseAvatar('hat'),
            (_) async => jsonResponse(<String, Object>{
              'error': <String, Object>{'code': code},
            }, 409),
          ),
          rewardsError(code),
        );
      }
    });

    test('an unknown refusal reports the HTTP status', () async {
      await expectLater(
        withServer(
          RewardsApiService.getBalance,
          (_) async => jsonResponse(<String, Object>{}, 500),
        ),
        throwsA(
          isA<RewardsApiException>()
              .having((e) => e.code, 'code', isNull)
              .having((e) => e.message, 'message', contains('HTTP 500')),
        ),
      );
    });

    test('401 and 403 mean the session is over', () async {
      for (final status in <int>[401, 403]) {
        await expectLater(
          withServer(
            RewardsApiService.getBalance,
            (_) async => jsonResponse(<String, Object>{'error': 'x'}, status),
          ),
          rewardsError('UNAUTHENTICATED'),
        );
      }
    });

    test('rejects an answer that is not a JSON object', () async {
      await expectLater(
        withServer(
          RewardsApiService.getBalance,
          (_) async => http.Response('<html>oops</html>', 200),
        ),
        rewardsError('INVALID_RESPONSE'),
      );
      await expectLater(
        withServer(
          RewardsApiService.getBalance,
          (_) async => jsonResponse(<int>[1, 2]),
        ),
        rewardsError('INVALID_RESPONSE'),
      );
    });

    test('reports a network failure', () async {
      await expectLater(
        withServer(
          RewardsApiService.getBalance,
          (_) async => throw http.ClientException('offline'),
        ),
        rewardsError('NETWORK_ERROR'),
      );
    });

    test('exception prints its message', () {
      expect(const RewardsApiException('hello').toString(), 'hello');
    });
  });

  group('VocabularyApiService', () {
    Map<String, Object> category(int id) => <String, Object>{
      'id': id,
      'slug': 'animals',
      'name': 'สัตว์',
      'sort_order': id,
      'word_count': 3,
    };

    Map<String, Object> word(int id) => <String, Object>{
      'id': id,
      'category_slug': 'animals',
      'term': 'cat',
      'translation': 'แมว',
      'thai_pronunciation': 'แคท',
      'image_url': 'assets/cat.png',
      'audio_url': 'https://example.test/cat.mp3',
      'sort_order': id,
    };

    Matcher vocabularyError([Object? message]) => throwsA(
      isA<VocabularyApiException>().having(
        (e) => e.message,
        'message',
        message ?? isNotEmpty,
      ),
    );

    test('getCategories reads the list without sending a token', () async {
      final categories = await withServer(
        VocabularyApiService.getCategories,
        (request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/vocabulary/categories');
          expect(request.headers.containsKey('authorization'), isFalse);
          return jsonResponse(<String, Object>{
            'categories': <Object>[category(1), category(2)],
          });
        },
      );

      expect(categories.map((c) => c.id), <String>['1', '2']);
      expect(categories.first.name, 'สัตว์');
    });

    test('getWords asks for the category and keeps the server order',
        () async {
      final words = await withServer(
        () => VocabularyApiService.getWords('daily routine'),
        (request) async {
          expect(
            request.url.path,
            '/api/vocabulary/categories/daily%20routine/words',
          );
          return jsonResponse(<String, Object>{
            'words': <Object>[word(5), word(2)],
          });
        },
      );

      expect(words.map((w) => w.id), <String>['5', '2']);
      expect(words.first.term, 'cat');
    });

    test('shows the server message when the request fails', () async {
      await expectLater(
        withServer(
          VocabularyApiService.getCategories,
          (_) async => jsonResponse(<String, Object>{'message': 'boom'}, 500),
        ),
        vocabularyError('boom'),
      );
    });

    test('falls back to the HTTP status when there is no message', () async {
      await expectLater(
        withServer(
          VocabularyApiService.getCategories,
          (_) async => jsonResponse(<String, Object>{'x': 1}, 503),
        ),
        vocabularyError(contains('HTTP 503')),
      );
      await expectLater(
        withServer(
          VocabularyApiService.getCategories,
          (_) async => http.Response('gateway down', 502),
        ),
        vocabularyError(contains('HTTP 502')),
      );
    });

    test('rejects an answer that is not the expected shape', () async {
      await expectLater(
        withServer(
          VocabularyApiService.getCategories,
          (_) async => http.Response('not json', 200),
        ),
        vocabularyError(),
      );
      await expectLater(
        withServer(
          VocabularyApiService.getCategories,
          (_) async => jsonResponse(<String, Object>{'words': <Object>[]}),
        ),
        vocabularyError(contains('categories')),
      );
      await expectLater(
        withServer(
          VocabularyApiService.getCategories,
          (_) async => jsonResponse(<String, Object>{
            'categories': <Object>[1, 2],
          }),
        ),
        vocabularyError(),
      );
    });

    test('rejects items with missing fields', () async {
      await expectLater(
        withServer(
          VocabularyApiService.getCategories,
          (_) async => jsonResponse(<String, Object>{
            'categories': <Object>[
              <String, Object>{'id': 1},
            ],
          }),
        ),
        vocabularyError(),
      );
      await expectLater(
        withServer(
          () => VocabularyApiService.getWords('animals'),
          (_) async => jsonResponse(<String, Object>{
            'words': <Object>[
              <String, Object>{'id': 1},
            ],
          }),
        ),
        vocabularyError(),
      );
    });

    test('reports a network failure', () async {
      await expectLater(
        withServer(
          VocabularyApiService.getCategories,
          (_) async => throw http.ClientException('offline'),
        ),
        vocabularyError(),
      );
    });

    test('exception prints its message', () {
      expect(const VocabularyApiException('hi').toString(), 'hi');
    });
  });
}
