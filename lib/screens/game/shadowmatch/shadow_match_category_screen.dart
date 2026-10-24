import 'package:flutter/material.dart';
import '../../../widgets/coin_balance_chip.dart';
import '../../../services/shadow_progress_service.dart';
import 'shadow_match_data.dart';
import 'shadow_match_screen.dart';

class ShadowMatchCategoryScreen extends StatefulWidget {
  const ShadowMatchCategoryScreen({super.key});

  @override
  State<ShadowMatchCategoryScreen> createState() =>
      _ShadowMatchCategoryScreenState();
}

class _ShadowMatchCategoryScreenState extends State<ShadowMatchCategoryScreen> {
  static const List<ShadowCategory> categories = shadowCategories;

  /// For the badges: unfinished games and finished categories.
  Map<String, ({int stage, int stages})> _unfinished = {};
  Map<String, int> _best = {};

  @override
  void initState() {
    super.initState();
    _loadBadges();
    // Progress saved on the server (e.g. another phone), then refresh.
    ShadowProgress.sync().then((_) => _loadBadges());
    ShadowCoins.flush(); // coins of matches made while offline
  }

  Map<String, Set<String>> get _idsByCategory => {
    for (final c in categories) c.key: c.items.map((i) => i.id).toSet(),
  };

  Future<void> _loadBadges() async {
    final unfinished = await ShadowProgress.unfinished(_idsByCategory);
    final best = await ShadowProgress.bestScores();
    if (!mounted) return;
    setState(() {
      _unfinished = unfinished;
      _best = best;
    });
  }

  Future<void> _open(ShadowCategory category) async {
    final saved = await ShadowProgress.load(category.key, _idsByCategory[category.key]!);
    if (!mounted) return;
    ShadowRound? resume;
    if (saved != null) {
      final choice = await _askResume(category, saved);
      if (!mounted || choice == null) return;
      if (choice) {
        resume = saved;
      } else {
        await ShadowProgress.clear(category.key);
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShadowMatchScreen(category: category, resume: resume),
      ),
    );
    _loadBadges();
  }

  Future<bool?> _askResume(ShadowCategory category, ShadowRound saved) {
    final color = category.cardColor;
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: color.withValues(alpha: 0.35), width: 2.5),
            ),
            title: Row(
              children: [
                Icon(Icons.play_circle_fill_rounded, color: color, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'หมวด${category.titleTh}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'เล่นค้างไว้ที่ด่าน ${saved.roundIndex + 1} จาก ${saved.stages}\n'
              'จับคู่ไปแล้ว ${saved.matchedTotal} คู่ จะเล่นต่อเลยไหม ?',
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
                        foregroundColor: color,
                        side: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
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
                        backgroundColor: color,
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

  /// "เล่นต่อ 3/8" for an unfinished game, a green tick when finished.
  Widget? _badge(ShadowCategory category) {
    final unfinished = _unfinished[category.key];
    if (unfinished != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, size: 14, color: Color(0xFFF59E0B)),
            const SizedBox(width: 2),
            Text(
              'เล่นต่อ ${unfinished.stage} / ${unfinished.stages}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      );
    }
    if (_best.containsKey(category.key)) {
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
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const topBarColor = Color(0xFF6366F1);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE0E7FF),
              Color(0xFFEEF2FF),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Column(
          children: [
            Container(
              color: topBarColor,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.maybePop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      // Same width as the coin chip on the right, so the title stays centred.
                      const SizedBox(width: CoinBalanceChip.width - 34),
                      const Expanded(
                        child: Text(
                          'จับคู่เงา',
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
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'จับคู่เงาแสนสนุก',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6366F1),
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'เลือกหมวดหมู่',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.88,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final cat = categories[index];
                          return _KidsLeafCard(
                            category: cat,
                            badge: _badge(cat),
                            onTap: () => _open(cat),
                          );
                        },
                        childCount: categories.length,
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
}

class _KidsLeafCard extends StatelessWidget {
  final ShadowCategory category;
  final Widget? badge;
  final VoidCallback onTap;

  const _KidsLeafCard({
    required this.category,
    required this.onTap,
    this.badge,
  });

  static const BorderRadius outerRadius = BorderRadius.only(
    topLeft: Radius.circular(38),
    topRight: Radius.circular(18),
    bottomLeft: Radius.circular(18),
    bottomRight: Radius.circular(18),
  );

  static const BorderRadius innerRadius = BorderRadius.only(
    topLeft: Radius.circular(34),
    topRight: Radius.circular(14),
    bottomLeft: Radius.circular(14),
    bottomRight: Radius.circular(14),
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: outerRadius,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: outerRadius,
          border: Border.all(color: Colors.white, width: 3.0),
          boxShadow: [
            BoxShadow(
              color: category.cardShadowColor,
              offset: const Offset(0, 5.5),
              blurRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: innerRadius,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: category.cardColor),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 16, 26, 44),
                  child: Center(
                    child: Image.asset(
                      category.cardImagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.category_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CustomPaint(
                  painter: _WaveBadgePainter(),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
                    alignment: Alignment.center,
                    child: Text(
                      category.titleTh,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: category.cardColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
              if (badge != null)
                Positioned(top: 8, right: 8, child: badge!),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 14);
    path.quadraticBezierTo(size.width * 0.25, 0, size.width * 0.60, 8);
    path.quadraticBezierTo(size.width * 0.85, 14, size.width, 5);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}