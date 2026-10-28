import 'package:flutter/material.dart';
import '../widgets/coin_balance_chip.dart';
import 'checkin_screen.dart';
import 'setting_screen.dart';
import 'category_vocabulary_screen.dart';
import 'profile_screen.dart';
import 'tale/tale_screen.dart';
import 'translate/translate_screen.dart';
import 'game/game_screen.dart';
import 'phonics/phonics_category_screen.dart'; // แก้ไข: ชี้ไปยังหน้าหมวดหมู่ Phonics
import 'listen/listen_screen.dart';
import '../services/sfx.dart';
import '../widgets/music_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    Sfx.welcomeOnce();
  }

  final items = const [
    {
      'title': 'คำศัพท์',
      'route': 'Vocabulary',
      'image': 'assets/images/Background/Vocabulary.png',
      'icon': Icons.menu_book,
      'color': Color(0xFFFF6658),
    },
    {
      'title': 'ฝึกออกเสียง',
      'route': 'Phonics',
      'image': 'assets/images/Background/phonics.png',
      'icon': Icons.record_voice_over_rounded,
      'color': Color(0xFFFFB928),
    },
    {
      'title': 'ฝึกฟัง',
      'route': 'Listen',
      'image': 'assets/images/Background/Listen.png',
      'icon': Icons.headphones_rounded,
      'color': Color(0xFFFF5286),
    },
    {
      'title': 'นิทาน',
      'route': 'Tale',
      'image': 'assets/images/Background/tale.png',
      'icon': Icons.auto_stories,
      'color': Color(0xFF9B6BE8),
    },
    {
      'title': 'แปลภาษา',
      'route': 'Translate',
      'image': 'assets/images/Background/translate.png',
      'icon': Icons.translate,
      'color': Color(0xFF399FE3),
    },
    {
      'title': 'เกม',
      'route': 'Game',
      'image': 'assets/images/Background/game.png',
      'icon': Icons.sports_esports,
      'color': Color(0xFF25B7A5),
    },
  ];

  void _onItemTapped(String title) {
    switch (title) {
      case 'Vocabulary':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CategoryVocabularyScreen(),
          ),
        );
        break;
      case 'Phonics':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PhonicsCategoryScreen(), // แก้ไข: เปิดหน้า 6 หมวดหมู่ Phonics ก่อน
          ),
        );
        break;
      case 'Listen':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ListenScreen(),
          ),
        );
        break;
      case 'Tale':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TaleScreen()),
        );
        break;
      case 'Translate':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TranslateScreen()),
        );
        break;
      case 'Game':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) =>
      MusicScope(child: _buildScreen(context));

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFFF8EF),
        title: const Text(
          "หมวดการเรียนรู้",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        leading: const Padding(
          padding: EdgeInsets.all(12),
          child: Text("🇹🇭", style: TextStyle(fontSize: 26)),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Center(child: CoinBalanceChip()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เลือกบทเรียนที่อยากเริ่มเรียน',
              style: TextStyle(
                color: Color(0xFF737B8C),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: .82,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final color = item['color'] as Color;
                  final title = item['title'] as String;
                  final route = item['route'] as String;
                  final paleColor = Color.alphaBlend(
                    color.withValues(alpha: .19),
                    Colors.white,
                  );
                  final lighterColor = Color.alphaBlend(
                    color.withValues(alpha: .11),
                    Colors.white,
                  );

                  // The shadow sits outside the Material: inside it, the shadow
                  // was clipped to the card's rectangle (faint square corners).
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: .16),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                    color: paleColor,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _onItemTapped(route),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [paleColor, lighterColor],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: color.withValues(alpha: .34),
                            width: 1.2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 12,
                              right: 13,
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 17,
                                color: color.withValues(alpha: .42),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              top: 22,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .35),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: SizedBox(
                                        width: 148,
                                        height: 132,
                                        child: Image.asset(
                                          item['image'] as String,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) => Icon(
                                            item['icon'] as IconData,
                                            color: color,
                                            size: 54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF26334A),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: ElevatedButton(
                                      onPressed: () => _onItemTapped(route),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: color,
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        shadowColor: color.withValues(alpha: .25),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(13),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      child: const Text('เริ่มต้น'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ));
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4D7CFE),
        unselectedItemColor: const Color(0xFF94A3B8),
        onTap: (index) {
          if (index == currentIndex) return;

          if (index == 0) return;

          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CheckInScreen()),
            );
          }

          if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SettingScreen()),
            );
          }

          if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "หน้าหลัก"),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), label: "เช็คอิน"),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: "ตั้งค่า"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "โปรไฟล์"),
        ],
      ),
    );
  }
}