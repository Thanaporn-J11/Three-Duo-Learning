import 'package:flutter/material.dart';
import '../../widgets/coin_balance_chip.dart';
import '../../models/quiz_vocabulary_item.dart';
import '../../services/exercise_api_service.dart';
import 'quiz_result_screen.dart';
import 'vocabulary_quiz_screen.dart';

class GraduationScreen extends StatefulWidget {
  final String categoryTitle;
  final String categorySlug;
  final List<QuizItem> quizItems;

  const GraduationScreen({
    super.key,
    required this.categoryTitle,
    required this.categorySlug,
    required this.quizItems,
  });

  @override
  State<GraduationScreen> createState() => _GraduationScreenState();
}

class _GraduationScreenState extends State<GraduationScreen>
    with TickerProviderStateMixin {
  bool _isStarting = false;
  String? _startError;
  String? _idempotencyKey;
  late final AnimationController _entryController;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _star1;
  late final Animation<double> _star2;
  late final Animation<double> _star3;
  late final Animation<Offset> _slideUp;

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

  Future<void> _startQuiz() async {
    if (_isStarting) return;
    setState(() {
      _isStarting = true;
      _startError = null;
      _idempotencyKey ??= ExerciseApiService.newIdempotencyKey();
    });
    try {
      final attempt = await ExerciseApiService.startAttempt(
        categorySlug: widget.categorySlug,
        idempotencyKey: _idempotencyKey!,
      );
      final loadedAttempt = await ExerciseApiService.getAttempt(attempt.id);
      if (!mounted) return;
      if (loadedAttempt.categorySlug != widget.categorySlug) {
        throw const ExerciseApiException('แบบทดสอบที่ได้รับไม่ตรงกับหมวดคำศัพท์');
      }
      if (loadedAttempt.status == 'expired') {
        throw const ExerciseApiException(
          'แบบทดสอบหมดเวลาแล้ว กรุณาเริ่มใหม่',
          code: 'ATTEMPT_EXPIRED',
          statusCode: 410,
        );
      }
      if (loadedAttempt.status == 'completed') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizResultScreen(
              totalScore: loadedAttempt.score ?? 0,
              totalQuestions: loadedAttempt.totalQuestions ?? loadedAttempt.questionCount,
              coinsAwarded: loadedAttempt.coinsAwarded ?? 0,
            ),
          ),
        );
        return;
      }
      if (loadedAttempt.status != 'in_progress') {
        throw const ExerciseApiException('แบบทดสอบไม่อยู่ในสถานะที่เริ่มทำได้');
      }
      if (loadedAttempt.questions.length != loadedAttempt.questionCount) {
        throw const ExerciseApiException('ข้อมูลจำนวนข้อสอบจากเซิร์ฟเวอร์ไม่ครบถ้วน');
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VocabularyQuizScreen(
            categoryTitle: widget.categoryTitle,
            attempt: loadedAttempt,
          ),
        ),
      );
    } on ExerciseApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _startError = error.message;
        if (error.code == 'ATTEMPT_EXPIRED' || error.statusCode == 410) {
          _idempotencyKey = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _startError = 'เริ่มแบบทดสอบไม่ได้ กรุณาลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
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
            colors: [
              Color(0xFF4FD1FF),
              Color(0xFF00A2FF),
              Color(0xFF0070DD),
            ],
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
                color: Colors.white.withOpacity(0.16),
              ),
            ),
            Positioned(
              top: 260,
              left: -90,
              child: _DecorativeCircle(
                size: 200,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -70,
              child: _DecorativeCircle(
                size: 280,
                color: const Color(0xFFB3E5FC).withOpacity(0.14),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -70,
              child: _DecorativeCircle(
                size: 220,
                color: const Color(0xFFB3E5FC).withOpacity(0.14),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                child: Column(
                  children: [
                    _buildTopBar(),

                    // โซนกลาง: ตัวละคร + หัวข้อ + คำอธิบาย
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
                                const SizedBox(height: 18),
                                _buildStars(),
                                const SizedBox(height: 10),
                                _buildHeadline(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // โซนล่าง: สถิติ + ปุ่ม
                    SlideTransition(
                      position: _slideUp,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            _buildStatsRow(),
                            const SizedBox(height: 22),
                            if (_startError != null) ...[
                              Text(
                                _startError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            _buildPrimaryButton(),
                            const SizedBox(height: 12),
                            _buildSecondaryButton(),
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

  // ───────────────────────── Top bar ─────────────────────────
  Widget _buildTopBar() {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ปุ่มย้อนกลับ (ขาว มน มีขอบ 3D เล็ก ๆ)
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFB3E5FC),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF0091EA),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Align(
            alignment: Alignment.centerRight,
            child: CoinBalanceChip(),
          ),

          // ชื่อหมวด อยู่กึ่งกลางจริง ๆ + ดาวน่ารักสองข้าง
          Padding(
            // Room for the back button (left) and the coins (right).
            padding: const EdgeInsets.symmetric(horizontal: CoinBalanceChip.width + 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'หมวด${widget.categoryTitle}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                  letterSpacing: 0.2,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 6,
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
    );
  }

  // ───────────────────────── Hero ─────────────────────────
  Widget _buildHero() {
    return SizedBox(
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // วงแสงด้านหลังตัวละคร
          ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.50),
                    Colors.white.withOpacity(0.18),
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // เงาใต้ตัวละคร
          Positioned(
            bottom: 14,
            child: Container(
              width: 140,
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: Colors.black.withOpacity(0.10),
              ),
            ),
          ),

          // ตัวละคร (อยู่นิ่ง)
          ScaleTransition(
            scale: _scaleAnim,
            child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 240, maxWidth: 330),
                  child: Image.asset(
                    'assets/images/character/friend_3.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      width: 260,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.auto_stories_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
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
    Widget star(Animation<double> a, double size, double dy) {
      return ScaleTransition(
        scale: a,
        child: Transform.translate(
          offset: Offset(0, dy),
          child: Icon(
            Icons.star_rounded,
            size: size,
            color: const Color(0xFFFFD54F),
            shadows: const [
              Shadow(
                color: Color(0x66E65100),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        star(_star1, 34, 4),
        const SizedBox(width: 4),
        star(_star2, 48, -2),
        const SizedBox(width: 4),
        star(_star3, 34, 4),
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
            'ยอดเยี่ยมมาก !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
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
          const SizedBox(height: 10),
          Text(
            'คุณเรียนรู้คำศัพท์ครบทุกคำแล้ว\nพร้อมทดสอบความจำในด่านต่อไปหรือยัง ?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.95),
              height: 1.5,
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
            icon: Icons.task_alt_rounded,
            label: 'สถานะ',
            value: 'ผ่านครบแล้ว',
            gradient: const [Color(0xFFB388FF), Color(0xFF7C4DFF)],
            edgeColor: const Color(0xFF4A2BC4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.quiz_rounded,
            label: 'แบบทดสอบ',
            // The quiz itself comes from the server, which always picks
            // 10 questions (the local list can be shorter, e.g. 7 days).
            value: '10 ข้อ',
            gradient: const [Color(0xFFFF8AC4), Color(0xFFFF4F9A)],
            edgeColor: const Color(0xFFC21F6B),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Buttons ─────────────────────────
  Widget _buildPrimaryButton() {
    return _GameButton(
      onTap: _isStarting ? () {} : _startQuiz,
      height: 62,
      color: const Color(0xFFFF9800),
      shadowColor: const Color(0xFFE65100),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isStarting) ...[
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Text('กำลังโหลดข้อสอบ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ] else ...[
            Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 26),
            SizedBox(width: 10),
            Text(
              'เริ่มทำแบบฝึกหัด',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecondaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.replay_rounded, size: 18),
        label: const Text(
          'กลับไปดูคำศัพท์อีกรอบ',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.12),
          side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Widgets ย่อย ─────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;
  final Color edgeColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
    required this.edgeColor,
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
            color: edgeColor.withOpacity(0.45),
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
          border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
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
                    color: edgeColor.withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: edgeColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
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
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
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
            // ฐานปุ่ม (เงา 3D)
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
            // หน้าปุ่ม
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
