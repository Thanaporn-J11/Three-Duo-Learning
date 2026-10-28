import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../widgets/coin_balance_chip.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../services/guess_progress_service.dart' show GuessCoinResult;
import '../../../services/shadow_progress_service.dart';
import 'shadow_match_data.dart';
import '../../../services/coin_balance.dart';
import '../../../services/sfx.dart';

class ShadowMatchScreen extends StatefulWidget {
  final ShadowCategory category;

  /// Unfinished game to continue (null = new game).
  final ShadowRound? resume;

  const ShadowMatchScreen({
    super.key,
    required this.category,
    this.resume,
  });

  @override
  State<ShadowMatchScreen> createState() => _ShadowMatchScreenState();
}

class _ShadowMatchScreenState extends State<ShadowMatchScreen> {
  final FlutterTts _flutterTts = FlutterTts();

  ShadowCategory get _currentCategory => widget.category;
  final math.Random _random = math.Random();

  late List<ShadowMatchItem> _shuffledPool;
  late List<ShadowMatchItem> _currentItems;
  late List<ShadowMatchItem> _shuffledShadows;
  final Map<String, bool> _matchedStatus = {};

  String? _selectedRealId;
  String? _selectedShadowId;

  /// True while a wrong pair is shown or the word pop-up is open: taps are
  /// ignored, so a new pick isn't wiped out by the old one being cleared.
  bool _busy = false;
  bool _completed = false;

  int _roundIndex = 0; // current stage, 0-based
  int get _round => _roundIndex + 1;
  late int _totalRounds;
  final int _itemsPerRound = shadowItemsPerStage;

  int _matches = 0;
  int _mistakes = 0;

  /// Coins confirmed by the server / matches waiting for internet.
  int _coins = 0;
  int _pending = 0;

  /// Changes for every new game, so late replies of an old game are ignored.
  int _gameId = 0;

  final Map<String, GlobalKey> _realDotKeys = {};
  final Map<String, GlobalKey> _shadowDotKeys = {};
  final GlobalKey _arenaKey = GlobalKey();

