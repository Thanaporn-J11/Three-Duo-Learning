import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/coin_balance.dart';
import '../../../services/guess_progress_service.dart' show GuessCoinResult;
import '../../../services/market_service.dart';
import '../../../services/user_account_preferences.dart';
import '../../../widgets/parent_pin_prompt.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await gameProgress.load();
  runApp(const OrderUpGameApp());
}

// ==========================================
// จำนวนด่าน: 28 ด่าน (ทุกด่านที่ 7, 14, 21, 28 คือด่านบอส)
// (ใช้ "ชุด" ละ 7 ด่านภายในเพื่อไล่ความยาก ไม่ได้แสดงเป็นโลกแล้ว)
// ==========================================
const int kLevelsPerWorld = 7;
const int kWorldCount = 4;
const int kTotalLevels = kLevelsPerWorld * kWorldCount;

// ==========================================
// Progress (ดาว / ด่าน / สมุดสะสม) — แยกตามบัญชี เก็บในเครื่องและบนเซิร์ฟเวอร์
// ==========================================

/// ความคืบหน้าของบัญชีที่ล็อกอินอยู่ (ดาว 28 ด่าน ด่านที่ปลดล็อก สติกเกอร์ที่สะสม)
/// เก็บในเครื่องแยกตามบัญชีและบนเซิร์ฟเวอร์ (MarketStateSync) ลบแอปแล้วไม่หาย
class ProgressStore extends ChangeNotifier {
  final List<int> stars = List<int>.filled(kTotalLevels, 0);

  int maxUnlockedLevel = 1; // ด่านสูงสุดที่ปลดล็อก
  final Map<String, int> remainingItems = {}; // สติกเกอร์ที่สะสม (itemId -> จำนวน)
  Set<int> unfinished = {}; // ด่านที่เล่นค้างไว้ (ป้าย "ต่อ")

  int get totalStars => stars.fold(0, (a, b) => a + b);
  int get clearedLevels => stars.where((s) => s > 0).length;

  /// ด่าน 1 เปิดเสมอ หรือด่านที่ <= maxUnlockedLevel หรือได้ดาวจากด่านก่อนหน้า
  bool isUnlocked(int level) =>
      level == 1 || level <= maxUnlockedLevel || (level >= 2 && stars[level - 2] > 0);

  /// ด่านแรกที่ยังไม่เคยผ่าน (ถ้าผ่านหมดแล้วจะเป็นด่านสุดท้าย)
  int get nextLevel {
    for (int i = 1; i <= kTotalLevels; i++) {
      if (stars[i - 1] == 0) return i;
    }
    return kTotalLevels;
  }

  // ---------- Load ----------

  void _setDefaults() {
    for (int i = 0; i < kTotalLevels; i++) {
      stars[i] = 0;
    }
    maxUnlockedLevel = 1;
    remainingItems.clear();
    unfinished = {};
  }

  /// โหลดของบัญชีที่ล็อกอินอยู่ (เรียกทุกครั้งที่เปิดเกม บัญชีอื่นจะไม่เห็นข้อมูลกัน)
  Future<void> load() async {
    if (CoinBalance.value.value == null) CoinBalance.refresh();
    _setDefaults();
    try {
      final local = await MarketStateSync.loadLocal();
      if (local != null) {
        _applyJson(local);
      } else {
        // เล่นไว้กับเวอร์ชันเก่า (เก็บในเครื่องแบบไม่แยกบัญชี): ย้ายเข้าบัญชีนี้
        final old = await _claimOldProgress();
        if (old != null) {
          _applyJson(old);
          _sanitize();
          await MarketStateSync.save(_toJson());
        }
      }
      // บนเซิร์ฟเวอร์ใหม่กว่า (ลบแอปแล้วลงใหม่ / เล่นอีกเครื่อง)?
      final server = await MarketStateSync.pull().timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (server != null) _applyJson(server);
      await MarketResume.sync().timeout(const Duration(seconds: 4), onTimeout: () {});
      final result = <int>{};
      for (int level = 1; level <= kTotalLevels; level++) {
        final r = await MarketResume.load(level, customers: LevelConfig.forLevel(level).customers);
        if (r != null) result.add(level);
      }
      unfinished = result;
    } catch (e) {
      debugPrint('ProgressStore.load failed: $e');
    }
    _sanitize();
    notifyListeners();
  }

  void _applyJson(dynamic data) {
    if (data is! Map) return;
    final s = data['stars'];
    for (int i = 0; i < kTotalLevels; i++) {
      stars[i] = (s is List && i < s.length) ? _asInt(s[i]) : 0;
    }
    maxUnlockedLevel = _asInt(data['maxUnlockedLevel'], 1);
    remainingItems.clear();
    final items = data['items'];
    if (items is Map) {
      items.forEach((k, v) {
        final n = _asInt(v);
        if (n > 0) remainingItems['$k'] = n;
      });
    }
  }

  /// ข้อมูลจากเวอร์ชันเก่า (key: progress_v2 หรือเก่ากว่านั้น) ให้บัญชีแรกที่เปิดเกมในเครื่องนี้
  Future<Map<String, dynamic>?> _claimOldProgress() async {
    final userId = await UserAccountPreferences.currentUserId();
    if (userId == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final doneKey = UserAccountPreferences.keyFor('market_old_checked', userId);
    if (prefs.getBool(doneKey) ?? false) return null;
    await prefs.setBool(doneKey, true);
    final raw = prefs.getString('progress_v2');
    final legacyStars = prefs.getStringList('level_stars');
    final legacyItemKeys = prefs.getStringList('inventory_keys');
    if (raw == null && legacyStars == null && legacyItemKeys == null &&
        !prefs.containsKey('max_unlocked_level')) {
      return null;
    }
    if (!await UserAccountPreferences.claimLegacyData('market_old_owner', userId)) return null;
    if (raw != null) {
      try {
        final j = jsonDecode(raw);
        if (j is Map) return Map<String, dynamic>.from(j);
      } catch (_) {}
    }
    return {
      'stars': [
        for (int i = 0; i < kTotalLevels; i++)
          legacyStars != null && i < legacyStars.length ? (int.tryParse(legacyStars[i]) ?? 0) : 0,
      ],
      'maxUnlockedLevel': prefs.getInt('max_unlocked_level') ?? 1,
      'items': {
        for (final key in legacyItemKeys ?? const <String>[]) key: prefs.getInt('inventory_item_$key') ?? 0,
      },
    };
  }

  /// กันข้อมูลเพี้ยน/ติดลบ และให้ด่านที่ปลดล็อกสอดคล้องกับดาวที่มี
  void _sanitize() {
    for (int i = 0; i < kTotalLevels; i++) {
      stars[i] = min(3, max(0, stars[i]));
    }
    int floorLevel = 1;
    for (int i = 0; i < kTotalLevels; i++) {
      if (stars[i] > 0) floorLevel = max(floorLevel, min(kTotalLevels, i + 2));
    }
    maxUnlockedLevel = min(kTotalLevels, max(floorLevel, max(1, maxUnlockedLevel)));
    remainingItems.removeWhere((id, v) => v <= 0 || !kAllMarketItems.any((i) => i.id == id));
  }

  static int _asInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

  // ---------- Save ----------

  Map<String, dynamic> _toJson() => {
        'stars': List<int>.of(stars),
        'maxUnlockedLevel': maxUnlockedLevel,
        'items': Map<String, int>.of(remainingItems),
      };

  Future<void> _save() => MarketStateSync.save(_toJson());

  /// บังคับบันทึกทันที
  Future<void> saveNow() => _save();

  // ---------- Mutations ----------

  /// ส่งของสำเร็จ 1 ออเดอร์: เก็บสินค้าเข้าสมุดสะสม แล้วบันทึก
  void recordDelivery({required Map<String, int> items}) {
    items.forEach((id, count) {
      if (count > 0) remainingItems[id] = (remainingItems[id] ?? 0) + count;
    });
    notifyListeners();
    _save();
  }

  void completeLevel(int level, int earnedStars) {
    if (level < 1 || level > kTotalLevels) return;
    final s = min(3, max(0, earnedStars));
    if (s > stars[level - 1]) stars[level - 1] = s;
    if (s > 0 && level < kTotalLevels && (level + 1) > maxUnlockedLevel) {
      maxUnlockedLevel = level + 1;
    }
    notifyListeners();
    _save();
  }

  void markUnfinished(int level, bool on) {
    final changed = on ? unfinished.add(level) : unfinished.remove(level);
    if (changed) notifyListeners();
  }

  Future<void> reset() async {
    _setDefaults();
    notifyListeners();
    await _save();
  }
}

final ProgressStore gameProgress = ProgressStore();

// ==========================================
// Palette: โทนสีสดใสสไตล์ลูกอม + ซูเปอร์มาร์เก็ต
// ==========================================
class AppColors {
  static const Color ink = Color(0xFF1E293B);
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueDark = Color(0xFF1D4ED8);
  static const Color sky = Color(0xFF38BDF8);
  static const Color green = Color(0xFF22C55E);
  static const Color greenDark = Color(0xFF15803D);
  static const Color orange = Color(0xFFFF8A3D);
  static const Color orangeDark = Color(0xFFC2560F);
  static const Color yellow = Color(0xFFFBBF24);
  static const Color yellowDark = Color(0xFFB45309);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleDark = Color(0xFF6D28D9);
  static const Color pink = Color(0xFFF472B6);
  static const Color pinkDark = Color(0xFFBE185D);
  static const Color red = Color(0xFFEF4444);
  static const Color redDark = Color(0xFF991B1B);
  static const Color cream = Color(0xFFFFF8E7);
  // พื้นหลังโทนทอง ต่อเนื่องจากแถบด้านบน (#F5B000)
  static const List<Color> goldenSky = [
    Color.fromARGB(255, 255, 227, 156),
    Color.fromARGB(255, 255, 241, 202),
    Color(0xFFFFF4CF),
    Color(0xFFFFFBEF),
  ];
  static const Color lockedFace = Color(0xFFB6C2D4);
  static const Color lockedEdge = Color(0xFF8795AB);
}

Color lighten(Color c, [double t = 0.25]) => Color.lerp(c, Colors.white, t)!;

/// การ์ดขาวมุมมน ขอบหนา เงานุ่ม — ใช้เป็นพื้นฐานของทุกหน้า
Widget softCard({
  required Widget child,
  Color border = Colors.white,
  Color color = Colors.white,
  EdgeInsets padding = const EdgeInsets.all(12),
  double radius = 24,
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x26000000), offset: Offset(0, 4), blurRadius: 8)],
    ),
    child: child,
  );
}

// ==========================================
// พื้นหลังสดใส: ไล่สี + อีโมจิลอยเบาๆ (เมฆ ดวงอาทิตย์ บอลลูน ดาว)
// ==========================================
class SunnyBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final List<String> decor;

  const SunnyBackground({
    super.key,
    required this.child,
    this.colors = AppColors.goldenSky,
    this.decor = const ['☁️', '☀️', '🎈', '⭐', '☁️', '🌈', '✨', '🎈'],
  });

  @override
  State<SunnyBackground> createState() => _SunnyBackgroundState();
}

class _SunnyBackgroundState extends State<SunnyBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const List<double> _fx = [0.04, 0.76, 0.88, 0.10, 0.46, 0.28, 0.64, 0.90];
  static const List<double> _fy = [0.05, 0.02, 0.38, 0.56, 0.14, 0.82, 0.90, 0.68];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.colors,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, c) {
                  return AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final children = <Widget>[];
                      for (int i = 0; i < widget.decor.length; i++) {
                        final dy = sin(_c.value * 2 * pi + i * 1.3) * 8;
                        children.add(Positioned(
                          left: c.maxWidth * _fx[i % _fx.length],
                          top: c.maxHeight * _fy[i % _fy.length] + dy,
                          child: Opacity(
                            opacity: 0.55,
                            child: Text(widget.decor[i], style: TextStyle(fontSize: 26.0 + (i % 3) * 8)),
                          ),
                        ));
                      }
                      return Stack(children: children);
                    },
                  );
                },
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

// ==========================================
// Animation Helpers
// ==========================================
class _FloatingCoin {
  final int id;
  final String text;
  final Color color;
  _FloatingCoin({required this.id, required this.text, required this.color});
}

class _ConfettiParticle {
  final double left;
  final double delay;
  final double speed;
  final Color color;
  final double size;
  final bool round;
  _ConfettiParticle({
    required this.left,
    required this.delay,
    required this.speed,
    required this.color,
    required this.size,
    required this.round,
  });
}

