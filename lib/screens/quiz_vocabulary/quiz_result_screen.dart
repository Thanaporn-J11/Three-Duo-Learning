import 'package:flutter/material.dart';
import '../../widgets/coin_balance_chip.dart';

class QuizResultScreen extends StatefulWidget {
  final int totalScore;
  final int totalQuestions;
  final int coinsAwarded;

  const QuizResultScreen({
    super.key,
    required this.totalScore,
    required this.totalQuestions,
    required this.coinsAwarded,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _star1;
  late final Animation<double> _star2;
  late final Animation<double> _star3;
  late final Animation<Offset> _slideUp;

  int get _percentage => widget.totalQuestions == 0
      ? 0
      : ((widget.totalScore / widget.totalQuestions) * 100).toInt();

  // จำนวนดาวที่ได้ตามเปอร์เซ็นต์ (อย่างน้อย 1 ดวง)
  int get _starCount => _percentage >= 80 ? 3 : (_percentage >= 50 ? 2 : 1);

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _scaleAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.35, 0.85, curve: Curves.easeIn),
    );
    _star1 = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.30, 0.60, curve: Curves.easeOutBack),
    );
    _star2 = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.42, 0.72, curve: Curves.easeOutBack),
    );
    _star3 = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.54, 0.84, curve: Curves.easeOutBack),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4FD1FF), Color(0xFF00A2FF), Color(0xFF0070DD)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // วงกลมตกแต่งพื้นหลัง
            Positioned(
              top: -70,
              right: -60,
              child: _DecorativeCircle(
                size: 270,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              top: 260,
              left: -90,
              child: _DecorativeCircle(
                size: 200,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              bottom: 150,
              right: -80,
              child: _DecorativeCircle(
                size: 200,
                color: const Color(0xFFB3E5FC).withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -70,
              child: _DecorativeCircle(
                size: 260,
                color: const Color(0xFFB3E5FC).withValues(alpha: 0.16),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                child: Column(
                  children: [
                    // Coins now (includes the ones just earned).
                    const Align(
                      alignment: Alignment.centerRight,
                      child: CoinBalanceChip(),
                    ),
                    // โซนกลาง: ตัวละคร + ดาว + หัวข้อ
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width - 44,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildHero(),
                                const SizedBox(height: 14),
                                _buildStars(),
                                const SizedBox(height: 10),
                                _buildHeadline(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // โซนล่าง: การ์ดสถิติ + ปุ่ม
                    SlideTransition(
                      position: _slideUp,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            _buildStatsRow(),
                            const SizedBox(height: 22),
                            _GameButton(
                              height: 62,
                              color: const Color(0xFFFF9800),
                              shadowColor: const Color(0xFFE65100),
                              onTap: () => Navigator.pop(context),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.home_rounded,
                                      color: Colors.white, size: 26),
                                  SizedBox(width: 10),
                                  Text(
                                    'รับคะแนน & กลับหน้าหลัก',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Hero ─────────────────────────
  Widget _buildHero() {
    return SizedBox(
      height: 350,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // วงแสงด้านหลังตัวละคร
          ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.50),
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // เงาใต้ตัวละคร
          Positioned(
            bottom: 10,
            child: Container(
              width: 170,
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: Colors.black.withValues(alpha: 0.10),
              ),
            ),
          ),

          // ตัวละคร
          ScaleTransition(
            scale: _scaleAnim,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              // รูปมีขอบโปร่งใสรอบตัว จึงขยายด้วย Transform.scale ให้ตัวนกฮูกใหญ่ขึ้น
              child: Transform.scale(
                scale: 1.4,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 300, maxWidth: 340),
                  child: Image.asset(
                    'assets/images/character/bravo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.stars_rounded,
                      size: 140,
                      color: Colors.white,
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

  // ───────────────────────── Stars ─────────────────────────
  Widget _buildStars() {
    Widget star(Animation<double> a, double size, double dy, bool filled) {
      return ScaleTransition(
        scale: a,
        child: Transform.translate(
          offset: Offset(0, dy),
          child: Icon(
            Icons.star_rounded,
            size: size,
            color: filled
                ? const Color(0xFFFFD54F)
                : Colors.white.withValues(alpha: 0.35),
            shadows: filled
                ? const [
                    Shadow(
                      color: Color(0x66E65100),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        star(_star1, 34, 4, _starCount >= 1),
        const SizedBox(width: 4),
        star(_star2, 48, -2, _starCount >= 3 || _starCount == 2),
        const SizedBox(width: 4),
        star(_star3, 34, 4, _starCount >= 3),
      ],
    );
  }

  // ───────────────────────── Headline ─────────────────────────
  Widget _buildHeadline() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          const Text(
            'เก่งมาก ยอดเยี่ยม',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 3),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'คุณทำแบบฝึกหัดครบเรียบร้อยแล้ว',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Stats ─────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.monetization_on_rounded,
            iconColor: const Color(0xFFFFA000),
            label: 'เหรียญที่ได้รับ',
            end: widget.coinsAwarded.toDouble(),
            prefix: '+',
            gradient: const [Color(0xFFB388FF), Color(0xFF7C4DFF)],
            edgeColor: const Color(0xFF4A2BC4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFFFF4F9A),
            label: 'ความแม่นยำ',
            end: _percentage.toDouble(),
            suffix: '%',
            gradient: const [Color(0xFFFF8AC4), Color(0xFFFF4F9A)],
            edgeColor: const Color(0xFFC21F6B),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Widgets ย่อย ─────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double end;
  final String prefix;
  final String suffix;
  final List<Color> gradient;
  final Color edgeColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.end,
    required this.gradient,
    required this.edgeColor,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: edgeColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: edgeColor.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: edgeColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            // ตัวเลขนับขึ้นครั้งเดียวตอนเข้าหน้า
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: end),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                '$prefix${value.round()}$suffix',
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                shadows: const [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 1),
                    blurRadius: 3,
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

/// ปุ่ม 3D สไตล์เกม กดแล้วจมลง
class _GameButton extends StatefulWidget {
  final VoidCallback onTap;
  final double height;
  final Color color;
  final Color shadowColor;
  final Widget child;

  const _GameButton({
    required this.onTap,
    required this.height,
    required this.color,
    required this.shadowColor,
    required this.child,
  });

  @override
  State<_GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<_GameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const depth = 5.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: SizedBox(
        height: widget.height + depth,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: widget.height,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.shadowColor,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 80),
              left: 0,
              right: 0,
              top: _pressed ? depth : 0,
              height: widget.height,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(widget.color, Colors.white, 0.18)!,
                      widget.color,
                    ],
                  ),
                ),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
