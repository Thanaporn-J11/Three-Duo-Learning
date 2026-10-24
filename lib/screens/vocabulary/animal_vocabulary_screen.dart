import 'package:flutter/material.dart';
import '../../models/vocabulary_word.dart';
import '../../services/vocabulary_api_service.dart';
import '../../services/vocabulary_progress_service.dart';
import '../../services/lesson_progress.dart';
import 'vocabulary_resume.dart';
import '../../services/word_speaker.dart';
import 'vocabulary_api_status_view.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart'; // import google_fonts
import '../quiz_vocabulary/graduation_screen.dart';
import '../../models/quiz_vocabulary_item.dart';

class AnimalItem implements VocabularyWordView {
  @override
  final String word;
  @override
  final String phonetics;
  @override
  final String thaiPhonetics;
  @override
  final String translation;
  @override
  final String imagePath;

  AnimalItem({
    required this.word,
    this.phonetics = '',
    required this.thaiPhonetics,
    required this.translation,
    required this.imagePath,
  });
  @override
  String? get audioUrl => null;

}

class AnimalVocabularyScreen extends StatefulWidget {
  const AnimalVocabularyScreen({super.key});

  @override
  State<AnimalVocabularyScreen> createState() => _AnimalVocabularyScreenState();
}

class _AnimalVocabularyScreenState extends State<AnimalVocabularyScreen> {
  int currentIndex = 0;
  List<VocabularyWord>? _apiWords;
  bool _isLoading = true;
  String? _loadError;

  int get _wordCount => _apiWords?.length ?? animals.length;
  late AudioPlayer _audioPlayer;
  bool isSpeaking = false;

