import 'package:flutter/material.dart';
import 'fruit_flashcards_screen.dart';
import 'sport_flashcards_screen.dart';
import 'animals_flashcards_screen.dart';
import 'occupations_flashcards_screen.dart';
import 'vehicle_flashcards_screen.dart';
import 'places_flashcards_screen.dart';

class FlashcardCategoryScreen extends StatelessWidget {
  const FlashcardCategoryScreen({super.key});

  final List<Map<String, dynamic>> categories = const [
    {
      'title': 'สัตว์น่ารัก',
      'subtitle': 'เพื่อนตัวน้อย',
      'image': 'assets/images/vocabulary/animals/Bear.png',
      'themeColor': Color(0xFF6C5CE7),
      'lightBg': Color(0xFFF3F0FF),
      'screen': AnimalsFlashcardsScreen(),
    },
    {
      'title': 'ผลไม้แสนอร่อย',
      'subtitle': 'หวานฉ่ำสดใส',
      'image': 'assets/images/vocabulary/fruits/Strawberry.png',
      'themeColor': Color(0xFFFF4757),
      'lightBg': Color(0xFFFFEAEB),
      'screen': FruitFlashcardsScreen(),
    },
    {
      'title': 'อาชีพในฝัน',
      'subtitle': 'โตขึ้นอยากเป็นอะไร',
      'image': 'assets/images/vocabulary/careers/Nurse.png',
      'themeColor': Color(0xFFFFA502),
      'lightBg': Color(0xFFFFF4E5),
      'screen': OccupationsFlashcardsScreen(),
    },
    {
      'title': 'กีฬาสุดสนุก',
      'subtitle': 'แข็งแรงสดใส',
      'image': 'assets/images/vocabulary/sports/Archery.png',
      'themeColor': Color(0xFFFF6B81),
      'lightBg': Color(0xFFFFF0F3),
      'screen': SportsFlashcardsScreen(),
    },
    {
      'title': 'ยานพาหนะ',
      'subtitle': 'ท่องโลกกว้าง',
      'image': 'assets/images/vocabulary/vehicles/Bike.png',
      'themeColor': Color(0xFF2ED573),
      'lightBg': Color(0xFFE8FCDD),
      'screen': VehicleFlashcardsScreen(),
    },
    {
      'title': 'สถานที่น่ารู้',
      'subtitle': 'รอบตัวเรา',
      'image': 'assets/images/vocabulary/places/School.png',
      'themeColor': Color(0xFFECCC68),
      'lightBg': Color(0xFFFFFDF0),
      'screen': PlacesFlashcardsScreen(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 246, 230),
      body: _GameScaffoldBody(
        title: 'แฟลชการ์ด',
        color: const Color(0xFFF26B21),
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: _CoinPill(fontSize: 14),
              ),
              const SizedBox(height: 10),
              Expanded(child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, index) {
              return _ToyCardCategory(category: categories[index]);
            },
          )),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _ToyCardCategory extends StatefulWidget {
  final Map<String, dynamic> category;

  const _ToyCardCategory({required this.category});

  @override
  State<_ToyCardCategory> createState() => _ToyCardCategoryState();
}

class _ToyCardCategoryState extends State<_ToyCardCategory> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    final Color themeColor = widget.category['themeColor'] as Color;
    final Color lightBg = widget.category['lightBg'] as Color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) => setState(() => _isDown = false),
      onTapCancel: () => setState(() => _isDown = false),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => widget.category['screen']),
        );
      },
      child: AnimatedScale(
        scale: _isDown ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // พื้นหลังด้านบนแบบนุ่มนวล
              Column(
                children: [
                  Expanded(
                    flex: 58,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: lightBg,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            widget.category['image'],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.stars_rounded,
                                size: 54,
                                color: themeColor,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ข้อความปุ่มกดส่วนล่าง
                  Expanded(
                    flex: 42,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                widget.category['title'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: themeColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.category['subtitle'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8A99AD),
                                ),
                              ),
                            ],
                          ),

                          // ปุ่มกด 3D Chunky Pill
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: themeColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: themeColor.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            // หลังแก้ไข (เอาไอคอนออกแล้ว)
                            child: const Center(
                              child: Text(
                                'เข้าเล่น',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------
// ป้ายแสดงเหรียญ (UI อย่างเดียว ไม่มีระบบเก็บเหรียญ)
// ---------------------------------------------------------------
class _CoinPill extends StatelessWidget {
  final int coins;
  final Color color;
  final double fontSize;

  const _CoinPill({
    // ignore: unused_element_parameter
    this.coins = 0,
    // ignore: unused_element_parameter
    this.color = const Color(0xFFB45309),
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final double fs = fontSize;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fs * 0.7, vertical: fs * 0.3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(fs * 1.6),
        border: Border.all(color: const Color(0xFFFFD43B), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.monetization_on_rounded,
            color: const Color(0xFFFFB627),
            size: fs * 1.45,
          ),
          SizedBox(width: fs * 0.35),
          Text(
            '$coins',
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _CoinPillBar extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final double fontSize;

  const _CoinPillBar({
    // ignore: unused_element_parameter
    this.padding = const EdgeInsets.only(bottom: 8),
    // ignore: unused_element_parameter
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: padding,
        child: _CoinPill(fontSize: fontSize),
      ),
    );
  }
}


// ---------------------------------------------------------------
// แถบหัวเรื่องด้านบนของเกม (ปุ่มย้อนกลับ + ชื่อเกม บนพื้นสีประจำเกม)
// ---------------------------------------------------------------
class _GameHeaderBar extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onBack;
  final bool showBack;

  const _GameHeaderBar({
    required this.title,
    required this.color,
    this.onBack,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (showBack)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onBack ?? () => Navigator.maybePop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                )
              else
                const SizedBox(width: 34),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameScaffoldBody extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onBack;
  final bool showBack;
  final Widget child;

  const _GameScaffoldBody({
    required this.title,
    required this.color,
    required this.child,
    // ignore: unused_element_parameter
    this.onBack,
    // ignore: unused_element_parameter
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GameHeaderBar(
          title: title,
          color: color,
          onBack: onBack,
          showBack: showBack,
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}