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

class ColorItem implements VocabularyWordView {
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

  ColorItem({
    required this.word,
    this.phonetics = '',
    required this.thaiPhonetics,
    required this.translation,
    required this.imagePath,
  });

  @override
  String? get audioUrl => null;
}

class ColorVocabularyScreen extends StatefulWidget {
  const ColorVocabularyScreen({super.key});

  @override
  State<ColorVocabularyScreen> createState() => _ColorVocabularyScreenState();
}

class _ColorVocabularyScreenState extends State<ColorVocabularyScreen> {
  int currentIndex = 0;
  List<VocabularyWord>? _apiWords;
  bool _isLoading = true;
  String? _loadError;

  int get _wordCount => _apiWords?.length ?? colors.length;
  late AudioPlayer _audioPlayer;
  bool isSpeaking = false;

  final List<ColorItem> colors = [
    ColorItem(
      word: 'Black',
      phonetics: '/blæk/',
      thaiPhonetics: 'แบล็ก',
      translation: 'สีดำ',
      imagePath: 'assets/images/vocabulary/colors/black.png',
    ),
    ColorItem(
      word: 'Blue',
      phonetics: '/bluː/',
      thaiPhonetics: 'บลู',
      translation: 'สีน้ำเงิน',
      imagePath: 'assets/images/vocabulary/colors/blue.png',
    ),
    ColorItem(
      word: 'Brown',
      phonetics: '/braʊn/',
      thaiPhonetics: 'บราวน์',
      translation: 'สีน้ำตาล',
      imagePath: 'assets/images/vocabulary/colors/brown.png',
    ),
    ColorItem(
      word: 'Gray',
      phonetics: '/ɡreɪ/',
      thaiPhonetics: 'เกรย์',
      translation: 'สีเทา',
      imagePath: 'assets/images/vocabulary/colors/gray.png',
    ),
    ColorItem(
      word: 'Green',
      phonetics: '/ɡriːn/',
      thaiPhonetics: 'กรีน',
      translation: 'สีเขียว',
      imagePath: 'assets/images/vocabulary/colors/green.png',
    ),
    ColorItem(
      word: 'Light blue',
      phonetics: '/laɪt bluː/',
      thaiPhonetics: 'ไลท์ บลู',
      translation: 'สีฟ้า',
      imagePath: 'assets/images/vocabulary/colors/light blue.png',
    ),
    ColorItem(
      word: 'Orange',
      phonetics: '/ˈɒr.ɪndʒ/',
      thaiPhonetics: 'ออ รินจ์',
      translation: 'สีส้ม',
      imagePath: 'assets/images/vocabulary/colors/orange.png',
    ),
    ColorItem(
      word: 'Pink',
      phonetics: '/pɪŋk/',
      thaiPhonetics: 'พิงก์',
      translation: 'สีชมพู',
      imagePath: 'assets/images/vocabulary/colors/pink.png',
    ),
    ColorItem(
      word: 'Purple',
      phonetics: '/ˈpɜː.pəl/',
      thaiPhonetics: 'เพอร์ เพิล',
      translation: 'สีม่วง',
      imagePath: 'assets/images/vocabulary/colors/purple.png',
    ),
    ColorItem(
      word: 'Red',
      phonetics: '/red/',
      thaiPhonetics: 'เรด',
      translation: 'สีแดง',
      imagePath: 'assets/images/vocabulary/colors/red.png',
    ),
    ColorItem(
      word: 'White',
      phonetics: '/waɪt/',
      thaiPhonetics: 'ไวท์',
      translation: 'สีขาว',
      imagePath: 'assets/images/vocabulary/colors/white.png',
    ),
    ColorItem(
      word: 'Yellow',
      phonetics: '/ˈjel.əʊ/',
      thaiPhonetics: 'เยล โล',
      translation: 'สีเหลือง',
      imagePath: 'assets/images/vocabulary/colors/yellow.png',
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
      final words = await VocabularyApiService.getWords('color');
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

  List<QuizItem> _generateColorQuiz() {
    final List<QuizItem> quizList = [];
    final List<ColorItem> shuffledList =
        List<ColorItem>.from(colors)..shuffle();

    for (int i = 0; i < 10 && i < shuffledList.length; i++) {
      final current = shuffledList[i];
      final otherOptions =
          colors.where((item) => item.word != current.word).toList()..shuffle();

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
    final saved = await LessonProgress.load('vocab_color', _wordCount);
    if (!mounted || saved == null) return;
    final api = _apiWords;
    final preview =
        api != null ? api[saved.index].term : colors[saved.index].word;
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
      LessonProgress.clear('vocab_color');
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
      if (currentIndex >= colors.length) return;
      word = colors[currentIndex].word;
    }
    VocabularyProgress.markLearned('color', word);
  }

  void _nextWord() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => isSpeaking = false);
    _markCurrentWordLearned();

    if (currentIndex < _wordCount - 1) {
      setState(() => currentIndex++);
      LessonProgress.save('vocab_color', currentIndex, 0);
    } else {
      // Went through every word: next time start from the first one.
      LessonProgress.clear('vocab_color');
      VocabularyProgress.markCategoryDone('color'); // green dot
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => GraduationScreen(
                categoryTitle: 'สีสัน',
                categorySlug: 'color',
                quizItems: _generateColorQuiz(),
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
      LessonProgress.save('vocab_color', currentIndex, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const VocabularyApiStatusView(
        title: 'คำศัพท์',
        message: 'กำลังโหลดคำศัพท์...',
        loading: true,
      );
    }
    if (_loadError != null) {
      return VocabularyApiStatusView(
        title: 'คำศัพท์',
        message: 'โหลดคำศัพท์ไม่สำเร็จ $_loadError',
        loading: false,
        onRetry: _loadWords,
        onUseLocal: _useLocalWords,
      );
    }
    if (_apiWords?.isEmpty ?? false) {
      return VocabularyApiStatusView(
        title: 'คำศัพท์',
        message: 'ยังไม่มีคำศัพท์ในหมวดนี้',
        loading: false,
        onRetry: _loadWords,
        onUseLocal: _useLocalWords,
      );
    }

    final VocabularyWordView currentColor = _apiWords == null
        ? colors[currentIndex]
        : _apiWords![currentIndex];
    final progress = (currentIndex + 1) / _wordCount;
    final double cardImageHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: const Color(0xFFE53935), // พื้นหลังจอสีแดงสดประจำหมวดสีสัน
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
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFFB71C1C),
              size: 22,
            ),
            onPressed: () {
              _audioPlayer.stop();
              Navigator.pop(context);
            },
          ),
        ),
        title: const Text(
          'คำศัพท์หมวดสีสัน',
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
              border: Border.all(color: const Color(0xFFB71C1C), width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB71C1C).withValues(alpha: 0.3),
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
                // Category Badge & Counter (สไตล์ 3D Capsule)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.palette_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'สีสัน',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${currentIndex + 1}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF9800),
                              ),
                            ),
                            TextSpan(
                              text: ' / $_wordCount',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // หลอดพลัง Progress Bar สไตล์ 3D
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
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF9800),
                            ),
                          ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // กรอบรูปภาพ: สีขาวล้วน พร้อมเงาจางๆ คลีน สบายตา
                Container(
                  height: cardImageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                          currentColor.imagePath,
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

                // Spacer ด้านบน: ผลักคำศัพท์ให้อยู่ตรงกลางพอดี
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              currentColor.word,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fredoka(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _speak(currentColor.word, currentColor.audioUrl),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    isSpeaking
                                        ? const Color(0xFF00C853)
                                        : const Color(0xFFE53935),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isSpeaking
                                            ? const Color(0xFF00C853)
                                            : const Color(0xFFE53935))
                                        .withValues(alpha: 0.35),
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
                      if (currentColor.phonetics.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          currentColor.phonetics,
                          style: GoogleFonts.fredoka(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade400,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        currentColor.thaiPhonetics
                            .replaceAll(RegExp(r'[-\u2010-\u2015]'), ' ')
                            .replaceAll(RegExp(r'\s+'), ' ')
                            .trim(),
                        style: GoogleFonts.mitr(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentColor.translation,
                        style: GoogleFonts.mitr(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF6D00),
                        ),
                      ),
                    ],
                  ),
                ),

                // Spacer ด้านล่าง: คั่นระยะห่างก่อนถึงปุ่มกด
                const Spacer(),

                // Action Buttons
                Row(
                  children: [
                    // Back Button
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color:
                              currentIndex > 0
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow:
                              currentIndex > 0
                                  ? [
                                    const BoxShadow(
                                      color: Color(0xFFCBD5E1),
                                      offset: Offset(0, 3),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: currentIndex > 0 ? _previousWord : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_back_rounded,
                                  size: 18,
                                  color:
                                      currentIndex > 0
                                          ? const Color(0xFF475569)
                                          : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ย้อนกลับ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color:
                                        currentIndex > 0
                                            ? const Color(0xFF475569)
                                            : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Next Button
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800),
                          borderRadius: BorderRadius.circular(18),
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
                            borderRadius: BorderRadius.circular(18),
                            onTap: _nextWord,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  currentIndex == _wordCount - 1
                                      ? 'เสร็จสิ้น'
                                      : 'ถัดไป',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  currentIndex == _wordCount - 1
                                      ? Icons.check_circle_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ],
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
