import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/parent_pin.dart';

import 'test_helpers.dart' show fakeJwt;

Future<void> switchTo(int userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('jwt_token', fakeJwt(<String, Object>{'userId': userId}));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a second account on the same phone does not get the first PIN',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await switchTo(1);
    await ParentPin.setPin('2222');
    expect(await ParentPin.verify('2222'), PinCheck.ok);

    await switchTo(2);
    expect(await ParentPin.hasPin(), isFalse);
    expect(await ParentPin.storedHash(), isNull);
    expect(await ParentPin.verify('2222'), PinCheck.wrong);

    await switchTo(1);
    expect(await ParentPin.hasPin(), isTrue);
    expect(await ParentPin.verify('2222'), PinCheck.ok);
  });

  test('the phone-wide PIN from older versions goes to the signed in account',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': fakeJwt(<String, Object>{'userId': 1}),
      'parent_pin_hash': 'hash',
      'parent_pin_salt': 'salt',
    });

    expect(await ParentPin.hasPin(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('parent_pin_hash'), isNull);

    await switchTo(2);
    expect(await ParentPin.hasPin(), isFalse);
  });
}