  final List<Color> _lineColors = const [
    Color(0xFF2563EB),
    Color(0xFFEC4899),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _setUpGame(widget.resume);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  /// New game (shuffled) or continue [resume].
  void _setUpGame(ShadowRound? resume) {
    _gameId++;
    final byId = {for (final item in _currentCategory.items) item.id: item};
    if (resume != null) {
      _shuffledPool = [for (final id in resume.order) byId[id]!];
      _roundIndex = resume.roundIndex;
      _matches = resume.matchedTotal;
      _mistakes = resume.mistakes;
      _coins = resume.coins;
      _pending = resume.pending;
    } else {
      _shuffledPool = List<ShadowMatchItem>.from(_currentCategory.items)..shuffle(_random);
      _roundIndex = 0;
      _matches = 0;
      _mistakes = 0;
      _coins = 0;
      _pending = 0;
    }
    _totalRounds = (_shuffledPool.length / _itemsPerRound).ceil();
    _completed = false;
    _busy = false;
    _startNewRound(alreadyMatched: resume?.matched ?? const []);
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.38);
      await _flutterTts.setPitch(1.30);
    } catch (_) {}
  }

  void _startNewRound({List<String> alreadyMatched = const []}) {
    final int startIndex = _roundIndex * _itemsPerRound;
    final int endIndex = math.min(startIndex + _itemsPerRound, _shuffledPool.length);

    _currentItems = _shuffledPool.sublist(startIndex, endIndex);
    _shuffledShadows = List<ShadowMatchItem>.from(_currentItems)..shuffle(_random);

    _matchedStatus.clear();
    _realDotKeys.clear();
    _shadowDotKeys.clear();

    for (final item in _currentItems) {
      _matchedStatus[item.id] = alreadyMatched.contains(item.id);
      _realDotKeys[item.id] = GlobalKey();
      _shadowDotKeys[item.id] = GlobalKey();
    }

    _selectedRealId = null;
    _selectedShadowId = null;

    if (mounted) setState(() {});
  }

  int get _accuracy {
    final tries = _matches + _mistakes;
    return tries == 0 ? 0 : (_matches * 100 / tries).round();
  }

  /// Saves the game so it can be continued (also on another phone).
  void _saveProgress() {
    if (_completed) return;
    final matchedNow = [
      for (final item in _currentItems)
        if (_matchedStatus[item.id] == true) item.id,
    ];
    // A finished stage is saved after moving on to the next one.
    if (matchedNow.length >= _currentItems.length) return;
    if (_roundIndex == 0 && matchedNow.isEmpty) return; // nothing played yet
    ShadowProgress.save(
      _currentCategory.key,
      ShadowRound(
        order: [for (final item in _shuffledPool) item.id],
        roundIndex: _roundIndex,
        matched: matchedNow,
        mistakes: _mistakes,
        coins: _coins,
        pending: _pending,
      ),
    );
  }

  Future<void> _playItemSound(String name) async {
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(name);
    } catch (_) {}
  }

  void _onSelectReal(String id) {
    if (_busy || _matchedStatus[id] == true) return;
    setState(() => _selectedRealId = id);
    _checkMatch();
  }

  void _onSelectShadow(String id) {
    if (_busy || _matchedStatus[id] == true) return;
    setState(() => _selectedShadowId = id);
    _checkMatch();
  }

  Future<void> _checkMatch() async {
    final realId = _selectedRealId;
    final shadowId = _selectedShadowId;
    if (realId == null || shadowId == null || _busy) return;
    final game = _gameId;

    if (realId != shadowId) {
      // Wrong pair: count it, show it briefly, then let them try again.
      Sfx.wrong();
      setState(() {
        _mistakes++;
        _busy = true;
      });
      await Future.delayed(const Duration(milliseconds: 280));
      if (!mounted || game != _gameId) return;
      setState(() {
        _selectedRealId = null;
        _selectedShadowId = null;
        _busy = false;
      });
      _saveProgress();
      return;
    }

    final matchedItem = _currentCategory.items.firstWhere((a) => a.id == realId);
    Sfx.correct();
    setState(() {
      _matchedStatus[realId] = true;
      _matches++;
      _selectedRealId = null;
      _selectedShadowId = null;
      _busy = true;
    });

    // 1 coin per item per day (the server decides).
    ShadowCoins.submit(categoryKey: _currentCategory.key, itemId: realId).then((
      GuessCoinResult result,
    ) {
      if (!mounted || game != _gameId) return;
      setState(() {
        _coins += result.coins;
        if (result.pending) _pending++;
      });
      _saveProgress();
    });

    final bool stageDone = _matchedStatus.values.every((matched) => matched);
    if (!stageDone) _saveProgress();

    _playItemSound(matchedItem.name);
    await _showWordRevealModal(matchedItem);
    if (!mounted || game != _gameId) return;
    setState(() => _busy = false);

    if (stageDone) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted || game != _gameId) return;
      Sfx.complete();
      if (_roundIndex < _totalRounds - 1) {
        setState(() => _roundIndex++);
        _startNewRound();
        // Saved at the start of the next stage (nothing matched there yet).
        ShadowProgress.save(
          _currentCategory.key,
          ShadowRound(
            order: [for (final item in _shuffledPool) item.id],
            roundIndex: _roundIndex,
            matched: const [],
            mistakes: _mistakes,
            coins: _coins,
            pending: _pending,
          ),
        );
      } else {
        setState(() => _completed = true);
        ShadowProgress.saveFinished(_currentCategory.key, _accuracy);
      }
    }
  }

  Future<void> _showWordRevealModal(ShadowMatchItem item) async {
    // Closes by itself after 1.4 s. One timer only, and it closes exactly
    // this pop-up: before, a tap outside + the timer could close the game
    // screen too, and every rebuild of the pop-up started another timer.
    final navigator = Navigator.of(context, rootNavigator: true);
    Route<dynamic>? dialogRoute;
    final timer = Timer(const Duration(milliseconds: 1400), () {
      final route = dialogRoute;
      if (route != null && route.isCurrent) navigator.pop();
    });
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        dialogRoute ??= ModalRoute.of(dialogCtx);

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 55),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _currentCategory.primaryColor, width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: _currentCategory.darkBorderColor,
                  offset: const Offset(0, 7),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 170,
                  decoration: BoxDecoration(
                    color: _currentCategory.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Center(
                    child: Image.asset(
                      item.imagePath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        item.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        item.thaiName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _currentCategory.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    timer.cancel();
  }

  /// End screen (part of the game page, so the phone's back button can't
  /// leave the game stuck on a finished board like the old pop-up could).
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
    return Scaffold(
      body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _currentCategory.primaryColor,
                _currentCategory.darkBorderColor,
              ],
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
                  child: CustomPaint(
                    painter: _CelebrationParticlesPainter(),
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
                          _buildBigStar(56, filled: stars >= 1),
                          const SizedBox(width: 8),
                          _buildBigStar(76, filled: stars >= 2),
                          const SizedBox(width: 8),
                          _buildBigStar(56, filled: stars >= 3),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: _currentCategory.darkBorderColor,
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
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: Text(
                          'หมวด${_currentCategory.titleTh} จับคู่ครบ $_matches คู่ • ผิด $_mistakes ครั้ง',
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
                                    '+$_coins',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    _pending > 0
                                        ? 'เหรียญ (+${_pending * kGameCoinsPerWord} รอต่อเน็ต)'
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
                                    '$percent%',
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
                          _flutterTts.stop();
                          _setUpGame(null); // new shuffled game
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

  Widget _buildBigStar(double size, {bool filled = true}) {
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

  @override
  Widget build(BuildContext context) {
    if (_completed) return _buildSummary();
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _currentCategory.backgroundGradient,
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: Column(
          children: [
            Container(
              color: _currentCategory.primaryColor,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                      // Same width as the coin chip on the right, so the title stays centred.
                      const SizedBox(width: CoinBalanceChip.width - 34),
                      Expanded(
                        child: Text(
                          _currentCategory.titleTh,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: _currentCategory.darkBorderColor,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF0F172A),
                      offset: Offset(0, 3.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(bottom: 3.5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _currentCategory.primaryColor, width: 2.2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'แตะรูปภาพ แล้วแตะเงา เพื่อโยงเส้นคู่กัน',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: _currentCategory.darkBorderColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xFFB45309),
                                  offset: Offset(0, 1.8),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Text(
                              'ด่าน $_round / $_totalRounds',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: List.generate(_totalRounds, (index) {
                                final bool isPassed = index < _round;
                                return Expanded(
                                  child: Container(
                                    height: 10,
                                    margin: EdgeInsets.only(right: index == _totalRounds - 1 ? 0 : 4),
                                    decoration: BoxDecoration(
                                      color: isPassed ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isPassed ? const Color(0xFFB45309) : const Color(0xFFCBD5E1),
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // ปรับขนาดการ์ดอัตโนมัติตามความสูงจอเพื่อป้องกัน Overflow
                  final double cardSize = math.min(94.0, (constraints.maxHeight / 4.4)).floorToDouble();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Stack(
                      key: _arenaKey,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _NewWorksheetLinePainter(
                              arenaKey: _arenaKey,
                              currentItems: _currentItems,
                              realDotKeys: _realDotKeys,
                              shadowDotKeys: _shadowDotKeys,
                              matchedStatus: _matchedStatus,
                              lineColors: _lineColors,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: List.generate(_currentItems.length, (index) {
                                final item = _currentItems[index];
                                final isSelected = _selectedRealId == item.id;
                                final isMatched = _matchedStatus[item.id] ?? false;
                                final dotColor = _lineColors[index % _lineColors.length];

                                return _buildCardItem(
                                  item: item,
                                  isShadow: false,
                                  isSelected: isSelected,
                                  isMatched: isMatched,
                                  dotColor: dotColor,
                                  dotKey: _realDotKeys[item.id],
                                  cardSize: cardSize,
                                  onTap: () => _onSelectReal(item.id),
                                );
                              }),
                            ),
                            const Spacer(),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: List.generate(_shuffledShadows.length, (index) {
                                final item = _shuffledShadows[index];
                                final isSelected = _selectedShadowId == item.id;
                                final isMatched = _matchedStatus[item.id] ?? false;
                                final realIndex = _currentItems.indexWhere((r) => r.id == item.id);
                                final dotColor = _lineColors[(realIndex >= 0 ? realIndex : 0) % _lineColors.length];

                                return _buildCardItem(
                                  item: item,
                                  isShadow: true,
                                  isSelected: isSelected,
                                  isMatched: isMatched,
                                  dotColor: dotColor,
                                  dotKey: _shadowDotKeys[item.id],
                                  cardSize: cardSize,
                                  onTap: () => _onSelectShadow(item.id),
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItem({
    required ShadowMatchItem item,
    required bool isShadow,
    required bool isSelected,
    required bool isMatched,
    required Color dotColor,
    required GlobalKey? dotKey,
    required double cardSize,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isShadow) ...[
            _buildRadioDot(dotKey, isSelected, isMatched, dotColor),
            const SizedBox(width: 8),
          ],
          Container(
            width: cardSize,
            height: cardSize,
            decoration: BoxDecoration(
              color: isSelected ? _currentCategory.primaryColor : _currentCategory.darkBorderColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? _currentCategory.primaryColor : _currentCategory.darkBorderColor,
                  offset: const Offset(0, 4.0),
                  blurRadius: 0,
                ),
              ],
            ),
            padding: const EdgeInsets.only(bottom: 3.2),
            child: Container(
              decoration: BoxDecoration(
                color: isShadow ? _currentCategory.shadowCardBg : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: isSelected ? _currentCategory.primaryColor : _currentCategory.darkBorderColor,
                  width: 2.4,
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: Center(
                child: Image.asset(
                  isShadow ? item.shadowPath : item.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    isShadow ? Icons.dark_mode_rounded : Icons.image_rounded,
                    size: cardSize * 0.45,
                    color: isShadow ? Colors.black87 : _currentCategory.primaryColor,
                  ),
                ),
              ),
            ),
          ),
          if (!isShadow) ...[
            const SizedBox(width: 8),
            _buildRadioDot(dotKey, isSelected, isMatched, dotColor),
          ],
        ],
      ),
    );
  }

  Widget _buildRadioDot(GlobalKey? key, bool isSelected, bool isMatched, Color dotColor) {
    return Container(
      key: key,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? _currentCategory.primaryColor : _currentCategory.darkBorderColor,
          width: 2.8,
        ),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isMatched ? dotColor : (isSelected ? _currentCategory.primaryColor : Colors.transparent),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _CelebrationParticlesPainter extends CustomPainter {
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
    ];

    for (int i = 0; i < 55; i++) {
      paint.color = colors[random.nextInt(colors.length)];
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height * 0.75;
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

class _NewWorksheetLinePainter extends CustomPainter {
  final GlobalKey arenaKey;
  final List<ShadowMatchItem> currentItems;
  final Map<String, GlobalKey> realDotKeys;
  final Map<String, GlobalKey> shadowDotKeys;
  final Map<String, bool> matchedStatus;
  final List<Color> lineColors;

  _NewWorksheetLinePainter({
    required this.arenaKey,
    required this.currentItems,
    required this.realDotKeys,
    required this.shadowDotKeys,
    required this.matchedStatus,
    required this.lineColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final RenderBox? arenaBox = arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (arenaBox == null || !arenaBox.hasSize) return;

    for (int i = 0; i < currentItems.length; i++) {
      final item = currentItems[i];
      if (matchedStatus[item.id] != true) continue;

      final realContext = realDotKeys[item.id]?.currentContext;
      final shadowContext = shadowDotKeys[item.id]?.currentContext;

      if (realContext == null || shadowContext == null) continue;

      final RenderBox? realBox = realContext.findRenderObject() as RenderBox?;
      final RenderBox? shadowBox = shadowContext.findRenderObject() as RenderBox?;

      if (realBox == null || !realBox.hasSize || shadowBox == null || !shadowBox.hasSize) continue;

      final startOffset = arenaBox.globalToLocal(
        realBox.localToGlobal(Offset(realBox.size.width / 2, realBox.size.height / 2)),
      );
      final endOffset = arenaBox.globalToLocal(
        shadowBox.localToGlobal(Offset(shadowBox.size.width / 2, shadowBox.size.height / 2)),
      );

      final lineColor = lineColors[i % lineColors.length];

      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(startOffset.dx, startOffset.dy);
      final midX = (startOffset.dx + endOffset.dx) / 2;
      path.cubicTo(
        midX, startOffset.dy,
        midX, endOffset.dy,
        endOffset.dx, endOffset.dy,
      );

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NewWorksheetLinePainter oldDelegate) => true;
}