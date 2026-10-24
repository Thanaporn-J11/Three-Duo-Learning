import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/avatar_api_service.dart';
import 'package:threeduo_learning/services/profile_api_service.dart';

typedef Handler = Future<http.Response> Function(http.Request request);

Future<T> withServer<T>(Future<T> Function() body, Handler handler) {
  return http.runWithClient(body, () => MockClient(handler));
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

Map<String, Object?> profileBody({
  Object? name = 'Mali',
  Object? email = 'mali@example.test',
  Object? phone,
  Object? createdAt,
}) => <String, Object?>{
  'profile': <String, Object?>{
    'name': name,
    'email': email,
    'phone': phone,
    'createdAt': createdAt,
  },
};

Map<String, Object?> avatarMap({Object? gender = 'female', int outfit = 2}) =>
    <String, Object?>{
      'gender': gender,
      'skinIndex': 1,
      'hairStyle': 3,
      'hairColorIndex': 4,
      'outfitIndex': outfit,
      'glasses': 0,
      'hat': 5,
      'clip': 0,
      'earring': 0,
      'neck': 0,
      'extra': 0,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileData.fromResponse', () {
    test('trims text and reads the date', () {
      final data = ProfileData.fromResponse(
        profileBody(
          name: '  Mali ',
          email: ' mali@example.test ',
          phone: ' 0812345678 ',
          createdAt: '2026-01-02T03:04:05Z',
        ),
      );

      expect(data.name, 'Mali');
      expect(data.email, 'mali@example.test');
      expect(data.phone, '0812345678');
      expect(data.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    });

    test('phone and date are optional', () {
      for (final phone in <Object?>[null, '', '   ', 5]) {
        final data = ProfileData.fromResponse(profileBody(phone: phone));
        expect(data.phone, isNull, reason: '$phone');
        expect(data.createdAt, isNull);
      }
    });

    test('rejects a profile that is not usable', () {
      expect(
        () => ProfileData.fromResponse(<String, dynamic>{}),
        throwsFormatException,
      );
      expect(
        () => ProfileData.fromResponse(profileBody(name: '  ')),
        throwsFormatException,
      );
      expect(
        () => ProfileData.fromResponse(profileBody(email: null)),
        throwsFormatException,
      );
      expect(
        () => ProfileData.fromResponse(profileBody(createdAt: 'yesterday')),
        throwsFormatException,
      );
      expect(
        () => ProfileData.fromResponse(profileBody(createdAt: 123)),
        throwsFormatException,
      );
      expect(
        () => ProfileData.fromResponse(profileBody(createdAt: '')),
        throwsFormatException,
      );
    });
  });

  group('ProfileApiService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'test-jwt',
      });
    });

    Matcher profileError(Object message) => throwsA(
      isA<ProfileApiException>().having((e) => e.message, 'message', message),
    );

    Map<String, Object?> errorBody(String code) => <String, Object?>{
      'error': <String, Object?>{'code': code},
    };

    test('getProfile sends the token and reads the profile', () async {
      final profile = await withServer(ProfileApiService.getProfile, (
        request,
      ) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/profile');
        expect(request.headers['authorization'], 'Bearer test-jwt');
        return jsonResponse(profileBody());
      });

      expect(profile.name, 'Mali');
    });

    test('getProfile asks to sign in again without a token', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await expectLater(
        withServer(ProfileApiService.getProfile, (_) async {
          called = true;
          return jsonResponse(profileBody());
        }),
        profileError(isNotEmpty),
      );
      expect(called, isFalse);
    });

    test('getProfile maps refusals', () async {
      await expectLater(
        withServer(
          ProfileApiService.getProfile,
          (_) async => jsonResponse(errorBody('PROFILE_NOT_FOUND'), 404),
        ),
        profileError(contains('ไม่พบข้อมูลโปรไฟล์')),
      );
      for (final code in <String>['UNAUTHENTICATED', 'INVALID_TOKEN']) {
        await expectLater(
          withServer(
            ProfileApiService.getProfile,
            (_) async => jsonResponse(errorBody(code), 401),
          ),
          profileError(contains('เซสชันหมดอายุ')),
        );
      }
      await expectLater(
        withServer(
          ProfileApiService.getProfile,
          (_) async => jsonResponse(<String, Object?>{}, 500),
        ),
        profileError(contains('HTTP 500')),
      );
    });

    test('getProfile rejects answers that are not a profile', () async {
      await expectLater(
        withServer(
          ProfileApiService.getProfile,
          (_) async => http.Response('<html></html>', 200),
        ),
        profileError(contains('HTTP 200')),
      );
      await expectLater(
        withServer(
          ProfileApiService.getProfile,
          (_) async => jsonResponse(<int>[1]),
        ),
        profileError(contains('HTTP 200')),
      );
      await expectLater(
        withServer(
          ProfileApiService.getProfile,
          (_) async => jsonResponse(profileBody(name: '')),
        ),
        profileError(isNotEmpty),
      );
    });

    test('getProfile reports a network failure', () async {
      await expectLater(
        withServer(
          ProfileApiService.getProfile,
          (_) async => throw http.ClientException('offline'),
        ),
        profileError(isNotEmpty),
      );
    });

    test('updateProfile patches the name and phone', () async {
      final updated = await withServer(
        () => ProfileApiService.updateProfile(name: 'Mali', phone: '0812345678'),
        (request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/profile');
          expect(request.headers['authorization'], 'Bearer test-jwt');
          expect(jsonDecode(request.body), <String, Object?>{
            'name': 'Mali',
            'phone': '0812345678',
          });
          return jsonResponse(profileBody(phone: '0812345678'));
        },
      );
      expect(updated.phone, '0812345678');

      await withServer(
        () => ProfileApiService.updateProfile(name: 'Mali', phone: null),
        (request) async {
          expect(jsonDecode(request.body), <String, Object?>{
            'name': 'Mali',
            'phone': null,
          });
          return jsonResponse(profileBody());
        },
      );
    });

    test('updateProfile asks to sign in again without a token', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await expectLater(
        withServer(
          () => ProfileApiService.updateProfile(name: 'Mali', phone: null),
          (_) async => jsonResponse(profileBody()),
        ),
        profileError(isNotEmpty),
      );
    });

    test('updateProfile maps refusals', () async {
      Future<void> expectRefusal(int status, Object? body, Object message) {
        return expectLater(
          withServer(
            () => ProfileApiService.updateProfile(name: 'x', phone: null),
            (_) async => body is String
                ? http.Response(body, status)
                : jsonResponse(body, status),
          ),
          profileError(message),
        );
      }

      await expectRefusal(401, <String, Object?>{}, contains('เซสชันหมดอายุ'));
      await expectRefusal(
        400,
        errorBody('INVALID_NAME'),
        contains('กรุณากรอกชื่อ'),
      );
      await expectRefusal(
        400,
        errorBody('INVALID_PHONE'),
        contains('เบอร์โทรศัพท์ไม่ถูกต้อง'),
      );
      await expectRefusal(
        404,
        errorBody('PROFILE_NOT_FOUND'),
        contains('ไม่พบข้อมูลโปรไฟล์'),
      );
      await expectRefusal(500, 'oops', contains('HTTP 500'));
      await expectRefusal(500, <String, Object?>{'error': 'x'}, contains('HTTP 500'));
    });

    test('updateProfile rejects a success answer that is not a profile',
        () async {
      await expectLater(
        withServer(
          () => ProfileApiService.updateProfile(name: 'x', phone: null),
          (_) async => jsonResponse(<String, Object?>{}),
        ),
        profileError(isNotEmpty),
      );
    });

    test('updateProfile reports a network failure', () async {
      await expectLater(
        withServer(
          () => ProfileApiService.updateProfile(name: 'x', phone: null),
          (_) async => throw http.ClientException('offline'),
        ),
        profileError(isNotEmpty),
      );
    });

    test('exception prints its message', () {
      expect(const ProfileApiException('hi').toString(), 'hi');
    });
  });

  group('AvatarData', () {
    test('round-trips through json', () {
      final avatar = AvatarData.fromJson(avatarMap());

      expect(avatar.gender, 'female');
      expect(avatar.skinIndex, 1);
      expect(avatar.hairStyle, 3);
      expect(avatar.hairColorIndex, 4);
      expect(avatar.outfitIndex, 2);
      expect(avatar.hat, 5);
      expect(avatar.toJson(), avatarMap());
    });

    test('accepts whole numbers sent as doubles', () {
      final avatar = AvatarData.fromJson(avatarMap()..['hat'] = 6.0);

      expect(avatar.hat, 6);
    });

    test('rejects a bad gender, negative, fractional or missing field', () {
      expect(
        () => AvatarData.fromJson(avatarMap(gender: 'robot')),
        throwsFormatException,
      );
      expect(
        () => AvatarData.fromJson(avatarMap()..['hat'] = -1),
        throwsFormatException,
      );
      expect(
        () => AvatarData.fromJson(avatarMap()..['hat'] = 1.5),
        throwsFormatException,
      );
      expect(
        () => AvatarData.fromJson(avatarMap()..remove('extra')),
        throwsFormatException,
      );
      expect(
        () => AvatarData.fromJson(avatarMap()..['clip'] = 'x'),
        throwsFormatException,
      );
    });
  });

  group('AvatarApiService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'test-jwt',
      });
    });

    Matcher avatarError(String code) => throwsA(
      isA<AvatarApiException>().having((e) => e.code, 'code', code),
    );

    test('getAvatar reads the saved avatar', () async {
      final avatar = await withServer(AvatarApiService.getAvatar, (
        request,
      ) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/profile/avatar');
        expect(request.headers['authorization'], 'Bearer test-jwt');
        return jsonResponse(<String, Object?>{'avatar': avatarMap()});
      });

      expect(avatar!.hairStyle, 3);
    });

    test('getAvatar is null when nothing was saved', () async {
      expect(
        await withServer(
          AvatarApiService.getAvatar,
          (_) async => jsonResponse(<String, Object?>{'avatar': null}),
        ),
        isNull,
      );
      expect(
        await withServer(
          AvatarApiService.getAvatar,
          (_) async => jsonResponse(<String, Object?>{'avatar': 'x'}),
        ),
        isNull,
      );
    });

    test('getAvatar rejects an avatar with bad values', () async {
      await expectLater(
        withServer(
          AvatarApiService.getAvatar,
          (_) async => jsonResponse(<String, Object?>{
            'avatar': avatarMap(gender: 'robot'),
          }),
        ),
        avatarError('INVALID_RESPONSE'),
      );
    });

    test('saveAvatar sends the avatar and returns what was stored', () async {
      final data = AvatarData.fromJson(avatarMap());

      final saved = await withServer(() => AvatarApiService.saveAvatar(data), (
        request,
      ) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/profile/avatar');
        expect(request.headers['content-type'], startsWith('application/json'));
        expect(jsonDecode(request.body), avatarMap());
        return jsonResponse(<String, Object?>{'avatar': avatarMap(outfit: 7)});
      });

      expect(saved.outfitIndex, 7);
    });

    test('saveAvatar rejects an answer without the avatar', () async {
      await expectLater(
        withServer(
          () => AvatarApiService.saveAvatar(AvatarData.fromJson(avatarMap())),
          (_) async => jsonResponse(<String, Object?>{}),
        ),
        avatarError('INVALID_RESPONSE'),
      );
    });

    test('asks to sign in again without a token or after a 401', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await expectLater(
        withServer(
          AvatarApiService.getAvatar,
          (_) async => jsonResponse(<String, Object?>{'avatar': null}),
        ),
        avatarError('UNAUTHENTICATED'),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'test-jwt',
      });
      await expectLater(
        withServer(
          AvatarApiService.getAvatar,
          (_) async => jsonResponse(<String, Object?>{}, 401),
        ),
        avatarError('UNAUTHENTICATED'),
      );
    });

    test('tells which avatar fields are not owned', () async {
      await expectLater(
        withServer(
          () => AvatarApiService.saveAvatar(AvatarData.fromJson(avatarMap())),
          (_) async => jsonResponse(<String, Object?>{
            'error': <String, Object?>{
              'code': 'AVATAR_ITEM_NOT_OWNED',
              'fields': <Object?>['outfitIndex', 3, 'hat'],
            },
          }, 403),
        ),
        throwsA(
          isA<AvatarApiException>()
              .having((e) => e.code, 'code', 'AVATAR_ITEM_NOT_OWNED')
              .having((e) => e.fields, 'fields', <String>['outfitIndex', 'hat'])
              .having((e) => e.isRetryable, 'isRetryable', isFalse),
        ),
      );
    });

    test('a server error can be retried, other refusals cannot', () async {
      await expectLater(
        withServer(
          AvatarApiService.getAvatar,
          (_) async => jsonResponse(<String, Object?>{}, 503),
        ),
        throwsA(
          isA<AvatarApiException>()
              .having((e) => e.code, 'code', 'SERVER_ERROR')
              .having((e) => e.isRetryable, 'isRetryable', isTrue)
              .having((e) => e.message, 'message', contains('HTTP 503')),
        ),
      );
      await expectLater(
        withServer(
          AvatarApiService.getAvatar,
          (_) async => http.Response('nope', 400),
        ),
        throwsA(
          isA<AvatarApiException>()
              .having((e) => e.code, 'code', isNull)
              .having((e) => e.fields, 'fields', isEmpty)
              .having((e) => e.isRetryable, 'isRetryable', isFalse),
        ),
      );
    });

    test('a success answer that is not JSON can be retried', () async {
      await expectLater(
        withServer(
          AvatarApiService.getAvatar,
          (_) async => http.Response('<html></html>', 200),
        ),
        throwsA(
          isA<AvatarApiException>()
              .having((e) => e.code, 'code', 'INVALID_RESPONSE')
              .having((e) => e.isRetryable, 'isRetryable', isTrue),
        ),
      );
    });

    test('a network failure can be retried', () async {
      await expectLater(
        withServer(
          AvatarApiService.getAvatar,
          (_) async => throw http.ClientException('offline'),
        ),
        throwsA(
          isA<AvatarApiException>()
              .having((e) => e.code, 'code', 'NETWORK_ERROR')
              .having((e) => e.isRetryable, 'isRetryable', isTrue),
        ),
      );
    });

    test('exception prints its message and knows its retry codes', () {
      expect(const AvatarApiException('hi').toString(), 'hi');
      expect(const AvatarApiException('x', code: 'TIMEOUT').isRetryable, isTrue);
      expect(const AvatarApiException('x').isRetryable, isFalse);
    });
  });
}
