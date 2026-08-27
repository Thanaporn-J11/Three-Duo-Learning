import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../quiz_vocabulary/graduation_screen.dart';
import '../../models/quiz_vocabulary_item.dart';

class AnimalItem {
  final String word;
  final String phonetics; // คำอ่าน
  final String translation;
  final String imagePath;

  AnimalItem({
    required this.word,
    required this.phonetics,
    required this.translation,
    required this.imagePath,
  });
}

class AnimalVocabularyScreen extends StatefulWidget {
  const AnimalVocabularyScreen({super.key});

  @override
  State<AnimalVocabularyScreen> createState() => _AnimalVocabularyScreenState();
}

class _AnimalVocabularyScreenState extends State<AnimalVocabularyScreen> {
  int currentIndex = 0;
  late FlutterTts flutterTts;
  bool isSpeaking = false;

  final List<AnimalItem> animals = [
    AnimalItem(
      word: 'Bear',
      phonetics: 'แบร์',
      translation: 'หมี',
      imagePath: 'assets/images/vocabulary/animals/Bear.png',
    ),
    AnimalItem(
      word: 'Bee',
      phonetics: 'บี',
      translation: 'ผึ้ง',
      imagePath: 'assets/images/vocabulary/animals/Bee.jpg',
    ),
    AnimalItem(
      word: 'Bird',
      phonetics: 'เบิร์ด',
      translation: 'นก',
      imagePath: 'assets/images/vocabulary/animals/Bird.jpg',
    ),
    AnimalItem(
      word: 'Butterfly',
      phonetics: 'บัต-เตอร์-ฟลาย',
      translation: 'ผีเสื้อ',
      imagePath: 'assets/images/vocabulary/animals/Butterfly.jpg',
    ),
    AnimalItem(
      word: 'Cat',
      phonetics: 'แคท',
      translation: 'แมว',
      imagePath: 'assets/images/vocabulary/animals/Cat.png',
    ),
    AnimalItem(
      word: 'Chicken',
      phonetics: 'ชิค-เก้น',
      translation: 'ไก่',
      imagePath: 'assets/images/vocabulary/animals/Chicken.png',
    ),
    AnimalItem(
      word: 'Cow',
      phonetics: 'คาว',
      translation: 'วัว',
      imagePath: 'assets/images/vocabulary/animals/Cow.png',
    ),
    AnimalItem(
      word: 'Dog',
      phonetics: 'ด็อก',
      translation: 'สุนัข',
      imagePath: 'assets/images/vocabulary/animals/Dog.jpg',
    ),
    AnimalItem(
      word: 'Dolphin',
      phonetics: 'ดอล-ฟิน',
      translation: 'โลมา',
      imagePath: 'assets/images/vocabulary/animals/Dolphin.png',
    ),
    AnimalItem(
      word: 'Duck',
      phonetics: 'ดัค',
      translation: 'เป็ด',
      imagePath: 'assets/images/vocabulary/animals/Duck.png',
    ),
    AnimalItem(
      word: 'Elephant',
      phonetics: 'เอล-เล-เฟินท์',
      translation: 'ช้าง',
      imagePath: 'assets/images/vocabulary/animals/Elephant.jpg',
    ),
    AnimalItem(
      word: 'Fish',
      phonetics: 'ฟิช',
      translation: 'ปลา',
      imagePath: 'assets/images/vocabulary/animals/Fish.jpg',
    ),
    AnimalItem(
      word: 'Frog',
      phonetics: 'ฟรอก',
      translation: 'กบ',
      imagePath: 'assets/images/vocabulary/animals/Frog.jpg',
    ),
    AnimalItem(
      word: 'Giraffe',
      phonetics: 'จิ-ราฟ',
      translation: 'ยีราฟ',
      imagePath: 'assets/images/vocabulary/animals/Giraffe.png',
    ),
    AnimalItem(
      word: 'Hippo',
      phonetics: 'ฮิป-โป',
      translation: 'ฮิปโปโปเตมัส',
      imagePath: 'assets/images/vocabulary/animals/Hippo.jpg',
    ),
    AnimalItem(
      word: 'Horse',
      phonetics: 'ฮอร์ส',
      translation: 'ม้า',
      imagePath: 'assets/images/vocabulary/animals/Horse.jpg',
    ),
    AnimalItem(
      word: 'Kangaroo',
      phonetics: 'แคง-กะ-รู',
      translation: 'จิงโจ้',
      imagePath: 'assets/images/vocabulary/animals/Kangaroo.jpg',
    ),
    AnimalItem(
      word: 'Lion',
      phonetics: 'ไล-เอิน',
      translation: 'สิงโต',
      imagePath: 'assets/images/vocabulary/animals/Lion.jpg',
    ),
    AnimalItem(
      word: 'Monkey',
      phonetics: 'มัง-คี',
      translation: 'ลิง',
      imagePath: 'assets/images/vocabulary/animals/Monkey.png',
    ),
    AnimalItem(
      word: 'Octopus',
      phonetics: 'อ็อค-โท-พุส',
      translation: 'ปลาหมึกยักษ์',
      imagePath: 'assets/images/vocabulary/animals/Octopus.jpg',
    ),
    AnimalItem(
      word: 'Owl',
      phonetics: 'เอาล์',
      translation: 'นกฮูก',
      imagePath: 'assets/images/vocabulary/animals/Owl.jpg',
    ),
    AnimalItem(
      word: 'Panda',
      phonetics: 'แพน-ด้า',
      translation: 'แพนด้า',
      imagePath: 'assets/images/vocabulary/animals/Panda.jpg',
    ),
    AnimalItem(
      word: 'Penguin',
      phonetics: 'เพน-กวิน',
      translation: 'เพนกวิน',
      imagePath: 'assets/images/vocabulary/animals/Penguin.jpg',
    ),
    AnimalItem(
      word: 'Pig',
      phonetics: 'พิก',
      translation: 'หมู',
      imagePath: 'assets/images/vocabulary/animals/Pig.png',
    ),
    AnimalItem(
      word: 'Rabbit',
      phonetics: 'แรบ-บิท',
      translation: 'กระต่าย',
      imagePath: 'assets/images/vocabulary/animals/Rabbit.jpg',
    ),
    AnimalItem(
      word: 'Sheep',
      phonetics: 'ชีพ',
      translation: 'แกะ',
      imagePath: 'assets/images/vocabulary/animals/Sheep.jpg',
    ),
    AnimalItem(
      word: 'Tiger',
      phonetics: 'ไท-เกอร์',
      translation: 'เสือ',
      imagePath: 'assets/images/vocabulary/animals/Tiger.jpg',
    ),
    AnimalItem(
      word: 'Turtle',
      phonetics: 'เทอร์-เทิล',
      translation: 'เต่า',
      imagePath: 'assets/images/vocabulary/animals/Turtle.png',
    ),
    AnimalItem(
      word: 'Whale',
      phonetics: 'เวล',
      translation: 'วาฬ',
      imagePath: 'assets/images/vocabulary/animals/Whale.jpg',
    ),
    AnimalItem(
      word: 'Zebra',
      phonetics: 'ซี-บรา',
      translation: 'ม้าลาย',
      imagePath: 'assets/images/vocabulary/animals/Zebra.png',
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

  // สร้างแบบทดสอบสุ่ม 10 ข้อสำหรับหมวดสัตว์
  List<QuizItem> _generateAnimalQuiz() {
    final List<QuizItem> quizList = [];
    final List<AnimalItem> shuffledList = List<AnimalItem>.from(animals)..shuffle();

    for (int i = 0; i < 10 && i < shuffledList.length; i++) {
      final current = shuffledList[i];
      final otherOptions = animals.where((item) => item.word != current.word).toList()..shuffle();

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
    if (currentIndex < animals.length - 1) {
      setState(() => currentIndex++);
    } else {
      // เปิดหน้า GraduationScreen เพื่อเตรียมเริ่มทำแบบฝึกหัด
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GraduationScreen(
            categoryTitle: 'สัตว์',
            quizItems: _generateAnimalQuiz(),
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
    final currentAnimal = animals[currentIndex];
    final progress = (currentIndex + 1) / animals.length;

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
          'คำศัพท์หมวดสัตว์',
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
                            '${currentIndex + 1} / ${animals.length}',
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

                      // กล่องพื้นหลังรูปภาพ
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
                              padding: const EdgeInsets.all(16),
                              child: Image.asset(
                                currentAnimal.imagePath,
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
                                    currentAnimal.word,
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
                                  onTap: () => _speak(currentAnimal.word),
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
                              currentAnimal.phonetics,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // คำแปลภาษาไทย
                            Text(
                              currentAnimal.translation,
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
                                currentIndex == animals.length - 1 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(
                                currentIndex == animals.length - 1 ? 'เสร็จสิ้น' : 'ถัดไป',
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