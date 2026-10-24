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

class CareerItem implements VocabularyWordView {
  final String word;
  final String phonetics;
  final String translation;
  final String imagePath;

  CareerItem({
    required this.word,
    required this.phonetics,
    required this.translation,
    required this.imagePath,
  });

  @override
  String get thaiPhonetics => phonetics;

  @override
  String? get audioUrl => null;

}

class CareerVocabularyScreen extends StatefulWidget {
  const CareerVocabularyScreen({super.key});

  @override
  State<CareerVocabularyScreen> createState() => _CareerVocabularyScreenState();
}

class _CareerVocabularyScreenState extends State<CareerVocabularyScreen> {
  int currentIndex = 0;
  List<VocabularyWord>? _apiWords;
  bool _isLoading = true;
  String? _loadError;

  int get _wordCount => _apiWords?.length ?? careers.length;
  late AudioPlayer _audioPlayer;
  bool isSpeaking = false;

  final List<CareerItem> careers = [
    // --- 30 อาชีพเดิม ---
    CareerItem(
      word: 'Accountant',
      phonetics: 'อะ เคาท์ เทินท์',
      translation: 'นักบัญชี',
      imagePath: 'assets/images/vocabulary/careers/Accountant.png',
    ),
    CareerItem(
      word: 'Architect',
      phonetics: 'อาร์ คิ เท็คท์',
      translation: 'สถาปนิก',
      imagePath: 'assets/images/vocabulary/careers/Architect.png',
    ),
    CareerItem(
      word: 'Artist',
      phonetics: 'อาร์ ทิสท์',
      translation: 'ศิลปิน / จิตรกร',
      imagePath: 'assets/images/vocabulary/careers/Artist.png',
    ),
    CareerItem(
      word: 'Carpenter',
      phonetics: 'คาร์ เพน เทอร์',
      translation: 'ช่างไม้',
      imagePath: 'assets/images/vocabulary/careers/Carpenter.png',
    ),
    CareerItem(
      word: 'Cashier',
      phonetics: 'แคช เชียร์',
      translation: 'พนักงานคิดเงิน',
      imagePath: 'assets/images/vocabulary/careers/Cashier.png',
    ),
    CareerItem(
      word: 'Chef',
      phonetics: 'เชฟ',
      translation: 'พ่อครัว / เชฟ',
      imagePath: 'assets/images/vocabulary/careers/Chef.png',
    ),
    CareerItem(
      word: 'Dentist',
      phonetics: 'เดน ทิสท์',
      translation: 'ทันตแพทย์ / หมอฟัน',
      imagePath: 'assets/images/vocabulary/careers/Dentist.png',
    ),
    CareerItem(
      word: 'Doctor',
      phonetics: 'ด็อก เตอร์',
      translation: 'แพทย์ / หมอ',
      imagePath: 'assets/images/vocabulary/careers/Doctor.png',
    ),
    CareerItem(
      word: 'Electrician',
      phonetics: 'อิ เล็ก ทริช เชิน',
      translation: 'ช่างไฟฟ้า',
      imagePath: 'assets/images/vocabulary/careers/Electrician.png',
    ),
    CareerItem(
      word: 'Engineer',
      phonetics: 'เอน จิ เนียร์',
      translation: 'วิศวกร',
      imagePath: 'assets/images/vocabulary/careers/Engineer.png',
    ),
    CareerItem(
      word: 'Farmer',
      phonetics: 'ฟาร์ม เมอร์',
      translation: 'ชาวนา / เกษตรกร',
      imagePath: 'assets/images/vocabulary/careers/Farmer.png',
    ),
    CareerItem(
      word: 'Firefighter',
      phonetics: 'ไฟร์ ไฟท์ เทอร์',
      translation: 'นักดับเพลิง',
      imagePath: 'assets/images/vocabulary/careers/Firefighter.png',
    ),
    CareerItem(
      word: 'Flight Attendant',
      phonetics: 'ไฟลต์ อะ เทน เดินท์',
      translation: 'พนักงานต้อนรับบนเครื่องบิน',
      imagePath: 'assets/images/vocabulary/careers/Flight Attendant.png',
    ),
    CareerItem(
      word: 'Journalist',
      phonetics: 'เจอร์ นะ ลิสท์',
      translation: 'นักข่าว / นักหนังสือพิมพ์',
      imagePath: 'assets/images/vocabulary/careers/Journalist.png',
    ),
    CareerItem(
      word: 'Lawyer',
      phonetics: 'ลอ เยอร์',
      translation: 'ทนายความ',
      imagePath: 'assets/images/vocabulary/careers/Lawyer.png',
    ),
    CareerItem(
      word: 'Mechanic',
      phonetics: 'มะ แคน นิก',
      translation: 'ช่างยนต์ / ช่างเครื่อง',
      imagePath: 'assets/images/vocabulary/careers/Mechanic.png',
    ),
    CareerItem(
      word: 'Musician',
      phonetics: 'มิว ซิช เชิน',
      translation: 'นักดนตรี',
      imagePath: 'assets/images/vocabulary/careers/Musician.png',
    ),
    CareerItem(
      word: 'Nurse',
      phonetics: 'เนิร์ส',
      translation: 'พยาบาล',
      imagePath: 'assets/images/vocabulary/careers/Nurse.png',
    ),
    CareerItem(
      word: 'Pharmacist',
      phonetics: 'ฟาร์ มะ ซิสท์',
      translation: 'เภสัชกร',
      imagePath: 'assets/images/vocabulary/careers/Pharmacist.png',
    ),
    CareerItem(
      word: 'Photographer',
      phonetics: 'ฟะ ท็อก ระ เฟอร์',
      translation: 'ช่างภาพ',
      imagePath: 'assets/images/vocabulary/careers/Photographer.png',
    ),
    CareerItem(
      word: 'Pilot',
      phonetics: 'ไพ ลัท',
      translation: 'นักบิน',
      imagePath: 'assets/images/vocabulary/careers/Pilot.png',
    ),
    CareerItem(
      word: 'Plumber',
      phonetics: 'พลัม เมอร์',
      translation: 'ช่างประปา',
      imagePath: 'assets/images/vocabulary/careers/Plumber.png',
    ),
    CareerItem(
      word: 'Police Officer',
      phonetics: 'พะ ลิส ออฟ ฟิ เซอร์',
      translation: 'เจ้าหน้าที่ตำรวจ',
      imagePath: 'assets/images/vocabulary/careers/Police Officer.png',
    ),
    CareerItem(
      word: 'Programmer',
      phonetics: 'โปร แกรม เมอร์',
      translation: 'โปรแกรมเมอร์',
      imagePath: 'assets/images/vocabulary/careers/Programmer.png',
    ),
    CareerItem(
      word: 'Scientist',
      phonetics: 'ไซ เอิน ทิสท์',
      translation: 'นักวิทยาศาสตร์',
      imagePath: 'assets/images/vocabulary/careers/Scientist.png',
    ),
    CareerItem(
      word: 'Soldier',
      phonetics: 'โซล เจอร์',
      translation: 'ทหาร',
      imagePath: 'assets/images/vocabulary/careers/Soldier.png',
    ),
    CareerItem(
      word: 'Teacher',
      phonetics: 'ทีช เฉอร์',
      translation: 'ครู / อาจารย์',
      imagePath: 'assets/images/vocabulary/careers/Teacher.png',
    ),
    CareerItem(
      word: 'Veterinarian',
      phonetics: 'เวท เทอ ริ แน เรียน',
      translation: 'สัตวแพทย์',
      imagePath: 'assets/images/vocabulary/careers/Veterinarian.png',
    ),
    CareerItem(
      word: 'Waiter',
      phonetics: 'เวท เทอร์',
      translation: 'บริกรชาย',
      imagePath: 'assets/images/vocabulary/careers/Waiter.png',
    ),
    CareerItem(
      word: 'Waitress',
      phonetics: 'เวท เทรส',
      translation: 'บริกรหญิง',
      imagePath: 'assets/images/vocabulary/careers/Waitress.png',
    ),

    // --- 6 อาชีพที่เพิ่มเข้ามาใหม่ ---
    CareerItem(
      word: 'Athlete',
      phonetics: 'แอธ ลีท',
      translation: 'นักกีฬา',
      imagePath: 'assets/images/vocabulary/careers/Athlete.png',
    ),
    CareerItem(
      word: 'Dancer',
      phonetics: 'แดน เซอร์',
      translation: 'นักเต้น',
      imagePath: 'assets/images/vocabulary/careers/Dancer.png',
    ),
    CareerItem(
      word: 'Driver',
      phonetics: 'ไดรฟ์ เวอร์',
      translation: 'คนขับรถ',
      imagePath: 'assets/images/vocabulary/careers/Driver.png',
    ),
    CareerItem(
      word: 'Fisherman',
      phonetics: 'ฟิช เชอร์ แมน',
      translation: 'ชาวประมง',
      imagePath: 'assets/images/vocabulary/careers/Fisherman.png',
    ),
    CareerItem(
      word: 'Postman',
      phonetics: 'โพสต์ แมน',
      translation: 'บุรุษไปรษณีย์',
      imagePath: 'assets/images/vocabulary/careers/Postman.png',
    ),
    CareerItem(
      word: 'Singer',
      phonetics: 'ซิง เกอร์',
      translation: 'นักร้อง',
      imagePath: 'assets/images/vocabulary/careers/Singer.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => isSpeaking = false);
      }
    });
    _loadWords().then((_) => _restorePosition());
  }

  Future<void> _loadWords() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final words = await VocabularyApiService.getWords('career');
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

  List<QuizItem> _generateCareerQuiz() {
    final List<QuizItem> quizList = [];
    final List<CareerItem> shuffledList = List<CareerItem>.from(careers)
      ..shuffle();

    for (int i = 0; i < 10 && i < shuffledList.length; i++) {
      final current = shuffledList[i];
      final otherOptions =
          careers.where((item) => item.word != current.word).toList()
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
    final saved = await LessonProgress.load('vocab_career', _wordCount);
    if (!mounted || saved == null) return;
    final api = _apiWords;
    final preview =
        api != null ? api[saved.index].term : careers[saved.index].word;
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
      LessonProgress.clear('vocab_career');
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
      if (currentIndex >= careers.length) return;
      word = careers[currentIndex].word;
    }
    VocabularyProgress.markLearned('career', word);
  }

  void _nextWord() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => isSpeaking = false);
    _markCurrentWordLearned();

    if (currentIndex < _wordCount - 1) {
      setState(() => currentIndex++);
      LessonProgress.save('vocab_career', currentIndex, 0);
    } else {
      // Went through every word: next time start from the first one.
      LessonProgress.clear('vocab_career');
      VocabularyProgress.markCategoryDone('career'); // green dot
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => GraduationScreen(
                categoryTitle: 'อาชีพ',
                categorySlug: 'career',
                quizItems: _generateCareerQuiz(),
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
      LessonProgress.save('vocab_career', currentIndex, 0);
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

    final VocabularyWordView currentCareer = _apiWords == null
        ? careers[currentIndex]
        : _apiWords![currentIndex];
    final progress = (currentIndex + 1) / _wordCount;
    final double cardImageHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: const Color(
        0xFF3346A2,
      ), // โทนน้ำเงินม่วงเข้มตามการ์ดหมวดอาชีพ
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
          'คำศัพท์หมวดอาชีพ',
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
              // สีกรอบเข้ม: น้ำเงินเนวี่เข้มจัด (Deep Navy)
              border: Border.all(color: const Color(0xFF1A237E), width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F1654).withOpacity(0.35),
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
                            Icons.work_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'อาชีพ',
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

                // กรอบรูปภาพ: สีครีมเหลืองพาสเทล (คู่ตรงข้ามกับน้ำเงินม่วง)
                Container(
                  height: cardImageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
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
                          currentCareer.imagePath,
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
                              currentCareer.word,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fredoka(
                                fontSize:
                                    currentCareer.word.length > 12 ? 34 : 42,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _speak(currentCareer.word, currentCareer.audioUrl),
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color:
                                    isSpeaking
                                        ? const Color(0xFF00C853)
                                        : const Color(
                                          0xFF3346A2,
                                        ), // ปุ่มลำโพงโทนเดียวกับจอ
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF1A237E,
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
                        currentCareer.thaiPhonetics,
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
                        currentCareer.translation,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.mitr(
                          fontSize:
                              currentCareer.translation.length > 14 ? 28 : 34,
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
