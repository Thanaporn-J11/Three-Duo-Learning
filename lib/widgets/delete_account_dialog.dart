import 'package:flutter/material.dart';

import '../services/parental_api_service.dart';
import '../services/user_account_preferences.dart';

const Color _ink = Color(0xFF1E293B);
const Color _danger = Color(0xFFEF4444);

/// Asks for the account password and, if the server accepts it, deletes the
/// account for good and signs out. Returns true when the account was deleted.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
  return deleted ?? false;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _hidden = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text;
    if (password.isEmpty) {
      setState(() => _error = 'กรุณากรอกรหัสผ่าน');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ParentalApiService.deleteAccount(password);
    } on ParentalApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'ลบบัญชีไม่สำเร็จ กรุณาลองอีกครั้ง';
      });
      return;
    }
    // The account is gone on the server; clean up this phone.
    try {
      await UserAccountPreferences.clearDeletedAccount();
    } catch (_) {}
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFFFFD3D8), width: 2.5),
      ),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _danger),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'ลบบัญชีผู้ใช้',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'บัญชีและข้อมูลทั้งหมด (ความคืบหน้า เหรียญ อวตาร ผลการเรียน) '
            'จะถูกลบถาวรและกู้คืนไม่ได้\n\n'
            'กรอกรหัสผ่านของบัญชีเพื่อยืนยัน',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            enabled: !_busy,
            obscureText: _hidden,
            decoration: InputDecoration(
              labelText: 'รหัสผ่านบัญชี',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _hidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _danger,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          onPressed: _busy ? null : _submit,
          child:
              _busy
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text('ลบบัญชี'),
        ),
      ],
    );
  }
}
