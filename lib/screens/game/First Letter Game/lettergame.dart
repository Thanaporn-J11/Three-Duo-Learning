import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/coin_balance.dart';
import '../../../services/guess_progress_service.dart' show GuessCoinResult;
import '../../../services/letter_levels_service.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Sukhumvit Set',
    ),
    home: const CategorySelectionScreen(),
  ));
}

// ============================================================
// 1. หน้าเลือกหมวดหมู่ (CategorySelectionScreen)
// ============================================================
class CategorySelectionScreen extends StatelessWidget {
  const CategorySelectionScreen({super.key});

  static const List<Map<String, dynamic>> categories = [
    {
      'title': 'สัตว์น่ารัก',
      'subtitle': 'เพื่อนตัวน้อยรอบตัวเรา',
      'tag': '30 คำศัพท์',
      'primaryColor': Color(0xFF6C5CE7),
      'accentColor': Color(0xFF5142CA),
      'cardBg': Color(0xFFF3F0FF),
      'image': 'assets/images/vocabulary/animals/Dog.png',
      'icon': Icons.pets_rounded,
      'folder': 'animals',
      'words': [
        'BEAR', 'BEE', 'BIRD', 'BUTTERFLY', 'CAT', 'CHICKEN', 'COW', 'DOG',
        'DOLPHIN', 'DUCK', 'ELEPHANT', 'FISH', 'FROG', 'GIRAFFE', 'HIPPO',
        'HORSE', 'KANGAROO', 'LION', 'MONKEY', 'OCTOPUS', 'OWL', 'PANDA',
        'PENGUIN', 'PIG', 'RABBIT', 'SHEEP', 'TIGER', 'TURTLE', 'WHALE', 'ZEBRA'
      ],
    },
    {
      'title': 'ผลไม้แสนอร่อย',
      'subtitle': 'ผลไม้หวานฉ่ำ สีสันสดใส',
      'tag': '28 คำศัพท์',
      'primaryColor': Color(0xFFFF5252),
      'accentColor': Color(0xFFE03838),
      'cardBg': Color(0xFFFFF0F0),
      'image': 'assets/images/vocabulary/fruits/Apple.png',
      'icon': Icons.apple_rounded,
      'folder': 'fruits',
      'words': [
        'APPLE', 'AVOCADO', 'BANANA', 'BLACKBERRY', 'BLUEBERRY', 'CHERRY',
        'COCONUT', 'DURIAN', 'GRAPES', 'GUAVA', 'JACKFRUIT', 'KIWI', 'LEMON',
        'LIME', 'LONGAN', 'LYCHEE', 'MANGO', 'MANGOSTEEN', 'ORANGE', 'PAPAYA',
        'PEACH', 'PEAR', 'PINEAPPLE', 'POMEGRANATE', 'RAMBUTAN', 'RASPBERRY',
        'STRAWBERRY', 'WATERMELON'
      ],
    },
    {
      'title': 'อาชีพในฝัน',
      'subtitle': 'โตขึ้นน้อง ๆ อยากเป็นอะไรนะ ?',
      'tag': '28 คำศัพท์',
      'primaryColor': Color(0xFFFF9F43),
      'accentColor': Color(0xFFE08328),
      'cardBg': Color(0xFFFFF7ED),
      'image': 'assets/images/vocabulary/careers/Nurse.png',
      'icon': Icons.work_rounded,
      'folder': 'careers',
      'words': [
        'ACCOUNTANT', 'ARCHITECT', 'ARTIST', 'CARPENTER', 'CASHIER', 'CHEF',
        'DENTIST', 'DOCTOR', 'ELECTRICIAN', 'ENGINEER', 'FARMER', 'FIREFIGHTER',
        'JOURNALIST', 'LAWYER', 'MECHANIC', 'MUSICIAN', 'NURSE', 'PHARMACIST',
        'PHOTOGRAPHER', 'PILOT', 'PLUMBER', 'PROGRAMMER', 'SCIENTIST', 'SOLDIER',
        'TEACHER', 'VETERINARIAN', 'WAITER', 'WAITRESS'
      ],
    },
    {
      'title': 'กีฬาสุดสนุก',
      'subtitle': 'ออกกำลังกายให้แข็งแรง',
      'tag': '10 คำศัพท์',
      'primaryColor': Color(0xFFFF4081),
      'accentColor': Color(0xFFD81B60),
      'cardBg': Color(0xFFFFF0F5),
      'image': 'assets/images/vocabulary/sports/Archery.png',
      'icon': Icons.sports_soccer_rounded,
      'folder': 'sports',
      'words': [
        'BADMINTON', 'BASEBALL', 'BASKETBALL', 'CYCLING', 'RUNNING',
        'SOCCER', 'SWIMMING', 'TABLE TENNIS', 'TENNIS', 'VOLLEYBALL'
      ],
    },
    {
      'title': 'ยานพาหนะ',
      'subtitle': 'ออกเดินทางไปท่องโลกกว้าง',
      'tag': '10 คำศัพท์',
      'primaryColor': Color(0xFF10AC84),
      'accentColor': Color(0xFF0E8E6D),
      'cardBg': Color(0xFFE8F8F5),
      'image': 'assets/images/vocabulary/vehicles/Boat.png',
      'icon': Icons.directions_car_rounded,
      'folder': 'vehicles',
      'words': [
        'AIRPLANE', 'BICYCLE', 'BOAT', 'BUS', 'CAR', 'MOTORCYCLE',
        'TAXI', 'TRAIN', 'TRUCK', 'VAN'
      ],
    },
    {
      'title': 'สถานที่น่ารู้',
      'subtitle': 'รอบ ๆ ตัวเรามีที่ไหนบ้างนะ ?',
      'tag': '20 คำศัพท์',
      'primaryColor': Color(0xFFFECA57),
      'accentColor': Color(0xFFE1AF3C),
      'cardBg': Color(0xFFFFFBF0),
      'image': 'assets/images/vocabulary/places/School.png',
      'icon': Icons.storefront_rounded,
      'folder': 'places',
      'words': [
        'AIRPORT', 'BANK', 'BAKERY', 'BEACH' , 'CAFE', 'CINEMA', 'FACTORY',
        'GYM', 'HOSPITAL', 'HOTEL', 'LIBRARY', 'MOUNTAIN', 'OFFICE', 'PARK', 'PHARMACY', 
        'RESTAURANT', 'SCHOOL', 'SUPERMARKET', 'TEMPLE', 'ZOO'
      ]
    }
  ];

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFDFF3FC),
      body: _GameScaffoldBody(
        title: 'พยัญชนะต้น',
        color: const Color(0xFF29ABE2),
        showBack: canPop,
        child: _SkyBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 20, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'เลือกหมวดหมู่',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0B4F7A),
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                            Text(
                              'เลือกบทเรียนที่ต้องการฝึกทายคำศัพท์เลย',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3B7CA6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _CoinPill(fontSize: 15),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final Color primaryColor = cat['primaryColor'] as Color;
                      final Color accentColor = cat['accentColor'] as Color;
                      final Color cardBg = cat['cardBg'] as Color;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: BouncyTap(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LevelSelectScreen(categoryData: cat),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBg, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.25),
                                  blurRadius: 0,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 82,
                                        height: 82,
                                        decoration: BoxDecoration(
                                          color: cardBg,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white, width: 3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withOpacity(0.12),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(17),
                                          child: Image.asset(
                                            cat['image'] as String,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(
                                                cat['icon'] as IconData,
                                                size: 40,
                                                color: primaryColor,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: primaryColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                cat['tag'],
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              cat['title'],
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF1E293B),
                                                height: 1.1,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              cat['subtitle'],
                                              maxLines: 1,
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
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: accentColor,
                                              blurRadius: 0,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyBackground extends StatelessWidget {
  final Widget child;
  const _SkyBackground({required this.child});

  Widget _bubble(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF8ED8F5),
            Color(0xFFBFE8FA),
            Color(0xFFE3F5FD),
            Color(0xFFF4FBFF),
          ],
          stops: [0.0, 0.28, 0.62, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -50,
            child: _bubble(170, Colors.white.withOpacity(0.18)),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: _bubble(150, Colors.white.withOpacity(0.16)),
          ),
          Positioned(
            top: 330,
            left: -70,
            child: _bubble(140, const Color(0xFF29ABE2).withOpacity(0.07)),
          ),
          Positioned(
            bottom: 90,
            right: -40,
            child: _bubble(120, const Color(0xFF29ABE2).withOpacity(0.07)),
          ),
          Positioned(
            bottom: -50,
            left: 40,
            child: _bubble(150, Colors.white.withOpacity(0.35)),
          ),
          child,
        ],
      ),
    );
  }
}

