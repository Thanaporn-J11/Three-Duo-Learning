import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'checkin_screen.dart' show NotificationService;
import 'home_screen.dart';
import 'verify_otp_screen.dart';
import 'login_otp_screen.dart';
import 'register_screen.dart';
import '../config/api_config.dart';

// เปลี่ยนตัวการ์ตูนของหน้านี้ได้ที่นี่
const String _loginMascotAsset = "assets/images/character/yep.png";

class BrandColors {
  static const skyBlue = Color(0xff6FB6FF);
  static const skyBlueDark = Color(0xff3D6EF7);
  static const lightBlue = Color(0xffEAF4FF);
  static const cream = Color(0xffFFF3D6);
  static const coral = Color(0xffFF8A80);
  static const pink = Color(0xffFFC7DE);
  static const mint = Color(0xffB8F1D9);
  static const sun = Color(0xffFFC24D);
  static const ink = Color(0xff3A3A55);
}

// Login Screen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool hidePassword = true;

  bool _isLoading = false;
  bool _isOtpLoading = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // 1. Login with Email + Password

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnack("กรุณากรอกอีเมลและรหัสผ่านให้ครบ");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.api}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'deviceName': 'Android Emulator',
          'deviceType': 'android',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('jwt_token', data['token']);
        // Plan this account's reminders (its own settings, streak and status).
        NotificationService.instance.syncDailyReminderFromSettings(
          refreshStatus: true,
        );

        if (!mounted) return;

        _showSnack("เข้าสู่ระบบสำเร็จ ! ไปเรียนภาษากันเลย");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (response.statusCode == 401) {
        if (!mounted) return;

        _showSnack(data['message'] ?? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
      } else if (response.statusCode == 400) {
        if (!mounted) return;

        _showSnack(data['message'] ?? 'กรุณากรอกข้อมูลให้ครบ');
      } else {
        if (!mounted) return;

        _showSnack(data['message'] ?? 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ');
      }
    } catch (e) {
      if (!mounted) return;

      _showSnack('ไม่สามารถเชื่อมต่อ Server ได้');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 2. Login with OTP

  Future<void> _handleSendLoginOtp() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showSnack('กรุณากรอกอีเมลก่อน');
      return;
    }

    setState(() {
      _isOtpLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.api}/send-login-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSnack('ส่งรหัส OTP ไปยังอีเมลแล้ว');

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LoginOtpScreen(email: email)),
        );
      } else {
        _showSnack(data['message'] ?? 'ไม่สามารถส่ง OTP ได้');
      }
    } catch (e) {
      if (!mounted) return;

      _showSnack('ไม่สามารถเชื่อมต่อ Server ได้');
    } finally {
      if (mounted) {
        setState(() {
          _isOtpLoading = false;
        });
      }
    }
  }

  // 3. Forgot Password

  Future<void> _handleForgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showSnack("กรุณากรอกอีเมลก่อนรีเซ็ตรหัสผ่าน");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.api}/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;

        _showSnack("ส่งรหัส PIN ไปยังอีเมลแล้ว");

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VerifyOtpScreen(email: email)),
        );
      } else if (response.statusCode == 404) {
        if (!mounted) return;

        _showSnack(data['message'] ?? 'ไม่พบอีเมลนี้ในระบบ');
      } else if (response.statusCode == 400) {
        if (!mounted) return;

        _showSnack(data['message'] ?? 'กรุณากรอกอีเมล');
      } else {
        if (!mounted) return;

        _showSnack(data['message'] ?? 'เกิดข้อผิดพลาด');
      }
    } catch (e) {
      if (!mounted) return;

      _showSnack('ไม่สามารถเชื่อมต่อ Server ได้');
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: BrandColors.ink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final kb = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xffF7FBFF),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/background_2.png",
              fit: BoxFit.cover,
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xff5FB5F7).withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.04),
                    const Color(0xffEAF7FF).withValues(alpha: 0.20),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: -55,
            right: -45,
            child: _DecorCircle(
              size: 150,
              color: const Color(0xff7EBBFF).withValues(alpha: 0.18),
            ),
          ),

          Positioned(
            top: 110,
            left: -50,
            child: _DecorCircle(
              size: 100,
              color: const Color(0xffFFD36A).withValues(alpha: 0.18),
            ),
          ),

          LayoutBuilder(
            builder: (context, c) {
              final h = c.maxHeight;
              final w = c.maxWidth;

              const overlap = 40.0;

              final sheetHeight = math.max(
                0.0,
                math.min(math.min(h * 0.78, 560.0 + bottomInset), h - 150.0),
              );

              final topArea = h - sheetHeight;

              final mascotSize = math.min(
                w * 0.7,
                math.max(80.0, topArea - topInset + overlap - 8),
              );

              final visibleSheetHeight = math.max(
                0.0,
                math.min(sheetHeight, h - kb - topInset - 12),
              );

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: kb,
                    height: visibleSheetHeight,
                    child: _GlassSheet(
                      child: _SheetBody(
                        scrollable: kb > 0,
                        contentWidth: w - 56,
                        padding: EdgeInsets.fromLTRB(
                          28,
                          28,
                          28,
                          12 + (kb > 0 ? 0 : bottomInset),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "เข้าสู่ระบบ",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff3977FF),
                              ),
                            ),

                            const SizedBox(height: 6),

                            const Text(
                              "กลับมาเรียนรู้ภาษาไปพร้อมกับเพื่อน ๆ กันนะ",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xff5C6478),
                              ),
                            ),

                            const SizedBox(height: 18),

                            _LoginField(
                              label: "อีเมล",
                              icon: Icons.mail_rounded,
                              controller: emailController,
                              hintText: "กรอกอีเมลของคุณ",
                              keyboardType: TextInputType.emailAddress,
                            ),

                            const SizedBox(height: 12),

                            _LoginField(
                              label: "รหัสผ่าน",
                              icon: Icons.lock_rounded,
                              controller: passwordController,
                              hintText: "กรอกรหัสผ่าน",
                              obscureText: hidePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xff9AA7C7),
                                  size: 21,
                                ),
                                onPressed: () {
                                  setState(() {
                                    hidePassword = !hidePassword;
                                  });
                                },
                              ),
                            ),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _handleForgotPassword,
                                style: TextButton.styleFrom(
                                  foregroundColor: BrandColors.skyBlueDark,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text(
                                  "ลืมรหัสผ่าน?",
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 2),

                            _GradientButton(
                              label: "เข้าสู่ระบบ",
                              isLoading: _isLoading,
                              onTap: _handleLogin,
                            ),

                            const SizedBox(height: 14),

                            Row(
                              children: [
                                const Expanded(
                                  child: Divider(color: Color(0xffD6E1F5)),
                                ),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    "หรือ",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),

                                const Expanded(
                                  child: Divider(color: Color(0xffD6E1F5)),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed:
                                    _isOtpLoading ? null : _handleSendLoginOtp,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: BrandColors.skyBlueDark,
                                  backgroundColor: Colors.white.withValues(alpha: 
                                    0.85,
                                  ),
                                  side: const BorderSide(
                                    color: BrandColors.skyBlue,
                                    width: 1.3,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child:
                                    _isOtpLoading
                                        ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: BrandColors.skyBlueDark,
                                          ),
                                        )
                                        : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.mark_email_read_rounded,
                                              size: 21,
                                            ),
                                            SizedBox(width: 9),
                                            Text(
                                              "เข้าสู่ระบบด้วย OTP",
                                              style: TextStyle(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              "รับรหัสยืนยัน 6 หลักผ่านอีเมล",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(height: 4),

                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xff5C6478),
                                  ),
                                  children: [
                                    TextSpan(text: "ยังไม่มีบัญชีใช่ไหม? "),
                                    TextSpan(
                                      text: "สมัครสมาชิก",
                                      style: TextStyle(
                                        color: Color(0xff3D6EF7),
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Color(0xff3D6EF7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (kb == 0)
                    Positioned(
                      top: topInset + 4,
                      left: 0,
                      right: 0,
                      child: Center(child: _MiniMascot(size: mascotSize)),
                    ),

                  Positioned(
                    top: topInset + 8,
                    left: 16,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(12, 8, 16, 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 16,
                                color: Color(0xff2450B8),
                              ),
                              SizedBox(width: 6),
                              Text(
                                "กลับ",
                                style: TextStyle(
                                  color: Color(0xff2450B8),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final Widget child;

  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(38));

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xff4D7CFE).withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  Colors.white.withValues(alpha: 0.76),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 1.5,
                ),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double contentWidth;
  final bool scrollable;

  const _SheetBody({
    required this.child,
    required this.padding,
    required this.contentWidth,
    required this.scrollable,
  });

  @override
  Widget build(BuildContext context) {
    if (scrollable) {
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: padding,
          child: child,
        ),
      );
    }

    return Padding(
      padding: padding,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(width: contentWidth, child: child),
      ),
    );
  }
}

class _MiniMascot extends StatelessWidget {
  final double size;

  const _MiniMascot({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.6),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),

          Image.asset(
            _loginMascotAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder:
                (_, __, ___) => Icon(
                  Icons.flutter_dash,
                  size: size * 0.7,
                  color: const Color(0xff4D7CFE),
                ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Login Field
// แก้ปัญหา Password + Notebook Keyboard
// ============================================================

class _LoginField extends StatefulWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hintText;

  // true = เป็น Password
  final bool obscureText;

  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _LoginField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  OutlineInputBorder _border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPassword = widget.obscureText;
    final String actualText = widget.controller.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 7),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xff3D4A7A),
            ),
          ),
        ),

        Stack(
          alignment: Alignment.centerLeft,
          children: [
            TextField(
              controller: widget.controller,

              // สำคัญมาก:
              // ไม่ใช้ obscureText: true
              // เพราะตัวนี้ทำให้ Notebook Keyboard มีปัญหา
              obscureText: false,

              keyboardType: widget.keyboardType,

              // Password ไม่ต้องการ suggestion/autocorrect
              enableSuggestions: !isPassword,
              autocorrect: !isPassword,

              // ถ้าเป็น Password
              // ตัวอักษรจริงจะถูกทำให้โปร่งใส
              // แล้วเราแสดง •••• ทับด้านบนแทน
              style: TextStyle(
                fontSize: 15.5,
                color:
                    isPassword ? Colors.transparent : const Color(0xff2B3350),
              ),

              cursorColor: const Color(0xff4D7CFE),

              decoration: InputDecoration(
                hintText: actualText.isEmpty ? widget.hintText : null,

                hintStyle: const TextStyle(
                  color: Color(0xffB5BED6),
                  fontSize: 14.5,
                ),

                prefixIcon: Icon(
                  widget.icon,
                  color: const Color(0xff7C93D6),
                  size: 21,
                ),

                suffixIcon: widget.suffixIcon,

                filled: true,
                fillColor: const Color(0xffF3F7FF),

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),

                border: _border(const Color(0xffE1E9FB), 1),

                enabledBorder: _border(const Color(0xffE1E9FB), 1),

                focusedBorder: _border(const Color(0xff4D7CFE), 1.6),
              ),
            ),

            // ==================================================
            // แสดง •••••• แทน Password จริง
            // ==================================================
            if (isPassword && actualText.isNotEmpty)
              Positioned(
                left: 52,
                right: widget.suffixIcon != null ? 55 : 16,
                child: IgnorePointer(
                  child: Text(
                    '•' * actualText.length,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontSize: 15.5,
                      color: Color(0xff2B3350),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xff4D7CFE), Color(0xff6A5CFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff4D7CFE).withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: isLoading ? null : onTap,
          child: Center(
            child:
                isLoading
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
