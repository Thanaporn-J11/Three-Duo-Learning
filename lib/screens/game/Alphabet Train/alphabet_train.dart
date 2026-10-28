import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../services/alphabet_train_service.dart';
import '../../../services/coin_balance.dart';
import '../../../services/guess_progress_service.dart' show GuessCoinResult;
import '../../../services/sfx.dart';

// ==========================================
// Helpers & Utilities
// ==========================================
Color darken(Color c, [double amount = 0.15]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

class BouncyTap extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const BouncyTap({super.key, required this.onTap, required this.child});

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

// ==========================================
// 0. ตั้งค่าด่าน & ระบบบันทึกความก้าวหน้า
// ==========================================
class WorldTheme {
  final String name;
  final String emoji;
  final Color skyTop;
  final Color skyMid;
  final Color skyBottom;
  final Color body;
  final Color bodyDark;
  final Color bodyLight;
  final Color hillBack;
  final Color hillFront;
  final Color accent;
  final Color accentDark;
  final List<String> floaters;

  const WorldTheme({
    required this.name,
    required this.emoji,
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.body,
    required this.bodyDark,
    required this.bodyLight,
    required this.hillBack,
    required this.hillFront,
    required this.accent,
    required this.accentDark,
    required this.floaters,
  });
}

class LevelConfig {
  LevelConfig._();

  static const int maxLevel = 50;
  static const int levelsPerWorld = 10;
  static const int starsPerLevel = 3;
  static const int maxStars = maxLevel * starsPerLevel;

  static int missingCountForLevel(int level) {
    if (level <= 34) return 1 + (level - 1) ~/ 3;
    return min(16, 12 + (level - 34) ~/ 4);
  }

  // 10 s + time for each missing letter (less per letter in later worlds),
  // so every level stays possible and gets harder step by step.
  static int timeForLevel(int level) {
    final int perLetter = level <= 10
        ? 8
        : level <= 20
            ? 7
            : level <= 30
                ? 6
                : level <= 40
                    ? 5
                    : 4;
    return 10 + missingCountForLevel(level) * perLetter;
  }

  static int optionCountForLevel(int level) => min(6, 3 + (level - 1) ~/ 8);

  static const List<WorldTheme> worlds = [
    WorldTheme(
      name: 'ทุ่งหญ้าสดใส',
      emoji: '🌳',
      skyTop: Color(0xFFFF6B80),
      skyMid: Color(0xFFFFC9D1),
      skyBottom: Color(0xFFFFF3D9),
      body: Color(0xFF4ADE80),
      bodyDark: Color(0xFF15803D),
      bodyLight: Color(0xFFBBF7D0),
      hillBack: Color(0xFFFFC1CC),
      hillFront: Color(0xFFFF9DB0),
      accent: Color(0xFFFB7185),
      accentDark: Color(0xFFA3174B),
      floaters: ['☁️', '🦋', '🌼'],
    ),
    WorldTheme(
      name: 'ชายหาดแสนสนุก',
      emoji: '🏖️',
      skyTop: Color(0xFFFF7A85),
      skyMid: Color(0xFFFFCDB8),
      skyBottom: Color(0xFFFFF1C9),
      body: Color(0xFF2DD4BF),
      bodyDark: Color(0xFF0F766E),
      bodyLight: Color(0xFF99F6E4),
      hillBack: Color(0xFFFFCDB3),
      hillFront: Color(0xFFFFA98F),
      accent: Color(0xFFFB7185),
      accentDark: Color(0xFFA3174B),
      floaters: ['☁️', '🐚', '🐠'],
    ),
    WorldTheme(
      name: 'ดินแดนลูกกวาด',
      emoji: '🍭',
      skyTop: Color(0xFFFF6F95),
      skyMid: Color(0xFFFFC4DD),
      skyBottom: Color(0xFFFFF0F7),
      body: Color(0xFFF472B6),
      bodyDark: Color(0xFFBE185D),
      bodyLight: Color(0xFFFBCFE8),
      hillBack: Color(0xFFFFC4DB),
      hillFront: Color(0xFFFF9CC0),
      accent: Color(0xFFF43F7A),
      accentDark: Color(0xFF9D174D),
      floaters: ['🍬', '🍭', '🎈'],
    ),
    WorldTheme(
      name: 'ท้องฟ้าสายรุ้ง',
      emoji: '🌈',
      skyTop: Color(0xFFF2707F),
      skyMid: Color(0xFFFFC9E6),
      skyBottom: Color(0xFFEDE4FF),
      body: Color(0xFFA78BFA),
      bodyDark: Color(0xFF6D28D9),
      bodyLight: Color(0xFFDDD6FE),
      hillBack: Color(0xFFF3C4E4),
      hillFront: Color(0xFFE7A3D6),
      accent: Color(0xFFE8607A),
      accentDark: Color(0xFF8E1B52),
      floaters: ['☁️', '🌈', '⭐'],
    ),
    WorldTheme(
      name: 'จักรวาลดาวระยิบ',
      emoji: '🚀',
      skyTop: Color(0xFFF5687A),
      skyMid: Color(0xFFFFB8C2),
      skyBottom: Color(0xFFFFE9B8),
      body: Color(0xFFFB923C),
      bodyDark: Color(0xFFC2410C),
      bodyLight: Color(0xFFFED7AA),
      hillBack: Color(0xFFFFBBC4),
      hillFront: Color(0xFFFF93A2),
      accent: Color(0xFFFB7185),
      accentDark: Color(0xFFA3174B),
      floaters: ['⭐', '🪐', '🌟'],
    ),
  ];

  static int worldIndexFor(int level) => max(0, min(worlds.length - 1, (level - 1) ~/ levelsPerWorld));
  static WorldTheme worldFor(int level) => worlds[worldIndexFor(level)];

  static const List<String> levelMascots = [
    '🍎', '🐱', '🐰', '🐼', '🦊', '🦁', '🐸', '🦄', '🐝', '🐥',
    '🐶', '🐻', '🐨', '🐯', '🐵', '🐙', '🐬', '🦋', '🐧', '🦉',
    '👑', '🎈', '⭐', '🍭', '🍓', '🚗', '🎨', '🚀', '🌈', '🍦',
    '🦖', '🦄', '🍬', '🍩', '🎂', '🔮', '🧸', '🎁', '💎', '🏆',
    '🐲', '🦕', '🐢', '🦈', '🦩', '🦜', '🐞', '🍉', '🎀', '🌟'
  ];
}

/// Stars per level, per account, kept on the server too (see AlphabetLevels).
class GameProgress {
  final int unlockedLevel;
  final List<int> stars;

  const GameProgress({
    required this.unlockedLevel,
    required this.stars,
  });

  int get totalStars => stars.fold(0, (sum, s) => sum + s);
  int starsOf(int level) => stars[level - 1];

  static Future<GameProgress> load() async {
    final stars = await AlphabetLevels.load();
    return GameProgress(unlockedLevel: AlphabetLevels.unlockedLevel(stars), stars: stars);
  }

  static Future<void> saveLevelResult({
    required int level,
    required int stars,
  }) =>
      AlphabetLevels.record(level, stars);
}

// ==========================================
// 1.1 หน้าเลือกด่าน 50 ด่าน
// ==========================================
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  GameProgress? _progress;
  int _selectedLevel = 1;
  Set<int> _unfinished = {}; // levels left in the middle
  bool _userPicked = false; // the child chose a level: don't move the choice
  bool _opening = false; // a game is being opened (no double taps)

  @override
  void initState() {
    super.initState();
    _loadProgress(selectHighest: true);
    if (CoinBalance.value.value == null) CoinBalance.refresh();
    // Stars from the server (after reinstalling / another phone).
    Future.wait([AlphabetLevels.sync(), AlphabetResume.sync()]).then((_) {
      if (mounted) _loadProgress(selectHighest: !_userPicked);
    });
  }

  Future<void> _loadProgress({bool selectHighest = false}) async {
    final p = await GameProgress.load();
    final unfinished = await alphabetUnfinishedLevels(LevelConfig.missingCountForLevel);
    if (!mounted) return;
    setState(() {
      _progress = p;
      _unfinished = unfinished;
      if (selectHighest || _selectedLevel > p.unlockedLevel) {
        _selectedLevel = p.unlockedLevel;
      }
    });
  }

  Future<void> _play() async {
    if (_opening) return;
    _opening = true;
    try {
      await _openLevel();
    } finally {
      _opening = false;
    }
  }

  Future<void> _openLevel() async {
    final level = _selectedLevel;
    AlphabetRound? resume =
        await AlphabetResume.load(level, LevelConfig.missingCountForLevel(level));
    if (!mounted) return;
    if (resume != null) {
      final choice = await _askResume(level, resume);
      if (!mounted || choice == null) return;
      if (!choice) {
        await AlphabetResume.clear(level);
        resume = null;
      }
    }
    if (!mounted) return;
    final reached = await Navigator.push<int>(
      context,
      MaterialPageRoute<int>(
        builder: (_) => AlphabetGameScreen(initialStage: level, resume: resume),
      ),
    );
    if (!mounted) return;
    await _loadProgress();
    if (!mounted) return;
    final p = _progress;
    if (reached != null && p != null && reached <= p.unlockedLevel) {
      setState(() => _selectedLevel = reached);
    }
  }

  Future<bool?> _askResume(int level, AlphabetRound saved) {
    const color = Color(0xFFE5334B);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: color.withValues(alpha: 0.35), width: 2.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.play_circle_fill_rounded, color: color, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ด่าน $level เล่นค้างไว้',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
        content: Text(
          'เติมไปแล้ว ${saved.done} / ${saved.missing.length} ตัว '
          'เหลือเวลา ${saved.remaining} วินาที\nจะเล่นต่อเลยไหม ?',
          style: const TextStyle(fontSize: 15.5, height: 1.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('เริ่มใหม่', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('เล่นต่อ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onLevelTap(int level, bool unlocked) {
    if (unlocked) {
      _userPicked = true;
      setState(() => _selectedLevel = level);
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFF3366),
        duration: const Duration(milliseconds: 1200),
        content: const Text(
          'ผ่านด่านก่อนหน้าเพื่อปลดล็อคด่านนี้นะ',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    return Scaffold(
      backgroundColor: const Color(0xFF86CFF3),
      body: _GameScaffoldBody(
        title: 'งูน้อยฉลาดเลือก',
        color: const Color(0xFFE5334B),
        child: Stack(
          children: [
            const Positioned.fill(child: _MeadowBackground()),
            SafeArea(
              top: false,
              child: p == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildTopBar(p),
                        const SizedBox(height: 18),
                        _buildCartoonBanner(),
                        _buildWorldSign(),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildLevelPanel(p),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildPlayButtonSection(),
                        const SizedBox(height: 14),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(GameProgress p) {
    final done = p.stars.where((s) => s > 0).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _buildStarBadge(done),
          const Spacer(),
          _buildCoinBadge(),
        ],
      ),
    );
  }

  BoxDecoration get _creamPillDecoration => BoxDecoration(
        color: const Color(0xFFFFF4DA).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3DDAE), width: 2),
        boxShadow: [
          BoxShadow(color: const Color(0xFFB8860B).withValues(alpha: 0.25), offset: const Offset(0, 3), blurRadius: 4),
        ],
      );

  Widget _buildStarBadge(int done) {
    return SizedBox(
      height: 50,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: _creamPillDecoration,
        child: Center(
          child: Text(
            '$done / ${LevelConfig.maxLevel}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF7A4B1E)),
          ),
        ),
      ),
    );
  }

  Widget _buildCoinBadge() {
    return SizedBox(
      height: 50,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
        decoration: _creamPillDecoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFEB8A), Color(0xFFF5B000)],
                ),
                border: Border.all(color: const Color(0xFFD98E00), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                '\$',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFC77700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int?>(
              valueListenable: CoinBalance.value,
              builder: (_, coins, _) => Text(
              coins == null ? '-' : '$coins',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF7A4B1E)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCartoonBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF6BE), Color(0xFFFFE98C)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFFFBE3), width: 3),
          boxShadow: [
            const BoxShadow(color: Color(0xFFDDB24F), offset: Offset(0, 4)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: CustomPaint(
                painter: _DashedRRectPainter(
                  color: Color(0xFFE2BC5A),
                  radius: 22,
                  inset: 6,
                  strokeWidth: 1.6,
                  dash: 6,
                  gap: 4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'ผจญภัย ${LevelConfig.maxLevel} ด่าน',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB0592B),
                    shadows: [Shadow(offset: Offset(0, 1.5), blurRadius: 0, color: Color(0xFFFFFBE3))],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorldSign() {
    final w = LevelConfig.worldFor(_selectedLevel);
    final no = LevelConfig.worldIndexFor(_selectedLevel) + 1;
    Widget post() => Container(
          width: 7,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFF9A6234),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
            border: Border.all(color: const Color(0xFF6B3F1B), width: 1),
          ),
        );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: IntrinsicWidth(
        key: ValueKey(no),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [post(), post()],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFC98D58), Color(0xFFA9692F)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF7B4A22), width: 2.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF5E3512).withValues(alpha: 0.55), offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(w.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'โลกที่ $no : ${w.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [Shadow(offset: Offset(0, 1.5), blurRadius: 1, color: Color(0xFF5E3512))],
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

  Widget _buildLevelPanel(GameProgress p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 3),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2E7D32).withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(33),
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          physics: const BouncingScrollPhysics(),
          itemCount: LevelConfig.maxLevel,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, i) => _buildCartoonLevelTile(i + 1, p),
        ),
      ),
    );
  }

  Widget _buildCartoonLevelTile(int level, GameProgress p) {
    final unlocked = level <= p.unlockedLevel;
    final selected = level == _selectedLevel;
    final earned = p.starsOf(level);

    List<Color> gradientColors;
    Color borderColor;
    Color shadowColor;
    bool glow = false;

    if (!unlocked) {
      gradientColors = const [Color(0xFFFFDDE9), Color(0xFFF9B3CC)];
      borderColor = const Color(0xFFFFC4D9);
      shadowColor = const Color(0xFFE48DAE);
    } else if (selected) {
      gradientColors = const [Color(0xFFFFB45E), Color(0xFFF47A1F)];
      borderColor = const Color(0xFFFFD4A3);
      shadowColor = const Color(0xFFC4570E);
    } else if (earned > 0) {
      gradientColors = const [Color(0xFF90DC7A), Color(0xFF4CB043)];
      borderColor = const Color(0xFFB9ECA6);
      shadowColor = const Color(0xFF2E8B3A);
    } else {
      gradientColors = const [Color(0xFFFFE98A), Color(0xFFF4C430)];
      borderColor = const Color(0xFFFFF2B0);
      shadowColor = const Color(0xFFC99A12);
      glow = true;
    }

    final numberColor = (unlocked && earned == 0 && !selected) ? const Color(0xFF7A4A12) : Colors.white;

    return BouncyTap(
      onTap: () => _onLevelTap(level, unlocked),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(color: shadowColor, offset: const Offset(0, 5)),
            if (glow) BoxShadow(color: const Color(0xFFFFE066).withValues(alpha: 0.85), blurRadius: 14, spreadRadius: 1),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 3,
              left: 8,
              right: 8,
              height: 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            if (unlocked && _unfinished.contains(level))
              Positioned(
                top: -8,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5334B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Text(
                    '▶ ต่อ',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ),
            if (unlocked)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$level',
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: numberColor,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1.5),
                                blurRadius: 2,
                                color: numberColor == Colors.white ? Colors.black38 : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                        if (earned > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              3,
                              (i) => Icon(
                                Icons.star_rounded,
                                size: 15,
                                color: i < earned ? const Color(0xFFFFD43B) : Colors.white38,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: const [
                    Icon(Icons.lock_rounded, size: 40, color: Color(0xFFC98A12)),
                    Icon(Icons.lock_rounded, size: 34, color: Color(0xFFFFC53D)),
                  ],
                ),
              ),

            if (unlocked && earned > 0)
              const Positioned(
                top: -10,
                right: -8,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.check_rounded, size: 34, color: Color(0xFFB8741A)),
                      Icon(Icons.check_rounded, size: 28, color: Color(0xFFFFD43B)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButtonSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: BouncyTap(
            onTap: _play,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7BDB55), Color(0xFF3FA535)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0xFFDDF7CC), width: 3.5),
                boxShadow: [
                  const BoxShadow(color: Color(0xFF2F7D32), offset: Offset(0, 6)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 10)),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'เริ่มเล่น ด่านที่ $_selectedLevel',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(offset: Offset(0, 2), blurRadius: 3, color: Color(0x66000000))],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// พื้นหลังท้องฟ้า + ทุ่งหญ้า