// ============================================================
// Shared Custom Components
// ============================================================
const Color kInk = Color(0xFF0B2A4A);
const Color kMuted = Color(0xFF5B7A99);
const Color kGreen = Color(0xFF22C55E);
const Color kCoral = Color(0xFFFF7A59);

Color darken(Color c, [double amount = 0.15]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

class DynamicCategoryBackground extends StatelessWidget {
  final List<Color> bgGradient;
  final Widget child;

  const DynamicCategoryBackground({
    super.key,
    required this.bgGradient,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bgGradient.first,
            Colors.white,
          ],
        ),
      ),
      child: child,
    );
  }
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
        scale: _down ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

class ChunkyButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;
  final IconData? icon;

  const ChunkyButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return BouncyTap(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: color, width: 2),
          boxShadow: filled
              ? [BoxShadow(color: darken(color), offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PopIn extends StatelessWidget {
  final Widget child;
  const PopIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, v, ch) => Transform.scale(scale: v, child: ch),
      child: child,
    );
  }
}

// ============================================================
// ระบบด่าน
// ============================================================
/// Stars per level: saved per account on the phone and on the server
/// (see LetterLevels). Coins are the account's real coins (CoinBalance).
class LetterLevelStore {
  static const int levelCount = LetterLevels.levelCount;

  static Future<List<int>> load(String folder) => LetterLevels.load(folder);
}

// ============================================================
// 1.5 หน้าเลือกด่าน (LevelSelectScreen) - เพิ่มป้ายเหรียญ
// ============================================================
class LevelSelectScreen extends StatefulWidget {
  final Map<String, dynamic> categoryData;
  const LevelSelectScreen({super.key, required this.categoryData});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  static const double _rowH = 118;
  static const double _topPad = 120;
  static const double _bottomPad = 150;
  static const double _nodeSize = 72;
  static const double _bossSize = 80;
  static const double _currentSize = 86;
  static const double _cellW = 120;

  static const List<String> _tierName = [
    'เริ่มต้นง่าย ๆ',
    'เริ่มสนุกแล้ว',
    'ท้าทายขึ้นอีกนิด',
    'สุดยอดนักอ่าน',
  ];
  static const Color _ink = Color(0xFF2E2A4F);

  static const List<double> _xPattern = [
    0.50, 0.64, 0.38, 0.60, 0.32, 0.66, 0.42,
  ];

  List<int> _stars = List<int>.filled(LetterLevelStore.levelCount, 0);
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<int> _tier = ValueNotifier<int>(0);
  double _viewportH = 0;

