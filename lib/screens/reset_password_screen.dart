import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';
import '../config/api_config.dart';

// กำหนด Path รูปภาพ character สำหรับหน้านี้
const String _resetPasswordMascotAsset = "assets/images/character/password.png";

class ResetPasswordScreen extends StatefulWidget {
  final String resetToken;

  const ResetPasswordScreen({super.key, required this.resetToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final FocusNode newPasswordFocusNode = FocusNode();

  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool _isLoading = false;
  bool _isPasswordFocused = false;

  @override
  void initState() {
    super.initState();
    newPasswordController.addListener(_onPasswordChanged);
    newPasswordFocusNode.addListener(_onPasswordFocusChanged);
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  void _onPasswordFocusChanged() {
    if (mounted) {
      setState(() {
        _isPasswordFocused = newPasswordFocusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    newPasswordController.removeListener(_onPasswordChanged);
    newPasswordFocusNode.removeListener(_onPasswordFocusChanged);
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    newPasswordFocusNode.dispose();
    super.dispose();
  }

  // ตรวจสอบเงื่อนไขรหัสผ่านตามเงื่อนไขของ Register
  bool _isPasswordValid(String password) {
    if (password.length < 8 || password.length > 72) return false;
    if (RegExp(r'\s').hasMatch(password)) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;
    if (!RegExp(r'[a-z]').hasMatch(password)) return false;
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;
    if (!RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)) return false;
    return true;
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (!_isPasswordValid(newPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาตั้งรหัสผ่านให้ถูกต้องตามเงื่อนไขทั้งหมด'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รหัสผ่านไม่ตรงกัน กรุณาตรวจสอบอีกครั้ง'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.api}/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'resetToken': widget.resetToken,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เปลี่ยนรหัสผ่านสำเร็จเรียบร้อยแล้ว'),
            backgroundColor: Color(0xFF4A72FF),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ??
                  'ไม่สามารถเปลี่ยนรหัสผ่านได้ กรุณาลองใหม่อีกครั้ง',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาลองใหม่อีกครั้ง',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
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
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E4ECB).withOpacity(0.08),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 6),

                        SizedBox(
                          height: 165,
                          child: Image.asset(
                            _resetPasswordMascotAsset,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (_, __, ___) => const Icon(
                                  Icons.lock_rounded,
                                  size: 90,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4A72FF,
                                ).withOpacity(0.12),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'ตั้งรหัสผ่านใหม่',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3366FF),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'กรุณากำหนดรหัสผ่านใหม่สำหรับบัญชีของคุณ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF757575),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // รหัสผ่านใหม่
                              _InputField(
                                label: 'รหัสผ่านใหม่',
                                icon: Icons.lock_outline_rounded,
                                controller: newPasswordController,
                                focusNode: newPasswordFocusNode,
                                obscureText: hidePassword,
                                hintText: 'อย่างน้อย 8 ตัวอักษร',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    hidePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF9AA7C7),
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => hidePassword = !hidePassword,
                                    );
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'กรุณากรอกรหัสผ่าน';
                                  }
                                  if (value.length < 8) {
                                    return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
                                  }
                                  if (value.length > 72) {
                                    return 'รหัสผ่านต้องไม่เกิน 72 ตัวอักษร';
                                  }
                                  if (RegExp(r'\s').hasMatch(value)) {
                                    return 'รหัสผ่านห้ามมีช่องว่าง';
                                  }
                                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                    return 'ต้องมีตัวพิมพ์ใหญ่อย่างน้อย 1 ตัว';
                                  }
                                  if (!RegExp(r'[a-z]').hasMatch(value)) {
                                    return 'ต้องมีตัวพิมพ์เล็กอย่างน้อย 1 ตัว';
                                  }
                                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                                    return 'ต้องมีตัวเลขอย่างน้อย 1 ตัว';
                                  }
                                  if (!RegExp(
                                    r'[^A-Za-z0-9\s]',
                                  ).hasMatch(value)) {
                                    return 'ต้องมีอักขระพิเศษอย่างน้อย 1 ตัว';
                                  }
                                  return null;
                                },
                              ),

                              // กล่องเงื่อนไขแสดงขึ้นมาเมื่อผู้ใช้แตะที่ช่องรหัสผ่าน
                              if (_isPasswordFocused) ...[
                                const SizedBox(height: 10),
                                _PasswordRequirements(
                                  password: newPasswordController.text,
                                ),
                              ],

                              const SizedBox(height: 16),

                              // ยืนยันรหัสผ่านใหม่
                              _InputField(
                                label: 'ยืนยันรหัสผ่านใหม่',
                                icon: Icons.lock_reset_rounded,
                                controller: confirmPasswordController,
                                obscureText: hideConfirmPassword,
                                hintText: 'กรอกรหัสผ่านใหม่อีกครั้ง',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    hideConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF9AA7C7),
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          hideConfirmPassword =
                                              !hideConfirmPassword,
                                    );
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'กรุณากรอกยืนยันรหัสผ่าน';
                                  }
                                  if (value != newPasswordController.text) {
                                    return 'รหัสผ่านไม่ตรงกัน';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              // ปุ่มยืนยันเปลี่ยนรหัสผ่าน
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
                                      ).withOpacity(0.32),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _handleResetPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                  child:
                                      _isLoading
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
                                                'เปลี่ยนรหัสผ่าน',
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
                        const SizedBox(height: 32),
                      ],
                    ),
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

// Widget ฟิลด์กรอกรหัสผ่าน
class _InputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;

  const _InputField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.suffixIcon,
    this.focusNode,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3D4A7A),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: Color(0xFF2B3350)),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFFB5BED6),
              fontSize: 13.5,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF7C93D6), size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF3F7FF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE1E9FB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE1E9FB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF4D7CFE),
                width: 1.6,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

// Widget แสดงรายการเช็คเงื่อนไขรหัสผ่าน
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
        color: const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E9FB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รหัสผ่านต้องมี',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3D4A7A),
            ),
          ),
          const SizedBox(height: 7),
          _RequirementItem(
            text: 'อย่างน้อย 8 ตัวอักษร',
            isValid: hasMinLength,
            hasStarted: hasStarted,
          ),
          _RequirementItem(
            text: 'ตัวพิมพ์ใหญ่ 1 ตัว (A-Z)',
            isValid: hasUppercase,
            hasStarted: hasStarted,
          ),
          _RequirementItem(
            text: 'ตัวพิมพ์เล็ก 1 ตัว (a-z)',
            isValid: hasLowercase,
            hasStarted: hasStarted,
          ),
          _RequirementItem(
            text: 'ตัวเลข 1 ตัว (0-9)',
            isValid: hasNumber,
            hasStarted: hasStarted,
          ),
          _RequirementItem(
            text: 'อักขระพิเศษ 1 ตัว เช่น @ # !',
            isValid: hasSpecial,
            hasStarted: hasStarted,
          ),
          _RequirementItem(
            text: 'ห้ามมีช่องว่าง',
            isValid: hasNoSpace,
            hasStarted: hasStarted,
          ),
        ],
      ),
    );
  }
}

// Widget ไอคอนและข้อความเงื่อนไขแต่ละข้อ
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
      iconColor = const Color(0xFFAAB5CF);
      icon = Icons.radio_button_unchecked_rounded;
    } else if (isValid) {
      iconColor = const Color(0xFF36B37E);
      icon = Icons.check_circle_rounded;
    } else {
      iconColor = Colors.redAccent;
      icon = Icons.cancel_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
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
