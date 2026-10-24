import 'package:flutter/material.dart';
import '../../../services/riddle_progress_service.dart';
import '../../../widgets/coin_balance_chip.dart';
import 'riddle_data.dart';
import 'riddle_game_play_screen.dart';

export 'riddle_data.dart' show RiddleCategoryItem, riddleCategories;

class WordRiddleScreen extends StatefulWidget {
  const WordRiddleScreen({super.key});

  @override
  State<WordRiddleScreen> createState() => _WordRiddleScreenState();
}

class _WordRiddleScreenState extends State<WordRiddleScreen> {
  static const List<RiddleCategoryItem> categories = riddleCategories;

  /// For the badges: unfinished games and finished categories.
  Map<String, ({int done, int total})> _unfinished = {};
  Map<String, int> _best = {};

  @override
  void initState() {
    super.initState();
    _loadBadges();
    // Progress saved on the server (e.g. another phone), then refresh.
    RiddleProgress.sync().then((_) => _loadBadges());
    RiddleCoins.flush(); // coins of answers given while offline
  }

  Map<String, Set<String>> get _answersByCategory => {
    for (final c in categories) c.key: c.answers,
  };

  Future<void> _loadBadges() async {
    final unfinished = await RiddleProgress.unfinished(_answersByCategory);
    final best = await RiddleProgress.bestScores();
    if (!mounted) return;
    setState(() {
      _unfinished = unfinished;
      _best = best;
    });
  }

  Future<void> _open(RiddleCategoryItem category) async {
    final saved = await RiddleProgress.load(category.key, category.answers);
    if (!mounted) return;
    RiddleRound? resume;
    if (saved != null) {
      final choice = await _askResume(category, saved);
      if (!mounted || choice == null) return;
      if (choice) {
        resume = saved;
      } else {
        await RiddleProgress.clear(category.key);
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RiddleGamePlayScreen(category: category, resume: resume),
      ),
    );
    _loadBadges();
  }

  Future<bool?> _askResume(RiddleCategoryItem category, RiddleRound saved) {
    final color = category.buttonColor;
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
              'เล่นค้างไว้ ทายถูกไปแล้ว ${saved.done} จาก ${saved.total} ข้อ\n'
              'จะเล่นต่อเลยไหม ?',
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

  /// "เล่นต่อ 7/18" for an unfinished game, a green tick when finished.
  Widget? _badge(RiddleCategoryItem category) {
    final unfinished = _unfinished[category.key];
    if (unfinished != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
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
              'เล่นต่อ ${unfinished.done} / ${unfinished.total}',
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
    const topBarColor = Color(0xFF008466);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
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
                        'ปริศนาทายคำ',
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
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ปริศนาทายคำแสนสนุก',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF008466),
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
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final cat = categories[index];
                        final badge = _badge(cat);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: GestureDetector(
                            onTap: () => _open(cat),
                            child: Stack(
                              children: [
                                Container(
                              height: 158,
                              decoration: BoxDecoration(
                                color: cat.shadowColor,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: cat.buttonColor.withValues(alpha: 0.4),
                                    width: 2.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 122,
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        color: cat.themeColor,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(19),
                                          bottomLeft: Radius.circular(19),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(19),
                                        ),
                                        child: Image.asset(
                                          cat.cardImagePath,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.image_rounded,
                                            size: 48,
                                            color: cat.buttonColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  cat.titleTh,
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF0F172A),
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'ฝึกทายคำศัพท์ภาษาอังกฤษ',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: cat.shadowColor,
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              padding: const EdgeInsets.only(bottom: 3.5),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                decoration: BoxDecoration(
                                                  color: cat.buttonColor,
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'เริ่มเล่นเลย',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    SizedBox(width: 6),
                                                    Icon(
                                                      Icons.play_arrow_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
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
                              ),
                            ),
                                if (badge != null)
                                  Positioned(top: 10, right: 12, child: badge),
                              ],
                            ),
                          ),
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
    );
  }
}