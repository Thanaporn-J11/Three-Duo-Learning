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

class DailyRoutineItem implements VocabularyWordView {
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

  DailyRoutineItem({
    required this.word,
    this.phonetics = '',
    required this.thaiPhonetics,
    required this.translation,
    required this.imagePath,
  });
  @override
  String? get audioUrl => null;

}

class DailyRoutineVocabularyScreen extends StatefulWidget {
  const DailyRoutineVocabularyScreen({super.key});

  @override
  State<DailyRoutineVocabularyScreen> createState() =>
      _DailyRoutineVocabularyScreenState();
}

class _DailyRoutineVocabularyScreenState
    extends State<DailyRoutineVocabularyScreen> {
  int currentIndex = 0;
  List<VocabularyWord>? _apiWords;
  bool _isLoading = true;
  String? _loadError;

  int get _wordCount => _apiWords?.length ?? routines.length;
  late AudioPlayer _audioPlayer;
  bool isSpeaking = false;

  final List<DailyRoutineItem> routines = [
    DailyRoutineItem(
      word: 'Brush my teeth',
      phonetics: '/brʌʃ maɪ tiːθ/',
      thaiPhonetics: 'บรัช มาย ทีธ',
      translation: 'แปรงฟัน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Brushmyteeth.png',
    ),
    DailyRoutineItem(
      word: 'Clean my room',
      phonetics: '/kliːn maɪ ruːm/',
      thaiPhonetics: 'คลีน มาย รูม',
      translation: 'ทำความสะอาดห้อง',
      imagePath: 'assets/images/vocabulary/dailyroutine/Cleanmyroom.png',
    ),
    DailyRoutineItem(
      word: 'Comb my hair',
      phonetics: '/kəʊm maɪ heər/',
      thaiPhonetics: 'โคม มาย แฮร์',
      translation: 'หวีผม',
      imagePath: 'assets/images/vocabulary/dailyroutine/Combmyhair.png',
    ),
    DailyRoutineItem(
      word: 'Do homework',
      phonetics: '/duː ˈhəʊm.wɜːk/',
      thaiPhonetics: 'ดู โฮม เวิร์ก',
      translation: 'ทำการบ้าน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Dohomework.png',
    ),
    DailyRoutineItem(
      word: 'Dream',
      phonetics: '/driːm/',
      thaiPhonetics: 'ดรีม',
      translation: 'ฝัน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Dream.png',
    ),
    DailyRoutineItem(
      word: 'Drink water',
      phonetics: '/drɪŋk ˈwɔː.tər/',
      thaiPhonetics: 'ดริงก์ วอ เทอะ',
      translation: 'ดื่มน้ำ',
      imagePath: 'assets/images/vocabulary/dailyroutine/Drinkwater.png',
    ),
    DailyRoutineItem(
      word: 'Exercise',
      phonetics: '/ˈek.sə.saɪz/',
      thaiPhonetics: 'เอ็ก เซอะ ไซส์',
      translation: 'ออกกำลังกาย',
      imagePath: 'assets/images/vocabulary/dailyroutine/Exercise.png',
    ),
    DailyRoutineItem(
      word: 'Get dressed',
      phonetics: '/ɡet drest/',
      thaiPhonetics: 'เก็ต เดรสต์',
      translation: 'แต่งตัว',
      imagePath: 'assets/images/vocabulary/dailyroutine/Getdressed.png',
    ),
    DailyRoutineItem(
      word: 'Get up',
      phonetics: '/ɡet ʌp/',
      thaiPhonetics: 'เก็ต อัป',
      translation: 'ลุกขึ้นจากที่นอน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Getup.png',
    ),
    DailyRoutineItem(
      word: 'Go home',
      phonetics: '/ɡəʊ həʊm/',
      thaiPhonetics: 'โก โฮม',
      translation: 'กลับบ้าน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Gohome.png',
    ),
    DailyRoutineItem(
      word: 'Go shopping',
      phonetics: '/ɡəʊ ˈʃɒp.ɪŋ/',
      thaiPhonetics: 'โก ช็อป ปิง',
      translation: 'ไปซื้อของ',
      imagePath: 'assets/images/vocabulary/dailyroutine/Goshopping.png',
    ),
    DailyRoutineItem(
      word: 'Go to school',
      phonetics: '/ɡəʊ tuː skuːl/',
      thaiPhonetics: 'โก ทู สคูล',
      translation: 'ไปโรงเรียน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Gotoschool.png',
    ),
    DailyRoutineItem(
      word: 'Have breakfast',
      phonetics: '/hæv ˈbrek.fəst/',
      thaiPhonetics: 'แฮฟ เบรค เฟิสต์',
      translation: 'รับประทานอาหารเช้า',
      imagePath: 'assets/images/vocabulary/dailyroutine/Havebreakfast.png',
    ),
    DailyRoutineItem(
      word: 'Listen',
      phonetics: '/ˈlɪs.ən/',
      thaiPhonetics: 'ลิส เซิน',
      translation: 'ฟัง',
      imagePath: 'assets/images/vocabulary/dailyroutine/Listen.png',
    ),
    DailyRoutineItem(
      word: 'Make my bed',
      phonetics: '/meɪk maɪ bed/',
      thaiPhonetics: 'เมค มาย เบด',
      translation: 'จัดที่นอน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Makemybed.png',
    ),
    DailyRoutineItem(
      word: 'Meet my friends',
      phonetics: '/miːt maɪ frendz/',
      thaiPhonetics: 'มีท มาย เฟรนดส์',
      translation: 'พบปะเพื่อนๆ',
      imagePath: 'assets/images/vocabulary/dailyroutine/Meetmyfriends.png',
    ),
    DailyRoutineItem(
      word: 'Pack my bag',
      phonetics: '/pæk maɪ bæɡ/',
      thaiPhonetics: 'แพ็ก มาย แบ็ก',
      translation: 'จัดกระเป๋า',
      imagePath: 'assets/images/vocabulary/dailyroutine/Packmybag.png',
    ),
    DailyRoutineItem(
      word: 'Play games',
      phonetics: '/pleɪ ɡeɪmz/',
      thaiPhonetics: 'เพลย์ เกมส์',
      translation: 'เล่นเกม',
      imagePath: 'assets/images/vocabulary/dailyroutine/Playgames.png',
    ),
    DailyRoutineItem(
      word: 'Read',
      phonetics: '/riːd/',
      thaiPhonetics: 'รีด',
      translation: 'อ่าน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Read.png',
    ),
    DailyRoutineItem(
      word: 'Read a book',
      phonetics: '/riːd ə bʊk/',
      thaiPhonetics: 'รีด อะ บุ๊ก',
      translation: 'อ่านหนังสือ',
      imagePath: 'assets/images/vocabulary/dailyroutine/Readabook.png',
    ),
    DailyRoutineItem(
      word: 'Ride a bike',
      phonetics: '/raɪd ə baɪk/',
      thaiPhonetics: 'ไรด์ อะ ไบค์',
      translation: 'ปั่นจักรยาน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Rideabike.png',
    ),
    DailyRoutineItem(
      word: 'Sleep',
      phonetics: '/sliːp/',
      thaiPhonetics: 'สลีป',
      translation: 'นอนหลับ',
      imagePath: 'assets/images/vocabulary/dailyroutine/Sleep.png',
    ),
    DailyRoutineItem(
      word: 'Study',
      phonetics: '/ˈstʌd.i/',
      thaiPhonetics: 'สตัด ดี',
      translation: 'เรียนหนังสือ',
      imagePath: 'assets/images/vocabulary/dailyroutine/Study.png',
    ),
    DailyRoutineItem(
      word: 'Take a bath',
      phonetics: '/teɪk ə bɑːθ/',
      thaiPhonetics: 'เทค อะ บาธ',
      translation: 'แช่อ่างอาบน้ำ',
      imagePath: 'assets/images/vocabulary/dailyroutine/Takeabath.png',
    ),
    DailyRoutineItem(
      word: 'Take a shower',
      phonetics: '/teɪk ə ˈʃaʊ.ər/',
      thaiPhonetics: 'เทค อะ เชา เวอะ',
      translation: 'อาบน้ำฝักบัว',
      imagePath: 'assets/images/vocabulary/dailyroutine/Takeashower.png',
    ),
    DailyRoutineItem(
      word: 'Wake up',
      phonetics: '/weɪk ʌp/',
      thaiPhonetics: 'เวค อัป',
      translation: 'ตื่นนอน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Wakeup.png',
    ),
    DailyRoutineItem(
      word: 'Wash my face',
      phonetics: '/wɒʃ maɪ feɪs/',
      thaiPhonetics: 'วอช มาย เฟซ',
      translation: 'ล้างหน้า',
      imagePath: 'assets/images/vocabulary/dailyroutine/Washmyface.png',
    ),
    DailyRoutineItem(
      word: 'Wash the dishes',
      phonetics: '/wɒʃ ðə dɪʃ.ɪz/',
      thaiPhonetics: 'วอช เดอะ ดิช ชิซ',
      translation: 'ล้างจาน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Washthedishes.png',
    ),
    DailyRoutineItem(
      word: 'Watch TV',
      phonetics: '/wɒtʃ ˌtiːˈviː/',
      thaiPhonetics: 'วอทช์ ที วี',
      translation: 'ดูโทรทัศน์',
      imagePath: 'assets/images/vocabulary/dailyroutine/WatchTV.png',
    ),
    DailyRoutineItem(
      word: 'Write',
      phonetics: '/raɪt/',
      thaiPhonetics: 'ไรต์',
      translation: 'เขียน',
      imagePath: 'assets/images/vocabulary/dailyroutine/Write.png',
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
      final words = await VocabularyApiService.getWords('daily-routine');
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

  List<QuizItem> _generateRoutineQuiz() {
    final List<QuizItem> quizList = [];
    final List<DailyRoutineItem> shuffledList =
        List<DailyRoutineItem>.from(routines)..shuffle();

    for (int i = 0; i < 10 && i < shuffledList.length; i++) {
      final current = shuffledList[i];
      final otherOptions =
          routines.where((item) => item.word != current.word).toList()..shuffle();

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
    final saved = await LessonProgress.load('vocab_daily-routine', _wordCount);
    if (!mounted || saved == null) return;
    final api = _apiWords;
    final preview =
        api != null ? api[saved.index].term : routines[saved.index].word;
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
      LessonProgress.clear('vocab_daily-routine');
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
      if (currentIndex >= routines.length) return;
      word = routines[currentIndex].word;
    }
    VocabularyProgress.markLearned('daily-routine', word);
  }

  void _nextWord() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => isSpeaking = false);
    _markCurrentWordLearned();

    if (currentIndex < _wordCount - 1) {
      setState(() => currentIndex++);
      LessonProgress.save('vocab_daily-routine', currentIndex, 0);
    } else {
      // Went through every word: next time start from the first one.
      LessonProgress.clear('vocab_daily-routine');
      VocabularyProgress.markCategoryDone('daily-routine'); // green dot
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => GraduationScreen(
                categoryTitle: 'กิจวัตรประจำวัน',
                categorySlug: 'daily-routine',
                quizItems: _generateRoutineQuiz(),
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
      LessonProgress.save('vocab_daily-routine', currentIndex, 0);
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
        ? routines[currentIndex]
        : _apiWords![currentIndex];
    final progress = (currentIndex + 1) / _wordCount;
    final double cardImageHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: const Color(0xFF006D77), // สีทีลเข้มอมน้ำเงินตามการ์ดหมวดหมู่
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
          'คำศัพท์หมวดกิจวัตรประจำวัน',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
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
              // สีกรอบเข้ม: สีทีลเข้มจัด
              border: Border.all(color: const Color(0xFF00383D), width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF002226).withValues(alpha: 0.35),
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
                            Icons.schedule_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'กิจวัตรประจำวัน',
                            style: GoogleFonts.mitr(
                              fontSize: 13,
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

                // กรอบรูปภาพ: สีชมพูพาสเทลอ่อน (คู่ตรงข้ามกับทีล ไม่ซ้ำหมวดอื่น)
                Container(
                  height: cardImageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F5FE),
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
                                    currentItem.word.length > 14 ? 28 : (currentItem.word.length > 10 ? 34 : 40),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _speak(currentItem.word, currentItem.audioUrl),
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color:
                                    isSpeaking
                                        ? const Color(0xFF00C853)
                                        : const Color(0xFF006D77), // ลำโพงโทนสีเดียวกับพื้นหลังจอ
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00383D).withValues(alpha: 0.35),
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
                      // คำอ่านภาษาไทย (เว้นวรรคตามพยางค์)
                      Text(
                        currentItem.thaiPhonetics.replaceAll('-', ' '),
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
