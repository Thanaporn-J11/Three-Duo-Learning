import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../services/guess_progress_service.dart' show GuessCoinResult;
import '../../../services/word_search_progress_service.dart';
import '../../../widgets/coin_balance_chip.dart';
import 'word_search_data.dart';
import '../../../services/coin_balance.dart';

export 'word_search_data.dart' show WordSearchTarget, WordSearchCategoryItem;

class PlacedWordLocation {
  final String word;
  final List<int> indices;

  const PlacedWordLocation({
    required this.word,
    required this.indices,
  });
}

class FoundWordItem {
  final String word;
  final List<int> cellIndices;
  final Color highlightColor;

  FoundWordItem({
    required this.word,
    required this.cellIndices,
    required this.highlightColor,
  });
}

enum WordDirection {
  horizontalForward,
  horizontalBackward,
  verticalDown,
  verticalUp,
  diagonalDownRight,
  diagonalDownLeft,
}

class WordSearchPlayScreen extends StatefulWidget {
  final WordSearchCategoryItem category;

  /// An unfinished game to continue (null = new game).
  final WordSearchRound? resume;

  const WordSearchPlayScreen({super.key, required this.category, this.resume});

  @override
  State<WordSearchPlayScreen> createState() => _WordSearchPlayScreenState();
}

