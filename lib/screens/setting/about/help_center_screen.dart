import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

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
          "ศูนย์ช่วยเหลือ",
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildFaqItem(
              "ลืมรหัสผ่าน ทำอย่างไร ?",
              "ออกจากระบบ แล้วกด ' ลืมรหัสผ่าน ? ' ในหน้าเข้าสู่ระบบ ระบบจะส่งรหัส OTP ไปที่อีเมลของคุณเพื่อตั้งรหัสผ่านใหม่",
            ),
            const SizedBox(height: 12),
            _buildFaqItem(
              "อยากเปลี่ยนรหัสผ่าน (จำรหัสเดิมได้) ?",
              "ไปที่ ตั้งค่า > ความปลอดภัยและรหัสผ่าน > เปลี่ยนรหัสผ่าน แล้วกรอกรหัสเดิมและรหัสใหม่",
            ),
            const SizedBox(height: 12),
            _buildFaqItem(
              "ใช้งานแบบออฟไลน์ได้ไหม ?",
              "ส่วนใหญ่ต้องต่ออินเทอร์เน็ต เพราะคำศัพท์ แบบฝึกหัด เหรียญ และการเช็กอินบันทึกไว้บนเซิร์ฟเวอร์ ส่วนการแต่งตัวอวตารเปลี่ยนได้ตอนออฟไลน์ และจะบันทึกขึ้นเซิร์ฟเวอร์เองเมื่อกลับมาออนไลน์",
            ),
            const SizedBox(height: 12),
            _buildFaqItem(
              "ลืมรหัส PIN ผู้ปกครอง ?",
              "กด ' ลืมรหัส PIN ? ' ในหน้าใส่ PIN แล้วกรอกรหัสผ่านของบัญชี จากนั้นตั้ง PIN ใหม่ได้เลย",
            ),
            const SizedBox(height: 12),
            _buildFaqItem(
              "ทำไมไม่มีการแจ้งเตือน ?",
              "ตรวจว่าเปิด ' การแจ้งเตือน ' ในหน้าตั้งค่าแล้ว และอนุญาตการแจ้งเตือนของแอปในการตั้งค่าของโทรศัพท์ การแจ้งเตือนอาจช้ากว่าเวลาที่ตั้งไว้เล็กน้อยเพื่อประหยัดแบตเตอรี่",
            ),
            const SizedBox(height: 12),
            _buildFaqItem(
              "แอปขึ้นหน้าพักผ่อนแล้วเล่นต่อไม่ได้ ?",
              "แปลว่าครบเวลาเล่นต่อวัน หรืออยู่ในช่วงเวลาห้ามใช้ที่ผู้ปกครองตั้งไว้ ผู้ปกครองกด ' ปลดล็อกสำหรับผู้ปกครอง ' แล้วใส่ PIN เพื่อเปิดให้เล่นต่อได้",
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}