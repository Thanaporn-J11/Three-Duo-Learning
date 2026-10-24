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

class HouseItem implements VocabularyWordView {
  final String word;
  final String thaiPhonetics;
  final String translation;
  final String imagePath;

  HouseItem({
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

class HouseVocabularyScreen extends StatefulWidget {
  const HouseVocabularyScreen({super.key});

  @override
  State<HouseVocabularyScreen> createState() => _HouseVocabularyScreenState();
}

class _HouseVocabularyScreenState extends State<HouseVocabularyScreen> {
  int currentIndex = 0;
  List<VocabularyWord>? _apiWords;
  bool _isLoading = true;
  String? _loadError;

  int get _wordCount => _apiWords?.length ?? houseItems.length;
  late AudioPlayer _audioPlayer;
  bool isSpeaking = false;

  final List<HouseItem> houseItems = [
    HouseItem(
      word: 'Bathroom',
      thaiPhonetics: 'บาธ รูม',
      translation: 'ห้องน้ำ',
      imagePath: 'assets/images/vocabulary/house/Bathroom.png',
    ),
    HouseItem(
      word: 'Bed',
      thaiPhonetics: 'เบด',
      translation: 'เตียงนอน',
      imagePath: 'assets/images/vocabulary/house/Bed.png',
    ),
    HouseItem(
      word: 'Bedroom',
      thaiPhonetics: 'เบด รูม',
      translation: 'ห้องนอน',
      imagePath: 'assets/images/vocabulary/house/Bedroom.png',
    ),
    HouseItem(
      word: 'Blanket',
      thaiPhonetics: 'แบล็ง คิท',
      translation: 'ผ้าห่ม',
      imagePath: 'assets/images/vocabulary/house/Blanket.png',
    ),
    HouseItem(
      word: 'Chair',
      thaiPhonetics: 'แชร์',
      translation: 'เก้าอี้',
      imagePath: 'assets/images/vocabulary/house/Chair.png',
    ),
    HouseItem(
      word: 'Clock',
      thaiPhonetics: 'คล็อก',
      translation: 'นาฬิกา',
      imagePath: 'assets/images/vocabulary/house/Clock.png',
    ),
    HouseItem(
      word: 'Closet',
      thaiPhonetics: 'คลอ ซิต',
      translation: 'ตู้เสื้อผ้า',
      imagePath: 'assets/images/vocabulary/house/Closet.png',
    ),
    HouseItem(
      word: 'Diningroom',
      thaiPhonetics: 'ได นิง รูม',
      translation: 'ห้องรับประทานอาหาร',
      imagePath: 'assets/images/vocabulary/house/Diningroom.png',
    ),
    HouseItem(
      word: 'Door',
      thaiPhonetics: 'ดอร์',
      translation: 'ประตู',
      imagePath: 'assets/images/vocabulary/house/Door.png',
    ),
    HouseItem(
      word: 'Fan',
      thaiPhonetics: 'แฟน',
      translation: 'พัดลม',
      imagePath: 'assets/images/vocabulary/house/Fan.png',
    ),
    HouseItem(
      word: 'Floor',
      thaiPhonetics: 'ฟลอร์',
      translation: 'พื้นห้อง',
      imagePath: 'assets/images/vocabulary/house/Floor.png',
    ),
    HouseItem(
      word: 'Fork',
      thaiPhonetics: 'ฟอร์ก',
      translation: 'ส้อม',
      imagePath: 'assets/images/vocabulary/house/Fork.png',
    ),
    HouseItem(
      word: 'Garden',
      thaiPhonetics: 'การ์ เดิน',
      translation: 'สวน',
      imagePath: 'assets/images/vocabulary/house/Garden.png',
    ),
    HouseItem(
      word: 'House',
      thaiPhonetics: 'เฮาส์',
      translation: 'บ้าน',
      imagePath: 'assets/images/vocabulary/house/House.png',
    ),
    HouseItem(
      word: 'Kitchen',
      thaiPhonetics: 'คิท ชิน',
      translation: 'ห้องครัว',
      imagePath: 'assets/images/vocabulary/house/Kitchen.png',
    ),
    HouseItem(
      word: 'Lamp',
      thaiPhonetics: 'แลมป์',
      translation: 'โคมไฟ',
      imagePath: 'assets/images/vocabulary/house/Lamp.png',
    ),
    HouseItem(
      word: 'Livingroom',
      thaiPhonetics: 'ลิฟ วิง รูม',
      translation: 'ห้องนั่งเล่น',
      imagePath: 'assets/images/vocabulary/house/Livingroom.png',
    ),
    HouseItem(
      word: 'Mirror',
      thaiPhonetics: 'มิร เรอร์',
      translation: 'กระจกเงา',
      imagePath: 'assets/images/vocabulary/house/Mirror.png',
    ),
    HouseItem(
      word: 'Pillow',
      thaiPhonetics: 'พิล โล',
      translation: 'หมอน',
      imagePath: 'assets/images/vocabulary/house/Pillow.png',
    ),
    HouseItem(
      word: 'Plate',
      thaiPhonetics: 'เพลท',
      translation: 'จาน',
      imagePath: 'assets/images/vocabulary/house/Plate.png',
    ),
    HouseItem(
      word: 'Refrigerator',
      thaiPhonetics: 'รี ฟริจ เจอะ เร เทอะ',
      translation: 'ตู้เย็น',
      imagePath: 'assets/images/vocabulary/house/Refrigerator.png',
    ),
    HouseItem(
      word: 'Roof',
      thaiPhonetics: 'รูฟ',
      translation: 'หลังคา',
      imagePath: 'assets/images/vocabulary/house/Roof.png',
    ),
    HouseItem(
      word: 'Room',
      thaiPhonetics: 'รูม',
      translation: 'ห้อง',
      imagePath: 'assets/images/vocabulary/house/Room.png',
    ),
    HouseItem(
      word: 'Shower',
      thaiPhonetics: 'เชา เวอะ',
      translation: 'ฝักบัวอาบน้ำ',
      imagePath: 'assets/images/vocabulary/house/Shower.png',
    ),
    HouseItem(
      word: 'Soap',
      thaiPhonetics: 'โซพ',
      translation: 'สบู่',
      imagePath: 'assets/images/vocabulary/house/Soap.png',
    ),
    HouseItem(
      word: 'Sofa',
      thaiPhonetics: 'โซ ฟา',
      translation: 'โซฟา',
      imagePath: 'assets/images/vocabulary/house/Sofa.png',
    ),
    HouseItem(
      word: 'Spoon',
      thaiPhonetics: 'สพูน',
      translation: 'ช้อน',
      imagePath: 'assets/images/vocabulary/house/Spoon.png',
    ),
    HouseItem(
      word: 'Stairs',
      thaiPhonetics: 'สแตร์ส',
      translation: 'บันได',
      imagePath: 'assets/images/vocabulary/house/Stairs.png',
    ),
    HouseItem(
      word: 'Table',
      thaiPhonetics: 'เท เบิล',
      translation: 'โต๊ะ',
      imagePath: 'assets/images/vocabulary/house/Table.png',
    ),
    HouseItem(
      word: 'Television',
      thaiPhonetics: 'เทล เลอะ วิช เชิน',
      translation: 'โทรทัศน์',
      imagePath: 'assets/images/vocabulary/house/Television.png',
    ),
    HouseItem(
      word: 'Toilet',
      thaiPhonetics: 'ทอย ลิท',
      translation: 'ชักโครก',
      imagePath: 'assets/images/vocabulary/house/Toilet.png',
    ),
    HouseItem(
      word: 'Towel',
      thaiPhonetics: 'ทาว เอิล',
      translation: 'ผ้าขนหนู',
      imagePath: 'assets/images/vocabulary/house/Towel.png',
    ),
    HouseItem(
      word: 'Wall',
      thaiPhonetics: 'วอลล์',
      translation: 'ฝาผนัง / กำแพง',
      imagePath: 'assets/images/vocabulary/house/Wall.png',
    ),
    HouseItem(
      word: 'Washingmachine',
      thaiPhonetics: 'วอช ชิง มะ ชีน',
      translation: 'เครื่องซักผ้า',
      imagePath: 'assets/images/vocabulary/house/Washingmachine.png',
    ),
    HouseItem(
      word: 'Window',
      thaiPhonetics: 'วิน โดว์',
      translation: 'หน้าต่าง',
      imagePath: 'assets/images/vocabulary/house/Window.png',
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
      final words = await VocabularyApiService.getWords('house');
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

  List<QuizItem> _generateHouseQuiz() {
    final List<QuizItem> quizList = [];
    final List<HouseItem> shuffledList =
        List<HouseItem>.from(houseItems)..shuffle();

    for (int i = 0; i < 10 && i < shuffledList.length; i++) {
      final current = shuffledList[i];
      final otherOptions =
          houseItems.where((item) => item.word != current.word).toList()..shuffle();

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
    final saved = await LessonProgress.load('vocab_house', _wordCount);
    if (!mounted || saved == null) return;
    final api = _apiWords;
    final preview =
        api != null ? api[saved.index].term : houseItems[saved.index].word;
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
      LessonProgress.clear('vocab_house');
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
      if (currentIndex >= houseItems.length) return;
      word = houseItems[currentIndex].word;
    }
    VocabularyProgress.markLearned('house', word);
  }

  void _nextWord() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => isSpeaking = false);
    _markCurrentWordLearned();

    if (currentIndex < _wordCount - 1) {
      setState(() => currentIndex++);
      LessonProgress.save('vocab_house', currentIndex, 0);
    } else {
      // Went through every word: next time start from the first one.
      LessonProgress.clear('vocab_house');
      VocabularyProgress.markCategoryDone('house'); // green dot
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => GraduationScreen(
                categoryTitle: 'บ้าน',
                categorySlug: 'house',
                quizItems: _generateHouseQuiz(),
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
      LessonProgress.save('vocab_house', currentIndex, 0);
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
        ? houseItems[currentIndex]
        : _apiWords![currentIndex];
    final progress = (currentIndex + 1) / _wordCount;
    final double cardImageHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: const Color(0xFF0077C2), // สีฟ้าสดตามการ์ดหมวดบ้าน
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
          'คำศัพท์หมวดบ้าน',
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
              // สีกรอบเข้ม: สีน้ำเงินเข้มลึก (Deep Blue)
              border: Border.all(color: const Color(0xFF004BA0), width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF002F6C).withOpacity(0.35),
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
                            Icons.home_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'บ้าน',
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

                // กรอบรูปภาพ: สีส้มอิฐพาสเทลอ่อน (เข้ากับหลังคาบ้าน ไม่ซ้ำหมวดอื่น)
                Container(
                  height: cardImageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 253, 237, 249),
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
                                    currentItem.word.length > 12 ? 30 : 42,
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
                                        : const Color(0xFF0077C2), // ปุ่มลำโพงโทนเดียวกับจอ
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF004BA0).withOpacity(0.35),
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
