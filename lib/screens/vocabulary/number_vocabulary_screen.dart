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

class NumberItem implements VocabularyWordView {
  final String word;
  final String thaiPhonetics;
  final String translation;
  final String imagePath;

  NumberItem({
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

class NumberVocabularyScreen extends StatefulWidget {
  const NumberVocabularyScreen({super.key});

  @override
  State<NumberVocabularyScreen> createState() => _NumberVocabularyScreenState();
}

class _NumberVocabularyScreenState extends State<NumberVocabularyScreen> {
  int currentIndex = 0;
  List<VocabularyWord>? _apiWords;
  bool _isLoading = true;
  String? _loadError;

  int get _wordCount => _apiWords?.length ?? numbers.length;
  late AudioPlayer _audioPlayer;
  bool isSpeaking = false;

  // 🔢 ข้อมูลคำศัพท์หมวดตัวเลข (Number) ครบ 38 คำ เรียงลำดับจาก 0 ถึง 100
  final List<NumberItem> numbers = [
    NumberItem(
      word: 'Zero',
      thaiPhonetics: 'ซี โร',
      translation: '0 (ศูนย์)',
      imagePath: 'assets/images/vocabulary/numbers/Zero.png',
    ),
    NumberItem(
      word: 'One',
      thaiPhonetics: 'วัน',
      translation: '1 (หนึ่ง)',
      imagePath: 'assets/images/vocabulary/numbers/One.png',
    ),
    NumberItem(
      word: 'Two',
      thaiPhonetics: 'ทู',
      translation: '2 (สอง)',
      imagePath: 'assets/images/vocabulary/numbers/Two.png',
    ),
    NumberItem(
      word: 'Three',
      thaiPhonetics: 'ทรี',
      translation: '3 (สาม)',
      imagePath: 'assets/images/vocabulary/numbers/Three.png',
    ),
    NumberItem(
      word: 'Four',
      thaiPhonetics: 'ฟอร์',
      translation: '4 (สี่)',
      imagePath: 'assets/images/vocabulary/numbers/Four.png',
    ),
    NumberItem(
      word: 'Five',
      thaiPhonetics: 'ไฟฟ์',
      translation: '5 (ห้า)',
      imagePath: 'assets/images/vocabulary/numbers/Five.png',
    ),
    NumberItem(
      word: 'Six',
      thaiPhonetics: 'ซิกส์',
      translation: '6 (หก)',
      imagePath: 'assets/images/vocabulary/numbers/Six.png',
    ),
    NumberItem(
      word: 'Seven',
      thaiPhonetics: 'เซฟ เวิน',
      translation: '7 (เจ็ด)',
      imagePath: 'assets/images/vocabulary/numbers/Seven.png',
    ),
    NumberItem(
      word: 'Eight',
      thaiPhonetics: 'เอท',
      translation: '8 (แปด)',
      imagePath: 'assets/images/vocabulary/numbers/Eight.png',
    ),
    NumberItem(
      word: 'Nine',
      thaiPhonetics: 'ไนน์',
      translation: '9 (เก้า)',
      imagePath: 'assets/images/vocabulary/numbers/Nine.png',
    ),
    NumberItem(
      word: 'Ten',
      thaiPhonetics: 'เทน',
      translation: '10 (สิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Ten.png',
    ),
    NumberItem(
      word: 'Eleven',
      thaiPhonetics: 'อิ เลฟ เวิน',
      translation: '11 (สิบเอ็ด)',
      imagePath: 'assets/images/vocabulary/numbers/Eleven.png',
    ),
    NumberItem(
      word: 'Twelve',
      thaiPhonetics: 'ทเวลฟ์',
      translation: '12 (สิบสอง)',
      imagePath: 'assets/images/vocabulary/numbers/Twelve.png',
    ),
    NumberItem(
      word: 'Thirteen',
      thaiPhonetics: 'เธิร์ ทีน',
      translation: '13 (สิบสาม)',
      imagePath: 'assets/images/vocabulary/numbers/Thirteen.png',
    ),
    NumberItem(
      word: 'Fourteen',
      thaiPhonetics: 'ฟอร์ ทีน',
      translation: '14 (สิบสี่)',
      imagePath: 'assets/images/vocabulary/numbers/Fourteen.png',
    ),
    NumberItem(
      word: 'Fifteen',
      thaiPhonetics: 'ฟิฟ ทีน',
      translation: '15 (สิบห้า)',
      imagePath: 'assets/images/vocabulary/numbers/Fifteen.png',
    ),
    NumberItem(
      word: 'Sixteen',
      thaiPhonetics: 'ซิกส์ ทีน',
      translation: '16 (สิบหก)',
      imagePath: 'assets/images/vocabulary/numbers/Sixteen.png',
    ),
    NumberItem(
      word: 'Seventeen',
      thaiPhonetics: 'เซฟ เวิน ทีน',
      translation: '17 (สิบเจ็ด)',
      imagePath: 'assets/images/vocabulary/numbers/Seventeen.png',
    ),
    NumberItem(
      word: 'Eighteen',
      thaiPhonetics: 'เอท ทีน',
      translation: '18 (สิบแปด)',
      imagePath: 'assets/images/vocabulary/numbers/Eighteen.png',
    ),
    NumberItem(
      word: 'Nineteen',
      thaiPhonetics: 'ไนน์ ทีน',
      translation: '19 (สิบเก้า)',
      imagePath: 'assets/images/vocabulary/numbers/Nineteen.png',
    ),
    NumberItem(
      word: 'Twenty',
      thaiPhonetics: 'ทเวน ที',
      translation: '20 (ยี่สิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty.png',
    ),
    NumberItem(
      word: 'Twenty-one',
      thaiPhonetics: 'ทเวน ที วัน',
      translation: '21 (ยี่สิบเอ็ด)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-one.png',
    ),
    NumberItem(
      word: 'Twenty-two',
      thaiPhonetics: 'ทเวน ที ทู',
      translation: '22 (ยี่สิบสอง)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-two.png',
    ),
    NumberItem(
      word: 'Twenty-three',
      thaiPhonetics: 'ทเวน ที ทรี',
      translation: '23 (ยี่สิบสาม)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-three.png',
    ),
    NumberItem(
      word: 'Twenty-four',
      thaiPhonetics: 'ทเวน ที ฟอร์',
      translation: '24 (ยี่สิบสี่)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-four.png',
    ),
    NumberItem(
      word: 'Twenty-five',
      thaiPhonetics: 'ทเวน ที ไฟฟ์',
      translation: '25 (ยี่สิบห้า)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-five.png',
    ),
    NumberItem(
      word: 'Twenty-six',
      thaiPhonetics: 'ทเวน ที ซิกส์',
      translation: '26 (ยี่สิบหก)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-six.png',
    ),
    NumberItem(
      word: 'Twenty-seven',
      thaiPhonetics: 'ทเวน ที เซฟ เวิน',
      translation: '27 (ยี่สิบเจ็ด)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-seven.png',
    ),
    NumberItem(
      word: 'Twenty-eight',
      thaiPhonetics: 'ทเวน ที เอท',
      translation: '28 (ยี่สิบแปด)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-eight.png',
    ),
    NumberItem(
      word: 'Twenty-nine',
      thaiPhonetics: 'ทเวน ที ไนน์',
      translation: '29 (ยี่สิบเก้า)',
      imagePath: 'assets/images/vocabulary/numbers/Twenty-nine.png',
    ),
    NumberItem(
      word: 'Thirty',
      thaiPhonetics: 'เธิร์ ที',
      translation: '30 (สามสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Thirty.png',
    ),
    NumberItem(
      word: 'Forty',
      thaiPhonetics: 'ฟอร์ ที',
      translation: '40 (สี่สิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Forty.png',
    ),
    NumberItem(
      word: 'Fifty',
      thaiPhonetics: 'ฟิฟ ที',
      translation: '50 (ห้าสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Fifty.png',
    ),
    NumberItem(
      word: 'Sixty',
      thaiPhonetics: 'ซิกส์ ที',
      translation: '60 (หกสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Sixty.png',
    ),
    NumberItem(
      word: 'Seventy',
      thaiPhonetics: 'เซฟ เวิน ที',
      translation: '70 (เจ็ดสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Seventy.png',
    ),
    NumberItem(
      word: 'Eighty',
      thaiPhonetics: 'เอท ที',
      translation: '80 (แปดสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Eighty.png',
    ),
    NumberItem(
      word: 'Ninety',
      thaiPhonetics: 'ไนน์ ที',
      translation: '90 (เก้าสิบ)',
      imagePath: 'assets/images/vocabulary/numbers/Ninety.png',
    ),
    NumberItem(
      word: 'One hundred',
      thaiPhonetics: 'วัน ฮัน เดริด',
      translation: '100 (หนึ่งร้อย)',
      imagePath: 'assets/images/vocabulary/numbers/One hundred.png',
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
      final words = await VocabularyApiService.getWords('number');
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

  // สร้างแบบทดสอบสุ่ม 10 ข้อสำหรับหมวดตัวเลข
  List<QuizItem> _generateNumberQuiz() {
    final List<QuizItem> quizList = [];
    final List<NumberItem> shuffledList =
        List<NumberItem>.from(numbers)..shuffle();

    for (int i = 0; i < 10 && i < shuffledList.length; i++) {
      final current = shuffledList[i];
      final otherOptions =
          numbers.where((item) => item.word != current.word).toList()..shuffle();

      if (i % 2 == 0) {
        // รูปแบบที่ 1: ดูรูปภาพ -> เลือกคำศัพท์
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
        // รูปแบบที่ 2: ดูคำศัพท์ -> เลือกรูปภาพ
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
    final saved = await LessonProgress.load('vocab_number', _wordCount);
    if (!mounted || saved == null) return;
    final api = _apiWords;
    final preview =
        api != null ? api[saved.index].term : numbers[saved.index].word;
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
      LessonProgress.clear('vocab_number');
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
      if (currentIndex >= numbers.length) return;
      word = numbers[currentIndex].word;
    }
    VocabularyProgress.markLearned('number', word);
  }

  void _nextWord() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => isSpeaking = false);
    _markCurrentWordLearned();

    if (currentIndex < _wordCount - 1) {
      setState(() => currentIndex++);
      LessonProgress.save('vocab_number', currentIndex, 0);
    } else {
      // Went through every word: next time start from the first one.
      LessonProgress.clear('vocab_number');
      VocabularyProgress.markCategoryDone('number'); // green dot
      if (!mounted) return;
      // เปิดหน้า GraduationScreen เพื่อเตรียมเริ่มทำแบบฝึกหัด
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => GraduationScreen(
                categoryTitle: 'ตัวเลข',
                categorySlug: 'number',
                quizItems: _generateNumberQuiz(),
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
      LessonProgress.save('vocab_number', currentIndex, 0);
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

    final VocabularyWordView currentNumber = _apiWords == null
        ? numbers[currentIndex]
        : _apiWords![currentIndex];
    final progress = (currentIndex + 1) / _wordCount;
    final double cardImageHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32), // สีเขียวสดใสตามการ์ดหมวดตัวเลข
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
          'คำศัพท์หมวดตัวเลข',
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
              // สีกรอบเข้ม: เขียวเข้มจัด (Forest Green)
              border: Border.all(color: const Color.fromARGB(255, 41, 103, 44), width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F3813).withOpacity(0.35),
                  offset: const Offset(0, 10),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
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
                            Icons.format_list_numbered_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ตัวเลข',
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
                              text: ' / ${_wordCount}',
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
                        color: Colors.black.withOpacity(0.06),
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

                // กรอบรูปภาพ: สีม่วงไลแลคอ่อนพาสเทล (คู่ตรงข้ามกับสีเขียว ไม่ซ้ำหมวดอื่น)
                Container(
                  height: cardImageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 227, 255, 208),
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
                          currentNumber.imagePath,
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
                              currentNumber.word,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fredoka(
                                fontSize:
                                    currentNumber.word.length > 11 ? 32 : 42,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _speak(currentNumber.word, currentNumber.audioUrl),
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color:
                                    isSpeaking
                                        ? const Color(0xFF00C853)
                                        : const Color(0xFF2E7D32), // ปุ่มลำโพงโทนเดียวกับจอ
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1B5E20).withOpacity(0.35),
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
                      // คำอ่านภาษาไทย: เว้นวรรคตามพยางค์
                      Text(
                        currentNumber.thaiPhonetics,
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
                        currentNumber.translation,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.mitr(
                          fontSize: 34,
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
