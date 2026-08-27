import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../quiz_vocabulary/graduation_screen.dart';
import '../../models/quiz_vocabulary_item.dart';

class NumberItem {
  final String word;
  final String phonetics; // คำอ่าน
  final String translation;
  final String imagePath;

  NumberItem({
    required this.word,
    required this.phonetics,
    required this.translation,
    required this.imagePath,
  });
}

class NumberVocabularyScreen extends StatefulWidget {
  const NumberVocabularyScreen({super.key});

  @override
  State<NumberVocabularyScreen> createState() => _NumberVocabularyScreenState();
}

class _NumberVocabularyScreenState extends State<NumberVocabularyScreen> {
  int currentIndex = 0;
  late FlutterTts flutterTts;
  bool isSpeaking = false;

  // 🔢 ข้อมูลคำศัพท์หมวดตัวเลข (Number) ทั้ง 35 คำ เรียงลำดับจาก 0 ถึง 100 ตามไฟล์รูปภาพ
  final List<NumberItem> numbers = [
    NumberItem(
      word: 'Zero',
      phonetics: 'ซี-โร่',
      translation: '0 (ศูนย์)',
      imagePath: 'assets/images/vocabulary/numbers/Zero.jpg',
    ),
    NumberItem(
      word: 'One',
      phonetics: 'วัน',
      translation: '1 (หนึ่ง)',
      imagePath: 'assets/images/vocabulary/numbers/One.jpg',
    ),
    NumberItem(
      word: 'Two',
      phonetics: 'ทู',
      translation: '2 (สอง)',
      imagePath: 'assets/images/vocabulary/numbers/Two.jpg',
    ),
    NumberItem(
      word: 'Three',
      phonetics: 'ทรี',
      translation: '3 (สาม)',
      imagePath: 'assets/images/vocabulary/numbers/Three.jpg',
    ),
    NumberItem(
      word: 'Four',
      phonetics: 'ฟอร์',
      translation: '4 (สี่)',
      imagePath: 'assets/images/vocabulary/numbers/Four.jpg',
    ),
    NumberItem(
      word: 'Five',
      phonetics: 'ไฟฟ์',
      translation: '5 (ห้า)',
      imagePath: 'assets/images/vocabulary/numbers/Five.png',
    ),
    NumberItem(
      word: 'Six',
      phonetics: 'ซิกส์',
      translation: '6 (หก)',
      imagePath: 'assets/images/vocabulary/numbers/Six.jpg',
    ),
    NumberItem(
      word: 'Seven',
      phonetics: 'เซฟ-เวิน',
      translation: '7 (เจ็ด)',
      imagePath: 'assets/images/vocabulary/numbers/Seven.jpg',
    ),
    NumberItem(
      word: 'Eight',
      phonetics: 'เอท',
      translation: '8 (แปด)',
      imagePath: 'assets/images/vocabulary/numbers/Eight.jpg',
    ),
    NumberItem(
      word: 'Nine',
      phonetics: 'ไนน์',
      translation: '9 (เก้า)',
      imagePath: 'assets/images/vocabulary/numbers/Nine.jpg',
    ),
    NumberItem(
      word: 'Ten',
      phonetics: 'เทน',
      translation: '10 (สิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Ten.jpg',
    ),
    NumberItem(
      word: 'Eleven',
      phonetics: 'อิ-เลฟ-เวิน',
      translation: '11 (สิบเอ็ด)',
      imagePath: 'assets/images/vocabulary/numbers/Eleven.jpg',
    ),
    NumberItem(
      word: 'Twelve',
      phonetics: 'ทเวลฟ์',
      translation: '12 (สิบสอง)',
      imagePath: 'assets/images/vocabulary/numbers/Twelve.jpg',
    ),
    NumberItem(
      word: 'Thirteen',
      phonetics: 'เธิร์-ทีน',
      translation: '13 (สิบสาม)',
      imagePath: 'assets/images/vocabulary/numbers/Thirteen.jpg',
    ),
    NumberItem(
      word: 'Fourteen',
      phonetics: 'ฟอร์-ทีน',
      translation: '14 (สิบสี่)',
      imagePath: 'assets/images/vocabulary/numbers/Fourteen.jpg',
    ),
    NumberItem(
      word: 'Fifteen',
      phonetics: 'ฟิฟ-ทีน',
      translation: '15 (สิบห้า)',
      imagePath: 'assets/images/vocabulary/numbers/Fifteen.jpg',
    ),
    NumberItem(
      word: 'Sixteen',
      phonetics: 'ซิกส์-ทีน',
      translation: '16 (สิบหก)',
      imagePath: 'assets/images/vocabulary/numbers/Sixteen.jpg',
    ),
    NumberItem(
      word: 'Seventeen',
      phonetics: 'เซฟ-เวิน-ทีน',
      translation: '17 (สิบเจ็ด)',
      imagePath: 'assets/images/vocabulary/numbers/Seventeen.jpg',
    ),
    NumberItem(
      word: 'Eighteen',
      phonetics: 'เอท-ทีน',
      translation: '18 (สิบแปด)',
      imagePath: 'assets/images/vocabulary/numbers/Eighteen.jpg',
    ),
    NumberItem(
      word: 'Nineteen',
      phonetics: 'ไนน์-ทีน',
      translation: '19 (สิบเก้า)',
      imagePath: 'assets/images/vocabulary/numbers/Nineteen.jpg',
    ),
    NumberItem(
      word: 'Twenty',
      phonetics: 'ทเวน-ที',
      translation: '20 (ยี่สิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty.jpg',
    ),
    NumberItem(
      word: 'Twenty-one',
      phonetics: 'ทเวน-ที-วัน',
      translation: '21 (ยี่สิบเอ็ด)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-one.jpg',
    ),
    NumberItem(
      word: 'Twenty-two',
      phonetics: 'ทเวน-ที-ทู',
      translation: '22 (ยี่สิบสอง)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-two.jpg',
    ),
    NumberItem(
      word: 'Twenty-three',
      phonetics: 'ทเวน-ที-ทรี',
      translation: '23 (ยี่สิบสาม)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-three.jpg',
    ),
    NumberItem(
      word: 'Twenty-four',
      phonetics: 'ทเวน-ที-ฟอร์',
      translation: '24 (ยี่สิบสี่)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-four.jpg',
    ),
    NumberItem(
      word: 'Twenty-five',
      phonetics: 'ทเวน-ที-ไฟฟ์',
      translation: '25 (ยี่สิบห้า)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-five.jpg',
    ),
    NumberItem(
      word: 'Twenty-six',
      phonetics: 'ทเวน-ที-ซิกส์',
      translation: '26 (ยี่สิบหก)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-six.jpg',
    ),
    NumberItem(
      word: 'Twenty-seven',
      phonetics: 'ทเวน-ที-เซฟ-เวิน',
      translation: '27 (ยี่สิบเจ็ด)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-seven.jpg',
    ),
    NumberItem(
      word: 'Twenty-eight',
      phonetics: 'ทเวน-ที-เอท',
      translation: '28 (ยี่สิบแปด)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-eight.jpg',
    ),
    NumberItem(
      word: 'Twenty-nine',
      phonetics: 'ทเวน-ที-ไนน์',
      translation: '29 (ยี่สิบเก้า)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-nine.jpg',
    ),
    NumberItem(
      word: 'Thirty',
      phonetics: 'เธิร์-ที',
      translation: '30 (สามสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Thirty.jpg',
    ),
    NumberItem(
      word: 'Forty',
      phonetics: 'ฟอร์-ที',
      translation: '40 (สี่สิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Forty.jpg',
    ),
    NumberItem(
      word: 'Fifty',
      phonetics: 'ฟิฟ-ที',
      translation: '50 (ห้าสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Fifty.jpg',
    ),
    NumberItem(
      word: 'Sixty',
      phonetics: 'ซิกส์-ที',
      translation: '60 (หกสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Sixty.jpg',
    ),
    NumberItem(
      word: 'Seventy',
      phonetics: 'เซฟ-เวิน-ที',
      translation: '70 (เจ็ดสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Seventy.jpg',
    ),
    NumberItem(
      word: 'Eighty',
      phonetics: 'เอท-ที',
      translation: '80 (แปดสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Eighty.jpg',
    ),
    NumberItem(
      word: 'Ninety',
      phonetics: 'ไนน์-ที',
      translation: '90 (เก้าสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Ninety.jpg',
    ),
    NumberItem(
      word: 'One hundred',
      phonetics: 'วัน-ฮัน-เดร็ด',
      translation: '100 (หนึ่งร้อย)',
      imagePath: 'assets/images/vocabulary/numbers/One hundred.jpg',
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

  // สร้างแบบทดสอบสุ่ม 10 ข้อสำหรับหมวดตัวเลข
  List<QuizItem> _generateNumberQuiz() {
    final List<QuizItem> quizList = [];
    final List<NumberItem> shuffledList = List<NumberItem>.from(numbers)..shuffle();

    for (int i = 0; i < 10 && i < shuffledList.length; i++) {
      final current = shuffledList[i];
      final otherOptions = numbers.where((item) => item.word != current.word).toList()..shuffle();

      if (i % 2 == 0) {
        // รูปแบบที่ 1: ดูรูปภาพ -> เลือกคำศัพท์
        final wordOptions = [
          current.word,
          otherOptions[0].word,
          otherOptions[1].word,
          otherOptions[2].word,
        ]..shuffle();

        quizList.add(QuizItem(
          questionText: 'รูปภาพนี้ตรงกับคำศัพท์ใด',
          questionImage: current.imagePath,
          correctWord: current.word,
          correctTranslation: current.translation,
          correctImage: current.imagePath,
          options: wordOptions,
          isImageOption: false,
        ));
      } else {
        // รูปแบบที่ 2: ดูคำศัพท์ -> เลือกรูปภาพ
        final imageOptions = [
          current.imagePath,
          otherOptions[0].imagePath,
          otherOptions[1].imagePath,
          otherOptions[2].imagePath,
        ]..shuffle();

        quizList.add(QuizItem(
          questionText: 'รูปภาพใด คือ ${current.word}',
          targetWord: current.word,
          correctWord: current.word,
          correctTranslation: current.translation,
          correctImage: current.imagePath,
          options: imageOptions,
          isImageOption: true,
        ));
      }
    }
    quizList.shuffle();
    return quizList;
  }

  void _nextWord() {
    if (currentIndex < numbers.length - 1) {
      setState(() => currentIndex++);
    } else {
      // เปิดหน้า GraduationScreen เพื่อเตรียมเริ่มทำแบบฝึกหัด
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GraduationScreen(
            categoryTitle: 'ตัวเลข',
            quizItems: _generateNumberQuiz(),
          ),
        ),
      );
    }
  }

  void _previousWord() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentNumber = numbers[currentIndex];
    final progress = (currentIndex + 1) / numbers.length;

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
          'คำศัพท์หมวดตัวเลข',
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
                            '${currentIndex + 1} / ${numbers.length}',
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
                                currentNumber.imagePath,
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
                                    currentNumber.word,
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
                                  onTap: () => _speak(currentNumber.word),
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
                              currentNumber.phonetics,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // คำแปลภาษาไทย
                            Text(
                              currentNumber.translation,
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
                                currentIndex == numbers.length - 1 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(
                                currentIndex == numbers.length - 1 ? 'เสร็จสิ้น' : 'ถัดไป',
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