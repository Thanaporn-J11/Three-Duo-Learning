import 'package:flutter/material.dart';
import '../../models/quiz_vocabulary_item.dart';
import 'vocabulary_quiz_screen.dart';

class GraduationScreen extends StatefulWidget {
  final String categoryTitle;
  final List<QuizItem> quizItems;

  const GraduationScreen({
    super.key,
    required this.categoryTitle,
    required this.quizItems,
  });

  @override
  State<GraduationScreen> createState() => _GraduationScreenState();
}

class _GraduationScreenState extends State<GraduationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0088FF);
    const darkBlue = Color(0xFF0C4A7A);
    const softBlue = Color(0xFF5A789A);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE7F3FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
          children: [
            // Decorative glow — top right
            Positioned(
              top: -70,
              right: -60,
              child: _Glow(size: 220, color: primaryBlue.withOpacity(0.18)),
            ),
            // Decorative glow — top left, smaller
            Positioned(
              top: 40,
              left: -50,
              child: _Glow(size: 120, color: const Color(0xFF60B5FF).withOpacity(0.15)),
            ),
            // Decorative glow — bottom left
            Positioned(
              bottom: -80,
              left: -60,
              child: _Glow(size: 200, color: primaryBlue.withOpacity(0.10)),
            ),

            // Floating "study" motifs scattered around, English-learning theme
            const Positioned(top: 90, left: 28, child: _FloatingGlyph(text: 'A', angle: -0.15)),
            const Positioned(top: 130, right: 34, child: _FloatingGlyph(text: 'B', angle: 0.2)),
            const Positioned(top: 250, left: 18, child: _FloatingGlyph(text: '★', angle: -0.1, size: 16)),
            const Positioned(top: 210, right: 20, child: _FloatingGlyph(text: '✓', angle: 0.15, size: 16)),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      const Spacer(flex: 3),

                      // Character with layered glow ring
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: Center(
                          child: Container(
                            width: 250,
                            height: 250,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  primaryBlue.withOpacity(0.55),
                                  const Color(0xFF60B5FF).withOpacity(0.15),
                                ],
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryBlue.withOpacity(0.20),
                                    blurRadius: 36,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/character/bravo.png',
                                  height: 185,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.school_rounded,
                                    size: 96,
                                    color: primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // "Success" pill badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryBlue.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded, size: 16, color: primaryBlue),
                            const SizedBox(width: 6),
                            Text(
                              'เรียนจบหมวดแล้ว',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: primaryBlue.withOpacity(0.9),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'เย้ ยินดีด้วย',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: darkBlue,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        'ไปทำแบบฝึกหัดทดสอบความรู้กันเถอะ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: softBlue,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: primaryBlue.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 15, color: primaryBlue),
                            const SizedBox(width: 6),
                            Text(
                              'หมวด${widget.categoryTitle}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: darkBlue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 4),

                      // Start Button
                      Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(29),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFF0088FF), Color(0xFF3DA4FF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryBlue.withOpacity(0.38),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(29),
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VocabularyQuizScreen(
                                    categoryTitle: widget.categoryTitle,
                                    quizItems: widget.quizItems,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'เริ่มทำแบบฝึกหัด',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                SizedBox(width: 8),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft round glow used as a decorative background element.
class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// A small tilted glyph (letter, star, checkmark) used to add a light,
/// playful "learning" motif around the character illustration.
class _FloatingGlyph extends StatelessWidget {
  final String text;
  final double angle;
  final double size;

  const _FloatingGlyph({
    required this.text,
    required this.angle,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0088FF).withOpacity(0.28),
        ),
      ),
    );
  }
}