class _WordSearchPlayScreenState extends State<WordSearchPlayScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final math.Random _random = math.Random();

  /// Smallest grid; it grows (up to [maxGridSize]) for longer words.
  static const int minGridSize = 9;
  static const int maxGridSize = 12;

  /// Hints for each board.
  static const int hintsPerBoard = 2;

  final List<Color> _pastelColors = const [
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFF06292),
    Color(0xFF64B5F6),
    Color(0xFFBA68C8),
    Color(0xFF4DD0E1),
    Color(0xFFFFD54F),
    Color(0xFFFF8A80),
  ];

  /// All words of this game in order; board n = the n-th group of 4.
  List<WordSearchTarget> _order = [];
  final Set<String> _found = {};
  int _hints = 0;
  int _coins = 0;
  int _pending = 0;
  bool _completed = false;

  /// Changes for every new game, so late callbacks of an old one are ignored.
  int _gameId = 0;

  /// Between boards: ignore drags.
  bool _busy = false;

  int _boardIndex = 0;
  List<WordSearchTarget> _boardWords = [];
  int _gridSize = minGridSize;
  List<List<String>> _grid = [];
  final List<PlacedWordLocation> _placedLocations = [];
  final List<FoundWordItem> _foundWordsList = [];
  final List<int> _draggedIndices = [];
  final GlobalKey _gridKey = GlobalKey();

  int _hintsLeft = hintsPerBoard;
  final Set<int> _hintedCells = {};
  final Set<String> _hintedWords = {};

  /// Words shown with "เฉลย" (counted as done, no coin).
  final Set<String> _revealed = {};

  static const Color _revealColor = Color(0xFFCBD5E1);

  /// Short message in the strip under the board ("เยี่ยม! CAT", "ลองใหม่นะ").
  String? _feedbackText;
  Color _feedbackColor = const Color(0xFF16A34A);
  Timer? _feedbackTimer;

  int get _total => _order.length;

  @override
  void initState() {
    super.initState();
    _initTts();
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
  void _setUpGame(WordSearchRound? resume) {
    _gameId++;
    final all = widget.category.words;
    final byWord = {for (final w in all) w.word: w};
    _found.clear();
    _revealed.clear();
    if (resume != null) {
      _order = [
        for (final w in resume.order)
          if (byWord[w] != null) byWord[w]!,
      ];
      _found.addAll(resume.found);
      _revealed.addAll(resume.revealed);
      _hints = resume.hints;
      _coins = resume.coins;
      _pending = resume.pending;
    } else {
      _order = List<WordSearchTarget>.from(all)..shuffle(_random);
      _hints = 0;
      _coins = 0;
      _pending = 0;
    }
    _busy = false;
    _completed = _order.isEmpty || _found.length >= _order.length;
    if (!_completed) _setUpBoard();
  }

  /// The board with the first word not found yet (call inside setState / initState).
  void _setUpBoard() {
    final firstMissing = _order.indexWhere((w) => !_found.contains(w.word));
    _boardIndex = firstMissing ~/ wordSearchWordsPerBoard;
    _boardWords = _order
        .skip(_boardIndex * wordSearchWordsPerBoard)
        .take(wordSearchWordsPerBoard)
        .toList();

    _foundWordsList.clear();
    _draggedIndices.clear();
    _hintedCells.clear();
    _hintedWords.clear();
    _hintsLeft = hintsPerBoard;

    _generateGrid();

    // Words of this board found before the game was closed stay marked.
    for (final target in _boardWords) {
      if (!_found.contains(target.word)) continue;
      final location = _placedLocations.firstWhere((p) => p.word == target.word);
      _foundWordsList.add(
        FoundWordItem(
          word: target.word,
          cellIndices: location.indices,
          highlightColor:
              _revealed.contains(target.word)
                  ? _revealColor
                  : _pastelColors[_foundWordsList.length % _pastelColors.length],
        ),
      );
    }
  }

  void _generateGrid() {
    final longest = _boardWords.fold<int>(0, (m, t) => math.max(m, t.letters.length));
    _gridSize = longest.clamp(minGridSize, maxGridSize);
    final size = _gridSize;
    bool allPlaced = false;
    int boardAttempts = 0;

    while (!allPlaced && boardAttempts < 80) {
      boardAttempts++;
      _grid = List.generate(size, (_) => List.generate(size, (_) => ''));
      _placedLocations.clear();
      allPlaced = true;

      // Longest first: they are the hardest to fit.
      final words = List<WordSearchTarget>.from(_boardWords)
        ..sort((a, b) => b.letters.length.compareTo(a.letters.length));
      for (var target in words) {
        bool placed = false;
        int wordAttempts = 0;
        final word = target.letters;

        while (!placed && wordAttempts < 150) {
          wordAttempts++;
          final dir = WordDirection.values[_random.nextInt(WordDirection.values.length)];
          int row = _random.nextInt(size);
          int col = _random.nextInt(size);

          int dRow = 0;
          int dCol = 0;

          switch (dir) {
            case WordDirection.horizontalForward:
              dCol = 1;
              break;
            case WordDirection.horizontalBackward:
              dCol = -1;
              break;
            case WordDirection.verticalDown:
              dRow = 1;
              break;
            case WordDirection.verticalUp:
              dRow = -1;
              break;
            case WordDirection.diagonalDownRight:
              dRow = 1;
              dCol = 1;
              break;
            case WordDirection.diagonalDownLeft:
              dRow = 1;
              dCol = -1;
              break;
          }

          int endRow = row + dRow * (word.length - 1);
          int endCol = col + dCol * (word.length - 1);

          if (endRow >= 0 && endRow < size && endCol >= 0 && endCol < size) {
            bool canPlace = true;
            for (int i = 0; i < word.length; i++) {
              int r = row + dRow * i;
              int c = col + dCol * i;
              if (_grid[r][c] != '' && _grid[r][c] != word[i]) {
                canPlace = false;
                break;
              }
            }

            if (canPlace) {
              List<int> wordIndices = [];
              for (int i = 0; i < word.length; i++) {
                int r = row + dRow * i;
                int c = col + dCol * i;
                _grid[r][c] = word[i];
                wordIndices.add(r * size + c);
              }
              _placedLocations.add(
                PlacedWordLocation(word: target.word, indices: wordIndices),
              );
              placed = true;
            }
          }
        }

        if (!placed) {
          allPlaced = false;
          break;
        }
      }
    }

    if (!allPlaced) {
      // Very unlikely: one word per row, left to right (every word fits).
      _grid = List.generate(size, (_) => List.generate(size, (_) => ''));
      _placedLocations.clear();
      for (int i = 0; i < _boardWords.length; i++) {
        final target = _boardWords[i];
        final word = target.letters;
        final r = (i * 2) % size;
        final indices = <int>[];
        for (int c = 0; c < word.length; c++) {
          _grid[r][c] = word[c];
          indices.add(r * size + c);
        }
        _placedLocations.add(PlacedWordLocation(word: target.word, indices: indices));
      }
    }

    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_grid[r][c] == '') {
          _grid[r][c] = letters[_random.nextInt(letters.length)];
        }
      }
    }
  }

  List<WordSearchTarget> get _unfoundOnBoard =>
      _boardWords.where((t) => !_found.contains(t.word)).toList();

  /// Help used: a hint counts 1, a revealed word 2.
  int get _helpPoints => _hints + 2 * _revealed.length;

  /// Score for the tick / best: less help = higher.
  int get _percent =>
      _total == 0 ? 0 : math.max(0, 100 - (_helpPoints * 100 / _total).round());

  /// Saves the game so it can be continued (also on another phone).
  void _saveProgress() {
    if (_completed || _found.isEmpty || _found.length >= _total) return;
    WordSearchProgress.save(
      widget.category.key,
      WordSearchRound(
        order: [for (final w in _order) w.word],
        found: [for (final w in _order) if (_found.contains(w.word)) w.word],
        revealed: [for (final w in _order) if (_revealed.contains(w.word)) w.word],
        hints: _hints,
        coins: math.min(
          _coins,
          (_found.length - _revealed.length) * kGameCoinsPerWord,
        ),
        pending: _pending,
      ),
    );
  }

  void _useHint() {
    if (_busy || _completed) return;
    final unfound = _unfoundOnBoard;
    if (unfound.isEmpty) return;

    if (_hintsLeft <= 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'กระดานนี้ใช้ใบ้ครบแล้ว ลองหาดูนะ!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFD97706),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    // A word not hinted yet gets its first letter; when all were hinted,
    // the first word gets one more letter.
    final target = unfound.firstWhere(
      (t) => !_hintedWords.contains(t.word),
      orElse: () => unfound.first,
    );
    final location = _placedLocations.firstWhere((p) => p.word == target.word);
    final cell = location.indices.firstWhere(
      (i) => !_hintedCells.contains(i),
      orElse: () => -1,
    );
    if (cell == -1) return;

    setState(() {
      _hintsLeft--;
      _hints++;
      _hintedWords.add(target.word);
      _hintedCells.add(cell);
    });
    _speakWord(target);
    _saveProgress();
  }

  /// "เฉลย": shows the first word of the board not found yet (no coin).
  void _revealWord() {
    if (_busy || _completed) return;
    final unfound = _unfoundOnBoard;
    if (unfound.isEmpty) return;
    _onWordFound(unfound.first, revealed: true);
  }

  int? _getIndexFromOffset(Offset globalPosition) {
    final RenderBox? renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final localPosition = renderBox.globalToLocal(globalPosition);
    final size = renderBox.size;

    if (localPosition.dx < 0 || localPosition.dx >= size.width ||
        localPosition.dy < 0 || localPosition.dy >= size.height) {
      return null;
    }

    final cellWidth = size.width / _gridSize;
    final cellHeight = size.height / _gridSize;

    final col = (localPosition.dx / cellWidth).floor().clamp(0, _gridSize - 1);
    final row = (localPosition.dy / cellHeight).floor().clamp(0, _gridSize - 1);

    return row * _gridSize + col;
  }

  void _onPanStart(DragStartDetails details) {
    if (_busy) return;
    final index = _getIndexFromOffset(details.globalPosition);
    if (index != null) {
      setState(() {
        _draggedIndices.clear();
        _draggedIndices.add(index);
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_busy) return;
    final index = _getIndexFromOffset(details.globalPosition);
    if (index != null && _draggedIndices.isNotEmpty) {
      final startIdx = _draggedIndices.first;
      final startRow = startIdx ~/ _gridSize;
      final startCol = startIdx % _gridSize;

      final curRow = index ~/ _gridSize;
      final curCol = index % _gridSize;

      final dRow = curRow - startRow;
      final dCol = curCol - startCol;

      bool isStraight = (dRow == 0 && dCol != 0) ||
          (dCol == 0 && dRow != 0) ||
          (dRow.abs() == dCol.abs() && dRow != 0);

      if (isStraight) {
        int steps = math.max(dRow.abs(), dCol.abs());
        int stepRow = dRow == 0 ? 0 : (dRow ~/ steps);
        int stepCol = dCol == 0 ? 0 : (dCol ~/ steps);

        List<int> newPath = [];
        for (int i = 0; i <= steps; i++) {
          int r = startRow + stepRow * i;
          int c = startCol + stepCol * i;
          if (r >= 0 && r < _gridSize && c >= 0 && c < _gridSize) {
            newPath.add(r * _gridSize + c);
          }
        }

        setState(() {
          _draggedIndices.clear();
          _draggedIndices.addAll(newPath);
        });
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_draggedIndices.isEmpty) return;
    if (_busy) {
      setState(() => _draggedIndices.clear());
      return;
    }

    final currentWord = _draggedIndices
        .map((idx) => _grid[idx ~/ _gridSize][idx % _gridSize])
        .join('');
    final reverseWord = currentWord.split('').reversed.join('');

    WordSearchTarget? match;
    for (final target in _unfoundOnBoard) {
      if (currentWord == target.letters || reverseWord == target.letters) {
        match = target;
        break;
      }
    }

    if (match == null) {
      final tried = _draggedIndices.length;
      setState(() => _draggedIndices.clear());
      // A tap on one letter is not a try; a longer wrong line gets a message.
      if (tried >= 2) _showFeedback('ยังไม่ใช่ ลองใหม่นะ', const Color(0xFFE11D48));
      return;
    }
    _onWordFound(match);
  }

  void _onWordFound(WordSearchTarget target, {bool revealed = false}) {
    final game = _gameId;
    final color =
        revealed
            ? _revealColor
            : _pastelColors[_foundWordsList.length % _pastelColors.length];
    final location = _placedLocations.firstWhere(
      (p) => p.word == target.word,
      orElse: () => PlacedWordLocation(word: target.word, indices: const []),
    );

    setState(() {
      _found.add(target.word);
      if (revealed) _revealed.add(target.word);
      _foundWordsList.add(
        FoundWordItem(
          word: target.word,
          cellIndices: revealed ? location.indices : List<int>.from(_draggedIndices),
          highlightColor: color,
        ),
      );
      _draggedIndices.clear();
      // The hint letters of this word aren't needed any more.
      _hintedCells.removeAll(location.indices);
    });
    _showFeedback(
      revealed ? 'เฉลย : ${target.word}' : 'เยี่ยม ! ${target.word}',
      revealed ? const Color(0xFF7C3AED) : const Color(0xFF16A34A),
    );
    _speakWord(target);

    // 1 coin per word per day (the server decides); none for "เฉลย".
    if (!revealed) {
      WordSearchCoins.submit(categoryKey: widget.category.key, word: target.word).then((
        GuessCoinResult result,
      ) {
        if (!mounted || game != _gameId) return;
        setState(() {
          _coins += result.coins;
          if (result.pending) _pending++;
        });
        _saveProgress();
      });
    }

    if (_found.length >= _total) {
      WordSearchProgress.saveFinished(widget.category.key, _percent);
      _busy = true;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || game != _gameId) return;
        setState(() {
          _completed = true;
          _busy = false;
        });
      });
      return;
    }

    _saveProgress();
    if (_unfoundOnBoard.isEmpty) {
      _busy = true;
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted || game != _gameId) return;
        setState(() {
          _setUpBoard();
          _busy = false;
        });
      });
    }
  }

  Future<void> _speakWord(WordSearchTarget target) async {
    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.speak(target.spoken);
    } catch (_) {}
  }

  Color _getCategoryThemeColor() {
    switch (widget.category.key) {
      case 'animal':
        return const Color(0xFF26A69A);
      case 'sport':
        return const Color(0xFF29B6F6);
      case 'career':
        return const Color(0xFFFFA726);
      case 'home':
        return const Color(0xFFEC407A);
      case 'vehicle':
        return const Color(0xFFAB47BC);
      case 'location':
        return const Color(0xFFFF5722);
      case 'clothing':
        return const Color(0xFF5C6BC0);
      case 'fruit':
        return const Color(0xFFFFCA28);
      case 'food':
        return const Color(0xFF66BB6A);
      default:
        return const Color(0xFFE65100);
    }
  }

  List<Color> _getCategoryBackgroundGradient() {
    switch (widget.category.key) {
      case 'animal':
        return [
          const Color(0xFF80CBC4),
          const Color(0xFFB2DFDB),
          const Color(0xFFE0F2F1),
          const Color(0xFFF2FBF9),
        ];
      case 'sport':
        return [
          const Color(0xFF81D4FA),
          const Color(0xFFB3E5FC),
          const Color(0xFFE1F5FE),
          const Color(0xFFF3FAFD),
        ];
      case 'career':
        return [
          const Color(0xFFFFCC80),
          const Color(0xFFFFE0B2),
          const Color(0xFFFFF3E0),
          const Color(0xFFFFFBF5),
        ];
      case 'home':
        return [
          const Color(0xFFF48FB1),
          const Color(0xFFF8BBD0),
          const Color(0xFFFCE4EC),
          const Color(0xFFFDF7F9),
        ];
      case 'vehicle':
        return [
          const Color(0xFFCE93D8),
          const Color(0xFFE1BEE7),
          const Color(0xFFF3E5F5),
          const Color(0xFFFAF5FB),
        ];
      case 'location':
        return [
          const Color(0xFFFFAB91),
          const Color(0xFFFFCCBC),
          const Color(0xFFFBE9E7),
          const Color(0xFFFDF5F4),
        ];
      case 'clothing':
        return [
          const Color(0xFF9FA8DA),
          const Color(0xFFC5CAE9),
          const Color(0xFFE8EAF6),
          const Color(0xFFF6F7FB),
        ];
      case 'fruit':
        return [
          const Color(0xFFFFE082),
          const Color(0xFFFFF176),
          const Color(0xFFFFF9C4),
          const Color(0xFFFFFDED),
        ];
      case 'food':
        return [
          const Color(0xFFA5D6A7),
          const Color(0xFFC8E6C9),
          const Color(0xFFE8F5E9),
          const Color(0xFFF5FAF6),
        ];
      default:
        return [
          const Color(0xFFFF8E72),
          const Color(0xFFFFBBA8),
          const Color(0xFFFFD7CC),
          const Color(0xFFFFF0EB),
        ];
    }
  }

  /// End screen (part of the game page, so the phone's back button can't
  /// leave the game stuck on a finished board like the old pop-up could).
  Widget _buildSummary() {
    final catColor = widget.category.cardColor;
    final catShadow = widget.category.shadowColor;
    final double hintRate = _total == 0 ? 0 : _helpPoints / _total;
    final int stars =
        hintRate <= 0.1
            ? 3
            : hintRate <= 0.3
            ? 2
            : 1;
    final String headline =
        stars == 3
            ? 'เก่งมาก ยอดเยี่ยม'
            : stars == 2
            ? 'ทำได้ดีมาก !'
            : 'เก่งมาก หาครบแล้ว !';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [catColor, catShadow],
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
                  borderRadius: const BorderRadius.vertical(top: Radius.elliptical(260, 90)),
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
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: catShadow,
                            offset: const Offset(0, 4),
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
                        'หมวด${widget.category.titleTh}\n หาเจอ ${_total - _revealed.length} จาก $_total คำ',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16.5,
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
                            icon: Icons.lightbulb_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            value: '$_hints',
                            label: 'ครั้งที่ใช้ใบ้',
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

  void _showFeedback(String text, Color color) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackText = text;
      _feedbackColor = color;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  /// Strip under the board: the letters being dragged, then a short
  /// right / wrong message, otherwise which board this is (กระดาน 2 / 8).
  Widget _buildStatusStrip(Color themeColor) {
    final boards = (_total / wordSearchWordsPerBoard).ceil();
    Widget child;
    Color border = themeColor.withValues(alpha: 0.30);
    Color background = Colors.white;

    if (_draggedIndices.isNotEmpty) {
      final letters = _draggedIndices
          .map((i) => _grid[i ~/ _gridSize][i % _gridSize])
          .join(' ');
      border = const Color(0xFFF50057);
      background = const Color(0xFFFFF1F6);
      child = FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          letters,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFFD6004C),
            letterSpacing: 1.5,
          ),
        ),
      );
    } else if (_feedbackText != null) {
      border = _feedbackColor;
      background = _feedbackColor.withValues(alpha: 0.10);
      child = FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _feedbackText!,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: _feedbackColor,
          ),
        ),
      );
    } else {
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'กระดาน ${_boardIndex + 1} / $boards',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey.shade800,
            ),
          ),
          const SizedBox(width: 12),
          // One dot per board: done = filled, current = big.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  for (var b = 0; b < boards; b++)
                    Container(
                      width: b == _boardIndex ? 14 : 10,
                      height: b == _boardIndex ? 14 : 10,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            b <= _boardIndex
                                ? themeColor
                                : themeColor.withValues(alpha: 0.20),
                        border:
                            b == _boardIndex
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                        boxShadow:
                            b == _boardIndex
                                ? [
                                  BoxShadow(
                                    color: themeColor.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ]
                                : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 52,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 2),
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) return _buildSummary();

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    // Room left for the board after the header, word cards and buttons.
    final double maxAllowedHeight = screenHeight - 300;
    final double boardSize = math.min(screenWidth - 32, maxAllowedHeight).clamp(240.0, 380.0);
    // Letters get a little smaller on the bigger grids.
    final double letterSize = _gridSize <= 9 ? 16.5 : (_gridSize <= 10 ? 15.0 : 13.5);

    final Color topBarColor = _getCategoryThemeColor();
    final List<Color> bgGradients = _getCategoryBackgroundGradient();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bgGradients,
            stops: const [0.0, 0.35, 0.70, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            children: [
              // 1. Header Bar
              Container(
                color: topBarColor,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.maybePop(context),
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
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const CoinBalanceChip(),
                      ],
                    ),
                  ),
                ),
              ),

              // 2-5. ทุกส่วนชิดกันเป็นกลุ่มเดียว ชิดด้านบน ที่ว่างที่เหลืออยู่ล่างสุด
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
              // 2. แถบสเตตัส WORDS FOUND
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: topBarColor.withValues(alpha: 0.25),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: topBarColor.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: topBarColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: topBarColor.withValues(alpha: 0.35),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.category.titleEn,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'WORDS FOUND ',
                              style: TextStyle(
                                color: Colors.blueGrey.shade800,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_found.length} / $_total',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 4),
              // 3. การ์ดคำศัพท์ 2 คอลัมน์
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.6),
                  ),
                  child: GridView.builder(
                    // No automatic status-bar padding (it pushed the cards down).
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _boardWords.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.3,
                    ),
                    itemBuilder: (context, index) {
                      final target = _boardWords[index];
                      final foundIndex = _foundWordsList.indexWhere((e) => e.word == target.word);
                      final isFound = foundIndex != -1;
                      final pillColor = isFound
                          ? _foundWordsList[foundIndex].highlightColor
                          : const Color(0xFFE2E8F0);

                      return GestureDetector(
                        onTap: () => _speakWord(target),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFound ? pillColor.withValues(alpha: 0.35) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isFound ? pillColor : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 46,
                                height: 46,
                                child: Image.asset(
                                  target.imagePath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_rounded,
                                    size: 28,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        target.word,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: isFound ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                          decoration: isFound ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      target.thai,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isFound ? Colors.black54 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isFound ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isFound ? pillColor : const Color(0xFFCBD5E1),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 4. กระดานค้นหาคำ (9x9 - 12x12 ตามความยาวคำ)
              Flexible(
                // heightFactor 1 = only as tall as the board (Center filled all the
                // free space and left gaps above and below the board).
                child: Align(
                  heightFactor: 1.0,
                  // Shrinks a little on short screens instead of overflowing.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                    width: boardSize,
                    height: boardSize,
                    child: Container(
                      decoration: BoxDecoration(
                        color: topBarColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: topBarColor.withValues(alpha: 0.4),
                            width: 2.2,
                          ),
                        ),
                        child: Container(
                          key: _gridKey,
                          child: GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: Column(
                              children: List.generate(_gridSize, (r) {
                                return Expanded(
                                  child: Row(
                                    children: List.generate(_gridSize, (c) {
                                      final index = r * _gridSize + c;
                                      final letter = _grid[r][c];

                                      final bool isDragging = _draggedIndices.contains(index);
                                      final bool isHinted = _hintedCells.contains(index);

                                      FoundWordItem? matchedFoundItem;
                                      for (var item in _foundWordsList.reversed) {
                                        if (item.cellIndices.contains(index)) {
                                          matchedFoundItem = item;
                                          break;
                                        }
                                      }

                                      Color cellBg = const Color(0xFFFFF7ED);
                                      Color cellBorder = const Color(0xFFFED7AA);
                                      Color textCol = const Color(0xFF0F172A);

                                      // A hint letter shows over a found word, so it is never hidden.
                                      if (isDragging) {
                                        cellBg = const Color(0xFFFF80AB).withValues(alpha: 0.85);
                                        cellBorder = const Color(0xFFF50057);
                                        textCol = Colors.white;
                                      } else if (isHinted) {
                                        cellBg = const Color(0xFFEA580C);
                                        cellBorder = const Color(0xFFC2410C);
                                        textCol = Colors.white;
                                      } else if (matchedFoundItem != null) {
                                        cellBg = matchedFoundItem.highlightColor.withValues(alpha: 0.70);
                                        cellBorder = matchedFoundItem.highlightColor;
                                        textCol = const Color(0xFF0F172A);
                                      }

                                      return Expanded(
                                        child: Container(
                                          margin: EdgeInsets.all(_gridSize <= 9 ? 1.2 : 0.9),
                                          decoration: BoxDecoration(
                                            color: cellBg,
                                            borderRadius: BorderRadius.circular(_gridSize <= 9 ? 6 : 5),
                                            border: Border.all(
                                              color: cellBorder,
                                              width: isHinted ? 2.0 : 1.0,
                                            ),
                                          ),
                                          child: Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                letter,
                                                style: TextStyle(
                                                  fontSize: isHinted ? letterSize + 1.5 : letterSize,
                                                  fontWeight: FontWeight.w900,
                                                  color: textCol,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ตัวอักษรที่กำลังลาก / ถูก-ผิด / กระดานที่เท่าไร
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildStatusStrip(topBarColor),
              ),
                  ],
                ),
              ),

              // 5. ปุ่มตัวช่วย 2 ปุ่ม
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _useHint,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _hintsLeft > 0 ? 1.0 : 0.6,
                          child: Container(
                            height: 58,
                            decoration: BoxDecoration(
                              color: const Color(0xFFB45309),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.only(bottom: 4.5),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Text(
                                    'ใบ้คำ ($_hintsLeft)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _revealWord,
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6D28D9),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.only(bottom: 4.5),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Text(
                                  'เฉลย',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 0.3,
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
              ),

              const SizedBox(height: 14),
            ],
          ),
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