  Color get _primary => widget.categoryData['primaryColor'] as Color;
  Color get _accent => widget.categoryData['accentColor'] as Color;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _tier.dispose();
    super.dispose();
  }

  Future<void> _load({bool fromServer = true}) async {
    final folder = widget.categoryData['folder'] as String;
    final s = await LetterLevelStore.load(folder);
    if (!mounted) return;
    setState(() => _stars = s);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    if (!fromServer) return;
    // Stars saved with the account (another phone / after reinstalling).
    await LetterLevels.syncAll();
    final synced = await LetterLevelStore.load(folder);
    if (!mounted) return;
    if (synced.join(',') != _stars.join(',')) {
      setState(() => _stars = synced);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final double y = _scroll.offset + _viewportH * 0.5 - _topPad;
    final int fromTop = (y / _rowH).floor();
    final int idx = (LetterLevelStore.levelCount - 1 - fromTop)
        .clamp(0, LetterLevelStore.levelCount - 1)
        .toInt();
    final int t = idx ~/ 5;
    if (t != _tier.value) _tier.value = t;
  }

  bool _isUnlocked(int level) => level == 1 || _stars[level - 2] > 0;

  int get _current {
    final i = _stars.indexWhere((s) => s == 0);
    return i == -1 ? 0 : i + 1;
  }

  double _levelY(int level) =>
      _topPad + (LetterLevelStore.levelCount - level) * _rowH + _rowH / 2;

  double _levelX(int level, double w) =>
      w * _xPattern[(level - 1) % _xPattern.length];

  double get _totalH =>
      _topPad + LetterLevelStore.levelCount * _rowH + _bottomPad;

  void _scrollToCurrent() {
    if (!_scroll.hasClients || _viewportH == 0) return;
    final int cur = _current;
    final double max = _scroll.position.maxScrollExtent;
    final double target = cur == 0 ? 0 : _levelY(cur) - _viewportH * 0.55;
    _scroll.jumpTo(target.clamp(0.0, max).toDouble());
  }

  Future<void> _openLevel(int level) async {
    HapticFeedback.lightImpact();
    if (!_isUnlocked(level)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Text(
            'ผ่านด่าน ${level - 1} ก่อน แล้วมาเจอกันนะ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          duration: const Duration(milliseconds: 1400),
        ));
      return;
    }
    // A level left in the middle: continue it or start again?
    final folder = widget.categoryData['folder'] as String;
    Map<String, dynamic>? resume = await LetterResume.load(folder, level);
    if (!mounted) return;
    if (resume != null) {
      final questions = resume['questions'] as List;
      final choice = await _askResume(level, resume['index'] as int, questions.length);
      if (!mounted || choice == null) return;
      if (!choice) {
        await LetterResume.clear(folder, level);
        resume = null;
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FirstLetterGame(
          categoryData: widget.categoryData,
          level: level,
          resume: resume,
        ),
      ),
    );
    _load(fromServer: false);
  }

  Future<bool?> _askResume(int level, int index, int total) {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: _primary.withOpacity(0.35), width: 2.5),
        ),
        title: Row(
          children: [
            Icon(Icons.play_circle_fill_rounded, color: _primary, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ด่าน $level',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: _ink),
              ),
            ),
          ],
        ),
        content: Text(
          'เล่นค้างไว้ที่ข้อ ${index + 1} จาก $total\nจะเล่นต่อเลยไหม ?',
          style: const TextStyle(
              fontSize: 15.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: BorderSide(color: _primary.withOpacity(0.5), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('เริ่มใหม่',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('เล่นต่อ',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Color.lerp(_primary, Colors.white, 0.6)!,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B6890),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _ink,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ เพิ่มป้ายเหรียญตรงนี้เรียบร้อยแล้ว
  Widget _buildInfoPanel(int passed, int totalStars) {
    final int total = LetterLevelStore.levelCount;
    final String msg = passed == 0
        ? 'เริ่มผจญภัยกันเลย'
        : passed >= total
            ? 'เก่งที่สุดเลย ผ่านครบทุกด่านแล้ว'
            : 'อีก ${total - passed} ด่านถึงเส้นชัย';

    return Container(
      width: double.infinity,
      color: Color.lerp(_primary, Colors.white, 0.86),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.categoryData['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      msg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A4668),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _statChip('ดาว', '$totalStars / ${total * 3}'),
              const SizedBox(width: 6),
              _statChip('ผ่านแล้ว', '$passed / $total'),
              const SizedBox(width: 6),
              const _CoinPill(fontSize: 13), // ✅ ป้ายเหรียญ
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: passed / total),
            duration: Duration.zero,
            builder: (context, v, _) {
              return Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: max(v.clamp(0.0, 1.0).toDouble(), 0.05),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6BE36F), Color(0xFF2BB24B)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTierPill() {
    return ValueListenableBuilder<int>(
      valueListenable: _tier,
      builder: (context, t, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.93),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            '${_tierName[t]}  •  ด่าน ${t * 5 + 1}-${t * 5 + 5}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        );
      },
    );
  }

  Widget _buildNode(int level, int current) {
    final bool unlocked = _isUnlocked(level);
    final int stars = _stars[level - 1];
    final bool isCurrent = level == current;
    final bool isBoss = level % 5 == 0;
    final double size =
        isCurrent ? _currentSize : (isBoss ? _bossSize : _nodeSize);

    final List<Color> fill;
    final Color edge;
    final Color rim;
    if (!unlocked) {
      fill = const [Color(0xFF8B5E3C), Color(0xFF5E3C24)];
      edge = const Color(0xFF3F2616);
      rim = isBoss ? const Color(0xFFF3D57A) : const Color(0xFFE6E0D6);
    } else if (isBoss) {
      fill = const [Color(0xFFFFE27A), Color(0xFFF0A416)];
      edge = const Color(0xFFB8730A);
      rim = Colors.white;
    } else {
      fill = const [Color(0xFF6BE36F), Color(0xFF2BB24B)];
      edge = const Color(0xFF1B7F36);
      rim = Colors.white;
    }

    final Widget box = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: fill,
        ),
        border: Border.all(color: rim, width: size * 0.055),
        boxShadow: [
          BoxShadow(color: edge, offset: Offset(0, size * 0.07)),
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 8,
            offset: Offset(0, size * 0.12),
          ),
          if (isCurrent)
            BoxShadow(
              color: const Color(0xFFFFE680).withOpacity(0.85),
              blurRadius: 18,
              spreadRadius: 3,
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.05,
            left: size * 0.14,
            right: size * 0.14,
            child: Container(
              height: size * 0.16,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(unlocked ? 0.28 : 0.12),
                borderRadius: BorderRadius.circular(size * 0.1),
              ),
            ),
          ),
          Text(
            '$level',
            style: TextStyle(
              fontSize: size * 0.46,
              fontWeight: FontWeight.w900,
              color: unlocked ? Colors.white : const Color(0xFFF1E6D8),
              height: 1.0,
              shadows: [Shadow(color: edge, offset: const Offset(0, 2.5))],
            ),
          ),
        ],
      ),
    );

    final Widget tappable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openLevel(level),
      child: box,
    );

    return SizedBox(
      width: _cellW,
      height: size + 30,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(top: 0, child: tappable),
          if (unlocked)
            Positioned(
              top: size - 6,
              child: IgnorePointer(
                child: SizedBox(
                  width: 78,
                  height: 28,
                  child: CustomPaint(painter: _StarsPainter(stars)),
                ),
              ),
            ),
          if (isCurrent)
            Positioned(
              top: -34,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFE27A), Color(0xFFE9A912)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFB8860B), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFF9A6B00), offset: Offset(0, 2.5)),
                    ],
                  ),
                  child: const Text(
                    'เล่นเลย',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5A3A00),
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(int current) {
    return LayoutBuilder(builder: (context, box) {
      final double w = box.maxWidth;
      _viewportH = box.maxHeight;
      final int total = LetterLevelStore.levelCount;

      final List<Offset> points = [
        for (int l = 1; l <= total; l++) Offset(_levelX(l, w), _levelY(l)),
      ];

      return Stack(
        children: [
          ClipRect(
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: w,
                height: _totalH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _LevelPathPainter(points: points),
                        ),
                      ),
                    ),
                    for (int l = 1; l <= total; l++)
                      Positioned(
                        left: _levelX(l, w) - _cellW / 2,
                        top: _levelY(l) -
                            (l == current
                                    ? _currentSize
                                    : (l % 5 == 0 ? _bossSize : _nodeSize)) /
                                2,
                        child: _buildNode(l, current),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: _buildTierPill())),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final int passed = _stars.where((s) => s > 0).length;
    final int totalStars = _stars.fold<int>(0, (a, b) => a + b);
    final int current = _current;

    return Scaffold(
      backgroundColor: const Color(0xFFA9D17F),
      body: _GameScaffoldBody(
        title: 'พยัญชนะต้น',
        color: _primary,
        child: Column(
          children: [
            _buildInfoPanel(passed, totalStars),
            Expanded(child: _buildMap(current)),
          ],
        ),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  final int count;
  const _StarsPainter(this.count);

  Path _star(Offset c, double r) {
    final Path p = Path();
    final double inner = r * 0.5;
    for (int i = 0; i < 10; i++) {
      final double rad = i.isEven ? r : inner;
      final double a = -pi / 2 + i * pi / 5;
      final Offset o = Offset(c.dx + rad * cos(a), c.dy + rad * sin(a));
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.height * 0.44;
    final List<Offset> centers = [
      Offset(size.width * 0.16, size.height * 0.60),
      Offset(size.width * 0.50, size.height * 0.42),
      Offset(size.width * 0.84, size.height * 0.60),
    ];
    for (int i = 0; i < 3; i++) {
      final bool on = i < count;
      final Path path = _star(centers[i], r);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..strokeJoin = StrokeJoin.round
          ..color = on ? const Color(0xFF9A6B00) : const Color(0xFF3E332B),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = on ? const Color(0xFFFFD43B) : const Color(0xFF6E5F52),
      );
      if (on) {
        canvas.drawCircle(
          centers[i].translate(-r * 0.25, -r * 0.3),
          r * 0.16,
          Paint()..color = Colors.white.withOpacity(0.7),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => old.count != count;
}

class _Deco {
  final int kind;
  final Offset pos;
  final double scale;
  const _Deco(this.kind, this.pos, this.scale);
}

class _LevelPathPainter extends CustomPainter {
  final List<Offset> points;
  const _LevelPathPainter({required this.points});

  static const double _topWater = 54;
  static const double _bottomWater = 104;

  Path _waterPath(Size size, {required bool top}) {
    const double seg = 56;
    final double w = size.width;
    final double y = top ? _topWater : size.height - _bottomWater;
    final double far = top ? 0 : size.height;
    final Path p = Path()..moveTo(0, far);
    p.lineTo(0, y);
    for (double x = 0; x < w; x += seg) {
      p.quadraticBezierTo(x + seg * 0.25, y - 9, x + seg * 0.5, y);
      p.quadraticBezierTo(x + seg * 0.75, y + 9, x + seg, y);
    }
    p.lineTo(w + seg, far);
    p.close();
    return p;
  }

  void _shadow(Canvas canvas, Offset c, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w, height: h),
      Paint()..color = const Color(0x26000000),
    );
  }

  void _tree(Canvas canvas, Offset base, double s) {
    _shadow(canvas, base.translate(0, 4 * s), 62 * s, 18 * s);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: base.translate(0, -12 * s), width: 14 * s, height: 28 * s),
        Radius.circular(5 * s),
      ),
      Paint()..color = const Color(0xFF9A6A3A),
    );
    final Offset c = base.translate(0, -46 * s);
    final Paint dark = Paint()..color = const Color(0xFF2E9E4F);
    final Paint mid = Paint()..color = const Color(0xFF45C25F);
    final Paint light = Paint()..color = const Color(0xFF86E594);
    canvas.drawCircle(c.translate(-17 * s, 9 * s), 21 * s, dark);
    canvas.drawCircle(c.translate(17 * s, 9 * s), 21 * s, dark);
    canvas.drawCircle(c, 28 * s, dark);
    canvas.drawCircle(c.translate(0, -3 * s), 25 * s, mid);
    canvas.drawCircle(c.translate(-9 * s, -11 * s), 10 * s, light);
  }

  void _bush(Canvas canvas, Offset base, double s) {
    _shadow(canvas, base.translate(0, 3 * s), 48 * s, 14 * s);
    final Paint dark = Paint()..color = const Color(0xFF33A453);
    final Paint mid = Paint()..color = const Color(0xFF4FCB68);
    canvas.drawCircle(base.translate(-12 * s, -8 * s), 13 * s, dark);
    canvas.drawCircle(base.translate(12 * s, -8 * s), 13 * s, dark);
    canvas.drawCircle(base.translate(0, -13 * s), 16 * s, dark);
    canvas.drawCircle(base.translate(0, -15 * s), 13 * s, mid);
    canvas.drawCircle(base.translate(-5 * s, -19 * s), 5 * s,
        Paint()..color = const Color(0xFF90EBA0));
  }

  void _rock(Canvas canvas, Offset base, double s) {
    _shadow(canvas, base.translate(0, 4 * s), 46 * s, 12 * s);
    canvas.drawOval(
      Rect.fromCenter(
          center: base.translate(0, -8 * s), width: 38 * s, height: 26 * s),
      Paint()..color = const Color(0xFF8E959C),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: base.translate(-3 * s, -12 * s),
          width: 28 * s,
          height: 16 * s),
      Paint()..color = const Color(0xFFB9BFC5),
    );
  }

  void _flowers(Canvas canvas, Offset p, double s) {
    const List<Color> cols = [
      Color(0xFFFFFFFF),
      Color(0xFFFFB3C7),
      Color(0xFFFFE066),
    ];
    const List<Offset> offs = [Offset(-12, 0), Offset(3, -6), Offset(14, 3)];
    for (int i = 0; i < 3; i++) {
      final Offset c = p + offs[i] * s;
      for (int k = 0; k < 5; k++) {
        final double a = k * 2 * pi / 5;
        canvas.drawCircle(
          c + Offset(cos(a), sin(a)) * (3.6 * s),
          2.6 * s,
          Paint()..color = cols[i],
        );
      }
      canvas.drawCircle(c, 2.2 * s, Paint()..color = const Color(0xFFFFC21A));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    canvas.clipRect(full);

    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB2DB86), Color(0xFF8FCB63)],
        ).createShader(full),
    );
    final Random rnd = Random(11);
    final Paint patch = Paint()..color = const Color(0x24FFFFFF);
    for (int i = 0; i < (size.height / 55).round(); i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
              rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
          width: 60 + rnd.nextDouble() * 90,
          height: 24 + rnd.nextDouble() * 30,
        ),
        patch,
      );
    }

    final Path topW = _waterPath(size, top: true);
    final Path botW = _waterPath(size, top: false);
    final Paint shore = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFE9DBA9);
    canvas.drawPath(topW, shore);
    canvas.drawPath(botW, shore);
    const List<Color> waterColors = [Color(0xFF66D1F8), Color(0xFF2E94DA)];
    canvas.drawPath(
      topW,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: waterColors,
        ).createShader(Rect.fromLTWH(0, 0, size.width, _topWater + 12)),
    );
    final double botTop = size.height - _bottomWater;
    canvas.drawPath(
      botW,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: waterColors,
        ).createShader(
            Rect.fromLTWH(0, botTop - 12, size.width, _bottomWater + 12)),
    );
    final Paint wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.38);
    for (int i = 0; i < 9; i++) {
      final double x = rnd.nextDouble() * size.width;
      final double yb = botTop + 26 + rnd.nextDouble() * (_bottomWater - 44);
      canvas.drawPath(
        Path()
          ..moveTo(x, yb)
          ..quadraticBezierTo(x + 9, yb - 5, x + 18, yb)
          ..quadraticBezierTo(x + 27, yb + 5, x + 36, yb),
        wave,
      );
    }
    for (int i = 0; i < 4; i++) {
      final double x = rnd.nextDouble() * size.width;
      final double yt = 14 + rnd.nextDouble() * (_topWater - 34);
      canvas.drawPath(
        Path()
          ..moveTo(x, yt)
          ..quadraticBezierTo(x + 9, yt - 5, x + 18, yt)
          ..quadraticBezierTo(x + 27, yt + 5, x + 36, yt),
        wave,
      );
    }

    if (points.isEmpty) return;

    final Offset first = points.first;
    final double startY = botTop + 8;
    final Path path = Path()..moveTo(first.dx, startY);
    path.cubicTo(first.dx, (startY + first.dy) / 2, first.dx,
        (startY + first.dy) / 2, first.dx, first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final Offset a = points[i];
      final Offset b = points[i + 1];
      final double midY = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }
    final Offset last = points.last;
    final double endY = _topWater + 6;
    path.cubicTo(last.dx, (last.dy + endY) / 2, last.dx, (last.dy + endY) / 2,
        last.dx, endY);

    Paint stroke(double width, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = color;
    canvas.drawPath(path, stroke(74, const Color(0xFFCDAE6E)));
    canvas.drawPath(path, stroke(64, const Color(0xFFEBD6A0)));
    canvas.drawPath(path, stroke(50, const Color(0xFFF4E5BA)));

    final List<Offset> samples = [];
    final Paint pebbleDark = Paint()..color = const Color(0xFFD9C48F);
    final Paint pebbleLight = Paint()..color = const Color(0x99FFFFFF);
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 16) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent == null) continue;
        samples.add(tangent.position);
        if (rnd.nextDouble() < 0.55) {
          final Offset normal = Offset(-tangent.vector.dy, tangent.vector.dx);
          final Offset c =
              tangent.position + normal * ((rnd.nextDouble() - 0.5) * 38);
          final Rect r = Rect.fromCenter(
            center: c,
            width: 5 + rnd.nextDouble() * 6,
            height: 4 + rnd.nextDouble() * 4,
          );
          canvas.drawOval(r, rnd.nextBool() ? pebbleDark : pebbleLight);
        }
      }
    }

    final List<_Deco> decos = [];
    final double yMin = _topWater + 90;
    final double yMax = size.height - _bottomWater - 18;
    final int attempts = (size.height / 14).round();
    for (int i = 0; i < attempts; i++) {
      final Offset p = Offset(
        14 + rnd.nextDouble() * (size.width - 28),
        yMin + rnd.nextDouble() * (yMax - yMin),
      );
      final double roll = rnd.nextDouble();
      final int kind = roll < 0.42
          ? 0
          : roll < 0.68
              ? 1
              : roll < 0.84
                  ? 2
                  : 3;
      final double scale = 0.8 + rnd.nextDouble() * 0.4;

      bool ok = true;
      for (final s in samples) {
        if (kind == 0) {
          if ((s - p).distance < 46 ||
              (s - p.translate(0, -46 * scale)).distance < 66) {
            ok = false;
            break;
          }
        } else if ((s - p).distance < (kind == 1 ? 56 : 48)) {
          ok = false;
          break;
        }
      }
      if (ok) {
        for (final d in decos) {
          final double gap = (d.kind == 0 || kind == 0) ? 64 : 40;
          if ((d.pos - p).distance < gap) {
            ok = false;
            break;
          }
        }
      }
      if (ok) decos.add(_Deco(kind, p, scale));
    }
    decos.sort((a, b) => a.pos.dy.compareTo(b.pos.dy));
    for (final d in decos) {
      switch (d.kind) {
        case 0:
          _tree(canvas, d.pos, d.scale);
          break;
        case 1:
          _bush(canvas, d.pos, d.scale);
          break;
        case 2:
          _rock(canvas, d.pos, d.scale);
          break;
        default:
          _flowers(canvas, d.pos, d.scale);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LevelPathPainter old) =>
      old.points.length != points.length ||
      (points.isNotEmpty &&
          (old.points.first != points.first || old.points.last != points.last));
}

