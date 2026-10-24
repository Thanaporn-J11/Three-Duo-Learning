import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
          "นโยบายความเป็นส่วนตัว",
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF64748B).withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ข้อมูลที่เราเก็บ",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 8),
                Text(
                  "• ข้อมูลบัญชี : ชื่อ อีเมล เบอร์โทรศัพท์ (ถ้ากรอก) และรหัสผ่าน ซึ่งเก็บแบบเข้ารหัสทางเดียว (hash) เราจึงไม่เห็นรหัสผ่านจริงของคุณ\n• ข้อมูลการเรียน : คำศัพท์ที่เรียน คำตอบและคะแนนแบบฝึกหัด การเช็กอิน เหรียญ ไอเทมที่แลก ชุดอวตาร ความคืบหน้านิทาน และประวัติการแปล\n• ข้อมูลการเข้าสู่ระบบ : ชื่อและประเภทอุปกรณ์ และเวลาที่ใช้งานล่าสุด เพื่อให้คุณดูและออกจากระบบอุปกรณ์อื่นได้",
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
                SizedBox(height: 20),
                Text(
                  "ข้อมูลที่เก็บไว้ในเครื่องเท่านั้น",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 8),
                Text(
                  "การตั้งค่าโซนผู้ปกครอง รหัส PIN (เก็บแบบเข้ารหัสทางเดียว) เวลาที่ใช้แอปในแต่ละวัน การตั้งค่าการแจ้งเตือน และไฟล์เสียงที่อัดในเกมร้องเพลง ข้อมูลเหล่านี้ไม่ถูกส่งขึ้นเซิร์ฟเวอร์ ไฟล์เสียงจะออกจากเครื่องก็ต่อเมื่อคุณกดแชร์เอง",
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
                SizedBox(height: 20),
                Text(
                  "บริการภายนอกที่ใช้",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 8),
                Text(
                  "• ข้อความที่พิมพ์ในหน้าแปลภาษา จะถูกส่งไปแปลที่ Google Translate (และ MyMemory หากใช้ Google ไม่ได้)\n• การฟังเสียงพูด ใช้ระบบรู้จำเสียงของโทรศัพท์ ซึ่งอาจประมวลผลโดยผู้ให้บริการของระบบปฏิบัติการ\nเราไม่ขายหรือแบ่งปันข้อมูลของคุณให้บุคคลที่สามเพื่อการโฆษณา",
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
                SizedBox(height: 20),
                Text(
                  "การใช้ข้อมูล",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 8),
                Text(
                  "เราใช้ข้อมูลเพื่อให้แอปทำงาน บันทึกความคืบหน้า แสดงรายงานการเรียนให้ผู้ปกครอง และส่งการแจ้งเตือนเช็กอินที่คุณเปิดไว้ เท่านั้น",
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
                SizedBox(height: 20),
                Text(
                  "ความปลอดภัยของข้อมูล",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 8),
                Text(
                  "ทุกคำขอไปยังเซิร์ฟเวอร์ต้องใช้รหัสเข้าสู่ระบบของบัญชีนั้น และคุณยกเลิกการเข้าสู่ระบบของอุปกรณ์อื่นได้ทุกเมื่อ ในเวอร์ชันทดสอบนี้การเชื่อมต่อกับเซิร์ฟเวอร์ยังไม่ได้เข้ารหัส (ยังไม่ใช้ HTTPS) โปรดหลีกเลี่ยงการใช้งานผ่าน Wi-Fi สาธารณะ",
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
                SizedBox(height: 20),
                Text(
                  "สิทธิ์ของคุณ",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 8),
                Text(
                  "คุณแก้ไขชื่อและเบอร์โทรได้ในหน้าโปรไฟล์ หากต้องการดูหรือลบข้อมูลบัญชี ติดต่อเราได้ที่ threeduo.learning@gmail.com",
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}