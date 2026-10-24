import 'package:flutter/material.dart';
import '../../models/vocabulary_word.dart';
import '../../services/vocabulary_api_service.dart';
import '../../services/vocabulary_progress_service.dart';
import '../../services/lesson_progress.dart';
import 'vocabulary_resume.dart';
import '../../services/word_speaker.dart';
import 'vocabulary_api_status_view.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import '../quiz_vocabulary/graduation_screen.dart';
import '../../models/quiz_vocabulary_item.dart';

class FoodItem implements VocabularyWordView {
  @override
  final String word;
  @override
  final String thaiPhonetics;
  @override
  final String translation;
  @override
  final String imagePath;

  FoodItem({
    required this.word,
    required this.thaiPhonetics,
    required this.translation,
    required this.imagePath,
  });
  @override
  String get phonetics => '';
  @override
  String? get audioUrl => null;

}

class FoodVocabularyScreen extends StatefulWidget {
  const FoodVocabularyScreen({super.key});

  @override
  State<FoodVocabularyScreen> createState() => _FoodVocabularyScreenState();
}

class _FoodVocabularyScreenState extends State<FoodVocabularyScreen> {
  int currentIndex = 0;
  List<VocabularyWord>? _apiWords;
  bool _isLoading = true;
  String? _loadError;

  int get _wordCount => _apiWords?.length ?? foods.length;
  late AudioPlayer _audioPlayer;
  bool isSpeaking = false;

