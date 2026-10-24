import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';
import 'reset_password_screen.dart';
import '../config/api_config.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;

  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool isLoading = false;
  bool isResending = false;

  Timer? _timer;
  int _startSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _startSeconds = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startSeconds > 0) {
        setState(() {
          _startSeconds--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  String get _currentOtp =>
      _controllers.map((controller) => controller.text).join();

  // ฟังก์ชันยืนยัน OTP
  Future<void> _verifyOtp() async {
    final otp = _currentOtp.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณากรอกรหัส OTP ให้ครบ 6 หลัก'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.api}/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'otp': otp}),
      );

      final data = jsonDecode(response.body);

      debugPrint('Backend verify-otp response: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final resetToken = data['resetToken'];

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(resetToken: resetToken),
          ),
        );
      } else {
        final serverMsg = (data['message'] ?? '').toString().toLowerCase();

        String errorMessage;
        if (serverMsg.contains('expired') &&
            !serverMsg.contains('invalid') &&
            !serverMsg.contains('incorrect')) {
          errorMessage = 'รหัส OTP หมดอายุแล้ว กรุณากดส่งรหัสใหม่อีกครั้ง';
        } else {
          errorMessage = 'รหัส OTP ไม่ถูกต้อง กรุณาตรวจสอบและลองใหม่อีกครั้ง';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาลองใหม่อีกครั้ง',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ฟังก์ชันขอส่งรหัส OTP ใหม่อีกครั้ง
  Future<void> _resendOtp() async {
    if (!_canResend || isResending) return;

    setState(() {
      isResending = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.api}/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();

        _startTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ส่งรหัส OTP ใหม่ไปยังอีเมลเรียบร้อยแล้ว'),
            backgroundColor: const Color(0xFF4A72FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'ไม่สามารถส่งรหัส OTP ได้ กรุณาลองใหม่อีกครั้ง',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาลองใหม่อีกครั้ง',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isResending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  // ช่องกล่องกรอกตัวเลข OTP แต่ละช่อง
  Widget _buildOtpBox(int index) {
    final isFilled = _controllers[index].text.isNotEmpty;
    return Container(
      width: 46,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFilled ? const Color(0xFF4E71F2) : const Color(0xFFE2E8F8),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        enableInteractiveSelection: false,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E4ECB),
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          setState(() {});
          if (value.isNotEmpty) {
            if (index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else {
              _focusNodes[index].unfocus();
              _verifyOtp();
            }
          } else {
            if (index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = (screenHeight * 0.28).clamp(170.0, 270.0).toDouble();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8EC5FC), Color(0xFFB5E2FA), Color(0xFFF9F7E8)],
          ),
        ),
        child: SafeArea(
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
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E4ECB).withValues(alpha: 0.08),
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),

                      SizedBox(
                        height: imageHeight,
                        child: Image.asset(
                          'assets/images/character/verify.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 26,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4A72FF).withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'ยืนยันรหัส OTP',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3366FF),
                              ),
                            ),
                            const SizedBox(height: 8),

                            const Text(
                              'เราได้ส่งรหัส OTP 6 หลักไปยังอีเมล',
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
                                  onTap: () {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(30),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F7FF),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F8),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.mail_outline_rounded,
                                          size: 16,
                                          color: Color(0xFF4A72FF),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            widget.email,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF3366FF),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.edit_rounded,
                                          size: 15,
                                          color: Color(0xFF4A72FF),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ช่องกรอก OTP 6 ช่อง
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                6,
                                (index) => _buildOtpBox(index),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // เวลานับถอยหลัง + ปุ่มส่งรหัสอีกครั้ง
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'ไม่ได้รับรหัส OTP? ',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                                if (!_canResend) ...[
                                  Text(
                                    'ส่งใหม่ได้ใน ($_startSeconds วินาที)',
                                    style: const TextStyle(
                                      color: Color(0xFF3366FF),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ] else ...[
                                  GestureDetector(
                                    onTap: isResending ? null : _resendOtp,
                                    child:
                                        isResending
                                            ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFF3366FF),
                                              ),
                                            )
                                            : const Text(
                                              'ส่งรหัสอีกครั้ง',
                                              style: TextStyle(
                                                color: Color(0xFF3366FF),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 26),

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
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF5559FF,
                                    ).withValues(alpha: 0.32),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child:
                                    isLoading
                                        ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                        : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'ยืนยัน',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward_rounded,
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
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}