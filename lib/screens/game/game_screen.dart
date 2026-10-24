import 'package:flutter/material.dart';

// Import หน้าเกมเดิม
import 'guess/guess_screen.dart';
import 'First Letter Game/lettergame.dart';
import 'AnimalSound/animalsound.dart';
import 'Alphabet Train/alphabet_train.dart';

// Import หน้าเกมเสริม
import 'shadowmatch/shadow_match_category_screen.dart';
import 'word_riddle/word_riddle_screen.dart';
import 'word_search/word_search_screen.dart';

// Import 3 เกมใหม่ (ใส่ alias ให้ BridgeBuilder เพื่อไม่ให้ชื่อคลาส LevelSelectScreen ชนกับ Alphabet Train)
import 'BridgeBuilder/bidge_builder.dart' as bridge;
import 'Mini Market/mini_market.dart';
import 'monster_battle_game/monster_battle_game.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // โทนสีเขียวหลักของแถบด้านบน (เรียบ Flat ไร้เงา)
  static const Color headerGreen = Color(0xFF10B981);

  final List<Map<String, dynamic>> gameItems = const [
    {
      'title': 'Guess',
      'label': 'ทายภาพ',
      'subtitle': 'นี่คือภาพอะไรนะ',
      'imagePath': 'assets/images/Background/gamepictureguessing.png',
      'icon': Icons.image_search_rounded,
      'bgGradient': [Color(0xFF4ADE80), Color(0xFF16A34A)],
      'borderDark': Color(0xFF14532D),
    },
    {
      'title': 'First Letter',
      'label': 'พยัญชนะต้น',
      'subtitle': 'ค้นหาอักษรตัวแรก',
      'imagePath': 'assets/images/Background/gameconsonant.png',
      'icon': Icons.text_fields_rounded,
      'bgGradient': [Color(0xFF38BDF8), Color(0xFF0284C7)],
      'borderDark': Color(0xFF075985),
    },
    {
      'title': 'Animal & Sound',
      'label': 'เสียงสัตว์',
      'subtitle': 'ฟังแล้วทายว่าเสียงใคร',
      'imagePath': 'assets/images/Background/gameanimalsounds.png',
      'icon': Icons.volume_up_rounded,
      'bgGradient': [Color(0xFFF59E0B), Color(0xFFD97706)],
      'borderDark': Color(0xFF92400E),
    },
    {
      'title': 'Alphabet Train',
      'label': 'งูน้อยฉลาดเลือก',
      'subtitle': 'ลากต่อขบวนอักษร',
      'imagePath': 'assets/images/Background/gamesnakes.png',
      'icon': Icons.directions_railway_rounded,
      'bgGradient': [Color(0xFFF43F5E), Color(0xFFE11D48)],
      'borderDark': Color(0xFF9F1239),
    },
    {
      'title': 'Shadow Match',
      'label': 'จับคู่เงา',
      'subtitle': 'โยงเส้นจับคู่เงาปริศนา',
      'imagePath': 'assets/images/Background/gameshadow.png',
      'icon': Icons.pets_rounded,
      'bgGradient': [Color(0xFFA78BFA), Color(0xFF7C3AED)],
      'borderDark': Color(0xFF4C1D95),
    },
    {
      'title': 'Word Riddle',
      'label': 'ปริศนาคำศัพท์',
      'subtitle': 'ทายคำตามคำบอกใบ้',
      'imagePath': 'assets/images/Background/gamecharades.png',
      'icon': Icons.lightbulb_rounded,
      'bgGradient': [Color(0xFF2DD4BF), Color(0xFF0D9488)],
      'borderDark': Color(0xFF134E4A),
    },
    {
      'title': 'Word Search',
      'label': 'ค้นหาคำศัพท์',
      'subtitle': 'ลากหาคำศัพท์ที่ซ่อนอยู่',
      'imagePath': 'assets/images/Background/gamelookupaword.png',
      'icon': Icons.grid_on_rounded,
      'bgGradient': [Color(0xFFFB923C), Color(0xFFEA580C)],
      'borderDark': Color(0xFF9A3412),
    },
    // 3 เกมใหม่
    {
      'title': 'Monster Maker',
      'label': 'มอนสเตอร์แบทเทิล',
      'subtitle': 'ประลองคำศัพท์กับมอนสเตอร์',
      'imagePath': 'assets/images/Background/gamemonstermaker.png',
      'icon': Icons.smart_toy_rounded,
      'bgGradient': [Color(0xFFF472B6), Color(0xFFDB2777)],
      'borderDark': Color(0xFF831843),
    },
    {
      'title': 'Mini Market',
      'label': 'มินิมาร์เก็ต',
      'subtitle': 'ช้อปปิ้งสนุกเรียนรู้คำศัพท์',
      'imagePath': 'assets/images/Background/gameminimarket.png',
      'icon': Icons.shopping_cart_rounded,
      'bgGradient': [Color(0xFFFDE047), Color(0xFFEAB308)],
      'borderDark': Color(0xFF854D0E),
    },
    {
      'title': 'Bridge Builder',
      'label': 'สร้างสะพาน',
      'subtitle': 'ต่อสะพานข้ามฟากแสนกล',
      'imagePath': 'assets/images/Background/gamebridgebuilder.png',
      'icon': Icons.deck_rounded,
      'bgGradient': [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      'borderDark': Color(0xFF1E3A8A),
    },
  ];

  void _navigateToGame(String title) {
    switch (title) {
      case 'Guess':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GuessScreen()),
        );
        break;
      case 'First Letter':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CategorySelectionScreen()),
        );
        break;
      case 'Animal & Sound':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnimalSound()),
        );
        break;
      case 'Alphabet Train':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AlphabetTrain()),
        );
        break;
      case 'Shadow Match':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShadowMatchCategoryScreen()),
        );
        break;
      case 'Word Riddle':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WordRiddleScreen()),
        );
        break;
      case 'Word Search':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WordSearchScreen()),
        );
        break;
      case 'Monster Maker':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DifficultySelectionScreen()),
        );
        break;
      case 'Mini Market':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MiniMarketScreen()),
        );
        break;
      case 'Bridge Builder':
        // ชี้ไปยังหน้าเลือกด่านของเกมสร้างสะพาน (ใช้ bridge.LevelSelectScreen)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const bridge.LevelSelectScreen()),
        );
        break;
    }
  }

  Widget _buildCartoonCard(Map<String, dynamic> item) {
    final List<Color> bgGradient = item['bgGradient'] as List<Color>;
    final Color borderDark = item['borderDark'] as Color;
    final String title = item['title'] as String;
    final String label = item['label'] as String;
    final String subtitle = item['subtitle'] as String;
    final String imagePath = item['imagePath'] as String;

    return InkWell(
      borderRadius: BorderRadius.circular(34),
      onTap: () => _navigateToGame(title),
      child: Container(
        height: 124,
        decoration: BoxDecoration(
          color: borderDark,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: borderDark.withValues(alpha: 0.35),
              offset: const Offset(0, 5),
              blurRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.only(bottom: 5.5),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: bgGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: borderDark,
              width: 3.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  left: -20,
                  right: -20,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.elliptical(250, 45),
                      ),
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    offset: Offset(0, 2),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 95,
                        height: 95,
                        child: Center(
                          child: Image.asset(
                            imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              item['icon'] as IconData,
                              size: 54,
                              color: Colors.white,
                            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: Column(
        children: [
          Container(
            color: headerGreen,
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
                        'เกม',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 38),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
              physics: const ClampingScrollPhysics(),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 6, bottom: 12),
                  child: Text(
                    'เลือกเกมที่อยากเล่น',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF14532D),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                ...gameItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _buildCartoonCard(item),
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