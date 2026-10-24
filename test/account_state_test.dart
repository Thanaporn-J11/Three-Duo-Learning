import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/coin_balance.dart';
import 'package:threeduo_learning/services/parent_pin.dart';
import 'package:threeduo_learning/services/user_account_preferences.dart';

/// A JWT-shaped string whose payload is [payload] (the signature is not used
/// by the app; the backend validates it).
String fakeJwt(Object payload) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc(<String, String>{'alg': 'none'})}.${enc(payload)}.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoinBalance', () {
    setUp(CoinBalance.clear);

    test('starts empty and takes a valid balance from the server', () {
      expect(CoinBalance.value.value, isNull);

      CoinBalance.set(42);
      expect(CoinBalance.value.value, 42);

      CoinBalance.set(0);
      expect(CoinBalance.value.value, 0);
    });

    test('ignores values that are not a non-negative integer', () {
      CoinBalance.set(10);

      CoinBalance.set(-1);
      CoinBalance.set('20');
      CoinBalance.set(null);
      CoinBalance.set(3.5);

      expect(CoinBalance.value.value, 10);
    });

    test('clear forgets the balance and notifies listeners', () {
      CoinBalance.set(7);
      var notified = 0;
      void listener() => notified++;
      CoinBalance.value.addListener(listener);

      CoinBalance.clear();

      CoinBalance.value.removeListener(listener);
      expect(CoinBalance.value.value, isNull);
      expect(notified, 1);
    });
  });

  group('UserAccountPreferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('currentUserId reads a numeric or string userId from the token',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': fakeJwt(<String, Object>{'userId': 15}),
      });
      expect(await UserAccountPreferences.currentUserId(), '15');

      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': fakeJwt(<String, Object>{'userId': '  abc  '}),
      });
      expect(await UserAccountPreferences.currentUserId(), 'abc');
    });

    test('currentUserId is null for a missing or unusable token', () async {
      expect(await UserAccountPreferences.currentUserId(), isNull);

      for (final token in <String>[
        'not-a-jwt',
        'a.b',
        'a.!!!.c',
        fakeJwt(<String, Object>{'userId': 0}),
        fakeJwt(<String, Object>{'userId': -4}),
        fakeJwt(<String, Object>{'userId': '   '}),
        fakeJwt(<String, Object>{'other': 1}),
        fakeJwt(<Object>[1, 2]),
      ]) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'jwt_token': token,
        });
        expect(
          await UserAccountPreferences.currentUserId(),
          isNull,
          reason: token,
        );
      }
    });

    test('keyFor scopes a key to one account', () {
      expect(UserAccountPreferences.keyFor('coins', '9'), 'coins_user_9');
      expect(
        UserAccountPreferences.keyFor('coins', '9'),
        isNot(UserAccountPreferences.keyFor('coins', '10')),
      );
    });

    test('claimLegacyData gives old data to the first account only', () async {
      expect(await UserAccountPreferences.claimLegacyData('marker', '1'), isTrue);
      expect(await UserAccountPreferences.claimLegacyData('marker', '1'), isTrue);
      expect(
        await UserAccountPreferences.claimLegacyData('marker', '2'),
        isFalse,
      );
    });

    test('clearLocalSession removes the token and runs the clean-up',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': fakeJwt(<String, Object>{'userId': 1}),
        'keep_me': 'yes',
      });
      var resets = 0;
      var hooks = 0;
      UserAccountPreferences.registerMemoryResetter(() => resets++);
      UserAccountPreferences.registerLogoutHook(() async {
        hooks++;
      });
      // A failing hook must not stop the logout or the other hooks.
      UserAccountPreferences.registerLogoutHook(() async {
        throw StateError('boom');
      });

      await UserAccountPreferences.clearLocalSession();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('jwt_token'), isNull);
      expect(prefs.getString('keep_me'), 'yes');
      expect(resets, 1);
      expect(hooks, 1);
      expect(await UserAccountPreferences.currentUserId(), isNull);
    });
  });

  group('ParentPin', () {
    setUp(() {
      // No jwt_token: pushing the PIN to the account is skipped offline.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('isValidFormat accepts exactly four digits', () {
      expect(ParentPin.isValidFormat('1234'), isTrue);
      expect(ParentPin.isValidFormat('0000'), isTrue);
      for (final bad in <String>['', '123', '12345', 'abcd', '12 4', '١٢٣٤']) {
        expect(ParentPin.isValidFormat(bad), isFalse, reason: bad);
      }
    });

    test('has no PIN until one is set', () async {
      expect(await ParentPin.hasPin(), isFalse);
      expect(await ParentPin.storedHash(), isNull);
      expect(await ParentPin.verify('1234'), PinCheck.wrong);
    });

    test('setPin rejects a malformed PIN', () async {
      await expectLater(ParentPin.setPin('12'), throwsArgumentError);
      expect(await ParentPin.hasPin(), isFalse);
    });

    test('stores only a salted hash and verifies the right PIN', () async {
      await ParentPin.setPin('4321');

      expect(await ParentPin.hasPin(), isTrue);
      final stored = await ParentPin.storedHash();
      expect(stored, isNotNull);
      expect(stored!.hash, isNot(contains('4321')));
      expect(stored.salt, isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().any((k) => prefs.get(k).toString() == '4321'),
        isFalse,
      );

      expect(await ParentPin.verify('4321'), PinCheck.ok);
      expect(await ParentPin.verify('0000'), PinCheck.wrong);
    });

    test('uses a fresh salt each time a PIN is set', () async {
      await ParentPin.setPin('1111');
      final first = await ParentPin.storedHash();
      await ParentPin.setPin('1111');
      final second = await ParentPin.storedHash();

      expect(second!.salt, isNot(first!.salt));
      expect(second.hash, isNot(first.hash));
    });

    test('locks after too many wrong tries, even for the right PIN', () async {
      await ParentPin.setPin('2468');

      for (var i = 1; i < ParentPin.maxFailures; i++) {
        expect(await ParentPin.verify('9999'), PinCheck.wrong);
      }
      expect(await ParentPin.verify('9999'), PinCheck.locked);

      final left = await ParentPin.lockedFor();
      expect(left, isNotNull);
      expect(left!, lessThanOrEqualTo(ParentPin.lockDuration));
      expect(await ParentPin.verify('2468'), PinCheck.locked);
    });

    test('a correct PIN resets the wrong-try counter', () async {
      await ParentPin.setPin('1357');

      for (var i = 1; i < ParentPin.maxFailures; i++) {
        expect(await ParentPin.verify('0000'), PinCheck.wrong);
      }
      expect(await ParentPin.verify('1357'), PinCheck.ok);
      // The counter started over, so another wrong try is not locked yet.
      expect(await ParentPin.verify('0000'), PinCheck.wrong);
    });

    test('an expired lock no longer blocks the PIN', () async {
      await ParentPin.setPin('1357');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'parent_pin_locked_until',
        DateTime.now()
            .subtract(const Duration(seconds: 5))
            .millisecondsSinceEpoch,
      );

      expect(await ParentPin.lockedFor(), isNull);
      expect(await ParentPin.verify('1357'), PinCheck.ok);
    });

    test('clear removes the PIN', () async {
      await ParentPin.setPin('1357');
      await ParentPin.clear();

      expect(await ParentPin.hasPin(), isFalse);
      expect(await ParentPin.storedHash(), isNull);
    });

    test('migrates the old plain-text PIN to a hash', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'parent_pin_code': '8642',
      });

      expect(await ParentPin.hasPin(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('parent_pin_code'), isNull);
      expect(await ParentPin.verify('8642'), PinCheck.ok);
    });

    test('drops an old plain-text value that is not a valid PIN', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'parent_pin_code': 'oops',
      });

      expect(await ParentPin.hasPin(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('parent_pin_code'), isNull);
    });

    test('applyFromServer takes, replaces and removes the account PIN',
        () async {
      await ParentPin.setPin('1357');
      final local = await ParentPin.storedHash();

      // The same PIN again changes nothing.
      await ParentPin.applyFromServer(local!.hash, local.salt);
      expect(await ParentPin.verify('1357'), PinCheck.ok);

      // A PIN made on another phone: copy its hash and salt.
      await ParentPin.applyFromServer('h', 's');
      final taken = await ParentPin.storedHash();
      expect(taken!.hash, 'h');
      expect(taken.salt, 's');

      // The account has no PIN: remove ours.
      await ParentPin.applyFromServer(null, null);
      expect(await ParentPin.hasPin(), isFalse);

      // Nothing to remove: stays empty.
      await ParentPin.applyFromServer(null, null);
      expect(await ParentPin.hasPin(), isFalse);
    });
  });
}
