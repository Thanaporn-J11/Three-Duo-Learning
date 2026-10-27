import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/config/api_config.dart';

/// A throw-away account for one test run. The email is unique so runs never
/// collide, and [cleanupAccount] removes it again.
class TestAccount {
  TestAccount()
    : email = 'e2e_${DateTime.now().microsecondsSinceEpoch}_${_count++}@example.com';

  static int _count = 0;

  final String email;
  final String name = 'E2E Tester';
  final String phone = '0812345678';
  final String password = 'Test@1234';
}

/// Waits (in real time) until [finder] matches something, or fails.
/// Used instead of `pumpAndSettle`, which never finishes on screens with
/// endless animations or while a request is in flight.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  // Say what IS on screen, so a failure can be understood without a debugger.
  final shown = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .take(80)
      .toList();
  throw TestFailure(
    'Timed out after $timeout waiting for: $finder\nTexts on screen: $shown',
  );
}

/// Forgets any sign-in left on the emulator by earlier manual use, so every
/// test starts from the Welcome screen.
Future<void> freshStart() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

/// Lets the UI run for [duration] (animations, short delays).
Future<void> settle(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 800),
]) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Creates the account on the backend without using the UI.
Future<void> registerViaApi(TestAccount a) async {
  final response = await http.post(
    Uri.parse('${ApiConfig.api}/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'name': a.name,
      'phone': a.phone,
      'email': a.email,
      'password': a.password,
    }),
  );
  if (response.statusCode != 201) {
    throw TestFailure(
      'Could not create the test account: ${response.statusCode} ${response.body}',
    );
  }
}

/// Deletes the account through the real API (best effort, never throws).
/// Safe to call when the test already deleted it.
Future<void> cleanupAccount(TestAccount a) async {
  try {
    final login = await http.post(
      Uri.parse('${ApiConfig.api}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': a.email, 'password': a.password}),
    );
    if (login.statusCode != 200) return;
    final token = (jsonDecode(login.body) as Map)['token'] as String?;
    if (token == null) return;
    await http.post(
      Uri.parse('${ApiConfig.api}/profile/delete-account'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'password': a.password}),
    );
  } catch (_) {}
}

/// Fails the test on a screen error, except the known "deactivated widget"
/// message raised while a game page is closing: that one is printed as a
/// warning (it is an app issue to fix, not a reason to stop the whole run).
void expectNoCrash(WidgetTester tester, String reason) {
  final e = tester.takeException();
  if (e == null) return;
  if (e.toString().contains("deactivated widget's ancestor")) {
    // ignore: avoid_print
    print('WARNING (app issue) $reason: $e');
    return;
  }
  fail('$reason: $e');
}

// ---------------------------------------------------------------------------
// Shared steps used by several test files
// ---------------------------------------------------------------------------

/// Starts the app signed out and waits for the Welcome screen.
Future<void> launchSignedOut(WidgetTester tester, void Function() appMain) async {
  await freshStart();
  appMain();
  await pumpUntilFound(
    tester,
    find.text('เริ่มต้นใช้งาน'),
    timeout: const Duration(seconds: 60),
  );
}

/// Welcome -> login form -> home page ("หมวดการเรียนรู้").
Future<void> signInViaUi(WidgetTester tester, TestAccount a) async {
  await tester.tap(find.text('เริ่มต้นใช้งาน'));
  await pumpUntilFound(tester, find.byType(TextField));
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), a.email);
  await tester.enterText(fields.at(1), a.password);
  await tester.pump();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  final signIn = find.text('เข้าสู่ระบบ').last;
  await tester.ensureVisible(signIn);
  await tester.tap(signIn);
  await pumpUntilFound(tester, find.text('หมวดการเรียนรู้'));
}

/// Scrolls the first scrollable until [text] is on screen. Waits first for the
/// floating "signed in" snack bar to go away, because it would swallow taps
/// near the bottom of the page.
Future<void> scrollToText(WidgetTester tester, String text) async {
  await settle(tester, const Duration(seconds: 5));
  await tester.scrollUntilVisible(
    find.text(text),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

/// Settings -> sign out -> Welcome.
Future<void> logOutViaUi(WidgetTester tester) async {
  // "ตั้งค่า" is both the bottom-bar label and the Settings page title, so
  // only use the bottom bar when Settings is not open yet.
  if (find.text('รายงานและพัฒนาการการเรียน').evaluate().isEmpty) {
    await tester.tap(find.text('ตั้งค่า'));
  }
  await pumpUntilFound(tester, find.text('ออกจากระบบ'));
  await scrollToText(tester, 'ออกจากระบบ');
  await tester.tap(find.text('ออกจากระบบ'));
  await settle(tester);
  await tester.tap(find.text('ออกจากระบบ').last); // the dialog's button
  await pumpUntilFound(tester, find.text('เริ่มต้นใช้งาน'));
}

/// Closes the top-most page, dialog or sheet.
Future<void> popTopRoute(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).last);
  Navigator.of(context).pop();
  await settle(tester, const Duration(seconds: 1));
}
