import 'package:flutter/material.dart';
import 'match_screen.dart';

enum GameDifficulty { easy, medium, hard }

class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> levels = const [
    {
      'difficulty': GameDifficulty.easy,
      'title': 'Easy (ระดับเริ่มต้น)',
      'subtitle': 'เหมาะสำหรับ ป.1 - ป.2 (คำศัพท์พื้นฐาน 3 คู่)',
      'color': Color(0xFF4CAF50),
      'shadowColor': Color(0xFF2E7D32),
      'icon': Icons.sentiment_very_satisfied_rounded,
      'coins': 15,
    },
    {
      'difficulty': GameDifficulty.medium,
      'title': 'Medium (ระดับกลาง)',
      'subtitle': 'เหมาะสำหรับ ป.3 - ป.4 (คำศัพท์ทั่วไป 4 คู่)',
      'color': Color(0xFF0088FF),
      'shadowColor': Color(0xFF00569E),
      'icon': Icons.military_tech_rounded,
      'coins': 25,
    },
    {
      'difficulty': GameDifficulty.hard,
      'title': 'Hard (ระดับท้าทาย)',
      'subtitle': 'เหมาะสำหรับ ป.5 - ป.6 (คำศัพท์ยาว/คำผสม 6 คู่)',
      'color': Color(0xFFFF7043),
      'shadowColor': Color(0xFFD84315),
      'icon': Icons.local_fire_department_rounded,
      'coins': 40,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF00569E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Difficulty',
          style: TextStyle(
            color: Color(0xFF00569E),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'เลือกระดับความยากที่เหมาะกับคุณ:',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: levels.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    final level = levels[index];
                    final Color color = level['color'];
                    final Color shadowColor = level['shadowColor'];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MatchScreen(
                              difficulty: level['difficulty'] as GameDifficulty,
                              rewardCoins: level['coins'] as int,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: shadowColor.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(level['icon'], color: Colors.white, size: 34),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    level['title'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    level['subtitle'],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        '+${level['coins']} Coins',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}