class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;
  static const double _areaWidth = 300;
  static const double _areaHeight = 200;

  static const List<Color> _colors = [
    Color(0xFF60A5FA),
    Color(0xFFFBBF24),
    Color(0xFF34D399),
    Color(0xFFF472B6),
    Color(0xFFFF8A3D),
    Color(0xFFA78BFA),
  ];

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _particles = List.generate(48, (i) {
      return _ConfettiParticle(
        left: rnd.nextDouble(),
        delay: rnd.nextDouble() * 0.35,
        speed: 0.7 + rnd.nextDouble() * 0.6,
        color: _colors[rnd.nextInt(_colors.length)],
        size: 7 + rnd.nextDouble() * 7,
        round: rnd.nextBool(),
      );
    });
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: _areaHeight,
        width: _areaWidth,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: _particles.map((p) {
                final t = ((_controller.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
                final y = t * _areaHeight * p.speed;
                final opacity = (1 - t).clamp(0.0, 1.0);
                return Positioned(
                  left: p.left * _areaWidth,
                  top: y,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: t * 6.28 * p.speed,
                      child: Container(
                        width: p.size,
                        height: p.round ? p.size : p.size * 0.6,
                        decoration: BoxDecoration(
                          color: p.color,
                          shape: p.round ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: p.round ? null : BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class FloatingUpText extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onDone;

  const FloatingUpText({super.key, required this.text, required this.color, required this.onDone});

  @override
  State<FloatingUpText> createState() => _FloatingUpTextState();
}

class _FloatingUpTextState extends State<FloatingUpText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rise;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _rise = Tween<double>(begin: 0, end: -40).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _rise.value),
        child: Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: widget.color,
              shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

/// ขยาย-หดเบาๆ เพื่อเรียกความสนใจ (ใช้กับด่านปัจจุบัน / ปุ่มเล่น)
class Pulse extends StatefulWidget {
  final Widget child;
  final double amount;
  const Pulse({super.key, required this.child, this.amount = 0.06});

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  // ไม่มีอนิเมชันแล้ว: แสดง child นิ่งๆ
  @override
  Widget build(BuildContext context) => widget.child;
}

/// แถวดาว 3 ดวง
class StarRow extends StatelessWidget {
  final int count;
  final double size;
  const StarRow({super.key, required this.count, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Icon(
          Icons.star_rounded,
          size: size,
          color: i < count ? AppColors.yellow : Colors.white.withAlpha(110),
        ),
      ),
    );
  }
}

class ChunkyButton extends StatefulWidget {
  final Widget child;
  final Color color;
  final Color shadowColor;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final double radius;

  const ChunkyButton({
    super.key,
    required this.child,
    required this.color,
    required this.shadowColor,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.radius = 18,
  });

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, enabled && _down ? 3 : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [lighten(widget.color, 0.22), widget.color],
                )
              : null,
          color: enabled ? null : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: Colors.white.withAlpha(enabled ? 170 : 90), width: 2),
          boxShadow: [
            BoxShadow(
              color: enabled ? widget.shadowColor : const Color(0xFF94A3B8),
              offset: Offset(0, enabled ? (_down ? 1 : 4) : 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
          textAlign: TextAlign.center,
          child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
        ),
      ),
    );
  }
}

class OrderUpGameApp extends StatelessWidget {
  const OrderUpGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Supermarket Order Up!',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFFFF4CF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.blue,
          primary: AppColors.blue,
          secondary: AppColors.green,
        ),
      ),
      home: const LevelSelectScreen(),
    );
  }
}

// ==========================================
// Models & Data Structures
// ==========================================

enum OrderStyle { plain, colorful, quantity, mixed }

enum CustomerPhase { entering, waiting, leaving }

class MarketItem {
  final String id;
  final String name;
  final String emoji;
  final String category;
  final String? quantifier;
  final String? quantName;
  final String? colorAdjective;
  final bool countable;

  const MarketItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    this.quantifier,
    this.quantName,
    this.colorAdjective,
    this.countable = true,
  });
}

class OrderRequirement {
  final MarketItem item;
  final int count;
  final OrderStyle style; // plain / colorful / quantity (ต่อรายการ เพราะโหมด mixed สลับได้)
  OrderRequirement({required this.item, required this.count, required this.style});
}

class CustomerModel {
  final String id;
  final String name;
  final String englishName;
  final String emoji;
  final Color avatarBg;
  final List<String> favoriteIds;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.englishName,
    required this.emoji,
    required this.avatarBg,
    required this.favoriteIds,
  });
}

class CategoryStyle {
  final String label;
  final String emoji;
  final Color color;
  final Color light;
  const CategoryStyle({required this.label, required this.emoji, required this.color, required this.light});
}

const List<String> kCategoryOrder = ['Vegetables', 'Fruits', 'Fresh', 'Drinks', 'Snacks', 'Bakery', 'Meals'];

const Map<String, CategoryStyle> kCategoryStyles = {
  'Vegetables': CategoryStyle(label: 'ผักสด', emoji: '🥦', color: Color(0xFF10B981), light: Color(0xFFD1FAE5)),
  'Fruits': CategoryStyle(label: 'ผลไม้', emoji: '🍎', color: Color(0xFFFF7A59), light: Color(0xFFFFE8E0)),
  'Fresh': CategoryStyle(label: 'เนื้อ / ไข่', emoji: '🥩', color: Color(0xFFE11D48), light: Color(0xFFFFE4E6)),
  'Drinks': CategoryStyle(label: 'เครื่องดื่ม', emoji: '🥤', color: Color(0xFF38BDF8), light: Color(0xFFE0F5FF)),
  'Snacks': CategoryStyle(label: 'ขนม', emoji: '🍿', color: Color(0xFFF5B301), light: Color(0xFFFFF4CC)),
  'Bakery': CategoryStyle(label: 'เบเกอรี่', emoji: '🍰', color: Color(0xFFF472B6), light: Color(0xFFFFE4F1)),
  'Meals': CategoryStyle(label: 'อาหารจานด่วน', emoji: '🍔', color: Color(0xFFFF6B35), light: Color(0xFFFFE5D9)),
};

final List<MarketItem> kAllMarketItems = [
  // Vegetables
  const MarketItem(id: 'pumpkin', name: 'pumpkin', emoji: '🎃', category: 'Vegetables', colorAdjective: 'orange'),
  const MarketItem(id: 'tomato', name: 'tomato', emoji: '🍅', category: 'Vegetables', colorAdjective: 'red'),
  const MarketItem(id: 'carrot', name: 'carrot', emoji: '🥕', category: 'Vegetables', colorAdjective: 'orange'),
  const MarketItem(id: 'broccoli', name: 'broccoli', emoji: '🥦', category: 'Vegetables', colorAdjective: 'green'),
  const MarketItem(id: 'potato', name: 'potato', emoji: '🥔', category: 'Vegetables', colorAdjective: 'yellow'),
  const MarketItem(id: 'cabbage', name: 'cabbage', emoji: '🥬', category: 'Vegetables', colorAdjective: 'green'),
  const MarketItem(id: 'eggplant', name: 'eggplant', emoji: '🍆', category: 'Vegetables', colorAdjective: 'purple'),
  const MarketItem(id: 'corn', name: 'corn cob', emoji: '🌽', category: 'Vegetables', colorAdjective: 'yellow'),
  const MarketItem(id: 'cucumber', name: 'cucumber', emoji: '🥒', category: 'Vegetables', colorAdjective: 'green'),
  const MarketItem(id: 'onion', name: 'onion', emoji: '🧅', category: 'Vegetables', colorAdjective: 'white'),
  const MarketItem(id: 'mushroom', name: 'mushroom', emoji: '🍄', category: 'Vegetables', colorAdjective: 'brown'),
  const MarketItem(id: 'chili', name: 'chili', emoji: '🌶️', category: 'Vegetables', colorAdjective: 'red'),

  // Fruits
  const MarketItem(id: 'banana', name: 'banana', emoji: '🍌', category: 'Fruits', colorAdjective: 'yellow'),
  const MarketItem(id: 'red_apple', name: 'red apple', emoji: '🍎', category: 'Fruits', colorAdjective: 'red'),
  const MarketItem(id: 'green_apple', name: 'green apple', emoji: '🍏', category: 'Fruits', colorAdjective: 'green'),
  const MarketItem(id: 'orange', name: 'orange', emoji: '🍊', category: 'Fruits', colorAdjective: 'orange'),
  const MarketItem(id: 'watermelon', name: 'watermelon', emoji: '🍉', category: 'Fruits', colorAdjective: 'big'),
  const MarketItem(id: 'strawberry', name: 'strawberry', emoji: '🍓', category: 'Fruits', colorAdjective: 'red'),
  const MarketItem(id: 'grapes', name: 'grapes', emoji: '🍇', category: 'Fruits', quantifier: 'bunch of', countable: false),
  const MarketItem(id: 'lemon', name: 'lemon', emoji: '🍋', category: 'Fruits', colorAdjective: 'yellow'),
  const MarketItem(id: 'peach', name: 'peach', emoji: '🍑', category: 'Fruits', colorAdjective: 'pink'),
  const MarketItem(id: 'pineapple', name: 'pineapple', emoji: '🍍', category: 'Fruits', colorAdjective: 'yellow'),
  const MarketItem(id: 'cherry', name: 'cherry', emoji: '🍒', category: 'Fruits', colorAdjective: 'red'),
  const MarketItem(id: 'kiwi', name: 'kiwi', emoji: '🥝', category: 'Fruits', colorAdjective: 'green'),

  // Fresh & Meat
  const MarketItem(id: 'egg', name: 'egg', emoji: '🥚', category: 'Fresh', quantifier: 'box of', quantName: 'eggs'),
  const MarketItem(id: 'cheese', name: 'cheese', emoji: '🧀', category: 'Fresh', quantifier: 'slice of', countable: false),
  const MarketItem(id: 'chicken', name: 'chicken', emoji: '🍗', category: 'Fresh'),
  const MarketItem(id: 'fish', name: 'fish', emoji: '🐟', category: 'Fresh', colorAdjective: 'silver'),
  const MarketItem(id: 'bacon', name: 'bacon', emoji: '🥓', category: 'Fresh', quantifier: 'slice of', countable: false),
  const MarketItem(id: 'shrimp', name: 'shrimp', emoji: '🦐', category: 'Fresh', colorAdjective: 'pink'),

  // Drinks
  const MarketItem(id: 'milk', name: 'milk', emoji: '🥛', category: 'Drinks', quantifier: 'bottle of', countable: false),
  const MarketItem(id: 'soda', name: 'soda', emoji: '🥤', category: 'Drinks', quantifier: 'can of'),
  const MarketItem(id: 'juice', name: 'juice', emoji: '🧃', category: 'Drinks', quantifier: 'box of', countable: false),
  const MarketItem(id: 'water', name: 'water', emoji: '💧', category: 'Drinks', quantifier: 'bottle of', countable: false),
  const MarketItem(id: 'coffee', name: 'coffee', emoji: '☕', category: 'Drinks', quantifier: 'cup of', countable: false),
  const MarketItem(id: 'tea', name: 'tea', emoji: '🍵', category: 'Drinks', quantifier: 'cup of', countable: false),

  // Snacks
  const MarketItem(id: 'chips', name: 'chips', emoji: '🍿', category: 'Snacks', quantifier: 'bag of', countable: false),
  const MarketItem(id: 'cookies', name: 'cookie', emoji: '🍪', category: 'Snacks', quantifier: 'box of', quantName: 'cookies'),
  const MarketItem(id: 'candy', name: 'candy', emoji: '🍬', category: 'Snacks', quantifier: 'bag of', countable: false),
  const MarketItem(id: 'ice_cream', name: 'ice cream', emoji: '🍦', category: 'Snacks', quantifier: 'scoop of', countable: false),
  const MarketItem(id: 'chocolate', name: 'chocolate', emoji: '🍫', category: 'Snacks', quantifier: 'bar of', countable: false),
  const MarketItem(id: 'pretzel', name: 'pretzel', emoji: '🥨', category: 'Snacks', quantifier: 'bag of', quantName: 'pretzels', countable: false),
  const MarketItem(id: 'lollipop', name: 'lollipop', emoji: '🍭', category: 'Snacks', colorAdjective: 'pink'),

  // Bakery
  const MarketItem(id: 'bread', name: 'bread', emoji: '🍞', category: 'Bakery', quantifier: 'loaf of', countable: false),
  const MarketItem(id: 'donut', name: 'donut', emoji: '🍩', category: 'Bakery', colorAdjective: 'sweet'),
  const MarketItem(id: 'cake', name: 'cake', emoji: '🍰', category: 'Bakery', colorAdjective: 'sweet'),
  const MarketItem(id: 'croissant', name: 'croissant', emoji: '🥐', category: 'Bakery', colorAdjective: 'golden'),
  const MarketItem(id: 'cupcake', name: 'cupcake', emoji: '🧁', category: 'Bakery', colorAdjective: 'pink'),
  const MarketItem(id: 'pie', name: 'pie', emoji: '🥧', category: 'Bakery', quantifier: 'slice of'),

  // Meals
  const MarketItem(id: 'burger', name: 'burger', emoji: '🍔', category: 'Meals', colorAdjective: 'big'),
  const MarketItem(id: 'pizza', name: 'pizza', emoji: '🍕', category: 'Meals', quantifier: 'slice of'),
  const MarketItem(id: 'hotdog', name: 'hot dog', emoji: '🌭', category: 'Meals', colorAdjective: 'hot'),
  const MarketItem(id: 'fries', name: 'fries', emoji: '🍟', category: 'Meals', quantifier: 'bag of', countable: false),
  const MarketItem(id: 'taco', name: 'taco', emoji: '🌮', category: 'Meals', colorAdjective: 'tasty'),
  const MarketItem(id: 'sandwich', name: 'sandwich', emoji: '🥪', category: 'Meals', colorAdjective: 'fresh'),
];