// ============================================================
// 2. หน้าเกมเล่นตามหมวดหมู่ (FirstLetterGame)
// ============================================================
class FirstLetterGame extends StatefulWidget {
  final Map<String, dynamic> categoryData;
  final int level;

  /// A level left in the middle (from LetterResume) to continue, or null.
  final Map<String, dynamic>? resume;

  const FirstLetterGame({
    super.key,
    required this.categoryData,
    this.level = 1,
    this.resume,
  });

  @override
  State<FirstLetterGame> createState() => _FirstLetterGameState();
}

class _FirstLetterGameState extends State<FirstLetterGame> {
  int score = 0; // จำนวนข้อที่ตอบถูกในด่านนี้
  // Coins: 1 per right word per day (the server decides), like the other games.
  int _coinsThisRound = 0;
  int _pendingThisRound = 0; // answered offline, coin comes when back online
  int _roundId = 0; // late coin replies of an old round are ignored
  final List<Future<GuessCoinResult>> _coinFutures = [];
  int currentIndex = 0;
  bool _locked = false; // กันกดซ้ำ/กดตอบระหว่างโชว์ผล
  late int _level;
  late List<Map<String, dynamic>> questions;
  final Random _random = Random();

  static const List<Color> _optionColors = [
    Color(0xFF38BDF8),
    Color(0xFF2F80ED),
    Color(0xFF6C7CFF),
  ];