// ---------------------------------------------------------------
class _MeadowBackground extends StatelessWidget {
  const _MeadowBackground();

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: SizedBox.expand(child: CustomPaint(painter: _MeadowPainter())),
    );
  }
}

class _MeadowPainter extends CustomPainter {
  const _MeadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final full = Offset.zero & size;

    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF86CFF3), Color(0xFFBFE6F9), Color(0xFFE6F6E4)],
          stops: [0.0, 0.5, 0.78],
        ).createShader(full),
    );

    void cloud(double cx, double cy, double s) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.93)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(cx, cy), 16 * s, paint);
      canvas.drawCircle(Offset(cx + 22 * s, cy - 10 * s), 22 * s, paint);
      canvas.drawCircle(Offset(cx + 48 * s, cy - 2 * s), 18 * s, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - 14 * s, cy, 80 * s, 18 * s), Radius.circular(9 * s)),
        paint,
      );
    }

    cloud(-6, h * 0.31, 1.25);
    cloud(w - 92, h * 0.27, 1.35);

    final back = Path()
      ..moveTo(0, h * 0.58)
      ..quadraticBezierTo(w * 0.12, h * 0.46, w * 0.34, h * 0.56)
      ..quadraticBezierTo(w * 0.6, h * 0.65, w * 0.82, h * 0.54)
      ..quadraticBezierTo(w * 0.94, h * 0.49, w, h * 0.53)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFF6DB65A));

    final mid = Path()
      ..moveTo(0, h * 0.68)
      ..quadraticBezierTo(w * 0.3, h * 0.6, w * 0.6, h * 0.68)
      ..quadraticBezierTo(w * 0.85, h * 0.74, w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      mid,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8AD05A), Color(0xFF5DB83C)],
        ).createShader(Rect.fromLTWH(0, h * 0.6, w, h * 0.4)),
    );

    final front = Path()
      ..moveTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.4, h * 0.72, w * 0.75, h * 0.79)
      ..quadraticBezierTo(w * 0.92, h * 0.82, w, h * 0.8)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7ACB4A), Color(0xFF4FA83A)],
        ).createShader(Rect.fromLTWH(0, h * 0.72, w, h * 0.28)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------
// เส้นประเย็บขอบป้าย
// ---------------------------------------------------------------
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double inset;
  final double strokeWidth;
  final double dash;
  final double gap;

  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.inset,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final path = Path()..addRRect(rrect);
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius || old.inset != inset;
}

