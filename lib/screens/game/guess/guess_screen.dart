import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../widgets/coin_balance_chip.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../services/guess_progress_service.dart';
import 'guess_data.dart';
import '../../../services/coin_balance.dart';

/// One question of a round: the picture's word + 4 answer choices.
class GuessQuestion {
  final GuessWord answer;
  final List<String> options;

  const GuessQuestion(this.answer, this.options);

  String get imagePath => answer.imagePath;
  String get correctAnswer => answer.word;
  String get thaiMeaning => answer.thai;
}

class GuessScreen extends StatefulWidget {
  const GuessScreen({super.key});

  @override
  State<GuessScreen> createState() => _GuessScreenState();
}

class _GuessScreenState extends State<GuessScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final math.Random _random = math.Random();

  GuessCategory? _category;
  List<GuessQuestion> activeQuestions = const [];
  int currentIndex = 0;
  int correctCount = 0;

  /// Coins the server confirmed in this round / answers waiting for internet.
  int coinsEarned = 0;
  int coinsPending = 0;
  String? selectedAnswer;
  bool isAnswerRevealed = false;
  bool isCurrentCorrect = false;
  bool isGameCompleted = false;

  /// For the badges on the category cards.
  Map<String, int> _bestScores = {};
  Map<String, ({int index, int total})> _unfinished = {};

  String? get selectedCategory => _category?.title;

  /// Changes for every new round, so a late coin reply of an old round is
  /// not added to the new one.
  int _roundId = 0;

  static const List<Map<String, dynamic>> _optionThemes = [
    {
      'label': 'A',
      'main': Color(0xFF2563EB),
      'shadow': Color(0xFF1D4ED8),
    },
    {
      'label': 'B',
      'main': Color(0xFFEF4444),
      'shadow': Color(0xFFB91C1C),
    },
    {
      'label': 'C',
      'main': Color(0xFFF97316),
      'shadow': Color(0xFFC2410C),
    },
    {
      'label': 'D',
      'main': Color(0xFF10B981),
      'shadow': Color(0xFF047857),
    },
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadBadges();
    // Take progress saved on the server (e.g. played on another phone),
    // then refresh the badges.
    GuessProgress.sync().then((_) => _loadBadges());
    GuessCoins.flush(); // coins of answers given while offline
  }

  @override
  void dispose() {
    _flutterTts.stop(); // don't keep talking after leaving the game
    super.dispose();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.38);
    await _flutterTts.setPitch(1.30);
  }

  Future<void> _speakWord(String text) async {
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  Future<void> _loadBadges() async {
    final best = await GuessProgress.bestScores();
    final unfinished = await GuessProgress.unfinished({
      for (final c in guessCategories) c.id: c.words.map((w) => w.word).toSet(),
    });
    if (!mounted) return;
    setState(() {
      _bestScores = best;
      _unfinished = unfinished;
    });
  }

  /// 3 wrong choices picked at random from the same category, never a word
  /// that looks like the answer (or like another choice) in a picture.
  List<String> _optionsFor(GuessCategory category, GuessWord answer) {
    final blocked = <String>{answer.word};
    for (final group in category.lookAlikes) {
      if (group.contains(answer.word)) blocked.addAll(group);
    }
    final pool =
        category.words
            .map((w) => w.word)
            .where((w) => !blocked.contains(w))
            .toList()
          ..shuffle(_random);
    final picks = <String>[];
    for (final w in pool) {
      if (picks.length == 3) break;
      final clash = category.lookAlikes.any(
        (group) => group.contains(w) && picks.any(group.contains),
      );
      if (!clash) picks.add(w);
    }
    for (final w in pool) {
      if (picks.length == 3) break;
      if (!picks.contains(w)) picks.add(w);
    }
    return [answer.word, ...picks]..shuffle(_random);
  }

  List<GuessQuestion> _buildRound(GuessCategory category, List<String> order) {
    final byWord = {for (final w in category.words) w.word: w};
    return [
      for (final word in order)
        GuessQuestion(byWord[word]!, _optionsFor(category, byWord[word]!)),
    ];
  }

  /// Tapping a category: continue an unfinished round, or start a new one
  /// (questions and choices are shuffled again every round).
  Future<void> _onCategoryTap(GuessCategory category) async {
    final valid = category.words.map((w) => w.word).toSet();
    final saved = await GuessProgress.load(category.id, valid);
    if (!mounted) return;
    if (saved != null) {
      final resume = await _askResume(category, saved);
      if (!mounted || resume == null) return;
      if (resume) {
        _startRound(
          category,
          saved.order,
          index: saved.index,
          correct: saved.correct,
          coins: saved.coins,
          pending: saved.pending,
        );
        return;
      }
      await GuessProgress.clear(category.id);
    }
    final order = category.words.map((w) => w.word).toList()..shuffle(_random);
    _startRound(category, order);
  }

  void _startRound(
    GuessCategory category,
    List<String> order, {
    int index = 0,
    int correct = 0,
    int coins = 0,
    int pending = 0,
  }) {
    setState(() {
      _roundId++;
      _category = category;
      activeQuestions = _buildRound(category, order);
      currentIndex = index;
      correctCount = correct;
      coinsEarned = coins;
      coinsPending = pending;
      selectedAnswer = null;
      isAnswerRevealed = false;
      isCurrentCorrect = false;
      isGameCompleted = false;
    });
  }

  /// Back to the category list (progress is already saved after each answer).
  void _backToCategories() {
    _flutterTts.stop();
    setState(() {
      _roundId++;
      _category = null;
      activeQuestions = const [];
      currentIndex = 0;
      correctCount = 0;
      coinsEarned = 0;
      coinsPending = 0;
      selectedAnswer = null;
      isAnswerRevealed = false;
      isCurrentCorrect = false;
      isGameCompleted = false;
    });
    _loadBadges();
  }

  int get _percent =>
      activeQuestions.isEmpty
          ? 0
          : (correctCount * 100 / activeQuestions.length).round();

  /// Saves the round: the next question to continue from.
  Future<void> _saveProgress() async {
    final category = _category;
    if (category == null || activeQuestions.isEmpty) return;
    final next = isAnswerRevealed ? currentIndex + 1 : currentIndex;
    if (next <= 0) return;
    if (next >= activeQuestions.length) {
      // Last question answered: the round is finished.
      await GuessProgress.clear(category.id);
      await GuessProgress.saveFinished(category.id, _percent);
      return;
    }
    await GuessProgress.save(
      category.id,
      GuessRound(
        order: activeQuestions.map((q) => q.correctAnswer).toList(),
        index: next,
        correct: correctCount,
        coins: coinsEarned,
        pending: coinsPending,
      ),
    );
  }

  Future<bool?> _askResume(GuessCategory category, GuessRound saved) {
    const green = Color(0xFF16A34A);
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: Color(0xFFBBF7D0), width: 2.5),
            ),
            title: Row(
              children: [
                const Icon(Icons.play_circle_fill_rounded, color: green, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'หมวด${category.title}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF14532D),
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'เล่นค้างไว้ที่ข้อ ${saved.index + 1} จาก ${saved.order.length}\n'
              'ตอบถูกไปแล้ว ${saved.correct} ข้อ จะเล่นต่อเลยไหม ?',
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: green,
                        side: const BorderSide(color: Color(0xFF86EFAC), width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text(
                        'เริ่มใหม่',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text(
                        'เล่นต่อ',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  void _onSelectOption(String option) {
    if (isAnswerRevealed) return;
    final category = _category;
    if (category == null) return;

    final currentQ = activeQuestions[currentIndex];
    final bool correct = option == currentQ.correctAnswer;
    final round = _roundId;

    setState(() {
      selectedAnswer = option;
      isAnswerRevealed = true;
      isCurrentCorrect = correct;
      if (correct) correctCount++;
    });

    _speakWord(currentQ.correctAnswer);

    // Correct: ask the server for the coin (it checks the answer itself).
    final Future<GuessCoinResult>? coinFuture =
        correct
            ? GuessCoins.submit(
              categoryId: category.id,
              word: currentQ.correctAnswer,
              choice: option,
            ).then((result) {
              if (mounted && round == _roundId) {
                setState(() {
                  coinsEarned += result.coins;
                  if (result.pending) coinsPending++;
                });
                _saveProgress(); // keep the saved coin count up to date
              }
              return result;
            })
            : null;

    _saveProgress();
    _showAnswerFeedbackSheet(
      isCorrect: correct,
      currentQ: currentQ,
      coinFuture: coinFuture,
    );
  }

  void _showAnswerFeedbackSheet({
    required bool isCorrect,
    required GuessQuestion currentQ,
    Future<GuessCoinResult>? coinFuture,
  }) {
    final Color sheetBg = isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final Color sheetBorder = isCorrect ? const Color(0xFF047857) : const Color(0xFFB91C1C);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        // The phone's back button must not close this sheet: the game would
        // stay on an answered question with every button locked.
        return PopScope(
          canPop: false,
          child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: sheetBorder,
              width: 3.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 110,
                child: Image.asset(
                  isCorrect
                      ? 'assets/images/character/bravo.png'
                      : 'assets/images/character/sad.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.emoji_events_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isCorrect ? 'ถูกต้อง เก่งมาก !' : 'ยังไม่ถูกต้อง',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 1.5),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (isCorrect)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        offset: Offset(0, 2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: Color(0xFFF59E0B),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      FutureBuilder<GuessCoinResult>(
                        future: coinFuture,
                        builder: (context, snap) {
                          final r = snap.data;
                          final String text;
                          if (snap.connectionState != ConnectionState.done) {
                            text = 'กำลังรับเหรียญ...';
                          } else if (r == null) {
                            text = 'ตอบถูก 1 ข้อ';
                          } else if (r.coins > 0) {
                            text = '+${r.coins} เหรียญ';
                          } else if (r.pending) {
                            text = '+$kGameCoinsPerWord เหรียญ (ได้รับเมื่อต่อเน็ต)';
                          } else if (r.alreadyToday) {
                            text = 'คำนี้ได้เหรียญไปแล้ววันนี้';
                          } else {
                            text = 'ตอบถูก 1 ข้อ';
                          }
                          return Flexible(
                            child: Text(
                              text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        offset: Offset(0, 2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'เฉลย คือ ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        TextSpan(
                          text: '${currentQ.correctAnswer} (${currentQ.thaiMeaning})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFB91C1C),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // ปุ่มกด "ต่อไป" โดยนำลูกศรออกเรียบร้อย
              GestureDetector(
                onTap: () {
                  Navigator.pop(sheetContext);
                  _goToNextQuestion();
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB45309),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.only(bottom: 4.5),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        currentIndex < activeQuestions.length - 1
                            ? 'ต่อไป'
                            : 'ดูสรุปผลคะแนน',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Color(0xFFB45309),
                              offset: Offset(0, 1.5),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  void _goToNextQuestion() {
    if (currentIndex < activeQuestions.length - 1) {
      setState(() {
        currentIndex++;
        selectedAnswer = null;
        isAnswerRevealed = false;
        isCurrentCorrect = false;
      });
    } else {
      setState(() {
        isGameCompleted = true;
      });
    }
  }

  // ================= หน้าจอเฉลิมฉลองตอนจบเกม (โทนสีเขียวสดใส) =================
  Widget _buildSummaryScreen() {
    const Color victoryBgTop = Color(0xFF10B981);
    const Color victoryBgBottom = Color(0xFF047857);
    final int percentage = _percent;
    // Stars and message follow the score (it used to say "เก่งมาก" with
    // 3 stars even when nothing was right).
    final int stars =
        percentage >= 80
            ? 3
            : percentage >= 50
            ? 2
            : percentage > 0
            ? 1
            : 0;
    final String headline =
        percentage >= 80
            ? 'เก่งมาก ยอดเยี่ยม'
            : percentage >= 50
            ? 'ทำได้ดีมาก !'
            : 'สู้ ๆ นะ ลองอีกครั้ง';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [victoryBgTop, victoryBgBottom],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: -40,
              right: -40,
              height: 360,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.elliptical(260, 90),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ConfettiParticlesPainter(),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Center(
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Image.asset(
                          'assets/images/character/bravo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.emoji_events_rounded,
                            size: 150,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildStarIcon(56, filled: stars >= 1),
                        const SizedBox(width: 8),
                        _buildStarIcon(76, filled: stars >= 2),
                        const SizedBox(width: 8),
                        _buildStarIcon(56, filled: stars >= 3),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Color(0xFF064E3B),
                            offset: Offset(0, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'หมวด$selectedCategory ตอบถูก $correctCount จาก ${activeQuestions.length} ข้อ',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 125,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA78BFA),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: Colors.white, width: 2.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  offset: const Offset(0, 5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.monetization_on_rounded,
                                    color: Color(0xFFF59E0B),
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '+$coinsEarned',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  coinsPending > 0
                                      ? 'เหรียญ (+${coinsPending * kGameCoinsPerWord} รอต่อเน็ต)'
                                      : 'เหรียญที่ได้รับ',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: 125,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF472B6),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: Colors.white, width: 2.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  offset: const Offset(0, 5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF10B981),
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$percentage%',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  'ความแม่นยำ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    GestureDetector(
                      onTap: () {
                        final category = _category;
                        if (category != null) _onCategoryTap(category);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white70, width: 2),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.replay_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'เล่นหมวดนี้อีกครั้ง',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _backToCategories,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white38, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFFB45309),
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home_rounded, color: Colors.white, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'กลับหน้าเลือกหมวด',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarIcon(double size, {bool filled = true}) {
    return Icon(
      Icons.star_rounded,
      color: filled ? const Color(0xFFFBBF24) : Colors.white.withValues(alpha: 0.35),
      size: size,
      shadows: [
        Shadow(
          color: filled ? const Color(0xFFD97706) : Colors.black12,
          offset: Offset(0, 3.5),
          blurRadius: 0,
        ),
      ],
    );
  }

  /// "เล่นต่อ 5/30" for an unfinished round, a green tick for a finished
  /// category, nothing for a new one.
  Widget _categoryBadge(GuessCategory category) {
    final unfinished = _unfinished[category.id];
    final best = _bestScores[category.id];
    if (unfinished == null && best == null) return const SizedBox.shrink();
    if (unfinished == null) {
      // Finished: just a green tick (same as the practiced cards in Phonics).
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1.5)),
          ],
        ),
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      );
    }
    // Only an unfinished round reaches this point (finished ones returned above).
    const Color color = Color(0xFFF59E0B);
    final String text = 'เล่นต่อ ${unfinished.index + 1} / ${unfinished.total}';
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 3,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ================= หน้าจอเลือกหมวดหมู่ =================
  Widget _buildCategorySelectionScreen() {
    const List<GuessCategory> displayCategories = guessCategories;
    const topBarColor = Color(0xFF16A34A);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFDCFCE7),
              Color(0xFFF0FDF4),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.4, 0.9],
          ),
        ),
        child: Column(
          children: [
            Container(
              color: topBarColor,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.maybePop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      // Same width as the coin chip on the right, so the title stays centred.
                      const SizedBox(width: CoinBalanceChip.width - 38),
                      const Expanded(
                        child: Text(
                          'ทายภาพ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const CoinBalanceChip(),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'ทายภาพแสนสนุก',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF16A34A),
                              letterSpacing: 0.4,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'เลือกหมวดหมู่',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.94,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final GuessCategory category = displayCategories[index];
                          final Color imageBackground = Color.alphaBlend(
                            category.color.withValues(alpha: .82),
                            Colors.white,
                          );
                          final Color imageBackgroundLight = Color.alphaBlend(
                            category.color.withValues(alpha: .68),
                            Colors.white,
                          );

                          return InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _onCategoryTap(category),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: category.color.withValues(alpha: .16),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [imageBackground, imageBackgroundLight],
                                              ),
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            child: Image.asset(
                                              category.imagePath,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const SizedBox.expand(),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: _categoryBadge(category),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    color: Colors.white,
                                    child: Text(
                                      category.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF27324A),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: displayCategories.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= หน้าจอเล่นเกม =================
  @override
  Widget build(BuildContext context) {
    if (_category == null) return _buildCategorySelectionScreen();
    // In a round, the phone's back button goes to the category list (like
    // the arrow at the top), not out of the whole game.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToCategories();
      },
      child: isGameCompleted ? _buildSummaryScreen() : _buildGameScreen(),
    );
  }

  Widget _buildGameScreen() {
    final GuessQuestion currentQ = activeQuestions[currentIndex];
    final double progress = (currentIndex + 1) / activeQuestions.length;
    const Color headerGreen = Color(0xFF16A34A);

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: Column(
        children: [
          // 1. แถบ Header สีเขียวชิดขอบบนพร้อมปุ่มย้อนกลับ
          Container(
            color: headerGreen,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _backToCategories,
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    // Same width as the coin chip on the right, so the title stays centred.
                    const SizedBox(width: CoinBalanceChip.width - 38),
                    const Expanded(
                      child: Text(
                        'ทายภาพ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const CoinBalanceChip(),
                  ],
                ),
              ),
            ),
          ),

          // 2. เนื้อหาคำถามและปุ่มคำตอบ
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                children: [
                  // แถบข้อมูล: ป้ายชื่อหมวด 3D, ข้อ X/รวมทั้งหมด, และ Progress Bar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFBBF7D0), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFF15803D),
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                'หมวด$selectedCategory',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const Spacer(),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF14532D),
                                ),
                                children: [
                                  const TextSpan(text: 'ข้อ '),
                                  TextSpan(
                                    text: '${currentIndex + 1}',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / ${activeQuestions.length}',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double totalWidth = constraints.maxWidth;
                            final double currentPos = totalWidth * progress;

                            return Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: 12,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  height: 12,
                                  width: currentPos,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4ADE80),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 300),
                                  left: math.max(0, currentPos - 10),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: const Color(0xFF16A34A),
                                        width: 3.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // กรอบภาพคำถาม 3D Jelly Frame
                  Expanded(
                    flex: 11,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFF064E3B),
                            width: 3.5,
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(22.0),
                            child: Image.asset(
                              currentQ.imagePath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_rounded,
                                size: 80,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ข้อความ "ภาพนี้คืออะไรเอ่ย?"
                  Text(
                    isAnswerRevealed
                        ? 'เฉลย : ${currentQ.correctAnswer} (${currentQ.thaiMeaning})'
                        : 'ภาพนี้คืออะไรเอ่ย ?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isAnswerRevealed
                          ? (isCurrentCorrect ? const Color(0xFF15803D) : const Color(0xFFDC2626))
                          : const Color(0xFF064E3B),
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ตารางปุ่มตัวเลือก 4 ปุ่ม 4 สี 3D
                  Expanded(
                    flex: 9,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentQ.options.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.1,
                      ),
                      itemBuilder: (context, index) {
                        final String option = currentQ.options[index];
                        final theme = _optionThemes[index % _optionThemes.length];
                        final String letterBadge = theme['label'] as String;

                        Color btnColor = theme['main'] as Color;
                        Color shadowColor = theme['shadow'] as Color;

                        if (isAnswerRevealed) {
                          if (option == currentQ.correctAnswer) {
                            btnColor = const Color(0xFF10B981);
                            shadowColor = const Color(0xFF047857);
                          } else if (option == selectedAnswer) {
                            btnColor = const Color(0xFFEF4444);
                            shadowColor = const Color(0xFFB91C1C);
                          } else {
                            btnColor = Colors.grey.shade400;
                            shadowColor = Colors.grey.shade600;
                          }
                        }

                        return GestureDetector(
                          onTap: () => _onSelectOption(option),
                          child: Container(
                            decoration: BoxDecoration(
                              color: shadowColor,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            padding: const EdgeInsets.only(bottom: 5.5),
                            child: Container(
                              decoration: BoxDecoration(
                                color: btnColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          offset: Offset(0, 1.5),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      letterBadge,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        color: btnColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    // Long words (Skateboarding, Police Station)
                                    // shrink to fit instead of being cut off.
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                      option,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black26,
                                            offset: Offset(0, 1.5),
                                            blurRadius: 1.5,
                                          ),
                                        ],
                                      ),
                                    ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
}

// Particle Painter สำหรับ Confetti เฉลิมฉลอง
class _ConfettiParticlesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(12345);
    final paint = Paint()..style = PaintingStyle.fill;

    final colors = [
      const Color(0xFFFBBF24),
      const Color(0xFFF472B6),
      const Color(0xFF34D399),
      const Color(0xFF60A5FA),
      const Color(0xFFC084FC),
      const Color(0xFFFB923C),
    ];

    for (int i = 0; i < 65; i++) {
      paint.color = colors[random.nextInt(colors.length)];
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height * 0.78;
      final double radius = random.nextDouble() * 4 + 3;

      if (random.nextBool()) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, radius * 2.2, radius),
          paint,
        );
      } else {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}