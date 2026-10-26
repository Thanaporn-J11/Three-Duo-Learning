import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/parental_api_service.dart';
import 'package:threeduo_learning/services/user_account_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleteAccount posts the password to the account endpoint', () async {
    signIn();
    late Map<String, dynamic> sent;
    String? path;
    await withServer(() => ParentalApiService.deleteAccount('Secret#1'), (
      request,
    ) async {
      path = request.url.path;
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return jsonResponse(<String, Object>{'deleted': true});
    });

    expect(path, endsWith('/profile/delete-account'));
    expect(sent['password'], 'Secret#1');
  });

  test('a wrong password is reported and nothing is deleted', () async {
    signIn();
    await expectLater(
      withServer(
        () => ParentalApiService.deleteAccount('nope'),
        (request) async => jsonResponse(<String, Object>{
          'error': <String, String>{'code': 'WRONG_PASSWORD'},
        }, 403),
      ),
      throwsA(
        isA<ParentalApiException>().having(
          (e) => e.code,
          'code',
          'WRONG_PASSWORD',
        ),
      ),
    );
  });

  test('clearDeletedAccount signs out and erases that account\'s data', () async {
    signIn(<String, Object>{
      'settings_user_1': 'a',
      'quiz_pending_food_user_1': 'k|1',
      'settings_user_2': 'other account',
      'plain_key': 'kept',
    });

    await UserAccountPreferences.clearDeletedAccount();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('jwt_token'), isNull);
    expect(prefs.getString('settings_user_1'), isNull);
    expect(prefs.getString('quiz_pending_food_user_1'), isNull);
    expect(prefs.getString('settings_user_2'), 'other account');
    expect(prefs.getString('plain_key'), 'kept');
  });
}
