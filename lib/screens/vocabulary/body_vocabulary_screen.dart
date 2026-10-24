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

class BodyItem implements VocabularyWordView {
  final String word;
  final String phonetics;
  final String thaiPhonetics;
  final String translation;
  final String imagePath;

  BodyItem({
    required this.word,
    this.phonetics = '',
    required this.thaiPhonetics,
    required this.translation,
    required this.imagePath,
  });
  @override
  String? get audioUrl => null;

}

class BodyVocabularyScreen extends StatefulWidget {
  const BodyVocabularyScreen({super.key});

  @override
  State<BodyVocabularyScreen> createState() => _BodyVocabularyScreenState();
}

class _BodyVocabularyScreenState extends State<BodyVocabularyScreen> {
  int currentIndex = 0;
  List<VocabularyWord>? _apiWords;
  bool _isLoading = true;
  String? _loadError;

  int get _wordCount => _apiWords?.length ?? bodyList.length;
  late AudioPlayer _audioPlayer;
  bool isSpeaking = false;

  final List<BodyItem> bodyList = [
    // --- 10 คำศัพท์เดิม ---
    BodyItem(
      word: 'Arm',
      thaiPhonetics: 'อาร์ม',
      translation: 'แขน',
      imagePath: 'assets/images/vocabulary/body/Arm.png',
    ),
    BodyItem(
      word: 'Ear',
      thaiPhonetics: 'เอียร์',
      translation: 'หู',
      imagePath: 'assets/images/vocabulary/body/Ear.png',
    ),
    BodyItem(
      word: 'Eye',
      thaiPhonetics: 'อาย',
      translation: 'ตา',
      imagePath: 'assets/images/vocabulary/body/Eye.png',
    ),
    BodyItem(
      word: 'Foot',
      thaiPhonetics: 'ฟุต',
      translation: 'เท้า',
      imagePath: 'assets/images/vocabulary/body/Foot.png',
    ),
    BodyItem(
      word: 'Hair',
      thaiPhonetics: 'แฮร์',
      translation: 'ผม',
      imagePath: 'assets/images/vocabulary/body/Hair.png',
    ),
    BodyItem(
      word: 'Hand',
      thaiPhonetics: 'แฮนด์',
      translation: 'มือ',
      imagePath: 'assets/images/vocabulary/body/Hand.png',
    ),
    BodyItem(
      word: 'Head',
      thaiPhonetics: 'เฮด',
      translation: 'ศีรษะ / หัว',
      imagePath: 'assets/images/vocabulary/body/Head.png',
    ),
    BodyItem(
      word: 'Leg',
      thaiPhonetics: 'เลก',
      translation: 'ขา',
      imagePath: 'assets/images/vocabulary/body/Leg.png',
    ),
    BodyItem(
      word: 'Mouth',
      thaiPhonetics: 'เมาธ์',
      translation: 'ปาก',
      imagePath: 'assets/images/vocabulary/body/Mouth.png',
    ),
    BodyItem(
      word: 'Nose',
      thaiPhonetics: 'โนส',
      translation: 'จมูก',
      imagePath: 'assets/images/vocabulary/body/Nose.png',
    ),

    // --- 20 คำศัพท์เพิ่มเติม ---
    BodyItem(
      word: 'Belly',
      thaiPhonetics: 'เบล ลี่',
      translation: 'ท้อง / พุง',
      imagePath: 'assets/images/vocabulary/body/Belly.png',
    ),
    BodyItem(
      word: 'Bone',
      thaiPhonetics: 'โบน',
      translation: 'กระดูก',
      imagePath: 'assets/images/vocabulary/body/Bone.png',
    ),
    BodyItem(
      word: 'Brain',
      thaiPhonetics: 'เบรน',
      translation: 'สมอง',
      imagePath: 'assets/images/vocabulary/body/Brain.png',
    ),
    BodyItem(
      word: 'Cheek',
      thaiPhonetics: 'ชีค',
      translation: 'แก้ม',
      imagePath: 'assets/images/vocabulary/body/Cheek.png',
    ),
    BodyItem(
      word: 'Chest',
      thaiPhonetics: 'เชสต์',
      translation: 'หน้าอก',
      imagePath: 'assets/images/vocabulary/body/Chest.png',
    ),
    BodyItem(
      word: 'Chin',
      thaiPhonetics: 'ชิน',
      translation: 'คาง',
      imagePath: 'assets/images/vocabulary/body/Chin.png',
    ),
    BodyItem(
      word: 'Eyebrow',
      thaiPhonetics: 'อาย เบรา',
      translation: 'คิ้ว',
      imagePath: 'assets/images/vocabulary/body/Eyebrow.png',
    ),
    BodyItem(
      word: 'Eyelash',

      thaiPhonetics: 'อาย แลช',
      translation: 'ขนตา',
      imagePath: 'assets/images/vocabulary/body/Eyelash.png',
    ),
    BodyItem(
      word: 'Face',

      thaiPhonetics: 'เฟซ',
      translation: 'ใบหน้า',
      imagePath: 'assets/images/vocabulary/body/Face.png',
    ),
    BodyItem(
      word: 'Finger',

      thaiPhonetics: 'ฟิง เกอร์',
      translation: 'นิ้วมือ',
      imagePath: 'assets/images/vocabulary/body/Finger.png',
    ),
    BodyItem(
      word: 'Forehead',
      thaiPhonetics: 'ฟอร์ เฮด',
      translation: 'หน้าผาก',
      imagePath: 'assets/images/vocabulary/body/Forehead.png',
    ),
    BodyItem(
      word: 'Heart',
      thaiPhonetics: 'ฮาร์ท',
      translation: 'หัวใจ',
      imagePath: 'assets/images/vocabulary/body/Heart.png',
    ),
    BodyItem(
      word: 'Lip',
      thaiPhonetics: 'ลิป',
      translation: 'ริมฝีปาก',
      imagePath: 'assets/images/vocabulary/body/Lip.png',
    ),
    BodyItem(
      word: 'Lungs',
      thaiPhonetics: 'ลังส์',
      translation: 'ปอด',
      imagePath: 'assets/images/vocabulary/body/Lungs.png',
    ),
    BodyItem(
      word: 'Nail',
      thaiPhonetics: 'เนล',
      translation: 'เล็บ',
      imagePath: 'assets/images/vocabulary/body/Nail.png',
    ),
    BodyItem(
      word: 'Neck',
      thaiPhonetics: 'เน็ค',
      translation: 'คอ',
      imagePath: 'assets/images/vocabulary/body/Neck.png',
    ),
    BodyItem(
      word: 'Shoulder',
      thaiPhonetics: 'โชล เดอร์',
      translation: 'ไหล่',
      imagePath: 'assets/images/vocabulary/body/Shoulder.png',
    ),
    BodyItem(
      word: 'Thigh',
      thaiPhonetics: 'ทาย',
      translation: 'ต้นขา',
      imagePath: 'assets/images/vocabulary/body/Thigh.png',
    ),
    BodyItem(
      word: 'Tongue',
      thaiPhonetics: 'ทัง',
      translation: 'ลิ้น',
      imagePath: 'assets/images/vocabulary/body/Tongue.png',
    ),
    BodyItem(
      word: 'Tooth',
      thaiPhonetics: 'ทูธ',
      translation: 'ฟัน',
      imagePath: 'assets/images/vocabulary/body/Tooth.png',
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
      final words = await VocabularyApiService.getWords('body');
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

  List<QuizItem> _generateBodyQuiz() {
    final List<QuizItem> quizList = [];
    final List<BodyItem> shuffledList = List<BodyItem>.from(bodyList)
      ..shuffle();

    for (int i = 0; i < 10 && i < shuffledList.length; i++) {
      final current = shuffledList[i];
      final otherOptions =
          bodyList.where((item) => item.word != current.word).toList()
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
    final saved = await LessonProgress.load('vocab_body', _wordCount);
    if (!mounted || saved == null) return;
    final api = _apiWords;
    final preview =
        api != null ? api[saved.index].term : bodyList[saved.index].word;
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
      LessonProgress.clear('vocab_body');
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
      if (currentIndex >= bodyList.length) return;
      word = bodyList[currentIndex].word;
    }
    VocabularyProgress.markLearned('body', word);
  }

  void _nextWord() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => isSpeaking = false);
    _markCurrentWordLearned();

    if (currentIndex < _wordCount - 1) {
      setState(() => currentIndex++);
      LessonProgress.save('vocab_body', currentIndex, 0);
    } else {
      // Went through every word: next time start from the first one.
      LessonProgress.clear('vocab_body');
      VocabularyProgress.markCategoryDone('body'); // green dot
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => GraduationScreen(
                categoryTitle: 'ร่างกาย',
                categorySlug: 'body',
                quizItems: _generateBodyQuiz(),
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
      LessonProgress.save('vocab_body', currentIndex, 0);
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

    final VocabularyWordView currentBody = _apiWords == null
        ? bodyList[currentIndex]
        : _apiWords![currentIndex];
    final progress = (currentIndex + 1) / _wordCount;
    final double cardImageHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: const Color(
        0xFF00897B,
      ), // โทนเขียวทีลเดียวกับหน้าหมวดร่างกาย
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
          'คำศัพท์หมวดร่างกาย',
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
              // สีกรอบเข้ม: เขียวหัวเป็ดเข้มจัด (Teal Dark)
              border: Border.all(color: const Color(0xFF004D40), width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00332C).withOpacity(0.35),
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
                            Icons.accessibility_new_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ร่างกาย',
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

                // กรอบรูปภาพ: สีส้มพีชพาสเทล (สีคู่ตรงข้ามกับเขียวทีล ช่วยขับตัวรูปให้เด่น)
                Container(
                  height: cardImageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E6),
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
                          currentBody.imagePath,
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

                // โซนแสดงคำศัพท์ (สไตล์เดียวกับหน้าหมวดสัตว์)
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
                            currentBody.word,
                            style: GoogleFonts.fredoka(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _speak(currentBody.word, currentBody.audioUrl),
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color:
                                    isSpeaking
                                        ? const Color(0xFF00C853)
                                        : const Color(
                                          0xFF00897B,
                                        ), // ปุ่มลำโพงโทนทีล
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF004D40,
                                    ).withOpacity(0.35),
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
                        currentBody.thaiPhonetics,
                        style: GoogleFonts.mitr(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // คำแปลภาษาไทย สีส้มสดใสขนาดใหญ่
                      Text(
                        currentBody.translation,
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
