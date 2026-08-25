import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FamilyItem {
  final String word;
  final String phonetics; // คำอ่านไทย
  final String translation;
  final String imagePath;

  FamilyItem({
    required this.word,
    required this.phonetics,
    required this.translation,
    required this.imagePath,
  });
}

class FamilyVocabularyScreen extends StatefulWidget {
  const FamilyVocabularyScreen({super.key});

  @override
  State<FamilyVocabularyScreen> createState() => _FamilyVocabularyScreenState();
}

class _FamilyVocabularyScreenState extends State<FamilyVocabularyScreen> {
  int currentIndex = 0;
  late FlutterTts flutterTts;
  bool isSpeaking = false;

  // 👨‍👩‍👧‍👦 ข้อมูลคำศัพท์หมวดครอบครัว (Family) ทั้ง 16 คำตรงตามไฟล์รูปภาพ
  final List<FamilyItem> familyList = [
    FamilyItem(
      word: 'Baby',
      phonetics: 'เบ-บี',
      translation: 'เด็กทารก',
      imagePath: 'assets/images/vocabulary/family/Baby.png',
    ),
    FamilyItem(
      word: 'Brother',
      phonetics: 'บรา-เธอร์',
      translation: 'พี่ชาย / น้องชาย',
      imagePath: 'assets/images/vocabulary/family/Brother.png',
    ),
    FamilyItem(
      word: 'Child',
      phonetics: 'ชายลด์',
      translation: 'เด็ก',
      imagePath: 'assets/images/vocabulary/family/Child.png',
    ),
    FamilyItem(
      word: 'Daughter',
      phonetics: 'ดอ-เทอร์',
      translation: 'ลูกสาว',
      imagePath: 'assets/images/vocabulary/family/Daughter.jpg',
    ),
    FamilyItem(
      word: 'Family',
      phonetics: 'แฟม-มิ-ลี',
      translation: 'ครอบครัว',
      imagePath: 'assets/images/vocabulary/family/Family.png',
    ),
    FamilyItem(
      word: 'Father',
      phonetics: 'ฟา-เธอร์',
      translation: 'พ่อ',
      imagePath: 'assets/images/vocabulary/family/Father.png',
    ),
    FamilyItem(
      word: 'Grandfather',
      phonetics: 'แกรนด์-ฟา-เธอร์',
      translation: 'ปู่ / ตา',
      imagePath: 'assets/images/vocabulary/family/Grandfather.png',
    ),
    FamilyItem(
      word: 'Grandmother',
      phonetics: 'แกรนด์-มา-เธอร์',
      translation: 'ย่า / ยาย',
      imagePath: 'assets/images/vocabulary/family/Grandmother.jpg',
    ),
    FamilyItem(
      word: 'Grandparents',
      phonetics: 'แกรนด์-แพ-เรินท์ส',
      translation: 'ปู่ย่าตายาย',
      imagePath: 'assets/images/vocabulary/family/Grandparents.jpg',
    ),
    FamilyItem(
      word: 'Mother',
      phonetics: 'มา-เธอร์',
      translation: 'แม่',
      imagePath: 'assets/images/vocabulary/family/Mother.png',
    ),
    FamilyItem(
      word: 'Parents',
      phonetics: 'แพ-เรินท์ส',
      translation: 'พ่อแม่ / ผู้ปกครอง',
      imagePath: 'assets/images/vocabulary/family/Parents.png',
    ),
    FamilyItem(
      word: 'Relative',
      phonetics: 'เรล-ละ-ทิฟ',
      translation: 'ญาติ',
      imagePath: 'assets/images/vocabulary/family/Relative.jpg',
    ),
    FamilyItem(
      word: 'Sibling',
      phonetics: 'ซิบลืง',
      translation: 'พี่น้อง',
      imagePath: 'assets/images/vocabulary/family/Sibling.png',
    ),
    FamilyItem(
      word: 'Sister',
      phonetics: 'ซิส-เตอร์',
      translation: 'พี่สาว / น้องสาว',
      imagePath: 'assets/images/vocabulary/family/Sister.png',
    ),
    FamilyItem(
      word: 'Son',
      phonetics: 'ซัน',
      translation: 'ลูกชาย',
      imagePath: 'assets/images/vocabulary/family/Son.png',
    ),
    FamilyItem(
      word: 'Twin',
      phonetics: 'ทวิน',
      translation: 'ฝาแฝด',
      imagePath: 'assets/images/vocabulary/family/Twin.jpg',
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
    if (currentIndex < familyList.length - 1) {
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
                'คุณเรียนรู้คำศัพท์ครบทั้ง ${familyList.length} คำแล้ว',
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
    final currentItem = familyList[currentIndex];
    final progress = (currentIndex + 1) / familyList.length;

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
          'คำศัพท์หมวดครอบครัว', // ✅ เปลี่ยนเป็นภาษาไทย
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
                      // ส่วนแสดงความคืบหน้าและป้ายกำกับ
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
                              'คำศัพท์', // ✅ เปลี่ยนเป็นภาษาไทย
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0088FF),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Text(
                            '${currentIndex + 1} / ${familyList.length}',
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

                      // กล่องรูปภาพ (ความสูง 360 px กรอบสี่เหลี่ยมมุมมน)
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
                                currentItem.imagePath,
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
                                    currentItem.word,
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
                                  onTap: () => _speak(currentItem.word),
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

                            // คำอ่านไทย
                            Text(
                              currentItem.phonetics,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // คำแปลภาษาไทย
                            Text(
                              currentItem.translation,
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

                      // ปุ่มย้อนกลับและปุ่มถัดไป (ภาษาไทย)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: currentIndex > 0 ? _previousWord : null,
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text('ย้อนกลับ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), // ✅ ภาษาไทย
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
                                currentIndex == familyList.length - 1 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(
                                currentIndex == familyList.length - 1 ? 'เสร็จสิ้น' : 'ถัดไป', // ✅ ภาษาไทย
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