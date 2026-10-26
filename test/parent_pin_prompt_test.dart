import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:threeduo_learning/services/parent_pin.dart';
import 'package:threeduo_learning/widgets/parent_pin_prompt.dart';

import 'test_helpers.dart';

Future<bool?> _open(WidgetTester tester, {required bool setup}) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showParentPinPrompt(
                    context,
                    setupIfMissing: setup,
                  );
                },
                child: const Text('open'),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('no PIN and no setup asked: let through (old behaviour)', (
    tester,
  ) async {
    signIn();
    final result = await _open(tester, setup: false);
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('no PIN with setup asked: a PIN must be created first', (
    tester,
  ) async {
    signIn();
    await _open(tester, setup: true);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('ตั้งรหัส'), findsOneWidget);

    // Different codes -> error, nothing saved.
    await tester.enterText(find.byType(TextField).at(0), '1234');
    await tester.enterText(find.byType(TextField).at(1), '4321');
    await tester.tap(find.text('ตั้งรหัส'));
    await tester.pump();
    expect(find.text('รหัส PIN ยืนยันไม่ตรงกัน'), findsOneWidget);
    expect(await tester.runAsync(ParentPin.hasPin), isFalse);

    // Not four digits -> error.
    await tester.enterText(find.byType(TextField).at(0), '12');
    await tester.tap(find.text('ตั้งรหัส'));
    await tester.pump();
    expect(find.text('กรุณากรอกตัวเลข 4 หลัก'), findsOneWidget);

    // Matching code -> saved, and it is the PIN the parent zone checks.
    await tester.enterText(find.byType(TextField).at(0), '2468');
    await tester.enterText(find.byType(TextField).at(1), '2468');
    await tester.tap(find.text('ตั้งรหัส'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(await tester.runAsync(ParentPin.hasPin), isTrue);
    expect(await tester.runAsync(() => ParentPin.verify('2468')), PinCheck.ok);
    expect(await tester.runAsync(() => ParentPin.verify('1234')), PinCheck.wrong);
  });

  testWidgets('no PIN with setup asked: cancelling does not let through', (
    tester,
  ) async {
    signIn();
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showParentPinPrompt(
                      context,
                      setupIfMissing: true,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pump();
    await tester.pump();
    expect(result, isFalse);
    expect(await tester.runAsync(ParentPin.hasPin), isFalse);
  });
}