  final List<AnimalItem> animals = [
    AnimalItem(
      word: 'Bear',
      thaiPhonetics: 'แบร์',
      translation: 'หมี',
      imagePath: 'assets/images/vocabulary/animals/Bear.png',
    ),
    AnimalItem(
      word: 'Bee',
      thaiPhonetics: 'บี',
      translation: 'ผึ้ง',
      imagePath: 'assets/images/vocabulary/animals/Bee.png',
    ),
    AnimalItem(
      word: 'Bird',
      thaiPhonetics: 'เบิร์ด',
      translation: 'นก',
      imagePath: 'assets/images/vocabulary/animals/Bird.png',
    ),
    AnimalItem(
      word: 'Butterfly',
      thaiPhonetics: 'บัต เตอร์ ฟลาย',
      translation: 'ผีเสื้อ',
      imagePath: 'assets/images/vocabulary/animals/Butterfly.png',
    ),
    AnimalItem(
      word: 'Cat',
      thaiPhonetics: 'แคท',
      translation: 'แมว',
      imagePath: 'assets/images/vocabulary/animals/Cat.png',
    ),
    AnimalItem(
      word: 'Chicken',
      thaiPhonetics: 'ชิค เก้น',
      translation: 'ไก่',
      imagePath: 'assets/images/vocabulary/animals/Chicken.png',
    ),
    AnimalItem(
      word: 'Cow',
      thaiPhonetics: 'คาว',
      translation: 'วัว',
      imagePath: 'assets/images/vocabulary/animals/Cow.png',
    ),
    AnimalItem(
      word: 'Dog',
      thaiPhonetics: 'ด็อก',
      translation: 'สุนัข',
      imagePath: 'assets/images/vocabulary/animals/Dog.png',
    ),
    AnimalItem(
      word: 'Dolphin',
      thaiPhonetics: 'ดอล เฟิน',
      translation: 'โลมา',
      imagePath: 'assets/images/vocabulary/animals/Dolphin.png',
    ),
    AnimalItem(
      word: 'Duck',
      thaiPhonetics: 'ดัค',
      translation: 'เป็ด',
      imagePath: 'assets/images/vocabulary/animals/Duck.png',
    ),
    AnimalItem(
      word: 'Elephant',
      thaiPhonetics: 'เอล เล เฟินท์',
      translation: 'ช้าง',
      imagePath: 'assets/images/vocabulary/animals/Elephant.png',
    ),
    AnimalItem(
      word: 'Fish',
      thaiPhonetics: 'ฟิช',
      translation: 'ปลา',
      imagePath: 'assets/images/vocabulary/animals/Fish.png',
    ),
    AnimalItem(
      word: 'Frog',
      thaiPhonetics: 'ฟรอก',
      translation: 'กบ',
      imagePath: 'assets/images/vocabulary/animals/Frog.png',
    ),
    AnimalItem(
      word: 'Giraffe',
      thaiPhonetics: 'จิ ราฟ',
      translation: 'ยีราฟ',
      imagePath: 'assets/images/vocabulary/animals/Giraffe.png',
    ),
    AnimalItem(
      word: 'Hippo',
      thaiPhonetics: 'ฮิป โป',
      translation: 'ฮิปโปโปเตมัส',
      imagePath: 'assets/images/vocabulary/animals/Hippo.png',
    ),
    AnimalItem(
      word: 'Horse',
      thaiPhonetics: 'ฮอร์ส',
      translation: 'ม้า',
      imagePath: 'assets/images/vocabulary/animals/Horse.png',
    ),
    AnimalItem(
      word: 'Kangaroo',
      thaiPhonetics: 'แคง กะ รู',
      translation: 'จิงโจ้',
      imagePath: 'assets/images/vocabulary/animals/Kangaroo.png',
    ),
    AnimalItem(
      word: 'Lion',
      thaiPhonetics: 'ไล เอิน',
      translation: 'สิงโต',
      imagePath: 'assets/images/vocabulary/animals/Lion.png',
    ),
    AnimalItem(
      word: 'Monkey',
      thaiPhonetics: 'มัง คี',
      translation: 'ลิง',
      imagePath: 'assets/images/vocabulary/animals/Monkey.png',
    ),
    AnimalItem(
      word: 'Octopus',
      thaiPhonetics: 'อ็อค โท พุส',
      translation: 'ปลาหมึกยักษ์',
      imagePath: 'assets/images/vocabulary/animals/Octopus.png',
    ),
    AnimalItem(
      word: 'Owl',
      thaiPhonetics: 'เอาล์',
      translation: 'นกฮูก',
      imagePath: 'assets/images/vocabulary/animals/Owl.png',
    ),
    AnimalItem(
      word: 'Panda',
      thaiPhonetics: 'แพน ด้า',
      translation: 'แพนด้า',
      imagePath: 'assets/images/vocabulary/animals/Panda.png',
    ),
    AnimalItem(
      word: 'Penguin',
      thaiPhonetics: 'เพน กวิน',
      translation: 'เพนกวิน',
      imagePath: 'assets/images/vocabulary/animals/Penguin.png',
    ),
    AnimalItem(
      word: 'Pig',
      thaiPhonetics: 'พิก',
      translation: 'หมู',
      imagePath: 'assets/images/vocabulary/animals/Pig.png',
    ),
    AnimalItem(
      word: 'Rabbit',
      thaiPhonetics: 'แรบ บิท',
      translation: 'กระต่าย',
      imagePath: 'assets/images/vocabulary/animals/Rabbit.png',
    ),
    AnimalItem(
      word: 'Sheep',
      thaiPhonetics: 'ชีพ',
      translation: 'แกะ',
      imagePath: 'assets/images/vocabulary/animals/Sheep.png',
    ),
    AnimalItem(
      word: 'Tiger',
      thaiPhonetics: 'ไท เกอร์',
      translation: 'เสือ',
      imagePath: 'assets/images/vocabulary/animals/Tiger.png',
    ),
    AnimalItem(
      word: 'Turtle',
      thaiPhonetics: 'เทอร์ เทิล',
      translation: 'เต่า',
      imagePath: 'assets/images/vocabulary/animals/Turtle.png',
    ),
    AnimalItem(
      word: 'Whale',
      thaiPhonetics: 'เวล',
      translation: 'วาฬ',
      imagePath: 'assets/images/vocabulary/animals/Whale.png',
    ),
    AnimalItem(
      word: 'Zebra',
      thaiPhonetics: 'ซี บรา',
      translation: 'ม้าลาย',
      imagePath: 'assets/images/vocabulary/animals/Zebra.png',
    ),
    AnimalItem(
      word: 'Crocodile',
      thaiPhonetics: 'ครอค โค ไดล์',
      translation: 'จระเข้',
      imagePath: 'assets/images/vocabulary/animals/Crocodile.png',
    ),
    AnimalItem(
      word: 'Koala',
      thaiPhonetics: 'โค อา ลา',
      translation: 'โคอาลา',
      imagePath: 'assets/images/vocabulary/animals/Koala.png',
    ),
    AnimalItem(
      word: 'Mosquito',
      thaiPhonetics: 'มอส คี โท',
      translation: 'ยุง',
      imagePath: 'assets/images/vocabulary/animals/Mosquito.png',
    ),
    AnimalItem(
      word: 'Peacock',
      thaiPhonetics: 'พี ค็อก',
      translation: 'นกยูง',
      imagePath: 'assets/images/vocabulary/animals/Peacock.png',
    ),
    AnimalItem(
      word: 'Shrimp',
      thaiPhonetics: 'ชริมพ์',
      translation: 'กุ้ง',
      imagePath: 'assets/images/vocabulary/animals/Shrimp.png',
    ),
    AnimalItem(
      word: 'Snake',
      thaiPhonetics: 'สเนค',
      translation: 'งู',
      imagePath: 'assets/images/vocabulary/animals/Snake.png',
    ),
    AnimalItem(
      word: 'Spider',
      thaiPhonetics: 'สไป เดอร์',
      translation: 'แมงมุม',
      imagePath: 'assets/images/vocabulary/animals/Spider.png',
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
      final words = await VocabularyApiService.getWords('animal');
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

  List<QuizItem> _generateAnimalQuiz() {
    final List<QuizItem> quizList = [];
    final List<AnimalItem> shuffledList = List<AnimalItem>.from(animals)
      ..shuffle();

    for (int i = 0; i < 10 && i < shuffledList.length; i++) {
      final current = shuffledList[i];
      final otherOptions =
          animals.where((item) => item.word != current.word).toList()
            ..shuffle();

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
    final saved = await LessonProgress.load('vocab_animal', _wordCount);
    if (!mounted || saved == null) return;
    final api = _apiWords;
    final preview =
        api != null ? api[saved.index].term : animals[saved.index].word;
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
      LessonProgress.clear('vocab_animal');
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
      if (currentIndex >= animals.length) return;
      word = animals[currentIndex].word;
    }
    VocabularyProgress.markLearned('animal', word);
  }

  void _nextWord() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => isSpeaking = false);
    _markCurrentWordLearned();

    if (currentIndex < _wordCount - 1) {
      setState(() => currentIndex++);
      LessonProgress.save('vocab_animal', currentIndex, 0);
    } else {
      // Went through every word: next time start from the first one.
      LessonProgress.clear('vocab_animal');
      VocabularyProgress.markCategoryDone('animal'); // green dot
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => GraduationScreen(
                categoryTitle: 'สัตว์',
                categorySlug: 'animal',
                quizItems: _generateAnimalQuiz(),
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
      LessonProgress.save('vocab_animal', currentIndex, 0);
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

    final VocabularyWordView currentAnimal = _apiWords == null
        ? animals[currentIndex]
        : _apiWords![currentIndex];
    final progress = (currentIndex + 1) / _wordCount;
    final double cardImageHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: const Color(0xFF1886E4),
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
          'คำศัพท์หมวดสัตว์',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900, // หรือ FontWeight.bold
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
              border: Border.all(color: const Color.fromARGB(255, 9, 98, 194), width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 14, 111, 201).withValues(alpha: 0.35),
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
                            Icons.pets_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'สัตว์',
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

                // กรอบรูปภาพ: เขียวมินต์พาสเทล
                Container(
                  height: cardImageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 232, 197),
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
                          currentAnimal.imagePath,
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

                // โซนแสดงคำศัพท์ (สไตล์ที่ 2)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey<int>(currentIndex),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currentAnimal.word,
                            style: GoogleFonts.fredoka(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _speak(currentAnimal.word, currentAnimal.audioUrl),
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color:
                                    isSpeaking
                                        ? const Color(0xFF00C853)
                                        : const Color(0xFF1886E4),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0D47A1,
                                    ).withValues(alpha: 0.3),
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
                        currentAnimal.thaiPhonetics,
                        style: GoogleFonts.mitr(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // คำแปลภาษาไทย สีส้มสดใสขนาดใหญ่
                      Text(
                        currentAnimal.translation,
                        style: GoogleFonts.mitr(
                          fontSize: 36,
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
