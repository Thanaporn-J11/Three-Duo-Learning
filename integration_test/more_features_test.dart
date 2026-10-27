// More end-to-end checks of things that behave the same every time:
//  - registering with an e-mail that already exists is refused  (TC-003)
//  - the vocabulary categories open                              (TC-008)
//  - first check-in of the day, and checking in again           (TC-023, 024)
//  - the profile page shows the signed-in account
//  - parent PIN: wrong PIN refused, right PIN accepted          (TC-029, 030)
//  - the PIN belongs to one account, not to the phone           (TC-032, 063)
//  - "sign out of all other devices" when there are none        (TC-037)
//
// Each test starts the app signed out, with its own throw-away account(s).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:threeduo_learning/main.dart' as app;

import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Shared by the tests that do not change anything lasting on the account.
  final main = TestAccount();

  setUpAll(() => registerViaApi(main));
  tearDownAll(() => cleanupAccount(main));

  /// A brand-new account for one test. Tests about the PIN or about signed-in
  /// devices must not share an account: the PIN and the sessions stay on the
  /// account after a test, and would change what the next test sees.
  Future<TestAccount> freshAccount() async {
    final account = TestAccount();
    await registerViaApi(account);
    addTearDown(() => cleanupAccount(account));
    return account;
  }

  testWidgets('register with an e-mail that is already used', (tester) async {
    await launchSignedOut(tester, app.main);

    await tester.tap(find.byType(TextButton).first); // "สร้างบัญชีใหม่"
    await pumpUntilFound(tester, find.text('สร้างบัญชี'));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Another Person');
    await tester.enterText(fields.at(1), '0899999999');
    await tester.enterText(fields.at(2), main.email); // already registered
    await tester.enterText(fields.at(3), 'Abcdef1!');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.text('สร้างบัญชี'));
    await tester.tap(find.text('สร้างบัญชี'));

    await pumpUntilFound(tester, find.text('อีเมลนี้ถูกใช้งานแล้ว'));
  });

  testWidgets('vocabulary categories open', (tester) async {
    await launchSignedOut(tester, app.main);
    await signInViaUi(tester, main);

    await tester.tap(find.text('คำศัพท์').first);
    // A few of the categories are always listed.
    await pumpUntilFound(tester, find.text('สัตว์'));
    for (final name in const ['อาหาร', 'ตัวเลข', 'สีสัน', 'ผลไม้']) {
      expect(find.text(name), findsWidgets, reason: 'category "$name"');
    }
    expectNoCrash(tester, 'vocabulary category list');

    // One category opens a lesson page and comes back.
    await tester.tap(find.text('สัตว์').first);
    await settle(tester, const Duration(seconds: 3));
    expectNoCrash(tester, 'opening the animals category');
    await popTopRoute(tester);
    await pumpUntilFound(tester, find.text('สัตว์'));
  });

  testWidgets('check in, check in again, profile page', (tester) async {
    await launchSignedOut(tester, app.main);
    await signInViaUi(tester, main);

    // ---- First check-in of the day ----
    await tester.tap(find.text('เช็คอิน').first); // bottom bar
    await pumpUntilFound(tester, find.text('เช็คอินเลย'));
    await tester.ensureVisible(find.text('เช็คอินเลย'));
    await tester.tap(find.text('เช็คอินเลย'));
    await pumpUntilFound(tester, find.text('เช็คอินแล้ววันนี้'));

    // ---- A second tap the same day changes nothing ----
    await tester.ensureVisible(find.text('เช็คอินแล้ววันนี้'));
    await tester.tap(find.text('เช็คอินแล้ววันนี้'), warnIfMissed: false);
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('เช็คอินแล้ววันนี้'), findsWidgets);
    expect(find.text('เช็คอินเลย'), findsNothing);
    expectNoCrash(tester, 'checking in twice');

    // ---- Profile page shows who is signed in ----
    await tester.tap(find.text('โปรไฟล์').first); // bottom bar
    await pumpUntilFound(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            ((w.data ?? '').contains(main.name) ||
                (w.data ?? '').contains(main.email)),
      ),
    );
    expectNoCrash(tester, 'profile page');
  });

  testWidgets('parent PIN: wrong PIN refused, right PIN accepted', (
    tester,
  ) async {
    final account = await freshAccount();
    await launchSignedOut(tester, app.main);
    await signInViaUi(tester, account);

    await _openParentZone(tester);
    await pumpUntilFound(tester, find.text('ตั้งรหัส PIN ผู้ปกครอง'));
    await _createPin(tester, '1234');
    await settle(tester, const Duration(seconds: 2));
    await popTopRoute(tester); // close the learning report that opens

    // The next time, the app asks for the PIN.
    await _openParentZone(tester);
    await pumpUntilFound(tester, find.text('ยืนยันรหัส PIN ผู้ปกครอง'));
    final pinField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    // Wrong PIN: refused, the dialog stays.
    await tester.enterText(pinField.first, '0000');
    await tester.tap(find.text('ยืนยัน'));
    await pumpUntilFound(tester, find.text('รหัส PIN ไม่ถูกต้อง ลองใหม่อีกครั้ง'));
    expect(find.text('ยืนยันรหัส PIN ผู้ปกครอง'), findsOneWidget);

    // Right PIN: the dialog closes and the parent zone opens.
    await tester.enterText(pinField.first, '1234');
    await tester.tap(find.text('ยืนยัน'));
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('ยืนยันรหัส PIN ผู้ปกครอง'), findsNothing);
    expectNoCrash(tester, 'opening the parent zone with the right PIN');
  });

  testWidgets('parent PIN belongs to the account, not the phone', (
    tester,
  ) async {
    final accountA = await freshAccount();
    final accountB = await freshAccount();
    await launchSignedOut(tester, app.main);

    // Account A creates a PIN.
    await signInViaUi(tester, accountA);
    await _openParentZone(tester);
    await pumpUntilFound(tester, find.text('ตั้งรหัส PIN ผู้ปกครอง'));
    await _createPin(tester, '2222');
    await settle(tester, const Duration(seconds: 2));
    await popTopRoute(tester);
    await logOutViaUi(tester);

    // Account B has never set one: it must be asked to CREATE a PIN, and
    // A's 2222 must not work for it.
    await signInViaUi(tester, accountB);
    await _openParentZone(tester);
    await pumpUntilFound(tester, find.text('ตั้งรหัส PIN ผู้ปกครอง'));
    expect(find.text('ยืนยันรหัส PIN ผู้ปกครอง'), findsNothing);
  });

  testWidgets('sign out of other devices when there are none', (tester) async {
    // A fresh account has only this one session (the shared account has one
    // for every earlier test that signed in).
    final account = await freshAccount();
    await launchSignedOut(tester, app.main);
    await signInViaUi(tester, account);

    await tester.tap(find.text('ตั้งค่า'));
    await pumpUntilFound(tester, find.text('ความปลอดภัยและรหัสผ่าน'));
    await scrollToText(tester, 'ความปลอดภัยและรหัสผ่าน');
    await tester.tap(find.text('ความปลอดภัยและรหัสผ่าน'));
    await pumpUntilFound(tester, find.text('ออกจากระบบในอุปกรณ์อื่นทั้งหมด'));

    await tester.ensureVisible(find.text('ออกจากระบบในอุปกรณ์อื่นทั้งหมด'));
    await tester.tap(find.text('ออกจากระบบในอุปกรณ์อื่นทั้งหมด'));
    await pumpUntilFound(tester, find.text('ออกจากระบบอุปกรณ์อื่นทั้งหมด ?'));
    await tester.tap(find.text('ออกจากระบบ').last); // confirm
    await pumpUntilFound(tester, find.text('ไม่มีอุปกรณ์อื่นที่เข้าสู่ระบบอยู่'));
  });
}

/// Settings -> "รายงานและพัฒนาการการเรียน" (guarded by the parent PIN).
Future<void> _openParentZone(WidgetTester tester) async {
  // "ตั้งค่า" is both the bottom-bar label and the Settings page title, so
  // only use the bottom bar when Settings is not open yet.
  if (find.text('รายงานและพัฒนาการการเรียน').evaluate().isEmpty) {
    await tester.tap(find.text('ตั้งค่า'));
  }
  await pumpUntilFound(tester, find.text('รายงานและพัฒนาการการเรียน'));
  await tester.tap(find.text('รายงานและพัฒนาการการเรียน'));
}

/// Fills the "create PIN" dialog (PIN + confirmation) and saves it.
Future<void> _createPin(WidgetTester tester, String pin) async {
  final fields = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), pin);
  await tester.enterText(fields.at(1), pin);
  await tester.tap(find.text('ตั้งรหัสผ่าน'));
  await pumpUntilFound(tester, find.text('บันทึกรหัส PIN ผู้ปกครองสำเร็จ !'));
}
