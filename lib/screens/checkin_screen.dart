import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../services/account_settings_sync.dart';
import '../services/user_account_preferences.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'setting_screen.dart';
import '../config/api_config.dart';

class Milestone {
  final int days;
  final String title;
  final String rewardDescription;
  final String emoji;

  const Milestone({
    required this.days,
    required this.title,
    required this.rewardDescription,
    required this.emoji,
  });
}

const List<Milestone> kMilestones = [
  Milestone(
    days: 7,
    title: '7 วันติดต่อกัน',
    rewardDescription: 'ปลดล็อกโล่ป้องกันสตรีค 🛡️ +1',
    emoji: '🥉',
  ),
  Milestone(
    days: 30,
    title: '30 วันติดต่อกัน',
    rewardDescription: 'ปลดล็อกโล่ป้องกันสตรีค 🛡️ +1 และป้าย "นักเรียนขยัน"',
    emoji: '🥈',
  ),
  Milestone(
    days: 100,
    title: '100 วันติดต่อกัน',
    rewardDescription:
        'ปลดล็อกโล่ป้องกันสตรีค 🛡️ +1 และป้าย "เซียนภาษาอังกฤษ"',
    emoji: '🥇',
  ),
];

class CheckInResult {
  final bool success;
  final bool alreadyCheckedToday;
  final int newStreak;
  final Milestone? milestoneReached;

  /// Set when the check-in could not be saved (offline, server error...).
  final String? errorMessage;

  const CheckInResult({
    required this.success,
    required this.alreadyCheckedToday,
    required this.newStreak,
    required this.milestoneReached,
    this.errorMessage,
  });
}

enum DayStatus { checked, shielded, missed, future }

class CheckInService {
  CheckInService._internal() {
    // Forget the previous account's streak/settings when someone logs out.
    UserAccountPreferences.registerMemoryResetter(_resetOnLogout);
  }
  static final CheckInService instance = CheckInService._internal();

  void _resetOnLogout() {
    _initialized = false;
    _resetLocalState();
    notifEnabled = true;
    notifHour = 20;
    notifMinute = 0;
  }

  // Reminder settings are saved per account. The old device-wide keys are
  // only read as a fallback so a choice made before this change carries over.
  static Future<({bool enabled, int hour, int minute})> readNotificationSettings(
    SharedPreferences prefs,
  ) async {
    final String? userId = await UserAccountPreferences.currentUserId();
    String key(String base) =>
        userId == null ? base : UserAccountPreferences.keyFor(base, userId);
    return (
      enabled:
          prefs.getBool(key('notif_enabled')) ??
          prefs.getBool('notif_enabled') ??
          true,
      hour: prefs.getInt(key('notif_hour')) ?? prefs.getInt('notif_hour') ?? 20,
      minute:
          prefs.getInt(key('notif_minute')) ??
          prefs.getInt('notif_minute') ??
          0,
    );
  }

  final String _baseUrl = '${ApiConfig.api}/checkin';
  static const Duration _timeout = Duration(seconds: 12);

  late SharedPreferences _prefs;
  bool _initialized = false;

  String _userName = 'เพื่อนๆ';
  String get userName => _userName;

  Set<String> _checkedDateKeys = {};
  Set<String> _shieldDateKeys = {};
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _shieldCount = 1;
  Set<int> _claimedMilestones = {};
  bool _isCheckedToday = false;
  bool _isQuizDoneToday = false;
  int _wordsLearned = 0;

  bool notifEnabled = true;
  int notifHour = 20;
  int notifMinute = 0;

  bool get isInitialized => _initialized;
  bool get isCheckedToday => _isCheckedToday;
  bool get isQuizDoneToday => _isQuizDoneToday;
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get shieldCount => _shieldCount;
  int get wordsLearned => _wordsLearned;
  Set<String> get checkedDateKeys => Set.unmodifiable(_checkedDateKeys);
  Set<String> get shieldDateKeys => Set.unmodifiable(_shieldDateKeys);
  Set<int> get claimedMilestones => Set.unmodifiable(_claimedMilestones);

  Future<String?> _getToken() async {
    _prefs = await SharedPreferences.getInstance();
    return _prefs.getString('jwt_token');
  }

  void _resetLocalState() {
    _userName = 'เพื่อนๆ';
    _currentStreak = 0;
    _longestStreak = 0;
    _shieldCount = 1;
    _wordsLearned = 0;
    _isCheckedToday = false;
    _isQuizDoneToday = false;
    _checkedDateKeys = {};
    _shieldDateKeys = {};
    _claimedMilestones = {};
  }

  Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _prefs = await SharedPreferences.getInstance();

    _userName =
        _prefs.getString('username') ??
        _prefs.getString('name') ??
        _prefs.getString('user_name') ??
        'เพื่อนๆ';

    final notif = await readNotificationSettings(_prefs);
    notifEnabled = notif.enabled;
    notifHour = notif.hour;
    notifMinute = notif.minute;

    final token = await _getToken();
    if (token == null) {
      _resetLocalState();
      _initialized = true;
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _userName = data['display_name'] ?? data['username'] ?? 'เพื่อนๆ';
        _currentStreak = data['current_streak'] ?? 0;
        _longestStreak = data['longest_streak'] ?? 0;
        _shieldCount = data['shield_count'] ?? 1;
        _wordsLearned = data['words_learned'] ?? 0;
        _isCheckedToday = data['is_checked_today'] ?? false;
        _isQuizDoneToday = data['is_quiz_done_today'] ?? false;
        _checkedDateKeys = Set<String>.from(data['checked_dates'] ?? []);
        _shieldDateKeys = Set<String>.from(data['shield_dates'] ?? []);
        _claimedMilestones = Set<int>.from(
          (data['claimed_milestones'] as List? ?? []).map(
            (e) => int.tryParse(e.toString()) ?? 0,
          ),
        );
      } else {
        _resetLocalState();
      }