MarketItem _itemById(String id) => kAllMarketItems.firstWhere((i) => i.id == id);

int collectedCount() => kAllMarketItems.where((i) => (gameProgress.remainingItems[i.id] ?? 0) > 0).length;

const List<CustomerModel> kCustomerList = [
  CustomerModel(
    id: 'lady',
    name: 'คุณผู้หญิง',
    englishName: 'Miss Rose',
    emoji: '👩',
    avatarBg: Color(0xFFFBCFE8),
    favoriteIds: ['pumpkin', 'tomato', 'carrot'],
  ),
  CustomerModel(
    id: 'farmer',
    name: 'คุณลุงชาวนา',
    englishName: 'Farmer George',
    emoji: '👨‍🌾',
    avatarBg: Color(0xFFFEF08A),
    favoriteIds: ['corn', 'broccoli', 'watermelon'],
  ),
  CustomerModel(
    id: 'police',
    name: 'คุณตำรวจ',
    englishName: 'Officer Sam',
    emoji: '👮‍♂️',
    avatarBg: Color(0xFFBFDBFE),
    favoriteIds: ['donut', 'milk', 'chicken'],
  ),
  CustomerModel(
    id: 'doctor',
    name: 'คุณหมอ',
    englishName: 'Doctor Amy',
    emoji: '👩‍⚕️',
    avatarBg: Color(0xFFBBF7D0),
    favoriteIds: ['green_apple', 'juice', 'cucumber'],
  ),
  CustomerModel(
    id: 'chef',
    name: 'เชฟใหญ่',
    englishName: 'Chef Leo',
    emoji: '🧑‍🍳',
    avatarBg: Color(0xFFFED7AA),
    favoriteIds: ['egg', 'cheese', 'fish'],
  ),
  CustomerModel(
    id: 'astronaut',
    name: 'นักบินอวกาศ',
    englishName: 'Captain Luna',
    emoji: '🧑‍🚀',
    avatarBg: Color(0xFFDDD6FE),
    favoriteIds: ['ice_cream', 'pineapple', 'pizza'],
  ),
  CustomerModel(
    id: 'wizard',
    name: 'พ่อมดใจดี',
    englishName: 'Wizard Wally',
    emoji: '🧙',
    avatarBg: Color(0xFFC7D2FE),
    favoriteIds: ['mushroom', 'pie', 'coffee'],
  ),
];

// ==========================================
// โลกทั้ง 5 (โลกละ 10 ด่าน, ด่านที่ 10 = BOSS)
// ==========================================
class WorldStyle {
  final String name;
  final String subtitle;
  final String emoji;
  final Color color;
  final Color dark;
  final Color light;
  const WorldStyle({
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.dark,
    required this.light,
  });
}

const List<WorldStyle> kWorlds = [
  WorldStyle(
    name: 'ตลาดสดใส',
    subtitle: 'ฟังแล้วหยิบสินค้าให้ถูก',
    emoji: '🥬',
    color: Color(0xFF22C55E),
    dark: Color(0xFF15803D),
    light: Color(0xFFDCFCE7),
  ),
  WorldStyle(
    name: 'ซอยสายรุ้ง',
    subtitle: 'ฟังสีของสินค้า เช่น red apple',
    emoji: '🌈',
    color: Color(0xFFF472B6),
    dark: Color(0xFFBE185D),
    light: Color(0xFFFFE4F1),
  ),
  WorldStyle(
    name: 'ซูเปอร์ลดราคา',
    subtitle: 'ฟังหน่วยนับ เช่น bottle of milk',
    emoji: '🛒',
    color: Color(0xFFFF8A3D),
    dark: Color(0xFFC2560F),
    light: Color(0xFFFFEAD6),
  ),
  WorldStyle(
    name: 'หูทิพย์',
    subtitle: 'ข้อความถูกซ่อน ต้องตั้งใจฟัง !',
    emoji: '🎧',
    color: Color(0xFF3B82F6),
    dark: Color(0xFF1D4ED8),
    light: Color(0xFFDBEAFE),
  ),
  WorldStyle(
    name: 'ราชาตลาด',
    subtitle: 'ออเดอร์ยาว เวลาน้อย สุดท้าทาย !',
    emoji: '👑',
    color: Color(0xFF8B5CF6),
    dark: Color(0xFF6D28D9),
    light: Color(0xFFEDE9FE),
  ),
];

int worldIndexOf(int level) => min(kWorldCount - 1, max(0, (level - 1) ~/ kLevelsPerWorld));

WorldStyle worldOf(int level) => kWorlds[worldIndexOf(level)];

bool isBossLevel(int level) => level % kLevelsPerWorld == 0;

// ==========================================
// Level configuration (28 ด่าน ยากขึ้นเรื่อยๆ)
//   โลก 1 (1-10)  : พูดชื่อสินค้าตรงๆ       one tomato
//   โลก 2 (11-20) : เพิ่มสี                 a red apple
//   โลก 3 (21-30) : เพิ่มหน่วยนับ           a bottle of milk
//   โลก 4 (31-40) : ผสมทุกแบบ + ซ่อนข้อความ
//   โลก 5 (41-50) : ออเดอร์ยาว เวลาน้อย
// ==========================================
class LevelConfig {
  final int level;
  final int world;
  final bool isBoss;
  final int customers;
  final int itemsPerOrder;
  final int maxCount;
  final OrderStyle style;
  final Set<String> categories;
  final double seconds;
  final bool showIcons;
  final bool hideText;

  const LevelConfig({
    required this.level,
    required this.world,
    required this.isBoss,
    required this.customers,
    required this.itemsPerOrder,
    required this.maxCount,
    required this.style,
    required this.categories,
    required this.seconds,
    required this.showIcons,
    required this.hideText,
  });

  factory LevelConfig.forLevel(int n) {
    final int world = worldIndexOf(n);
    final int step = (n - 1) % kLevelsPerWorld; // 0..6
    final bool boss = isBossLevel(n);

    final cats = <String>{'Vegetables', 'Fruits'};
    if (n >= 2) cats.add('Drinks');
    if (n >= 3) cats.add('Snacks');
    if (n >= 4) cats.add('Bakery');
    if (n >= 5) cats.add('Fresh');
    if (n >= 7) cats.add('Meals');

    int items;
    switch (world) {
      case 0:
        items = step < 3 ? 1 : 2;
        break;
      case 1:
        items = step < 4 ? 2 : 3;
        break;
      case 2:
        items = step < 3 ? 2 : 3;
        break;
      case 3:
        items = boss ? 4 : 3;
        break;
      default:
        items = step < 3 ? 3 : 4;
    }

    final OrderStyle style = n <= 7
        ? OrderStyle.plain
        : (n <= 14 ? OrderStyle.colorful : (n <= 21 ? OrderStyle.quantity : OrderStyle.mixed));

    final int maxCount = n < 3 ? 2 : (n < 15 ? 3 : 4);

    // เวลารอของลูกค้า: ค่อยๆ ลดจาก x1.5 (ด่าน 1) เหลือ x0.85 (ด่านสุดท้าย) บวกเวลาตามจำนวนสินค้า
    final double factor = 1.5 - (n - 1) * (0.65 / (kTotalLevels - 1));
    final double seconds = (24.0 + 9.0 * items) * factor * (boss ? 0.92 : 1.0);

    return LevelConfig(
      level: n,
      world: world,
      isBoss: boss,
      customers: 4 + n ~/ 4 + (boss ? 2 : 0), // same formula on the server
      itemsPerOrder: items,
      maxCount: maxCount,
      style: style,
      categories: cats,
      seconds: seconds,
      showIcons: n <= 5,
      hideText: n >= 18,
    );
  }
}

// ==========================================
// Shared dialog shell
// ==========================================
Widget appDialogShell({required Color borderColor, required Widget child, bool lockBack = false}) {
  final Widget dialog = Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, lighten(borderColor, 0.88)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor, width: 5),
        boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 8), blurRadius: 16)],
      ),
      child: SingleChildScrollView(child: child),
    ),
  );
  // กันปุ่ม Back ปิดหน้าต่างผลลัพธ์แล้วหน้าจอค้าง
  return lockBack ? PopScope(canPop: false, child: dialog) : dialog;
}

