import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../services/guess_progress_service.dart' show GuessCoinResult;
import '../../../services/riddle_progress_service.dart';
import '../../../widgets/coin_balance_chip.dart';
import 'riddle_data.dart';
import '../../../services/coin_balance.dart';

export 'riddle_data.dart' show RiddleQuestion, RiddleCategoryItem;

class PlacedLetter {
  final String char;
  final int originalKeyIndex;

  /// Put there by "ขอตัวช่วย": always right and can't be taken out.
  final bool hinted;

  PlacedLetter({
    required this.char,
    required this.originalKeyIndex,
    this.hinted = false,
  });
}

/// What the child chose on the answer sheet.
enum _SheetAction { next, retry, reveal }

class RiddleGamePlayScreen extends StatefulWidget {
  final RiddleCategoryItem category;

  /// An unfinished game to continue (null = new game).
  final RiddleRound? resume;

  const RiddleGamePlayScreen({super.key, required this.category, this.resume});

  @override
  State<RiddleGamePlayScreen> createState() => _RiddleGamePlayScreenState();
}

class _RiddleGamePlayScreenState extends State<RiddleGamePlayScreen>
    with TickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();
  final math.Random _random = math.Random();

  /// Questions still to do; the current one is first, skipped ones go last.
  List<RiddleQuestion> _queue = [];
  int _total = 0;
  int _done = 0;
  int _mistakes = 0;

  /// Questions where "ดูเฉลย" was used (counted in [_done], no coin).
  int _revealed = 0;
  int _hints = 0;
  int _coins = 0;
  int _pending = 0;
  bool _completed = false;

  /// Changes for every new game, so late callbacks of an old one are ignored.
  int _gameId = 0;

  /// A pop-up is open or an answer is being checked: ignore taps.
  bool _busy = false;

  /// Hints used per word in this game, kept when the word is skipped so
  /// skipping can't give fresh hints.
  final Map<String, int> _hintsByWord = {};
  int _hintsUsedInCurrentQuestion = 0;

  RiddleQuestion get _currentQ => _queue.first;

  /// The letters to type for the current question (no spaces).
  String get _target => _currentQ.letters;

  int get _maxHintsForCurrentQuestion => riddleMaxHints(_currentQ.answer);

  int get _remainingHints =>
      math.max(0, _maxHintsForCurrentQuestion - _hintsUsedInCurrentQuestion);

  List<String> _shuffledLetters = [];
  List<bool> _usedLetters = [];
  final List<PlacedLetter> _userAnswers = [];

  bool _isAnswerCorrect = false;
  bool _hasError = false;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _initTts();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _setUpGame(widget.resume);
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.38);
      await _flutterTts.setPitch(1.30);
    } catch (_) {}
  }

  /// Starts a new shuffled game, or continues [resume].
  void _setUpGame(RiddleRound? resume) {
    _gameId++;
    final all = widget.category.questions;
    final byAnswer = {for (final q in all) q.answer: q};
    _hintsByWord.clear();
    _total = all.length;
    if (resume != null) {
      _queue = [
        for (final a in resume.queue)
          if (byAnswer[a] != null) byAnswer[a]!,
      ];
      _done = resume.done;
      _mistakes = resume.mistakes;
      _revealed = resume.revealed;
      _hints = resume.hints;
      _coins = resume.coins;
      _pending = resume.pending;
    } else {
      _queue = List<RiddleQuestion>.from(all)..shuffle(_random);
      _done = 0;
      _mistakes = 0;
      _revealed = 0;
      _hints = 0;
      _coins = 0;
      _pending = 0;
    }
    _busy = false;
    _completed = _queue.isEmpty;
    if (!_completed) _setupQuestion();
  }

  /// Gets the board ready for [_currentQ] (call inside setState / initState).
  void _setupQuestion() {
    _userAnswers.clear();
    _isAnswerCorrect = false;
    _hasError = false;
    _hintsUsedInCurrentQuestion = _hintsByWord[_currentQ.answer] ?? 0;

    final letters = _target.split('');
    if (letters.toSet().length > 1) {
      do {
        letters.shuffle(_random);
      } while (letters.join('') == _target);
    }
    _shuffledLetters = letters;
    _usedLetters = List<bool>.filled(_shuffledLetters.length, false);

    // Hints used before the word was skipped stay on the board.
    for (var i = 0;
        i < _hintsUsedInCurrentQuestion && i < _target.length - 1;
        i++) {
      _placeCorrectLetter(i);
    }
  }

  /// Puts the right letter at [position] (= the current length of the answer).
  void _placeCorrectLetter(int position) {
    final correctChar = _target[position];
    for (int i = 0; i < _shuffledLetters.length; i++) {
      if (!_usedLetters[i] && _shuffledLetters[i] == correctChar) {
        _usedLetters[i] = true;
        _userAnswers.add(
          PlacedLetter(char: correctChar, originalKeyIndex: i, hinted: true),
        );
        return;
      }
    }
  }

  /// Letters at the start that came from hints (everything before the last
  /// hinted letter is right, so none of these can be removed).
  int get _lockedCount {
    for (var i = _userAnswers.length - 1; i >= 0; i--) {
      if (_userAnswers[i].hinted) return i + 1;
    }
    return 0;
  }

  /// Questions spelled right (the rest of [_done] were revealed).
  int get _correct => math.max(0, _done - _revealed);

  int get _accuracy {
    final tries = _correct + _mistakes;
    return tries == 0 ? 0 : (_correct * 100 / tries).round();
  }

  /// Saves the game so it can be continued (also on another phone).
  void _saveProgress() {
    if (_completed) return;
    // A word answered correctly is done even while its sheet is still open.
    final remaining = [
      for (final q in (_isAnswerCorrect ? _queue.skip(1) : _queue)) q.answer,
    ];
    if (remaining.isEmpty || _done < 1) return; // finished / nothing done yet
    RiddleProgress.save(
      widget.category.key,
      RiddleRound(
        queue: remaining,
        done: _done,
        mistakes: _mistakes,
        revealed: _revealed,
        hints: _hints,
        coins: math.min(_coins, _correct * kGameCoinsPerWord),
        pending: _pending,
      ),
    );
  }

  Future<void> _speak(String text, String language) async {
    try {
      await _flutterTts.stop();
      // Set every time: the Thai clue and the English word share one voice.
      await _flutterTts.setLanguage(language);
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  Future<void> _speakClue() => _speak(_currentQ.thaiClue, "th-TH");

  void _onLetterTap(int index) {
    if (_busy || _completed || _isAnswerCorrect) return;
    if (_usedLetters[index] || _userAnswers.length >= _target.length) return;

    setState(() {
      _usedLetters[index] = true;
      _userAnswers.add(
        PlacedLetter(char: _shuffledLetters[index], originalKeyIndex: index),
      );
      _hasError = false;
    });

    if (_userAnswers.length == _target.length) _checkAttempt();
  }

  Future<void> _checkAttempt() async {
    final game = _gameId;
    final question = _currentQ;
    final attempt = _userAnswers.map((e) => e.char).join('');

    if (attempt == _target) {
      final hintsUsed = _hintsUsedInCurrentQuestion;
      final allHintsUsed = hintsUsed >= _maxHintsForCurrentQuestion;
      _bounceController.forward(from: 0.0);
      setState(() {
        _isAnswerCorrect = true;
        _busy = true;
        _done++;
      });
      final isLast = _queue.length == 1;
      if (isLast) {
        RiddleProgress.saveFinished(widget.category.key, _accuracy);
      } else {
        _saveProgress();
      }

      // 1 coin per word per day; none when every hint was used.
      final coinFuture = RiddleCoins.submit(
        categoryKey: widget.category.key,
        answer: question.answer,
        hintsUsed: hintsUsed,
      ).then((result) {
        if (mounted && game == _gameId) {
          setState(() {
            _coins += result.coins;
            if (result.pending) _pending++;
          });
          _saveProgress();
        }
        return result;
      });

      _speak(question.spoken, "en-US");
      final action = await _showAnswerFeedbackSheet(
        isCorrect: true,
        question: question,
        coinFuture: coinFuture,
        allHintsUsed: allHintsUsed,
        isLast: isLast,
      );
      if (!mounted || game != _gameId) return;
      if (action == _SheetAction.next) _nextQuestion();
    } else {
      setState(() {
        _hasError = true;
        _busy = true;
        _mistakes++;
      });
      _saveProgress();

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted || game != _gameId) return;

      final action = await _showAnswerFeedbackSheet(
        isCorrect: false,
        question: question,
      );
      if (!mounted || game != _gameId) return;
      setState(() => _busy = false);
      if (action == _SheetAction.reveal) {
        _revealAnswer(question);
      } else {
        _resetLetters();
      }
    }
  }

  /// "ดูเฉลย": fills in the word, shows it, then goes on (no coin).
  Future<void> _revealAnswer(RiddleQuestion question) async {
    final game = _gameId;
    final isLast = _queue.length == 1;
    setState(() {
      while (_userAnswers.isNotEmpty) {
        final removed = _userAnswers.removeLast();
        _usedLetters[removed.originalKeyIndex] = false;
      }
      for (var i = 0; i < _target.length; i++) {
        _placeCorrectLetter(i);
      }
      _hasError = false;
      _isAnswerCorrect = true; // answered: no more typing
      _busy = true;
      _done++;
      _revealed++;
    });
    if (isLast) {
      RiddleProgress.saveFinished(widget.category.key, _accuracy);
    } else {
      _saveProgress();
    }

    _speak(question.spoken, "en-US");
    await _showRevealSheet(question: question, isLast: isLast);
    if (!mounted || game != _gameId) return;
    _nextQuestion();
  }

  Future<void> _showRevealSheet({
    required RiddleQuestion question,
    required bool isLast,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return PopScope(
          canPop: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: const Color(0xFF0369A1), width: 3.5),
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
                const Text(
                  'เฉลยข้อนี้',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        offset: Offset(0, 2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: Image.asset(
                          question.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_rounded,
                            size: 40,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          question.answer,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0369A1),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      Material(
                        color: const Color(0xFFE0F2FE),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _speak(question.spoken, "en-US"),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.volume_up_rounded,
                              color: Color(0xFF0284C7),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'จำคำนี้ไว้นะ ข้อที่ดูเฉลยจะไม่ได้เหรียญ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                _sheetButton(
                  label: isLast ? 'ดูผลคะแนน' : 'ไปข้อต่อไป',
                  icon: isLast ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
                  iconAfter: true,
                  height: 52,
                  fontSize: 17.5,
                  colors: const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                  shadow: const Color(0xFFB45309),
                  onTap: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _nextQuestion() {
    _flutterTts.stop();
    setState(() {
      _queue.removeAt(0);
      _busy = false;
      if (_queue.isEmpty) {
        _completed = true; // already saved as finished
      } else {
        _setupQuestion();
      }
    });
  }

  Future<_SheetAction?> _showAnswerFeedbackSheet({
    required bool isCorrect,
    required RiddleQuestion question,
    Future<GuessCoinResult>? coinFuture,
    bool allHintsUsed = false,
    bool isLast = false,
  }) {
    final Color sheetBg =
        isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final Color sheetBorder =
        isCorrect ? const Color(0xFF047857) : const Color(0xFFB91C1C);

    return showModalBottomSheet<_SheetAction>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        // The phone's back button must not close it without choosing.
        return PopScope(
          canPop: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: sheetBorder, width: 3.5),
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
                  height: 105,
                  child: Image.asset(
                    isCorrect
                        ? 'assets/images/character/bravo.png'
                        : 'assets/images/character/sad.png',
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) => Icon(
                          isCorrect
                              ? Icons.celebration_rounded
                              : Icons.sentiment_dissatisfied_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isCorrect ? 'ถูกต้อง เก่งมาก !' : 'ยังไม่ถูกน้า ลองดูอีกที',
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
                if (isCorrect) ...[
                  const SizedBox(height: 4),
                  Text(
                    question.answer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
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
                        Icon(
                          allHintsUsed
                              ? Icons.lightbulb_rounded
                              : Icons.monetization_on_rounded,
                          color: const Color(0xFFF59E0B),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        FutureBuilder<GuessCoinResult>(
                          future: coinFuture,
                          builder: (context, snap) {
                            final r = snap.data;
                            final String text;
                            if (allHintsUsed) {
                              text = 'ใช้ตัวช่วยครบ ข้อนี้ไม่ได้เหรียญนะ';
                            } else if (snap.connectionState != ConnectionState.done) {
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
                                  fontSize: 15.5,
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
                  const Text(
                    'อย่าเพิ่งยอมแพ้ ลองสะกดใหม่ หรือกดดูเฉลยก็ได้',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 1),
                          blurRadius: 1.5,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                if (isCorrect)
                  _sheetButton(
                    label: isLast ? 'ดูผลคะแนน' : 'ไปข้อต่อไป',
                    icon: isLast ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
                    iconAfter: true,
                    height: 52,
                    fontSize: 17.5,
                    colors: const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                    shadow: const Color(0xFFB45309),
                    onTap: () => Navigator.pop(sheetContext, _SheetAction.next),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _sheetButton(
                          label: 'ลองอีกครั้ง',
                          icon: Icons.refresh_rounded,
                          colors: const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                          shadow: const Color(0xFFB45309),
                          onTap: () => Navigator.pop(sheetContext, _SheetAction.retry),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _sheetButton(
                          label: 'ดูเฉลย',
                          icon: Icons.visibility_rounded,
                          colors: const [Color(0xFF38BDF8), Color(0xFF0284C7)],
                          shadow: const Color(0xFF0369A1),
                          onTap: () => Navigator.pop(sheetContext, _SheetAction.reveal),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required Color shadow,
    required VoidCallback onTap,
    bool iconAfter = false,
    double height = 50,
    double fontSize = 15.5,
  }) {
    final iconWidget = Icon(icon, color: Colors.white, size: iconAfter ? 22 : 20);
    final text = Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        letterSpacing: iconAfter ? 0.5 : 0,
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: shadow,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.only(bottom: 4.5),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                iconAfter
                    ? [text, const SizedBox(width: 8), iconWidget]
                    : [iconWidget, const SizedBox(width: 6), text],
          ),
        ),
      ),
    );
  }

  void _useHint() {
    if (_busy || _completed || _isAnswerCorrect) return;

    if (_hintsUsedInCurrentQuestion >= _maxHintsForCurrentQuestion) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ข้อนี้ใช้ตัวช่วยครบ ($_maxHintsForCurrentQuestion ตัว) แล้วนะ ลองสะกดดูนะค้าบ! 😊',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFD97706),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
      return;
    }

    // The first box that is empty or has a wrong letter.
    var position = 0;
    while (position < _userAnswers.length &&
        _userAnswers[position].char == _target[position]) {
      position++;
    }
    if (position >= _target.length) return;

    setState(() {
      // Give back the letters from there on, then put the right one in.
      while (_userAnswers.length > position) {
        final removed = _userAnswers.removeLast();
        _usedLetters[removed.originalKeyIndex] = false;
      }
      _placeCorrectLetter(position);
      _hintsUsedInCurrentQuestion++;
      _hintsByWord[_currentQ.answer] = _hintsUsedInCurrentQuestion;
      _hints++;
      _hasError = false;
    });

    if (_userAnswers.length == _target.length) {
      _checkAttempt();
    } else {
      _saveProgress();
    }
  }

  void _skipQuestion() {
    if (_busy || _completed || _isAnswerCorrect) return;
    if (_queue.length <= 1) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ข้อนี้เป็นข้อสุดท้ายแล้ว ลองเล่นดูนะ!'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    _flutterTts.stop();
    setState(() {
      _queue.add(_queue.removeAt(0));
      _setupQuestion();
    });
    _saveProgress();
  }

  void _removeLetterAt(int index) {
    if (_busy || _isAnswerCorrect || index >= _userAnswers.length) return;
    if (index < _lockedCount) return; // a hint letter

    setState(() {
      final removed = _userAnswers.removeAt(index);
      _usedLetters[removed.originalKeyIndex] = false;
      _hasError = false;
    });
  }

  void _removeLastLetter() {
    if (_userAnswers.length > _lockedCount) {
      _removeLetterAt(_userAnswers.length - 1);
    }
  }

  /// Takes back the typed letters (hint letters stay).
  void _resetLetters() {
    setState(() {
      final keep = _lockedCount;
      while (_userAnswers.length > keep) {
        final removed = _userAnswers.removeLast();
        _usedLetters[removed.originalKeyIndex] = false;
      }
      _hasError = false;
    });
  }

  /// End screen (part of the game page, so the phone's back button can't
  /// leave the game stuck behind a pop-up like the old one could).
  Widget _buildSummary() {
    final int percent = _accuracy;
    final int stars =
        percent >= 80
            ? 3
            : percent >= 50
            ? 2
            : percent > 0
            ? 1
            : 0;
    final String headline =
        percent >= 80
            ? 'เก่งมาก ยอดเยี่ยม'
            : percent >= 50
            ? 'ทำได้ดีมาก!'
            : 'สู้ ๆ นะ ลองอีกครั้ง!';
    const Color victoryPrimaryGreen = Color(0xFF10B981);
    const Color victoryDarkGreen = Color(0xFF047857);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [victoryPrimaryGreen, victoryDarkGreen],
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
                child: CustomPaint(painter: _ConfettiParticlesPainter()),
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
                        width: 210,
                        height: 210,
                        child: Image.asset(
                          'assets/images/character/bravo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
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
                            color: victoryDarkGreen,
                            offset: Offset(0, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'หมวด${widget.category.titleTh}\n ทายถูก $_correct จาก $_total ข้อ • ผิด $_mistakes ครั้ง',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16.5,
                          height: 1.45,
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
                          child: _summaryTile(
                            color: const Color(0xFFA78BFA),
                            icon: Icons.monetization_on_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            value: '+$_coins',
                            label:
                                _pending > 0
                                    ? 'เหรียญ (+${_pending * kGameCoinsPerWord} รอต่อเน็ต)'
                                    : 'เหรียญที่ได้รับ',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _summaryTile(
                            color: const Color(0xFFF472B6),
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF10B981),
                            value: '$percent%',
                            label: 'ความแม่นยำ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    GestureDetector(
                      onTap: () {
                        _flutterTts.stop();
                        setState(() => _setUpGame(null)); // new shuffled game
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
                      onTap: () => Navigator.pop(context),
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

  Widget _summaryTile({
    required Color color,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      height: 125,
      decoration: BoxDecoration(
        color: color,
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
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ],
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
          offset: const Offset(0, 3.5),
          blurRadius: 0,
        ),
      ],
    );
  }

  /// The answer boxes; a space or hyphen in the answer becomes a gap.
  Widget _buildAnswerSlots() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final String answer = _currentQ.answer;
        final int slotCount = _target.length;
        final int gapCount = answer.length - slotCount;
        final double horizontalGap = slotCount > 8 ? 2.0 : 3.5;
        const double wordGap = 12.0;
        final double availableWidth =
            constraints.maxWidth -
            (slotCount * horizontalGap * 2) -
            (gapCount * wordGap);
        final double slotWidth = math.max(
          18.0,
          math.min(44.0, availableWidth / slotCount),
        );
        final int locked = _lockedCount;

        final children = <Widget>[];
        var index = 0;
        for (final ch in answer.split('')) {
          if (!RegExp(r'[A-Z]').hasMatch(ch)) {
            children.add(
              SizedBox(
                width: wordGap,
                child:
                    ch == '-'
                        ? const Center(
                          child: Text(
                            '-',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                        : null,
              ),
            );
            continue;
          }
          final int slot = index++;
          final bool hasLetter = slot < _userAnswers.length;
          final bool isHint = hasLetter && slot < locked;
          final String letter = hasLetter ? _userAnswers[slot].char : '';
          final Color tileColor =
              !hasLetter
                  ? const Color(0xFF087D73)
                  : (_hasError && !isHint
                      ? const Color(0xFFFFE4E6)
                      : (isHint ? const Color(0xFFFFE08A) : Colors.white));
          final Color letterColor =
              _hasError && !isHint
                  ? const Color(0xFFE11D48)
                  : (isHint ? const Color(0xFF9A6400) : const Color(0xFF08796F));

          children.add(
            GestureDetector(
              onTap: () => _removeLetterAt(slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: slotWidth,
                height: 42,
                margin: EdgeInsets.symmetric(horizontal: horizontalGap),
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow:
                      hasLetter
                          ? const [
                            BoxShadow(
                              color: Color(0x22004F49),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ]
                          : null,
                ),
                child: Center(
                  child:
                      hasLetter
                          ? Text(
                            letter,
                            style: TextStyle(
                              fontSize: math.min(22.0, slotWidth * 0.65),
                              fontWeight: FontWeight.w900,
                              color: letterColor,
                            ),
                          )
                          : null,
                ),
              ),
            ),
          );
        }

        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) return _buildSummary();

    final double progress =
        _total > 0 ? math.min(1.0, _done / _total) : 0;
    const topBarColor = Color(0xFF008466);
    final bool canSkip = _queue.length > 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF43D9D0), Color(0xFFBDF4E9), Color(0xFFF0FFF8)],
          ),
        ),
        child: Column(
          children: [
            Container(
              color: topBarColor,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      // Same width as the coin chip on the right, so the title stays centred.
                      const SizedBox(width: CoinBalanceChip.width - 36),
                      Expanded(
                        child: Text(
                          widget.category.titleTh,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
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
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 6.0,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF0D9488),
                                width: 1.6,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF08796F,
                                  ).withValues(alpha: 0.10),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'ข้อที่ ${math.min(_done + (_isAnswerCorrect ? 0 : 1), _total)} / $_total',
                              style: const TextStyle(
                                color: Color(0xFF0D9488),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 9,
                                backgroundColor: Colors.white.withValues(alpha: 0.85),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFB703),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF0D9488),
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF08796F).withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  _currentQ.thaiClue,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _currentQ.clue,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: const Color(0xFFFFF7ED),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _speakClue,
                              child: const Padding(
                                padding: EdgeInsets.all(7),
                                child: Icon(
                                  Icons.volume_up_rounded,
                                  color: Color(0xFFEA580C),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: MediaQuery.of(context).size.height * 0.22,
                      width: 260,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF0D9488),
                          width: 3.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF08796F).withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          _currentQ.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) => const Icon(
                                Icons.image_search_rounded,
                                size: 50,
                                color: Color(0xFFCBD5E1),
                              ),
                        ),
                      ),
                    ),

                    // ขยายระยะห่างเพื่อดันโซนคำตอบลงมา
                    const SizedBox(height: 28),

                    // ช่องใส่ตัวอักษรคำตอบ (Answer Slots)
                    ScaleTransition(
                      scale: _bounceAnimation,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF18B89F), Color(0xFF079486)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF08796F).withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _buildAnswerSlots(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // แถบลบตัวท้าย / เริ่มใหม่
                    SizedBox(
                      height: 24,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_userAnswers.length > _lockedCount &&
                              !_isAnswerCorrect) ...[
                            GestureDetector(
                              onTap: _removeLastLetter,
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.backspace_outlined,
                                    color: Color(0xFF08796F),
                                    size: 15,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'ลบตัวท้าย',
                                    style: TextStyle(
                                      color: Color(0xFF08796F),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            GestureDetector(
                              onTap: _resetLetters,
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 15,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'เริ่มใหม่',
                                    style: TextStyle(
                                      color: Color(0xFFCC4456),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // แป้นพิมพ์ตัวเลือกตัวอักษร
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.black, width: 2.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_shuffledLetters.length, (
                          index,
                        ) {
                          final isUsed = _usedLetters[index];
                          final letter = _shuffledLetters[index];
                          double keySize =
                              _shuffledLetters.length > 7 ? 44 : 48;

                          return GestureDetector(
                            onTap: () => _onLetterTap(index),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: isUsed ? 0.35 : 1.0,
                              child: Container(
                                width: keySize,
                                height: keySize,
                                decoration: BoxDecoration(
                                  gradient:
                                      isUsed
                                          ? null
                                          : const LinearGradient(
                                            colors: [
                                              Color(0xFFFFD94D),
                                              Color(0xFFFFB900),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                  color:
                                      isUsed ? const Color(0xFFE2E8F0) : null,
                                  borderRadius: BorderRadius.circular(50),
                                  boxShadow:
                                      isUsed
                                          ? null
                                          : [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFD18A00,
                                              ).withValues(alpha: 0.28),
                                              blurRadius: 5,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                ),
                                child: Center(
                                  child: Text(
                                    letter,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF705000),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ปุ่มขอตัวช่วย และ ข้ามข้อ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _useHint,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _remainingHints > 0 ? 1.0 : 0.65,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color:
                                    _remainingHints > 0
                                        ? const Color(0xFFD97706)
                                        : Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.only(bottom: 3.5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  gradient:
                                      _remainingHints > 0
                                          ? const LinearGradient(
                                            colors: [
                                              Color(0xFFFFC000),
                                              Color(0xFFFFA500),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          )
                                          : LinearGradient(
                                            colors: [
                                              Colors.grey.shade400,
                                              Colors.grey.shade500,
                                            ],
                                          ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFFA500,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.lightbulb_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ขอตัวช่วย ($_remainingHints)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: _skipQuestion,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: canSkip ? 1.0 : 0.5,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.only(bottom: 3.5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2DD4BF),
                                      Color(0xFF0D9488),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.fast_forward_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'ข้ามข้อนี้ไปก่อน',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ใช้ตัวช่วยจนหมด ข้อนั้นจะไม่ได้เหรียญนะ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.teal.shade800.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
