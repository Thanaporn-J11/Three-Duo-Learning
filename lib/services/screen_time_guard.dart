import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/setting_screen.dart' show RestScreen;
import '../widgets/parent_pin_prompt.dart';
import 'app_usage_sync.dart';
import 'user_account_preferences.dart';

/// Parent-zone time controls, enforced while the app is in use:
/// - daily limit: once today's usage reaches the limit the app shows
///   [RestScreen] until a parent unlocks it (for the rest of the day)
/// - downtime: inside the "no play" window the app shows [RestScreen]
///   until the window ends or a parent unlocks it
/// - eye rest: a short break reminder after 20 minutes of continuous use
///
/// Usage time is counted per account per day on this device, and also feeds
/// the "time spent" chart in the parent learning report.
class ScreenTimeGuard with WidgetsBindingObserver {
  ScreenTimeGuard._();
  static final ScreenTimeGuard instance = ScreenTimeGuard._();

  /// Give this to MaterialApp so the guard can show screens from anywhere.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const Duration _tick = Duration(seconds: 15);
  static const Duration eyeRestEvery = Duration(minutes: 20);
  static const Duration eyeRestLength = Duration(seconds: 20);

  // Parent settings (saved by the setting screen).
  static const String kLimitEnabled = 'parent_screen_time_enabled';
  static const String kLimitMinutes = 'parent_daily_time_limit';
  static const String kEyeRestEnabled = 'parent_eye_rest_enabled';
  static const String kDowntimeEnabled = 'parent_downtime_enabled';
  static const String kDowntimeStartH = 'parent_downtime_start_h';
  static const String kDowntimeStartM = 'parent_downtime_start_m';
  static const String kDowntimeEndH = 'parent_downtime_end_h';
  static const String kDowntimeEndM = 'parent_downtime_end_m';
  static const String _kOverrideUntil = 'parent_lock_override_until';

  Timer? _timer;
  DateTime? _lastTick;
  bool _foreground = true;
  bool _started = false;
  bool _lockShowing = false;
  bool _eyeRestShowing = false;
  Duration _continuous = Duration.zero;

