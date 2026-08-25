import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FruitItem {
  final String word;
  final String phonetics; // คำอ่าน
  final String translation;
  final String imagePath;

  FruitItem({
    required this.word,
    required this.phonetics,
    required this.translation,
    required this.imagePath,
  });
}

class FruitVocabularyScreen extends StatefulWidget {
  const FruitVocabularyScreen({super.key});

  @override
  State<FruitVocabularyScreen> createState() => _FruitVocabularyScreenState();
}

class _FruitVocabularyScreenState extends State<FruitVocabularyScreen> {
  int currentIndex = 0;
  late FlutterTts flutterTts;
  bool isSpeaking = false;

  final List<FruitItem> fruits = [
    FruitItem(
      word: 'Apple',
      phonetics: 'แอพ-เปิ้ล',
      translation: 'แอปเปิ้ล',
      imagePath: 'assets/images/vocabulary/fruits/Apple.png',
    ),
    FruitItem(
      word: 'Avocado',
      phonetics: 'อะ-โว-คา-โด',
      translation: 'อะโวคาโด',
      imagePath: 'assets/images/vocabulary/fruits/Avocado.jpg',
    ),
    FruitItem(
      word: 'Banana',
      phonetics: 'บะ-แน-นะ',
      translation: 'กล้วย',
      imagePath: 'assets/images/vocabulary/fruits/Banana.webp',
    ),
    FruitItem(
      word: 'Blackberry',
      phonetics: 'แบล็ก-เบอ-รี',
      translation: 'แบล็กเบอร์รี',
      imagePath: 'assets/images/vocabulary/fruits/Blackberry.jpg',
    ),
    FruitItem(
      word: 'Blueberry',
      phonetics: 'บลู-เบอ-รี',
      translation: 'บลูเบอร์รี',
      imagePath: 'assets/images/vocabulary/fruits/Blueberry.jpg',
    ),
    FruitItem(
      word: 'Cherry',
      phonetics: 'เชอ-รี',
      translation: 'เชอร์รี',
      imagePath: 'assets/images/vocabulary/fruits/Cherry.jpg',
    ),
    FruitItem(
      word: 'Coconut',
      phonetics: 'โค-โค-นัท',
      translation: 'มะพร้าว',
      imagePath: 'assets/images/vocabulary/fruits/Coconut.png',
    ),
    FruitItem(
      word: 'Dragon Fruit',
      phonetics: 'ดรา-กอน-ฟรุต',
      translation: 'แก้วมังกร',
      imagePath: 'assets/images/vocabulary/fruits/Dragon Fruit.jpg',
    ),
    FruitItem(
      word: 'Durian',
      phonetics: 'ดู-เรียน',
      translation: 'ทุเรียน',
      imagePath: 'assets/images/vocabulary/fruits/Durian.jpg',
    ),
    FruitItem(
      word: 'Grapes',
      phonetics: 'เกรพส์',
      translation: 'องุ่น',
      imagePath: 'assets/images/vocabulary/fruits/Grapes.jpg',
    ),
    FruitItem(
      word: 'Guava',
      phonetics: 'กวา-วา',
      translation: 'ฝรั่ง',
      imagePath: 'assets/images/vocabulary/fruits/Guava.jpg',
    ),
    FruitItem(
      word: 'Jackfruit',
      phonetics: 'แจ็ค-ฟรุต',
      translation: 'ขนุน',
      imagePath: 'assets/images/vocabulary/fruits/Jackfruit.jpg',
    ),
    FruitItem(
      word: 'Kiwi',
      phonetics: 'คี-วี',
      translation: 'กีวี่',
      imagePath: 'assets/images/vocabulary/fruits/Kiwi.jpg',
    ),
    FruitItem(
      word: 'Lemon',
      phonetics: 'เลม-เอิน',
      translation: 'เลมอน',
      imagePath: 'assets/images/vocabulary/fruits/Lemon.jpg',
    ),
    FruitItem(
      word: 'Lime',
      phonetics: 'ไลม์',
      translation: 'มะนาว',
      imagePath: 'assets/images/vocabulary/fruits/Lime.jpg',
    ),
    FruitItem(
      word: 'Longan',
      phonetics: 'ลอง-แกน',
      translation: 'ลำไย',
      imagePath: 'assets/images/vocabulary/fruits/Longan.jpg',
    ),
    FruitItem(
      word: 'Lychee',
      phonetics: 'ไล-ชี',
      translation: 'ลิ้นจี่',
      imagePath: 'assets/images/vocabulary/fruits/Lychee.jpg',
    ),
    FruitItem(
      word: 'Mango',
      phonetics: 'แมง-โก',
      translation: 'มะม่วง',
      imagePath: 'assets/images/vocabulary/fruits/Mango.jpg',
    ),
    FruitItem(
      word: 'Mangosteen',
      phonetics: 'แมง-โก-สทีน',
      translation: 'มังคุด',
      imagePath: 'assets/images/vocabulary/fruits/Mangosteen.jpg',
    ),
    FruitItem(
      word: 'Orange',
      phonetics: 'ออ-รินจ์',
      translation: 'ส้ม',
      imagePath: 'assets/images/vocabulary/fruits/Orange.jpg',
    ),
    FruitItem(
      word: 'Papaya',
      phonetics: 'พะ-พาย-ยา',
      translation: 'มะละกอ',
      imagePath: 'assets/images/vocabulary/fruits/Papaya.png',
    ),
    FruitItem(
      word: 'Passion Fruit',
      phonetics: 'แพช-เชิน-ฟรุต',
      translation: 'เสาวรส',
      imagePath: 'assets/images/vocabulary/fruits/Passion Fruit.jpg',
    ),
    FruitItem(
      word: 'Peach',
      phonetics: 'พีช',
      translation: 'ลูกพีช',
      imagePath: 'assets/images/vocabulary/fruits/Peach.jpg',
    ),
    FruitItem(
      word: 'Pear',
      phonetics: 'แพร',
      translation: 'ลูกแพร์',
      imagePath: 'assets/images/vocabulary/fruits/Pear.jpg',
    ),
    FruitItem(
      word: 'Pineapple',
      phonetics: 'ไพน์-แอพ-เปิ้ล',
      translation: 'สับปะรด',
      imagePath: 'assets/images/vocabulary/fruits/Pineapple.jpg',
    ),
    FruitItem(
      word: 'Pomegranate',
      phonetics: 'พอม-แกรน-เนต',
      translation: 'ทับทิม',
      imagePath: 'assets/images/vocabulary/fruits/Pomegranate.jpg',
    ),
    FruitItem(
      word: 'Rambutan',
      phonetics: 'แรม-บู-แทน',
      translation: 'เงาะ',
      imagePath: 'assets/images/vocabulary/fruits/Rambutan.jpg',
    ),
    FruitItem(
      word: 'Raspberry',
      phonetics: 'แรซ-เบอ-รี',
      translation: 'ราสเบอร์รี',
      imagePath: 'assets/images/vocabulary/fruits/Raspberry.jpg',
    ),
    FruitItem(
      word: 'Strawberry',
      phonetics: 'สตรอ-เบอ-รี',
      translation: 'สตรอว์เบอร์รี',
      imagePath: 'assets/images/vocabulary/fruits/Strawberry.png',
    ),
    FruitItem(
      word: 'Watermelon',
      phonetics: 'วอ-เทอร์-เมล-ลอน',
      translation: 'แตงโม',
      imagePath: 'assets/images/vocabulary/fruits/Watermelon.jpg',
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
    if (currentIndex < fruits.length - 1) {
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
                'คุณเรียนรู้คำศัพท์ครบทั้ง ${fruits.length} คำแล้ว',
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
    final currentFruit = fruits[currentIndex];
    final progress = (currentIndex + 1) / fruits.length;

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
          'คำศัพท์หมวดผลไม้', // ✅ เปลี่ยนเป็นภาษาไทย
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
                            '${currentIndex + 1} / ${fruits.length}',
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
                              padding: const EdgeInsets.all(16),
                              child: Image.asset(
                                currentFruit.imagePath,
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
                                    currentFruit.word,
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
                                  onTap: () => _speak(currentFruit.word),
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

                            // คำอ่านโฟเนติกส์
                            Text(
                              currentFruit.phonetics,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // คำแปลภาษาไทย
                            Text(
                              currentFruit.translation,
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

                      // ปุ่ม Previous และ Next (เปลี่ยนเป็นภาษาไทย)
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
                                currentIndex == fruits.length - 1 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(
                                currentIndex == fruits.length - 1 ? 'เสร็จสิ้น' : 'ถัดไป', // ✅ ภาษาไทย
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