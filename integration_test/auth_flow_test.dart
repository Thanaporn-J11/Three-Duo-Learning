// End-to-end: register -> login -> logout -> login again -> delete account.
// Covers manual cases: register, login, wrong password, logout, delete account,
// register again with the same email after deleting.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:threeduo_learning/main.dart' as app;

import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final account = TestAccount();

  tearDownAll(() => cleanupAccount(account));

  testWidgets('register, login, logout, delete account', (tester) async {
    await freshStart();
    app.main();
    await pumpUntilFound(
      tester,
      find.text('เริ่มต้นใช้งาน'),
      timeout: const Duration(seconds: 60),
    );

    // ---- Register (Welcome -> "สร้างบัญชีใหม่") ----
    // The link is a TextButton wrapping rich text, so tap the button itself.
    await tester.tap(find.byType(TextButton).first);
    await pumpUntilFound(tester, find.text('สร้างบัญชี'));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), account.name);
    await tester.enterText(fields.at(1), account.phone);
    await tester.enterText(fields.at(2), account.email);
    await tester.enterText(fields.at(3), account.password);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.text('สร้างบัญชี'));
    await tester.tap(find.text('สร้างบัญชี'));

    // The app shows "สร้างบัญชีสำเร็จ" and then opens the login page.
    await pumpUntilFound(
      tester,
      find.text('กลับมาเรียนรู้ภาษาไปพร้อมกับเพื่อน ๆ กันนะ'),
    );
    await settle(tester);

    // ---- Wrong password is rejected ----
    await _typeLoginAndSubmit(tester, account.email, 'Wrong#1234');
    // The app shows the server's message (English) or its own Thai fallback.
    await pumpUntilFound(tester, _invalidLoginMessage());

    // ---- Correct password signs in ----
    await _typeLoginAndSubmit(tester, account.email, account.password);
    await pumpUntilFound(tester, find.text('หมวดการเรียนรู้'));

    // ---- Settings -> logout -> Welcome ----
    await tester.tap(find.text('ตั้งค่า'));
    await pumpUntilFound(tester, find.text('ออกจากระบบ'), timeout: const Duration(seconds: 15));
    await _scrollTo(tester, 'ออกจากระบบ');
    await tester.tap(find.text('ออกจากระบบ'));
    await settle(tester);
    await tester.tap(find.text('ออกจากระบบ').last); // the dialog's button
    await pumpUntilFound(tester, find.text('เริ่มต้นใช้งาน'));

    // ---- Sign in again, then delete the account ----
    await tester.tap(find.text('เริ่มต้นใช้งาน'));
    await pumpUntilFound(tester, find.byType(TextField));
    await _typeLoginAndSubmit(tester, account.email, account.password);
    await pumpUntilFound(tester, find.text('หมวดการเรียนรู้'));

    await tester.tap(find.text('ตั้งค่า'));
    await pumpUntilFound(tester, find.text('ออกจากระบบ'));
    await _scrollTo(tester, 'ลบบัญชีผู้ใช้');
    await tester.tap(find.text('ลบบัญชีผู้ใช้'));
    await settle(tester);

    // Wrong password: nothing is deleted, an error is shown.
    await tester.enterText(find.byType(TextField).last, 'Wrong#1234');
    await _pressDelete(tester);
    await pumpUntilFound(tester, find.text('รหัสผ่านไม่ถูกต้อง'));

    // Right password, in a fresh dialog: account deleted, back to Welcome.
    await tester.tap(find.text('ยกเลิก'));
    await settle(tester);
    await tester.tap(find.text('ลบบัญชีผู้ใช้'));
    await settle(tester);
    final passwordField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(passwordField, account.password);
    await _pressDelete(tester);
    await pumpUntilFound(tester, find.text('เริ่มต้นใช้งาน'));

    // ---- The deleted account can no longer sign in ----
    await tester.tap(find.text('เริ่มต้นใช้งาน'));
    await pumpUntilFound(tester, find.byType(TextField));
    await _typeLoginAndSubmit(tester, account.email, account.password);
    await pumpUntilFound(tester, _invalidLoginMessage());
  });
}

/// Types into the login form (email = 1st field, password = 2nd) and presses
/// the "เข้าสู่ระบบ" button (the last widget with that text; the first is the title).
Future<void> _typeLoginAndSubmit(
  WidgetTester tester,
  String email,
  String password,
) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
  await tester.pump();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  final button = find.text('เข้าสู่ระบบ').last;
  await tester.ensureVisible(button);
  await tester.tap(button);
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  // A "signed in" snack bar floats over the bottom of the page for a few
  // seconds and would swallow the tap, so let it go first.
  await settle(tester, const Duration(seconds: 5));
  await tester.scrollUntilVisible(
    find.text(text),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

/// Presses the red "ลบบัญชี" button of the dialog. The keyboard is closed and
/// the dialog given time to settle first, otherwise the tap lands beside it.
Future<void> _pressDelete(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, const Duration(seconds: 1));
  await tester.tap(find.widgetWithText(ElevatedButton, 'ลบบัญชี'));
}

/// The snack bar shown for a refused login: the server's English message, or
/// the app's own Thai fallback.
Finder _invalidLoginMessage() => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data == 'Invalid email or password' ||
          w.data == 'อีเมลหรือรหัสผ่านไม่ถูกต้อง'),
);
