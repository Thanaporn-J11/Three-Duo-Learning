import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
          "ข้อตกลงและเงื่อนไขการใช้บริการ",
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
                  "1. การยอมรับข้อตกลง",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 8),
                Text(
                  "การเข้าถึงและใช้งานแอปพลิเคชันนี้ ถือว่าคุณยอมรับและตกลงที่จะปฏิบัติตามข้อตกลงและเงื่อนไขของข้อตกลงนี้ทุกประการ",
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
                SizedBox(height: 20),
                Text(
                  "2. สิทธิ์การใช้งานของผู้ใช้",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 8),
                Text(
                  "อนุญาตให้ใช้งานแอปพลิเคชันนี้เป็นการชั่วคราวเพื่อวัตถุประสงค์ส่วนตัวและไม่ใช่เพื่อการค้าเท่านั้น",
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
                SizedBox(height: 20),
                Text(
                  "3. การจำกัดความรับผิดชอบ",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 8),
                Text(
                  "ผู้พัฒนาไม่ต้องรับผิดชอบต่อความเสียหายใด ๆ ที่เกิดขึ้นจากการใช้งาน หรือการไม่สามารถใช้งานแอปพลิเคชันนี้ได้ ไม่ว่าในกรณีใด ๆ",
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