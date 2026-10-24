import 'package:flutter/material.dart';
import 'minimal_pairs_screen.dart';
import 'video_fill_blank_screen.dart';
import 'karaoke_record_screen.dart';
import '../../services/lesson_progress.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({Key? key}) : super(key: key);

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  static const Color headerPink = Color(0xFFFF146A);

  // "เล่นต่อ ข้อ x/y" for the minimal-pairs game (20 questions).
  ({int index, int correct})? _minimalPairsProgress;
  static const int _minimalPairsTotal = 20;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final saved = await LessonProgress.load(
      'minimal_pairs',
      _minimalPairsTotal,
    );
    if (mounted) setState(() => _minimalPairsProgress = saved);
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menuItems = [
      {
        'title': 'ฟังแยกเสียงคำศัพท์',
        'subtitle': 'Minimal Pairs',
        'image': 'assets/images/sentence/earphones.png',
        'gradient': const [Color(0xFFFFA452), Color(0xFFFF7E36)],
        'shadowColor': const Color(0xFFC75210),
        'accentColor': const Color(0xFFFF6D1B),
        'textShadowColor': const Color(0xFFC75210), // เงาคมสีส้มเข้ม
        'screen': const MinimalPairsScreen(),
        'badge':
            _minimalPairsProgress == null
                ? null
                : 'เล่นต่อ ข้อ ${_minimalPairsProgress!.index + 1} / $_minimalPairsTotal',
      },
      {
        'title': 'ฟังเสียงเติมคำ',
        'subtitle': 'Video Fill Blank',
        'image': 'assets/images/sentence/play.png',
        'gradient': const [Color(0xFFE91E63), Color(0xFFC2185B)],
        'shadowColor': const Color(0xFF880E4F),
        'accentColor': const Color(0xFFAD1457),
        'textShadowColor': const Color(0xFF560027),
        'screen': const VideoFillBlankScreen(),
      },
      {
        'title': 'คาราโอเกะเพลง',
        'subtitle': 'Sing & Record',
        'image': 'assets/images/sentence/microphone.png',
        'gradient': const [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
        'shadowColor': const Color(0xFF6D28D9),
        'accentColor': const Color(0xFF7C3AED),
        'textShadowColor': const Color(0xFF5B21B6), // เงาคมสีม่วงเข้ม
        'screen': const KaraokeRecordScreen(),
      },
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDE2E8),
              Color(0xFFFCE4EC),
              Color(0xFFF8BBD0),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Column(
          children: [
            // 1. Header สีชมพู
            Container(
              color: headerPink,
              width: double.infinity,
              child: SafeArea(
                bottom: false,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'ฝึกฟัง',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 38),
                    ],
                  ),
                ),
              ),
            ),

            // 2. เนื้อหาการ์ด & ปรับ Spacing กระจายตัวเต็มหน้าจอ
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                physics: const BouncingScrollPhysics(),
                children: [
                  const Text(
                    'พร้อมฝึกฟังกันหรือยัง ?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF33092B),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'แตะกิจกรรมที่ต้องการเรียนรู้ได้เลย',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A6B80),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // รายการการ์ดทั้ง 3 ด่าน (ระยะห่าง 24px)
                  ...menuItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _buildLessonCard(
                        context: context,
                        title: item['title'] as String,
                        subtitle: item['subtitle'] as String,
                        imagePath: item['image'] as String,
                        gradient: item['gradient'] as List<Color>,
                        shadowColor: item['shadowColor'] as Color,
                        accentColor: item['accentColor'] as Color,
                        textShadowColor: item['textShadowColor'] as Color,
                        badge: item['badge'] as String?,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => item['screen'] as Widget),
                          );
                          _loadProgress(); // refresh the "continue" badge
                        },
                      ),
                    );
                  }),

                  // การ์ดคำแนะนำด้านล่าง (ใส่หูฟัง)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFFFCCD9),
                        width: 1.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: headerPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'i',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'ใส่หูฟังและอยู่ในที่เงียบ จะช่วยให้ได้ยินเสียงชัดขึ้น',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2B0A25),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildLessonCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String imagePath,
    required List<Color> gradient,
    required Color shadowColor,
    required Color accentColor,
    required Color textShadowColor,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130, // เพิ่มความสูงเล็กน้อยเพื่อความโปร่ง
        decoration: BoxDecoration(
          color: shadowColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.38),
              offset: const Offset(0, 7),
              blurRadius: 12,
            ),
          ],
        ),
        padding: const EdgeInsets.only(bottom: 7.5),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              children: [
                Positioned(
                  right: -25,
                  bottom: -35,
                  child: Container(
                    width: 155,
                    height: 155,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // รูปภาพฝั่งซ้าย
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // ข้อความ 2 บรรทัดพร้อมเงาคมชัดสไตล์การ์ตูน
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.2,
                                shadows: [
                                  Shadow(
                                    color: textShadowColor,
                                    offset: const Offset(0, 2),
                                    blurRadius: 0, // เงาคมกริบ ไม่ฟุ้งดำ
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.95),
                                letterSpacing: 0.2,
                                shadows: [
                                  Shadow(
                                    color: textShadowColor.withValues(alpha: 0.8),
                                    offset: const Offset(0, 1.2),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(height: 6),
                              // "Continue" badge in the card's own colour
                              Container(
                                padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: shadowColor.withValues(alpha: 0.6),
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_circle_fill_rounded,
                                      size: 16,
                                      color: shadowColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      badge,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: shadowColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // ปุ่มลูกศร 3D สีขาวนูน
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.only(bottom: 3.5),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: accentColor,
                            size: 18,
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
      ),
    );
  }
}