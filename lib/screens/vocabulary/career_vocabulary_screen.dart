import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class CareerItem {
  final String word;
  final String phonetics; // คำอ่าน
  final String translation;
  final String imagePath;

  CareerItem({
    required this.word,
    required this.phonetics,
    required this.translation,
    required this.imagePath,
  });
}

class CareerVocabularyScreen extends StatefulWidget {
  const CareerVocabularyScreen({super.key});

  @override
  State<CareerVocabularyScreen> createState() => _CareerVocabularyScreenState();
}

class _CareerVocabularyScreenState extends State<CareerVocabularyScreen> {
  int currentIndex = 0;
  late FlutterTts flutterTts;
  bool isSpeaking = false;

  // 💼 ข้อมูลคำศัพท์หมวดอาชีพ (Career) ทั้ง 30 คำตรงตามไฟล์รูปภาพ
  final List<CareerItem> careers = [
    CareerItem(
      word: 'Accountant',
      phonetics: 'อะ-เคาท์-เทินท์',
      translation: 'นักบัญชี',
      imagePath: 'assets/images/vocabulary/careers/Accountant.jpg',
    ),
    CareerItem(
      word: 'Architect',
      phonetics: 'อาร์-คิ-เท็คท์',
      translation: 'สถาปนิก',
      imagePath: 'assets/images/vocabulary/careers/Architect.jpg',
    ),
    CareerItem(
      word: 'Artist',
      phonetics: 'อาร์-ทิสท์',
      translation: 'ศิลปิน / จิตรกร',
      imagePath: 'assets/images/vocabulary/careers/Artist.png',
    ),
    CareerItem(
      word: 'Carpenter',
      phonetics: 'คาร์-เพน-เทอร์',
      translation: 'ช่างไม้',
      imagePath: 'assets/images/vocabulary/careers/Carpenter.png',
    ),
    CareerItem(
      word: 'Cashier',
      phonetics: 'แคช-เชียร์',
      translation: 'พนักงานคิดเงิน',
      imagePath: 'assets/images/vocabulary/careers/Cashier.jpg',
    ),
    CareerItem(
      word: 'Chef',
      phonetics: 'เชฟ',
      translation: 'พ่อครัว / เชฟ',
      imagePath: 'assets/images/vocabulary/careers/Chef.jpg',
    ),
    CareerItem(
      word: 'Dentist',
      phonetics: 'เดน-ทิสท์',
      translation: 'ทันตแพทย์ / หมอฟัน',
      imagePath: 'assets/images/vocabulary/careers/Dentist.jpg',
    ),
    CareerItem(
      word: 'Doctor',
      phonetics: 'ด็อก-เตอร์',
      translation: 'แพทย์ / หมอ',
      imagePath: 'assets/images/vocabulary/careers/Doctor.jpg',
    ),
    CareerItem(
      word: 'Electrician',
      phonetics: 'อิ-เล็ก-ทริช-เชิน',
      translation: 'ช่างไฟฟ้า',
      imagePath: 'assets/images/vocabulary/careers/Electrician.png',
    ),
    CareerItem(
      word: 'Engineer',
      phonetics: 'เอน-จิ-เนียร์',
      translation: 'วิศวกร',
      imagePath: 'assets/images/vocabulary/careers/Engineer.png',
    ),
    CareerItem(
      word: 'Farmer',
      phonetics: 'ฟาร์ม-เมอร์',
      translation: 'ชาวนา / เกษตรกร',
      imagePath: 'assets/images/vocabulary/careers/Farmer.jpg',
    ),
    CareerItem(
      word: 'Firefighter',
      phonetics: 'ไฟร์-ไฟท์-เทอร์',
      translation: 'นักดับเพลิง',
      imagePath: 'assets/images/vocabulary/careers/Firefighter.jpg',
    ),
    CareerItem(
      word: 'Flight Attendant',
      phonetics: 'ไฟลต์-อะ-เทน-เดินท์',
      translation: 'พนักงานต้อนรับบนเครื่องบิน',
      imagePath: 'assets/images/vocabulary/careers/Flight Attendant.jpg',
    ),
    CareerItem(
      word: 'Journalist',
      phonetics: 'เจอร์-นะ-ลิสท์',
      translation: 'นักข่าว / นักหนังสือพิมพ์',
      imagePath: 'assets/images/vocabulary/careers/Journalist.png',
    ),
    CareerItem(
      word: 'Lawyer',
      phonetics: 'ลอ-เยอร์',
      translation: 'ทนายความ',
      imagePath: 'assets/images/vocabulary/careers/Lawyer.png',
    ),
    CareerItem(
      word: 'Mechanic',
      phonetics: 'มะ-แคน-นิก',
      translation: 'ช่างยนต์ / ช่างเครื่อง',
      imagePath: 'assets/images/vocabulary/careers/Mechanic.jpg',
    ),
    CareerItem(
      word: 'Musician',
      phonetics: 'มิว-ซิช-เชิน',
      translation: 'นักดนตรี',
      imagePath: 'assets/images/vocabulary/careers/Musician.jpg',
    ),
    CareerItem(
      word: 'Nurse',
      phonetics: 'เนิร์ส',
      translation: 'พยาบาล',
      imagePath: 'assets/images/vocabulary/careers/Nurse.jpg',
    ),
    CareerItem(
      word: 'Pharmacist',
      phonetics: 'ฟาร์-มะ-ซิสท์',
      translation: 'เภสัชกร',
      imagePath: 'assets/images/vocabulary/careers/Pharmacist.png',
    ),
    CareerItem(
      word: 'Photographer',
      phonetics: 'ฟะ-ท็อก-ระ-เฟอร์',
      translation: 'ช่างภาพ',
      imagePath: 'assets/images/vocabulary/careers/Photographer.png',
    ),
    CareerItem(
      word: 'Pilot',
      phonetics: 'ไพ-ลัท',
      translation: 'นักบิน',
      imagePath: 'assets/images/vocabulary/careers/Pilot.png',
    ),
    CareerItem(
      word: 'Plumber',
      phonetics: 'พลัม-เมอร์',
      translation: 'ช่างประปา',
      imagePath: 'assets/images/vocabulary/careers/Plumber.jpg',
    ),
    CareerItem(
      word: 'Police Officer',
      phonetics: 'พะ-ลิส-ออฟ-ฟิ-เซอร์',
      translation: 'เจ้าหน้าที่ตำรวจ',
      imagePath: 'assets/images/vocabulary/careers/Police Officer.jpg',
    ),
    CareerItem(
      word: 'Programmer',
      phonetics: 'โปร-แกรม-เมอร์',
      translation: 'โปรแกรมเมอร์',
      imagePath: 'assets/images/vocabulary/careers/Programmer.png',
    ),
    CareerItem(
      word: 'Scientist',
      phonetics: 'ไซ-เอิน-ทิสท์',
      translation: 'นักวิทยาศาสตร์',
      imagePath: 'assets/images/vocabulary/careers/Scientist.jpg',
    ),
    CareerItem(
      word: 'Soldier',
      phonetics: 'โซล-เจอร์',
      translation: 'ทหาร',
      imagePath: 'assets/images/vocabulary/careers/Soldier.png',
    ),
    CareerItem(
      word: 'Teacher',
      phonetics: 'ทีช-เชอร์',
      translation: 'ครู / อาจารย์',
      imagePath: 'assets/images/vocabulary/careers/Teacher.jpg',
    ),
    CareerItem(
      word: 'Veterinarian',
      phonetics: 'เวท-เทอ-ริ-แน-เรียน',
      translation: 'สัตวแพทย์',
      imagePath: 'assets/images/vocabulary/careers/Veterinarian.png',
    ),
    CareerItem(
      word: 'Waiter',
      phonetics: 'เวท-เทอร์',
      translation: 'บริกรชาย',
      imagePath: 'assets/images/vocabulary/careers/Waiter.jpg',
    ),
    CareerItem(
      word: 'Waitress',
      phonetics: 'เวท-เทรส',
      translation: 'บริกรหญิง',
      imagePath: 'assets/images/vocabulary/careers/Waitress.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() {
    flutterTts = FlutterTts();
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.45);
    flutterTts.setVolume(1.0);
    flutterTts.setPitch(1.0);

    flutterTts.setStartHandler(() => setState(() => isSpeaking = true));
    flutterTts.setCompletionHandler(() => setState(() => isSpeaking = false));
    flutterTts.setErrorHandler((msg) => setState(() => isSpeaking = false));
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  void _nextWord() {
    if (currentIndex < careers.length - 1) {
      setState(() => currentIndex++);
    } else {
      _showCompletionDialog();
    }
  }

  void _previousWord() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8F5FE),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0088FF).withOpacity(0.12),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/character/bravo.png',
                    height: 145,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.stars_rounded, size: 80, color: Color(0xFF0088FF)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'เยี่ยมมาก!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: Color(0xFF0D5C9E),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'คุณเรียนรู้คำศัพท์ครบทั้ง ${careers.length} คำแล้ว',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // ปิด Dialog
                    Navigator.pop(context); // กลับหน้า Category
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadowColor: const Color(0xFF0088FF).withOpacity(0.35),
                  ),
                  child: const Text(
                    'กลับหน้าหลัก',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.2,
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

  @override
  Widget build(BuildContext context) {
    final currentCareer = careers[currentIndex];
    final progress = (currentIndex + 1) / careers.length;

    return Scaffold(
      backgroundColor: const Color(0xFFEDF5FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF0D5C9E), size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'คำศัพท์หมวดอาชีพ',
          style: TextStyle(
            color: Color(0xFF0D5C9E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6FAFD),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D5C9E).withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header Progress & Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Text(
                              'คำศัพท์',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0088FF),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Text(
                            '${currentIndex + 1} / ${careers.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5A789A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // แถบ Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          tween: Tween<double>(begin: 0, end: progress),
                          builder: (context, value, _) => LinearProgressIndicator(
                            value: value,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFDCEAF7),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0088FF)),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // กล่องพื้นหลังรูปภาพ (สี่เหลี่ยมมุมมน ความสูง 360)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Container(
                          key: ValueKey<int>(currentIndex),
                          height: 360,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D5C9E).withOpacity(0.08),
                                blurRadius: 16,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Image.asset(
                                currentCareer.imagePath,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.image_not_supported_rounded, size: 80, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // คำศัพท์ + ปุ่มกดฟังเสียง
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey<int>(currentIndex),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    currentCareer.word,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => _speak(currentCareer.word),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSpeaking ? const Color(0xFF00C853) : const Color(0xFF0088FF),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isSpeaking ? const Color(0xFF00C853) : const Color(0xFF0088FF)).withOpacity(0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // คำอ่าน
                            Text(
                              currentCareer.phonetics,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // คำแปลภาษาไทย
                            Text(
                              currentCareer.translation,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D5C9E),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 2),

                      // ปุ่มย้อนกลับและถัดไป
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: currentIndex > 0 ? _previousWord : null,
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text('ย้อนกลับ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0D5C9E),
                                side: const BorderSide(color: Color(0xFFCCE0F2), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _nextWord,
                              icon: Icon(
                                currentIndex == careers.length - 1 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(
                                currentIndex == careers.length - 1 ? 'เสร็จสิ้น' : 'ถัดไป',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0088FF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                shadowColor: const Color(0xFF0088FF).withOpacity(0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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