// ==========================================
// Level Select Screen (5 โลก x 10 ด่าน)
// ==========================================
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  bool _opening = false; // a level is being opened (no double taps)
  final ScrollController _scroll = ScrollController();
  static const int _perRow = 4;
  static const int _rowCount = (kTotalLevels + _perRow - 1) ~/ _perRow;
  final List<GlobalKey> _rowKeys = List.generate(_rowCount, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCurrent(animate: false);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// เลื่อนไปยังแถวของด่านที่กำลังเล่นอยู่
  void _scrollToCurrent({bool animate = true}) {
    final int row = (gameProgress.nextLevel - 1) ~/ _perRow;
    final ctx = _rowKeys[row].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: animate ? const Duration(milliseconds: 500) : Duration.zero,
      curve: Curves.easeOutCubic,
      alignment: 0.3,
    );
  }

  /// ด่าน 1–28 ต่อกันเป็นทางเดียว (แถวคู่ไปทางขวา แถวคี่ย้อนกลับทางซ้าย)
  Widget _levelPath(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9D8AE), width: 4),
        boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 6), blurRadius: 12)],
      ),
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 20),
      child: LayoutBuilder(builder: (context, b) {
        const double gap = 8;
        const double rowGap = 24;
        final double cw = (b.maxWidth - gap * (_perRow - 1)) / _perRow;
        final double ch = cw * 1.2;
        return SizedBox(
          height: ch * _rowCount + rowGap * (_rowCount - 1),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoutePainter(cellW: cw, cellH: ch, gap: gap, rowGap: rowGap, rows: _rowCount, perRow: _perRow),
                ),
              ),
              for (int r = 0; r < _rowCount; r++)
                Positioned(
                  key: _rowKeys[r],
                  left: 0,
                  top: r * (ch + rowGap),
                  width: 1,
                  height: ch,
                  child: const SizedBox.shrink(),
                ),
              for (int i = 0; i < kTotalLevels; i++)
                Positioned(
                  left: ((i ~/ _perRow).isEven ? i % _perRow : _perRow - 1 - i % _perRow) * (cw + gap),
                  top: (i ~/ _perRow) * (ch + rowGap),
                  width: cw,
                  height: ch,
                  child: _tile(context, i + 1, worldOf(i + 1), cw, ch),
                ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _play(BuildContext context, int level) async {
    if (_opening) return;
    _opening = true;
    try {
      final int customers = LevelConfig.forLevel(level).customers;
      MarketRound? resume = await MarketResume.load(level, customers: customers);
      if (resume != null) {
        if (!context.mounted) return;
        final bool? goOn = await _askMarketResume(context, level, resume, customers);
        if (goOn == null) return;
        if (!goOn) {
          await MarketResume.clear(level);
          gameProgress.markUnfinished(level, false);
          resume = null;
        }
      }
      if (!context.mounted) return;
      final MarketRound? start = resume;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => MarketGameScreen(level: level, resume: start)));
    } finally {
      _opening = false;
    }
    if (mounted) _scrollToCurrent();
  }

  void _showLocked(BuildContext context, int level) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1600),
          content: Text('🔒 ผ่านด่าน ${level - 1} ก่อนนะ แล้วจะปลดล็อกด่านนี้ !'),
        ),
      );
  }

  void _openSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => appDialogShell(
        borderColor: AppColors.purple,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ตั้งค่า',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.purpleDark)),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: gameProgress,
              builder: (context, _) => Column(
                children: [
                  _statRow('ดาวที่สะสม', '${gameProgress.totalStars} / ${kTotalLevels * 3}'),
                  _statRow('ด่านที่ผ่านแล้ว', '${gameProgress.clearedLevels} / $kTotalLevels'),
                  _statRow('สติกเกอร์ที่สะสม', '${collectedCount()} / ${kAllMarketItems.length}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ChunkyButton(
                color: AppColors.red,
                shadowColor: AppColors.redDark,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(ctx);
                  Navigator.pop(ctx);
                  // ลบความคืบหน้าของเด็กได้เฉพาะผู้ปกครอง
                  final allowed = await showParentPinPrompt(context, title: 'ผู้ปกครองยืนยันก่อนรีเซ็ต');
                  if (!allowed) return;
                  await gameProgress.reset();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('รีเซ็ตความคืบหน้าเรียบร้อยแล้ว')),
                  );
                },
                child: const Text('รีเซ็ตความคืบหน้าทั้งหมด (ใช้ PIN ผู้ปกครอง)'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ChunkyButton(
                color: AppColors.blue,
                shadowColor: AppColors.blueDark,
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ปิด'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.purpleDark, fontSize: 16)),
        ],
      ),
    );
  }

  // ============================================================
  // UI สไตล์ "ตลาดไม้" : ป้ายไม้แขวน กันสาด ลังผลไม้ แผงขายของ
  // ============================================================
  static const Color _wood = Color(0xFF8B5A2B);
  static const Color _woodDark = Color(0xFF5B3A1E);
  static const Color _brass = Color(0xFFE0A526);
  static const Color _cream = Color(0xFFFFF6E3);

  // ผลไม้/ของที่โชว์บนลังของแต่ละด่าน (โลกละ 10 ด่าน)
  static const List<List<String>> _crateFruit = [
    ['🍎', '🥕', '🍓', '🍇', '🍅', '🥬', '🍊', '🍋', '🥒', '🍆'],
    ['🍓', '🍊', '🍋', '🥬', '🍇', '🍆', '🍑', '🍎', '🥕', '🌈'],
    ['🥛', '🧃', '🥫', '🍞', '🧀', '🥚', '🍯', '🍪', '🍫', '🛒'],
    ['🍎', '🍌', '🥕', '🍇', '🍓', '🍞', '🥛', '🧀', '🍊', '🎧'],
    ['🍉', '🍍', '🥭', '🍒', '🥝', '🍐', '🍑', '🥥', '🍋', '👑'],
  ];

  // ---------- ป้ายชื่อเกม: ป้ายไม้แขวน + กันสาด + ริบบิ้น ----------
  // ignore: unused_element
  Widget _buildHeaderSign() {
    return SizedBox(
      height: 84,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // กันสาดลายทาง
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 38,
            child: CustomPaint(painter: _AwningPainter()),
          ),
          // ริบบิ้น Supermarket Order Up!
          Positioned(
            top: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF58897A), Color(0xFF3E6B5C)],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE9D8AE), width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x55000000), offset: Offset(0, 4), blurRadius: 5),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _Bobbing(dy: 3, child: Text('🧺', style: TextStyle(fontSize: 24))),
                  SizedBox(width: 6),
                  Text(
                    'Supermarket Order Up!',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFF6DA),
                      shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2))],
                    ),
                  ),
                  SizedBox(width: 4),
                  _Bobbing(dy: 3, child: Text('🔔', style: TextStyle(fontSize: 20))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- แคปซูลสถิติ ----------
  BoxDecoration _goldPillDeco() => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8DD), Color(0xFFFFE9A8)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _brass, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 3), blurRadius: 3)],
      );

  Widget _starPill() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _goldPillDeco(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 24),
          const SizedBox(width: 4),
          Text('${gameProgress.totalStars}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _woodDark)),
        ],
      ),
    );
  }

  Widget _progressPill() {
    final int cleared = gameProgress.clearedLevels;
    final double frac = (cleared / kTotalLevels).clamp(0.0, 1.0).toDouble();
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FD),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF9CC3E6), width: 3),
        boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 3), blurRadius: 3)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: frac),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: max(v, 0.2),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF7CC0F5), Color(0xFF3B82F6)]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('$cleared / $kTotalLevels',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x88000000), offset: Offset(0, 1.5))],
                  )),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- ลังไม้ 1 ด่าน ----------
  Widget _tile(BuildContext context, int level, WorldStyle world, double w, double h) {
    final bool unlocked = gameProgress.isUnlocked(level);
    final int stars = gameProgress.stars[level - 1];
    final bool isCurrent = unlocked && level == gameProgress.nextLevel;
    final bool boss = isBossLevel(level);
    final String fruit = _crateFruit[worldIndexOf(level)][(level - 1) % kLevelsPerWorld];

    final double boxTop = h * 0.27;
    final List<Color> woodGrad = unlocked
        ? const [Color(0xFFDDA766), Color(0xFFB07A44)]
        : const [Color(0xFFB9A084), Color(0xFF8E7559)];

    const List<Shadow> outline = [
      Shadow(color: Color(0xFF5A3410), offset: Offset(1.6, 1.6)),
      Shadow(color: Color(0xFF5A3410), offset: Offset(-1.6, 1.6)),
      Shadow(color: Color(0xFF5A3410), offset: Offset(1.6, -1.6)),
      Shadow(color: Color(0xFF5A3410), offset: Offset(-1.6, -1.6)),
      Shadow(color: Color(0x66000000), offset: Offset(0, 3), blurRadius: 2),
    ];

    Widget inner;
    if (!unlocked) {
      inner = Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _ChainPainter(inset: 0.0))),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DAE3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6B7280), width: 1.5),
                ),
                child: const Icon(Icons.lock_rounded, color: Color(0xFF4B5563), size: 17),
              ),
              const SizedBox(height: 2),
              Text('$level',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0xAA000000), offset: Offset(0, 1.5))],
                  )),
            ],
          ),
        ],
      );
    } else {
      inner = Column(
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$level',
                    style: TextStyle(
                      fontSize: w * 0.44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                      shadows: outline,
                    )),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            height: 17,
            decoration: BoxDecoration(
              color: const Color(0xFF8A5A2B),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF6B4220), width: 1),
            ),
            child: isCurrent && stars == 0
                ? null
                : Center(child: StarRow(count: stars, size: 12)),
          ),
        ],
      );
    }

    final Widget box = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: woodGrad),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: unlocked ? const Color(0xFF7A4B22) : const Color(0xFF6E5A47), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 3), blurRadius: 4)],
      ),
      child: CustomPaint(painter: const _PlankPainter(), child: inner),
    );

    final List<Widget> kids = [];
    // ผลไม้กองอยู่บนลัง (ลังที่ล็อกอยู่จะว่างเปล่า)
    if (unlocked) {
      kids.add(Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: boxTop + 10,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomCenter,
          child: Text('$fruit$fruit$fruit', style: TextStyle(fontSize: w * 0.3, letterSpacing: -w * 0.08)),
        ),
      ));
    }
    kids.add(Positioned(top: boxTop, left: 0, right: 0, bottom: 0, child: box));

    // ด่านปัจจุบัน: แผงขายของมีกันสาด + ป้ายเลข + ปุ่ม "เล่น!" + มือชี้
    if (isCurrent) {
      kids.add(Positioned(
        top: boxTop - 16,
        left: -4,
        right: -4,
        height: 26,
        child: const CustomPaint(painter: _MiniAwningPainter()),
      ));
      kids.add(Positioned(
        top: boxTop - 36,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A3D),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text('$level',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
      ));
      kids.add(Positioned(
        left: 1,
        right: 1,
        bottom: -7,
        height: 25,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFA24D), Color(0xFFF2650C)],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFFFE0BF), width: 2),
            boxShadow: const [BoxShadow(color: Color(0xFFB4470A), offset: Offset(0, 3))],
          ),
          child: const Text('เล่น',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 1.5))])),
        ),
      ));
      kids.add(const Positioned(
        right: -14,
        bottom: -18,
        child: _Bobbing(dy: 0, child: Text('', style: TextStyle(fontSize: 26))),
      ));
    }
    if (boss) {
      kids.add(Positioned(
        top: boxTop - 16,
        right: -9,
        child: Transform.rotate(
          angle: 0.4,
          child: Opacity(opacity: unlocked ? 1 : 0.85, child: const Text('', style: TextStyle(fontSize: 22))),
        ),
      ));
    }

    if (unlocked && gameProgress.unfinished.contains(level)) {
      kids.add(Positioned(
        top: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.orangeDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: const Text('▶ ต่อ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ));
    }
    Widget tile = Stack(clipBehavior: Clip.none, children: kids);
    if (isCurrent) tile = Pulse(amount: 0.05, child: tile);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: unlocked ? () => _play(context, level) : () => _showLocked(context, level),
      child: tile,
    );
  }

  // ---------- การ์ดโลก ----------
  Widget _bookButton() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionScreen())),
      child: SizedBox(
        width: 66,
        height: 66,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 54,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFC0623A), Color(0xFF8E3B1E)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF0C77A), width: 2.5),
                  boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 4), blurRadius: 4)],
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFFFFE6A8), size: 28),
              ),
            ),
            Positioned(
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _wood, width: 1.5),
                ),
                child: Text('${collectedCount()} / ${kAllMarketItems.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _woodDark)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF1DD),
      body: _GameScaffoldBody(
        title: 'มินิมาร์เก็ต',
        color: const Color(0xFFF5B000),
        showBack: true,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _DiamondBgPainter())),
            SafeArea(
              child: AnimatedBuilder(
                animation: gameProgress,
                builder: (context, _) {
                  final int next = gameProgress.nextLevel;
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                        child: Row(
                          children: [
                            _starPill(),
                            const SizedBox(width: 8),
                            Expanded(child: _progressPill()),
                            const SizedBox(width: 8),
                            const _CoinPill(color: AppColors.orangeDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scroll,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
                          child: _levelPath(context),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFFBEF), Color(0xFFFFEFC8)],
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                          border: const Border(top: BorderSide(color: Color(0xFFF0C77A), width: 3)),
                          boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, -3), blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            _bookButton(),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Pulse(
                                amount: 0.03,
                                child: ChunkyButton(
                                  color: AppColors.green,
                                  shadowColor: AppColors.greenDark,
                                  radius: 30,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  onPressed: () => _play(context, next),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                        child: const Icon(Icons.play_arrow_rounded, color: AppColors.green, size: 26),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('เล่นด่าน $next',
                                          style: const TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2))])),
                                      const SizedBox(width: 6),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ChunkyButton(
                              color: AppColors.blue,
                              shadowColor: AppColors.blueDark,
                              radius: 20,
                              padding: const EdgeInsets.all(12),
                              onPressed: () => _openSettings(context),
                              child: const Icon(Icons.settings_rounded, color: Colors.white, size: 28),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- ตัวช่วยวาด ----------------

// พื้นหลังลายเพชรสีครีม
class _DiamondBgPainter extends CustomPainter {
  const _DiamondBgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = const Color(0xFFF4E4C4).withAlpha(150);
    const double s = 46;
    for (int j = -1; j * s / 2 < size.height + s; j++) {
      for (int i = -1; i * s / 2 < size.width + s; i++) {
        if ((i + j).isOdd || i.isOdd) continue;
        final double cx = i * s / 2;
        final double cy = j * s / 2;
        canvas.drawPath(
          Path()
            ..moveTo(cx, cy - s / 2)
            ..lineTo(cx + s / 2, cy)
            ..lineTo(cx, cy + s / 2)
            ..lineTo(cx - s / 2, cy)
            ..close(),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// เส้นประเชื่อมลังด่าน
class _RoutePainter extends CustomPainter {
  final double cellW, cellH, gap, rowGap;
  final int rows;
  final int perRow;
  const _RoutePainter({
    required this.cellW,
    required this.cellH,
    required this.gap,
    required this.rowGap,
    required this.rows,
    required this.perRow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double x0 = cellW / 2;
    final double x4 = (perRow - 1) * (cellW + gap) + cellW / 2;
    final Path path = Path();
    for (int r = 0; r < rows; r++) {
      final double y = r * (cellH + rowGap) + cellH * 0.74;
      path
        ..moveTo(x0, y)
        ..lineTo(x4, y);
      if (r < rows - 1) {
        // ทางลงไปแถวถัดไป: ด้านขวาสำหรับแถวคู่ ด้านซ้ายสำหรับแถวคี่
        final double x = r.isEven ? x4 : x0;
        path
          ..moveTo(x, y)
          ..lineTo(x, y + cellH + rowGap);
      }
    }
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = const Color(0xFFD9C197);
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, min(d + 7, m.length)), p);
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.cellW != cellW || old.cellH != cellH || old.rows != rows;
}

// เส้นไม้ในลัง + หัวตะปู
class _PlankPainter extends CustomPainter {
  const _PlankPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = const Color(0xFF6B4220).withAlpha(70)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(4, size.height * 0.34), Offset(size.width - 4, size.height * 0.34), line);
    canvas.drawLine(Offset(4, size.height * 0.68), Offset(size.width - 4, size.height * 0.68), line);
    final Paint nail = Paint()..color = const Color(0xFF5A3410).withAlpha(150);
    for (final o in [
      const Offset(4.5, 4.5),
      Offset(size.width - 4.5, 4.5),
    ]) {
      canvas.drawCircle(o, 1.5, nail);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// กันสาดเล็กของแผงขายของ (ด่านปัจจุบัน)
class _MiniAwningPainter extends CustomPainter {
  const _MiniAwningPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const int n = 5;
    final double sw = size.width / n;
    final double r = sw / 2;
    final double bodyH = max(0.0, size.height - r);
    for (int pass = 0; pass < 2; pass++) {
      for (int i = 0; i < n; i++) {
        final Paint p = Paint()
          ..color = pass == 0 ? const Color(0x44000000) : (i.isEven ? const Color(0xFFFF8A3D) : const Color(0xFFFFF8E7));
        final double dy = pass == 0 ? 2.5 : 0;
        canvas.drawRect(Rect.fromLTWH(i * sw, dy, sw + 0.5, bodyH), p);
        canvas.drawArc(Rect.fromLTWH(i * sw, bodyH - r + dy, sw, sw), 0, pi, true, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// โซ่พาดทแยง
class _ChainPainter extends CustomPainter {
  final double inset;
  final bool big;
  const _ChainPainter({
    this.inset = 0,
    // ignore: unused_element_parameter
    this.big = false,
  });

  void _chain(Canvas canvas, Offset a, Offset b) {
    final double len = (b - a).distance;
    final double step = big ? 12 : 7;
    final double ang = atan2(b.dy - a.dy, b.dx - a.dx);
    final int n = (len / step).floor();
    final Paint fill = Paint()..color = const Color(0xFFC5CBD6);
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = big ? 2 : 1.3
      ..color = const Color(0xFF5B6372);
    final double lw = big ? 14 : 9;
    final double lh = big ? 8 : 5;
    for (int i = 0; i <= n; i++) {
      final Offset c = Offset.lerp(a, b, i / max(1, n))!;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(ang);
      final Rect r = i.isEven
          ? Rect.fromCenter(center: Offset.zero, width: lw, height: lh)
          : Rect.fromCenter(center: Offset.zero, width: lw * 0.7, height: lh * 0.8);
      final RRect rr = RRect.fromRectAndRadius(r, Radius.circular(lh / 2));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, edge);
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    if (big) {
      final Offset c = Offset(w / 2, h * 0.5);
      for (final o in [
        Offset(w * inset, h * 0.12),
        Offset(w * (1 - inset), h * 0.12),
        Offset(w * inset, h * 0.88),
        Offset(w * (1 - inset), h * 0.88),
      ]) {
        _chain(canvas, o, c);
      }
    } else {
      _chain(canvas, Offset(3, 3), Offset(w - 3, h - 3));
      _chain(canvas, Offset(w - 3, 3), Offset(3, h - 3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ตัวช่วย: ลอยขึ้นลงเบาๆ (ใช้กับอีโมจิ/มาสคอต)
class _Bobbing extends StatefulWidget {
  final Widget child;
  final double dy;
  const _Bobbing({required this.child, this.dy = 4});

  @override
  State<_Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<_Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dy == 0) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -widget.dy * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
    );
  }
}

// กันสาดร้านค้าลายทางส้ม-ครีม ขอบหยัก
class _AwningPainter extends CustomPainter {
  const _AwningPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const int n = 11;
    final double sw = size.width / n;
    final double r = sw / 2;
    final double bodyH = max(0.0, size.height - r - 3);
    for (int pass = 0; pass < 2; pass++) {
      for (int i = 0; i < n; i++) {
        final Paint p = Paint()
          ..color = pass == 0
              ? const Color(0x33000000)
              : (i.isEven ? const Color(0xFFFF8A3D) : const Color(0xFFFFF8E7));
        final double dy = pass == 0 ? 3 : 0;
        canvas.drawRect(Rect.fromLTWH(i * sw, dy, sw + 0.5, bodyH), p);
        canvas.drawArc(Rect.fromLTWH(i * sw, bodyH - r + dy, sw, sw), 0, pi, true, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// Main Gameplay Screen
// ==========================================

// ignore: unused_element
class _FloorPainter extends CustomPainter {
  final Color a;
  final Color b;
  const _FloorPainter(this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    const double s = 22;
    final pa = Paint()..color = a;
    final pb = Paint()..color = b;
    final cols = (size.width / s).ceil();
    final rows = (size.height / s).ceil();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        canvas.drawRect(Rect.fromLTWH(c * s, r * s, s, s), (r + c).isEven ? pa : pb);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FloorPainter old) => old.a != a || old.b != b;
}

/// "ด่าน 3 เล่นค้างไว้ … เล่นต่อ / เริ่มใหม่": true = go on, false = start again.
Future<bool?> _askMarketResume(BuildContext context, int level, MarketRound r, int customers) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => appDialogShell(
      borderColor: AppColors.orange,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ด่าน $level เล่นค้างไว้',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.orangeDark)),
          const SizedBox(height: 8),
          Text(
            'บริการลูกค้าไปแล้ว ${r.served} / $customers คน\nจะเล่นต่อเลยไหม ?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ChunkyButton(
              color: AppColors.green,
              shadowColor: AppColors.greenDark,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('เล่นต่อ'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ChunkyButton(
              color: AppColors.orange,
              shadowColor: AppColors.orangeDark,
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('เริ่มใหม่'),
            ),
          ),
        ],
      ),
    ),
  );
}

class MarketGameScreen extends StatefulWidget {
  final int level;

  /// The level left in the middle, to continue (null = start it fresh).
  final MarketRound? resume;

  const MarketGameScreen({super.key, required this.level, this.resume});

  @override
  State<MarketGameScreen> createState() => _MarketGameScreenState();
}

class _MarketGameScreenState extends State<MarketGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final FlutterTts _tts = FlutterTts();
  bool _pausedByApp = false; // customer's patience stopped while the app is away
  bool _askingExit = false; // "ออกจากด่านนี้" is on screen
  VoidCallback? _afterExit; // what was waiting for the answer
  bool _afterExitFinishes = false; // ...and it was the end of the level
  final List<Future<GuessCoinResult>> _levelCoins = []; // real coins earned since the level was opened
  late final Future<void> _ttsInit;

  late final AnimationController _idleCtrl;
  late final AnimationController _walkCtrl;
  late final LevelConfig _cfg;

  // ผลของด่าน
  int _served = 0;
  int _successes = 0;
  int _mistakes = 0;

  // ลูกค้าปัจจุบัน
  CustomerPhase _phase = CustomerPhase.entering;
  CustomerModel _currentCustomer = kCustomerList.first;
  String? _lastCustomerId;
  final Set<String> _seenCustomers = {};
  int _arrivalId = 0;
  String _greeting = '';
  String _spokenText = '';
  List<OrderRequirement> _targetOrder = [];
  bool _textRevealed = false;
  String? _reaction;
  String? _feedback;
  Color _feedbackColor = AppColors.greenDark;

  final Map<String, int> _basket = {};
  bool _orderActive = false;

  // ---- ลูกเล่นเพิ่มความสนุก ----
  String? _praise; // ป้ายชมเชยเด้งๆ บนเคาน์เตอร์
  Timer? _praiseTimer;
  // ignore: unused_field
  final int _confettiSeq = 0;
  // ignore: unused_field
  final bool _showConfetti = false;
  Timer? _confettiTimer;
  bool _hintIcons = false; // เปิดคำใบ้
  int _newCollected = 0; // สติกเกอร์ใหม่ที่ได้ในด่านนี้

  Timer? _patienceTimer;
  double _patienceLevel = 1.0;

  final List<_FloatingCoin> _floatingCoins = [];
  int _floatingCoinSeq = 0;

  late String _selectedCategoryTab;

  List<String> get _availableCategories => kCategoryOrder.where(_cfg.categories.contains).toList();

  @override
  void initState() {
    super.initState();
    _cfg = LevelConfig.forLevel(widget.level);
    _selectedCategoryTab = _availableCategories.first;
    _idleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _walkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
    _ttsInit = _initTts();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startLevel(resume: widget.resume);
    });
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.42);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.1);
    } catch (_) {}
  }

  @override
  void dispose() {
    _patienceTimer?.cancel();
    _praiseTimer?.cancel();
    _confettiTimer?.cancel();
    _idleCtrl.dispose();
    _walkCtrl.dispose();
    _tts.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---------- หยุดเวลาตอนสลับแอป / มีสายเข้า ----------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pausedByApp && mounted && _orderActive && !_askingExit) {
        _pausedByApp = false;
        _startPatienceTimer(); // goes on from the patience that was left
      }
    } else if (_orderActive && _patienceTimer != null && _patienceTimer!.isActive) {
      _patienceTimer?.cancel();
      _pausedByApp = true;
    }
  }

  // ---------- เล่นต่อจากลูกค้าคนถัดไป (แยกตามบัญชี เก็บบนเซิร์ฟเวอร์) ----------
  void _saveResume() {
    MarketResume.save(
      widget.level,
      MarketRound(served: _served, successes: _successes, mistakes: _mistakes, collected: _newCollected),
    );
    gameProgress.markUnfinished(widget.level, true);
  }

  void _clearResume() {
    MarketResume.clear(widget.level);
    gameProgress.markUnfinished(widget.level, false);
  }

  Future<void> _say(String text) async {
    try {
      await _ttsInit;
      if (!mounted) return;
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void _speakOrder({bool withGreeting = false}) {
    if (_spokenText.isEmpty) return;
    _say(withGreeting && _greeting.isNotEmpty ? '$_greeting $_spokenText' : _spokenText);
  }

  void _speakItem(MarketItem item) {
    _say(item.quantifier != null ? '${item.quantifier} ${item.quantName ?? item.name}' : item.name);
  }

  // ---------- ป้ายชม / พลุ ----------
  void _showPraise(String text, {int ms = 1400}) {
    _praiseTimer?.cancel();
    setState(() => _praise = text);
    _praiseTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _praise = null);
    });
  }

  // ปิดเอฟเฟกต์ริบบิ้น/คอนเฟตติ์ตอนส่งของแล้ว
  void _celebrate() {}

  bool get _canHint => _orderActive && !_hintIcons && !_cfg.showIcons;

  // คำใบ้: ดูรูปสินค้าที่ต้องหยิบ + ตัวหนังสือ
  void _useHint() {
    if (!_canHint) return;
    setState(() {
      _hintIcons = true;
      _textRevealed = true;
    });
    _addFloatingCoin('คำใบ้', AppColors.purple);
    _speakOrder();
  }

  // ---------- Floating coins ----------
  void _addFloatingCoin(String text, Color color) {
    final id = _floatingCoinSeq++;
    setState(() => _floatingCoins.add(_FloatingCoin(id: id, text: text, color: color)));
  }

  void _removeFloatingCoin(int id) {
    if (!mounted) return;
    setState(() => _floatingCoins.removeWhere((c) => c.id == id));
  }

  // ==========================================
  // English phrase builders
  // ==========================================
  String _numberToWord(int num) {
    switch (num) {
      case 1:
        return 'one';
      case 2:
        return 'two';
      case 3:
        return 'three';
      case 4:
        return 'four';
      default:
        return '$num';
    }
  }

  String _article(String phrase) => 'aeiou'.contains(phrase[0].toLowerCase()) ? 'an' : 'a';

  String _pluralize(String name, int count) {
    if (count <= 1) return name;
    const irregular = {
      'fish': 'fish',
      'broccoli': 'broccoli',
      'shrimp': 'shrimp',
      'taco': 'tacos',
      'kiwi': 'kiwis',
      'chili': 'chilis',
    };
    final words = name.split(' ');
    final last = words.last;
    String plural;
    if (irregular.containsKey(last)) {
      plural = irregular[last]!;
    } else if (last.endsWith('y') && last.length > 1 && !'aeiou'.contains(last[last.length - 2])) {
      plural = '${last.substring(0, last.length - 1)}ies';
    } else if (last.endsWith('o') || last.endsWith('s') || last.endsWith('ch') || last.endsWith('x')) {
      plural = '${last}es';
    } else {
      plural = '${last}s';
    }
    words[words.length - 1] = plural;
    return words.join(' ');
  }

  String _pluralizeQuantifier(String q) {
    final first = q.split(' ').first;
    final rest = q.substring(first.length);
    String plural;
    if (first == 'loaf') {
      plural = 'loaves';
    } else if (first.endsWith('x') || first.endsWith('ch')) {
      plural = '${first}es';
    } else {
      plural = '${first}s';
    }
    return '$plural$rest';
  }

  String _describe(MarketItem item) {
    final adj = item.colorAdjective;
    if (adj != null && !item.name.contains(adj)) return '$adj ${item.name}';
    return item.name;
  }

  String _phrase(OrderRequirement r) {
    final item = r.item;
    final n = r.count;
    switch (r.style) {
      case OrderStyle.colorful:
        final d = _describe(item);
        return n == 1 ? '${_article(d)} $d' : '${_numberToWord(n)} ${_pluralize(d, n)}';
      case OrderStyle.quantity:
        final q = item.quantifier ?? 'piece of';
        final noun = item.quantName ?? item.name;
        return n == 1 ? '${_article(q)} $q $noun' : '${_numberToWord(n)} ${_pluralizeQuantifier(q)} $noun';
      case OrderStyle.plain:
      case OrderStyle.mixed:
        return '${_numberToWord(n)} ${_pluralize(item.name, n)}';
    }
  }

  String _buildSentence(List<OrderRequirement> reqs) {
    final parts = reqs.map(_phrase).toList();
    final joined = parts.length == 1
        ? parts.first
        : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    return 'I want $joined.';
  }

  // ==========================================
  // Level / customer flow
  // ==========================================
  void _startLevel({MarketRound? resume}) {
    _patienceTimer?.cancel();
    _pausedByApp = false;
    _levelCoins.clear();
    if (resume != null) {
      _served = resume.served;
      _successes = resume.successes;
      _mistakes = resume.mistakes;
      _newCollected = resume.collected;
    } else {
      _served = 0;
      _successes = 0;
      _mistakes = 0;
      _newCollected = 0;
      _clearResume(); // a new game of this level
    }
    _lastCustomerId = null;
    _seenCustomers.clear();
    _spawnCustomer();
    _showPraise(_cfg.isBoss ? 'ด่านบอส' : (resume != null ? 'เปิดร้านต่อ' : 'ร้านเปิดแล้ว'), ms: 1800);
  }

  CustomerModel _pickCustomer(Random r) {
    final others = kCustomerList.where((c) => c.id != _lastCustomerId).toList();
    return others[r.nextInt(others.length)];
  }

  /// เลือกรูปแบบประโยคของสินค้าแต่ละชิ้น (โหมด mixed สลับไปมาได้)
  OrderStyle _styleFor(MarketItem item, Random r) {
    switch (_cfg.style) {
      case OrderStyle.mixed:
        if (!item.countable) return OrderStyle.quantity;
        if (item.quantifier != null && r.nextBool()) return OrderStyle.quantity;
        return OrderStyle.colorful;
      default:
        return _cfg.style;
    }
  }

  void _generateOrder(Random random) {
    final all = kAllMarketItems.where((i) => _cfg.categories.contains(i.category)).toList();
    List<MarketItem> pool;
    switch (_cfg.style) {
      case OrderStyle.quantity:
        pool = all.where((i) => i.quantifier != null).toList();
        break;
      case OrderStyle.mixed:
        pool = all.where((i) => i.countable || i.quantifier != null).toList();
        break;
      default:
        pool = all.where((i) => i.countable).toList();
    }
    if (pool.length < _cfg.itemsPerOrder) pool = all;
    pool.shuffle(random);

    final chosen = <MarketItem>[];
    final favs = pool.where((i) => _currentCustomer.favoriteIds.contains(i.id)).toList();
    if (favs.isNotEmpty && random.nextDouble() < 0.6) {
      chosen.add(favs[random.nextInt(favs.length)]);
    }
    for (final item in pool) {
      if (chosen.length >= _cfg.itemsPerOrder) break;
      if (!chosen.contains(item)) chosen.add(item);
    }

    _targetOrder = chosen
        .map((i) => OrderRequirement(
              item: i,
              count: 1 + random.nextInt(_cfg.maxCount),
              style: _styleFor(i, random),
            ))
        .toList();
    _spokenText = _buildSentence(_targetOrder);
  }

  void _spawnCustomer() {
    final random = Random();
    _patienceTimer?.cancel();
    final token = ++_arrivalId;

    _basket.clear();
    _reaction = null;
    _feedback = null;
    _textRevealed = false;
    _hintIcons = false;
    _orderActive = false;
    _patienceLevel = 1.0;

    _currentCustomer = _pickCustomer(random);
    _lastCustomerId = _currentCustomer.id;
    final returning = _seenCustomers.contains(_currentCustomer.id);
    _seenCustomers.add(_currentCustomer.id);
    _greeting = returning ? 'Hi again!' : 'Hello! I am ${_currentCustomer.englishName}.';
    _generateOrder(random);

    setState(() => _phase = CustomerPhase.entering);
    _walkCtrl.forward(from: 0).then((_) {
      if (!mounted || token != _arrivalId) return;
      _onCustomerArrived();
    });
  }

  void _onCustomerArrived() {
    setState(() {
      _phase = CustomerPhase.waiting;
      _orderActive = true;
    });
    _speakOrder(withGreeting: true);
    _startPatienceTimer();
  }

  void _startPatienceTimer() {
    _patienceTimer?.cancel();
    // A customer who arrives while "ออกจากด่านนี้" is open, or while the app
    // is in the background, waits: the clock starts when the child is back.
    final AppLifecycleState? app = WidgetsBinding.instance.lifecycleState;
    if (_askingExit || (app != null && app != AppLifecycleState.resumed)) {
      _pausedByApp = true;
      return;
    }
    final step = 0.2 / _cfg.seconds;
    _patienceTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || !_orderActive) {
        timer.cancel();
        return;
      }
      final next = max(0.0, _patienceLevel - step);
      setState(() => _patienceLevel = next);
      if (next <= 0.0) {
        timer.cancel();
        _onPatienceTimeout();
      }
    });
  }

  void _sendCustomerAway() {
    final token = _arrivalId;
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || token != _arrivalId) return;
      setState(() {
        _basket.clear();
        _phase = CustomerPhase.leaving;
      });
      _walkCtrl.forward(from: 0).then((_) {
        if (!mounted || token != _arrivalId) return;
        _served++;
        final bool done = _served >= _cfg.customers;
        if (!done) _saveResume();
        void goOn() {
          if (!mounted) return;
          if (done) {
            _finishLevel();
          } else {
            _spawnCustomer();
          }
        }
        // "ออกจากด่านนี้" is open: wait for the answer before the next
        // customer / the result (no dialog on top of the question).
        if (_askingExit) {
          _afterExit = goOn;
          _afterExitFinishes = done;
        } else {
          goOn();
        }
      });
    });
  }

  // ---------- Basket ----------
  void _addItemToBasket(MarketItem item) {
    if (!_orderActive) return;
    setState(() => _basket[item.id] = (_basket[item.id] ?? 0) + 1);
    HapticFeedback.selectionClick();
    _speakItem(item); // แตะแล้วออกเสียงคำศัพท์ให้เด็กฟัง
  }

  // ถังขยะ: ล้างสินค้าในตะกร้าทั้งหมด (กรณีกดผิดหลายชิ้น)
  void _clearBasket() {
    if (!_orderActive || _basket.isEmpty) return;
    setState(() => _basket.clear());
  }

  void _removeItemFromBasket(String itemId) {
    if (!_orderActive || !_basket.containsKey(itemId)) return;
    setState(() {
      if (_basket[itemId]! > 1) {
        _basket[itemId] = _basket[itemId]! - 1;
      } else {
        _basket.remove(itemId);
      }
    });
  }

  bool _isExactMatch() {
    if (_basket.length != _targetOrder.length) return false;
    for (final req in _targetOrder) {
      if ((_basket[req.item.id] ?? 0) != req.count) return false;
    }
    return true;
  }

  void _checkOrder() {
    if (!_orderActive) return;
    if (_isExactMatch()) {
      _onOrderSuccess();
    } else {
      _onOrderMistake();
    }
  }

  void _onOrderSuccess() {
    _patienceTimer?.cancel();
    _orderActive = false;
    _successes++;

    final bool fav = _targetOrder.any((r) => _currentCustomer.favoriteIds.contains(r.item.id));
    final List<MarketItem> newItems =
        _targetOrder.map((r) => r.item).where((i) => (gameProgress.remainingItems[i.id] ?? 0) <= 0).toList();
    gameProgress.recordDelivery(
      items: {for (final req in _targetOrder) req.item.id: req.count},
    );
    // Real coins: 2 per item per day (from the server).
    final coins = [for (final req in _targetOrder) MarketCoins.submit(req.item.id)];
    _levelCoins.addAll(coins);
    Future.wait(coins).then((list) {
      final got = list.fold<int>(0, (s, r) => s + r.coins);
      if (mounted && got > 0) _addFloatingCoin('+$got เหรียญ', AppColors.orange);
    });
    if (newItems.isNotEmpty) {
      _newCollected += newItems.length;
      _addFloatingCoin('สติกเกอร์ใหม่ ${newItems.first.name}', AppColors.purple);
    }

    setState(() {
      _reaction = fav ? '😍' : '🥰';
      _feedback = 'Thank you! Bye-bye!';
      _feedbackColor = AppColors.greenDark;
    });
    _say('Thank you! Bye-bye!');
    const List<String> words = ['เก่งมาก', 'สุดยอด', 'เยี่ยมเลย', 'ถูกต้อง', 'เก่งจัง', 'ว้าว'];
    if (fav) {
      _showPraise('ของโปรดของลูกค้า');
    } else {
      _showPraise(words[Random().nextInt(words.length)]);
    }
    if (newItems.isNotEmpty) _celebrate();
    _sendCustomerAway();
  }

  String _mismatchHint() {
    for (final e in _basket.entries) {
      final item = _itemById(e.key);
      final req = _targetOrder.where((r) => r.item.id == e.key).toList();
      if (req.isEmpty) return "Oops! I don't want ${item.emoji}.";
      if (e.value > req.first.count) return 'Too many ${item.emoji}!';
    }
    for (final r in _targetOrder) {
      if ((_basket[r.item.id] ?? 0) < r.count) return 'Almost! Add more ${r.item.emoji}.';
    }
    return "Hmm, that's not right. Try again!";
  }

  void _onOrderMistake() {
    _mistakes++;
    setState(() {
      _reaction = '🤔';
      _feedback = _mismatchHint();
      _feedbackColor = AppColors.orangeDark;
    });
    _say("Let's try again. $_spokenText"); // ฟังออเดอร์ซ้ำอีกรอบ
    final token = _arrivalId;
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted || token != _arrivalId || !_orderActive) return;
      setState(() {
        _reaction = null;
        _feedback = null;
      });
    });
  }

  void _onPatienceTimeout() {
    _orderActive = false;
    setState(() {
      _reaction = '😠';
      _feedback = "Too slow! I'm leaving.";
      _feedbackColor = AppColors.red;
    });
    _say("Too slow! I'm leaving.");
    _sendCustomerAway();
  }

  // ---------- End of level ----------
  int _calcStars() {
    final ratio = _successes / _cfg.customers;
    if (ratio >= 1.0 && _mistakes <= 2) return 3;
    if (ratio >= 0.8) return 2;
    if (ratio >= 0.5) return 1;
    return 0;
  }

  void _finishLevel() {
    _clearResume();
    final stars = _calcStars();
    final passed = stars > 0;
    if (passed) {
      gameProgress.completeLevel(widget.level, stars);
    } else {
    }
    _showResult(stars, passed);
  }

  Widget _resultStars(int stars) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final bool on = i < stars;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 500 + i * 250),
          curve: Curves.elasticOut,
          builder: (context, v, child) => Transform.scale(scale: on ? v : 1.0, child: child),
          child: Icon(
            Icons.star_rounded,
            size: i == 1 ? 70 : 54,
            color: on ? AppColors.yellow : const Color(0xFFE2E8F0),
            shadows: on ? const [Shadow(color: Color(0x66B45309), offset: Offset(0, 3), blurRadius: 4)] : null,
          ),
        );
      }),
    );
  }

  void _showResult(int stars, bool passed) {
    final hasNext = passed && widget.level < kTotalLevels;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => appDialogShell(
        lockBack: true,
        borderColor: passed ? AppColors.yellow : AppColors.orange,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  passed
                      ? (_cfg.isBoss ? 'ผ่านด่านบอสแล้ว' : 'ผ่านด่าน ${widget.level} แล้ว')
                      : 'ลองใหม่อีกครั้งนะ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: passed ? AppColors.greenDark : AppColors.orangeDark),
                ),
                const SizedBox(height: 8),
                _resultStars(stars),
                const SizedBox(height: 8),
                Text(
                  stars == 3
                      ? 'สุดยอดไปเลย เก่งมาก'
                      : (stars == 2
                          ? 'เก่งมาก เกือบเต็มแล้ว'
                          : (stars == 1 ? 'ผ่านแล้ว ลองอีกครั้งเพื่อเก็บดาวเพิ่มนะ ' : 'ไม่เป็นไรนะ ลองใหม่ได้เสมอ')),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.blueDark),
                ),
                if (_newCollected > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('ได้สติกเกอร์ใหม่ $_newCollected ชิ้น ดูในสมุดสะสม',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.purpleDark)),
                  ),
                const SizedBox(height: 8),
               
                const SizedBox(height: 4),
                FutureBuilder<List<GuessCoinResult>>(
                  future: Future.wait(_levelCoins),
                  builder: (_, snap) {
                    final list = snap.data;
                    final coins = list?.fold<int>(0, (s, r) => s + r.coins) ?? 0;
                    final pending = list?.where((r) => r.pending).length ?? 0;
                    final String text = list == null
                        ? 'กำลังนับเหรียญ...'
                        : pending > 0
                            ? 'ได้ $coins เหรียญ (รอต่อเน็ต)'
                            : coins > 0
                                ? 'ได้ $coins เหรียญ'
                                : 'สินค้ารอบนี้ได้เหรียญไปแล้ววันนี้';
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFB627), size: 20),
                        const SizedBox(width: 4),
                        Text(text,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.purpleDark)),
                      ],
                    );
                  },
                ),
                if (!passed)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'ต้องบริการลูกค้าให้ได้อย่างน้อยครึ่งหนึ่งเพื่อผ่านด่าน',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.ink),
                    ),
                  ),
                if (passed && widget.level == kTotalLevels)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('คุณคือราชาตลาดตัวจริง ผ่านครบทุกด่านแล้ว',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.purpleDark)),
                  ),
                const SizedBox(height: 16),
                if (hasNext)
                  SizedBox(
                    width: double.infinity,
                    child: ChunkyButton(
                      color: AppColors.green,
                      shadowColor: AppColors.greenDark,
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => MarketGameScreen(level: widget.level + 1)),
                        );
                      },
                      child: const Text('ด่านต่อไป', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                if (hasNext) const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ChunkyButton(
                    color: AppColors.blue,
                    shadowColor: AppColors.blueDark,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _startLevel();
                    },
                    child: const Text('เล่นอีกครั้ง'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ChunkyButton(
                    color: AppColors.orange,
                    shadowColor: AppColors.orangeDark,
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: const Text('เลือกด่าน'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExit() async {
    if (_askingExit) return;
    _askingExit = true;
    _patienceTimer?.cancel();
    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => appDialogShell(
        borderColor: AppColors.orange,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ออกจากด่านนี้',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.orangeDark)),
            const SizedBox(height: 8),
            const Text('กลับมาเล่นต่อจากลูกค้าคนถัดไปได้นะ',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.ink)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ChunkyButton(
                color: AppColors.green,
                shadowColor: AppColors.greenDark,
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('เล่นต่อ'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ChunkyButton(
                color: AppColors.orange,
                shadowColor: AppColors.orangeDark,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ออก'),
              ),
            ),
          ],
        ),
      ),
    );
    _askingExit = false;
    final VoidCallback? waiting = _afterExit;
    final bool waitingFinish = _afterExitFinishes;
    _afterExit = null;
    _afterExitFinishes = false;
    if (!mounted) return;
    if (leave == true) {
      // The last customer had just been served: keep the result.
      if (waitingFinish) {
        _clearResume();
        final stars = _calcStars();
        if (stars > 0) gameProgress.completeLevel(widget.level, stars);
      }
      Navigator.pop(context);
    } else if (waiting != null) {
      waiting();
    } else if (_orderActive) {
      _pausedByApp = false;
      _startPatienceTimer();
    }
  }

  // ==========================================
  // UI — สไตล์ตลาดไม้ตามภาพอ้างอิง
  // ==========================================
  // ignore: unused_field
  static const Color _wLight = Color(0xFFD9A868);
  static const Color _wMid = Color(0xFFB07A44);
  static const Color _wDark = Color(0xFF7A4B22);
  static const Color _wDeep = Color(0xFF5B3A1E);
  static const Color _paper = Color(0xFFFFF3DA);

  static const Map<String, String> _crateProduce = {
    'Vegetables': '🥬🥕🍅',
    'Fruits': '🍏🍎🍊',
    'Fresh': '🥩🥚🧀',
    'Drinks': '🥛🧃🥤',
    'Snacks': '🍪🍫🍿',
    'Bakery': '🍞🥐🍩',
    'Meals': '🍔🍕🌭',
  };

  @override
  Widget build(BuildContext context) {
    // ปุ่ม Back ของเครื่องต้องถามยืนยันก่อนออก เหมือนปุ่มย้อนกลับบนหัวจอ
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: _buildGameScaffold(context),
    );
  }

  Widget _buildGameScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE2BC82),
      body: _GameScaffoldBody(
        title: 'มินิมาร์เก็ต',
        color: const Color(0xFFF5B000),
        onBack: _confirmExit,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2D9A4), Color(0xFFDDB279), Color(0xFFC08B52)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildStatsRow(),
                _buildScene(),
                _buildChalkboard(),
                Expanded(child: _buildShelfZone()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- ป้ายโลก/เลเวล (ย่อ) ----------
  Widget _worldSign() {
    return Container(
      width: 62,
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8E6), Color(0xFFFFE9BC)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _wMid, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 3)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('ด่าน ${widget.level}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF4B3A1E))),
          ),
        ],
      ),
    );
  }

  // ---------- แถบสถิติ: กระเป๋า+เหรียญ / หลอดความคืบหน้า / ลูกค้า ----------
  Widget _bagCoin() {
    return SizedBox(
      width: 104,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 26,
            top: 6,
            right: 0,
            height: 32,
            child: Container(
              padding: const EdgeInsets.only(left: 20, right: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF9A6533), Color(0xFF714420)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _wDeep, width: 2.5),
              ),
              // เหรียญจริงของบัญชี (เพิ่มขึ้นทันทีที่ส่งของถูกแล้วได้เหรียญ)
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFC107), size: 20),
                  const SizedBox(width: 4),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ValueListenableBuilder<int?>(
                        valueListenable: CoinBalance.value,
                        builder: (_, coins, _) => Text(
                          coins == null ? '-' : '$coins',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFFFF0C8)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFB8733B), Color(0xFF7A4520)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4A2B12), width: 2.5),
                boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 3), blurRadius: 3)],
              ),
              child: const Text('👜', style: TextStyle(fontSize: 24)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar(double frac) {
    return SizedBox(
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 18),
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF4A2F18),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _wMid, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 3), blurRadius: 3)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: max(frac, 0.1),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF9BE35A), Color(0xFF4FAE2C)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 2,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8A6034), Color(0xFF5B3A1E)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3E2A18), width: 3),
                boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 2)],
              ),
              child: Text('$_successes',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFFFF0C8))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _servedPill() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5AA7F0), Color(0xFF2F6FC4)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F4F96), width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 3), blurRadius: 3)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Text('$_served / ${_cfg.customers}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final double frac = _cfg.customers == 0 ? 0.0 : (_served / _cfg.customers).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          _bagCoin(),
          const SizedBox(width: 6),
          Expanded(child: _progressBar(frac)),
          const SizedBox(width: 8),
          _servedPill(),
        ],
      ),
    );
  }

  // ---------- ฉากแผงขายของ (ย่อให้เตี้ยลง เหลือพื้นที่เลือกสินค้ามากขึ้น) ----------
  double _lerp(double a, double b, double t) => a + (b - a) * t;

  Widget _buildCustomerSprite() {
    // ลูกค้าเริ่มหน้าตาเป็นห่วงเมื่อความอดทนเหลือน้อย
    final String? face =
        _reaction ?? ((_phase == CustomerPhase.waiting && _orderActive && _patienceLevel < 0.35) ? '😟' : null);
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: 50,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0x33000000),
                borderRadius: BorderRadius.all(Radius.elliptical(25, 5)),
              ),
            ),
          ),
          Center(child: Text(_currentCustomer.emoji, style: const TextStyle(fontSize: 52, height: 1.1))),
          if (face != null) Positioned(top: -8, right: -6, child: Text(face, style: const TextStyle(fontSize: 26))),
        ],
      ),
    );
  }

  Widget _wicker(String produce, double w) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, 7),
          child: Text(produce, style: const TextStyle(fontSize: 20, letterSpacing: -5, height: 1.0)),
        ),
        Container(
          width: w,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE2AE62), Color(0xFFA9722F)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3), bottom: Radius.circular(10)),
            border: Border.all(color: _wDark, width: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _post() => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFB07A44), Color(0xFF8B5A2B)]),
          border: Border.all(color: _wDeep, width: 1.5),
        ),
      );

  Widget _buildScene() {
    final double sceneH = (MediaQuery.of(context).size.height * 0.2).clamp(150.0, 180.0).toDouble();
    return Container(
      height: sceneH,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      child: LayoutBuilder(
        builder: (context, c) {
          final double w = c.maxWidth;
          const double spriteW = 72;
          const double sideW = 72; // พื้นที่ป้ายโลก + ธง ด้านขวา
          final double stallRight = w - sideW;
          final double waitLeft = w * 0.56 - spriteW / 2;
          final bool waiting = _phase == CustomerPhase.waiting;
          final double p1 = sceneH * 0.52 + 2;
          final double p2 = sceneH - 22;
          final double bw = ((w - 200) / 3 - 4).clamp(30.0, 44.0).toDouble();

          Widget shelf(double plankY, double l, double r, List<Widget> items) {
            return Positioned(
              left: l,
              right: w - r,
              top: plankY - 42,
              height: 48,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: items,
                    ),
                  ),
                  Container(
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC48A47),
                      border: Border(bottom: BorderSide(color: Color(0xFF5B3A1E), width: 2)),
                    ),
                  ),
                ],
              ),
            );
          }

          Widget smallRow(String e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(e, style: const TextStyle(fontSize: 17, letterSpacing: -1)),
              );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // ผนังหลังแผง
              Positioned(
                left: 0,
                right: sideW,
                top: 26,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFA8733A), Color(0xFF7E5128)],
                    ),
                    border: Border.all(color: _wDeep, width: 2),
                  ),
                ),
              ),
              // เสา
              Positioned(left: 0, top: 26, bottom: 0, width: 9, child: _post()),
              Positioned(left: 104, top: 26, bottom: 0, width: 7, child: _post()),
              Positioned(left: stallRight - 9, top: 26, bottom: 0, width: 9, child: _post()),
              // ชั้นซ้าย
              shelf(p1, 12, 100, [smallRow('🥫🍎🥕')]),
              shelf(p2, 12, 100, [smallRow('🧃🍞🥦')]),
              // ชั้นขวา (ตะกร้าหวาย)
              shelf(p1, 116, stallRight - 12, [_wicker('🍅🍅', bw), _wicker('🍅🍅', bw), _wicker('🥕🥕', bw)]),
              shelf(p2, 116, stallRight - 12, [_wicker('🍆🍆', bw), _wicker('🥔🥔', bw), _wicker('🌽🌽', bw)]),
              // ลูกค้า
              AnimatedBuilder(
                animation: Listenable.merge([_walkCtrl, _idleCtrl]),
                builder: (context, _) {
                  final t = _walkCtrl.value;
                  double left;
                  double dy;
                  switch (_phase) {
                    case CustomerPhase.entering:
                      left = _lerp(-spriteW - 10, waitLeft, Curves.easeOutCubic.transform(t));
                      dy = -sin(t * pi * 8).abs() * 8;
                      break;
                    case CustomerPhase.waiting:
                      // ดีใจ = กระโดด, งง/โกรธ = สั่นหัว
                      left = waitLeft +
                          ((_reaction == '🤔' || _reaction == '😠') ? sin(_idleCtrl.value * pi * 6) * 5 : 0);
                      dy = (_reaction == '🥰' || _reaction == '😍')
                          ? -sin(_idleCtrl.value * pi) * 16
                          : -_idleCtrl.value * 3;
                      break;
                    case CustomerPhase.leaving:
                      left = _lerp(waitLeft, w + 10, Curves.easeInCubic.transform(t));
                      dy = -sin(t * pi * 8).abs() * 8;
                      break;
                  }
                  return Positioned(
                    left: left,
                    bottom: 18,
                    child: Transform.translate(offset: Offset(0, dy), child: _buildCustomerSprite()),
                  );
                },
              ),
              // เคาน์เตอร์ไม้
              Positioned(
                left: 0,
                right: sideW,
                bottom: 0,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFC48A47), Color(0xFF8B5A2B)],
                    ),
                    border: Border.all(color: _wDeep, width: 2),
                  ),
                ),
              ),
              // ป้ายชื่อลูกค้า
              Positioned(
                left: waitLeft + spriteW / 2 - 52,
                width: 104,
                bottom: 2,
                height: 24,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF1D29B), Color(0xFFD8A760)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _wDark, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 2)],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_currentCustomer.englishName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF4B3A1E))),
                  ),
                ),
              ),
              // กันสาดลายทางเขียว-ครีม
              Positioned(
                left: -4,
                right: -4,
                top: 0,
                height: 38,
                child: const CustomPaint(
                  painter: _StripedAwningPainter(a: Color(0xFF86A862), b: Color(0xFFFFF8E7), n: 9),
                ),
              ),
              // แถบความอดทน
              Positioned(
                left: 14,
                right: sideW + 12,
                top: 31,
                height: 9,
                child: AnimatedOpacity(
                  opacity: waiting ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _wDeep, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: _patienceLevel,
                        minHeight: 6,
                        backgroundColor: Colors.white,
                        color: _patienceLevel > 0.4 ? AppColors.green : AppColors.red,
                      ),
                    ),
                  ),
                ),
              ),
              // ป้ายโลก/เลเวล (ขวาบน)
              Positioned(right: 6, top: 42, child: _worldSign()),
              // เสาธง + ธง "Store is OPEN!"
              Positioned(
                right: 2,
                top: 104,
                bottom: 0,
                width: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5A2B),
                    border: Border.all(color: _wDeep, width: 1),
                  ),
                ),
              ),
              Positioned(
                right: 7,
                top: 106,
                width: 68,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF5E9A6C), Color(0xFF3E7350)],
                    ),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    border: Border.all(color: const Color(0xFF2B5238), width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 2), blurRadius: 2)],
                  ),
                  child: Text(
                    _praise ?? 'ร้านเปิดแล้ว',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFFFFF6DA), height: 1.15),
                  ),
                ),
              ),
              Positioned(
                left: 22,
                top: 48,
                child: Column(
                  children: _floatingCoins
                      .map((coin) => FloatingUpText(
                            key: ValueKey(coin.id),
                            text: coin.text,
                            color: coin.color,
                            onDone: () => _removeFloatingCoin(coin.id),
                          ))
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- กระดานดำ: คำสั่งลูกค้า + ตะกร้า + ปุ่มส่งของ ----------
  Widget _chalkChip(Widget child, {Color bg = const Color(0xFFF7F3E3), Color border = const Color(0xFFFFB066)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: child,
    );
  }

  Widget _buildChalkboard() {
    final bool orderChipsShown = _cfg.showIcons || _hintIcons;
    final bool waiting = _phase == CustomerPhase.waiting && _orderActive;
    final bool hidden = _cfg.hideText && !_textRevealed;
    const Color chalk = Color(0xFFF7F3E3);
    const Color chalkSoft = Color(0xFFBFE3C8);
    final List<Widget> lines = [];
    final List<Widget> chips = []; // ชิปเป้าหมาย + ชิปในตะกร้า วางแถวเดียวกัน

    if (waiting) {
      lines.add(GestureDetector(
        onTap: _speakOrder,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            const Icon(Icons.volume_up_rounded, size: 16, color: chalkSoft),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: chalkSoft),
              ),
            ),
          ],
        ),
      ));
      lines.add(const SizedBox(height: 3));
      if (hidden) {
        lines.add(Row(
          children: [
            const Expanded(
              child: Text('ฟังให้ดีนะ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: chalk)),
            ),
            GestureDetector(
              onTap: () => setState(() => _textRevealed = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(12)),
                child: const Text('ดูข้อความ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.ink)),
              ),
            ),
          ],
        ));
      } else {
        lines.add(GestureDetector(
          onTap: _speakOrder,
          child: Text(
            _spokenText,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: chalk, height: 1.2),
          ),
        ));
      }
      if (orderChipsShown) {
        chips.addAll(_targetOrder.map((req) {
            final bool done = (_basket[req.item.id] ?? 0) >= req.count;
            // แตะเพื่อเอาออก 1 ชิ้น (สินค้าที่หยิบถูกไม่ขึ้นซ้ำในแถวตะกร้าแล้ว)
            return GestureDetector(
              onTap: () => _removeItemFromBasket(req.item.id),
              child: _chalkChip(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(req.item.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 3),
                  Text(
                    done ? '✓ x${req.count}' : '${_basket[req.item.id] ?? 0} / ${req.count}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: done ? AppColors.greenDark : AppColors.ink,
                    ),
                  ),
                ],
              ),
              bg: done ? const Color(0xFFDCFCE7) : const Color(0xFFF0F9FF),
              border: done ? AppColors.green : AppColors.orange,
            ),
            );
          }).toList());
      }
    }

    // สินค้าที่หยิบถูก (อยู่ในออเดอร์ และไม่เกินจำนวน) แสดงอยู่แล้วที่ป้ายออเดอร์
    // ด้านบน: แถวตะกร้าแสดงเฉพาะของที่หยิบผิดหรือหยิบเกิน
    bool shownInOrder(MapEntry<String, int> entry) {
      if (!orderChipsShown) return false;
      final req = _targetOrder.where((r) => r.item.id == entry.key);
      return req.isNotEmpty && entry.value <= req.first.count;
    }

    final basketChips = _basket.entries.where((e) => !shownInOrder(e)).toList();
    if (basketChips.isNotEmpty) {
      chips.addAll(basketChips.map((entry) {
          final item = _itemById(entry.key);
          return GestureDetector(
            onTap: () => _removeItemFromBasket(item.id),
            child: _chalkChip(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 3),
                  Text('x${entry.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.ink)),
                ],
              ),
            ),
          );
        }).toList());
    } else if (_basket.isEmpty && !waiting && _feedback == null) {
      lines.add(const Text('แตะสินค้าด้านล่างใส่ตะกร้า',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: chalk)));
    }

    if (chips.isNotEmpty) {
      lines.add(const SizedBox(height: 5));
      lines.add(Wrap(spacing: 6, runSpacing: 4, children: chips));
    }

    if (_feedback != null) {
      lines.add(const SizedBox(height: 5));
      lines.add(Text(_feedback!,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: lighten(_feedbackColor, 0.6))));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC48A4C), Color(0xFF94602F)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _wDeep, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 4), blurRadius: 5)],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF37574A), Color(0xFF2A4539)],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF1F3329), width: 2),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50, maxHeight: 150),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('🧺', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ChunkyButton(
                        color: AppColors.green,
                        shadowColor: AppColors.greenDark,
                        radius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        onPressed: (_basket.isEmpty || !_orderActive) ? null : _checkOrder,
                        child: const Text('ส่งของ 🛎️',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ChunkyButton(
                        color: AppColors.red,
                        shadowColor: AppColors.redDark,
                        radius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        onPressed: (_basket.isEmpty || !_orderActive) ? null : _clearBasket,
                        child: const Text('🗑️ ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                    if (!_cfg.showIcons) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: ChunkyButton(
                          color: AppColors.yellow,
                          shadowColor: AppColors.yellowDark,
                          radius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          onPressed: _canHint ? _useHint : null,
                          child: const Text('💡 คำใบ้',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.ink)),
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
  }

  // ---------- ลังหมวดหมู่ + แท็บ ----------
  Widget _crateTab(int index, String cat, double w) {
    final CategoryStyle st = kCategoryStyles[cat]!;
    final bool selected = _selectedCategoryTab == cat;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryTab = cat),
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 42,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(_crateProduce[cat] ?? st.emoji,
                            style: const TextStyle(fontSize: 20, letterSpacing: -5, height: 1.0)),
                      ),
                    ),
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFD9A868), Color(0xFFA9723A)],
                        ),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _wDark, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: selected ? const Color(0xAAFFF176) : const Color(0x55000000),
                            offset: const Offset(0, 3),
                            blurRadius: selected ? 8 : 3,
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        painter: const _PlankPainter(),
                        child: Center(
                          child: Container(
                            width: 19,
                            height: 19,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _paper,
                              shape: BoxShape.circle,
                              border: Border.all(color: _wDark, width: 2),
                            ),
                            child: Text('${index + 1}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF4B3A1E))),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: selected ? st.color : Color.lerp(st.light, st.color, 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? Colors.white : st.color.withAlpha(170), width: 2.5),
                  boxShadow: [BoxShadow(color: st.color.withAlpha(selected ? 170 : 90), offset: const Offset(0, 3))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(st.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          st.label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: selected ? Colors.white : AppColors.ink,
                          ),
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
    );
  }

  Widget _buildCrateTabs(List<String> categories) {
    return LayoutBuilder(builder: (context, c) {
      final double itemW = (c.maxWidth - 24) / (categories.length <= 4 ? 4 : 4.4);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Row(
          children: [
            for (int i = 0; i < categories.length; i++) _crateTab(i, categories[i], itemW),
          ],
        ),
      );
    });
  }

  // ---------- ช่องสินค้าไม้ ----------
  Widget _shelfTile(MarketItem item) {
    final int count = _basket[item.id] ?? 0;
    final bool has = count > 0;
    return GestureDetector(
      onTap: () => _addItemToBasket(item),
      onLongPress: () => _speakItem(item),
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>('${item.id}_$count'),
        tween: Tween<double>(begin: has ? 1.18 : 1.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFC48A4C), Color(0xFF94602F)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _wDeep, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: has ? const Color(0xAA7CE05A) : const Color(0x55000000),
                      offset: const Offset(0, 3),
                      blurRadius: has ? 7 : 3,
                    ),
                  ],
                ),
                child: Container(
                  alignment: const Alignment(0, -0.35),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: has
                          ? const [Color(0xFF9CCB7A), Color(0xFFD3EBB8)]
                          : const [Color(0xFF8A5A2B), Color(0xFFC08A50)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF6B4220), width: 1.5),
                  ),
                  child: Text(item.emoji, style: const TextStyle(fontSize: 42)),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _wMid, width: 1.5),
                ),
                child: Text(
                  item.name,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF4B3A1E)),
                ),
              ),
            ),
            if (has)
              Positioned(
                top: -3,
                right: -3,
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.green,
                  child: Text('$count',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelfZone() {
    final categories = _availableCategories;
    final currentCategoryItems = kAllMarketItems.where((i) => i.category == _selectedCategoryTab).toList();

    return Column(
      children: [
        _buildCrateTabs(categories),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFCB9A5F), Color(0xFFA8743F)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(top: BorderSide(color: Color(0xFF8B5A2B), width: 3)),
            ),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.92,
                crossAxisSpacing: 8,
                mainAxisSpacing: 10,
              ),
              itemCount: currentCategoryItems.length,
              itemBuilder: (context, index) => _shelfTile(currentCategoryItems[index]),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// สมุดสะสมสติกเกอร์: ส่งสินค้าให้ลูกค้าเพื่อปลดล็อกสติกเกอร์ แตะเพื่อฟังคำศัพท์
// ==========================================
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.42);
    _tts.setPitch(1.1);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(MarketItem item) async {
    try {
      await _tts.stop();
      await _tts.speak(item.quantifier != null ? '${item.quantifier} ${item.quantName ?? item.name}' : item.name);
    } catch (_) {}
  }

  Widget _tile(MarketItem item, CategoryStyle st) {
    final int n = gameProgress.remainingItems[item.id] ?? 0;
    final bool have = n > 0;
    return GestureDetector(
      onTap: have
          ? () => _speak(item)
          : () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              duration: Duration(milliseconds: 1500),
              content: Text('🔒 ส่งสินค้าชิ้นนี้ให้ลูกค้าเพื่อปลดล็อกสติกเกอร์ !'),
            )),
      child: Container(
        decoration: BoxDecoration(
          color: have ? st.light : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: have ? st.color : const Color(0xFFCBD5E1), width: 2.5),
          boxShadow: have ? [BoxShadow(color: st.color.withAlpha(90), offset: const Offset(0, 3))] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(have ? item.emoji : '❓', style: TextStyle(fontSize: 32, color: have ? null : const Color(0xFF94A3B8))),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                have ? item.name : '???',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w900, color: have ? AppColors.ink : const Color(0xFF94A3B8)),
              ),
            ),
            if (have) Text('x$n', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: st.color)),
          ],
        ),
      ),
    );
  }

  Widget _section(String cat) {
    final st = kCategoryStyles[cat]!;
    final items = kAllMarketItems.where((i) => i.category == cat).toList();
    final got = items.where((i) => (gameProgress.remainingItems[i.id] ?? 0) > 0).length;
    final bool complete = got == items.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: softCard(
        border: complete ? AppColors.yellow : Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        radius: 24,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: st.light, shape: BoxShape.circle),
                  child: Text(st.emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(st.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: st.color)),
                ),
                Text(complete ? 'ครบแล้ว' : '$got / ${items.length}',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900, color: complete ? AppColors.orangeDark : AppColors.ink)),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.9,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: items.map((i) => _tile(i, st)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _GameScaffoldBody(
        title: 'สมุดสะสม',
        color: const Color(0xFFF5B000),
        child: SunnyBackground(
        colors: AppColors.goldenSky,
        decor: const ['🌸', '⭐', '🎀', '✨', '🌈', '💖'],
        child: SafeArea(
          child: AnimatedBuilder(
            animation: gameProgress,
            builder: (context, _) {
              final int got = collectedCount();
              final int total = kAllMarketItems.length;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('📖 สมุดสะสม',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.pinkDark)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(color: Color(0x22000000), offset: Offset(0, 2), blurRadius: 3)],
                          ),
                          child: Text('$got / $total',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.orangeDark)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : got / total,
                        minHeight: 14,
                        backgroundColor: Colors.white,
                        color: AppColors.pink,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('แตะสติกเกอร์เพื่อฟังคำศัพท์ ส่งของให้ลูกค้าเพื่อสะสมให้ครบ !',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                      children: kCategoryOrder.map(_section).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}

// ==========================================
// Entry point สำหรับเรียกจากเมนูเกม (game_screen.dart)
// ==========================================
class MiniMarketScreen extends StatefulWidget {
  const MiniMarketScreen({super.key});

  @override
  State<MiniMarketScreen> createState() => _MiniMarketScreenState();
}

class _MiniMarketScreenState extends State<MiniMarketScreen> {
  late final Future<void> _loading = gameProgress.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return const LevelSelectScreen();
      },
    );
  }
}


// ---------------------------------------------------------------
// ป้ายแสดงเหรียญจริงของบัญชี (เหมือนเกมอื่น)
// ---------------------------------------------------------------
class _CoinPill extends StatelessWidget {
  final Color color;
  final double fontSize;

  const _CoinPill({
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
            builder: (_, coins, _) => Text(
            coins == null ? '-' : '$coins',
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          )),
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


// กันสาดลายทางสองสี ขอบหยัก (ใช้กับแผงขายของในหน้าเล่น)
class _StripedAwningPainter extends CustomPainter {
  final Color a;
  final Color b;
  final int n;
  const _StripedAwningPainter({required this.a, required this.b, this.n = 9});

  @override
  void paint(Canvas canvas, Size size) {
    final double sw = size.width / n;
    final double r = sw / 2;
    final double bodyH = max(0.0, size.height - r - 4);
    for (int pass = 0; pass < 2; pass++) {
      for (int i = 0; i < n; i++) {
        final Paint p = Paint()
          ..color = pass == 0 ? const Color(0x44000000) : (i.isEven ? a : b);
        final double dy = pass == 0 ? 3 : 0;
        canvas.drawRect(Rect.fromLTWH(i * sw, dy, sw + 0.5, bodyH), p);
        canvas.drawArc(Rect.fromLTWH(i * sw, bodyH - r + dy, sw, sw), 0, pi, true, p);
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 6),
      Paint()..color = const Color(0xFF6B4220),
    );
  }

  @override
  bool shouldRepaint(covariant _StripedAwningPainter old) => old.a != a || old.b != b || old.n != n;
}