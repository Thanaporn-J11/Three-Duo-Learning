import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ---------------- Background ----------------
          Positioned.fill(
            child: Image.asset(
              "assets/images/background_1.png",
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xff5FB5F7).withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.04),
                    const Color(0xffEAF7FF).withValues(alpha: 0.20),
                  ],
                ),
              ),
            ),
          ),

          // ---------------- Decorative bubbles ----------------
          Positioned(
            top: -55,
            right: -45,
            child: _DecorCircle(
              size: 150,
              color: const Color(0xff7EBBFF).withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: size.height * 0.30,
            left: -55,
            child: _DecorCircle(
              size: 105,
              color: const Color(0xffFFD36A).withValues(alpha: 0.18),
            ),
          ),

          // ---------------- Content ----------------
          Column(
            children: [
              // ---------- Mascot area ----------
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final mascotSize = math.min(
                        size.width * 0.92,
                        constraints.maxHeight - 24,
                      );
                      return Center(child: _Mascot(size: mascotSize));
                    },
                  ),
                ),
              ),

              // ---------- Bottom sheet (กระจกฝ้าโค้ง) ----------
              const _BottomPanel(),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Bottom Panel
// ============================================================

class _BottomPanel extends StatelessWidget {
  const _BottomPanel();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final minHeight = MediaQuery.of(context).size.height * 0.44;
    const radius = BorderRadius.vertical(top: Radius.circular(38));

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xff4D7CFE).withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: minHeight),
            alignment: Alignment.center,
            padding: EdgeInsets.fromLTRB(24, 36, 24, 18 + bottomInset),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.74),
                  Colors.white.withValues(alpha: 0.48),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---------- App name ----------
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    children: [
                      TextSpan(
                        text: "ThreeDuo ",
                        style: TextStyle(color: Color(0xff3977FF)),
                      ),
                      TextSpan(
                        text: "Learning",
                        style: TextStyle(color: Color(0xffFF9F1C)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "สนุกทุกวันกับการฝึกภาษาอังกฤษ",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xff4A5170),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // ---------- Feature chips ----------
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FeatureChip(
                      icon: Icons.menu_book_rounded,
                      label: "คำศัพท์",
                      color: Color(0xff3D6EF7),
                    ),
                    _FeatureChip(
                      icon: Icons.mic_rounded,
                      label: "ออกเสียง",
                      color: Color(0xff12B5A0),
                    ),
                    _FeatureChip(
                      icon: Icons.emoji_events_rounded,
                      label: "เกมทายคำ",
                      color: Color(0xffF5A623),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // ---------- Start button ----------
                _GradientButton(
                  label: "เริ่มต้นใช้งาน",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // ---------- Register ----------
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xff5C6478),
                      ),
                      children: [
                        TextSpan(text: "ยังไม่มีบัญชี? "),
                        TextSpan(
                          text: "สร้างบัญชีใหม่",
                          style: TextStyle(
                            color: Color(0xff3D6EF7),
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xff3D6EF7),
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
      ),
    );
  }
}

// ============================================================
// Mascot
// ============================================================

class _Mascot extends StatelessWidget {
  final double size;
  const _Mascot({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // glow
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.6),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: const Color(0xff4D9FFF).withValues(alpha: 0.20),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          // ก้อนเมฆใต้ตัวน้อง
          Positioned(
            bottom: size * 0.01,
            child: _Cloud(width: size * 0.86),
          ),

          Image.asset(
            "assets/images/normal.png",
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.flutter_dash,
              size: size * 0.7,
              color: const Color(0xff4D7CFE),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Cloud (ก้อนเมฆให้น้องยืน)
// ============================================================

class _Cloud extends StatelessWidget {
  final double width;
  const _Cloud({required this.width});

  @override
  Widget build(BuildContext context) {
    final cloudColor = Colors.white.withValues(alpha: 0.92);

    Widget puff(double d) => Container(
          width: d,
          height: d,
          decoration: BoxDecoration(color: cloudColor, shape: BoxShape.circle),
        );

    return SizedBox(
      width: width,
      height: width * 0.30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // เงานุ่มใต้เมฆ
          Positioned(
            left: width * 0.06,
            right: width * 0.06,
            bottom: 0,
            height: width * 0.12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff4D9FFF).withValues(alpha: 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),

          // ฐานเมฆ
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: width * 0.16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cloudColor,
                borderRadius: BorderRadius.circular(width),
              ),
            ),
          ),

          // ก้อนนูนด้านบน
          Positioned(left: width * 0.12, bottom: width * 0.09, child: puff(width * 0.20)),
          Positioned(left: width * 0.32, bottom: width * 0.09, child: puff(width * 0.30)),
          Positioned(right: width * 0.12, bottom: width * 0.09, child: puff(width * 0.22)),
        ],
      ),
    );
  }
}

// ============================================================
// Gradient Button
// ============================================================

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xff4D7CFE), Color(0xff6A5CFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff4D7CFE).withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Decorative Circle
// ============================================================

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ============================================================
// Feature Chip
// ============================================================

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}