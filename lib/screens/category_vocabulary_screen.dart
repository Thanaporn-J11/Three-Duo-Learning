import 'package:flutter/material.dart';
import 'vocabulary/fruit_vocabulary_screen.dart'; // 1. หน้าคำศัพท์หมวดผลไม้
import 'vocabulary/animal_vocabulary_screen.dart'; // 2. หน้าคำศัพท์หมวดสัตว์
import 'vocabulary/color_vocabulary_screen.dart'; // 3. หน้าคำศัพท์หมวดสี
import 'vocabulary/clothes_vocabulary_screen.dart'; // 4. หน้าคำศัพท์หมวดเสื้อผ้า
import 'vocabulary/family_vocabulary_screen.dart'; // 5. หน้าคำศัพท์หมวดครอบครัว
import 'vocabulary/vehicle_vocabulary_screen.dart'; // 6. หน้าคำศัพท์หมวดยานพาหนะ
import 'vocabulary/career_vocabulary_screen.dart'; // 7. หน้าคำศัพท์หมวดอาชีพ
import 'vocabulary/sport_vocabulary_screen.dart'; // 8. หน้าคำศัพท์หมวดกีฬา
import 'vocabulary/day_vocabulary_screen.dart'; // 9. หน้าคำศัพท์หมวดวัน
import 'vocabulary/month_vocabulary_screen.dart'; // 10. หน้าคำศัพท์หมวดเดือน
import 'vocabulary/body_vocabulary_screen.dart'; // 11. หน้าคำศัพท์หมวดร่างกาย
import 'vocabulary/number_vocabulary_screen.dart'; // 12. หน้าคำศัพท์หมวดตัวเลข
import 'vocabulary/place_vocabulary_screen.dart'; // 13. หน้าคำศัพท์หมวดสถานที่

// Model ข้อมูลหมวดหมู่
class CategoryItem {
  final String titleEn;
  final String titleTh;
  final int wordCount;
  final IconData icon;

  CategoryItem({
    required this.titleEn,
    required this.titleTh,
    required this.wordCount,
    required this.icon,
  });
}

class CategoryScreen extends StatelessWidget {
  CategoryScreen({super.key});

  // ข้อมูลหมวดหมู่ครบทั้ง 13 หมวด
  final List<CategoryItem> categories = [
    CategoryItem(titleEn: 'Family', titleTh: 'ครอบครัว', wordCount: 16, icon: Icons.people_alt_rounded),
    CategoryItem(titleEn: 'Animal', titleTh: 'สัตว์', wordCount: 30, icon: Icons.pets_rounded),
    CategoryItem(titleEn: 'Color', titleTh: 'สี', wordCount: 11, icon: Icons.palette_rounded),
    CategoryItem(titleEn: 'Sport', titleTh: 'กีฬา', wordCount: 10, icon: Icons.sports_basketball_rounded),
    CategoryItem(titleEn: 'Day', titleTh: 'วัน', wordCount: 7, icon: Icons.calendar_today_rounded),
    CategoryItem(titleEn: 'Vehicle', titleTh: 'ยานพาหนะ', wordCount: 10, icon: Icons.directions_car_rounded),
    CategoryItem(titleEn: 'Clothes', titleTh: 'เสื้อผ้า', wordCount: 10, icon: Icons.checkroom_rounded),
    CategoryItem(titleEn: 'Body', titleTh: 'ร่างกาย', wordCount: 10, icon: Icons.accessibility_new_rounded),
    CategoryItem(titleEn: 'Month', titleTh: 'เดือน', wordCount: 12, icon: Icons.date_range_rounded),
    CategoryItem(titleEn: 'Number', titleTh: 'ตัวเลข', wordCount: 38, icon: Icons.pin_rounded),
    CategoryItem(titleEn: 'Career', titleTh: 'อาชีพ', wordCount: 30, icon: Icons.work_rounded),
    CategoryItem(titleEn: 'Fruit', titleTh: 'ผลไม้', wordCount: 30, icon: Icons.apple_rounded),
    CategoryItem(titleEn: 'Place', titleTh: 'สถานที่', wordCount: 26, icon: Icons.location_on_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0088FF); // สีฟ้าหลัก

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FA), // สีพื้นหลังฟ้าอ่อน
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'หมวดหมู่คำศัพท์',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.82,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemBuilder: (context, index) {
          final item = categories[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon Box
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    item.icon,
                    size: 32,
                    color: Colors.white,
                  ),
                ),

                // Text Section
                Column(
                  children: [
                    Text(
                      item.titleTh,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.titleEn} • ${item.wordCount} คำ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),

                // Start Button
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () {
                      if (item.titleEn == 'Fruit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FruitVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Animal') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnimalVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Color') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ColorVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Clothes') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ClothesVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Family') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FamilyVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Vehicle') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const VehicleVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Career') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CareerVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Sport') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SportVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Day') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DayVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Month') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MonthVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Body') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BodyVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Number') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NumberVocabularyScreen(),
                          ),
                        );
                      } else if (item.titleEn == 'Place') {
                        // ✅ เชื่อมต่อหมวด Place
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PlaceVocabularyScreen(),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'เริ่มเรียน',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}