import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

// ============================================================
// COLORS & THEME (ตรงตามหน้า Translate)
// ============================================================

const Color _primaryBlue = Color(0xff3B9EFF);
const Color _primaryBlueDark = Color(0xff1C7ED6);
const Color _primaryBlueLight = Color(0xffEAF4FF);

const Color _mintGreen = Color(0xff2EC4B6);
const Color _mintGreenLight = Color(0xffE8F9F5);

const Color _pastelPink = Color(0xffFF6B8B);
const Color _pastelPinkLight = Color(0xffFFF0F3);

const Color _softPurple = Color(0xff845EC2);
const Color _softPurpleLight = Color(0xffF3EDF9);

const Color _ink = Color(0xff2A324B);
const Color _muted = Color(0xff7A869A);
const Color _line = Color(0xffE9EEF7);

class TranslationHistoryScreen extends StatefulWidget {
  const TranslationHistoryScreen({super.key});

  @override
  State<TranslationHistoryScreen> createState() =>
      _TranslationHistoryScreenState();
}

class _TranslationHistoryScreenState
    extends State<TranslationHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ============================================================
  // LOAD HISTORY
  // ============================================================

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.api}/translation-history'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;
        setState(() {
          _history = List<Map<String, dynamic>>.from(
            data['history'] ?? [],
          );
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _showMessage('ไม่สามารถโหลดประวัติการแปลได้');
      }
    } catch (e) {
      debugPrint('Load history error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showMessage('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  // ============================================================
  // DELETE SINGLE HISTORY
  // ============================================================

  Future<void> _deleteHistoryItem(Map<String, dynamic> item) async {
    final historyId = item['id'];
    if (historyId == null) {
      _showMessage('ไม่พบ ID ของประวัติ');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'ลบประวัติรายการนี้?',
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink, fontSize: 18),
          ),
          content: const Text(
            'คุณต้องการลบประวัติการแปลรายการนี้หรือไม่',
            style: TextStyle(color: _muted, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก', style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบ', style: TextStyle(color: _pastelPink, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        _showMessage('ไม่พบข้อมูลการเข้าสู่ระบบ');
        return;
      }

      final response = await http.delete(
        Uri.parse('${ApiConfig.api}/translation-history/$historyId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _history.removeWhere((history) => history['id'] == historyId);
        });
        _showMessage('ลบประวัติแล้ว');
      } else {
        _showMessage('ไม่สามารถลบประวัติได้');
      }
    } catch (e) {
      debugPrint('Delete single history error: $e');
      _showMessage('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  // ============================================================
  // DELETE ALL HISTORY
  // ============================================================

  Future<void> _clearHistory() async {
    if (_history.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'ลบประวัติทั้งหมด?',
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink, fontSize: 18),
          ),
          content: const Text(
            'คุณต้องการล้างประวัติการแปลทั้งหมดหรือไม่ การดำเนินการนี้ไม่สามารถย้อนกลับได้',
            style: TextStyle(color: _muted, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก', style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบทั้งหมด', style: TextStyle(color: _pastelPink, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        _showMessage('ไม่พบข้อมูลการเข้าสู่ระบบ');
        return;
      }

      final response = await http.delete(
        Uri.parse('${ApiConfig.api}/translation-history'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _history.clear();
        });
        _showMessage('ลบประวัติทั้งหมดแล้ว');
      } else {
        _showMessage('ไม่สามารถลบประวัติได้');
      }
    } catch (e) {
      debugPrint('Delete history error: $e');
      _showMessage('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';

    try {
      final date = DateTime.parse(dateString).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year · $hour:$minute น.';
    } catch (e) {
      return dateString;
    }
  }

  // ============================================================
  // LANGUAGE CODE HELPER (EN / TH)
  // ============================================================

  String _langCode(String lang) {
    final lower = lang.toLowerCase();
    if (lower == 'th' || lower == 'thai') return 'TH';
    return 'EN';
  }

  // ============================================================
  // HISTORY CARD
  // ============================================================

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final sourceLang = item['source_language']?.toString() ?? 'English';
    final targetLang = item['target_language']?.toString() ?? 'Thai';
    final sourceText = item['source_text']?.toString() ?? '';
    final translatedText = item['translated_text']?.toString() ?? '';
    final createdAt = _formatDate(item['created_at']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Language Badges (แสดงเฉพาะ EN -> TH)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _mintGreenLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _mintGreen.withValues(alpha: 0.35)),
                ),
                child: Text(
                  _langCode(sourceLang),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _mintGreen,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: _muted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryBlueLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _primaryBlue.withValues(alpha: 0.35)),
                ),
                child: Text(
                  _langCode(targetLang),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _primaryBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Source Text
          SelectableText(
            sourceText,
            style: const TextStyle(
              color: _ink,
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 8),
          Container(height: 1, color: _line),
          const SizedBox(height: 8),

          // 3. Translated Text
          SelectableText(
            translatedText,
            style: const TextStyle(
              color: _primaryBlueDark,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          // 4. Time & Delete Button
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: _muted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  createdAt,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Material(
                color: _pastelPinkLight,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _deleteHistoryItem(item),
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: _pastelPink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

// ============================================================
  // EMPTY STATE (จัดสัดส่วนใหม่ สมดุลสายตา)
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. เพิ่มขนาดรูปนกฮูกให้พอดีกับหน้าจอ
            Image.asset(
              'assets/images/character/sad.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: _softPurpleLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_stories_outlined,
                  size: 45,
                  color: _softPurple,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. หัวข้อข้อความ
            const Text(
              'ยังไม่มีประวัติการแปล',
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),

            // 3. คำอธิบาย
            const Text(
              'คำหรือประโยคที่คุณแปลจะถูกบันทึกไว้ที่นี่อัตโนมัติ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),

            // 4. ปุ่มกดเริ่มแปล (ช่วยถ่วงน้ำหนักส่วนล่าง ไม่ให้โล่งลอย)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.maybePop(context),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _primaryBlue,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryBlue.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.translate_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'ไปที่หน้าแปลภาษา',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPER: ฟองสีฟุ้งพื้นหลัง
  // ============================================================

  Widget _buildBlurBubble({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xffF2F8FF),
              Color(0xffF5FCF9),
              Color(0xffFFF5F8),
            ],
          ),
        ),
        child: Stack(
          children: [
            // วงกลมพาสเทลประดับพื้นหลัง
            Positioned(
              top: 80,
              right: -40,
              child: _buildBlurBubble(
                size: 150,
                color: _primaryBlue.withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              top: 300,
              left: -40,
              child: _buildBlurBubble(
                size: 140,
                color: const Color(0xffFFD166).withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              bottom: 60,
              right: -30,
              child: _buildBlurBubble(
                size: 160,
                color: _pastelPink.withValues(alpha: 0.13),
              ),
            ),

            // เนื้อหาหลัก
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 1. Custom Header สไตล์เดียวกับ Translate
                  Container(
                    height: 60,
                    width: double.infinity,
                    color: _primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 4,
                          child: IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        const Text(
                          'ประวัติการแปล',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_history.isNotEmpty)
                          Positioned(
                            right: 4,
                            child: IconButton(
                              tooltip: 'ล้างประวัติทั้งหมด',
                              onPressed: _clearHistory,
                              icon: const Icon(
                                Icons.delete_sweep_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 2. รายการประวัติ
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _primaryBlue,
                              strokeWidth: 2.5,
                            ),
                          )
                        : _history.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                color: _primaryBlue,
                                onRefresh: _loadHistory,
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                                  itemCount: _history.length,
                                  itemBuilder: (context, index) {
                                    return _buildHistoryCard(_history[index]);
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}