class AlphabetTrain extends StatelessWidget {
  const AlphabetTrain({super.key});

  @override
  Widget build(BuildContext context) => const LevelSelectScreen();
}

// ==========================================
// 2. หน้าเล่นเกม (Alphabet Snake Game)
// ==========================================
class AlphabetGameScreen extends StatefulWidget {
  final int initialStage;

  /// The level left in the middle, to continue (null = start it fresh).
  final AlphabetRound? resume;

  const AlphabetGameScreen({super.key, this.initialStage = 1, this.resume});

  @override
  State<AlphabetGameScreen> createState() => _AlphabetGameScreenState();
}

class _AlphabetGameScreenState extends State<AlphabetGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final FlutterTts _tts = FlutterTts();

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  late final AnimationController _burstController;
  late final AnimationController _blinkController;
  late final AnimationController _pulseController;
  late final AnimationController _bgController;

  final Map<String, Map<String, String>> _alphabetData = {
    'A': {'word': 'Apple', 'emoji': '🍎'},
    'B': {'word': 'Ball', 'emoji': '⚽'},
    'C': {'word': 'Cat', 'emoji': '🐱'},
    'D': {'word': 'Dog', 'emoji': '🐶'},
    'E': {'word': 'Elephant', 'emoji': '🐘'},
    'F': {'word': 'Fish', 'emoji': '🐟'},
    'G': {'word': 'Giraffe', 'emoji': '🦒'},
    'H': {'word': 'House', 'emoji': '🏠'},
    'I': {'word': 'Ice Cream', 'emoji': '🍦'},
    'J': {'word': 'Juice', 'emoji': '🧃'},
    'K': {'word': 'Kangaroo', 'emoji': '🦘'},
    'L': {'word': 'Lion', 'emoji': '🦁'},
    'M': {'word': 'Monkey', 'emoji': '🐒'},
    'N': {'word': 'Nest', 'emoji': '🪺'},
    'O': {'word': 'Owl', 'emoji': '🦉'},
    'P': {'word': 'Panda', 'emoji': '🐼'},
    'Q': {'word': 'Queen', 'emoji': '👑'},
    'R': {'word': 'Rabbit', 'emoji': '🐰'},
    'S': {'word': 'Sun', 'emoji': '☀️'},
    'T': {'word': 'Tiger', 'emoji': '🐯'},
    'U': {'word': 'Umbrella', 'emoji': '☂️'},
    'V': {'word': 'Van', 'emoji': '🚐'},
    'W': {'word': 'Whale', 'emoji': '🐳'},
    'X': {'word': 'Xylophone', 'emoji': '🎼'},
    'Y': {'word': 'Yo-yo', 'emoji': '🪀'},
    'Z': {'word': 'Zebra', 'emoji': '🦓'},
  };

  final List<String> _alphabet = List.generate(26, (i) => String.fromCharCode(65 + i));

  static const List<int> _rowLengths = [5, 5, 5, 5, 6];
  static const double _cellW = 52;
  static const double _cellH = 48;
  static const double _rowGap = 16;
  static const double _sideMargin = 62;
  static const double _topPad = 25;
  static const double _bottomPad = 34;

  List<String> _boardLetters = [];
  List<int> _missingIndices = [];
  int _currentMissingIndex = -1;
  String _correctAnswer = '';
  List<String> _options = [];

  late final Future<void> _ttsReady; // voice settings applied before speaking
  // Real coins of this level (2 per letter per day, from the server).
  final List<Future<GuessCoinResult>> _levelCoins = [];
  bool _pausedByApp = false; // time stopped while the app was in the background
  List<int> _allMissing = []; // every hidden position of this level
  int _coinsBefore = 0; // coins of this level earned before "เล่นต่อ"
  int _coinsNow = 0; // coins earned since the level was opened
  late int _stage;
  String? _wrongOption;
  Rect? _burstOriginRect;

  Timer? _timer;
  int _totalSeconds = 60;
  int _remainingSeconds = 60;
  bool _levelEnded = false;
  bool _busy = false;
  int _earnedStars = 1;

  final List<List<Color>> _cellGradients = [
    [const Color(0xFF7BD958), const Color(0xFF2E9E2E)],
    [const Color(0xFFFFE04D), const Color(0xFFF0A500)],
    [const Color(0xFFFF6B6B), const Color(0xFFD62839)],
    [const Color(0xFF5BB4FF), const Color(0xFF1C6FD6)],
    [const Color(0xFFB583FF), const Color(0xFF7B2FD6)],
    [const Color(0xFFFFA03D), const Color(0xFFE5610A)],
  ];

  @override
  void initState() {
    super.initState();
    _stage = widget.initialStage;
    _ttsReady = _initTts();

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _burstController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();

    _startLevel(resume: widget.resume);
    WidgetsBinding.instance.addObserver(this);
  }

  // The time doesn't run while the app is in the background (phone call,
  // another app); it goes on when the child comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pausedByApp && mounted && !_levelEnded) {
        _pausedByApp = false;
        _startTimer();
      }
    } else if (_timer != null) {
      _stopTimer();
      _pausedByApp = true;
      _saveResume(); // the app may be closed while in the background
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.38);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.2);
  }

  @override
  void dispose() {
    _saveResume(); // left in the middle (back button): continue later
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _shakeController.dispose();
    _burstController.dispose();
    _blinkController.dispose();
    _pulseController.dispose();
    _bgController.dispose();
    _tts.stop();
    super.dispose();
  }

  List<Rect> _cellRects() {
    final rects = <Rect>[];
    final numRows = _rowLengths.length;
    for (int r = 0; r < numRows; r++) {
      final cols = _rowLengths[r];
      final reversed = r.isOdd;
      final top = _topPad + (numRows - 1 - r) * (_cellH + _rowGap);
      for (int c = 0; c < cols; c++) {
        final col = reversed ? (cols - 1 - c) : c;
        final left = _sideMargin + col * _cellW;
        rects.add(Rect.fromLTWH(left, top, _cellW, _cellH));
      }
    }
    return rects;
  }

  double get _boardWidth {
    final maxCols = _rowLengths.reduce(max);
    return _sideMargin * 2 + maxCols * _cellW;
  }

  double get _boardHeight =>
      _topPad + _bottomPad + _rowLengths.length * _cellH + (_rowLengths.length - 1) * _rowGap;

  void _startLevel({AlphabetRound? resume}) {
    final random = Random();

    _boardLetters = List.from(_alphabet);

    if (resume != null) {
      // Same hidden letters; the ones filled before stay filled.
      _allMissing = List.of(resume.missing);
      _missingIndices = _allMissing.sublist(resume.done);
      _coinsBefore = resume.coins;
    } else {
      final missingCount = LevelConfig.missingCountForLevel(_stage);
      final missingSet = <int>{};
      while (missingSet.length < missingCount) {
        missingSet.add(random.nextInt(_alphabet.length));
      }
      _allMissing = missingSet.toList()..sort();
      _missingIndices = List.of(_allMissing);
      _coinsBefore = 0;
      AlphabetResume.clear(_stage); // a new game of this level
    }
    for (final idx in _missingIndices) {
      _boardLetters[idx] = '?';
    }

    _coinsNow = 0;
    _levelCoins.clear();
    _pausedByApp = false;
    _wrongOption = null;
    _burstOriginRect = null;
    _levelEnded = false;
    _busy = false;

    _totalSeconds = LevelConfig.timeForLevel(_stage);
    _remainingSeconds = resume == null
        ? _totalSeconds
        : resume.remaining.clamp(1, _totalSeconds).toInt();

    _prepareNextQuestion();
    _startTimer();
  }

  void _prepareNextQuestion() {
    final random = Random();
    _currentMissingIndex = _missingIndices.first;
    _correctAnswer = _alphabet[_currentMissingIndex];

    final optionCount = LevelConfig.optionCountForLevel(_stage);
    final optionSet = <String>{_correctAnswer};
    while (optionSet.length < optionCount) {
      optionSet.add(_alphabet[random.nextInt(_alphabet.length)]);
    }
    _options = optionSet.toList()..shuffle();
    _wrongOption = null;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _onTimeUp();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Where the child is in this level, so it can be continued later.
  void _saveResume() {
    final done = _allMissing.length - _missingIndices.length;
    if (_levelEnded || done < 1 || _missingIndices.isEmpty || _remainingSeconds < 1) return;
    AlphabetResume.save(
      _stage,
      AlphabetRound(
        missing: List.of(_allMissing),
        done: done,
        remaining: _remainingSeconds,
        coins: min(_coinsBefore + _coinsNow, done * kGameCoinsPerWord),
      ),
    );
  }

  void _onTimeUp() {
    _levelEnded = true;
    AlphabetResume.clear(_stage);
    ScaffoldMessenger.of(context).clearSnackBars();
    _showGameOverDialog();
  }

  static const int _wrongPenaltySeconds = 3;

  void _handleOptionSelect(String selectedLetter) async {
    if (_levelEnded || _busy) return;

    if (selectedLetter == _correctAnswer) {
      _busy = true;
      _stopTimer();
      Sfx.correct();

      final coinFuture = AlphabetCoins.submit(selectedLetter);
      _levelCoins.add(coinFuture);
      coinFuture.then((r) => _coinsNow += r.coins);
      final cellRects = _cellRects();

      setState(() {
        _boardLetters[_currentMissingIndex] = selectedLetter;
        _burstOriginRect = cellRects[_currentMissingIndex];
        _missingIndices.removeAt(0);
      });

      _saveResume(); // kept even if the app is closed during the reward
      _burstController.forward(from: 0.0);

      final data = _alphabetData[selectedLetter];
      final word = data?['word'] ?? selectedLetter;

      _ttsReady.then((_) => _tts.speak('$selectedLetter. $selectedLetter is for $word'));

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _RewardDialog(
          letter: selectedLetter,
          word: word,
          emoji: data?['emoji'] ?? '',
          coin: coinFuture,
        ),
      );

      if (!mounted) return;

      if (_missingIndices.isEmpty) {
        _completeLevel();
      } else {
        setState(() {
          _prepareNextQuestion();
          _busy = false;
        });
        _startTimer();
      }
    } else {
      // A wrong guess costs 3 seconds, so tapping every letter doesn't pay.
      Sfx.wrong();
      setState(() {
        _wrongOption = selectedLetter;
        _remainingSeconds = max(0, _remainingSeconds - _wrongPenaltySeconds);
      });
      if (_remainingSeconds <= 0) {
        _stopTimer();
        _onTimeUp();
        return;
      }

      _shakeController.forward(from: 0.0);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('ลองใหม่อีกทีนะ (-$_wrongPenaltySeconds วินาที)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
  }

  Future<void> _completeLevel() async {
    _levelEnded = true;
    _stopTimer();
    AlphabetResume.clear(_stage);

    // ดาวตามเวลาที่เหลือ: เหลือ >= 50% = 3 ดาว, >= 25% = 2 ดาว, น้อยกว่านั้น 1 ดาว
    final double timeRatio = _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 0;
    _earnedStars = timeRatio >= 0.5 ? 3 : (timeRatio >= 0.25 ? 2 : 1);
    await GameProgress.saveLevelResult(level: _stage, stars: _earnedStars);
    if (!mounted) return;

    Sfx.complete();
    _showLevelCompleteDialog();
  }

  String _coinSummary(List<GuessCoinResult>? list) {
    if (list == null) return 'กำลังนับเหรียญ...';
    final coins = _coinsBefore + list.fold<int>(0, (sum, r) => sum + r.coins);
    final pending = list.where((r) => r.pending).length;
    if (pending > 0) return 'ได้ $coins เหรียญ (+${pending * kGameCoinsPerWord} รอต่อเน็ต)';
    return coins > 0 ? 'ได้ $coins เหรียญ' : 'ตัวอักษรด่านนี้ได้เหรียญไปแล้ววันนี้';
  }

  void _showLevelCompleteDialog() {
    final hasNext = _stage < LevelConfig.maxLevel;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFFDE68A), width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // แสดงดาวเฉลิมฉลอง 3 ดวง
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final isCenter = index == 1;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Transform.translate(
                        offset: Offset(0, isCenter ? -6 : 0),
                        child: Icon(
                          Icons.star_rounded,
                          size: isCenter ? 52 : 44,
                          color: index < _earnedStars ? const Color(0xFFFFB800) : const Color(0xFFE2E8F0),
                          shadows: const [
                            Shadow(offset: Offset(0, 2), blurRadius: 4, color: Color(0x33000000)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),

                // ข้อความหัวข้อ
                Text(
                  'ผ่านด่าน $_stage แล้วนะ !',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD97706),
                    shadows: [
                      Shadow(offset: Offset(0, 1.5), blurRadius: 2, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ป้ายแสดงคะแนน
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                  ),
                  child: FutureBuilder<List<GuessCoinResult>>(
                    future: Future.wait(_levelCoins),
                    builder: (_, snap) => Text(
                    _coinSummary(snap.data),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF78350F),
                    ),
                  )),
                ),

                if (_stage % LevelConfig.levelsPerWorld == 0 && hasNext) ...[
                  const SizedBox(height: 12),
                  Text(
                    'ผ่านโลก "${LevelConfig.worldFor(_stage).name}" แล้ว !\nด่านต่อไปจะเปลี่ยนโลกใหม่นะ',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],

                if (!hasNext) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'เก่งมาก ! คุณเล่นชนะครบทุกด่านแล้ว',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                  ),
                ],

                const SizedBox(height: 26),

                // แถบปุ่มกด
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ปุ่มเลือกด่าน
                    Expanded(
                      child: BouncyTap(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context, _stage);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFECDD3), width: 2),
                            boxShadow: const [
                              BoxShadow(color: Color(0xFFFDA4AF), offset: Offset(0, 3)),
                            ],
                          ),
                          child: const Text(
                            'เลือกด่าน',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (hasNext) ...[
                      const SizedBox(width: 12),
                      // ปุ่มด่านถัดไป
                      Expanded(
                        child: BouncyTap(
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _stage += 1;
                              _startLevel();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFBBF7D0), width: 2),
                              boxShadow: const [
                                BoxShadow(color: Color(0xFF15803D), offset: Offset(0, 4)),
                              ],
                            ),
                            child: const Text(
                              'ด่านถัดไป',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black26)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // UI หน้า GAME OVER
  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF5F5), Color(0xFFFFEAEA)],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFFFA8A8), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'GAME OVER',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE53E3E),
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(offset: Offset(0, 2), blurRadius: 4, color: Color(0x33000000)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'หมดเวลาในด่าน $_stage แล้ว ลองอีกครั้งนะ !',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A5568),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: BouncyTap(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context, _stage);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF2F7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFCBD5E0), width: 2),
                            boxShadow: const [
                              BoxShadow(color: Color(0xFFA0AEC0), offset: Offset(0, 3)),
                            ],
                          ),
                          child: const Text(
                            'ออก',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: BouncyTap(
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _startLevel());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF48BB78), Color(0xFF2F855A)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF9AE6B4), width: 2),
                            boxShadow: const [
                              BoxShadow(color: Color(0xFF22543D), offset: Offset(0, 4)),
                            ],
                          ),
                          child: const Text(
                            'ลองใหม่',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black26)],
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

  String get _stageDifficultyText => 'ด่าน $_stage / ${LevelConfig.maxLevel}';

  String _formatTime(int seconds) {
    final s = max(0, seconds);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  WorldTheme get _world => LevelConfig.worldFor(_stage);

  static const Color _woodDeep = Color(0xFF5B3A1E);

  BoxDecoration _woodDeco({double radius = 10, bool red = false}) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: red
              ? const [Color(0xFFD9694A), Color(0xFF9E2F1E)]
              : const [Color(0xFFBF8A52), Color(0xFF8B5A2B)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _woodDeep, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 3), blurRadius: 4)],
      );

  @override
  Widget build(BuildContext context) {
    final w = _world;
    return Scaffold(
      backgroundColor: const Color(0xFF3F7A3A),
      body: _GameScaffoldBody(
        title: 'งูน้อยฉลาดเลือก',
        color: const Color(0xFFE5334B),
        onBack: () {
          _stopTimer();
          Navigator.pop(context, _stage);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: CustomPaint(painter: _WorldBackdropPainter(world: w, t: _bgController)),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                    child: _buildCustomTopBar(),
                  ),
                  _buildTimeBar(),
                  const SizedBox(height: 2),
                  _buildProgressBadge(),
                  const SizedBox(height: 8),
                  _buildHintBubble(),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: _buildSnakeBoardGraphic(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    ),
                    child: _buildOptionsSection(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintBubble() {
    Widget roll() => Container(
          width: 13,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFD9B778), Color(0xFFF2DDA8), Color(0xFFC9A66B)]),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFF9A7A45), width: 1.5),
          ),
        );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF6DC), Color(0xFFF5E3B4)],
              ),
              border: Border.all(color: const Color(0xFFC9A66B), width: 2),
              boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 3), blurRadius: 4)],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'ลากตัวอักษรไปเติมช่อง ? ของงูน้อย',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF6B4A22)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(left: 0, top: -2, bottom: -2, child: roll()),
          Positioned(right: 0, top: -2, bottom: -2, child: roll()),
        ],
      ),
    );
  }

  Widget _buildCustomTopBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimerChip(),
        const Spacer(),
        _buildRewardCluster(),
      ],
    );
  }

  // แถบจับเวลา ใส่ อิโมจินาฬิกาทราย ⏳
  Widget _buildTimerChip() {
    final low = _remainingSeconds <= 10;
    return SizedBox(
      width: 124,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 24,
            top: 8,
            right: 0,
            height: 38,
            child: Container(
              alignment: const Alignment(0.5, 0),
              decoration: _woodDeco(radius: 8, red: low),
              child: Text(
                _formatTime(_remainingSeconds),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [Shadow(color: Color(0xFF3E2A18), offset: Offset(0, 2))],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF8E6), Color(0xFFE9D3A6)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8B5A2B), width: 4),
                boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 3), blurRadius: 4)],
              ),
              child: const Text('⏳', style: TextStyle(fontSize: 26)),
            ),
          ),
        ],
      ),
    );
  }

  // ป้ายเหรียญดอลลาร์ทรงแคปซูล (สไตล์เดียวกับรูปที่ 2)
  Widget _buildCoinBadge() {
    return SizedBox(
      height: 48,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4DA).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF3DDAE), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8860B).withValues(alpha: 0.25),
              offset: const Offset(0, 3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFEB8A), Color(0xFFF5B000)],
                ),
                border: Border.all(color: const Color(0xFFD98E00), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                '\$',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFC77700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int?>(
              valueListenable: CoinBalance.value,
              builder: (_, coins, _) => Text(
              coins == null ? '-' : '$coins',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF7A4B1E),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardCluster() {
    return _buildCoinBadge();
  }

  Widget _buildTimeBar() {
    final low = _remainingSeconds <= 10;
    final value = (_remainingSeconds / _totalSeconds).clamp(0.0, 1.0).toDouble();
    final List<Color> fillColors = low
        ? const [Color(0xFFFCA5A5), Color(0xFFEF4444)]
        : const [Color(0xFFD7FF8A), Color(0xFF46C42C)];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final fillW = max(20.0, (c.maxWidth - 24) * value);
          return SizedBox(
            height: 34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 20,
                  margin: const EdgeInsets.only(top: 8, right: 22),
                  decoration: BoxDecoration(
                    color: const Color(0x66113311),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: fillW,
                  height: 20,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: fillColors,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(color: fillColors[1].withValues(alpha: 0.7), blurRadius: 8)],
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressBadge() {
    Widget rope() => Container(width: 3, height: 14, color: const Color(0xFF8A6A3C));
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Positioned(top: -8, left: 90, child: rope()),
        Positioned(top: -8, right: 90, child: rope()),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: _woodDeco(radius: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _stageDifficultyText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFFFFF3D0),
                  shadows: [Shadow(color: Color(0xFF3E2A18), offset: Offset(0, 1.5))],
                ),
              ),
              const SizedBox(width: 10),
              Container(height: 14, width: 1.5, color: const Color(0xFFE9CE9A)),
              const SizedBox(width: 10),
              Text(
                'เหลืออีก ${_missingIndices.length} ช่อง',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFFFFF3D0),
                  shadows: [Shadow(color: Color(0xFF3E2A18), offset: Offset(0, 1.5))],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _letterBall(Widget inner, List<Color> colors, double d, {List<BoxShadow>? glow}) {
    return Container(
      width: d,
      height: d,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDD8CE), Color(0xFF8C857A)],
        ),
        border: Border.all(color: const Color(0xFF6F685E), width: 1.5),
        boxShadow: glow ?? const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 3), blurRadius: 3)],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 2,
              left: 7,
              right: 7,
              height: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Center(child: inner),
          ],
        ),
      ),
    );
  }

  Widget _buildSnakeBoardGraphic() {
    final cellRects = _cellRects();
    final w = _world;

    return SizedBox(
      width: _boardWidth,
      height: _boardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(_boardWidth, _boardHeight),
            painter: SnakeBodyPainter(cellRects: cellRects, blink: _blinkController, world: w),
          ),
          ...List.generate(26, (index) {
            final rect = cellRects[index];
            final letter = _boardLetters[index];
            final isCurrentMissing = index == _currentMissingIndex;
            final isMissingSlot = letter == '?';
            final colors = _cellGradients[index % _cellGradients.length];
            final double d = rect.height - 2;
            final EdgeInsets m = EdgeInsets.symmetric(horizontal: (rect.width - d) / 2, vertical: 1);

            return Positioned(
              left: rect.left,
              top: rect.top,
              child: DragTarget<String>(
                onWillAcceptWithDetails: (details) => isCurrentMissing,
                onAcceptWithDetails: (details) => _handleOptionSelect(details.data),
                builder: (context, candidateData, rejectedData) {
                  final isHovered = candidateData.isNotEmpty;

                  if (isMissingSlot) {
                    if (isCurrentMissing) {
                      return AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final pulseScale = 1.0 + (_pulseController.value * 0.1);
                          return Transform.scale(
                            scale: pulseScale,
                            child: Container(
                              margin: m,
                              child: _letterBall(
                                const Text(
                                  '?',
                                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF7A3E0A)),
                                ),
                                isHovered
                                    ? const [Color(0xFFFFF59D), Color(0xFFFFB300)]
                                    : const [Color(0xFFFFE9A8), Color(0xFFE0A33C)],
                                d,
                                glow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD54F).withValues(alpha: 0.9),
                                    blurRadius: 14,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    } else {
                      return Container(
                        margin: m,
                        child: _letterBall(
                          const Text(
                            '?',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF4A3A2A)),
                          ),
                          const [Color(0xFFB5A58F), Color(0xFF86765F)],
                          d,
                        ),
                      );
                    }
                  }

                  return Container(
                    margin: m,
                    child: _letterBall(
                      Text(
                        letter,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [Shadow(offset: Offset(0, 2), blurRadius: 3, color: Colors.black45)],
                        ),
                      ),
                      colors,
                      d,
                    ),
                  );
                },
              ),
            );
          }),
          if (_burstOriginRect != null)
            AnimatedBuilder(
              animation: _burstController,
              builder: (context, _) => _StarBurst(origin: _burstOriginRect!.center, progress: _burstController.value),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    final int n = _options.length;
    final double cardWidth = n >= 6 ? 52 : (n == 5 ? 62 : 80);
    final double cardHeight = cardWidth * 0.95;
    final double optionFontSize = n >= 6 ? 28 : (n == 5 ? 32 : 44);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _options.map((option) {
          final isWrong = _wrongOption == option;

          final optionCard = Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isWrong
                    ? const [Color(0xFFFCA5A5), Color(0xFFEF4444)]
                    : const [Color(0xFFEAE4DA), Color(0xFFB4ACA0)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isWrong ? const Color(0xFF991B1B) : const Color(0xFF8D857A), width: 3),
              boxShadow: [
                BoxShadow(
                  color: isWrong ? const Color(0xFF991B1B) : const Color(0xFF6F685E),
                  offset: const Offset(0, 6),
                ),
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), offset: const Offset(0, 10), blurRadius: 8),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 5,
                  left: 10,
                  right: 10,
                  height: 8,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                Center(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: optionFontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: const [
                        Shadow(offset: Offset(0, 3), color: Color(0xFF6B655B)),
                        Shadow(offset: Offset(1.5, 1.5), color: Color(0xFF6B655B)),
                        Shadow(offset: Offset(-1.5, 1.5), color: Color(0xFF6B655B)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

          return Draggable<String>(
            data: option,
            feedback: Material(color: Colors.transparent, child: Transform.scale(scale: 1.15, child: optionCard)),
            childWhenDragging: Opacity(opacity: 0.25, child: optionCard),
            child: BouncyTap(
              onTap: () => _handleOptionSelect(option),
              child: optionCard,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==========================================
// 3. Components ต่างๆ
// ==========================================
class _RewardDialog extends StatelessWidget {
  final String letter;
  final String word;
  final String emoji;
  final Future<GuessCoinResult> coin;

  const _RewardDialog({required this.letter, required this.word, required this.emoji, required this.coin});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        backgroundColor: Colors.white,
        elevation: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFEF08A), borderRadius: BorderRadius.circular(16)),
                child: const Text('ยอดเยี่ยมมาก', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF854D0E))),
              ),
              const SizedBox(height: 16),
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 26, color: Color(0xFF0284C7)),
                  children: [
                    TextSpan(text: '$letter ', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 36)),
                    const TextSpan(text: 'is for ', style: TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: word, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFE11D48))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<GuessCoinResult>(
                future: coin,
                builder: (_, snap) {
                  final r = snap.data;
                  final String text = r == null
                      ? 'กำลังรับเหรียญ...'
                      : r.pending
                          ? '+$kGameCoinsPerWord เหรียญ (รอต่อเน็ต)'
                          : r.coins > 0
                              ? '+${r.coins} เหรียญ'
                              : r.alreadyToday
                                  ? 'ตัวนี้ได้เหรียญไปแล้ววันนี้'
                                  : '';
                  if (text.isEmpty) return const SizedBox.shrink();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFB627), size: 26),
                      const SizedBox(width: 6),
                      Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              BouncyTap(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(color: darken(const Color(0xFF22C55E)), offset: const Offset(0, 5)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ลุยต่อ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarBurst extends StatelessWidget {
  final Offset origin;
  final double progress;

  const _StarBurst({required this.origin, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _StarBurstPainter(origin: origin, progress: progress),
        size: Size.infinite,
      ),
    );
  }
}

class _StarBurstPainter extends CustomPainter {
  final Offset origin;
  final double progress;

  _StarBurstPainter({required this.origin, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const starCount = 8;
    final maxRadius = 75.0 * progress;
    final opacity = (1 - progress).clamp(0.0, 1.0);

    for (int i = 0; i < starCount; i++) {
      final angle = (2 * pi / starCount) * i;
      final dx = origin.dx + cos(angle) * maxRadius;
      final dy = origin.dy + sin(angle) * maxRadius;
      final paint = Paint()..color = const Color(0xFFFACC15).withValues(alpha: opacity);
      _drawStar(canvas, Offset(dx, dy), 7 + 4 * (1 - progress), paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    const points = 5;
    for (int i = 0; i < points * 2; i++) {
      final angle = (pi / points) * i - pi / 2;
      final r = i.isEven ? size : size / 2.2;
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.origin != origin;
}

class _WorldBackdropPainter extends CustomPainter {
  final WorldTheme world;
  final Animation<double> t;

  _WorldBackdropPainter({required this.world, required this.t}) : super(repaint: t);

  void _bush(Canvas canvas, Offset c, double s, Random r) {
    final dark = Paint()..color = const Color(0xFF2F6B2E);
    final mid = Paint()..color = const Color(0xFF3F8A38);
    final light = Paint()..color = const Color(0xFF5BAA48);
    for (int i = 0; i < 7; i++) {
      final o = Offset((r.nextDouble() - 0.5) * 70 * s, (r.nextDouble() - 0.5) * 38 * s);
      canvas.drawCircle(c + o, (20 + r.nextDouble() * 8) * s, dark);
    }
    for (int i = 0; i < 6; i++) {
      final o = Offset((r.nextDouble() - 0.5) * 62 * s, (r.nextDouble() - 0.6) * 34 * s);
      canvas.drawCircle(c + o, (14 + r.nextDouble() * 6) * s, mid);
    }
    for (int i = 0; i < 4; i++) {
      final o = Offset((r.nextDouble() - 0.5) * 50 * s, (r.nextDouble() - 0.8) * 28 * s);
      canvas.drawCircle(c + o, (9 + r.nextDouble() * 4) * s, light);
    }
    const flowers = [Color(0xFFFF6F91), Color(0xFFFFFFFF), Color(0xFFFF8A3D), Color(0xFFFFD166)];
    for (int i = 0; i < 9; i++) {
      final o = Offset((r.nextDouble() - 0.5) * 66 * s, (r.nextDouble() - 0.6) * 36 * s);
      canvas.drawCircle(c + o, 4.2 * s, Paint()..color = flowers[r.nextInt(flowers.length)]);
      canvas.drawCircle(c + o, 1.6 * s, Paint()..color = const Color(0xFFFFE066));
    }
  }

  void _trunk(Canvas canvas, double x0, double x1, double h) {
    final rect = Rect.fromLTRB(x0, -10, x1, h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF4A321D), Color(0xFF8A6238), Color(0xFF5A3E26)],
        ).createShader(rect),
    );
    final bark = Paint()
      ..color = const Color(0xFF3A2614).withValues(alpha: 0.5)
      ..strokeWidth = 2.5;
    for (double y = 30; y < h; y += 46) {
      canvas.drawLine(Offset(x0 + (x1 - x0) * 0.25, y), Offset(x0 + (x1 - x0) * 0.25, y + 26), bark);
      canvas.drawLine(Offset(x0 + (x1 - x0) * 0.7, y + 18), Offset(x0 + (x1 - x0) * 0.7, y + 40), bark);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E5A3A), Color(0xFF5F9A55), Color(0xFF9CC96E), Color(0xFF5E9A48), Color(0xFF3A6B2C)],
          stops: [0.0, 0.22, 0.45, 0.78, 1.0],
        ).createShader(rect),
    );

    final glowC = Offset(w * 0.5, h * 0.12);
    canvas.drawCircle(
      glowC,
      w * 0.75,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFF7C2).withValues(alpha: 0.75), const Color(0xFFFFF7C2).withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: glowC, radius: w * 0.75)),
    );
    for (int i = -2; i <= 2; i++) {
      final ray = Path()
        ..moveTo(w * 0.5 + i * 8, 0)
        ..lineTo(w * 0.5 + i * w * 0.22 - 24, h * 0.62)
        ..lineTo(w * 0.5 + i * w * 0.22 + 24, h * 0.62)
        ..lineTo(w * 0.5 + i * 8 + 14, 0)
        ..close();
      canvas.drawPath(ray, Paint()..color = Colors.white.withValues(alpha: 0.07));
    }

    _trunk(canvas, -w * 0.04, w * 0.17, h * 0.62);
    _trunk(canvas, w * 0.86, w * 1.04, h * 0.7);

    final top = Random(5);
    for (int i = 0; i < 12; i++) {
      final x = w * i / 11;
      canvas.drawCircle(Offset(x, -6 + top.nextDouble() * 14), 34 + top.nextDouble() * 26, Paint()..color = const Color(0xFF244E2C));
    }
    for (int i = 0; i < 9; i++) {
      final x = w * (i + 0.5) / 9;
      canvas.drawCircle(Offset(x, 2 + top.nextDouble() * 10), 22 + top.nextDouble() * 18, Paint()..color = const Color(0xFF356B38).withValues(alpha: 0.9));
    }

    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 1.0), width: w * 1.35, height: h * 0.26),
      Paint()..color = const Color(0xFFB98A57),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 1.02), width: w * 1.1, height: h * 0.2),
      Paint()..color = const Color(0xFFD1A56E),
    );

    final br = Random(11);
    _bush(canvas, Offset(w * 0.03, h * 0.46), 1.0, br);
    _bush(canvas, Offset(w * 0.97, h * 0.62), 1.2, br);
    _bush(canvas, Offset(w * 0.04, h * 0.9), 1.2, br);
    _bush(canvas, Offset(w * 0.96, h * 0.93), 1.1, br);

    final rockC = Offset(w * 0.9, h * 0.88);
    canvas.drawOval(Rect.fromCenter(center: rockC, width: 70, height: 38), Paint()..color = const Color(0xFF8C8F8A));
    canvas.drawOval(Rect.fromCenter(center: rockC + const Offset(-6, -6), width: 50, height: 22), Paint()..color = const Color(0xFFB4B7B0));

    final rnd = Random(7);
    for (int i = 0; i < 18; i++) {
      final x = rnd.nextDouble() * w;
      final y = rnd.nextDouble() * h * 0.8;
      final r = 1.4 + rnd.nextDouble() * 2.0;
      final tw = 0.3 + 0.7 * sin((t.value * 2 + i * 0.17) * pi).abs();
      canvas.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.8 * tw));
    }
  }

  @override
  bool shouldRepaint(covariant _WorldBackdropPainter oldDelegate) => oldDelegate.world != world;
}

