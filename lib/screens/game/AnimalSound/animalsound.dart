import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../services/animal_sound_service.dart';
import '../../../services/coin_balance.dart';
import '../../../services/guess_progress_service.dart' show GuessCoinResult;
import '../../../services/listening_results_service.dart';
import '../../../services/sfx.dart';

class AnimalSound extends StatefulWidget {
  const AnimalSound({super.key});

  @override
  State<AnimalSound> createState() => _AnimalSoundState();
}

class _AnimalSoundState extends State<AnimalSound>
    with SingleTickerProviderStateMixin {
  int correctCount = 0; // จำนวนข้อที่ตอบถูก
  bool _answered = false; // กันกดตอบซ้ำระหว่างโชว์ผล
  int currentIndex = 0;
  bool isPlaying = false;
  bool _loading = true; // กำลังเช็กว่ามีเกมเล่นค้างไว้ไหม

  // เหรียญจริงจากเซิร์ฟเวอร์ (2 เหรียญต่อสัตว์ 1 ตัว ต่อวัน)
  int _coinsBefore = 0; // เหรียญที่ได้ไปแล้วก่อนกลับมาเล่นต่อ
  int _coinsNow = 0; // เหรียญที่ได้ในรอบที่เปิดเล่นอยู่นี้
  final List<Future<GuessCoinResult>> _coinFutures = [];
  bool _resultSent = false; // ส่งผลให้รายงานผู้ปกครองครั้งเดียว

  static const List<String> _allAnimals = [
    'BEE', 'BIRD', 'CAT', 'CHICKEN', 'DOG', 'DUCK',
    'ELEPHANT', 'FROG', 'GECKO', 'LION', 'MONKEY', 'MOUSE', 'SHEEP', 'SNAKE'
  ];

  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _animationController;

  // ============================================================
  // COLOR PALETTE (พาสเทลน่ารัก สดใสสำหรับเด็ก)
  // ============================================================
  static const Color primarySky = Color(0xFFF59A1B);
  static const Color softSkyBackground = Color(0xFFFFEBCF);
  static const Color containerBg = Color(0xFFFFF1DC);
  static const Color borderSky = Color(0xFFFFD39A);
  static const Color darkSkyText = Color(0xFFC2650A);

  final Map<String, String> animalEmojis = {
    'BEE': '🐝',
    'BIRD': '🐦',
    'CAT': '🐱',
    'CHICKEN': '🐔',
    'DOG': '🐶',
    'DUCK': '🦆',
    'ELEPHANT': '🐘',
    'FROG': '🐸',
    'GECKO': '🦎',
    'LION': '🦁',
    'MONKEY': '🐒',
    'MOUSE': '🐭',
    'SHEEP': '🐑',
    'SNAKE': '🐍',
  };

  late List<Map<String, dynamic>> questions;

  final List<Map<String, dynamic>> rawQuestions = [
    {'soundPath': 'sounds/animal/bee.mp3', 'correctAnswer': 'BEE', 'options': ['BEE', 'BIRD', 'FROG']},
    {'soundPath': 'sounds/animal/bird.mp3', 'correctAnswer': 'BIRD', 'options': ['DUCK', 'BIRD', 'CHICKEN']},
    {'soundPath': 'sounds/animal/cat.mp3', 'correctAnswer': 'CAT', 'options': ['LION', 'CAT', 'DOG']},
    {'soundPath': 'sounds/animal/chicken.mp3', 'correctAnswer': 'CHICKEN', 'options': ['CHICKEN', 'DUCK', 'SHEEP']},
    {'soundPath': 'sounds/animal/dog.mp3', 'correctAnswer': 'DOG', 'options': ['DOG', 'CAT', 'MONKEY']},
    {'soundPath': 'sounds/animal/duck.mp3', 'correctAnswer': 'DUCK', 'options': ['BIRD', 'DUCK', 'FROG']},
    {'soundPath': 'sounds/animal/elephant.mp3', 'correctAnswer': 'ELEPHANT', 'options': ['ELEPHANT', 'LION', 'SHEEP']},
    {'soundPath': 'sounds/animal/frog.mp3', 'correctAnswer': 'FROG', 'options': ['GECKO', 'FROG', 'SNAKE']},
    {'soundPath': 'sounds/animal/gecko.mp3', 'correctAnswer': 'GECKO', 'options': ['SNAKE', 'MOUSE', 'GECKO']},
    {'soundPath': 'sounds/animal/lion.mp3', 'correctAnswer': 'LION', 'options': ['LION', 'CAT', 'DOG']},
    {'soundPath': 'sounds/animal/monkey.mp3', 'correctAnswer': 'MONKEY', 'options': ['ELEPHANT', 'MONKEY', 'BEE']},
    {'soundPath': 'sounds/animal/mouse.mp3', 'correctAnswer': 'MOUSE', 'options': ['MOUSE', 'GECKO', 'CAT']},
    {'soundPath': 'sounds/animal/sheep.mp3', 'correctAnswer': 'SHEEP', 'options': ['CHICKEN', 'SHEEP', 'DUCK']},
    {'soundPath': 'sounds/animal/snake.mp3', 'correctAnswer': 'SNAKE', 'options': ['SNAKE', 'GECKO', 'FROG']},
  ];

  @override
  void initState() {
    super.initState();
    _initGameData();
    if (CoinBalance.value.value == null) CoinBalance.refresh();
    AnimalSoundCoins.flush();
    _restoreSavedGame();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
      }
      _animationController.stop();
    });
  }

  void _initGameData() {
    final random = Random();
    questions = List.from(rawQuestions)..shuffle(random);

    const allAnimals = [
      'BEE', 'BIRD', 'CAT', 'CHICKEN', 'DOG', 'DUCK',
      'ELEPHANT', 'FROG', 'GECKO', 'LION', 'MONKEY', 'MOUSE', 'SHEEP', 'SNAKE'
    ];

    // Every game: the right animal + 2 random others, so the choices
    // can't be remembered without listening.
    questions = [
      for (final q in questions)
        {
          ...q,
          'options': [
            q['correctAnswer'] as String,
            ...(allAnimals.where((a) => a != q['correctAnswer']).toList()..shuffle(random)).take(2),
          ]..shuffle(random),
        },
    ];
  }

  // ---------- เล่นต่อจากข้อเดิม (แยกตามบัญชี เก็บบนเซิร์ฟเวอร์ด้วย) ----------

  AnimalSoundRound _currentRound() => AnimalSoundRound(
        order: [for (final q in questions) q['correctAnswer'] as String],
        options: [for (final q in questions) List<String>.from(q['options'])],
        index: currentIndex,
        correct: correctCount,
        coins: min(_coinsBefore + _coinsNow, correctCount * kGameCoinsPerWord),
      );

  Future<void> _restoreSavedGame() async {
    final animals = _allAnimals.toSet();
    var saved = await AnimalSoundProgress.load(animals);
    if (saved == null) {
      // Nothing on this phone (e.g. reinstalled): ask the server, briefly.
      await AnimalSoundProgress.sync()
          .timeout(const Duration(seconds: 4), onTimeout: () {});
      if (!mounted) return;
      saved = await AnimalSoundProgress.load(animals);
    } else {
      AnimalSoundProgress.sync(); // in the background
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (saved == null) {
      _playSound(); // first question plays by itself
      return;
    }
    final resume = await _askResume(saved);
    if (!mounted) return;
    if (resume == true) {
      final round = saved; // non-null copy for the closure below
      await _audioPlayer.stop();
      _animationController.stop();
      setState(() {
        questions = [
          for (int i = 0; i < round.order.length; i++)
            {
              'soundPath': rawQuestions.firstWhere(
                (q) => q['correctAnswer'] == round.order[i],
              )['soundPath'],
              'correctAnswer': round.order[i],
              'options': List<String>.from(round.options[i]),
            },
        ];
        currentIndex = round.index;
        correctCount = round.correct;
        _coinsBefore = round.coins;
        _coinsNow = 0;
        _coinFutures.clear();
        _answered = false;
        _resultSent = false;
        isPlaying = false;
      });
    } else {
      await AnimalSoundProgress.clear();
    }
    if (mounted) _playSound();
  }

  Future<bool?> _askResume(AnimalSoundRound saved) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: primarySky.withValues(alpha: 0.35), width: 2.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill_rounded, color: primarySky, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'เล่นค้างไว้',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'เล่นถึงข้อ ${saved.index + 1} จาก ${saved.order.length} ข้อ '
          '(ตอบถูก ${saved.correct} ข้อ)\nจะเล่นต่อเลยไหม ?',
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
                    foregroundColor: primarySky,
                    side: BorderSide(color: primarySky.withValues(alpha: 0.5), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    backgroundColor: primarySky,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  /// End of the game: result for the parent report (once), best score, and
  /// no unfinished game any more.
  void _finishGame() {
    if (!_resultSent) {
      _resultSent = true;
      ListeningResults.submit(
        game: 'animal_sound',
        score: correctCount,
        total: questions.length,
      );
      AnimalSoundProgress.saveFinished(
        (correctCount * 100 / questions.length).round().clamp(0, 100).toInt(),
      );
    }
    Sfx.complete();
    _showCompletionDialog();
  }

  Widget _coinLine(String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BigGoldCoin(size: 26),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: darkSkyText,
              ),
            ),
          ),
        ],
      );

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _playSound() async {
    final String soundPath = questions[currentIndex]['soundPath'];

    try {
      await _audioPlayer.stop();
      if (!mounted) return;

      setState(() {
        isPlaying = true;
      });

      _animationController.repeat(reverse: true);
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isPlaying = false;
      });
      _animationController.stop();
      debugPrint('Audio Error: $e');
    }
  }

  // dialog ที่ปุ่ม Back ของเครื่องปิดไม่ได้ (กันเกมค้าง/ตอบข้อเดิมซ้ำ)
  Future<void> _showLockedDialog(WidgetBuilder builder) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(canPop: false, child: builder(ctx)),
      );

  Future<void> _checkAnswer(String selected) async {
    if (_answered || _loading) return;
    _answered = true;
    await _audioPlayer.stop();

    if (!mounted) return;

    setState(() {
      isPlaying = false;
    });

    _animationController.stop();

    final String correctAnswer = questions[currentIndex]['correctAnswer'];
    final bool isCorrect = selected == correctAnswer;
    isCorrect ? Sfx.correct() : Sfx.wrong();

    Future<GuessCoinResult>? coinFuture;
    if (isCorrect) {
      coinFuture = AnimalSoundCoins.submit(correctAnswer);
      _coinFutures.add(coinFuture);
      coinFuture.then((r) {
        if (mounted) _coinsNow += r.coins;
      });
      setState(() {
        correctCount += 1;
      });
    }

    final String correctEmoji = animalEmojis[correctAnswer] ?? '🐾';

    _showLockedDialog(
      (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isCorrect ? const Color(0xFF86EFAC) : const Color(0xFFFECDD3),
              width: 4,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: isCorrect ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isCorrect ? Colors.green : Colors.red).withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    isCorrect ? correctEmoji : '❌',
                    style: const TextStyle(fontSize: 52),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isCorrect ? "ถูกต้องแล้วนะ" : "ยังไม่ถูกนะ",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isCorrect ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCorrect
                    ? "ตัวนี้คือ $correctAnswer"
                    : "คำตอบที่ถูกคือ $correctAnswer\nลองใหม่ข้อต่อไปนะ",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              if (coinFuture != null) ...[
                const SizedBox(height: 12),
                FutureBuilder<GuessCoinResult>(
                  future: coinFuture,
                  builder: (_, snap) {
                    final r = snap.data;
                    if (r == null) return _coinLine('กำลังรับเหรียญ...');
                    if (r.pending) return _coinLine('+$kGameCoinsPerWord เหรียญ (รอต่อเน็ต)');
                    if (r.coins > 0) return _coinLine('+${r.coins} เหรียญ');
                    if (r.alreadyToday) return _coinLine('ตัวนี้ได้เหรียญไปแล้ววันนี้');
                    return const SizedBox.shrink();
                  },
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primarySky,
                    elevation: 3,
                    shadowColor: const Color(0xFFC2650A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (currentIndex < questions.length - 1) {
                      setState(() {
                        currentIndex++;
                        _answered = false;
                      });
                      AnimalSoundProgress.save(_currentRound());
                      _playSound(); // new question plays by itself
                    } else {
                      _finishGame();
                    }
                  },
                  child: Text(
                    currentIndex < questions.length - 1 ? "ข้อต่อไป" : "ดูผลลัพธ์",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompletionDialog() {
    final double percentage = correctCount / questions.length;

    String feedbackText = "พยายามได้ดีมาก ลองเล่นอีกครั้งนะ";
    if (percentage >= 0.8) {
      feedbackText = "สุดยอดไปเลย เก่งมาก ๆ";
    } else if (percentage >= 0.5) {
      feedbackText = "เก่งจังเลย อีกนิดเดียวจะเต็มแล้ว";
    }

    _showLockedDialog(
      (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text(
                  "จบเกมแล้ว",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: darkSkyText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  feedbackText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: containerBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderSky, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "ตอบถูก $correctCount จาก ${questions.length} ข้อ",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          color: darkSkyText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<List<GuessCoinResult>>(
                        future: Future.wait(_coinFutures),
                        builder: (_, snap) {
                          final list = snap.data;
                          if (list == null) return _coinLine('กำลังนับเหรียญ...');
                          final coins = _coinsBefore +
                              list.fold<int>(0, (sum, r) => sum + r.coins);
                          final pending = list.where((r) => r.pending).length;
                          return _coinLine(
                            pending > 0
                                ? 'ได้ $coins เหรียญ (+${pending * kGameCoinsPerWord} รอต่อเน็ต)'
                                : 'ได้ $coins เหรียญ',
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primarySky,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _initGameData();
                        currentIndex = 0;
                        correctCount = 0;
                        _coinsBefore = 0;
                        _coinsNow = 0;
                        _coinFutures.clear();
                        _resultSent = false;
                        _answered = false;
                        isPlaying = false;
                      });
                      _playSound();
                    },
                    icon: const Icon(Icons.replay_rounded, color: Colors.white),
                    label: const Text(
                      "เล่นอีกครั้ง",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primarySky, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.home_rounded, color: primarySky),
                    label: const Text(
                      "กลับหน้าหลัก",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primarySky,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = questions[currentIndex];
    // Bar = questions answered so far (full only after the last answer).
    final double progress = (currentIndex + (_answered ? 1 : 0)) / questions.length;
    final List<String> options = List<String>.from(currentQ['options']);

    return Scaffold(
      backgroundColor: softSkyBackground,
      body: _GameScaffoldBody(
        title: 'เสียงสัตว์',
        color: const Color(0xFFF59A1B),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFDDB8), Color(0xFFFFEBD6), Color(0xFFFFF5EA)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: ClipRect(
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -50,
                    child: _bubble(Colors.white.withValues(alpha: 0.35), 190),
                  ),
                  LayoutBuilder(
                    builder: (context, box) {
                      final double contentH = max(box.maxHeight, 560.0);
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          height: contentH,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Column(
                              children: [
                                _buildHeaderRow(),
                                const SizedBox(height: 8),
                                _buildProgressCard(progress),
                                const SizedBox(height: 10),
                                Expanded(flex: 5, child: _buildSoundCard()),
                                // Same gap above and below the sign, so it sits
                                // halfway between the sound card and the answers.
                                const SizedBox(height: 14),
                                _buildQuestionSign(),
                                const SizedBox(height: 14),
                                // Smaller answer cards with a gap between them.
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      for (int i = 0; i < options.length; i++) ...[
                                        if (i > 0) const SizedBox(height: 8),
                                        Flexible(
                                          child: SizedBox(
                                            height: 82,
                                            child: _buildOptionCard(i, options[i]),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_loading)
                    Positioned.fill(
                      child: ColoredBox(
                        color: softSkyBackground.withValues(alpha: 0.85),
                        child: const Center(
                          child: CircularProgressIndicator(color: primarySky),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- หัวเรื่อง Animal Sounds + ป้ายเหรียญ/ดาว ----------
  Widget _buildHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // One strong colour: the deep orange of the top bar.
                  const Text(
                    'Animal Sounds',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE8590C),
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(
                          color: Color(0x33E8590C),
                          offset: Offset(0, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Text(
                'ทายเสียงสัตว์สนุก ๆ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B4A33),
                ),
              ),
            ],
          ),
        ),
        _buildScorePill(),
      ],
    );
  }

  Widget _buildScorePill() {
    return SizedBox(
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 24),
            padding: const EdgeInsets.fromLTRB(24, 6, 18, 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF9B6B4B), Color(0xFF7A4E32)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF6A4128), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5E3512).withValues(alpha: 0.35),
                  offset: const Offset(0, 3),
                  blurRadius: 4,
                ),
              ],
            ),
            // The account's real coins (same as the other games).
            child: ValueListenableBuilder<int?>(
              valueListenable: CoinBalance.value,
              builder: (_, coins, _) => Text(
                coins == null ? '-' : '$coins',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
          const Positioned(left: 0, top: 1, child: _BigGoldCoin(size: 46)),
        ],
      ),
    );
  }

  // ---------- การ์ดความคืบหน้า ----------
  Widget _buildProgressCard(double progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFE3C2), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC2650A).withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'ข้อที่',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF8A4B14)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9D2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${currentIndex + 1} / ${questions.length}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF8A4B14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 13,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9D6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD2AD), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v,
                    heightFactor: 1,
                    // One colour: the orange of this game.
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFFF97316)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- การ์ดป่า + ปุ่มลำโพง ----------
  Widget _buildSoundCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D5B).withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: LayoutBuilder(
          builder: (context, box) {
            final double ch = box.maxHeight;
            final double s = (ch / 172).clamp(0.6, 1.1);
            // Centred in the space under the "แตะเพื่อฟังเสียงสัตว์" label.
            const double labelBottom = 30;
            final double btn = (ch - labelBottom - 16).clamp(56.0, 104.0);
            final double btnTop = max(
              labelBottom,
              labelBottom + (ch - labelBottom - btn) / 2,
            );
            return Stack(
              children: [
                const Positioned.fill(child: CustomPaint(painter: _JunglePainter())),
                Positioned(left: 14 * s, bottom: 4, child: Text('🌼', style: TextStyle(fontSize: 22 * s))),
                Positioned(right: 18 * s, bottom: 2, child: Text('🌷', style: TextStyle(fontSize: 22 * s))),
                Positioned(left: 64 * s, top: 52 * s, child: Text('🐦', style: TextStyle(fontSize: 26 * s))),
                Positioned(right: 22 * s, top: 82 * s, child: Text('🦜', style: TextStyle(fontSize: 26 * s))),
                Positioned(left: 8, bottom: 6, child: Text('🦁', style: TextStyle(fontSize: 66 * s))),
                Positioned(right: 6, bottom: 4, child: Text('🐘', style: TextStyle(fontSize: 70 * s))),
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E2).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFDDB5), width: 1.5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'แตะเพื่อฟังเสียงสัตว์',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF8A4B14)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: btnTop,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildSpeakerButton(btn)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpeakerButton(double size) {
    final Color glow = isPlaying ? const Color(0xFFFF5252) : const Color(0xFFFF7A2F);
    return GestureDetector(
      onTap: _playSound,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.08).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
        ),
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.055),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.85),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.4),
                blurRadius: 18,
                spreadRadius: isPlaying ? 4 : 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                radius: 1.0,
                colors: isPlaying
                    ? const [Color(0xFFFF8A8A), Color(0xFFE53935)]
                    : const [Color(0xFFFF9A52), Color(0xFFE8412A)],
              ),
              border: Border.all(color: const Color(0xFFFFC9A6), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPlaying ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                  size: size * 0.38,
                  color: Colors.white,
                ),
                Text(
                  isPlaying ? 'กำลังเล่น...' : 'กดตรงนี้',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (size * 0.115).clamp(10.0, 13.0),
                    fontWeight: FontWeight.w900,
                    shadows: const [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x66000000))],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- ป้ายไม้คำถาม ----------
  Widget _buildQuestionSign() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFB98154), Color(0xFF9A6338)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6B4020), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5E3512).withValues(alpha: 0.5),
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'สัตว์ตัวไหนเอ่ย ?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFF3D0),
                  shadows: [Shadow(offset: Offset(0, 1.5), blurRadius: 1, color: Color(0xFF5E3512))],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- การ์ดตัวเลือก ----------
  Widget _buildOptionCard(int index, String title) {
    final pal = _optionPalettes[index % _optionPalettes.length];
    final String emoji = animalEmojis[title] ?? '🐾';

    return LayoutBuilder(
      builder: (context, box) {
        final double cardH = max(box.maxHeight - 8, 40.0);
        final double tile = (cardH - 6 - 16).clamp(32.0, 58.0);
        final double btn = (tile * 0.84).clamp(30.0, 48.0);
        final double titleSize = (tile * 0.42).clamp(15.0, 24.0);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () => _checkAnswer(title),
              child: Container(
                width: double.infinity,
                height: cardH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: pal.border, width: 3),
                  gradient: LinearGradient(colors: [pal.bgLeft, pal.bgRight]),
                  boxShadow: [
                    BoxShadow(color: pal.shadow, offset: const Offset(0, 6)),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              // The animal emoji on its own (no box around it).
                              SizedBox(
                                width: tile,
                                child: Center(
                                  child: Text(emoji, style: TextStyle(fontSize: tile * 0.72)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: pal.text,
                                  ),
                                ),
                              ),
                              Container(
                                width: btn,
                                height: btn,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  // One colour: the dark shade of this card's frame.
                                  color: pal.shadow,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.touch_app_rounded, color: Colors.white, size: btn * 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bubble(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  // ignore: unused_element
  Widget _roundIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderSky, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// ป้ายแสดงเหรียญ
// ---------------------------------------------------------------
class _CoinPill extends StatelessWidget {
  final int coins;
  final Color color;
  final double fontSize;

  const _CoinPill({
    // ignore: unused_element_parameter
    this.coins = 0,
    // ignore: unused_element_parameter
    this.color = const Color(0xFFB45309),
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final double fs = fontSize;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fs * 0.7, vertical: fs * 0.3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(fs * 1.6),
        border: Border.all(color: const Color(0xFFFFD43B), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.monetization_on_rounded,
            color: const Color(0xFFFFB627),
            size: fs * 1.45,
          ),
          SizedBox(width: fs * 0.35),
          Text(
            '$coins',
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _CoinPillBar extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final double fontSize;

  const _CoinPillBar({
    // ignore: unused_element_parameter
    this.padding = const EdgeInsets.only(bottom: 8),
    // ignore: unused_element_parameter
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: padding,
        child: _CoinPill(fontSize: fontSize),
      ),
    );
  }
}


// ---------------------------------------------------------------
// แถบหัวเรื่องด้านบนของเกม (ปุ่มย้อนกลับ + ชื่อเกม บนพื้นสีประจำเกม)
// ---------------------------------------------------------------
class _GameHeaderBar extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onBack;
  final bool showBack;

  const _GameHeaderBar({
    required this.title,
    required this.color,
    this.onBack,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (showBack)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onBack ?? () => Navigator.maybePop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                )
              else
                const SizedBox(width: 34),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameScaffoldBody extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onBack;
  final bool showBack;
  final Widget child;

  const _GameScaffoldBody({
    required this.title,
    required this.color,
    required this.child,
    // ignore: unused_element_parameter
    this.onBack,
    // ignore: unused_element_parameter
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GameHeaderBar(
          title: title,
          color: color,
          onBack: onBack,
          showBack: showBack,
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// ชุดสีของการ์ดตัวเลือกแต่ละใบ
// ---------------------------------------------------------------
enum _TexKind { fur, fluff, scales }

class _OptionPalette {
  final Color border;
  final Color shadow;
  final Color bgLeft;
  final Color bgRight;
  final Color text;
  final _TexKind kind;
  final Color texBase;
  final Color texAccent;
  final List<Color> ring;
  final List<Color> btn;

  const _OptionPalette({
    required this.border,
    required this.shadow,
    required this.bgLeft,
    required this.bgRight,
    required this.text,
    required this.kind,
    required this.texBase,
    required this.texAccent,
    required this.ring,
    required this.btn,
  });
}

const List<_OptionPalette> _optionPalettes = [
  _OptionPalette(
    border: Color(0xFFF5A524),
    shadow: Color(0xFFE08A0B),
    bgLeft: Color(0xFFFFF3DC),
    bgRight: Color(0xFFF3DDB8),
    text: Color(0xFF7A3B12),
    kind: _TexKind.fur,
    texBase: Color(0xFFC99A68),
    texAccent: Color(0xFF8E6338),
    ring: [Color(0xFFFFB347), Color(0xFFB66DFF), Color(0xFFFF7A59), Color(0xFFFFB347)],
    btn: [Color(0xFFFFB05A), Color(0xFFE8700F)],
  ),
  _OptionPalette(
    border: Color(0xFFF06FA6),
    shadow: Color(0xFFDB4585),
    bgLeft: Color(0xFFFFE6F0),
    bgRight: Color(0xFFFFC4DB),
    text: Color(0xFF8E1F4F),
    kind: _TexKind.fluff,
    texBase: Color(0xFFF7A8C8),
    texAccent: Color(0xFFFFFFFF),
    ring: [Color(0xFFFF6FA8), Color(0xFF4FC3F7), Color(0xFFB66DFF), Color(0xFFFF6FA8)],
    btn: [Color(0xFFFF7FB0), Color(0xFF3BA8E0)],
  ),
  _OptionPalette(
    border: Color(0xFF3DBE6A),
    shadow: Color(0xFF2A9A52),
    bgLeft: Color(0xFFE6FAE4),
    bgRight: Color(0xFFBFE8A8),
    text: Color(0xFF14532D),
    kind: _TexKind.scales,
    texBase: Color(0xFF6DBA3B),
    texAccent: Color(0xFFD4EC6B),
    ring: [Color(0xFF3DBE6A), Color(0xFFF5A524), Color(0xFF4FC3F7), Color(0xFF3DBE6A)],
    btn: [Color(0xFF5ED08A), Color(0xFF2A9A52)],
  ),
];

// ---------------------------------------------------------------
// เหรียญทองใหญ่ (ป้ายคะแนน)
// ---------------------------------------------------------------
class _BigGoldCoin extends StatelessWidget {
  final double size;
  const _BigGoldCoin({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFEB8A), Color(0xFFF5B000)],
        ),
        border: Border.all(color: const Color(0xFFD98E00), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        width: size * 0.72,
        height: size * 0.72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5A100), width: 2),
        ),
        child: Text(
          '\$',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFC77700),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// ฉากป่าในการ์ดลำโพง
// ---------------------------------------------------------------
class _JunglePainter extends CustomPainter {
  const _JunglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final full = Offset.zero & size;

    // Soft sky: light blue at the top, warm cream lower down.
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBFE6FF), Color(0xFFE4F4FF), Color(0xFFFFF4E0)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(full),
    );

    // Pastel rainbow behind the speaker button.
    const rainbow = [
      Color(0xFFFFB3BA),
      Color(0xFFFFDFBA),
      Color(0xFFFFF5BA),
      Color(0xFFBAFFC9),
      Color(0xFFBAE1FF),
    ];
    final center = Offset(w * 0.5, h * 0.86);
    for (int i = 0; i < rainbow.length; i++) {
      final r = h * 0.62 - i * h * 0.045;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        pi,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.045
          ..color = rainbow[i].withValues(alpha: 0.75),
      );
    }

    // Smiling sun (top right).
    final sun = Offset(w * 0.86, h * 0.2);
    final sr = h * 0.1;
    canvas.drawCircle(sun, sr * 1.7, Paint()..color = const Color(0xFFFFE680).withValues(alpha: 0.35));
    canvas.drawCircle(sun, sr, Paint()..color = const Color(0xFFFFD54F));
    final face = Paint()..color = const Color(0xFF8A5A00);
    canvas.drawCircle(sun + Offset(-sr * 0.35, -sr * 0.15), sr * 0.1, face);
    canvas.drawCircle(sun + Offset(sr * 0.35, -sr * 0.15), sr * 0.1, face);
    canvas.drawArc(
      Rect.fromCenter(center: sun + Offset(0, sr * 0.12), width: sr * 0.8, height: sr * 0.55),
      0.2,
      pi - 0.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sr * 0.1
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8A5A00),
    );
    canvas.drawCircle(sun + Offset(-sr * 0.55, sr * 0.2), sr * 0.14,
        Paint()..color = const Color(0xFFFF9E80).withValues(alpha: 0.7));
    canvas.drawCircle(sun + Offset(sr * 0.55, sr * 0.2), sr * 0.14,
        Paint()..color = const Color(0xFFFF9E80).withValues(alpha: 0.7));

    // Fluffy clouds.
    void cloud(double x, double y, double r) {
      final p = Paint()..color = Colors.white.withValues(alpha: 0.95);
      canvas.drawCircle(Offset(x, y), r, p);
      canvas.drawCircle(Offset(x + r * 0.9, y + r * 0.15), r * 0.8, p);
      canvas.drawCircle(Offset(x - r * 0.9, y + r * 0.2), r * 0.7, p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - r * 1.5, y + r * 0.1, r * 3.1, r * 0.8),
          Radius.circular(r * 0.4),
        ),
        p,
      );
    }

    cloud(w * 0.16, h * 0.2, h * 0.075);
    cloud(w * 0.62, h * 0.12, h * 0.055);

    // Two rolling hills, back and front.
    final back = Path()
      ..moveTo(0, h * 0.74)
      ..quadraticBezierTo(w * 0.25, h * 0.6, w * 0.5, h * 0.72)
      ..quadraticBezierTo(w * 0.78, h * 0.84, w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFFC8EBA5));
    final front = Path()
      ..moveTo(0, h * 0.86)
      ..quadraticBezierTo(w * 0.35, h * 0.76, w * 0.62, h * 0.86)
      ..quadraticBezierTo(w * 0.85, h * 0.94, w, h * 0.82)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA6DD7C), Color(0xFF8BCF63)],
        ).createShader(Rect.fromLTWH(0, h * 0.76, w, h * 0.24)),
    );

    // Little flowers on the grass.
    void flower(double x, double y, double r, Color petal) {
      final p = Paint()..color = petal;
      for (int i = 0; i < 5; i++) {
        final a = i * 2 * pi / 5;
        canvas.drawCircle(Offset(x + cos(a) * r, y + sin(a) * r), r * 0.75, p);
      }
      canvas.drawCircle(Offset(x, y), r * 0.6, Paint()..color = const Color(0xFFFFD54F));
    }

    flower(w * 0.3, h * 0.88, h * 0.022, const Color(0xFFFFFFFF));
    flower(w * 0.42, h * 0.95, h * 0.02, const Color(0xFFFFB3C7));
    flower(w * 0.58, h * 0.92, h * 0.022, const Color(0xFFFFFFFF));
    flower(w * 0.7, h * 0.97, h * 0.02, const Color(0xFFB3D9FF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
