import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/startup_gate.dart';
import 'screens/home_screen.dart';
import 'screens/checkin_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'services/listening_results_service.dart';
import 'services/vocabulary_progress_service.dart';
import 'services/phonics_progress_service.dart';
import 'services/guess_progress_service.dart';
import 'services/shadow_progress_service.dart';
import 'services/riddle_progress_service.dart';
import 'services/word_search_progress_service.dart';
import 'services/app_usage_sync.dart';
import 'services/lesson_progress.dart';
import 'services/letter_levels_service.dart';
import 'services/animal_sound_service.dart';
import 'services/alphabet_train_service.dart';
import 'services/monster_battle_service.dart';
import 'services/market_service.dart';
import 'services/bridge_service.dart';
import 'services/coin_balance.dart';
import 'services/user_account_preferences.dart';
import 'services/screen_time_guard.dart';
import 'services/sfx.dart';
import 'widgets/music_scope.dart';
import 'widgets/sfx_tap_listener.dart';
import 'widgets/bottom_bar_fill.dart';

void main() {
  runApp(const ThreeDuoApp());
  // Saved sound / music on-off choices, and the app-level music handling.
  Sfx.load();
  // Schedule (or cancel) the daily check-in reminder from saved settings.
  // Runs after runApp so the permission dialog can show over the app.
  NotificationService.instance.syncDailyReminderFromSettings();
  // Parent time controls: daily limit, downtime and eye-rest reminders.
  ScreenTimeGuard.instance.start();
  // Send listening-game results that were saved while offline.
  ListeningResults.flush();
  VocabularyProgress.flush();
  PhonicsProgress.flush();
  GuessCoins.flush();
  GuessProgress.flush();
  ShadowCoins.flush();
  ShadowProgress.flush();
  RiddleCoins.flush();
  RiddleProgress.flush();
  WordSearchCoins.flush();
  WordSearchProgress.flush();
  LessonProgress.flush();
  LetterLevels.flush();
  LetterCoins.flush();
  LetterResume.flush();
  AnimalSoundCoins.flush();
  AnimalSoundProgress.flush();
  AlphabetLevels.flush();
  AlphabetCoins.flush();
  AlphabetResume.flush();
  MonsterStateSync.flush();
  MonsterCoins.flush();
  MonsterResume.flush();
  MarketStateSync.flush();
  MarketCoins.flush();
  MarketResume.flush();
  BridgeStateSync.flush();
  BridgeCoins.flush();
  BridgeResume.flush();
  // Other phones' time today belongs to the old account after a logout.
  UserAccountPreferences.registerMemoryResetter(AppUsageSync.reset);
  // Coins shown at the top of game screens: forget them on logout.
  UserAccountPreferences.registerMemoryResetter(CoinBalance.clear);
}

class ThreeDuoApp extends StatelessWidget {
  const ThreeDuoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: ScreenTimeGuard.instance.navigatorKey,
      title: 'ThreeDuo Learning',
      navigatorObservers: [profileRouteObserver, musicRouteObserver],
      // Soft pop on every button tap.
      builder: (context, child) {
        final app = SfxTapListener(child: child ?? const SizedBox.shrink());
        // Phones with the three-button bar (not the thin gesture line): the
        // app draws underneath it and bottom buttons / sheets get cut off.
        // Lift the whole app above the bar.
        final mq = MediaQuery.of(context);
        final bar = mq.viewPadding.bottom;
        if (bar < 30) return app;
        return BottomBarFill(
          bar: bar,
          child: MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: 0),
              viewPadding: mq.viewPadding.copyWith(bottom: 0),
              viewInsets: mq.viewInsets.copyWith(
                bottom: mq.viewInsets.bottom > bar
                    ? mq.viewInsets.bottom - bar
                    : 0,
              ),
            ),
            child: app,
          ),
        );
      },

      theme: ThemeData(
        fontFamily: 'Roboto',
      ),

      // Signed in already? -> home screen; otherwise -> welcome screen.
      home: const StartupGate(),

      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/checkin': (context) => const CheckInScreen(),
        '/setting': (context) => const SettingScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
