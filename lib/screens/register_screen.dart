import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';
import '../config/api_config.dart';

// เปลี่ยนตัวการ์ตูนของหน้านี้ได้ที่นี่
const String _registerMascotAsset = "assets/images/character/bravo.png";

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool hidePassword = true;
  bool _isLoading = false;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // Password Focus

  final FocusNode passwordFocusNode = FocusNode();

  bool _isPasswordFocused = false;

  @override
  void initState() {
    super.initState();

    // ตรวจการพิมพ์รหัสผ่าน
    passwordController.addListener(_onPasswordChanged);

    // ตรวจว่าช่องรหัสผ่านกำลังถูกเลือกอยู่หรือไม่
    passwordFocusNode.addListener(_onPasswordFocusChanged);
  }

  // Password Changed

  void _onPasswordChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // Password Focus Changed

  void _onPasswordFocusChanged() {
    if (mounted) {
      setState(() {
        _isPasswordFocused = passwordFocusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    passwordController.removeListener(_onPasswordChanged);

    passwordFocusNode.removeListener(_onPasswordFocusChanged);

    passwordFocusNode.dispose();

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  // Register

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();

    // ไม่ trim password เพื่อไม่เปลี่ยนค่ารหัสผ่านที่ผู้ใช้กรอก
    final password = passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.api}/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("สร้างบัญชีสำเร็จ"),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'เกิดข้อผิดพลาดในการสมัครสมาชิก'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้: $e"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =====================================================
  // Build
  // =====================================================

  @override
  Widget build(BuildContext context) {
    const backH = 56.0;
    const mascotSize = 128.0;
    const overlap = 36.0;

    final cardTop = backH + mascotSize - overlap;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // =================================================
          // BACKGROUND
          // ล็อกอยู่กับที่
          // =================================================
          Positioned.fill(
            child: Image.asset(
              "assets/images/background_1.png",
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
            top: 120,
            left: -50,
            child: _DecorCircle(
              size: 100,
              color: const Color(0xffFFD36A).withValues(alpha: 0.18),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: cardTop,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: const _GlassSheet(child: SizedBox.expand()),
                ),

                Positioned(
                  top: cardTop,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ScrollConfiguration(
                    behavior: const _NoOverscrollBehavior(),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        26,
                        overlap + 14,
                        26,
                        24 + bottomInset,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "สร้างบัญชีใหม่",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff3977FF),
                              ),
                            ),

                            const SizedBox(height: 6),

                            const Text(
                              "สมัครฟรี แล้วเริ่มเรียนภาษาอังกฤษได้เลย",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xff5C6478),
                              ),
                            ),

                            const SizedBox(height: 26),

                            _RegisterField(
                              label: "ชื่อ - นามสกุล",
                              icon: Icons.person_rounded,
                              controller: nameController,
                              hintText: "เช่น ปรียา มีสุข",
                              keyboardType: TextInputType.name,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "กรุณากรอกชื่อ";
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _RegisterField(
                              label: "เบอร์โทรศัพท์",
                              icon: Icons.phone_rounded,
                              controller: phoneController,
                              hintText: "เช่น 0812345678",
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "กรุณากรอกเบอร์โทรศัพท์";
                                }

                                if (value.length < 9) {
                                  return "กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง";
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _RegisterField(
                              label: "อีเมล",
                              icon: Icons.mail_rounded,
                              controller: emailController,
                              hintText: "เช่น preeya@gmail.com",
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "กรุณากรอกอีเมล";
                                }

                                if (!value.contains("@")) {
                                  return "กรุณากรอกอีเมลให้ถูกต้อง";
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _RegisterField(
                              label: "รหัสผ่าน",
                              icon: Icons.lock_rounded,
                              controller: passwordController,

                              focusNode: passwordFocusNode,

                              hintText: "อย่างน้อย 8 ตัวอักษร",

                              obscureText: hidePassword,

                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    hidePassword = !hidePassword;
                                  });
                                },
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xff9AA7C7),
                                ),
                              ),

                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "กรุณากรอกรหัสผ่าน";
                                }

                                if (value.length < 8) {
                                  return "รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร";
                                }

                                if (value.length > 72) {
                                  return "รหัสผ่านต้องไม่เกิน 72 ตัวอักษร";
                                }

                                if (RegExp(r'\s').hasMatch(value)) {
                                  return "รหัสผ่านห้ามมีช่องว่าง";
                                }

                                if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                  return "ต้องมีตัวพิมพ์ใหญ่อย่างน้อย 1 ตัว";
                                }

                                if (!RegExp(r'[a-z]').hasMatch(value)) {
                                  return "ต้องมีตัวพิมพ์เล็กอย่างน้อย 1 ตัว";
                                }

                                if (!RegExp(r'[0-9]').hasMatch(value)) {
                                  return "ต้องมีตัวเลขอย่างน้อย 1 ตัว";
                                }

                                if (!RegExp(
                                  r'[^A-Za-z0-9\s]',
                                ).hasMatch(value)) {
                                  return "ต้องมีอักขระพิเศษอย่างน้อย 1 ตัว";
                                }

                                return null;
                              },
                            ),

                            if (_isPasswordFocused) ...[
                              const SizedBox(height: 10),

                              _PasswordRequirements(
                                password: passwordController.text,
                              ),
                            ],

                            const SizedBox(height: 30),

                            _GradientButton(
                              label: "สร้างบัญชี",
                              isLoading: _isLoading,
                              onTap: _handleRegister,
                            ),

                            const SizedBox(height: 10),

                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
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
                                      TextSpan(text: "มีบัญชีอยู่แล้ว? "),
                                      TextSpan(
                                        text: "เข้าสู่ระบบ",
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
                            ),

                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: backH - 4,
                  left: 0,
                  right: 0,
                  child: const Center(child: _MiniMascot(size: mascotSize)),
                ),

                Positioned(
                  top: 8,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _NoOverscrollBehavior extends MaterialScrollBehavior {
  const _NoOverscrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

// Password Requirements

class _PasswordRequirements extends StatelessWidget {
  final String password;

  const _PasswordRequirements({required this.password});

  @override
  Widget build(BuildContext context) {
    final bool hasStarted = password.isNotEmpty;

    final bool hasMinLength = password.length >= 8;

    final bool hasUppercase = RegExp(r'[A-Z]').hasMatch(password);

    final bool hasLowercase = RegExp(r'[a-z]').hasMatch(password);

    final bool hasNumber = RegExp(r'[0-9]').hasMatch(password);

    final bool hasSpecial = RegExp(r'[^A-Za-z0-9\s]').hasMatch(password);

    final bool hasNoSpace = !RegExp(r'\s').hasMatch(password);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xffF3F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffE1E9FB)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "รหัสผ่านต้องมี",
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xff3D4A7A),
            ),
          ),

          const SizedBox(height: 7),

          _RequirementItem(
            text: "อย่างน้อย 8 ตัวอักษร",
            isValid: hasMinLength,
            hasStarted: hasStarted,
          ),

          _RequirementItem(
            text: "ตัวพิมพ์ใหญ่ 1 ตัว (A-Z)",
            isValid: hasUppercase,
            hasStarted: hasStarted,
          ),

          _RequirementItem(
            text: "ตัวพิมพ์เล็ก 1 ตัว (a-z)",
            isValid: hasLowercase,
            hasStarted: hasStarted,
          ),

          _RequirementItem(
            text: "ตัวเลข 1 ตัว (0-9)",
            isValid: hasNumber,
            hasStarted: hasStarted,
          ),

          _RequirementItem(
            text: "อักขระพิเศษ 1 ตัว เช่น @ # !",
            isValid: hasSpecial,
            hasStarted: hasStarted,
          ),

          _RequirementItem(
            text: "ห้ามมีช่องว่าง",
            isValid: hasNoSpace,
            hasStarted: hasStarted,
          ),
        ],
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final String text;
  final bool isValid;
  final bool hasStarted;

  const _RequirementItem({
    required this.text,
    required this.isValid,
    required this.hasStarted,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData icon;

    if (!hasStarted) {
      iconColor = const Color(0xffAAB5CF);

      icon = Icons.radio_button_unchecked_rounded;
    } else if (isValid) {
      iconColor = const Color(0xff36B37E);

      icon = Icons.check_circle_rounded;
    } else {
      iconColor = Colors.redAccent;

      icon = Icons.cancel_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),

          const SizedBox(width: 7),

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: iconColor,
                fontWeight:
                    isValid && hasStarted ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
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
                  blurRadius: 36,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),

          Image.asset(
            _registerMascotAsset,
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

class _RegisterField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  final FocusNode? focusNode;

  const _RegisterField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,

    this.focusNode,
  });

  OutlineInputBorder _border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 7),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xff3D4A7A),
            ),
          ),
        ),

        TextFormField(
          controller: controller,

          focusNode: focusNode,

          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,

          style: const TextStyle(fontSize: 15.5, color: Color(0xff2B3350)),

          decoration: InputDecoration(
            hintText: hintText,

            hintStyle: const TextStyle(
              color: Color(0xffB5BED6),
              fontSize: 14.5,
            ),

            prefixIcon: Icon(icon, color: const Color(0xff7C93D6), size: 21),

            suffixIcon: suffixIcon,

            filled: true,

            fillColor: const Color(0xffF3F7FF),

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),

            border: _border(const Color(0xffE1E9FB), 1),

            enabledBorder: _border(const Color(0xffE1E9FB), 1),

            focusedBorder: _border(const Color(0xff4D7CFE), 1.6),

            errorBorder: _border(Colors.redAccent, 1),

            focusedErrorBorder: _border(Colors.redAccent, 1.6),
          ),
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
      height: 58,
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
                            fontSize: 19,
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