  // ชื่อคำศัพท์ในเกม -> ชื่อไฟล์รูปจริง (กรณีชื่อไม่ตรงกัน)
  // key ใช้รูปแบบ 'โฟลเดอร์/คำศัพท์ตัวพิมพ์เล็ก'
  static const Map<String, String> _imageAlias = {
    'vehicles/bicycle': 'Bike',
    'places/office': 'office',
    'places/gas station': 'Gasstation',
  };

  Color get _primaryColor =>
      widget.categoryData['primaryColor'] as Color? ?? const Color(0xFF7C4DFF);
  Color get _accentColor =>
      widget.categoryData['accentColor'] as Color? ?? const Color(0xFF651FFF);
  List<Color> get _bgGradient {
    final custom = widget.categoryData['bgGradient'] as List<Color>?;
    if (custom != null) return custom;
    return [
      Color.lerp(_primaryColor, Colors.white, 0.78)!,
      Color.lerp(_primaryColor, Colors.white, 0.9)!,
    ];
  }

  @override
  void initState() {
    super.initState();
    _level = widget.level;
    final resume = widget.resume;
    if (resume != null) {
      // Same words and letters as before, from the question they were on.
      questions = [
        for (final q in resume['questions'] as List)
          Map<String, dynamic>.from(q as Map),
      ];
      currentIndex = resume['index'] as int;
      score = resume['score'] as int;
      _coinsThisRound = resume['coins'] as int;
    } else {
      _generateQuestions();
    }
  }

