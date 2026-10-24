import 'package:flutter/material.dart';

import 'package:threeduo_learning/services/account_settings_api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // สำหรับวัดความแข็งแรงของรหัสผ่าน
  double _strength = 0;
  bool _hasMinLength = false;
  bool _hasUpperAndLower = false;
  bool _hasDigits = false;
  bool _hasSpecial = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_checkPasswordStrength);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    final text = _newPasswordController.text;
    setState(() {
      _hasMinLength = text.length >= 8;
      _hasUpperAndLower = text.contains(RegExp(r'(?=.*[a-z])(?=.*[A-Z])'));
      _hasDigits = text.contains(RegExp(r'[0-9]'));
      _hasSpecial = text.contains(RegExp(r'[!@#\$&*~]'));

      int score = 0;
      if (_hasMinLength) score++;
      if (_hasUpperAndLower) score++;
      if (_hasDigits) score++;
      if (_hasSpecial) score++;

      _strength = text.isEmpty ? 0 : score / 4;
    });
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AccountSettingsApiService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(
                "อัปเดตรหัสผ่านเรียบร้อยแล้ว !",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.pop(context);
    } on AccountSettingsApiException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A),
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          "เปลี่ยนรหัสผ่าน",
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner ให้คำแนะนำ
                _buildInfoBanner(),
                const SizedBox(height: 24),

                // รหัสผ่านปัจจุบัน
                _buildPasswordField(
                  controller: _currentPasswordController,
                  label: "รหัสผ่านปัจจุบัน",
                  hint: "กรอกรหัสผ่านเดิมของคุณ",
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscureCurrent,
                  onToggleObscure:
                      () => setState(() => _obscureCurrent = !_obscureCurrent),
                  validator:
                      (val) =>
                          val == null || val.isEmpty
                              ? "กรุณากรอกรหัสผ่านปัจจุบัน"
                              : null,
                ),
                const SizedBox(height: 20),

                // รหัสผ่านใหม่
                _buildPasswordField(
                  controller: _newPasswordController,
                  label: "รหัสผ่านใหม่",
                  hint: "สร้างรหัสผ่านใหม่ที่คาดเดายาก",
                  prefixIcon: Icons.key_rounded,
                  obscureText: _obscureNew,
                  onToggleObscure:
                      () => setState(() => _obscureNew = !_obscureNew),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return "กรุณากรอกรหัสผ่านใหม่";
                    }
                    if (val.length < 8) {
                      return "รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร";
                    }
                    if (val.contains(RegExp(r'\s'))) {
                      return "รหัสผ่านต้องไม่มีช่องว่าง";
                    }
                    if (!RegExp(r'[A-Z]').hasMatch(val) ||
                        !RegExp(r'[a-z]').hasMatch(val) ||
                        !RegExp(r'[0-9]').hasMatch(val) ||
                        !RegExp(r'[!@#\$&*~]').hasMatch(val)) {
                      return "ต้องมีตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก ตัวเลข และอักขระพิเศษ";
                    }
                    return null;
                  },
                ),

                // แถบ Strength Meter และ Checklist
                if (_newPasswordController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildStrengthBar(),
                  const SizedBox(height: 12),
                  _buildValidationChecklist(),
                ],

                const SizedBox(height: 20),

                // ยืนยันรหัสผ่านใหม่
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: "ยืนยันรหัสผ่านใหม่",
                  hint: "กรอกรหัสผ่านใหม่อีกครั้ง",
                  prefixIcon: Icons.lock_reset_rounded,
                  obscureText: _obscureConfirm,
                  onToggleObscure:
                      () => setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (val) {
                    if (val != _newPasswordController.text) {
                      return "รหัสผ่านไม่ตรงกัน";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 40),

                // ปุ่ม Save Gradient พร้อม Loading State
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF2563EB),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              "ตรวจสอบให้แน่ใจว่ารหัสผ่านใหม่ของคุณมีความยาวอย่างน้อย 8 ตัวอักษร และประกอบด้วยตัวอักษรและตัวเลขผสมกัน",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF1E40AF),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: const Color(0xFF64748B),
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: onToggleObscure,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrengthBar() {
    Color getStrengthColor() {
      if (_strength <= 0.25) return const Color(0xFFEF4444);
      if (_strength <= 0.75) return const Color(0xFFF59E0B);
      return const Color(0xFF10B981);
    }

    String getStrengthText() {
      if (_strength <= 0.25) return "คาดเดาง่าย";
      if (_strength <= 0.75) return "ปานกลาง";
      return "ปลอดภัยสูง";
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "ความปลอดภัยของรหัสผ่าน",
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              getStrengthText(),
              style: TextStyle(
                fontSize: 12,
                color: getStrengthColor(),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _strength,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(getStrengthColor()),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildValidationChecklist() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          _buildCheckItem("ความยาวอย่างน้อย 8 ตัวอักษร", _hasMinLength),
          const SizedBox(height: 6),
          _buildCheckItem(
            "มีทั้งตัวพิมพ์ใหญ่และตัวพิมพ์เล็ก",
            _hasUpperAndLower,
          ),
          const SizedBox(height: 6),
          _buildCheckItem("มีตัวเลข", _hasDigits),
          const SizedBox(height: 6),
          _buildCheckItem("มีอักขระพิเศษ", _hasSpecial),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text, bool isMet) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMet ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
          ),
          child: const Icon(Icons.check, size: 12, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isMet ? const Color(0xFF334155) : const Color(0xFF94A3B8),
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isLoading ? null : _savePassword,
        child:
            _isLoading
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                : const Text(
                  "อัปเดตรหัสผ่าน",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
      ),
    );
  }
}