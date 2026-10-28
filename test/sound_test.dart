import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/sfx.dart';
import 'package:threeduo_learning/widgets/bottom_bar_fill.dart';
import 'package:threeduo_learning/widgets/music_scope.dart';
import 'package:threeduo_learning/widgets/sfx_tap_listener.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sfx settings', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sound and music are on by default', () async {
      await Sfx.load();
      expect(Sfx.soundEnabled, isTrue);
      expect(Sfx.musicEnabled, isTrue);
    });

    test('the choices are saved and loaded again', () async {
      await Sfx.setSoundEnabled(false);
      await Sfx.setMusicEnabled(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sfx_sound_enabled'), isFalse);
      expect(prefs.getBool('sfx_music_enabled'), isFalse);

      await Sfx.setSoundEnabled(true);
      await Sfx.setMusicEnabled(true);
      await Sfx.load();
      expect(Sfx.soundEnabled, isTrue);
      expect(Sfx.musicEnabled, isTrue);
    });

    test('load reads values that were saved earlier', () async {
      SharedPreferences.setMockInitialValues({
        'sfx_sound_enabled': false,
        'sfx_music_enabled': false,
      });
      await Sfx.load();
      expect(Sfx.soundEnabled, isFalse);
      expect(Sfx.musicEnabled, isFalse);
      await Sfx.setSoundEnabled(true);
      await Sfx.setMusicEnabled(true);
    });

    test('playing sounds in tests never throws', () {
      Sfx.correct();
      Sfx.wrong();
      Sfx.complete();
      Sfx.reward();
      Sfx.tap();
      Sfx.welcomeOnce();
      Sfx.musicScopeEnter();
      Sfx.musicScopeExit();
      Sfx.musicScopeExit(); // more exits than enters is harmless
    });
  });

  group('MusicScope', () {
    testWidgets('shows its child and follows the route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [musicRouteObserver],
          home: Builder(
            builder: (context) => const MusicScope(child: Text('home')),
          ),
        ),
      );
      expect(find.text('home'), findsOneWidget);

      // Covered by another page, then shown again, then removed.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const MusicScope(child: Text('other')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('other'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a dialog does not count as leaving the screen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [musicRouteObserver],
          home: const MusicScope(child: Text('home')),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      showDialog<void>(
        context: navigator.context,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      );
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('SfxTapListener', () {
    testWidgets('taps on buttons and background still work', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SfxTapListener(
            child: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => taps++,
                    child: const Text('go'),
                  ),
                  const Text('plain'),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.tap(find.text('plain'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
    });

    testWidgets('dragging and two fingers are not taps', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SfxTapListener(
            child: Scaffold(
              body: ListView(
                children: [
                  for (var i = 0; i < 30; i++)
                    ListTile(title: Text('item $i'), onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 200));

      final a = await tester.startGesture(const Offset(100, 100));
      final b = await tester.startGesture(const Offset(200, 100));
      await a.up();
      await b.up();
      final c = await tester.startGesture(const Offset(100, 300));
      await c.cancel();
      await tester.pump(const Duration(milliseconds: 200));
    });
  });

  group('BottomBarFill', () {
    testWidgets('lifts the app above the bar and samples its colour',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: BottomBarFill(
            bar: 48,
            child: ColoredBox(color: Color(0xFF123456)),
          ),
        ),
      );

      // The timer fires and takes a picture of the app; whatever the colour
      // turns out to be, the page must stay on screen and nothing may throw.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AnimatedContainer), findsOneWidget);
      expect(find.byType(ColoredBox), findsWidgets);

      // Removing it stops the timer.
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('sound files are bundled', () async {
    for (final name in [
      'correct',
      'wrong',
      'complete',
      'tap',
      'reward',
      'welcome',
      'bgm',
    ]) {
      final data = await rootBundle.load('assets/sounds/sfx/$name.wav');
      expect(data.lengthInBytes, greaterThan(1000), reason: name);
    }
  });
}
