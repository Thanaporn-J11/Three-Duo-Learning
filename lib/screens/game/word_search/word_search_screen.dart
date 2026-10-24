import 'package:flutter/material.dart';
import '../../../services/word_search_progress_service.dart';
import '../../../widgets/coin_balance_chip.dart';
import 'word_search_data.dart';
import 'word_search_play_screen.dart';

export 'word_search_data.dart' show WordSearchCategoryItem, wordSearchCategories;

class WordSearchScreen extends StatefulWidget {
  const WordSearchScreen({super.key});

  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  static const List<WordSearchCategoryItem> categories = wordSearchCategories;

  /// For the badges: unfinished games and finished categories.
  Map<String, ({int done, int total})> _unfinished = {};
  Map<String, int> _best = {};

  @override
  void initState() {
    super.initState();
    _loadBadges();
    // Progress saved on the server (e.g. another phone), then refresh.
    WordSearchProgress.sync().then((_) => _loadBadges());
    WordSearchCoins.flush(); // coins of words found while offline
  }

  Map<String, Set<String>> get _wordsByCategory => {
    for (final c in categories) c.key: c.answers,
  };

  Future<void> _loadBadges() async {
    final unfinished = await WordSearchProgress.unfinished(_wordsByCategory);
    final best = await WordSearchProgress.bestScores();
    if (!mounted) return;
    setState(() {
      _unfinished = unfinished;
      _best = best;
    });
  }

  Future<void> _open(WordSearchCategoryItem category) async {
    final saved = await WordSearchProgress.load(category.key, category.answers);
    if (!mounted) return;
    WordSearchRound? resume;
    if (saved != null) {
      final choice = await _askResume(category, saved);
      if (!mounted || choice == null) return;
      if (choice) {
        resume = saved;
      } else {
        await WordSearchProgress.clear(category.key);
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordSearchPlayScreen(category: category, resume: resume),
      ),
    );
    _loadBadges();
  }

  Future<bool?> _askResume(WordSearchCategoryItem category, WordSearchRound saved) {
    final color = category.shadowColor;
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
              'เล่นค้างไว้ หาเจอแล้ว ${saved.found.length} จาก ${saved.total} คำ\n'
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
  Widget? _badge(WordSearchCategoryItem category) {
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
    const topBarColor = Color(0xFFE65100);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFCCBC),
              Color(0xFFFFF3E0),
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
                          'ค้นหาคำศัพท์',
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
                      padding: EdgeInsets.fromLTRB(24, 18, 24, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ค้นหาคำศัพท์แสนสนุก',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE65100),
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
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: 0.95,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final cat = categories[index];
                          return _CategoryFilledCard(
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

class _CategoryFilledCard extends StatefulWidget {
  final WordSearchCategoryItem category;
  final Widget? badge;
  final VoidCallback onTap;

  const _CategoryFilledCard({
    required this.category,
    required this.onTap,
    this.badge,
  });

  @override
  State<_CategoryFilledCard> createState() => _CategoryFilledCardState();
}

class _CategoryFilledCardState extends State<_CategoryFilledCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: cat.shadowColor,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            decoration: BoxDecoration(
              color: cat.cardColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -14,
                  right: -14,
                  child: Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 86,
                          height: 86,
                          child: Image.asset(
                            cat.cardImagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.extension_rounded,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cat.titleTh,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 1.5),
                                blurRadius: 2.5,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.badge != null)
                  Positioned(top: 10, right: 10, child: widget.badge!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}