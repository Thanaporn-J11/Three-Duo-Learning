import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../services/lesson_progress.dart';
import '../../services/listening_results_service.dart';
import '../../services/sfx.dart';

class ListeningQuizItem {
  final String soundFocus; // หมวดหมู่เสียงที่กำลังฝึก
  final String targetWord;
  final String word1;
  final String phonetics1;
  final String word2;
  final String phonetics2;

  const ListeningQuizItem({
    required this.soundFocus,
    required this.targetWord,
    required this.word1,
    required this.phonetics1,
    required this.word2,
    required this.phonetics2,
  });
}

class MinimalPairsScreen extends StatefulWidget {
  const MinimalPairsScreen({super.key});

  @override
  State<MinimalPairsScreen> createState() => _MinimalPairsScreenState();
}

class _MinimalPairsScreenState extends State<MinimalPairsScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  int currentIndex = 0;
  String? selectedWord;
  bool isAnswerChecked = false;
  bool isCorrect = false;
  int correctAnswersCount = 0;

  /// The result of this round was already sent (send it once only).
  bool _resultSent = false;

  // 20 ข้อ แบ่งเป็น 4 กลุ่มเสียงชัดเจน กลุ่มละ 5 ข้อ คัดคำศัพท์เข้าใจง่ายสำหรับเด็ก
  final List<ListeningQuizItem> quizList = const [
    // --- กลุ่มที่ 1: พยัญชนะริมฝีปาก /p/ vs /b/ (ข้อ 1-5) ---
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียง /p/ กับ /b/',
      targetWord: 'pin',
      word1: 'pin',
      phonetics1: '/pɪn/',
      word2: 'bin',
      phonetics2: '/bɪn/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียง /p/ กับ /b/',
      targetWord: 'pig',
      word1: 'pig',
      phonetics1: '/pɪɡ/',
      word2: 'big',
      phonetics2: '/bɪɡ/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียง /p/ กับ /b/',
      targetWord: 'pan',
      word1: 'ban',
      phonetics1: '/bæn/',
      word2: 'pan',
      phonetics2: '/pæn/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียง /p/ กับ /b/',
      targetWord: 'bat',
      word1: 'pat',
      phonetics1: '/pæt/',
      word2: 'bat',
      phonetics2: '/bæt/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียง /p/ กับ /b/',
      targetWord: 'pet',
      word1: 'pet',
      phonetics1: '/pɛt/',
      word2: 'bet',
      phonetics2: '/bɛt/',
    ),

    // --- กลุ่มที่ 2: สระสั้น /æ/ vs /ʌ/ vs /ɛ/ (ข้อ 6-10) ---
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียงสระ /ʌ/ กับ /æ/',
      targetWord: 'cap',
      word1: 'cup',
      phonetics1: '/kʌp/',
      word2: 'cap',
      phonetics2: '/kæp/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียงสระ /ɛ/ กับ /æ/',
      targetWord: 'bed',
      word1: 'bed',
      phonetics1: '/bɛd/',
      word2: 'bad',
      phonetics2: '/bæd/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียงสระ /æ/ กับ /ʌ/',
      targetWord: 'fun',
      word1: 'fan',
      phonetics1: '/fæn/',
      word2: 'fun',
      phonetics2: '/fʌn/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียงสระ /æ/ กับ /ʌ/',
      targetWord: 'bug',
      word1: 'bag',
      phonetics1: '/bæɡ/',
      word2: 'bug',
      phonetics2: '/bʌɡ/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียงสระ /ɛ/ กับ /æ/',
      targetWord: 'pen',
      word1: 'pen',
      phonetics1: '/pɛn/',
      word2: 'pan',
      phonetics2: '/pæn/',
    ),

    // --- กลุ่มที่ 3: สระสั้น-ยาว /ɪ/ vs /iː/ และ /l/ vs /r/ (ข้อ 11-15) ---
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียงสระ /ɪ/ กับ /iː/',
      targetWord: 'sheep',
      word1: 'ship',
      phonetics1: '/ʃɪp/',
      word2: 'sheep',
      phonetics2: '/ʃiːp/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียงสระ /ɪ/ กับ /iː/',
      targetWord: 'sit',
      word1: 'sit',
      phonetics1: '/sɪt/',
      word2: 'seat',
      phonetics2: '/siːt/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียงสระ /ɪ/ กับ /iː/',
      targetWord: 'feet',
      word1: 'fit',
      phonetics1: '/fɪt/',
      word2: 'feet',
      phonetics2: '/fiːt/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียง /l/ กับ /r/',
      targetWord: 'right',
      word1: 'light',
      phonetics1: '/laɪt/',
      word2: 'right',
      phonetics2: '/raɪt/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียง /l/ กับ /r/',
      targetWord: 'rock',
      word1: 'lock',
      phonetics1: '/lɑːk/',
      word2: 'rock',
      phonetics2: '/rɑːk/',
    ),

    // --- กลุ่มที่ 4: พยัญชนะ /s/ vs /ʃ/ และเสียงท้ายคำ (ข้อ 16-20) ---
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียง /s/ กับ /ʃ/',
      targetWord: 'sea',
      word1: 'sea',
      phonetics1: '/siː/',
      word2: 'she',
      phonetics2: '/ʃiː/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียง /s/ กับ /ʃ/',
      targetWord: 'shock',
      word1: 'sock',
      phonetics1: '/sɑːk/',
      word2: 'shock',
      phonetics2: '/ʃɑːk/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียง /f/ กับ /b/',
      targetWord: 'box',
      word1: 'fox',
      phonetics1: '/fɑːks/',
      word2: 'box',
      phonetics2: '/bɑːks/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียงท้าย /k/ กับ /ɡ/',
      targetWord: 'bag',
      word1: 'back',
      phonetics1: '/bæk/',
      word2: 'bag',
      phonetics2: '/bæɡ/',
    ),
    ListeningQuizItem(
      soundFocus: 'ฝึกเสียงต้น /s/ กับ /r/',
      targetWord: 'sun',
      word1: 'sun',
      phonetics1: '/sʌn/',
      word2: 'run',
      phonetics2: '/rʌn/',
    ),
  ];

  /// Saved position id for LessonProgress (shown on the listen menu too).
  static const String progressId = 'minimal_pairs';

  @override
  void initState() {
    super.initState();
    _initTts();
    // After the first frame, offer to continue where the child stopped.
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerResume());
  }

  Future<void> _offerResume() async {
    final saved = await LessonProgress.load(progressId, quizList.length);
    if (saved == null || !mounted) return;
    final resume = await _askResume(saved);
    if (!mounted) return;
    if (resume) {
      setState(() {
        currentIndex = saved.index;
        correctAnswersCount = saved.correct;
        selectedWord = null;
        isAnswerChecked = false;
        isCorrect = false;
      });
    } else {
      await LessonProgress.clear(progressId);
    }
  }

  /// true = continue, false = start over. Must pick one (no tap-outside).
  Future<bool> _askResume(({int index, int correct}) saved) async {
    final total = quizList.length;
    final focus = quizList[saved.index].soundFocus;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EC),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFFFCC80), width: 2.5),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Earphones picture on the game's orange (same as its menu card)
                Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFA452), Color(0xFFFF7E36)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFFC75210), offset: Offset(0, 5)),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/sentence/earphones.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.headphones_rounded,
                      color: Colors.white,
                      size: 46,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'เล่นต่อจากเดิมไหม ?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4E2A00),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ค้างไว้ที่ข้อ ${saved.index + 1} จาก $total • ตอบถูก ${saved.correct} ข้อ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A6B4F),
                  ),
                ),
                const SizedBox(height: 10),
                // Which sound group they were on
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFCC80), width: 1.5),
                  ),
                  child: Text(
                    '🎧 $focus',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Progress bar (20 questions are too many for dots)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: saved.index / total,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFFFE0B2),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFF7E36)),
                  ),
                ),
                const SizedBox(height: 20),
                _orangeButton(
                  label: 'เล่นต่อข้อ ${saved.index + 1}',
                  icon: Icons.play_arrow_rounded,
                  primary: true,
                  onTap: () => Navigator.pop(dialogContext, true),
                ),
                const SizedBox(height: 12),
                _orangeButton(
                  label: 'เริ่มใหม่ตั้งแต่ข้อ 1',
                  icon: Icons.replay_rounded,
                  primary: false,
                  onTap: () => Navigator.pop(dialogContext, false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result ?? true;
  }

  /// 3D pill button matching this game's result screen:
  /// primary = gold ("กลับหน้าหลัก"), secondary = white/orange ("เล่นอีกครั้ง").
  Widget _orangeButton({
    required String label,
    required IconData icon,
    required bool primary,
    required VoidCallback onTap,
  }) {
    final Color content = primary ? const Color(0xFF6D4C00) : const Color(0xFFE65100);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: primary ? 56 : 52,
        decoration: BoxDecoration(
          color: primary ? const Color(0xFFB26A00) : const Color(0xFFBF360C),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        padding: EdgeInsets.only(bottom: primary ? 5 : 4.5),
        child: Container(
          decoration: BoxDecoration(
            color: primary ? null : Colors.white,
            gradient: primary
                ? const LinearGradient(
                  colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
                : null,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: primary
                  ? Colors.white.withValues(alpha: 0.8)
                  : const Color(0xFFFFCC80),
              width: 1.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: content, size: primary ? 26 : 23),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: content,
                  fontSize: primary ? 19 : 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.15);
  }

  Future<void> _speakTarget({required bool isSlow}) async {
    await _flutterTts.stop();
    await _flutterTts.setSpeechRate(isSlow ? 0.16 : 0.40);
    await _flutterTts.speak(quizList[currentIndex].targetWord);
  }

  void _onSelectChoice(String word) {
    if (isAnswerChecked) return;
    setState(() {
      selectedWord = word;
    });
  }

  void _checkAnswer() {
    if (selectedWord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณาแตะเลือกคำศัพท์ที่ได้ยินก่อนนะจ๊ะ'),
          backgroundColor: const Color(0xFFFF993A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    final currentTarget = quizList[currentIndex].targetWord;
    final isRight = selectedWord!.trim().toLowerCase() == currentTarget.trim().toLowerCase();

    setState(() {
      isAnswerChecked = true;
      isCorrect = isRight;
      if (isRight) {
        correctAnswersCount++;
      }
    });

    isRight ? Sfx.correct() : Sfx.wrong();
    _showFeedbackSheet(isRight);
  }

  void _showFeedbackSheet(bool correct) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final Color sheetBg = correct ? const Color(0xFF10B981) : const Color(0xFFEF4444);
        final Color sheetBorder = correct ? const Color(0xFF059669) : const Color(0xFFDC2626);

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: sheetBorder, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 10),
              Text(
                correct ? 'ถูกต้อง เก่งมาก !' : 'ยังไม่ถูกต้อง ลองอีกครั้ง',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'คำที่ถูกต้อง คือ  ${quizList[currentIndex].targetWord}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _nextQuestion();
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, offset: Offset(0, 3), blurRadius: 4),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    currentIndex < quizList.length - 1 ? 'ข้อต่อไป' : 'ดูสรุปผลการเรียน',
                    style: TextStyle(
                      color: sheetBorder,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _nextQuestion() {
    if (currentIndex < quizList.length - 1) {
      setState(() {
        currentIndex++;
        selectedWord = null;
        isAnswerChecked = false;
        isCorrect = false;
      });
      // Remember where we are, so leaving now continues from this question.
      LessonProgress.save(progressId, currentIndex, correctAnswersCount);
    } else {
      // Finished all 20: next time starts from question 1.
      LessonProgress.clear(progressId);
      // Send the score for the parent report (no coins).
      if (!_resultSent) {
        _resultSent = true;
        ListeningResults.submit(
        game: 'minimal_pairs',
        score: correctAnswersCount,
        total: quizList.length,
      );
      }
      _showCompletionDialog();
    }
  }

  // หน้าจอแสดงผลเมื่อทำครบ 20 ข้อ (ธีมสีส้มทองสดใส 3D)
  void _showCompletionDialog() {
    Sfx.complete();
    final int accuracyPercent = ((correctAnswersCount / quizList.length) * 100).round();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) {
        // The phone's back button must not close it: that left the game on
        // the last question, and finishing again sent the result twice.
        return PopScope(
          canPop: false,
          child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFA53B), // ส้มสว่างด้านบน
                  Color(0xFFFF7A00), // ส้มสดใสตรงกลาง
                  Color(0xFFE65100), // ส้มเข้มอบอุ่นด้านล่าง
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                ..._buildConfettiBackground(),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 10),

                        // 1. มาสคอตตัวการ์ตูนถือหนังสือ + รัศมีวงกลมสีขาวโปร่ง
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            SizedBox(
                              height: 190,
                              child: Image.asset(
                                'assets/images/character/yep.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.celebration_rounded,
                                  size: 130,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // 2. ดาว 3 ดวงสีทอง
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStar(size: 46, angle: -0.15),
                            const SizedBox(width: 8),
                            _buildStar(size: 64, angle: 0.0), // ดวงกลางใหญ่สุด
                            const SizedBox(width: 8),
                            _buildStar(size: 46, angle: 0.15),
                          ],
                        ),

                        // 3. หัวข้อ & ป้ายข้อความ "เรียนจบกิจกรรมเรียบร้อยแล้ว!"
                        Column(
                          children: [
                            const Text(
                              'เก่งมาก ยอดเยี่ยม',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 31,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFFBF360C),
                                    offset: Offset(0, 3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 1.6,
                                ),
                              ),
                              child: const Text(
                                'เรียนจบกิจกรรมเรียบร้อยแล้ว !',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // 4. การ์ดแสดงความแม่นยำ (โทนส้มอมแดง 3D สดใส)
                        Container(
                          width: 205,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFBF360C).withValues(alpha: 0.6),
                                offset: const Offset(0, 6),
                                blurRadius: 0,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF10B981),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$accuracyPercent%',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'ความแม่นยำ',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 5. ปุ่ม "เล่นอีกครั้ง" และ "กลับหน้าหลัก"
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  currentIndex = 0;
                                  selectedWord = null;
                                  isAnswerChecked = false;
                                  isCorrect = false;
                                  correctAnswersCount = 0;
                                  _resultSent = false;
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFBF360C),
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.only(bottom: 4.5),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color(0xFFFFCC80),
                                      width: 1.8,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.replay_rounded, color: Color(0xFFE65100), size: 23),
                                      SizedBox(width: 8),
                                      Text(
                                        'เล่นอีกครั้ง',
                                        style: TextStyle(
                                          color: Color(0xFFE65100),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              child: Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB26A00),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      width: 1.8,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.home_rounded, color: Color(0xFF6D4C00), size: 25),
                                      SizedBox(width: 8),
                                      Text(
                                        'กลับหน้าหลัก',
                                        style: TextStyle(
                                          color: Color(0xFF6D4C00),
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
      },
    );
  }

  Widget _buildStar({required double size, required double angle}) {
    return Transform.rotate(
      angle: angle,
      child: Icon(
        Icons.star_rounded,
        size: size,
        color: const Color(0xFFFFD54F),
        shadows: const [
          Shadow(
            color: Color(0xFFE65100),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildConfettiBackground() {
    final List<Map<String, dynamic>> confettis = [
      {'top': 60.0, 'left': 30.0, 'color': Colors.pinkAccent, 'w': 10.0, 'h': 6.0, 'angle': 0.4},
      {'top': 90.0, 'right': 40.0, 'color': Colors.white, 'w': 12.0, 'h': 7.0, 'angle': -0.3},
      {'top': 140.0, 'left': 60.0, 'color': Colors.yellowAccent, 'w': 14.0, 'h': 6.0, 'angle': 0.8},
      {'top': 180.0, 'right': 70.0, 'color': Colors.cyanAccent, 'w': 8.0, 'h': 8.0, 'angle': 0.2},
      {'top': 280.0, 'left': 25.0, 'color': Colors.amberAccent, 'w': 12.0, 'h': 6.0, 'angle': -0.5},
      {'top': 320.0, 'right': 30.0, 'color': Colors.white, 'w': 10.0, 'h': 10.0, 'angle': 0.6},
      {'top': 420.0, 'left': 40.0, 'color': Colors.yellow, 'w': 14.0, 'h': 7.0, 'angle': -0.2},
      {'top': 460.0, 'right': 45.0, 'color': Colors.lightBlueAccent, 'w': 9.0, 'h': 9.0, 'angle': 0.7},
    ];

    return confettis.map((c) {
      return Positioned(
        top: c['top'] as double?,
        left: c['left'] as double?,
        right: c['right'] as double?,
        child: Transform.rotate(
          angle: c['angle'] as double,
          child: Container(
            width: c['w'] as double,
            height: c['h'] as double,
            decoration: BoxDecoration(
              color: c['color'] as Color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = quizList[currentIndex];
    const headerColor = Color(0xFFFF993A);

    return Scaffold(
      body: Column(
        children: [
          // 1. Header สีส้ม
          Container(
            color: headerColor,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF5A2A08), size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'ฟังแยกเสียงคำศัพท์',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF3E1C00),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // 2. พื้นที่เนื้อหาหลัก
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF90CDF4),
                    Color(0xFFBAE6FD),
                    Color(0xFFFDE68A),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // เมฆซ้าย-ขวา
                  Positioned(
                    top: 25,
                    left: -40,
                    child: Container(
                      width: 80,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 15,
                    right: -40,
                    child: Container(
                      width: 80,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),

                  // ผังองค์ประกอบแนวตั้ง
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 1) ข้อความหัวข้อ + ป้ายบอกคู่เสียง แบบที่ 2 (สีน้ำเงินสดใส)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              children: [
                                // ป้ายบอกคู่เสียง สไตล์น้ำเงินตัดขอบขาว สดใส ชัดเจน ไม่แย่งซีนสีส้ม
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E40AF),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.only(bottom: 3.5),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8.5),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'ข้อ ${currentIndex + 1} / ${quizList.length} • ',
                                          style: const TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white70,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        Text(
                                          current.soundFocus,
                                          style: const TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                            shadows: [
                                              Shadow(color: Colors.black26, offset: Offset(0, 1.2), blurRadius: 2),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'ฟังเสียงแล้วเลือกคำที่ได้ยิน',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'แตะลำโพงใหญ่เพื่อฟังได้เลย',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 2) ตัวการ์ตูน yep.png ขนาด 210px
                          SizedBox(
                            height: 210,
                            child: Image.asset(
                              'assets/images/character/yep.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.cruelty_free_rounded,
                                size: 130,
                                color: Color(0xFFFF993A),
                              ),
                            ),
                          ),

                          // 3) ปุ่มลำโพงกลมใหญ่ 3D
                          _buildBigSpeakerButton(),

                          // 4) ปุ่มแคปซูล "ฟังช้าๆ" และข้อความ "เลือกคำที่ได้ยิน"
                          Column(
                            children: [
                              _buildSlowListenButton(),
                              const SizedBox(height: 14),
                              const Text(
                                'เลือกคำที่ได้ยิน',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1F2937),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),

                          // 5) การ์ดตัวเลือก 1 & 2
                          Row(
                            children: [
                              Expanded(
                                child: _buildChoiceCard(
                                  number: '1',
                                  word: current.word1,
                                  phonetics: current.phonetics1,
                                  isSelected: selectedWord == current.word1,
                                  hasAnySelection: selectedWord != null,
                                  numberColor: const Color(0xFFFF2D6F),
                                  borderColor: const Color(0xFFFF3366),
                                  shadowColor: const Color(0xFFE01E5A),
                                  normalBgColor: const Color(0xFFFFF0F5),
                                  selectedBgColor: const Color(0xFFFFD6E7),
                                  onTap: () => _onSelectChoice(current.word1),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildChoiceCard(
                                  number: '2',
                                  word: current.word2,
                                  phonetics: current.phonetics2,
                                  isSelected: selectedWord == current.word2,
                                  hasAnySelection: selectedWord != null,
                                  numberColor: const Color(0xFF009688),
                                  borderColor: const Color(0xFF00BFA5),
                                  shadowColor: const Color(0xFF00897B),
                                  normalBgColor: const Color(0xFFE6FAF7),
                                  selectedBgColor: const Color(0xFFB2F5EA),
                                  onTap: () => _onSelectChoice(current.word2),
                                ),
                              ),
                            ],
                          ),

                          // 6) ปุ่ม "ตรวจคำตอบ" 3D
                          _buildCheckAnswerButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ปุ่มลำโพงกลมใหญ่ 3D
  Widget _buildBigSpeakerButton() {
    return GestureDetector(
      onTap: () => _speakTarget(isSlow: false),
      child: Container(
        width: 154,
        height: 154,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFCBD5E1).withValues(alpha: 0.45),
        ),
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFED7AA).withValues(alpha: 0.7),
          ),
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD46B12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA65008).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.only(bottom: 6.5),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFA24C), Color(0xFFFF7E1D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Icon(
                Icons.volume_up_rounded,
                color: Colors.white,
                size: 58,
                shadows: [
                  Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ปุ่มแคปซูล "ฟังช้าๆ" สีส้มเหลือง
  Widget _buildSlowListenButton() {
    return GestureDetector(
      onTap: () => _speakTarget(isSlow: true),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFD97706),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB45309).withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.only(bottom: 3.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8.5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB74D), Color(0xFFFFA000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: const Text(
            'ฟังช้า ๆ',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.2,
              shadows: [
                Shadow(color: Colors.black26, offset: Offset(0, 1.2), blurRadius: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // การ์ดตัวเลือก 1 และ 2
  Widget _buildChoiceCard({
    required String number,
    required String word,
    required String phonetics,
    required bool isSelected,
    required bool hasAnySelection,
    required Color numberColor,
    required Color borderColor,
    required Color shadowColor,
    required Color normalBgColor,
    required Color selectedBgColor,
    required VoidCallback onTap,
  }) {
    final double cardOpacity = (!isSelected && hasAnySelection) ? 0.72 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: cardOpacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 132,
          decoration: BoxDecoration(
            color: shadowColor,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? shadowColor.withValues(alpha: 0.6)
                    : shadowColor.withValues(alpha: 0.2),
                blurRadius: isSelected ? 14 : 7,
                offset: Offset(0, isSelected ? 6 : 4),
              ),
            ],
          ),
          padding: EdgeInsets.only(bottom: isSelected ? 8 : 6),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? selectedBgColor : normalBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 4.0 : 2.5,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 9,
                  left: 9,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: numberColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: borderColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        word,
                        style: TextStyle(
                          fontSize: isSelected ? 29 : 28,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF26190E),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phonetics,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? const Color(0xFF005E75)
                              : const Color(0xFF007A99),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ปุ่ม "ตรวจคำตอบ" 3D
  Widget _buildCheckAnswerButton() {
    final bool isReady = selectedWord != null;

    final Color buttonShadow = isReady ? const Color(0xFFC2410C) : const Color(0xFFCBD5E1);
    final List<Color> buttonGradient = isReady
        ? const [Color(0xFFFB923C), Color(0xFFEA580C)]
        : const [Color(0xFFF1F5F9), Color(0xFFE2E8F0)];
    final Color textColor = isReady ? Colors.white : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: _checkAnswer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: buttonShadow,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: buttonShadow.withValues(alpha: isReady ? 0.45 : 0.25),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.only(bottom: 5),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: buttonGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: isReady ? 0.6 : 0.8),
              width: 1.6,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'ตรวจคำตอบ',
            style: TextStyle(
              color: textColor,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              shadows: isReady
                  ? const [
                      Shadow(
                        color: Color(0xFF9A3412),
                        offset: Offset(0, 1.5),
                        blurRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}