  /// Ticks since the usage was last sent to the server.
  int _ticksSinceSync = 0;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _lastTick = DateTime.now();
    _timer = Timer.periodic(_tick, (_) => _onTick());
    AppUsageSync.flush(); // days counted while offline
    // First check shortly after launch (e.g. opened during downtime).
    Timer(const Duration(seconds: 2), checkNow);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _lastTick = DateTime.now();
      checkNow();
    } else if (_foreground) {
      // Count the time up to leaving the app, then back it up.
      _accumulate().then((_) => AppUsageSync.flush());
      _foreground = false;
      _continuous = Duration.zero; // leaving the app counts as a break
    }
  }

  Future<void> _onTick() async {
    if (!_foreground) return;
    await _accumulate();
    // Back up to the server every 2 minutes (8 ticks of 15 s).
    if (++_ticksSinceSync >= 8) {
      _ticksSinceSync = 0;
      AppUsageSync.flush();
    }
    await checkNow();
  }

  static String _dayKey(DateTime d) =>
      'usage_seconds_${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _accumulate() async {
    final now = DateTime.now();
    final last = _lastTick ?? now;
    _lastTick = now;
    if (_lockShowing) return; // time on the rest screen isn't usage
    var elapsed = now.difference(last);
    // Ignore gaps (device asleep, debugger paused): at most two ticks.
    if (elapsed.isNegative || elapsed > _tick * 2) elapsed = _tick;
    final userId = await UserAccountPreferences.currentUserId();
    if (userId == null) return;
    _continuous += elapsed;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = UserAccountPreferences.keyFor(_dayKey(now), userId);
      await prefs.setInt(key, (prefs.getInt(key) ?? 0) + elapsed.inSeconds);
    } catch (_) {}
  }

  /// Seconds used per day for the signed-in account, oldest first,
  /// for the last [days] days including today.
  static Future<List<({DateTime day, int seconds})>> usageLastDays(
    int days,
  ) async {
    final userId = await UserAccountPreferences.currentUserId();
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    return [
      for (int i = days - 1; i >= 0; i--)
        (() {
          final d = DateTime(today.year, today.month, today.day - i);
          final seconds =
              userId == null
                  ? 0
                  : prefs.getInt(
                        UserAccountPreferences.keyFor(_dayKey(d), userId),
                      ) ??
                      0;
          return (day: d, seconds: seconds);
        })(),
    ];
  }

  /// Re-checks the rules now (call after the parent changes a setting).
  Future<void> checkNow() async {
    if (_lockShowing) return;
    if (await UserAccountPreferences.currentUserId() == null) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final overrideUntil = prefs.getInt(_kOverrideUntil);
    final overridden =
        overrideUntil != null && now.millisecondsSinceEpoch < overrideUntil;

    if (!overridden) {
      // 1) Downtime window
      if (prefs.getBool(kDowntimeEnabled) ?? false) {
        final start = TimeOfDay(
          hour: prefs.getInt(kDowntimeStartH) ?? 20,
          minute: prefs.getInt(kDowntimeStartM) ?? 0,
        );
        final end = TimeOfDay(
          hour: prefs.getInt(kDowntimeEndH) ?? 7,
          minute: prefs.getInt(kDowntimeEndM) ?? 0,
        );
        final endsAt = _downtimeEndIfInside(now, start, end);
        if (endsAt != null) {
          await _showLock(
            title: 'ตอนนี้เป็นเวลาพักผ่อนแล้วนะ 🌙',
            message:
                'ผู้ปกครองตั้งให้งดเล่นแอปในช่วงนี้ '
                'แอปจะเปิดให้เล่นอีกครั้งเวลา ${_fmt(end)} น.',
            unlockUntil: endsAt,
          );
          return;
        }
      }

      // 2) Daily limit
      if (prefs.getBool(kLimitEnabled) ?? false) {
        final limitMinutes = prefs.getInt(kLimitMinutes) ?? 30;
        final userId = await UserAccountPreferences.currentUserId();
        if (userId == null) return;
        // This phone + the account's other phones today (from the server).
        final used =
            (prefs.getInt(UserAccountPreferences.keyFor(_dayKey(now), userId)) ??
                0) +
            AppUsageSync.othersTodaySeconds(now);
        if (used >= limitMinutes * 60) {
          await _showLock(
            title: 'ได้เวลาพักสายตา',
            message:
                'วันนี้น้อง ๆ เรียนครบ $limitMinutes นาทีตามที่ผู้ปกครองกำหนดแล้ว '
                'ไปพักผ่อนหรือทำกิจกรรมอื่นกันเถอะ แล้วพรุ่งนี้มาเรียนกันใหม่นะ !',
            unlockUntil: DateTime(now.year, now.month, now.day + 1),
          );
          return;
        }
      }
    }

    // 3) Eye-rest reminder (never locks)
    if ((prefs.getBool(kEyeRestEnabled) ?? true) &&
        _continuous >= eyeRestEvery) {
      _continuous = Duration.zero;
      await _showEyeRest();
    }
  }

  /// If [now] is inside the downtime window, returns when the window ends.
  static DateTime? _downtimeEndIfInside(
    DateTime now,
    TimeOfDay start,
    TimeOfDay end,
  ) {
    final s = start.hour * 60 + start.minute;
    final e = end.hour * 60 + end.minute;
    final m = now.hour * 60 + now.minute;
    if (s == e) return null;
    final inside = s < e ? (m >= s && m < e) : (m >= s || m < e);
    if (!inside) return null;
    final endToday = DateTime(now.year, now.month, now.day, end.hour, end.minute);
    return endToday.isAfter(now) ? endToday : endToday.add(const Duration(days: 1));
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _showLock({
    required String title,
    required String message,
    required DateTime unlockUntil,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null || _lockShowing) return;
    _lockShowing = true;
    await navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder:
            (routeContext) => RestScreen(
              title: title,
              message: message,
              onUnlock: () async {
                final ok = await showParentPinPrompt(
                  routeContext,
                  title: 'ปลดล็อกโดยผู้ปกครอง',
                );
                if (!ok) return;
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt(
                    _kOverrideUntil,
                    unlockUntil.millisecondsSinceEpoch,
                  );
                } catch (_) {}
                if (routeContext.mounted) Navigator.of(routeContext).pop();
              },
            ),
      ),
    );
    _lockShowing = false;
    _lastTick = DateTime.now();
    _continuous = Duration.zero;
  }

  Future<void> _showEyeRest() async {
    final context = navigatorKey.currentContext;
    if (context == null || _eyeRestShowing || _lockShowing) return;
    _eyeRestShowing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _EyeRestDialog(),
    );
    _eyeRestShowing = false;
  }
}

class _EyeRestDialog extends StatefulWidget {
  const _EyeRestDialog();

  @override
  State<_EyeRestDialog> createState() => _EyeRestDialogState();
}

class _EyeRestDialogState extends State<_EyeRestDialog> {
  late int _left = ScreenTimeGuard.eyeRestLength.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _left <= 0;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'พักสายตากันหน่อยนะ',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF26314F)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'เล่นมา 20 นาทีแล้ว ลองมองไปไกล ๆ นอกหน้าต่าง 20 วินาที แล้วค่อยกลับมาเรียนต่อ',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: done ? () => Navigator.pop(context) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4D7CFE),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(done ? 'พักเสร็จแล้ว กลับไปเรียนต่อ' : 'กำลังพักสายตา...'),
            ),
          ),
        ],
      ),
    );
  }
}
