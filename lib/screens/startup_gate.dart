import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/session_service.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

/// First screen when the app opens: still signed in -> straight to the home
/// screen; otherwise -> the welcome / sign-in screens.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  /// Show this screen at least this long, so the name and logo are seen
  /// (checking the sign-in is usually much quicker).
  static const Duration _minShow = Duration(milliseconds: 3000);

  Future<void> _decide() async {
    final shownFor = Future<void>.delayed(_minShow);
    SessionStatus status;
    try {
      status = await SessionService.restore();
    } catch (_) {
      status = SessionStatus.signedOut;
    }
    await shownFor;
    if (!mounted) return;
    final Widget next =
        status == SessionStatus.signedOut
            ? const WelcomeScreen()
            : const HomeScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => next,
        transitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder:
            (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Light-blue gradient. The middle colour is the Android splash colour
        // and the logo is the same size in the same place (exact centre), so
        // the system splash turns into this screen without a jump.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF7FF), Color(0xFFD6EEFF), Color(0xFFB8E1FF)],
          ),
        ),
        child: Column(
          children: [
            const Spacer(),
            // Square app logo with rounded corners
            ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Image.asset(
                'assets/images/character/app_logo_hd.png',
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => const SizedBox(
                      width: 150,
                      height: 150,
                      child: Icon(
                        Icons.school_rounded,
                        size: 80,
                        color: Color(0xFF2F6FE4),
                      ),
                    ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 22),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'ThreeDuo ',
                          style: GoogleFonts.fredoka(
                            color: const Color(0xFF2F6FE4),
                          ),
                        ),
                        TextSpan(
                          text: 'Learning',
                          style: GoogleFonts.fredoka(
                            color: const Color(0xFFFF8A3D),
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fredoka(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'เรียนภาษาอังกฤษสนุก ๆ ทุกวัน',
                    style: GoogleFonts.mitr(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF3A5F8F),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF2F6FE4),
                    ),
                  ),
                  const SizedBox(height: 56),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
