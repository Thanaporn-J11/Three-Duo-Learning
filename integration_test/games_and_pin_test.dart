// End-to-end smoke test on a freshly created account:
//  - the home page opens every lesson area,
//  - all 10 games open and come back without crashing,
//  - the parent PIN can be set (settings -> learning report).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:threeduo_learning/main.dart' as app;

import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final account = TestAccount();

  setUpAll(() => registerViaApi(account));
  tearDownAll(() => cleanupAccount(account));

  testWidgets('home areas and 10 games', (tester) async {
    await freshStart();
    app.main();
    await pumpUntilFound(
      tester,
      find.text('เริ่มต้นใช้งาน'),
      timeout: const Duration(seconds: 60),
    );

    // ---- Sign in ----
    await tester.tap(find.text('เริ่มต้นใช้งาน'));
    await pumpUntilFound(tester, find.byType(TextField));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), account.email);
    await tester.enterText(fields.at(1), account.password);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final signIn = find.text('เข้าสู่ระบบ').last;
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await pumpUntilFound(tester, find.text('หมวดการเรียนรู้'));

    // ---- Every area of the home page opens and goes back ----
    for (final area in const <String>[
      'คำศัพท์',
      'ฝึกออกเสียง',
      'ฝึกฟัง',
      'นิทาน',
      'แปลภาษา',
    ]) {
      await tester.tap(find.text(area).first);
      await settle(tester, const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'opening "$area"');
      await _goBack(tester);
      await pumpUntilFound(tester, find.text('หมวดการเรียนรู้'));
    }

    // ---- All ten games open without an error ----
    final gameTile = find.text('เกม');
    await tester.scrollUntilVisible(
      gameTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(gameTile);
    await pumpUntilFound(tester, find.text('ทายภาพ'));
    for (final game in const <String>[
      'ทายภาพ',
      'พยัญชนะต้น',
      'เสียงสัตว์',
      'งูน้อยฉลาดเลือก',
      'จับคู่เงา',
      'ปริศนาคำศัพท์',
      'ค้นหาคำศัพท์',
      'มอนสเตอร์แบทเทิล',
      'มินิมาร์เก็ต',
      'สร้างสะพาน',
    ]) {
      final card = find.text(game);
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(card);
      await settle(tester, const Duration(seconds: 3));
      expectNoCrash(tester, 'opening game "$game"');
      await _goBack(tester);
      expectNoCrash(tester, 'leaving game "$game"');
      await pumpUntilFound(tester, find.text('เกม'));
    }
    await _goBack(tester); // game list -> home
    await pumpUntilFound(tester, find.text('หมวดการเรียนรู้'));
  });

  // A separate run of the app, so snack bars and pages left over from the
  // game screens cannot interfere with the PIN dialog.
  testWidgets('parent PIN', (tester) async {
    await freshStart();
    app.main();
    await pumpUntilFound(
      tester,
      find.text('เริ่มต้นใช้งาน'),
      timeout: const Duration(seconds: 60),
    );

    // ---- Sign in ----
    await tester.tap(find.text('เริ่มต้นใช้งาน'));
    await pumpUntilFound(tester, find.byType(TextField));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), account.email);
    await tester.enterText(fields.at(1), account.password);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final signIn = find.text('เข้าสู่ระบบ').last;
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await pumpUntilFound(tester, find.text('หมวดการเรียนรู้'));

    // ---- Parent PIN: the first time, the app asks to create one ----
    await tester.tap(find.text('ตั้งค่า'));
    await pumpUntilFound(tester, find.text('รายงานและพัฒนาการการเรียน'));
    await tester.tap(find.text('รายงานและพัฒนาการการเรียน'));
    await pumpUntilFound(tester, find.text('ตั้งรหัส PIN ผู้ปกครอง'));

    final pinFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    // Mismatch is rejected...
    await tester.enterText(pinFields.at(0), '1234');
    await tester.enterText(pinFields.at(1), '9999');
    await tester.tap(find.text('ตั้งรหัสผ่าน'));
    await pumpUntilFound(tester, find.text('รหัส PIN ยืนยันไม่ตรงกัน'));

    // ...a matching PIN is saved.
    await tester.enterText(pinFields.at(1), '1234');
    await tester.tap(find.text('ตั้งรหัสผ่าน'));
    await pumpUntilFound(tester, find.text('บันทึกรหัส PIN ผู้ปกครองสำเร็จ !'));
  });
}

/// Goes back one page by popping the route directly. (Back arrows differ from
/// page to page and some games ask "leave the game?" first.)
Future<void> _goBack(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).last);
  Navigator.of(context).pop();
  await settle(tester, const Duration(seconds: 1));
}