      // ดึงจาก /api/profile สำรองหากชื่อยังเป็น 'เพื่อนๆ'
      if (_userName == 'เพื่อนๆ') {
        try {
          final profileRes = await http.get(
            Uri.parse('${ApiConfig.api}/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(_timeout);
          if (profileRes.statusCode == 200) {
            final pData = jsonDecode(profileRes.body);
            final fetchedName =
                pData['name'] ??
                pData['username'] ??
                pData['full_name'] ??
                pData['user']?['name'] ??
                pData['user']?['username'];
            if (fetchedName != null && fetchedName.toString().isNotEmpty) {
              _userName = fetchedName.toString();
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Failed to load checkin status: $e');
    }

    _initialized = true;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _key(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  /// True if [day] counts for the streak (checked in or covered by a shield).
  bool keptStreakOn(DateTime day) {
    final key = _key(_dateOnly(day));
    return _checkedDateKeys.contains(key) || _shieldDateKeys.contains(key);
  }

  DayStatus statusFor(DateTime day) {
    final today = _dateOnly(DateTime.now());
    final d = _dateOnly(day);
    if (d.isAfter(today)) return DayStatus.future;
    final key = _key(d);
    if (_checkedDateKeys.contains(key)) return DayStatus.checked;
    if (_shieldDateKeys.contains(key)) return DayStatus.shielded;
    if (_checkedDateKeys.isEmpty ||
        _checkedDateKeys.every((k) => k.compareTo(key) > 0)) {
      return DayStatus.future;
    }
    return DayStatus.missed;
  }

  Future<CheckInResult> checkIn() async {
    final token = await _getToken();
    if (token == null) {
      return const CheckInResult(
        success: false,
        alreadyCheckedToday: false,
        newStreak: 0,
        milestoneReached: null,
        errorMessage: 'กรุณาเข้าสู่ระบบใหม่',
      );
    }

    try {
      final res = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _currentStreak = data['new_streak'] ?? _currentStreak + 1;
        if (_currentStreak > _longestStreak) _longestStreak = _currentStreak;
        _isCheckedToday = true;
        _checkedDateKeys.add(_key(_dateOnly(DateTime.now())));
        // Drop today's reminders now that the user has checked in.
        NotificationService.instance.syncDailyReminderFromSettings();

        Milestone? reached;
        if (data['milestone_reached'] != null) {
          final m = data['milestone_reached'];
          reached = Milestone(
            days: m['days'],
            title: m['title'],
            rewardDescription: m['reward_description'],
            emoji: m['emoji'] ?? '🥉',
          );
          _shieldCount += 1;
          _claimedMilestones.add(m['days']);
        }

        return CheckInResult(
          success: true,
          alreadyCheckedToday: false,
          newStreak: _currentStreak,
          milestoneReached: reached,
        );
      } else {
        if (data['already_checked_today'] == true) {
          _isCheckedToday = true;
          _checkedDateKeys.add(_key(_dateOnly(DateTime.now())));
          NotificationService.instance.syncDailyReminderFromSettings();
        }

        // A server error is NOT "already checked in" (it used to default to true).
        final bool already = data['already_checked_today'] == true;
        return CheckInResult(
          success: false,
          alreadyCheckedToday: already,
          newStreak: _currentStreak,
          milestoneReached: null,
          errorMessage:
              already ? null : 'เช็คอินไม่สำเร็จ (HTTP ${res.statusCode}) ลองใหม่อีกครั้งนะ',
        );
      }
    } catch (e) {
      debugPrint('CheckIn Error: $e');
      return CheckInResult(
        success: false,
        alreadyCheckedToday: false,
        newStreak: _currentStreak,
        milestoneReached: null,
        errorMessage: 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่อีกครั้งนะ',
      );
    }
  }

  /// Returns true when the server saved today's quiz.
  Future<bool> completeQuiz() async {
    final token = await _getToken();
    if (token == null) return false;

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/quiz-complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _isQuizDoneToday = true;
        _wordsLearned = data['words_learned'] ?? (_wordsLearned + 1);
        return true;
      }
    } catch (e) {
      debugPrint('CompleteQuiz Error: $e');
    }
    return false;
  }

  Future<void> setNotificationSettings({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    notifEnabled = enabled;
    notifHour = hour;
    notifMinute = minute;
    _prefs = await SharedPreferences.getInstance();
    final String? userId = await UserAccountPreferences.currentUserId();
    String key(String base) =>
        userId == null ? base : UserAccountPreferences.keyFor(base, userId);
    await _prefs.setBool(key('notif_enabled'), enabled);
    await _prefs.setInt(key('notif_hour'), hour);
    await _prefs.setInt(key('notif_minute'), minute);
    unawaited(AccountSettingsSync.pushReminder()); // keep it with the account
  }
}

class NotificationService {
  NotificationService._internal() {
    // Reminders belong to the signed-in account: drop them on logout.
    UserAccountPreferences.registerLogoutHook(cancelDailyReminder);
  }
  static final NotificationService instance = NotificationService._internal();

  // One notification per day, scheduled a week ahead (ids 100-106), instead of
  // a single repeating one, so the day the user has already checked in can be
  // skipped. Rescheduled on every app start and after every check-in.
  static const int _dailyReminderBaseId = 100;
  static const int _streakWarningBaseId = 200; // 200-201
  static const int _daysAhead = 7;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    _configureLocalTimeZone();

    // White silhouette of the mascot (Android shows the small icon as one colour).
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_notify');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(settings);

    _initialized = true;
  }

  // tz.local defaults to UTC, so a reminder set for 20:00 used to fire at
  // 20:00 UTC (03:00 in Thailand). Point tz.local at the device's time zone.
  void _configureLocalTimeZone() {
    final int offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
    tz.Location? match;
    if (offsetMs == const Duration(hours: 7).inMilliseconds) {
      match = tz.getLocation('Asia/Bangkok');
    } else {
      for (final tz.Location location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == offsetMs) {
          match = location;
          break;
        }
      }
    }
    tz.setLocalLocation(match ?? tz.UTC);
  }

  /// Asks for notification permission (Android 13+ / iOS). Returns true when
  /// notifications are allowed. Android 12 and older need no runtime permission.
  Future<bool> requestPermission() async {
    await init();
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android != null) {
      final bool? granted = await android.requestNotificationsPermission();
      return granted ?? true;
    }
    final ios =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    if (ios != null) {
      final bool? granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Re-applies the saved reminder setting. Called once at app start so the
  /// reminder works even if the user never opens the check-in screen.
  /// Pass [refreshStatus] after a login so the new account's check-in status
  /// and streak are fetched instead of reusing what is in memory.
  Future<void> syncDailyReminderFromSettings({bool refreshStatus = false}) async {
    try {
      // Nobody signed in: no reminders.
      if (await UserAccountPreferences.currentUserId() == null) {
        await cancelDailyReminder();
        return;
      }
      // Settings saved with the account (reminder, parent controls, PIN,
      // lesson positions), e.g. after reinstalling the app or a new login.
      await AccountSettingsSync.pull();
      // Need today's check-in status and the streak to plan the reminders.
      await CheckInService.instance.init(force: refreshStatus);
      final prefs = await SharedPreferences.getInstance();
      final settings = await CheckInService.readNotificationSettings(prefs);
      CheckInService.instance
        ..notifEnabled = settings.enabled
        ..notifHour = settings.hour
        ..notifMinute = settings.minute;
      if (settings.enabled) {
        await scheduleDailyReminder(
          hour: settings.hour,
          minute: settings.minute,
        );
      } else {
        await cancelDailyReminder();
      }
    } catch (e) {
      debugPrint('syncDailyReminderFromSettings failed: $e');
    }
  }

  /// Schedules the check-in reminders for the next week:
  /// - a daily reminder at [hour]:[minute], skipped on days already checked in
  /// - a "streak is about to be lost" warning later that evening, on the day
  ///   the current streak would break
  /// Returns false if the user has not allowed notifications (nothing is
  /// scheduled in that case).
  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await init();
    if (!await requestPermission()) return false;
    await _cancelAllReminders();

    final CheckInService checkin = CheckInService.instance;
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final bool checkedToday = checkin.isInitialized && checkin.isCheckedToday;

    for (int day = 0; day < _daysAhead; day++) {
      if (day == 0 && checkedToday) continue;
      final tz.TZDateTime at = _dayAt(now, day, hour, minute);
      if (!at.isAfter(now)) continue;
      await _schedule(
        _dailyReminderBaseId + day,
        'ถึงเวลาเรียนภาษาอังกฤษแล้ว ! 📚',
        'อย่าลืมเช็คอินวันนี้เพื่อรักษาสตรีคของคุณไว้นะ 🔥',
        at,
        _dailyDetails,
      );
    }

    await _scheduleStreakWarning(checkin, now, hour, minute, checkedToday);
    return true;
  }

  Future<void> _scheduleStreakWarning(
    CheckInService checkin,
    tz.TZDateTime now,
    int reminderHour,
    int reminderMinute,
    bool checkedToday,
  ) async {
    if (!checkin.isInitialized) return;
    final int streak = checkin.currentStreak;
    if (streak <= 0) return;

    // Which day would the streak break on? Today if the user kept it
    // yesterday but hasn't checked in yet; tomorrow if already checked in today.
    final int riskDay;
    if (checkedToday) {
      riskDay = 1;
    } else if (checkin.keptStreakOn(now.subtract(const Duration(days: 1)))) {
      riskDay = 0;
    } else {
      return; // streak already broken; nothing to protect
    }

    // Evening warning: at least 21:00, at least 1 hour after the daily
    // reminder, and no later than 23:30.
    final int reminderMinutes = reminderHour * 60 + reminderMinute;
    int warnMinutes = reminderMinutes + 60;
    if (warnMinutes < 21 * 60) warnMinutes = 21 * 60;
    if (warnMinutes > 23 * 60 + 30) warnMinutes = 23 * 60 + 30;
    if (warnMinutes <= reminderMinutes) return; // reminder is already that late

    final tz.TZDateTime at = _dayAt(
      now,
      riskDay,
      warnMinutes ~/ 60,
      warnMinutes % 60,
    );
    if (!at.isAfter(now)) return;
    await _schedule(
      _streakWarningBaseId + riskDay,
      'สตรีค $streak วันกำลังจะหาย ! 😱',
      'เหลือเวลาอีกไม่นาน เช็คอินก่อนเที่ยงคืนเพื่อรักษาสตรีคไว้นะ 🔥',
      at,
      _streakDetails,
    );
  }

  static tz.TZDateTime _dayAt(
    tz.TZDateTime now,
    int daysFromToday,
    int hour,
    int minute,
  ) {
    final DateTime date = DateTime(now.year, now.month, now.day + daysFromToday);
    return tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  static const NotificationDetails _dailyDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_checkin_channel',
      'แจ้งเตือนเช็คอินประจำวัน',
      channelDescription: 'แจ้งเตือนเช็คอินประจำวัน',
      color: Color(0xFF5BB8F5), // mascot blue
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const NotificationDetails _streakDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'streak_warning_channel',
      'แจ้งเตือนสตรีคใกล้หาย',
      channelDescription: 'เตือนเมื่อยังไม่เช็คอินและสตรีคกำลังจะหาย',
      color: Color(0xFF5BB8F5), // mascot blue
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _schedule(
    int id,
    String title,
    String body,
    tz.TZDateTime at,
    NotificationDetails details,
  ) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      at,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _cancelAllReminders() async {
    for (int day = 0; day < _daysAhead; day++) {
      await _plugin.cancel(_dailyReminderBaseId + day);
    }
    for (int day = 0; day < 2; day++) {
      await _plugin.cancel(_streakWarningBaseId + day);
    }
  }

  Future<void> cancelDailyReminder() async {
    await init();
    await _cancelAllReminders();
  }
}

class DailyWord {
  final String word;
  final String emoji;
  final String thai;
  final String say;
  final String sentence;
  final String sentenceThai;
  const DailyWord(
    this.word,
    this.emoji,
    this.thai,
    this.say,
    this.sentence,
    this.sentenceThai,
  );
}

const List<DailyWord> kWords = [
  DailyWord(
    'apple',
    '🍎',
    'แอปเปิล',
    'แอ๊พ-เปิ้ล',
    'I eat a red apple.',
    'ฉันกินแอปเปิลสีแดง',
  ),
  DailyWord(
    'banana',
    '🍌',
    'กล้วย',
    'บะ-แน้น-นะ',
    'Monkeys love bananas.',
    'ลิงชอบกล้วย',
  ),
  DailyWord(
    'cat',
    '🐱',
    'แมว',
    'แคท',
    'The cat is sleeping.',
    'แมวกำลังนอนหลับ',
  ),
  DailyWord(
    'dog',
    '🐶',
    'สุนัข',
    'ด็อก',
    'My dog can run fast.',
    'สุนัขของฉันวิ่งเร็ว',
  ),
  DailyWord(
    'elephant',
    '🐘',
    'ช้าง',
    'เอ๊ล-ละ-เฟิ่น',
    'The elephant is big.',
    'ช้างตัวใหญ่',
  ),
  DailyWord('fish', '🐟', 'ปลา', 'ฟิช', 'The fish can swim.', 'ปลาว่ายน้ำได้'),
  DailyWord(
    'house',
    '🏠',
    'บ้าน',
    'เฮาส์',
    'This is my house.',
    'นี่คือบ้านของฉัน',
  ),
  DailyWord(
    'ice cream',
    '🍦',
    'ไอศกรีม',
    'ไอซ์-ครีม',
    'I like ice cream.',
    'ฉันชอบไอศกรีม',
  ),
  DailyWord(
    'juice',
    '🧃',
    'น้ำผลไม้',
    'จูส',
    'I drink orange juice.',
    'ฉันดื่มน้ำส้ม',
  ),
  DailyWord(
    'lion',
    '🦁',
    'สิงโต',
    'ไล-เอิ่น',
    'The lion is strong.',
    'สิงโตแข็งแรง',
  ),
  DailyWord(
    'monkey',
    '🐵',
    'ลิง',
    'มั๊ง-คี่',
    'The monkey climbs a tree.',
    'ลิงปีนต้นไม้',
  ),
  DailyWord(
    'moon',
    '🌙',
    'พระจันทร์',
    'มูน',
    'I see the moon.',
    'ฉันเห็นพระจันทร์',
  ),
  DailyWord(
    'rabbit',
    '🐰',
    'กระต่าย',
    'แร๊บ-บิท',
    'The rabbit can jump.',
    'กระต่ายกระโดดได้',
  ),
  DailyWord(
    'rainbow',
    '🌈',
    'รุ้ง',
    'เรน-โบว์',
    'A rainbow is colorful.',
    'รุ้งมีหลากสี',
  ),
  DailyWord(
    'school',
    '🏫',
    'โรงเรียน',
    'สกูล',
    'I go to school.',
    'ฉันไปโรงเรียน',
  ),
  DailyWord(
    'sun',
    '☀️',
    'ดวงอาทิตย์',
    'ซัน',
    'The sun is hot.',
    'ดวงอาทิตย์ร้อน',
  ),
  DailyWord(
    'tiger',
    '🐯',
    'เสือ',
    'ไท-เกอร์',
    'The tiger is orange.',
    'เสือสีส้ม',
  ),
  DailyWord(
    'umbrella',
    '☂️',
    'ร่ม',
    'อัม-เบร็ล-ล่า',
    'I have an umbrella.',
    'ฉันมีร่ม',
  ),
  DailyWord('water', '💧', 'น้ำ', 'วอ-เทอร์', 'I drink water.', 'ฉันดื่มน้ำ'),
  DailyWord('bird', '🐦', 'นก', 'เบิร์ด', 'The bird can fly.', 'นกบินได้'),
  DailyWord(
    'book',
    '📖',
    'หนังสือ',
    'บุ๊ค',
    'I read a book.',
    'ฉันอ่านหนังสือ',
  ),
  DailyWord('car', '🚗', 'รถยนต์', 'คาร์', 'The car is red.', 'รถสีแดง'),
  DailyWord(
    'flower',
    '🌸',
    'ดอกไม้',
    'ฟลาว-เออร์',
    'The flower smells good.',
    'ดอกไม้หอม',
  ),
  DailyWord('tree', '🌳', 'ต้นไม้', 'ทรี', 'The tree is tall.', 'ต้นไม้สูง'),
  DailyWord('star', '⭐', 'ดาว', 'สตาร์', 'I see a star.', 'ฉันเห็นดาว'),
  DailyWord(
    'milk',
    '🥛',
    'นม',
    'มิลค์',
    'I drink milk every day.',
    'ฉันดื่มนมทุกวัน',
  ),
  DailyWord(
    'pencil',
    '✏️',
    'ดินสอ',
    'เพ็น-เซิ่ล',
    'I have a pencil.',
    'ฉันมีดินสอ',
  ),
  DailyWord(
    'butterfly',
    '🦋',
    'ผีเสื้อ',
    'บั๊ท-เทอร์-ฟลาย',
    'The butterfly is pretty.',
    'ผีเสื้อสวย',
  ),
  DailyWord(
    'strawberry',
    '🍓',
    'สตรอว์เบอร์รี',
    'สตรอ-เบอร์-รี่',
    'I like strawberries.',
    'ฉันชอบสตรอว์เบอร์รี',
  ),
  DailyWord(
    'bear',
    '🐻',
    'หมี',
    'แบร์',
    'The bear likes honey.',
    'หมีชอบน้ำผึ้ง',
  ),
];

DailyWord wordForDate(DateTime d) {
  final days =
      DateTime.utc(
        d.year,
        d.month,
        d.day,
      ).difference(DateTime.utc(2024, 1, 1)).inDays;
  return kWords[days % kWords.length];
}

class _Rank {
  final int minDays;
  final String title;
  final String thai;
  final String emoji;
  const _Rank(this.minDays, this.title, this.thai, this.emoji);
}

const List<_Rank> _kRanks = [
  _Rank(0, 'Little Starter', 'นักเรียนหน้าใหม่', '🐣'),
  _Rank(3, 'Word Explorer', 'นักสำรวจคำศัพท์', '🧭'),
  _Rank(7, 'Grammar Hero', 'ฮีโร่ไวยากรณ์', '🦸'),
  _Rank(14, 'English Star', 'ดาวเด่นภาษาอังกฤษ', '⭐'),
  _Rank(30, 'Super Speaker', 'นักพูดสุดเจ๋ง', '🎤'),
  _Rank(100, 'English Master', 'เซียนภาษาอังกฤษ', '👑'),
];

_Rank _rankFor(int streak) {
  var r = _kRanks.first;
  for (final x in _kRanks) {
    if (streak >= x.minDays) r = x;
  }
  return r;
}

const Color _kBlue = Color(0xFF2563EB);
const Color _kInk = Color(0xFF0F172A);
const Color _kSlate = Color(0xFF64748B);
const Color _kOrange = Color(0xFFF97316);
const Color _kPurple = Color(0xFFA855F7);
const Color _kGreen = Color(0xFF22C55E);

BoxDecoration _cardDeco({
  Color color = Colors.white,
  Gradient? gradient,
  Color? border,
}) {
  return BoxDecoration(
    color: gradient == null ? color : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular(30),
    border: border != null ? Border.all(color: border, width: 2.5) : null,
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.13),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  final String emoji;
  final String en;
  final String th;
  final Color tint;
  final Widget? trailing;
  final bool compact;

  const _SectionTitle({
    required this.emoji,
    required this.en,
    required this.th,
    this.tint = _kBlue,
    this.trailing,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double box = compact ? 38 : 46;
    return Row(
      children: [
        Container(
          width: box,
          height: box,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(compact ? 13 : 16),
          ),
          child: Text(emoji, style: TextStyle(fontSize: compact ? 21 : 25)),
        ),
        SizedBox(width: compact ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                en,
                style: TextStyle(
                  fontSize: compact ? 16.5 : 19,
                  fontWeight: FontWeight.w900,
                  color: _kInk,
                ),
              ),
              Text(
                th,
                style: TextStyle(
                  fontSize: compact ? 11.5 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kSlate,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

Widget _pill(String text, Color bg, Color fg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: fg),
    ),
  );
}

class _PulsingEmoji extends StatelessWidget {
  final String emoji;
  final double size;
  const _PulsingEmoji({required this.emoji, required this.size});

  @override
  Widget build(BuildContext context) {
    return Text(emoji, style: TextStyle(fontSize: size));
  }
}

// แก้ไข _CandyButton ให้อยู่นิ่งๆ ไม่เต้นขยายขนาดอัตโนมัติ
class _CandyButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color shadow;
  final VoidCallback? onTap;
  final double vPad;

  const _CandyButton({
    required this.label,
    required this.color,
    required this.shadow,
    required this.onTap,
    this.icon,
    this.vPad = 16,
  });

  @override
  State<_CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<_CandyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: widget.vPad),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: widget.shadow, offset: Offset(0, _down ? 1 : 5)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 26),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// แก้ไข AnimatedCharacter ให้เป็นภาพนิ่ง ไม่ลอยขึ้นลง
class AnimatedCharacter extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  final bool isHappy;

  const AnimatedCharacter({
    super.key,
    required this.imagePath,
    this.width = 70,
    this.height = 50,
    this.isHappy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder:
          (context, error, stackTrace) => SizedBox(
            width: width,
            height: height,
            child: const FittedBox(child: Text('🐼')),
          ),
    );
  }
}

class StreakCalendar extends StatefulWidget {
  final CheckInService service;
  const StreakCalendar({super.key, required this.service});

  @override
  State<StreakCalendar> createState() => _StreakCalendarState();
}

class _StreakCalendarState extends State<StreakCalendar> {
  late DateTime _visibleMonth;

  static const List<String> _thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];
  static const List<String> _weekdayLabels = [
    'อา.',
    'จ.',
    'อ.',
    'พ.',
    'พฤ.',
    'ศ.',
    'ส.',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: _kBlue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingEmpty = firstDayOfMonth.weekday % 7;

    final cells = <Widget>[
      for (int i = 0; i < leadingEmpty; i++) const SizedBox.shrink(),
      for (int d = 1; d <= daysInMonth; d++)
        _DayCell(
          day: d,
          status: widget.service.statusFor(
            DateTime(_visibleMonth.year, _visibleMonth.month, d),
          ),
          isToday: _isSameDay(
            DateTime(_visibleMonth.year, _visibleMonth.month, d),
            DateTime.now(),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navButton(Icons.chevron_left_rounded, () => _changeMonth(-1)),
            Text(
              '${_thaiMonths[_visibleMonth.month - 1]} ${_visibleMonth.year + 543}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: _kInk,
              ),
            ),
            _navButton(Icons.chevron_right_rounded, () => _changeMonth(1)),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final w in _weekdayLabels)
              Center(
                child: Text(
                  w,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ...cells,
          ],
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _LegendItem(color: _kBlue, label: 'เช็คอินแล้ว'),
            _LegendItem(color: _kPurple, label: 'ใช้โล่ป้องกัน'),
            _LegendItem(color: Color(0xFFFCA5A5), label: 'ขาดเช็คอิน'),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final DayStatus status;
  final bool isToday;

  const _DayCell({
    required this.day,
    required this.status,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    Gradient? gradient;
    Color? bg;
    Color fg;
    Widget? icon;

    switch (status) {
      case DayStatus.checked:
        gradient = const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        fg = Colors.white;
        icon = const Icon(Icons.star_rounded, size: 17, color: Colors.white);
        break;
      case DayStatus.shielded:
        bg = const Color(0xFFF3E8FF);
        fg = _kPurple;
        icon = const Icon(Icons.shield_rounded, size: 15, color: _kPurple);
        break;
      case DayStatus.missed:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFFCA5A5);
        icon = null;
        break;
      case DayStatus.future:
        bg = Colors.transparent;
        fg = const Color(0xFFCBD5E1);
        icon = null;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          gradient: gradient,
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: _kOrange, width: 2.5) : null,
        ),
        child: Center(
          child:
              icon ??
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _kSlate,
          ),
        ),
      ],
    );
  }
}

Future<void> showMilestoneDialog(BuildContext context, Milestone milestone) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFBEB), Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: const Color(0xFFFFC107),
                      width: 5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Text(
                          milestone.emoji,
                          style: const TextStyle(fontSize: 62),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ยินดีด้วย! 🎉',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'ยินดีด้วย!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kSlate,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'คุณเช็คอินครบ ${milestone.title} แล้ว',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFFED7AA),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '🎁 ${milestone.rewardDescription}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _CandyButton(
                        label: 'รับรางวัล!',
                        icon: Icons.card_giftcard_rounded,
                        color: _kGreen,
                        shadow: const Color(0xFF15803D),
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}