  String get _folder => widget.categoryData['folder'] as String;

  /// Remembers where we are in this level (continued from here next time).
  void _saveResume() {
    LetterResume.save(
      _folder,
      _level,
      questions: questions,
      index: currentIndex,
      score: score,
      coins: _coinsThisRound,
    );
  }

  /// สร้าง path รูปให้ตรงกับชื่อไฟล์จริง เช่น "TABLE TENNIS" -> "Table Tennis.png"
  String _imagePathFor(String folder, String word) {
    final String alias = _imageAlias['$folder/${word.toLowerCase()}'] ??
        _titleCase(word);
    return 'assets/images/vocabulary/$folder/$alias.png';
  }

  String _titleCase(String text) => text
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  int _questionCountFor(int level) => 5 + ((level - 1) ~/ 5);

  int _pickMissingIndex(String word, int tier) {
    final List<int> idx = [
      for (int i = 0; i < word.length; i++)
        if (word[i] != ' ') i
    ];
    switch (tier) {
      case 0:
        return idx.first;
      case 1:
        return _random.nextBool() ? idx.first : idx.last;
      case 2:
        return idx[_random.nextInt(idx.length)];
      default:
        final List<int> mid =
            idx.length > 2 ? idx.sublist(1, idx.length - 1) : idx;
        return mid[_random.nextInt(mid.length)];
    }
  }

  List<String> _buildOptions(String word, String correct, int tier) {
    const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String vowels = 'AEIOU';
    final Set<String> inWord = word.replaceAll(' ', '').split('').toSet();
    final bool correctIsVowel = vowels.contains(correct);
    final List<String> letters = alphabet.split('')..remove(correct);

    List<String> candidates;
    if (tier <= 1) {
      candidates = letters.where((c) => !inWord.contains(c)).toList();
    } else {
      final List<String> sameType =
          letters.where((c) => vowels.contains(c) == correctIsVowel).toList();
      if (tier == 2) {
        candidates = sameType;
      } else {
        final List<String> inside =
            sameType.where((c) => inWord.contains(c)).toList()
              ..shuffle(_random);
        final List<String> outside =
            sameType.where((c) => !inWord.contains(c)).toList()
              ..shuffle(_random);
        candidates = [...inside, ...outside];
      }
    }
    if (tier != 3) candidates.shuffle(_random);

    final List<String> options = [correct, ...candidates.take(2)];
    letters.shuffle(_random);
    for (final String c in letters) {
      if (options.length >= 3) break;
      if (!options.contains(c)) options.add(c);
    }
    options.shuffle(_random);
    return options;
  }

  void _generateQuestions() {
    final int level = _level;
    final int tier = (level - 1) ~/ 5;

    int len(String w) => w.replaceAll(' ', '').length;
    final List<String> all = List<String>.from(widget.categoryData['words']);
    all.sort((a, b) {
      final int c = len(a).compareTo(len(b));
      return c != 0 ? c : a.compareTo(b);
    });

    final int n = all.length;
    final int count = min(_questionCountFor(level), n);
    final int window = min(n, max(count, (n * 0.4).ceil()));
    final double d = (level - 1) / (LetterLevelStore.levelCount - 1);
    final int start = ((n - window) * d).round();
    final List<String> pool = all.sublist(start, start + window)
      ..shuffle(_random);
    final List<String> picked = pool.take(count).toList()
      ..sort((a, b) => len(a).compareTo(len(b)));

    final String folder = widget.categoryData['folder'] as String;

    questions = picked.map((word) {
      final int missingIndex = _pickMissingIndex(word, tier);
      final String correctLetter = word[missingIndex];

      return {
        'fullWord': word,
        'missingIndex': missingIndex,
        'correctLetter': correctLetter,
        'options': _buildOptions(word, correctLetter, tier),
        'imagePath': _imagePathFor(folder, word),
      };
    }).toList();
  }

  // ignore: unused_element
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  void _playAgain() {
    setState(() {
      _roundId++;
      _coinsThisRound = 0;
      _pendingThisRound = 0;
      _coinFutures.clear();
      _locked = false;
      score = 0;
      currentIndex = 0;
      _generateQuestions();
    });
  }

