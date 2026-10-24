import 'package:flutter/material.dart';
import '../models/vocabulary_category.dart';
import '../services/vocabulary_api_service.dart';
import '../services/vocabulary_progress_service.dart';
import '../services/lesson_progress.dart';

// Import Screens หมวดหมู่
import 'vocabulary/fruit_vocabulary_screen.dart';
import 'vocabulary/animal_vocabulary_screen.dart';
import 'vocabulary/color_vocabulary_screen.dart';
import 'vocabulary/clothes_vocabulary_screen.dart';
import 'vocabulary/family_vocabulary_screen.dart';
import 'vocabulary/vehicle_vocabulary_screen.dart';
import 'vocabulary/career_vocabulary_screen.dart';
import 'vocabulary/sport_vocabulary_screen.dart';
import 'vocabulary/day_vocabulary_screen.dart';
import 'vocabulary/month_vocabulary_screen.dart';
import 'vocabulary/body_vocabulary_screen.dart';
import 'vocabulary/number_vocabulary_screen.dart';
import 'vocabulary/place_vocabulary_screen.dart';
import 'vocabulary/house_vocabulary_screen.dart';
import 'vocabulary/daily_routine_vocabulary_screen.dart';
import 'vocabulary/food_vocabulary_screen.dart';

class CategoryItem {
  final String slug;
  final String titleTh;
  final IconData fallbackIcon;
  final String imagePath;
  final Color cardColor;
  final Widget screen;

  CategoryItem({
    required this.slug,
    required this.titleTh,
    required this.fallbackIcon,
    required this.imagePath,
    required this.cardColor,
    required this.screen,
  });
}

class CategoryVocabularyScreen extends StatefulWidget {
  const CategoryVocabularyScreen({super.key});

  @override
  State<CategoryVocabularyScreen> createState() => _CategoryVocabularyScreenState();
}

class _CategoryVocabularyScreenState extends State<CategoryVocabularyScreen> {
  List<VocabularyCategory>? _apiCategories;
  bool _isLoading = true;
  String? _loadError;

