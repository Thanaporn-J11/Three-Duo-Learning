import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';
import 'checkin_screen.dart';
import '../services/account_settings_sync.dart';
import '../services/app_version.dart';
import '../services/parent_pin.dart';
import '../services/screen_time_guard.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/parent_pin_prompt.dart';
import 'setting/learning_report_sheet.dart';
import '../services/user_account_preferences.dart';
import 'profile_screen.dart'; // มี AvatarProfile, AvatarPainter, kSkinTones, kHairColors, kMaleOutfits, kFemaleOutfits
import 'setting/security_screen.dart';
import 'setting/about_screen.dart';
import 'welcome_screen.dart';
import '../config/api_config.dart';
import '../services/sfx.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  int currentIndex = 2;

  // State สำหรับตัวเลือกการแจ้งเตือน
  bool isNotificationEnabled = true;

  // State สำหรับการตั้งค่าผู้ปกครอง (บันทึกผ่าน SharedPreferences)
  bool isScreenTimeEnabled = false;
  int dailyTimeLimitMinutes = 30; // 15, 30, 45, 60 นาที
  bool isEyeRestReminderEnabled = true;

  String _userName = 'กำลังโหลด...';
  String _userEmail = '';
  bool _isLoadingUser = false;
  String _appVersion = '';

  // State สำหรับ Downtime / Bedtime Schedule
  bool isDowntimeEnabled = false;
  TimeOfDay downtimeStart = const TimeOfDay(hour: 20, minute: 0); // 20:00 น.
  TimeOfDay downtimeEnd = const TimeOfDay(hour: 7, minute: 0); // 07:00 น.

  // ---------- สีธีม ----------
  static const Color _bg = Color(0xFFF4F8FF);
  static const Color _ink = Color(0xFF26314F);
  static const Color _brand = Color(0xFF4D7CFE);
  static const Color _border = Color(0xFFDCE9FF);

  @override
  void initState() {
    super.initState();

    _loadNotificationState();
    _loadParentalSettings();
    // Then the copy saved with the account (another phone may have changed it).
    AccountSettingsSync.pull().then((_) {
      if (!mounted) return;
      _loadParentalSettings();
      _loadNotificationState();
    });
    _loadCurrentUser();
    AppVersion.number().then((v) {
      if (mounted) setState(() => _appVersion = v);
    });

    // โหลดข้อมูลอวตารเดิม
    AvatarProfile.instance.load();
  }

  Future<void> _loadNotificationState() async {
    await CheckInService.instance.init();
    // Re-read the saved choice (it may have just come from the server).
    final saved = await CheckInService.readNotificationSettings(
      await SharedPreferences.getInstance(),
    );
    CheckInService.instance
      ..notifEnabled = saved.enabled
      ..notifHour = saved.hour
      ..notifMinute = saved.minute;
    if (mounted) {
      setState(() {
        isNotificationEnabled = CheckInService.instance.notifEnabled;
      });
    }
  }

  Future<void> _loadParentalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        isScreenTimeEnabled =
            prefs.getBool('parent_screen_time_enabled') ?? false;
        dailyTimeLimitMinutes = prefs.getInt('parent_daily_time_limit') ?? 30;
        isEyeRestReminderEnabled =
            prefs.getBool('parent_eye_rest_enabled') ?? true;

        isDowntimeEnabled = prefs.getBool('parent_downtime_enabled') ?? false;
        final startH = prefs.getInt('parent_downtime_start_h') ?? 20;
        final startM = prefs.getInt('parent_downtime_start_m') ?? 0;
        final endH = prefs.getInt('parent_downtime_end_h') ?? 7;
        final endM = prefs.getInt('parent_downtime_end_m') ?? 0;

        downtimeStart = TimeOfDay(hour: startH, minute: startM);
        downtimeEnd = TimeOfDay(hour: endH, minute: endM);
      });
    }
  }

  Future<void> _saveParentalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('parent_screen_time_enabled', isScreenTimeEnabled);
    await prefs.setInt('parent_daily_time_limit', dailyTimeLimitMinutes);
    await prefs.setBool('parent_eye_rest_enabled', isEyeRestReminderEnabled);

    await prefs.setBool('parent_downtime_enabled', isDowntimeEnabled);
    await prefs.setInt('parent_downtime_start_h', downtimeStart.hour);
    await prefs.setInt('parent_downtime_start_m', downtimeStart.minute);
    await prefs.setInt('parent_downtime_end_h', downtimeEnd.hour);
    await prefs.setInt('parent_downtime_end_m', downtimeEnd.minute);
    // Keep them with the account too (survives reinstalling / other phones).
    AccountSettingsSync.pushControls();
  }

  Future<void> _toggleNotification(bool val) async {
    setState(() {
      isNotificationEnabled = val;
    });

    final service = CheckInService.instance;
    await service.setNotificationSettings(
      enabled: val,
      hour: service.notifHour,
      minute: service.notifMinute,
    );

    if (val) {
      final bool scheduled = await NotificationService.instance
          .scheduleDailyReminder(
            hour: service.notifHour,
            minute: service.notifMinute,
          );
      if (!scheduled) {
        // Permission denied: switch back off so the UI doesn't lie.
        await service.setNotificationSettings(
          enabled: false,
          hour: service.notifHour,
          minute: service.notifMinute,
        );
        if (!mounted) return;
        setState(() => isNotificationEnabled = false);
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
  }

  Future<void> _loadCurrentUser() async {
    if (_isLoadingUser) return;
    _isLoadingUser = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        if (!mounted) return;

        setState(() {
          _userName = 'กรุณาเข้าสู่ระบบ';
          _userEmail = '';
        });
        return;
      }

      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/profile'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('โหลดข้อมูลผู้ใช้ไม่สำเร็จ');
      }

      final data = jsonDecode(response.body);
      final profile = data['profile'];

      if (profile is! Map) {
        throw Exception('รูปแบบข้อมูลโปรไฟล์ไม่ถูกต้อง');
      }

      if (!mounted) return;

      setState(() {
        _userName =
            (profile['name'] as String?)?.trim().isNotEmpty == true
                ? (profile['name'] as String).trim()
                : 'ผู้ใช้งาน';

        _userEmail = (profile['email'] as String?)?.trim() ?? '';
      });
    } catch (e) {
      debugPrint('Load current user error: $e');

      if (!mounted) return;

      setState(() {
        _userName = 'ไม่สามารถโหลดข้อมูลได้';
        _userEmail = '';
      });
    } finally {
      _isLoadingUser = false;
    }
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
    // The name may have been edited on the profile page.
    if (mounted) _loadCurrentUser();
  }

  // ============================================================
  // 🔑 PARENTAL GATE (ระบบรหัสผ่าน PIN 4 หลัก)
  // ============================================================

  /// ตรวจสอบ PIN และปลดล็อกโหมดผู้ปกครอง
  Future<void> _showParentGate(
    BuildContext context, {
    required VoidCallback onSuccess,
  }) async {
    final hasPin = await ParentPin.hasPin();

    if (!context.mounted) return;

    if (!hasPin) {
      _showSetupPinDialog(context, onPinCreated: onSuccess);
    } else {
      _showEnterPinDialog(context, onSuccess: onSuccess);
    }
  }

  /// Dialog ตั้งรหัส PIN ครั้งแรก
  void _showSetupPinDialog(
    BuildContext context, {
    required VoidCallback onPinCreated,
  }) {
    final controller = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: _border, width: 2.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: _brand, size: 26),
                SizedBox(width: 10),
                Text(
                  "ตั้งรหัส PIN ผู้ปกครอง",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: _ink,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ตั้งรหัสผ่าน PIN 4 ตัวเลข เพื่อป้องกันไม่ให้เด็กแอบเปลี่ยนการตั้งค่า",
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: _ink,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "••••",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      letterSpacing: 8,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _border, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _brand, width: 2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "ยืนยันรหัส PIN อีกครั้ง",
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: _ink,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "••••",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      letterSpacing: 8,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _border, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _brand, width: 2.5),
                    ),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "ยกเลิก",
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  final pin = controller.text.trim();
                  final confirmPin = confirmController.text.trim();

                  if (pin.length != 4 || int.tryParse(pin) == null) {
                    _showToast("กรุณากรอกรหัส PIN เป็นตัวเลข 4 หลัก");
                    return;
                  }

                  if (pin != confirmPin) {
                    _showToast("รหัส PIN ยืนยันไม่ตรงกัน");
                    return;
                  }

                  // Stored as a salted hash, never as the PIN itself.
                  await ParentPin.setPin(pin);

                  if (ctx.mounted) Navigator.pop(ctx);
                  _showToast("บันทึกรหัส PIN ผู้ปกครองสำเร็จ !");
                  onPinCreated();
                },
                child: const Text(
                  "ตั้งรหัสผ่าน",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  /// Dialog กรอกรหัส PIN ยืนยันเข้าใช้งาน
  void _showEnterPinDialog(
    BuildContext context, {
    required VoidCallback onSuccess,
  }) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: _border, width: 2.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock_person_rounded, color: _brand, size: 26),
                SizedBox(width: 10),
                Text(
                  "ยืนยันรหัส PIN ผู้ปกครอง",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: _ink,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ใส่รหัส PIN 4 หลักเพื่อเข้าสู่โหมดผู้ปกครอง:",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                    color: _ink,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "••••",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade300,
                      letterSpacing: 10,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _border, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _brand, width: 2.5),
                    ),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      // Only someone who knows the account password (the
                      // parent) may reset the PIN.
                      final verified = await showAccountPasswordPrompt(context);
                      if (!verified || !mounted) return;
                      await ParentPin.clear();
                      if (!context.mounted) return;
                      _showSetupPinDialog(context, onPinCreated: onSuccess);
                    },
                    child: const Text(
                      "ลืมรหัส PIN ?",
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "ยกเลิก",
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      final result = await ParentPin.verify(
                        controller.text.trim(),
                      );
                      switch (result) {
                        case PinCheck.ok:
                          if (ctx.mounted) Navigator.pop(ctx);
                          onSuccess();
                        case PinCheck.wrong:
                          controller.clear();
                          _showToast("รหัส PIN ไม่ถูกต้อง ลองใหม่อีกครั้ง");
                        case PinCheck.locked:
                          controller.clear();
                          _showToast(
                            "ใส่ PIN ผิดหลายครั้ง กรุณารอ 1 นาทีแล้วลองใหม่",
                          );
                      }
                    },
                    child: const Text(
                      "ยืนยัน",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  // ============================================================
  // 📊 PARENT FEATURE SHEETS (หน้าทำงานจริงสำหรับผู้ปกครอง)
  // ============================================================

  /// 📊 1. การรายงานผลการเรียนรู้ (Learning Progress & Analytics)
  void _openLearningReportSheet(BuildContext context) {
    // Real data from the server + usage time counted on this device.
    showLearningReportSheet(context);
  }

  /// ⏰ 2. การควบคุมการใช้งานและระยะเวลา (Time Management Sheet)
  void _openScreenTimeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setSheetState) => Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Text(
                              "การควบคุมเวลา",
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "ตั้งค่าจำกัดเวลาเรียน และช่วงเวลาห้ามเข้าใช้งาน",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 2.1 Daily Screen Time Limit
                        const Text(
                          "จำกัดเวลาเรียน",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFF22C55E),
                          title: const Text(
                            "เปิดใช้งานการจำกัดเวลาต่อวัน",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: _ink,
                            ),
                          ),
                          subtitle: Text(
                            isScreenTimeEnabled
                                ? "เมื่อครบกำหนด แอปจะล็อกเข้าสู่โหมดพักผ่อนโดยอัตโนมัติ"
                                : "ปิดการจำกัดเวลา",
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          value: isScreenTimeEnabled,
                          onChanged: (val) {
                            setSheetState(() => isScreenTimeEnabled = val);
                            setState(() {});
                            _saveParentalSettings();
                          },
                        ),

                        if (isScreenTimeEnabled) ...[
                          const SizedBox(height: 8),
                          const Text(
                            "เลือกระยะเวลาเรียนต่อวัน:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            children:
                                [15, 30, 45, 60].map((mins) {
                                  final isSel = dailyTimeLimitMinutes == mins;
                                  return ChoiceChip(
                                    label: Text("$mins นาที"),
                                    selected: isSel,
                                    selectedColor: const Color(0xFFF59E0B),
                                    labelStyle: TextStyle(
                                      color: isSel ? Colors.white : _ink,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    onSelected: (sel) {
                                      if (sel) {
                                        setSheetState(
                                          () => dailyTimeLimitMinutes = mins,
                                        );
                                        setState(() {});
                                        _saveParentalSettings();
                                      }
                                    },
                                  );
                                }).toList(),
                          ),
                        ],

                        const SizedBox(height: 4),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFF22C55E),
                          title: const Text(
                            "เตือนพักสายตาทุก 20 นาที",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: _ink,
                            ),
                          ),
                          subtitle: const Text(
                            "ให้มองไกล ๆ 20 วินาที เมื่อใช้แอปต่อเนื่อง 20 นาที",
                            style: TextStyle(fontSize: 11.5),
                          ),
                          value: isEyeRestReminderEnabled,
                          onChanged: (val) {
                            setSheetState(() => isEyeRestReminderEnabled = val);
                            setState(() {});
                            _saveParentalSettings();
                          },
                        ),

                        const Divider(height: 32),

                        // 2.2 Bedtime / Downtime Schedule
                        const Text(
                          "เวลาเปิด-ปิดแอป",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFF22C55E),
                          title: const Text(
                            "เปิดใช้งานช่วงเวลาห้ามเข้าใช้งาน",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: _ink,
                            ),
                          ),
                          subtitle: const Text(
                            "ป้องกันเด็กแอบเล่นแอปช่วงดึกหรือตื่นนอน",
                            style: TextStyle(fontSize: 11.5),
                          ),
                          value: isDowntimeEnabled,
                          onChanged: (val) {
                            setSheetState(() => isDowntimeEnabled = val);
                            setState(() {});
                            _saveParentalSettings();
                          },
                        ),

                        if (isDowntimeEnabled) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimePickerTile(
                                  context,
                                  label: "เริ่มปิดแอป (ห้ามเล่น)",
                                  time: downtimeStart,
                                  onPick: (picked) {
                                    setSheetState(() => downtimeStart = picked);
                                    setState(() {});
                                    _saveParentalSettings();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTimePickerTile(
                                  context,
                                  label: "เปิดให้เล่นอีกครั้ง",
                                  time: downtimeEnd,
                                  onPick: (picked) {
                                    setSheetState(() => downtimeEnd = picked);
                                    setState(() {});
                                    _saveParentalSettings();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _saveParentalSettings();
                              _showToast(
                                "บันทึกการตั้งค่าเวลาใช้งานเรียบร้อยแล้ว",
                              );
                              // Apply the new limits right away.
                              ScreenTimeGuard.instance.checkNow();
                            },
                            child: const Text(
                              "บันทึกการตั้งค่า",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildTimePickerTile(
    BuildContext context, {
    required String label,
    required TimeOfDay time,
    required Function(TimeOfDay) onPick,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: _brand),
                const SizedBox(width: 6),
                Text(
                  time.format(context),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 📲 3. Dialog แนะนำวิธีตั้งค่าล็อกไม่ให้ออกจากแอป
  void _showKioskGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: _border, width: 2.5),
            ),
            title: const Row(
              children: [
                Text(
                  "โหมดป้องกันการออกจากแอป",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: _ink,
                  ),
                ),
              ],
            ),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "เพื่อไม่ให้เด็กสลับไปใช้งานแอปอื่น คุณสามารถเปิดใช้งานฟังก์ชันของระบบมือถือได้ดังนี้",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    "📱 สำหรับ iOS",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: _ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "1. ไปที่ Setting > Accessibility > Guided Access",
                    style: TextStyle(fontSize: 12.5, color: _ink),
                  ),
                  Text(
                    "2. เปิดใช้งาน และตั้งรหัสผ่าน",
                    style: TextStyle(fontSize: 12.5, color: _ink),
                  ),
                  Text(
                    "3. เมื่ออยู่ในแอปนี้ ให้กดปุ่ม Power 3 ครั้งเพื่อเปิดโหมดล็อก",
                    style: TextStyle(fontSize: 12.5, color: _ink),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "🤖 สำหรับ Android",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: _ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "1. ไปที่ การตั้งค่า > ความปลอดภัย > การตรึงแอป (App Pinning)",
                    style: TextStyle(fontSize: 12.5, color: _ink),
                  ),
                  Text(
                    "2. เปิดใช้งานระบบ ' ตรึงแอป '",
                    style: TextStyle(fontSize: 12.5, color: _ink),
                  ),
                  Text(
                    "3. กดปุ่ม Recent Apps แล้วเลือก ' ปักหมุด / ตรึง ' บนหน้าจอแอปนี้",
                    style: TextStyle(fontSize: 12.5, color: _ink),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "เข้าใจแล้ว",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================
  Widget _buildAvatar(double size) {
    return AnimatedBuilder(
      animation: AvatarProfile.instance,
      builder: (context, _) {
        final AvatarProfile p = AvatarProfile.instance;
        final List<OutfitItem> outfits =
            p.gender == 'male' ? kMaleOutfits : kFemaleOutfits;
        final int outfitIdx =
            p.outfitIndex >= 0 && p.outfitIndex < outfits.length
                ? p.outfitIndex
                : 0;
        final int skinIdx = p.skinIndex.clamp(0, kSkinTones.length - 1).toInt();
        final int hairIdx =
            p.hairColorIndex.clamp(0, kHairColors.length - 1).toInt();

        final String signature =
            '${p.gender}-${p.skinIndex}-${p.hairStyle}-${p.hairColorIndex}-$outfitIdx-${p.glasses}-${p.hat}-${p.clip}-${p.earring}-${p.neck}-${p.extra}';

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder:
              (child, animation) => ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
          child: SizedBox(
            key: ValueKey(signature),
            width: size,
            height: size,
            child: ClipOval(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFBFE3FF), Color(0xFFEAF6FF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Transform.scale(
                  scale: 1.0,
                  alignment: const Alignment(0, 0.00),
                  child: CustomPaint(
                    painter: AvatarPainter(
                      gender: p.gender,
                      skinColor: kSkinTones[skinIdx],
                      hairStyle: p.hairStyle,
                      hairColor: kHairColors[hairIdx],
                      outfit: outfits[outfitIdx],
                      glassesStyle: p.glasses,
                      hatStyle: p.hat,
                      clipStyle: p.clip,
                      earringStyle: p.earring,
                      neckStyle: p.neck,
                      extraStyle: p.extra,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A3D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "ตั้งค่า",
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //=========================
              // HERO PROFILE CARD
              //=========================
              _buildHeroCard(),

              const SizedBox(height: 28),

              //=========================
              // PARENTAL CONTROL SECTION (โซนผู้ปกครอง)
              //=========================
              _sectionLabel(
                "โซนผู้ปกครอง"
              ),

              _buildSettingTile(
                icon: Icons.insights_rounded,
                color: const Color(0xFFEF4444),
                title: "รายงานและพัฒนาการการเรียน",
                subtitle: "สถิติเวลาเรียนจริง, คำศัพท์ที่ได้ และประวัติจุดอ่อน",
                onTap: () {
                  _showParentGate(
                    context,
                    onSuccess: () {
                      _openLearningReportSheet(context);
                    },
                  );
                },
              ),
              const SizedBox(height: 14),
              _buildSettingTile(
                icon: Icons.timer_rounded,
                color: const Color(0xFFF59E0B),
                title: "จำกัดเวลาเรียน & เวลาเปิด-ปิดแอป",
                subtitle:
                    isScreenTimeEnabled
                        ? "เปิดอยู่ • $dailyTimeLimitMinutes นาที / วัน"
                        : "กำหนดเวลาเรียนต่อวัน และเวลาห้ามเข้าใช้งาน",
                onTap: () {
                  _showParentGate(
                    context,
                    onSuccess: () {
                      _openScreenTimeSheet(context);
                    },
                  );
                },
              ),
              const SizedBox(height: 14),
              _buildSettingTile(
                icon: Icons.screen_lock_portrait_rounded,
                color: const Color(0xFF8B5CF6),
                title: "โหมดล็อกหน้าจอ",
                subtitle: "คำแนะนำการล็อกแอปไม่ให้เด็กกดออกไปเล่นอย่างอื่น",
                onTap: () {
                  _showParentGate(
                    context,
                    onSuccess: () {
                      _showKioskGuideDialog(context);
                    },
                  );
                },
              ),
              const SizedBox(height: 14),
              _buildSettingTile(
                icon: Icons.pin_rounded,
                color: const Color(0xFF10B981),
                title: "เปลี่ยนรหัส PIN ผู้ปกครอง",
                subtitle: "แก้ไขรหัสผ่าน 4 หลักสำหรับเข้าโหมดผู้ปกครอง",
                onTap: () {
                  _showParentGate(
                    context,
                    onSuccess: () {
                      _showSetupPinDialog(context, onPinCreated: () {});
                    },
                  );
                },
              ),

              const SizedBox(height: 28),

              //=========================
              // ACCOUNT SECTION
              //=========================
              _sectionLabel(
                "ตั้งค่าบัญชีผู้ใช้"
              ),

              _buildSettingTile(
                icon: Icons.person_rounded,
                color: const Color(0xFF4D7CFE),
                title: "โปรไฟล์ส่วนตัว",
                subtitle: "แต่งตัวอวตารและจัดการข้อมูลของคุณ",
                onTap: _openProfile,
              ),
              const SizedBox(height: 14),
              _buildSettingTile(
                icon: Icons.lock_rounded,
                color: const Color(0xFF22C55E),
                title: "ความปลอดภัยและรหัสผ่าน",
                subtitle: "เปลี่ยนรหัสผ่านและจัดการอุปกรณ์",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SecurityScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _buildNotificationCard(),
              const SizedBox(height: 14),
              _buildSoundToggleCard(
                icon: Icons.volume_up_rounded,
                color: const Color(0xFF8B5CF6),
                title: "เสียงเอฟเฟกต์",
                subtitle: Sfx.soundEnabled
                    ? "เปิดอยู่ • เสียงกดปุ่ม ตอบถูก/ผิด และรางวัล"
                    : "ปิดอยู่",
                value: Sfx.soundEnabled,
                onChanged: (v) {
                  Sfx.setSoundEnabled(v);
                  setState(() {});
                },
              ),
              const SizedBox(height: 14),
              _buildSoundToggleCard(
                icon: Icons.music_note_rounded,
                color: const Color(0xFFEC4899),
                title: "เพลงพื้นหลัง",
                subtitle: Sfx.musicEnabled
                    ? "เปิดอยู่ • เพลงเบา ๆ ตลอดการใช้งาน"
                    : "ปิดอยู่",
                value: Sfx.musicEnabled,
                onChanged: (v) {
                  Sfx.setMusicEnabled(v);
                  setState(() {});
                },
              ),
              const SizedBox(height: 14),
              _buildSettingTile(
                icon: Icons.info_rounded,
                color: const Color(0xFF0EA5E9),
                title: "เกี่ยวกับแอปพลิเคชัน",
                subtitle:
                    _appVersion.isEmpty
                        ? "ข้อกำหนดและความเป็นส่วนตัว"
                        : "เวอร์ชัน $_appVersion • ข้อกำหนดและความเป็นส่วนตัว",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              //=========================
              // LOG OUT BUTTON
              //=========================
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1F2),
                    foregroundColor: const Color(0xFFEF4444),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: const BorderSide(
                        color: Color(0xFFFFD3D8),
                        width: 2.5,
                      ),
                    ),
                  ),
                  onPressed: () => _showLogoutDialog(context),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, size: 22),
                      SizedBox(width: 8),
                      Text(
                        "ออกจากระบบ",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              //=========================
              // DELETE ACCOUNT BUTTON
              //=========================
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                ),
                onPressed: () async {
                  final deleted = await showDeleteAccountDialog(context);
                  if (deleted && context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.delete_forever_rounded, size: 20),
                label: const Text(
                  "ลบบัญชีผู้ใช้",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      //=========================
      // BOTTOM NAVIGATION BAR
      //=========================
      bottomNavigationBar: BottomNavigationBar(
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

          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CheckInScreen()),
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
      ),
    );
  }

  // ============================================================
  // HERO CARD
  // ============================================================
  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4D7CFE), Color(0xFF6FA8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          const BoxShadow(color: Color(0xFF3A63D8), offset: Offset(0, 6)),
          BoxShadow(
            color: const Color(0xFF4D7CFE).withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -36,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const Positioned(
              right: 22,
              bottom: 14,
              child: Icon(
                Icons.star_rounded,
                color: Color(0x66FFFFFF),
                size: 18,
              ),
            ),
            const Positioned(
              right: 56,
              top: 18,
              child: Icon(
                Icons.star_rounded,
                color: Color(0x55FFFFFF),
                size: 12,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _openProfile,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFFFB627),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: _buildAvatar(78),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF8A3D),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _userEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  // ============================================================
  // HELPER WIDGETS
  // ============================================================
Widget _sectionLabel(String text, [IconData? icon]) {
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 14),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: _brand),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: _ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

  List<BoxShadow> _cardShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.14),
          blurRadius: 14,
          offset: const Offset(0, 7),
        ),
      ];

  BoxDecoration _cardDecoration(Color color, {bool shadow = true}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color.withValues(alpha: 0.28), width: 2.5),
      boxShadow: shadow ? _cardShadow(color) : null,
    );
  }

  Widget _iconBubble(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  // The shadow sits outside the Material: inside it, the shadow was clipped to
  // the card's rectangle and showed up as faint square corners.
  Widget _buildSettingTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: _cardShadow(color),
      ),
      child: _settingTileBody(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      ),
    );
  }

  Widget _settingTileBody({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: _cardDecoration(color, shadow: false),
          child: Row(
            children: [
              _iconBubble(icon, color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    const Color color = Color(0xFFFF9F1C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _cardDecoration(color),
      child: Row(
        children: [
          _iconBubble(Icons.notifications_active_rounded, color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "การแจ้งเตือน",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isNotificationEnabled
                      ? "เปิดอยู่ • เตือนให้มาเรียนทุกวัน"
                      : "ปิดอยู่",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isNotificationEnabled,
            activeColor: const Color(0xFF22C55E),
            onChanged: _toggleNotification,
          ),
        ],
      ),
    );
  }

  Widget _buildSoundToggleCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _cardDecoration(color),
      child: Row(
        children: [
          _iconBubble(icon, color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF22C55E),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: _border, width: 2.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "ออกจากระบบ",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: _ink,
                ),
              ),
            ],
          ),
          content: const Text(
            "คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบบัญชีนี้ ?",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "ยกเลิก",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                // Clear the session (token, cached account data) and cancel
                // this account's scheduled reminders before leaving.
                await UserAccountPreferences.logout();

                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WelcomeScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
              child: const Text(
                "ออกจากระบบ",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// 😴 REST SCREEN (หน้าจอล็อกโหมดพักผ่อนเมื่อครบเวลา)
// ============================================================
class RestScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  final String title;
  final String message;

  const RestScreen({
    super.key,
    required this.onUnlock,
    this.title = "ได้เวลาพักสายตาแล้ว",
    this.message =
        "น้อง ๆ เรียนครบเวลาที่ผู้ปกครองกำหนดไว้สำหรับวันนี้แล้ว ไปพักผ่อนหรือทำกิจกรรมอื่นกันเถอะ !",
  });

  @override
  Widget build(BuildContext context) {
    // The back button must not close the lock; only a parent can unlock it.
    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: const Color(0xFF1E1B4B), // โทนสีกะทัดรัดยามค่ำคืน
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // The three friends fast asleep (replaces the moon icon).
              Image.asset(
                'assets/images/character/sleeping_friends.png',
                width: 280,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFC7D2FE),
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF818CF8), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: onUnlock,
                  icon: const Icon(Icons.lock_open_rounded, size: 20),
                  label: const Text(
                    "ปลดล็อกสำหรับผู้ปกครอง",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