  final List<FoodItem> foods = [
    FoodItem(
      word: 'Bread',
      thaiPhonetics: 'เบรด',
      translation: 'ขนมปัง',
      imagePath: 'assets/images/vocabulary/food/Bread.png',
    ),
    FoodItem(
      word: 'Burger',
      thaiPhonetics: 'เบอร์ เกอร์',
      translation: 'เบอร์เกอร์',
      imagePath: 'assets/images/vocabulary/food/Burger.png',
    ),
    FoodItem(
      word: 'Cake',
      thaiPhonetics: 'เค้ก',
      translation: 'เค้ก',
      imagePath: 'assets/images/vocabulary/food/Cake.png',
    ),
    FoodItem(
      word: 'Candy',
      thaiPhonetics: 'แคน ดี',
      translation: 'ลูกอม / ท็อฟฟี่',
      imagePath: 'assets/images/vocabulary/food/Candy.png',
    ),
    FoodItem(
      word: 'Cheese',
      thaiPhonetics: 'ชีส',
      translation: 'เนยแข็ง / ชีส',
      imagePath: 'assets/images/vocabulary/food/Cheese.png',
    ),
    FoodItem(
      word: 'Chicken',
      thaiPhonetics: 'ชิก คิน',
      translation: 'ไก่ทอด / เนื้อไก่',
      imagePath: 'assets/images/vocabulary/food/Chicken.png',
    ),
    FoodItem(
      word: 'Chocolate',
      thaiPhonetics: 'ช็อก เคอะ ลิต',
      translation: 'ช็อกโกแลต',
      imagePath: 'assets/images/vocabulary/food/Chocolate.png',
    ),
    FoodItem(
      word: 'Cookie',
      thaiPhonetics: 'คุ้ก คี',
      translation: 'คุกกี้',
      imagePath: 'assets/images/vocabulary/food/Cookie.png',
    ),
    FoodItem(
      word: 'Corn',
      thaiPhonetics: 'คอร์น',
      translation: 'ข้าวโพด',
      imagePath: 'assets/images/vocabulary/food/Corn.png',
    ),
    FoodItem(
      word: 'Donut',
      thaiPhonetics: 'โด นัท',
      translation: 'โดนัท',
      imagePath: 'assets/images/vocabulary/food/Donut.png',
    ),
    FoodItem(
      word: 'Egg',
      thaiPhonetics: 'เอ้ก',
      translation: 'ไข่',
      imagePath: 'assets/images/vocabulary/food/Egg.png',
    ),
    FoodItem(
      word: 'Fish',
      thaiPhonetics: 'ฟิช',
      translation: 'ปลา',
      imagePath: 'assets/images/vocabulary/food/Fish.png',
    ),
    FoodItem(
      word: 'French fries',
      thaiPhonetics: 'เฟรนช์ ฟรายส์',
      translation: 'มันฝรั่งทอด',
      imagePath: 'assets/images/vocabulary/food/Frenchfries.png',
    ),
    FoodItem(
      word: 'Ice cream',
      thaiPhonetics: 'ไอซ์ ครีม',
      translation: 'ไอศกรีม',
      imagePath: 'assets/images/vocabulary/food/Icecream.png',
    ),
    FoodItem(
      word: 'Juice',
      thaiPhonetics: 'จูซ',
      translation: 'น้ำผลไม้',
      imagePath: 'assets/images/vocabulary/food/Juice.png',
    ),
    FoodItem(
      word: 'Meat',
      thaiPhonetics: 'มีท',
      translation: 'เนื้อสัตว์',
      imagePath: 'assets/images/vocabulary/food/Meat.png',
    ),
    FoodItem(
      word: 'Milk',
      thaiPhonetics: 'มิลก์',
      translation: 'นม',
      imagePath: 'assets/images/vocabulary/food/Milk.png',
    ),
    FoodItem(
      word: 'Noodle',
      thaiPhonetics: 'นู เดิล',
      translation: 'ก๋วยเตี๋ยว / บะหมี่',
      imagePath: 'assets/images/vocabulary/food/Noodle.png',
    ),
    FoodItem(
      word: 'Pizza',
      thaiPhonetics: 'พิท ซ่า',
      translation: 'พิซซ่า',
      imagePath: 'assets/images/vocabulary/food/Pizza.png',
    ),
    FoodItem(
      word: 'Potato',
      thaiPhonetics: 'พะ เท โท',
      translation: 'มันฝรั่ง',
      imagePath: 'assets/images/vocabulary/food/Potato.png',
    ),
    FoodItem(
      word: 'Rice',
      thaiPhonetics: 'ไรซ์',
      translation: 'ข้าว',
      imagePath: 'assets/images/vocabulary/food/Rice.png',
    ),
    FoodItem(
      word: 'Salad',
      thaiPhonetics: 'แซล เลิด',
      translation: 'สลัด',
      imagePath: 'assets/images/vocabulary/food/Salad.png',
    ),
    FoodItem(
      word: 'Salt',
      thaiPhonetics: 'ซอลต์',
      translation: 'เกลือ',
      imagePath: 'assets/images/vocabulary/food/Salt.png',
    ),
    FoodItem(
      word: 'Sandwich',
      thaiPhonetics: 'แซนด์ วิช',
      translation: 'แซนด์วิช',
      imagePath: 'assets/images/vocabulary/food/Sandwich.png',
    ),
    FoodItem(
      word: 'Sausage',
      thaiPhonetics: 'ซอ สิจ',
      translation: 'ไส้กรอก',
      imagePath: 'assets/images/vocabulary/food/Sausage.png',
    ),
    FoodItem(
      word: 'Soup',
      thaiPhonetics: 'ซุป',
      translation: 'ซุป / แกงจืด',
      imagePath: 'assets/images/vocabulary/food/Soup.png',
    ),
    FoodItem(
      word: 'Sugar',
      thaiPhonetics: 'ชู เกอะ',
      translation: 'น้ำตาล',
      imagePath: 'assets/images/vocabulary/food/Sugar.png',
    ),
    FoodItem(
      word: 'Tomato',
      thaiPhonetics: 'ทะ เม โท',
      translation: 'มะเขือเทศ',
      imagePath: 'assets/images/vocabulary/food/Tomato.png',
    ),
    FoodItem(
      word: 'Vegetable',
      thaiPhonetics: 'เวจ เทอะ เบิล',
      translation: 'ผัก',
      imagePath: 'assets/images/vocabulary/food/Vegetable.png',
    ),
    FoodItem(
      word: 'Water',
      thaiPhonetics: 'วอ เทอะ',
      translation: 'น้ำเปล่า',
      imagePath: 'assets/images/vocabulary/food/Water.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => isSpeaking = false);
    });
    _loadWords().then((_) => _restorePosition());
  }

  Future<void> _loadWords() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final words = await VocabularyApiService.getWords('food');
      if (!mounted) return;
      setState(() {
        // An empty list from the server -> use the built-in words.
        _apiWords = words.isEmpty ? null : words;
        _isLoading = false;
      });
    } catch (error) {
      // Server down / offline: carry on with the words built into the app
      // instead of stopping the child on an error page.
      debugPrint('Vocabulary API error: $error');
      if (!mounted) return;
      setState(() {
        _apiWords = null;
        _loadError = null;
        _isLoading = false;
      });
      _showOfflineNotice();
    }
  }

  void _showOfflineNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ตอนนี้เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ใช้คำศัพท์ในเครื่องแทนนะ'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _useLocalWords() {
    setState(() {
      _apiWords = null;
      _loadError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ใช้คำศัพท์ที่มีในเครื่องแทน')),
    );
  }


  Future<void> _speak(String word, [String? providedAudioUrl]) async {
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    try {
      final audioUrl = providedAudioUrl != null && providedAudioUrl.isNotEmpty
          ? providedAudioUrl
          : "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=${Uri.encodeComponent(cleanWord)}";

      await _audioPlayer.stop();
      await WordSpeaker.stop();
      setState(() => isSpeaking = true);
      await _audioPlayer
          .play(UrlSource(audioUrl))
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      // Online voice unavailable (offline, blocked, too slow):
      // read the word with the phone's own voice instead.
      debugPrint("Audio Error: $e");
      try {
        await _audioPlayer.stop();
      } catch (_) {}
      if (mounted) setState(() => isSpeaking = false);
      await WordSpeaker.speak(cleanWord);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  List<QuizItem> _generateFoodQuiz() {
    final List<QuizItem> quizList = [];
    final List<FoodItem> shuffledList = List<FoodItem>.from(foods)..shuffle();

    for (int i = 0; i < 10 && i < shuffledList.length; i++) {
      final current = shuffledList[i];
      final otherOptions =
          foods.where((item) => item.word != current.word).toList()..shuffle();

      if (i % 2 == 0) {
        final wordOptions = [
          current.word,
          otherOptions[0].word,
          otherOptions[1].word,
          otherOptions[2].word,
        ]..shuffle();

        quizList.add(
          QuizItem(
            questionText: 'รูปภาพนี้ตรงกับคำศัพท์ใด',
            questionImage: current.imagePath,
            correctWord: current.word,
            correctTranslation: current.translation,
            correctImage: current.imagePath,
            options: wordOptions,
            isImageOption: false,
          ),
        );
      } else {
        final imageOptions = [
          current.imagePath,
          otherOptions[0].imagePath,
          otherOptions[1].imagePath,
          otherOptions[2].imagePath,
        ]..shuffle();

        quizList.add(
          QuizItem(
            questionText: 'รูปภาพใด คือ ${current.word}',
            targetWord: current.word,
            correctWord: current.word,
            correctTranslation: current.translation,
            correctImage: current.imagePath,
            options: imageOptions,
            isImageOption: true,
          ),
        );
      }
    }
    quizList.shuffle();
    return quizList;
  }

  /// Back to the word the child stopped at last time (asks first).
  Future<void> _restorePosition() async {
    if (!mounted || _isLoading || _loadError != null) return;
    final saved = await LessonProgress.load('vocab_food', _wordCount);
    if (!mounted || saved == null) return;
    final api = _apiWords;
    final preview =
        api != null ? api[saved.index].term : foods[saved.index].word;
    final resume = await askVocabularyResume(
      context,
      wordNumber: saved.index + 1,
      total: _wordCount,
      wordPreview: preview,
    );
    if (!mounted) return;
    if (resume) {
      setState(() => currentIndex = saved.index);
    } else {
      LessonProgress.clear('vocab_food');
    }
  }

  /// Counts the word on screen as learned (for the parent report).
  void _markCurrentWordLearned() {
    final api = _apiWords;
    final String word;
    if (api != null) {
      if (currentIndex >= api.length) return;
      word = api[currentIndex].term;
    } else {
      if (currentIndex >= foods.length) return;
      word = foods[currentIndex].word;
    }
    VocabularyProgress.markLearned('food', word);
  }

  void _nextWord() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => isSpeaking = false);
    _markCurrentWordLearned();

    if (currentIndex < _wordCount - 1) {
      setState(() => currentIndex++);
      LessonProgress.save('vocab_food', currentIndex, 0);
    } else {
      // Went through every word: next time start from the first one.
      LessonProgress.clear('vocab_food');
      VocabularyProgress.markCategoryDone('food'); // green dot
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => GraduationScreen(
                categoryTitle: 'อาหาร',
                categorySlug: 'food',
                quizItems: _generateFoodQuiz(),
              ),
        ),
      );
    }
  }

  void _previousWord() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => isSpeaking = false);

    if (currentIndex > 0) {
      setState(() => currentIndex--);
      LessonProgress.save('vocab_food', currentIndex, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const VocabularyApiStatusView(
        title: '\u0e04\u0e33\u0e28\u0e31\u0e1e\u0e17\u0e4c',
        message: 'กำลังโหลดคำศัพท์...',
        loading: true,
      );
    }
    if (_loadError != null) {
      return VocabularyApiStatusView(
        title: '\u0e04\u0e33\u0e28\u0e31\u0e1e\u0e17\u0e4c',
        message: 'โหลดคำศัพท์ไม่สำเร็จ $_loadError',
        loading: false,
        onRetry: _loadWords,
        onUseLocal: _useLocalWords,
      );
    }
    if (_apiWords?.isEmpty ?? false) {
      return VocabularyApiStatusView(
        title: '\u0e04\u0e33\u0e28\u0e31\u0e1e\u0e17\u0e4c',
        message: 'ยังไม่มีคำศัพท์ในหมวดนี้',
        loading: false,
        onRetry: _loadWords,
        onUseLocal: _useLocalWords,
      );
    }

    final VocabularyWordView currentItem = _apiWords == null
        ? foods[currentIndex]
        : _apiWords![currentIndex];
    final progress = (currentIndex + 1) / _wordCount;
    final double cardImageHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: const Color(0xFF009CA6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () {
            _audioPlayer.stop();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'คำศัพท์หมวดอาหาร',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 21,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: const Color.fromARGB(255, 6, 113, 120), width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00332B).withValues(alpha: 0.35),
                  offset: const Offset(0, 10),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Category Badge & Counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFE65100),
                            offset: Offset(0, 3),
                          ),
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.restaurant_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'อาหาร',
                            style: GoogleFonts.mitr(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFE2E8F0),
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${currentIndex + 1}',
                              style: GoogleFonts.fredoka(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF9800),
                              ),
                            ),
                            TextSpan(
                              text: ' / $_wordCount',
                              style: GoogleFonts.fredoka(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // หลอดพลัง Progress Bar
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFFE2E8F0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 2,
                        offset: const Offset(0, 2),
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      tween: Tween<double>(begin: 0, end: progress),
                      builder:
                          (context, value, _) => LinearProgressIndicator(
                            value: value,
                            backgroundColor: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF9800),
                            ),
                          ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // กรอบรูปภาพ: สีม่วงลาเวนเดอร์พาสเทลอ่อน
                Container(
                  height: cardImageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 236, 196),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                      child: Container(
                        key: ValueKey<int>(currentIndex),
                        width: double.infinity,
                        height: double.infinity,
                        padding: const EdgeInsets.all(22.0),
                        child: Image.asset(
                          currentItem.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (context, error, stackTrace) => const Icon(
                                Icons.image_not_supported_rounded,
                                size: 70,
                                color: Colors.grey,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // โซนแสดงคำศัพท์
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey<int>(currentIndex),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              currentItem.word,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fredoka(
                                fontSize:
                                    currentItem.word.length > 12 ? 34 : 42,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _speak(currentItem.word, currentItem.audioUrl),
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color:
                                    isSpeaking
                                        ? const Color(0xFF00C853)
                                        : const Color(0xFF009CA6),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF004D40).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // คำอ่านภาษาไทย
                      Text(
                        currentItem.thaiPhonetics,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.mitr(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // คำแปลภาษาไทย สีส้มสดใสขนาดใหญ่
                      Text(
                        currentItem.translation,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.mitr(
                          fontSize:
                              currentItem.translation.length > 14 ? 28 : 34,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF6D00),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Action Buttons
                Row(
                  children: [
                    // ปุ่มย้อนกลับ
                    Expanded(
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color:
                              currentIndex > 0
                                  ? Colors.white
                                  : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                currentIndex > 0
                                    ? const Color(0xFFCBD5E1)
                                    : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow:
                              currentIndex > 0
                                  ? const [
                                    BoxShadow(
                                      color: Color(0xFFCBD5E1),
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: currentIndex > 0 ? _previousWord : null,
                            child: Center(
                              child: Text(
                                'ย้อนกลับ',
                                style: GoogleFonts.mitr(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color:
                                      currentIndex > 0
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // ปุ่มถัดไป
                    Expanded(
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFA726), Color(0xFFFF9800)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFFE65100),
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _nextWord,
                            child: Center(
                              child: Text(
                                currentIndex == _wordCount - 1
                                    ? 'เสร็จสิ้น'
                                    : 'ถัดไป',
                                style: GoogleFonts.mitr(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
