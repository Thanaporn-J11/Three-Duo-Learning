import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/account_settings_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sends password change with JWT and reports only confirmed success',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'test-jwt',
      });
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/profile/password');
        expect(request.headers['authorization'], 'Bearer test-jwt');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, <String, String>{
          'currentPassword': 'CurrentPass1!',
          'newPassword': 'ChangedPass2!',
        });
        expect(body.containsKey('userId'), isFalse);
        return http.Response(
          jsonEncode(<String, String>{
            'message': 'Password updated successfully',
          }),
          200,
        );
      });

      await AccountSettingsApiService.changePassword(
        currentPassword: 'CurrentPass1!',
        newPassword: 'ChangedPass2!',
        client: client,
      );
      client.close();
    },
  );

  test('maps server rejection to a user facing error', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': 'test-jwt',
    });
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode(<String, Object>{
          'error': <String, String>{
            'code': 'CURRENT_PASSWORD_INVALID',
            'message': 'Current password is incorrect',
          },
        }),
        401,
      ),
    );

    await expectLater(
      AccountSettingsApiService.changePassword(
        currentPassword: 'wrong',
        newPassword: 'ChangedPass2!',
        client: client,
      ),
      throwsA(
        isA<AccountSettingsApiException>().having(
          (error) => error.message,
          'message',
          'รหัสผ่านปัจจุบันไม่ถูกต้อง',
        ),
      ),
    );
    client.close();
  });
}