class SnakeBodyPainter extends CustomPainter {
  final List<Rect> cellRects;
  final Animation<double> blink;
  final WorldTheme world;

  SnakeBodyPainter({required this.cellRects, required this.blink, required this.world}) : super(repaint: blink);

  void _emoji(Canvas canvas, String e, Offset center, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: e, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _label(Canvas canvas, String text, Offset offset, Color color, {double fontSize = 11}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          shadows: const [Shadow(offset: Offset(0, 1.2), blurRadius: 2, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (cellRects.isEmpty) return;

    final path = Path();
    path.moveTo(cellRects.first.center.dx, cellRects.first.center.dy);
    for (int i = 0; i < cellRects.length - 1; i++) {
      final p1 = cellRects[i].center;
      final p2 = cellRects[i + 1].center;
      if ((p1.dy - p2.dy).abs() > 10) {
        final controlP = Offset(
          p1.dx > size.width / 2 ? p1.dx + 42 : p1.dx - 42,
          (p1.dy + p2.dy) / 2,
        );
        path.quadraticBezierTo(controlP.dx, controlP.dy, p2.dx, p2.dy);
      } else {
        path.lineTo(p2.dx, p2.dy);
      }
    }

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path.shift(const Offset(0, 5)), stroke(const Color(0x55000000), 60));
    canvas.drawPath(path, stroke(const Color(0xFF3F7A2C), 60));
    canvas.drawPath(path, stroke(const Color(0xFF7A5430), 54));
    canvas.drawPath(path, stroke(const Color(0xFFCFA56F), 49));
    canvas.drawPath(path, stroke(const Color(0xFFE2C18E), 34));

    const petals = [Color(0xFFFFFFFF), Color(0xFFFF8FB1), Color(0xFFFFE066), Color(0xFFFFFFFF)];
    final rnd = Random(3);
    for (final m in path.computeMetrics()) {
      double d = 6;
      int k = 0;
      while (d < m.length) {
        final tan = m.getTangentForOffset(d);
        if (tan != null) {
          final nrm = Offset(-tan.vector.dy, tan.vector.dx);
          final side = k.isEven ? 1.0 : -1.0;
          final base = tan.position + nrm * (side * 29);
          canvas.drawOval(
            Rect.fromCenter(center: base + Offset(rnd.nextDouble() * 4 - 2, 0), width: 9, height: 5),
            Paint()..color = const Color(0xFF58A83C),
          );
          if (k % 3 == 0) {
            canvas.drawCircle(base, 3.3, Paint()..color = petals[rnd.nextInt(petals.length)]);
            canvas.drawCircle(base, 1.2, Paint()..color = const Color(0xFFFFC107));
          }
        }
        d += 17;
        k++;
      }
    }

    // START: งูอยู่นิ่งตรงจุดเริ่มต้น
    final first = cellRects.first;
    final hc = Offset(first.left - 18, first.center.dy - 2);
    canvas.drawOval(
      Rect.fromCenter(center: hc + const Offset(0, 24), width: 46, height: 10),
      Paint()..color = Colors.black26,
    );
    _emoji(canvas, '🐍', hc, 46);
    _label(canvas, 'START', Offset(hc.dx - 28, hc.dy + 25), Colors.white, fontSize: 10.5);

    // FINISH: ถ้วยรางวัล
    final last = cellRects.last;
    _label(canvas, '🏆 FINISH', Offset(last.right - 6, last.top - 18), Colors.white, fontSize: 10.5);
    _emoji(canvas, '🌻', Offset(last.right + 8, last.center.dy - 16), 24);
    _emoji(canvas, '🏆', Offset(last.right + 24, last.center.dy + 2), 36);
    _emoji(canvas, '🌻', Offset(last.right + 36, last.center.dy - 14), 20);
  }

  @override
  bool shouldRepaint(covariant SnakeBodyPainter oldDelegate) =>
      oldDelegate.cellRects != cellRects || oldDelegate.world != world;
}

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
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