Future<void> showNotificationSettingsSheet(
  BuildContext context,
  CheckInService service,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _NotificationSettingsSheet(service: service),
  );
}

class _TimePreset {
  final String emoji;
  final String label;
  final int hour;
  final int minute;
  const _TimePreset(this.emoji, this.label, this.hour, this.minute);
}

class _NotificationSettingsSheet extends StatefulWidget {
  final CheckInService service;
  const _NotificationSettingsSheet({required this.service});

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  late bool _enabled;
  late TimeOfDay _time;
  bool _saving = false;

  static const List<_TimePreset> _presets = [
    _TimePreset('', 'ก่อนไปโรงเรียน', 7, 0),
    _TimePreset('', 'หลังเลิกเรียน', 16, 30),
    _TimePreset('', 'ก่อนนอน', 19, 0),
    _TimePreset('', 'เวลาอ่านหนังสือ', 20, 0),
  ];

  @override
  void initState() {
    super.initState();
    _enabled = widget.service.notifEnabled;
    _time = TimeOfDay(
      hour: widget.service.notifHour,
      minute: widget.service.notifMinute,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.service.setNotificationSettings(
      enabled: _enabled,
      hour: _time.hour,
      minute: _time.minute,
    );
    if (_enabled) {
      final bool scheduled = await NotificationService.instance
          .scheduleDailyReminder(hour: _time.hour, minute: _time.minute);
      if (!scheduled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ยังไม่ได้อนุญาตการแจ้งเตือน กรุณาเปิดสิทธิ์ในการตั้งค่าของเครื่อง',
            ),
          ),
        );
      }
    } else {
      await NotificationService.instance.cancelDailyReminder();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                emoji: '🔔',
                en: 'ตั้งการแจ้งเตือนรายวัน',
                th: 'แจ้งเตือนให้เราเช็คอินทุกวัน',
                tint: _kOrange,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  activeColor: _kBlue,
                  title: const Text(
                    'เปิดการแจ้งเตือน',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ),
              if (_enabled) ...[
                const SizedBox(height: 16),
                const Text(
                  'เลือกเวลาที่เหมาะกับเรา',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _kInk),
                ),
                const SizedBox(height: 10),
                Column(
                  children: [
                    for (int i = 0; i < _presets.length; i += 2) ...[
                      if (i > 0) const SizedBox(height: 10),
                      Row(
                        children: [
                          for (int j = i; j < i + 2; j++) ...[
                            if (j > i) const SizedBox(width: 10),
                            if (j < _presets.length)
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final p = _presets[j];
                                    final isSelected =
                                        _time.hour == p.hour &&
                                        _time.minute == p.minute;
                                    return GestureDetector(
                                      onTap:
                                          () => setState(
                                            () =>
                                                _time = TimeOfDay(
                                                  hour: p.hour,
                                                  minute: p.minute,
                                                ),
                                          ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color:
                                              isSelected
                                                  ? _kBlue
                                                  : const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Text(
                                          '${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')}  ${p.label}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : _kBlue,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_rounded, color: _kBlue),
                  title: const Text(
                    'ตั้งเวลาเอง',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: Text(
                    _time.format(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _kBlue,
                      fontSize: 16,
                    ),
                  ),
                  onTap: _pickTime,
                ),
              ],
              const SizedBox(height: 14),
              _CandyButton(
                label: _saving ? 'กำลังบันทึก...' : 'บันทึก',
                icon: Icons.check_rounded,
                color: _kBlue,
                shadow: const Color(0xFF1D4ED8),
                onTap: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  int currentIndex = 1;

  final CheckInService _service = CheckInService.instance;
  bool _showMonthlyCalendar = false;
  final Set<String> _wrongPicks = {};
  String? _quizMsg;

  static const List<String> _weekdayShort = [
    'จ.',
    'อ.',
    'พ.',
    'พฤ.',
    'ศ.',
    'ส.',
    'อา.',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // No loading screen: the page shows straight away and fills in
    // (streak, calendar, ...) as soon as the server answers.
    await _service.init(force: true);
    if (mounted) setState(() {});
    if (_service.notifEnabled) {
      try {
        await NotificationService.instance.scheduleDailyReminder(
          hour: _service.notifHour,
          minute: _service.notifMinute,
        );
      } catch (e) {
        debugPrint('scheduleDailyReminder failed: $e');
      }
    }
  }

  void _toast(
    String text,
    IconData icon,
    Color bg, {
    Color iconColor = Colors.white,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: bg,
        duration: const Duration(milliseconds: 2400),
        content: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCheckIn() async {
    final result = await _service.checkIn();
    if (!mounted) return;

    if (result.alreadyCheckedToday) {
      setState(() {});
      _toast(
        'วันนี้คุณเช็คอินไปแล้ว 🙂',
        Icons.info_outline_rounded,
        const Color(0xFF1E293B),
      );
      return;
    }

    if (!result.success) {
      _toast(
        result.errorMessage ?? 'เช็คอินไม่สำเร็จ ลองใหม่อีกครั้งนะ',
        Icons.wifi_off_rounded,
        const Color(0xFFDC2626),
      );
      return;
    }

    if (result.success) {
      setState(() {});
      _toast(
        'เช็คอินสำเร็จแล้ว ! ${result.newStreak} วันติดต่อกัน',
        Icons.stars_rounded,
        const Color(0xFF16A34A),
        iconColor: Colors.amber,
      );

      if (result.milestoneReached != null) {
        await showMilestoneDialog(context, result.milestoneReached!);
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _answerQuiz(DailyWord picked, DailyWord target) async {
    if (picked.word == target.word) {
      final saved = await _service.completeQuiz();
      if (!mounted) return;
      if (!saved) {
        // Correct answer, but it wasn't saved: no confetti, let them retry.
        _toast(
          'ตอบถูกแล้ว แต่บันทึกไม่สำเร็จ ลองกดคำตอบอีกครั้งนะ',
          Icons.wifi_off_rounded,
          const Color(0xFFDC2626),
        );
        return;
      }
      setState(() {
        _quizMsg = null;
      });
    } else {
      setState(() {
        _wrongPicks.add(picked.word);
        _quizMsg = 'ลองอีกครั้งนะ สู้ๆ! 💪';
      });
    }
  }

  Widget _buildHeader() {
    final h = DateTime.now().hour;
    final greetingTh =
        h < 12 ? 'สวัสดีตอนเช้า' : (h < 17 ? 'สวัสดีตอนบ่าย' : 'สวัสดีตอนเย็น');
    final sun = h < 12 ? '☀️' : (h < 17 ? '🌤️' : '🌙');
    final checked = _service.isCheckedToday;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 8,
        18,
        18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '📅 เช็คอิน',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap:
                          () =>
                              showNotificationSettingsSheet(context, _service),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greetingTh,',
                            style: const TextStyle(
                              color: Color(0xFFDBEAFE),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_service.userName} $sun',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              checked
                                  ? '$greetingTh · วันนี้ทำสำเร็จแล้ว !'
                                  : '$greetingTh · พร้อมเรียนรู้กันหรือยัง ?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                          width: 2.5,
                        ),
                      ),
                      child: AnimatedCharacter(
                        imagePath: "assets/images/character/normal.png",
                        width: 62,
                        height: 62,
                        isHappy: checked,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String emoji, String value, String label, Color tint) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: tint,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _kSlate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    final streak = _service.currentStreak;
    final rank = _rankFor(streak);
    Milestone? next;
    for (final m in kMilestones) {
      if (streak < m.days) {
        next = m;
        break;
      }
    }
    final progress =
        next == null ? 1.0 : (streak / next.days).clamp(0.0, 1.0).toDouble();
    final left = next == null ? 0 : next.days - streak;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: const Color(0xFFFFEDD5),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          _kOrange,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _PulsingEmoji(emoji: '🔥', size: 20),
                        Text(
                          '$streak',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFEA580C),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'เรียนติดต่อกัน',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: _kInk,
                        height: 1.15,
                      ),
                    ),
                    const Text(
                      'วันที่เรียนติดต่อกัน',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _kSlate,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${rank.emoji} ${rank.thai}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _kBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      next == null
                          ? '🏆 ครบทุกเป้าหมายแล้ว!'
                          : 'อีก $left วัน ถึง ${next.emoji} ${next.days} วัน',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _kOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile(
                '🏆',
                '${_service.longestStreak}',
                'สถิติสูงสุด',
                const Color(0xFFD97706),
              ),
              _statTile(
                '🛡️',
                '${_service.shieldCount}',
                'โล่ป้องกัน',
                _kPurple,
              ),
              _statTile(
                '📚',
                '${_service.wordsLearned}',
                'คำที่เรียนแล้ว',
                _kBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStampCard() {
    final today = DateTime.now();
    final last7Days = List.generate(
      7,
      (i) => DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - i)),
    );
    final doneCount =
        last7Days
            .where((d) => _service.statusFor(d) == DayStatus.checked)
            .length;
    final checked = _service.isCheckedToday;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            compact: true,
            emoji: '🗓️',
            en: 'สมุดแสตมป์',
            th: 'สมุดแสตมป์ 7 วันล่าสุด',
            tint: _kBlue,
            trailing: _pill('$doneCount / 7', const Color(0xFFEFF6FF), _kBlue),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final day = last7Days[index];
              final status = _service.statusFor(day);
              final isChecked = status == DayStatus.checked;
              final isShielded = status == DayStatus.shielded;
              final isToday = index == 6;

              return Column(
                children: [
                  Text(
                    _weekdayShort[(day.weekday - 1) % 7],
                    style: TextStyle(
                      color:
                          isToday
                              ? _kOrange
                              : (isChecked ? _kBlue : const Color(0xFF94A3B8)),
                      fontSize: 11.5,
                      fontWeight:
                          isToday || isChecked
                              ? FontWeight.w900
                              : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          isChecked
                              ? const LinearGradient(
                                colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      color:
                          isChecked
                              ? null
                              : isShielded
                              ? const Color(0xFFF3E8FF)
                              : isToday
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFF1F5F9),
                      border:
                          isToday && !isChecked
                              ? Border.all(color: _kOrange, width: 2.5)
                              : null,
                      boxShadow:
                          isChecked
                              ? [
                                BoxShadow(
                                  color: _kBlue.withValues(alpha: 0.35),
                                  blurRadius: 7,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                              : null,
                    ),
                    child: Center(
                      child: Icon(
                        isChecked
                            ? Icons.star_rounded
                            : isShielded
                            ? Icons.shield_rounded
                            : isToday
                            ? Icons.local_fire_department_rounded
                            : Icons.circle_outlined,
                        color:
                            isChecked
                                ? Colors.white
                                : isShielded
                                ? _kPurple
                                : isToday
                                ? _kOrange
                                : const Color(0xFFCBD5E1),
                        size: isChecked ? 22 : 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          _CandyButton(
            vPad: 13,
            label: checked ? 'เช็คอินแล้ววันนี้' : 'เช็คอินเลย',
            icon:
                checked ? Icons.check_circle_rounded : Icons.touch_app_rounded,
            color: checked ? _kGreen : _kBlue,
            shadow: checked ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
            onTap: checked ? null : _handleCheckIn,
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap:
                () => setState(
                  () => _showMonthlyCalendar = !_showMonthlyCalendar,
                ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showMonthlyCalendar
                        ? "ซ่อนปฏิทินรายเดือน"
                        : "ดูปฏิทินรายเดือน",
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _kBlue,
                    ),
                  ),
                  Icon(
                    _showMonthlyCalendar
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _kBlue,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child:
                _showMonthlyCalendar
                    ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: StreakCalendar(service: _service),
                    )
                    : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _missionRow(String emoji, String en, String th, bool done) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  en,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _kInk,
                  ),
                ),
                Text(
                  th,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kSlate,
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? _kGreen : Colors.white,
              border: Border.all(
                color: done ? _kGreen : const Color(0xFFCBD5E1),
                width: 2.5,
              ),
            ),
            child:
                done
                    ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    )
                    : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard() {
    final checked = _service.isCheckedToday;
    final quiz = _service.isQuizDoneToday;
    final done = (checked ? 1 : 0) + (quiz ? 1 : 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            emoji: '🎯',
            en: 'ภารกิจวันนี้',
            th: 'ทำเช็คอินและควิซให้ครบเพื่อรักษาสตรีค',
            tint: _kGreen,
            trailing: _pill(
              '$done / 2',
              const Color(0xFFF0FDF4),
              const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: done / 2),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder:
                  (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 14,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
                  ),
            ),
          ),
          _missionRow(
            '✅',
            'เช็คอินวันนี้',
            'บันทึกการเข้าเรียนประจำวัน',
            checked,
          ),
          _missionRow('🧩', 'ควิซคำศัพท์', 'ตอบคำถามคำศัพท์ให้ถูก', quiz),
          if (done == 2) ...[
            const SizedBox(height: 12),
            Center(
              child: _pill(
                'ทำภารกิจวันนี้ครบแล้ว !',
                const Color(0xFFFFF7ED),
                const Color(0xFFEA580C),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWordCard() {
    final checked = _service.isCheckedToday;
    final w = wordForDate(DateTime.now());

    final Widget body =
        checked
            ? Container(
              key: const ValueKey('word_open'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFDE68A), width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          w.emoji,
                          style: const TextStyle(fontSize: 52),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                w.word,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: _kBlue,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _pill(
                              w.say,
                              const Color(0xFFF3E8FF),
                              const Color(0xFF7E22CE),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              w.thai,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: _kInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.sentence,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: _kInk,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                w.sentenceThai,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _kSlate,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            : Container(
              key: const ValueKey('word_locked'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE2E8F0), Color(0xFFF1F5F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 46)),
                  const SizedBox(height: 6),
                  const Text(
                    '? ? ? ? ?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _pill(
                    'เช็คอินเพื่อเปิดคำศัพท์วันนี้',
                    Colors.white,
                    _kSlate,
                  ),
                ],
              ),
            );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            emoji: '🌟',
            en: 'คำศัพท์ประจำวัน',
            th: 'เรียนรู้คำศัพท์ใหม่ในแต่ละวัน',
            tint: const Color(0xFFF59E0B),
            trailing:
                checked
                    ? _pill(
                      'ใหม่',
                      const Color(0xFFFFF7ED),
                      const Color(0xFFEA580C),
                    )
                    : null,
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            transitionBuilder:
                (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCard() {
    final checked = _service.isCheckedToday;
    final quizDone = _service.isQuizDoneToday;
    final now = DateTime.now();
    final target = wordForDate(now);

    final r = Random(now.year * 10000 + now.month * 100 + now.day);
    final others = List<DailyWord>.from(kWords)
      ..removeWhere((x) => x.word == target.word);
    others.shuffle(r);
    final options = <DailyWord>[target, others[0], others[1]]..shuffle(r);

    Widget content;
    if (!checked) {
      content = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Column(
          children: [
            Text('🔒', style: TextStyle(fontSize: 34)),
            SizedBox(height: 6),
            Text(
              'เช็คอินก่อน แล้วมาเล่นควิซกันนะ',
              style: TextStyle(fontWeight: FontWeight.w800, color: _kSlate),
            ),
          ],
        ),
      );
    } else if (quizDone) {
      content = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFBBF7D0), width: 2),
        ),
        child: Column(
          children: [
            Text(target.emoji, style: const TextStyle(fontSize: 46)),
            const SizedBox(height: 6),
            const Text(
              'เก่งมาก !',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF15803D),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'ตอบถูกแล้ว ${target.word} แปลว่า ${target.thai}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF166534),
              ),
            ),
            const SizedBox(height: 8),
            _pill(
              'เรียนรู้แล้วทั้งหมด ${_service.wordsLearned} คำ',
              Colors.white,
              const Color(0xFF15803D),
            ),
          ],
        ),
      );
    } else {
      content = Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  'รูปไหนตรงกับคำว่า ${target.word} ?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _kBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'อันไหนคือคำว่า ${target.word} ? แตะรูปที่ถูกต้องเลย',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kSlate,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final o in options)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: GestureDetector(
                      onTap:
                          _wrongPicks.contains(o.word)
                              ? null
                              : () => _answerQuiz(o, target),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                _wrongPicks.contains(o.word)
                                    ? const Color(0xFFFEE2E2)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  _wrongPicks.contains(o.word)
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFFBFDBFE),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    _wrongPicks.contains(o.word)
                                        ? Colors.transparent
                                        : const Color(0xFFBFDBFE),
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Opacity(
                            opacity: _wrongPicks.contains(o.word) ? 0.4 : 1.0,
                            child: Text(
                              o.emoji,
                              style: const TextStyle(fontSize: 46),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_quizMsg != null) ...[
            const SizedBox(height: 10),
            Text(
              _quizMsg!,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            emoji: '🧩',
            en: 'ควิซทายคำศัพท์',
            th: 'ตอบคำถามจากคำศัพท์ประจำวัน',
            tint: _kPurple,
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }

  Widget _roadNode(Milestone m, bool reached) {
    return SizedBox(
      width: 66,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  reached
                      ? const LinearGradient(
                        colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
              color: reached ? null : const Color(0xFFE2E8F0),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow:
                  reached
                      ? [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                      : null,
            ),
            child: Opacity(
              opacity: reached ? 1.0 : 0.4,
              child: Text(m.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${m.days} วัน',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: reached ? _kInk : _kSlate,
            ),
          ),
          const Text(
            '🛡️ +1',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _kPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardRoad() {
    final streak = _service.currentStreak;
    final claimed = _service.claimedMilestones;
    Milestone? next;
    for (final m in kMilestones) {
      if (streak < m.days) {
        next = m;
        break;
      }
    }

    final row = <Widget>[];
    for (int i = 0; i < kMilestones.length; i++) {
      final m = kMilestones[i];
      row.add(_roadNode(m, streak >= m.days || claimed.contains(m.days)));
      if (i < kMilestones.length - 1) {
        final a = m.days;
        final b = kMilestones[i + 1].days;
        final frac = ((streak - a) / (b - a)).clamp(0.0, 1.0).toDouble();
        row.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 9,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(_kOrange),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            emoji: '🗺️',
            en: 'เส้นทางสู่รางวัล',
            th: 'สะสมวันเรียนเพื่อรับโล่ป้องกัน',
            tint: _kOrange,
          ),
          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: row),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFED7AA), width: 2),
            ),
            child: Text(
              next == null
                  ? 'สุดยอด ! คุณเก็บรางวัลครบทุกขั้นแล้ว'
                  : 'เป้าหมายถัดไป เรียน ${next.title}\n${next.rewardDescription}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEA580C),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheer() {
    final checked = _service.isCheckedToday;
    final quiz = _service.isQuizDoneToday;
    final msg =
        checked && quiz
            ? 'ทำได้ครบทุกอย่างแล้ว ! \nวันนี้เก่งมาก พรุ่งนี้มาเรียนกันต่อ'
            : checked
            ? 'เยี่ยมเลย อีกหนึ่งวันที่ทำสำเร็จ ! \nลองตอบควิซคำศัพท์ดู'
            : 'อย่าลืมเช็คอินวันนี้\nเพื่อรักษาสตรีคของคุณ';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Column(
        children: [
          AnimatedCharacter(
            imagePath: "assets/images/character/bravo.png",
            width: 96,
            height: 72,
            isHappy: checked,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _kBlue.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNav() {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF4D7CFE),
      unselectedItemColor: const Color(0xFF94A3B8),
      onTap: (index) {
        if (index == currentIndex) return;

        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }

        if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SettingScreen()),
          );
        }

        if (index == 3) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: "หน้าหลัก",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.fact_check_outlined),
          label: "เช็คอิน",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: "ตั้งค่า",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: "โปรไฟล์",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FF),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEAF4FF), Color(0xFFFFF8EC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  child: Column(
                    children: [
                      _buildStreakCard(),
                      gap,
                      _buildStampCard(),
                      gap,
                      _buildMissionCard(),
                      gap,
                      _buildWordCard(),
                      gap,
                      _buildQuizCard(),
                      gap,
                      _buildRewardRoad(),
                      gap,
                      _buildCheer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNav(),
    );
  }
}
