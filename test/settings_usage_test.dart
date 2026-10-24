import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/screens/setting_screen.dart' show RestScreen;
import 'package:threeduo_learning/services/account_settings_sync.dart';
import 'package:threeduo_learning/services/app_usage_sync.dart';
import 'package:threeduo_learning/services/parent_pin.dart';
import 'package:threeduo_learning/services/screen_time_guard.dart';

import 'test_helpers.dart';

Future<String?> stringOf(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Future<bool> pendingOf(String group) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('settings_pending_${group}_user_1') ?? false;
}

String dayKey(DateTime d) =>
    'usage_seconds_${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String dayText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String usageKey(DateTime d) => '${dayKey(d)}_user_1';

DateTime daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - n);
}

Handler ok([int status = 200, Object? body]) =>
    (_) async => jsonResponse(body ?? <String, Object?>{}, status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    signIn();
    AppUsageSync.reset();
  });

  group('AccountSettingsSync pushing', () {
    Future<List<http.Request>> run(
      Future<void> Function() action, {
      Handler? handler,
    }) async {
      final requests = <http.Request>[];
      await withServer(action, (request) async {
        requests.add(request);
        return (handler ?? ok())(request);
      });
      return requests;
    }

    test('controls are sent with the defaults when nothing was changed',
        () async {
      final requests = await run(AccountSettingsSync.pushControls);

      expect(requests, hasLength(1));
      expect(requests.single.method, 'PUT');
      expect(requests.single.url.path, '/api/settings');
      expect(jsonDecode(requests.single.body), <String, Object?>{
        'screenTimeEnabled': false,
        'dailyTimeLimitMinutes': 30,
        'eyeRestReminderEnabled': true,
        'downtimeEnabled': false,
        'downtimeStart': '20:00',
        'downtimeEnd': '07:00',
      });
      expect(await pendingOf('controls'), isFalse);
    });

    test('controls are sent with the parent\'s choices', () async {
      signIn(<String, Object>{
        ScreenTimeGuard.kLimitEnabled: true,
        ScreenTimeGuard.kLimitMinutes: 45,
        ScreenTimeGuard.kEyeRestEnabled: false,
        ScreenTimeGuard.kDowntimeEnabled: true,
        ScreenTimeGuard.kDowntimeStartH: 21,
        ScreenTimeGuard.kDowntimeStartM: 5,
        ScreenTimeGuard.kDowntimeEndH: 6,
        ScreenTimeGuard.kDowntimeEndM: 30,
      });

      final requests = await run(AccountSettingsSync.pushControls);

      expect(jsonDecode(requests.single.body), <String, Object?>{
        'screenTimeEnabled': true,
        'dailyTimeLimitMinutes': 45,
        'eyeRestReminderEnabled': false,
        'downtimeEnabled': true,
        'downtimeStart': '21:05',
        'downtimeEnd': '06:30',
      });
    });

    test('a time limit that is not one of the choices becomes 30', () async {
      signIn(<String, Object>{ScreenTimeGuard.kLimitMinutes: 20});

      final requests = await run(AccountSettingsSync.pushControls);

      expect(jsonDecode(requests.single.body)['dailyTimeLimitMinutes'], 30);
    });

    test('the reminder uses the child\'s own settings, then the old ones',
        () async {
      var requests = await run(AccountSettingsSync.pushReminder);
      expect(jsonDecode(requests.single.body), <String, Object?>{
        'notificationsEnabled': true,
        'reminderHour': 20,
        'reminderMinute': 0,
      });

      signIn(<String, Object>{
        'notif_enabled': false,
        'notif_hour': 9,
        'notif_minute': 15,
      });
      requests = await run(AccountSettingsSync.pushReminder);
      expect(jsonDecode(requests.single.body), <String, Object?>{
        'notificationsEnabled': false,
        'reminderHour': 9,
        'reminderMinute': 15,
      });

      signIn(<String, Object>{
        'notif_enabled': false,
        'notif_hour': 9,
        'notif_enabled_user_1': true,
        'notif_hour_user_1': 18,
        'notif_minute_user_1': 45,
      });
      requests = await run(AccountSettingsSync.pushReminder);
      expect(jsonDecode(requests.single.body), <String, Object?>{
        'notificationsEnabled': true,
        'reminderHour': 18,
        'reminderMinute': 45,
      });
    });

    test('the PIN is sent as its hash, or as nothing when there is none',
        () async {
      var requests = await run(AccountSettingsSync.pushPin);
      expect(jsonDecode(requests.single.body), <String, Object?>{
        'pinHash': null,
        'pinSalt': null,
      });

      signIn(<String, Object>{
        'parent_pin_hash': 'hash',
        'parent_pin_salt': 'salt',
      });
      requests = await run(AccountSettingsSync.pushPin);
      expect(jsonDecode(requests.single.body), <String, Object?>{
        'pinHash': 'hash',
        'pinSalt': 'salt',
      });
    });

    test('a change the server refuses is not kept waiting', () async {
      await run(AccountSettingsSync.pushControls, handler: ok(400));

      expect(await pendingOf('controls'), isFalse);
    });

    test('a change that could not be sent is kept waiting', () async {
      await run(AccountSettingsSync.pushControls, handler: ok(500));
      expect(await pendingOf('controls'), isTrue);

      await withServer(AccountSettingsSync.pushReminder, offline);
      expect(await pendingOf('reminder'), isTrue);

      await run(AccountSettingsSync.pushPin, handler: ok(401));
      expect(await pendingOf('pin'), isTrue);
    });

    test('signed out: nothing is sent or kept waiting', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(() async {
        await AccountSettingsSync.pushControls();
        await AccountSettingsSync.pushReminder();
        await AccountSettingsSync.pushPin();
      }, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });

    test('a token but no valid account id sends nothing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'not-a-jwt',
      });
      var called = false;

      await withServer(AccountSettingsSync.pushControls, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });
  });

  group('AccountSettingsSync pull', () {
    Map<String, Object?> settings({
      bool controls = true,
      bool reminder = true,
      bool pin = true,
      Object? hash = 'srv-hash',
      Object? salt = 'srv-salt',
    }) => <String, Object?>{
      'controlsSaved': controls,
      'screenTimeEnabled': true,
      'dailyTimeLimitMinutes': 60,
      'eyeRestReminderEnabled': false,
      'downtimeEnabled': true,
      'downtimeStart': '21:30',
      'downtimeEnd': '06:15',
      'reminderSaved': reminder,
      'notificationsEnabled': false,
      'reminderHour': 8,
      'reminderMinute': 45,
      'pinSaved': pin,
      'pinHash': hash,
      'pinSalt': salt,
    };

    /// Answers the settings, and lessons (which pull also syncs).
    Handler server(Object? settingsBody, {int status = 200}) =>
        (request) async {
          if (request.url.path == '/api/lesson-progress') {
            return jsonResponse(<String, Object?>{'topics': <String, Object?>{}});
          }
          if (request.method == 'GET') {
            return jsonResponse(settingsBody, status);
          }
          return jsonResponse(<String, Object?>{});
        };

    Future<List<http.Request>> pull(Handler handler) async {
      final requests = <http.Request>[];
      await withServer(AccountSettingsSync.pull, (request) async {
        requests.add(request);
        return handler(request);
      });
      return requests;
    }

    Future<int> intOf(String key) async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(key) ?? -1;
    }

    Future<bool?> boolOf(String key) async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key);
    }

    test('takes the server\'s settings', () async {
      await pull(server(<String, Object?>{'settings': settings()}));

      expect(await boolOf(ScreenTimeGuard.kLimitEnabled), isTrue);
      expect(await intOf(ScreenTimeGuard.kLimitMinutes), 60);
      expect(await boolOf(ScreenTimeGuard.kEyeRestEnabled), isFalse);
      expect(await boolOf(ScreenTimeGuard.kDowntimeEnabled), isTrue);
      expect(await intOf(ScreenTimeGuard.kDowntimeStartH), 21);
      expect(await intOf(ScreenTimeGuard.kDowntimeStartM), 30);
      expect(await intOf(ScreenTimeGuard.kDowntimeEndH), 6);
      expect(await intOf(ScreenTimeGuard.kDowntimeEndM), 15);
      expect(await boolOf('notif_enabled_user_1'), isFalse);
      expect(await intOf('notif_hour_user_1'), 8);
      expect(await intOf('notif_minute_user_1'), 45);
      final pin = await ParentPin.storedHash();
      expect(pin!.hash, 'srv-hash');
      expect(pin.salt, 'srv-salt');
    });

    test('also looks for where lessons were left off', () async {
      final requests = await pull(
        server(<String, Object?>{'settings': settings()}),
      );

      expect(
        requests.map((r) => r.url.path),
        contains('/api/lesson-progress'),
      );
    });

    test('an account without a PIN removes the PIN on the phone', () async {
      signIn(<String, Object>{
        'parent_pin_hash': 'old',
        'parent_pin_salt': 'old',
      });

      await pull(
        server(<String, Object?>{
          'settings': settings(hash: null, salt: null),
        }),
      );

      expect(await ParentPin.storedHash(), isNull);
    });

    test('settings the server never received are uploaded from the phone',
        () async {
      signIn(<String, Object>{
        ScreenTimeGuard.kLimitMinutes: 15,
        'parent_pin_hash': 'hash',
        'parent_pin_salt': 'salt',
      });

      final requests = await pull(
        server(<String, Object?>{
          'settings': settings(controls: false, reminder: false, pin: false),
        }),
      );

      final puts = requests.where((r) => r.method == 'PUT').toList();
      expect(puts, hasLength(3));
      final bodies = puts.map((r) => jsonDecode(r.body) as Map).toList();
      expect(bodies.any((b) => b['dailyTimeLimitMinutes'] == 15), isTrue);
      expect(bodies.any((b) => b.containsKey('reminderHour')), isTrue);
      expect(bodies.any((b) => b['pinHash'] == 'hash'), isTrue);
      expect(await boolOf(ScreenTimeGuard.kLimitEnabled), isNull);
    });

    test('without a PIN on either side, no PIN is uploaded', () async {
      final requests = await pull(
        server(<String, Object?>{
          'settings': settings(controls: true, reminder: true, pin: false),
        }),
      );

      expect(requests.where((r) => r.method == 'PUT'), isEmpty);
    });

    test('changes waiting to be sent are sent before the server is asked',
        () async {
      signIn(<String, Object>{
        'settings_pending_controls_user_1': true,
        ScreenTimeGuard.kLimitMinutes: 15,
      });

      final requests = await pull(
        server(<String, Object?>{'settings': settings()}),
      );

      expect(requests.first.method, 'PUT');
      expect(jsonDecode(requests.first.body)['dailyTimeLimitMinutes'], 15);
      expect(await pendingOf('controls'), isFalse);
    });

    test('a waiting change that still cannot be sent keeps the phone\'s copy',
        () async {
      signIn(<String, Object>{
        'settings_pending_controls_user_1': true,
        ScreenTimeGuard.kLimitMinutes: 15,
      });

      await pull((request) async {
        if (request.method == 'PUT') {
          return jsonResponse(<String, Object?>{}, 500);
        }
        if (request.url.path == '/api/lesson-progress') {
          return jsonResponse(<String, Object?>{});
        }
        return jsonResponse(<String, Object?>{'settings': settings()});
      });

      expect(await intOf(ScreenTimeGuard.kLimitMinutes), 15);
      expect(await pendingOf('controls'), isTrue);
    });

    test('odd values from the server are ignored one by one', () async {
      await pull(
        server(<String, Object?>{
          'settings': <String, Object?>{
            'controlsSaved': true,
            'screenTimeEnabled': 'yes',
            'dailyTimeLimitMinutes': '60',
            'downtimeStart': 'soon',
            'downtimeEnd': '7',
            'reminderSaved': true,
            'notificationsEnabled': 1,
            'reminderHour': '8',
            'pinSaved': true,
            'pinHash': 5,
            'pinSalt': 5,
          },
        }),
      );

      expect(await boolOf(ScreenTimeGuard.kLimitEnabled), isNull);
      expect(await intOf(ScreenTimeGuard.kLimitMinutes), -1);
      expect(await intOf(ScreenTimeGuard.kDowntimeStartH), -1);
      expect(await intOf(ScreenTimeGuard.kDowntimeEndH), -1);
      expect(await intOf('notif_hour_user_1'), -1);
    });

    test('a server that cannot answer leaves the phone as it is', () async {
      signIn(<String, Object>{ScreenTimeGuard.kLimitMinutes: 15});

      await pull(server(<String, Object?>{}, status: 500));
      await withServer(AccountSettingsSync.pull, offline);
      await pull(server(<int>[1]));
      await pull(server(<String, Object?>{'settings': 'x'}));

      expect(await intOf(ScreenTimeGuard.kLimitMinutes), 15);
    });

    test('signed out: no request is made', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      await withServer(AccountSettingsSync.pull, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });

    test('asking twice at once does the work once', () async {
      var gets = 0;

      await withServer(() async {
        final a = AccountSettingsSync.pull();
        final b = AccountSettingsSync.pull();
        expect(identical(a, b), isTrue);
        await a;
      }, (request) async {
        if (request.url.path == '/api/settings' && request.method == 'GET') {
          gets++;
        }
        return jsonResponse(<String, Object?>{'topics': <String, Object?>{}});
      });

      expect(gets, 1);
    });
  });

  group('AppUsageSync', () {
    Handler server({
      Object? today = const <String, Object?>{'seconds': 0},
      Object? usage,
      int usageStatus = 200,
      List<http.Request>? log,
    }) => (request) async {
      log?.add(request);
      if (request.method == 'PUT') return jsonResponse(<String, Object?>{});
      if (request.url.path == '/api/usage/today-others') {
        return jsonResponse(today);
      }
      return jsonResponse(usage ?? <String, Object?>{'days': <Object?>[]}, usageStatus);
    };

    group('deviceId', () {
      test('is made once and kept', () async {
        final id = await AppUsageSync.deviceId();

        expect(id, matches(RegExp(r'^[a-z0-9]{24}$')));
        expect(await AppUsageSync.deviceId(), id);
        expect(await stringOf('app_install_id'), id);
      });

      test('a saved id is reused, a too-short one is replaced', () async {
        signIn(<String, Object>{'app_install_id': 'abcdefgh1234'});
        expect(await AppUsageSync.deviceId(), 'abcdefgh1234');

        signIn(<String, Object>{'app_install_id': 'short'});
        final fresh = await AppUsageSync.deviceId();
        expect(fresh, hasLength(24));
        expect(fresh, isNot('short'));
      });
    });

    group('flush', () {
      test('sends the days used and asks about the other phones', () async {
        final today = daysAgo(0);
        signIn(<String, Object>{
          usageKey(today): 120,
          usageKey(daysAgo(1)): 999999,
          usageKey(daysAgo(2)): 0,
          'app_install_id': 'install-id-12345',
        });
        final log = <http.Request>[];

        await withServer(
          AppUsageSync.flush,
          server(today: <String, Object?>{'seconds': 300}, log: log),
        );

        final put = log.firstWhere((r) => r.method == 'PUT');
        expect(put.url.path, '/api/usage');
        final body = jsonDecode(put.body) as Map<String, dynamic>;
        expect(body['deviceId'], 'install-id-12345');
        expect(body['days'], <String, Object?>{
          dayText(today): 120,
          dayText(daysAgo(1)): 86400,
        });
        final get = log.firstWhere((r) => r.method == 'GET');
        expect(get.url.path, '/api/usage/today-others');
        expect(get.url.queryParameters['deviceId'], 'install-id-12345');
        expect(AppUsageSync.othersTodaySeconds(), 300);
      });

      test('nothing is sent when no time was used, but others are asked',
          () async {
        final log = <http.Request>[];

        await withServer(AppUsageSync.flush, server(log: log));

        expect(log.where((r) => r.method == 'PUT'), isEmpty);
        expect(log.where((r) => r.method == 'GET'), hasLength(1));
      });

      test('signed out: no request is made', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        var called = false;

        await withServer(AppUsageSync.flush, (_) async {
          called = true;
          return jsonResponse(<String, Object?>{});
        });

        expect(called, isFalse);
      });

      test('no network is not an error', () async {
        signIn(<String, Object>{usageKey(daysAgo(0)): 60});

        await withServer(AppUsageSync.flush, offline);

        expect(AppUsageSync.othersTodaySeconds(), 0);
      });

      test('an answer that is not usable leaves the other phones at zero',
          () async {
        await withServer(AppUsageSync.flush, ok(500));
        expect(AppUsageSync.othersTodaySeconds(), 0);

        await withServer(
          AppUsageSync.flush,
          server(today: <String, Object?>{'seconds': 'x'}),
        );
        expect(AppUsageSync.othersTodaySeconds(), 0);

        await withServer(AppUsageSync.flush, server(today: <int>[1]));
        expect(AppUsageSync.othersTodaySeconds(), 0);
      });
    });

    group('othersTodaySeconds', () {
      test('only counts for the day it was read', () async {
        await withServer(
          AppUsageSync.flush,
          server(today: <String, Object?>{'seconds': 300}),
        );

        expect(AppUsageSync.othersTodaySeconds(), 300);
        expect(
          AppUsageSync.othersTodaySeconds(
            DateTime.now().add(const Duration(days: 2)),
          ),
          0,
        );
      });

      test('reset forgets it', () async {
        await withServer(
          AppUsageSync.flush,
          server(today: <String, Object?>{'seconds': 300}),
        );

        AppUsageSync.reset();

        expect(AppUsageSync.othersTodaySeconds(), 0);
      });
    });

    group('lastDays', () {
      test('on this phone only when signed out', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});

        final days = await AppUsageSync.lastDays(3);

        expect(days, hasLength(3));
        expect(days.every((d) => d.seconds == 0), isTrue);
      });

      test('takes the server total but never less than this phone', () async {
        signIn(<String, Object>{
          usageKey(daysAgo(0)): 500,
          usageKey(daysAgo(1)): 100,
          usageKey(daysAgo(2)): 50,
        });

        final days = await withServer(
          () => AppUsageSync.lastDays(3),
          server(usage: <String, Object?>{
            'days': <Object?>[
              <String, Object?>{'day': dayText(daysAgo(0)), 'seconds': 200},
              <String, Object?>{'day': dayText(daysAgo(1)), 'seconds': 900},
              <String, Object?>{'day': 5, 'seconds': 900},
              <String, Object?>{'day': dayText(daysAgo(2)), 'seconds': 'x'},
              'x',
            ],
          }),
        );

        expect(days.map((d) => d.seconds), <int>[50, 900, 500]);
        expect(days.last.day, daysAgo(0));
      });

      test('falls back to this phone when the server cannot help', () async {
        signIn(<String, Object>{usageKey(daysAgo(0)): 500});

        for (final handler in <Handler>[
          server(usageStatus: 500),
          offline,
          server(usage: <int>[1]),
          server(usage: <String, Object?>{'days': 'x'}),
        ]) {
          final days = await withServer(() => AppUsageSync.lastDays(2), handler);

          expect(days.map((d) => d.seconds), <int>[0, 500]);
        }
      });
    });
  });

  group('ScreenTimeGuard usage', () {
    test('lists the seconds used, oldest day first, today last', () async {
      signIn(<String, Object>{
        usageKey(daysAgo(0)): 30,
        usageKey(daysAgo(2)): 90,
        '${dayKey(daysAgo(1))}_user_2': 999,
      });

      final days = await ScreenTimeGuard.usageLastDays(3);

      expect(days.map((d) => d.seconds), <int>[90, 0, 30]);
      expect(days.first.day, daysAgo(2));
      expect(days.last.day, daysAgo(0));
    });

    test('a signed-out phone has no usage', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        usageKey(daysAgo(0)): 30,
      });

      final days = await ScreenTimeGuard.usageLastDays(2);

      expect(days.every((d) => d.seconds == 0), isTrue);
    });

    test('leaving and coming back to the app is handled', () async {
      final log = <http.Request>[];

      await withServer(() async {
        final guard = ScreenTimeGuard.instance;
        guard.didChangeAppLifecycleState(AppLifecycleState.paused);
        await pumpEventQueue();
        guard.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await pumpEventQueue();
      }, (request) async {
        log.add(request);
        return jsonResponse(<String, Object?>{'seconds': 0});
      });

      expect(
        log.map((r) => r.url.path),
        contains('/api/usage/today-others'),
      );
    });
  });

  group('ScreenTimeGuard rules', () {
    final guard = ScreenTimeGuard.instance;

    Future<void> openApp(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: guard.navigatorKey,
          home: const Scaffold(body: Text('home')),
        ),
      );
    }

    /// Runs the check, then shows whatever it pushed.
    Future<void> check(WidgetTester tester) async {
      await tester.runAsync(() async {
        unawaited(guard.checkNow());
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    /// Closes a rest screen so the next test starts clean.
    Future<void> close(WidgetTester tester) async {
      if (find.byType(RestScreen).evaluate().isEmpty) return;
      guard.navigatorKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }

    Map<String, Object> window({required bool inside}) {
      final now = DateTime.now();
      final startHour = inside ? (now.hour + 23) % 24 : (now.hour + 2) % 24;
      final endHour = inside ? (now.hour + 1) % 24 : (now.hour + 3) % 24;
      return <String, Object>{
        ScreenTimeGuard.kDowntimeEnabled: true,
        ScreenTimeGuard.kDowntimeStartH: startHour,
        ScreenTimeGuard.kDowntimeStartM: 0,
        ScreenTimeGuard.kDowntimeEndH: endHour,
        ScreenTimeGuard.kDowntimeEndM: 0,
      };
    }

    testWidgets('downtime shows the rest screen with the time it ends',
        (tester) async {
      final now = DateTime.now();
      signIn(window(inside: true));
      await openApp(tester);

      await check(tester);

      expect(find.byType(RestScreen), findsOneWidget);
      final endHour = ((now.hour + 1) % 24).toString().padLeft(2, '0');
      expect(find.textContaining('$endHour:00 น.'), findsOneWidget);
      await close(tester);
    });

    testWidgets('outside the downtime window nothing is shown',
        (tester) async {
      signIn(window(inside: false));
      await openApp(tester);

      await check(tester);

      expect(find.byType(RestScreen), findsNothing);
    });

    testWidgets('a start and end that are the same never lock',
        (tester) async {
      signIn(<String, Object>{
        ScreenTimeGuard.kDowntimeEnabled: true,
        ScreenTimeGuard.kDowntimeStartH: 8,
        ScreenTimeGuard.kDowntimeEndH: 8,
      });
      await openApp(tester);

      await check(tester);

      expect(find.byType(RestScreen), findsNothing);
    });

    testWidgets('reaching the daily limit shows the rest screen',
        (tester) async {
      signIn(<String, Object>{
        ScreenTimeGuard.kLimitEnabled: true,
        ScreenTimeGuard.kLimitMinutes: 15,
        usageKey(DateTime.now()): 15 * 60,
      });
      await openApp(tester);

      await check(tester);

      expect(find.byType(RestScreen), findsOneWidget);
      expect(find.text('ได้เวลาพักสายตา'), findsOneWidget);
      await close(tester);
    });

    testWidgets('under the daily limit nothing is shown', (tester) async {
      signIn(<String, Object>{
        ScreenTimeGuard.kLimitEnabled: true,
        ScreenTimeGuard.kLimitMinutes: 15,
        usageKey(DateTime.now()): 15 * 60 - 1,
      });
      await openApp(tester);

      await check(tester);

      expect(find.byType(RestScreen), findsNothing);
    });

    testWidgets('a limit that is switched off never locks', (tester) async {
      signIn(<String, Object>{
        ScreenTimeGuard.kLimitMinutes: 15,
        usageKey(DateTime.now()): 99999,
      });
      await openApp(tester);

      await check(tester);

      expect(find.byType(RestScreen), findsNothing);
    });

    testWidgets('a parent\'s unlock lets the child play until it ends',
        (tester) async {
      signIn(<String, Object>{
        ScreenTimeGuard.kLimitEnabled: true,
        ScreenTimeGuard.kLimitMinutes: 15,
        usageKey(DateTime.now()): 99999,
        'parent_lock_override_until':
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
      });
      await openApp(tester);

      await check(tester);

      expect(find.byType(RestScreen), findsNothing);
    });

    testWidgets('an unlock that has run out no longer counts', (tester) async {
      signIn(<String, Object>{
        ScreenTimeGuard.kLimitEnabled: true,
        ScreenTimeGuard.kLimitMinutes: 15,
        usageKey(DateTime.now()): 99999,
        'parent_lock_override_until':
            DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      });
      await openApp(tester);

      await check(tester);

      expect(find.byType(RestScreen), findsOneWidget);
      await close(tester);
    });

    testWidgets('signed out: nothing is shown', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ...window(inside: true),
      });
      await openApp(tester);

      await check(tester);

      expect(find.byType(RestScreen), findsNothing);
    });
  });
}
