import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/profile_api_service.dart';

/// Edit the account's name and phone number (PATCH /api/profile).
/// Pops with the updated [ProfileData] when saved.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final ProfileData profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _ink = Color(0xFF1F2B52);
  static const Color _blue = Color(0xFF3B73F5);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _phone = TextEditingController(text: widget.profile.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'กรุณากรอกชื่อ';
    if (name.length > 50) return 'ชื่อยาวได้ไม่เกิน 50 ตัวอักษร';
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null; // optional
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9 || digits.length > 15) {
      return 'เบอร์โทรศัพท์ควรมี 9–15 หลัก';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final phone = _phone.text.trim();
      final updated = await ProfileApiService.updateProfile(
        name: _name.text.trim(),
        phone: phone.isEmpty ? null : phone,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อยแล้ว')),
      );
      Navigator.pop(context, updated);
    } on ProfileApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลไม่สำเร็จ กรุณาลองอีกครั้ง')),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _blue),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD6E0F5), width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD6E0F5), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _blue, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF3FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEEF3FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: _ink,
        title: const Text(
          'แก้ไขข้อมูลส่วนตัว',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              TextFormField(
                controller: _name,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                maxLength: 50,
                decoration: _decoration('ชื่อ', Icons.person_rounded),
                validator: _validateName,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
                  LengthLimitingTextInputFormatter(20), // users.phone is varchar(20)
                ],
                decoration: _decoration(
                  'เบอร์โทรศัพท์ (ไม่บังคับ)',
                  Icons.phone_rounded,
                  hint: 'เช่น 0812345678',
                ),
                validator: _validatePhone,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 12),
              Text(
                'อีเมล: ${widget.profile.email} (แก้ไขไม่ได้)',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child:
                      _saving
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            'บันทึก',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
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
