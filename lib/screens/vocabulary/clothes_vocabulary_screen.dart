import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../quiz_vocabulary/graduation_screen.dart';
import '../../models/quiz_vocabulary_item.dart';

class ClothesItem {
  final String word;
  final String phonetics; // คำอ่าน
  final String translation;
  final String imagePath;

  ClothesItem({
    required this.word,
    required this.phonetics,
    required this.translation,
    required this.imagePath,
  });
}

class ClothesVocabularyScreen extends StatefulWidget {
  const ClothesVocabularyScreen({super.key});

  @override
  State<ClothesVocabularyScreen> createState() => _ClothesVocabularyScreenState();
}

class _ClothesVocabularyScreenState extends State<ClothesVocabularyScreen> {
  int currentIndex = 0;
  late FlutterTts flutterTts;
  bool isSpeaking = false;

  // 👗 ข้อมูลคำศัพท์หมวดเสื้อผ้า (Clothes) ทั้ง 10 คำตรงตามไฟล์รูปภาพ
  final List<ClothesItem> clothes = [
    ClothesItem(
      word: 'Dress',
      phonetics: 'เดรส',
      translation: 'ชุดกระโปรง / ชุดเดรส',
      imagePath: 'assets/images/vocabulary/clothes/Dress.png',
    ),
    ClothesItem(
      word: 'Hat',
      phonetics: 'แฮท',
      translation: 'หมวก',
      imagePath: 'assets/images/vocabulary/clothes/Hat.png',
    ),
    ClothesItem(
      word: 'Jacket',
      phonetics: 'แจ็ค-เก็ต',
      translation: 'เสื้อแจ็คเก็ต',
      imagePath: 'assets/images/vocabulary/clothes/Jacket.jpg',
    ),
    ClothesItem(
      word: 'Pants',
      phonetics: 'แพนทส์',
      translation: 'กางเกงขายาว',
      imagePath: 'assets/images/vocabulary/clothes/Pants.jpg',
    ),
    ClothesItem(
      word: 'Shirt',
      phonetics: 'เชิ้ต',
      translation: 'เสื้อเชิ้ต',
      imagePath: 'assets/images/vocabulary/clothes/Shirt.jpg',
    ),
    ClothesItem(
      word: 'Shoes',
      phonetics: 'ชูส์',
      translation: 'รองเท้า',
      imagePath: 'assets/images/vocabulary/clothes/Shoes.jpg',
    ),
    ClothesItem(
      word: 'Shorts',
      phonetics: 'ชอร์ทส์',
      translation: 'กางเกงขาสั้น',
      imagePath: 'assets/images/vocabulary/clothes/Shorts.jpg',
    ),
    ClothesItem(
      word: 'Skirt',
      phonetics: 'สเกิร์ต',
      translation: 'กระโปรง',
      imagePath: 'assets/images/vocabulary/clothes/Skirt.jpg',
    ),
    ClothesItem(
      word: 'Sock',
      phonetics: 'ซ็อค',
      translation: 'ถุงเท้า',
      imagePath: 'assets/images/vocabulary/clothes/Sock.jpg',
    ),
    ClothesItem(
      word: 'T Shirt',
      phonetics: 'ที-เชิ้ต',
      translation: 'เสื้อยืด',
      imagePath: 'assets/images/vocabulary/clothes/T Shirt.jpg',
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

  // สร้างแบบทดสอบสุ่ม 10 ข้อสำหรับหมวดเสื้อผ้า
  List<QuizItem> _generateClothesQuiz() {
    final List<QuizItem> quizList = [];
    final List<ClothesItem> shuffledList = List<ClothesItem>.from(clothes)..shuffle();

    for (int i = 0; i < 10 && i < shuffledList.length; i++) {
      final current = shuffledList[i];
      final otherOptions = clothes.where((item) => item.word != current.word).toList()..shuffle();

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
    if (currentIndex < clothes.length - 1) {
      setState(() => currentIndex++);
    } else {
      // เปิดหน้า GraduationScreen เพื่อเตรียมเริ่มทำแบบฝึกหัด
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GraduationScreen(
            categoryTitle: 'เสื้อผ้า',
            quizItems: _generateClothesQuiz(),
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
    final currentClothes = clothes[currentIndex];
    final progress = (currentIndex + 1) / clothes.length;

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
          'คำศัพท์หมวดเสื้อผ้า',
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
                            '${currentIndex + 1} / ${clothes.length}',
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
                                currentClothes.imagePath,
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
                                    currentClothes.word,
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
                                  onTap: () => _speak(currentClothes.word),
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
                              currentClothes.phonetics,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // คำแปลภาษาไทย
                            Text(
                              currentClothes.translation,
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
                                currentIndex == clothes.length - 1 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(
                                currentIndex == clothes.length - 1 ? 'เสร็จสิ้น' : 'ถัดไป',
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