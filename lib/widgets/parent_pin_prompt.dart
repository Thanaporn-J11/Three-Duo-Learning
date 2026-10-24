import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/parent_pin.dart';
import '../services/parental_api_service.dart';

const Color _ink = Color(0xFF26314F);
const Color _brand = Color(0xFF4D7CFE);

ShapeBorder _dialogShape() => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(28),
  side: const BorderSide(color: Color(0xFFDCE9FF), width: 2.5),
);

String _lockedMessage(Duration left) {
  final seconds = left.inSeconds + 1;
  return 'ใส่ PIN ผิดหลายครั้ง กรุณารอ $seconds วินาที';
}

/// Asks for the parent PIN. Returns true when the right PIN was entered, or
/// when the parent proved who they are with the account password ("ลืม PIN?"),
/// in which case the PIN is cleared so a new one can be set.
/// If no PIN has been set yet there is nothing to check, so it returns true.
Future<bool> showParentPinPrompt(
  BuildContext context, {
  String title = 'ยืนยันรหัส PIN ผู้ปกครอง',
}) async {
  if (!await ParentPin.hasPin()) return true;
  if (!context.mounted) return false;
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinDialog(title: title),
  );
  if (result == 'ok') return true;
  if (result == 'forgot' && context.mounted) {
    final verified = await showAccountPasswordPrompt(context);
    if (verified) {
      await ParentPin.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ยืนยันตัวตนสำเร็จ ล้างรหัส PIN แล้ว ตั้งรหัสใหม่ได้ที่โซนผู้ปกครอง',
            ),
          ),
        );
      }
      return true;
    }
  }
  return false;
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title});

  final String title;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text.trim();
    if (!ParentPin.isValidFormat(pin)) {
      setState(() => _error = 'กรุณากรอกตัวเลข 4 หลัก');
      return;
    }
    setState(() => _busy = true);
    final result = await ParentPin.verify(pin);
    if (!mounted) return;
    switch (result) {
      case PinCheck.ok:
        Navigator.pop(context, 'ok');
      case PinCheck.wrong:
        _controller.clear();
        setState(() {
          _busy = false;
          _error = 'รหัส PIN ไม่ถูกต้อง';
        });
      case PinCheck.locked:
        final left = await ParentPin.lockedFor() ?? ParentPin.lockDuration;
        if (!mounted) return;
        _controller.clear();
        setState(() {
          _busy = false;
          _error = _lockedMessage(left);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: _dialogShape(),
      title: Row(
        children: [
          const Icon(Icons.lock_rounded, color: _brand, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_busy,
        obscureText: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 4,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 26, letterSpacing: 12),
        decoration: InputDecoration(
          counterText: '',
          hintText: '••••',
          errorText: _error,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, 'forgot'),
          child: const Text(
            'ลืมรหัส PIN ?',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, 'cancel'),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _brand,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: const Text('ยืนยัน'),
        ),
      ],
    );
  }
}

/// Asks for the account password and checks it with the server.
/// Used as the "forgot PIN" path: only someone who knows the account
/// password (the parent) can reset the parent PIN.
Future<bool> showAccountPasswordPrompt(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PasswordDialog(),
  );
  return ok ?? false;
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
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
      await ParentalApiService.verifyPassword(password);
      if (mounted) Navigator.pop(context, true);
    } on ParentalApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'ตรวจสอบรหัสผ่านไม่สำเร็จ กรุณาลองอีกครั้ง';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: _dialogShape(),
      title: const Text(
        'ยืนยันตัวตนผู้ปกครอง',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: _ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'กรอกรหัสผ่านของบัญชีนี้ (รหัสที่ใช้เข้าสู่ระบบ) เพื่อรีเซ็ตรหัส PIN',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
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
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _brand,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
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
                  : const Text('ยืนยัน'),
        ),
      ],
    );
  }
}
