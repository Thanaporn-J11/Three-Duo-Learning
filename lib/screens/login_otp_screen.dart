
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'checkin_screen.dart' show NotificationService;
import 'home_screen.dart';
import 'login_screen.dart';
import '../config/api_config.dart';

const String _otpMascotAsset = "assets/images/character/friend_1.png";
const int _otpLength = 6;

class LoginOtpScreen extends StatefulWidget {
  final String email;

  const LoginOtpScreen({super.key, required this.email});

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  final TextEditingController otpController = TextEditingController();
  final FocusNode otpFocus = FocusNode();

  bool isLoading = false;

  Timer? _resendTimer;
  int _resendSeconds = 60;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    otpController.dispose();
    otpFocus.dispose();
    super.dispose();
  }

  void _showSnack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor:
            isError ? Colors.redAccent : const Color(0xFF4A72FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _goToLoginScreen() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendSeconds = 60;

    _resendTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_resendSeconds <= 1) {
          timer.cancel();
          setState(() {
            _resendSeconds = 0;
          });
        } else {
          setState(() {
            _resendSeconds--;
          });
        }
      },
    );
  }

  Future<void> _resendLoginOtp() async {
    if (_resendSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.api}/send-login-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        otpController.clear();
        _startResendTimer();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (otpFocus.canRequestFocus) {
            otpFocus.requestFocus();
          }
        });

        _showSnack('ส่งรหัส OTP ใหม่ไปยังอีเมลเรียบร้อยแล้ว');
      } else {
        _showSnack(
          data['message'] ??
              'ไม่สามารถส่งรหัส OTP ได้ กรุณาลองใหม่อีกครั้ง',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'ไม่สามารถเชื่อมต่อ Server ได้: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _verifyLoginOtp() async {
    final otp = otpController.text.trim();

    if (otp.length != _otpLength) {
      _showSnack(
        'กรุณากรอกรหัส OTP ให้ครบ 6 หลัก',
        isError: true,
      );
      return;
    }

    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.api}/verify-login-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'otp': otp,
          'deviceName': 'Android Emulator',
          'deviceType': 'android',
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final token = data['token'];

        if (token == null || token is! String || token.isEmpty) {
          _showSnack(
            'เข้าสู่ระบบไม่สำเร็จ เนื่องจากไม่ได้รับ Token',
            isError: true,
          );
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        // Plan this account's reminders (its own settings, streak and status).
        NotificationService.instance.syncDailyReminderFromSettings(
          refreshStatus: true,
        );

        if (!mounted) return;

        _showSnack('เข้าสู่ระบบสำเร็จ');

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
          (route) => false,
        );
      } else {
        final serverMsg =
            (data['message'] ?? '').toString().toLowerCase();

        String errorMessage;

        if (serverMsg.contains('expired') &&
            !serverMsg.contains('invalid') &&
            !serverMsg.contains('incorrect')) {
          errorMessage =
              'รหัส OTP หมดอายุแล้ว กรุณากดส่งรหัสใหม่อีกครั้ง';
        } else {
          errorMessage =
              'รหัส OTP ไม่ถูกต้อง กรุณาตรวจสอบและลองใหม่อีกครั้ง';
        }

        _showSnack(errorMessage, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'ไม่สามารถเชื่อมต่อ Server ได้: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFBFE0FE),
                    Color(0xFFD6EBFE),
                    Color(0xFFEBF5FE),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          Positioned(
            top: -45,
            right: -35,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5BA4FC).withValues(alpha: 0.35),
              ),
            ),
          ),

          Positioned(
            top: 130,
            left: -45,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD54F).withValues(alpha: 0.40),
              ),
            ),
          ),

          Positioned(
            bottom: 25,
            right: -35,
            child: Container(
              width: 155,
              height: 155,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC084FC).withValues(alpha: 0.35),
              ),
            ),
          ),

          Positioned(
            bottom: 110,
            left: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6EE7B7).withValues(alpha: 0.35),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E4ECB)
                                  .withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_ios_new,
                              size: 13,
                              color: Color(0xFF2E4ECB),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'กลับ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E4ECB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 145,
                                      height: 145,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white
                                                .withValues(alpha: 0.65),
                                            blurRadius: 36,
                                            spreadRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 195,
                                      child: Image.asset(
                                        _otpMascotAsset,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.mark_email_read_rounded,
                                          size: 90,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 22,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4A72FF)
                                            .withValues(alpha: 0.12),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'กรอกรหัส OTP',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3366FF),
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      const Text(
                                        'เราได้ส่งรหัส OTP 6 หลักไปยังอีเมลของคุณแล้ว',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF757575),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _goToLoginScreen,
                                            borderRadius:
                                                BorderRadius.circular(30),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 7,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    const Color(0xFFF4F7FF),
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFE2E8F8,
                                                  ),
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .mail_outline_rounded,
                                                    size: 16,
                                                    color:
                                                        Color(0xFF4A72FF),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      widget.email,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF3366FF,
                                                        ),
                                                      ),
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Icon(
                                                    Icons.edit_rounded,
                                                    size: 15,
                                                    color:
                                                        Color(0xFF4A72FF),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      // ช่องกรอก OTP 6 ช่อง
                                      _OtpBoxes(
                                        controller: otpController,
                                        focusNode: otpFocus,
                                        onComplete: _verifyLoginOtp,
                                      ),
                                      const SizedBox(height: 16),

                                      // เวลานับถอยหลัง + ปุ่มส่งรหัสอีกครั้ง
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'ไม่ได้รับรหัส OTP? ',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (_resendSeconds > 0) ...[
                                            Text(
                                              'ส่งใหม่ได้ใน ($_resendSeconds วินาที)',
                                              style: const TextStyle(
                                                color: Color(0xFF3366FF),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ] else ...[
                                            GestureDetector(
                                              onTap: _isResending
                                                  ? null
                                                  : _resendLoginOtp,
                                              child: _isResending
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            Color(0xFF3366FF),
                                                      ),
                                                    )
                                                  : const Text(
                                                      'ส่งรหัสอีกครั้ง',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF3366FF,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 22),

                                      // ปุ่มยืนยันและเข้าสู่ระบบ
                                      Container(
                                        width: double.infinity,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF4A72FF),
                                              Color(0xFF674AFF),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(25),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF5559FF)
                                                  .withValues(alpha: 0.32),
                                              blurRadius: 12,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: isLoading
                                              ? null
                                              : _verifyLoginOtp,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                          ),
                                          child: isLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                              : const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'ยืนยันและเข้าสู่ระบบ',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget ช่อง OTP 6 ช่อง
class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onComplete;

  const _OtpBoxes({
    required this.controller,
    required this.focusNode,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!focusNode.hasFocus && focusNode.canRequestFocus) {
            focusNode.requestFocus();
          }
        });
      },
      child: SizedBox(
        height: 54,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([controller, focusNode]),
              builder: (context, _) {
                final text = controller.text;
                final focused = focusNode.hasFocus;
                final activeIndex =
                    math.min(text.length, _otpLength - 1);

                return Row(
                  children: List.generate(_otpLength, (i) {
                    final hasDigit = i < text.length;
                    final isActive = focused && i == activeIndex;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i == _otpLength - 1 ? 0 : 8,
                        ),
                        child: Container(
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F7FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF4E71F2)
                                  : hasDigit
                                      ? const Color(0xFF4E71F2)
                                      : const Color(0xFFE2E8F8),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            hasDigit ? text[i] : '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E4ECB),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  onChanged: (value) {
                    if (value.length == _otpLength) {
                      onComplete();
                    }
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_otpLength),
                  ],
                  enableInteractiveSelection: true,
                  showCursor: false,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
