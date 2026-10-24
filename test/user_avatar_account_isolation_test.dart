import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/screens/profile_screen.dart';
import 'package:threeduo_learning/services/user_account_preferences.dart';

String _tokenFor(int userId) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode(<String, Object>{'userId': userId})))
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'avatar appearance and legacy unlocks stay scoped to the JWT user',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': _tokenFor(101),
        'avatar_gender': 'male',
        'avatar_outfit_index': 2,
        'avatar_unlocked_items': <String>['outfit:male:2'],
        'coins': 900,
      });
      final avatar = AvatarProfile.instance;
      final wallet = CoinWallet.instance;

      await avatar.load();
      await wallet.load(force: true);
      expect(avatar.gender, 'male');
      expect(avatar.outfitIndex, 2);
      expect(wallet.owns('outfit:male:2', 150), isTrue);
      expect(wallet.coins, 0, reason: 'legacy global coins are not assigned');

      avatar.update(outfitIndex: 4);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await UserAccountPreferences.logout();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _tokenFor(202));
      await avatar.load();
      await wallet.load(force: true);
      expect(avatar.gender, 'female');
      expect(avatar.outfitIndex, 0);
      expect(wallet.owns('outfit:male:2', 150), isFalse);
      expect(wallet.coins, 0);

      avatar.update(gender: 'female', outfitIndex: 5);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await UserAccountPreferences.logout();
      await prefs.setString('jwt_token', _tokenFor(101));
      await avatar.load();
      expect(avatar.gender, 'male');
      expect(avatar.outfitIndex, 4);

      await UserAccountPreferences.logout();
      await prefs.setString('jwt_token', _tokenFor(202));
      await avatar.load();
      expect(avatar.gender, 'female');
      expect(avatar.outfitIndex, 5);
    },
  );
}