  Future<void> _goNextLevel() async {
    final next = _level + 1;
    // The next level may have been left in the middle before: continue it
    // (nothing played is thrown away).
    final resume = await LetterResume.load(_folder, next);
    if (!mounted) return;
    setState(() {
      _roundId++;
      _pendingThisRound = 0;
      _coinFutures.clear();
      _locked = false;
      _level = next;
      if (resume != null) {
        questions = [
          for (final q in resume['questions'] as List)
            Map<String, dynamic>.from(q as Map),
        ];
        currentIndex = resume['index'] as int;
        score = resume['score'] as int;
        _coinsThisRound = resume['coins'] as int;
      } else {
        score = 0;
        currentIndex = 0;
        _coinsThisRound = 0;
        _generateQuestions();
      }
    });
    if (resume != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _accentColor,
          content: Text(
            'ด่าน $next เคยเล่นค้างไว้ เล่นต่อจากข้อ ${currentIndex + 1} นะ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          duration: const Duration(milliseconds: 1800),
        ));
    }
  }

  // ครอบ Dialog ไม่ให้ปุ่ม Back ปิดได้ (ไม่งั้นตอบข้อเดิมซ้ำแล้วคะแนนเบิ้ล)
  Widget _lockedDialog(Widget dialog) =>
      PopIn(child: PopScope(canPop: false, child: dialog));

  void _checkAnswer(String letter) {
    if (_locked) return;
    _locked = true;
    final q = questions[currentIndex];
    final bool isCorrect = letter == q['correctLetter'];
    final bool isLast = currentIndex >= questions.length - 1;
    final Color tone = isCorrect ? kGreen : kCoral;

    if (isCorrect) setState(() => score++);

    final String word = q['fullWord'];
    final int missing = q['missingIndex'];

    // 1 coin per word per day (the server decides).
    Future<GuessCoinResult>? coinFuture;
    if (isCorrect) {
      final round = _roundId;
      coinFuture = LetterCoins.submit(
        categoryKey: widget.categoryData['folder'] as String,
        word: word,
      ).then((r) {
        if (mounted && round == _roundId) {
          setState(() {
            _coinsThisRound += r.coins;
            if (r.pending) _pendingThisRound++;
          });
        }
        return r;
      });
      _coinFutures.add(coinFuture);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _lockedDialog(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                    color: tone.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 12))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The bird character: happy when right, sad when wrong.
                SizedBox(
                  width: 130,
                  height: 120,
                  child: Image.asset(
                    isCorrect
                        ? 'assets/images/character/bravo.png'
                        : 'assets/images/character/sad.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.sentiment_dissatisfied_rounded,
                      size: 66,
                      color: tone,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isCorrect ? 'ถูกต้องแล้ว' : 'ยังไม่ถูกนะ ไม่เป็นไร!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900, color: tone),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _bgGradient.first.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text('คำเต็มคือ',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kMuted)),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            for (int i = 0; i < word.length; i++)
                              TextSpan(
                                text: word[i],
                                style: TextStyle(
                                  fontSize: i == missing ? 32 : 26,
                                  fontWeight: FontWeight.w900,
                                  color: i == missing ? tone : kInk,
                                ),
                              ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(letterSpacing: 3),
                      ),
                    ],
                  ),
                ),
                if (coinFuture != null) ...[
                  const SizedBox(height: 12),
                  FutureBuilder<GuessCoinResult>(
                    future: coinFuture,
                    builder: (context, snap) {
                      final r = snap.data;
                      final String text;
                      if (snap.connectionState != ConnectionState.done) {
                        text = 'กำลังรับเหรียญ...';
                      } else if (r != null && r.coins > 0) {
                        text = '+${r.coins} เหรียญ';
                      } else if (r != null && r.pending) {
                        text = '+$kGameCoinsPerWord เหรียญ (ได้รับเมื่อต่อเน็ต)';
                      } else if (r != null && r.alreadyToday) {
                        text = 'คำนี้ได้เหรียญไปแล้ววันนี้';
                      } else {
                        text = 'ตอบถูก 1 ข้อ';
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on_rounded,
                              color: Color(0xFFFFB627), size: 24),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFB45309))),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 22),
                ChunkyButton(
                  label: isLast ? 'ดูผลลัพธ์' : 'ข้อถัดไป',
                  color: _primaryColor,
                  onTap: () {
                    Navigator.pop(dialogCtx);
                    if (!isLast) {
                      setState(() {
                        currentIndex++;
                        _locked = false;
                      });
                      _saveResume();
                    } else {
                      _showCompletionDialog();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _starsFor(int correct, int total) {
    if (total == 0) return 0;
    final double r = correct / total;
    if (r >= 1.0) return 3;
    if (r >= 0.8) return 2;
    if (r >= 0.6) return 1;
    return 0;
  }

  Future<void> _showCompletionDialog() async {
    final int correct = score;
    final int stars = _starsFor(correct, questions.length);
    final bool passed = stars > 0;
    final bool hasNext = passed && _level < LetterLevelStore.levelCount;
    final bool finishedAll = passed && _level >= LetterLevelStore.levelCount;

    // Best stars, here and on the server (coins came with each right word).
    final String folder = widget.categoryData['folder'] as String;
    await LetterResume.clear(folder, _level); // finished: nothing to continue
    await LetterLevels.record(folder, _level, stars);
    // Wait for the last coin replies, so the total below is complete.
    await Future.wait(List.of(_coinFutures));
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _lockedDialog(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                    color: _primaryColor.withOpacity(0.35),
                    blurRadius: 34,
                    offset: const Offset(0, 14))
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    passed ? 'ผ่านด่าน $_level แล้ว' : 'เกือบแล้ว ลองอีกครั้งนะ',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900, color: kInk),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < 3; i++)
                        Icon(
                          Icons.star_rounded,
                          size: i == 1 ? 54 : 44,
                          color: i < stars
                              ? const Color(0xFFFFB300)
                              : const Color(0xFFE2E8F0),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        Text('ตอบถูก $correct จาก ${questions.length} ข้อ',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: kMuted)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monetization_on_rounded,
                                color: Color(0xFFFFB627), size: 46),
                            const SizedBox(width: 8),
                            Text('+$_coinsThisRound',
                                style: TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    color: darken(_primaryColor, 0.08),
                                    height: 1.1)),
                          ],
                        ),
                        Text(
                            _pendingThisRound > 0
                                ? 'เหรียญที่ได้ (+${_pendingThisRound * kGameCoinsPerWord} รอต่อเน็ต)'
                                : 'เหรียญที่ได้ (คำละ $kGameCoinsPerWord เหรียญต่อวัน)',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: kMuted)),
                      ],
                    ),
                  ),
                  if (finishedAll) ...[
                    const SizedBox(height: 10),
                    const Text('ผ่านครบทุกด่านในหมวดนี้แล้ว',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kInk)),
                  ],
                  const SizedBox(height: 18),
                  if (hasNext) ...[
                    ChunkyButton(
                      label: 'ด่านถัดไป ➔',
                      color: _primaryColor,
                      onTap: () {
                        Navigator.pop(dialogCtx);
                        _goNextLevel();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  ChunkyButton(
                    label: passed ? 'เล่นด่านนี้อีกครั้ง' : 'ลองอีกครั้ง',
                    icon: Icons.replay_rounded,
                    color: _primaryColor,
                    filled: !hasNext,
                    onTap: () {
                      Navigator.pop(dialogCtx);
                      _playAgain();
                    },
                  ),
                  const SizedBox(height: 12),
                  ChunkyButton(
                    label: 'กลับหน้าเลือกด่าน',
                    icon: Icons.grid_view_rounded,
                    color: kMuted,
                    filled: false,
                    onTap: () {
                      Navigator.pop(dialogCtx);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final int total = questions.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.categoryData['title'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _accentColor),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [_primaryColor, _accentColor]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('ด่าน $_level',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ),
              const SizedBox(width: 8),
              const _CoinPill(fontSize: 14),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primaryColor.withOpacity(0.3), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (currentIndex + 1) / total),
                      duration: const Duration(milliseconds: 450),
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 12,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(_primaryColor),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${currentIndex + 1} / $total',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // รูปภาพในวงกลม: ตัดด้วย ClipOval ไม่ให้มุมรูปเกินออกนอกกรอบ + เว้นขอบให้พอดี
  Widget _buildImage(Map<String, dynamic> q) {
    const double outer = 280; // ขนาดวงกลมนอก
    const double ring = 8; // ความหนาขอบสี
    const double inner = outer - ring * 2; // วงกลมขาวด้านใน = 264
    const double imgPad = 36; // ระยะห่างรูปจากขอบวงกลม (ปรับได้)

    return Container(
      width: outer,
      height: outer,
      padding: const EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _accentColor],
        ),
        boxShadow: [
          BoxShadow(
              color: _primaryColor.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10))
        ],
      ),
      child: ClipOval(
        child: Container(
          width: inner,
          height: inner,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white,
                Color.lerp(Colors.white, _primaryColor, 0.08)!,
              ],
              stops: const [0.65, 1.0],
            ),
          ),
          padding: const EdgeInsets.all(imgPad),
          child: Image.asset(
            q['imagePath'] as String,
            key: ValueKey(q['imagePath']),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Icon(
              widget.categoryData['icon'] as IconData,
              size: 90,
              color: _primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordDisplay(Map<String, dynamic> q) {
    final String word = q['fullWord'];
    final int missing = q['missingIndex'];

    return LayoutBuilder(builder: (context, box) {
      final int n = word.length;
      final int spaces = ' '.allMatches(word).length;
      final int letters = n - spaces;
      const double gap = 6;
      const double spaceW = 12;
      final double avail = box.maxWidth - spaces * spaceW - (n - 1) * gap - 4;
      final double w = (avail / letters).clamp(22.0, 42.0).toDouble();
      final double h = (w * 1.4).clamp(34.0, 56.0).toDouble();

      final List<Widget> tiles = [];
      for (int i = 0; i < n; i++) {
        if (i > 0) tiles.add(const SizedBox(width: gap));
        if (word[i] == ' ') {
          tiles.add(const SizedBox(width: spaceW));
          continue;
        }
        final bool isMissing = i == missing;
        tiles.add(Container(
          width: isMissing ? w + 4 : w,
          height: h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isMissing ? _primaryColor.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(h * 0.28),
            border: Border.all(
              color: isMissing ? _primaryColor : _primaryColor.withOpacity(0.25),
              width: isMissing ? 3 : 2,
            ),
            boxShadow: isMissing
                ? null
                : [
                    BoxShadow(
                        color: _primaryColor.withOpacity(0.15),
                        offset: const Offset(0, 4))
                  ],
          ),
          child: Text(
            isMissing ? '?' : word[i],
            style: TextStyle(
              fontSize: isMissing ? h * 0.58 : h * 0.5,
              fontWeight: FontWeight.w900,
              color: isMissing ? _primaryColor : kInk,
            ),
          ),
        ));
      }
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: tiles),
        ),
      );
    });
  }

  Widget _buildQuestion(Map<String, dynamic> q) {
    final List<String> options = q['options'] as List<String>;
    return LayoutBuilder(builder: (context, box) {
      final double h = box.maxHeight;
      final double optSize = (h * 0.105).clamp(50.0, 68.0).toDouble();
      final double gap = (h * 0.025).clamp(8.0, 20.0).toDouble();
      return Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildImage(q),
                ),
              ),
            ),
          ),
          SizedBox(height: gap),
          _buildWordDisplay(q),
          SizedBox(height: gap),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: _primaryColor.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'เลือกตัวอักษรที่หายไป',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _accentColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap * 1.4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(options.length, (i) {
              final Color c = _optionColors[i % _optionColors.length];
              return BouncyTap(
                onTap: () => _checkAnswer(options[i]),
                child: Container(
                  width: optSize,
                  height: optSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(optSize * 0.3),
                    boxShadow: [
                      BoxShadow(color: darken(c), offset: const Offset(0, 5)),
                      BoxShadow(
                          color: c.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Text(
                    options[i],
                    style: TextStyle(
                        fontSize: optSize * 0.48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = questions[currentIndex];

    return Scaffold(
      body: _GameScaffoldBody(
        title: 'พยัญชนะต้น',
        color: _primaryColor,
        child: DynamicCategoryBackground(
          bgGradient: _bgGradient,
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      // The old question fading out can't be tapped (that
                      // answered the new question with an old letter).
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [
                          for (final w in previous) IgnorePointer(child: w),
                          if (current != null) current,
                        ],
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(currentIndex),
                        child: _buildQuestion(currentQ),
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
}

// ---------------------------------------------------------------
// ป้ายแสดงเหรียญ
// ---------------------------------------------------------------
class _CoinPill extends StatefulWidget {
  final Color color;
  final double fontSize;

  const _CoinPill({
    // ignore: unused_element_parameter
    this.color = const Color(0xFFB45309),
    this.fontSize = 15,
  });

  @override
  State<_CoinPill> createState() => _CoinPillState();
}

class _CoinPillState extends State<_CoinPill> {
  @override
  void initState() {
    super.initState();
    // The account's coins (same number as the other games and the profile).
    if (CoinBalance.value.value == null) CoinBalance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final double fs = widget.fontSize;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fs * 0.7, vertical: fs * 0.3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(fs * 1.6),
        border: Border.all(color: const Color(0xFFFFD43B), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
          ValueListenableBuilder<int?>(
            valueListenable: CoinBalance.value,
            builder: (context, value, _) => Text(
              value == null ? '–' : '$value',
              style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w900,
                color: widget.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
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