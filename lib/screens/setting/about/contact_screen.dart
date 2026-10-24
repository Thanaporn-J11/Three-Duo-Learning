import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/app_version.dart';

const String kSupportEmail = 'threeduo.learning@gmail.com';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Opens the phone's email app with the message already filled in.
  /// The app itself doesn't send anything; the user presses send there.
  Future<void> _openEmailApp() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาพิมพ์ข้อความก่อนส่ง')),
      );
      return;
    }

    final version = await AppVersion.label();
    final body = '$message\n\n---\nThreeDuo Learning เวอร์ชัน $version';
    // Encode by hand: Uri.queryParameters turns spaces into "+", which some
    // email apps show literally.
    final uri = Uri.parse(
      'mailto:$kSupportEmail'
      '?subject=${Uri.encodeComponent('ติดต่อจากแอป ThreeDuo Learning')}'
      '&body=${Uri.encodeComponent(body)}',
    );

    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;

    if (opened) {
      _messageController.clear();
      return;
    }
    // No email app on this phone: give the address so they can write to us.
    await Clipboard.setData(const ClipboardData(text: kSupportEmail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'ไม่พบแอปอีเมลในเครื่อง คัดลอกอีเมล $kSupportEmail ไว้ให้แล้ว',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "ติดต่อเรา",
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF64748B).withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "ส่งข้อความถึงเรา",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "กดส่งแล้วแอปอีเมลจะเปิดขึ้นพร้อมข้อความนี้ ส่งถึง $kSupportEmail",
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _messageController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: "อธิบายปัญหาหรือเสนอแนะข้อคิดเห็นของคุณ",
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _openEmailApp,
                        child: const Text(
                          "ส่งผ่านแอปอีเมล",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}