  /// Dot on each card: finished (green) / started (yellow) / new (white).
  Set<String> _doneSlugs = {};
  Set<String> _startedSlugs = {};
  Map<String, int> _learnedOnServer = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadStatus();
  }

  static const List<String> _allSlugs = [
    'food', 'animal', 'number', 'color', 'fruit', 'vehicle', 'career', 'sport',
    'house', 'daily-routine', 'family', 'place', 'month', 'day', 'clothes', 'body',
  ];

  Future<void> _loadStatus() async {
    final done = await VocabularyProgress.doneCategories();
    final started = <String>{};
    for (final slug in _allSlugs) {
      // Any saved position counts as started (validated against a big total).
      if (await LessonProgress.load('vocab_$slug', 1 << 20) != null) {
        started.add(slug);
      }
    }
    if (mounted) {
      setState(() {
        _doneSlugs = done;
        _startedSlugs = started;
      });
    }
    // Words learned on any phone (server); used when online.
    final learned = await VocabularyProgress.learnedCounts();
    if (mounted && learned.isNotEmpty) setState(() => _learnedOnServer = learned);
  }

  /// green = went through every word, yellow = started, white = not yet.
  Color _dotColor(String slug) {
    final learned = _learnedOnServer[slug] ?? 0;
    int? total;
    for (final c in _apiCategories ?? const <VocabularyCategory>[]) {
      if (c.slug == slug) total = c.wordCount;
    }
    final finished =
        _doneSlugs.contains(slug) || (total != null && total > 0 && learned >= total);
    if (finished) return const Color(0xFF22C55E);
    if (_startedSlugs.contains(slug) || learned > 0) return const Color(0xFFFACC15);
    return Colors.white.withValues(alpha: 0.85);
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final categories = await VocabularyApiService.getCategories();
      if (!mounted) return;
      categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      setState(() {
        _apiCategories = categories;
        _isLoading = false;
      });
    } on VocabularyApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _apiCategories = null;
        _loadError = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apiCategories = null;
        _loadError = 'โหลดหมวดคำศัพท์ออนไลน์ไม่สำเร็จ';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const topBarColor = Color(0xFF3886D8);

    final List<CategoryItem> categories = [
      CategoryItem(
        slug: 'food',
        titleTh: 'อาหาร',
        fallbackIcon: Icons.restaurant_rounded,
        imagePath: 'assets/images/Background/Vocabularyfood.png',
        cardColor: const Color(0xFF00ACC1),
        screen: const FoodVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'animal',
        titleTh: 'สัตว์',
        fallbackIcon: Icons.pets_rounded,
        imagePath: 'assets/images/Background/Vocabularyanimal.png',
        cardColor: const Color(0xFF1E88E5),
        screen: const AnimalVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'number',
        titleTh: 'ตัวเลข',
        fallbackIcon: Icons.format_list_numbered_rounded,
        imagePath: 'assets/images/Background/Vocabularynumber.png',
        cardColor: const Color(0xFF43A047),
        screen: const NumberVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'color',
        titleTh: 'สีสัน',
        fallbackIcon: Icons.palette_rounded,
        imagePath: 'assets/images/Background/Vocabularycolor.png',
        cardColor: const Color(0xFFE53935),
        screen: const ColorVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'fruit',
        titleTh: 'ผลไม้',
        fallbackIcon: Icons.apple_rounded,
        imagePath: 'assets/images/Background/Vocabularyfruit.png',
        cardColor: const Color(0xFF5E35B1),
        screen: const FruitVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'vehicle',
        titleTh: 'ยานพาหนะ',
        fallbackIcon: Icons.directions_car_rounded,
        imagePath: 'assets/images/Background/Vocabularyvehicle.png',
        cardColor: const Color(0xFF00897B),
        screen: const VehicleVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'career',
        titleTh: 'อาชีพ',
        fallbackIcon: Icons.work_rounded,
        imagePath: 'assets/images/Background/Vocabularycareer.png',
        cardColor: const Color(0xFF3949AB),
        screen: const CareerVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'sport',
        titleTh: 'กีฬา',
        fallbackIcon: Icons.sports_basketball_rounded,
        imagePath: 'assets/images/Background/Vocabularysport.png',
        cardColor: const Color(0xFFD81B60),
        screen: const SportVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'house',
        titleTh: 'บ้าน',
        fallbackIcon: Icons.home_rounded,
        imagePath: 'assets/images/Background/VocabularyHouse.png',
        cardColor: const Color(0xFF0288D1),
        screen: const HouseVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'daily-routine',
        titleTh: 'กิจวัตรประจำวัน',
        fallbackIcon: Icons.access_time_filled_rounded,
        imagePath: 'assets/images/Background/VocabularyDailyroutine.png',
        cardColor: const Color(0xFF00838F),
        screen: const DailyRoutineVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'family',
        titleTh: 'ครอบครัว',
        fallbackIcon: Icons.people_alt_rounded,
        imagePath: 'assets/images/Background/Vocabularyfamily.png',
        cardColor: const Color(0xFF2E7D32),
        screen: const FamilyVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'place',
        titleTh: 'สถานที่',
        fallbackIcon: Icons.location_on_rounded,
        imagePath: 'assets/images/Background/Vocabularylocation.png',
        cardColor: const Color(0xFFC2185B),
        screen: const PlaceVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'month',
        titleTh: 'เดือน',
        fallbackIcon: Icons.date_range_rounded,
        imagePath: 'assets/images/Background/Vocabularymonth.png',
        cardColor: const Color(0xFFE65100),
        screen: const MonthVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'day',
        titleTh: 'วัน',
        fallbackIcon: Icons.calendar_today_rounded,
        imagePath: 'assets/images/Background/Vocabularyday.png',
        cardColor: const Color(0xFF6A1B9A),
        screen: const DayVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'clothes',
        titleTh: 'เสื้อผ้า',
        fallbackIcon: Icons.checkroom_rounded,
        imagePath: 'assets/images/Background/Vocabularyclothes.png',
        cardColor: const Color(0xFF1565C0),
        screen: const ClothesVocabularyScreen(),
      ),
      CategoryItem(
        slug: 'body',
        titleTh: 'ร่างกาย',
        fallbackIcon: Icons.accessibility_new_rounded,
        imagePath: 'assets/images/Background/Vocabularybody.png',
        cardColor: const Color(0xFF0097A7),
        screen: const BodyVocabularyScreen(),
      ),
    ];
    final metadataBySlug = {for (final item in categories) item.slug: item};
    final visibleCategories = _apiCategories == null
        ? categories
        : _apiCategories!
            .map((category) => metadataBySlug[category.slug])
            .whereType<CategoryItem>()
            .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ----------------------------------------------------
          // แถบด้านบน
          // ----------------------------------------------------
          Container(
            color: topBarColor,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'หมวดหมู่คำศัพท์',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // ----------------------------------------------------
          // เนื้อหา
          // ----------------------------------------------------
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. ภาพแบนเนอร์ด้านบน
                  Image.asset(
                    'assets/images/Background/BackgroundVocabulary.jpg',
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: const Color(0xFF3886D8),
                      child: const Center(
                        child: Icon(Icons.image_rounded, size: 48, color: Colors.white70),
                      ),
                    ),
                  ),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(minHeight: 3),
                          SizedBox(height: 6),
                          Text('กำลังโหลดหมวดคำศัพท์ออนไลน์...'),
                        ],
                      ),
                    ),
                  if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDBA74)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_off_rounded, color: Color(0xFFC2410C)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_loadError กำลังแสดงหมวดเดิมในเครื่อง',
                                style: const TextStyle(color: Color(0xFF9A3412)),
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : _loadCategories,
                              child: const Text('ลองอีกครั้ง'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. แถบหัวข้อคั่นขนาดใหญ่ เด่นชัด
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 6,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: topBarColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'เลือกหมวดหมู่คำศัพท์',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'แตะเพื่อเริ่มต้นฝึกออกเสียงและการเรียนรู้',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // ป้ายจำนวนหมวดหมู่
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '${visibleCategories.length} หมวด',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Grid การ์ดหมวดหมู่
                  if (visibleCategories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                      child: Center(
                        child: Text(
                          'ยังไม่มีหมวดคำศัพท์ให้แสดง',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                        ),
                      ),
                    )
                  else
                    Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleCategories.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.82,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 26,
                      ),
                      itemBuilder: (context, index) {
                        final item = visibleCategories[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: item.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: item.cardColor.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => item.screen),
                                ).then((_) => _loadStatus()); // refresh the dot
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  // จุดมุมขวาบน: เขียว = เรียนจบแล้ว, เหลือง = เรียนค้าง, ขาว = ยังไม่เรียน
                                  Positioned(
                                    top: 14,
                                    right: 14,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: _dotColor(item.slug),
                                        border: Border.all(color: Colors.white, width: 1.5),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.12),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // จัดรูปภาพและวงกลมแสงให้อยู่กึ่งกลางพื้นที่การ์ด
                                  Positioned.fill(
                                    bottom: 22,
                                    child: Center(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // วงกลมแสงพื้นหลัง
                                          Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.18),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          // รูปภาพขนาด 110x110 px ตรงกลาง
                                          Image.asset(
                                            item.imagePath,
                                            height: 110,
                                            width: 110,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Icon(
                                              item.fallbackIcon,
                                              size: 64,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // ป้ายชื่อสีทอง 3D (เฉพาะภาษาไทย)
                                  Positioned(
                                    bottom: -15,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
                                      constraints: const BoxConstraints(minWidth: 110),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFFCA28), Color(0xFFFFA000)],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white, width: 2.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFB45309).withValues(alpha: 0.45),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        item.titleTh,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
