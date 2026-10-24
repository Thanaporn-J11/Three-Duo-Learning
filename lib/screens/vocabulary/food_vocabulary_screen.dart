import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "อาหาร" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class FoodVocabularyScreen extends StatelessWidget {
  const FoodVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'food',
      categoryTitle: 'อาหาร',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดอาหาร',
  badge: 'อาหาร',
  icon: Icons.restaurant_rounded,
  background: Color(0xFF009CA6),
  border: Color(0xFF067178),
  shadow: Color(0xFF00332B),
  imageBackground: Color(0xFFFFECC4),
  speakerShadow: Color(0xFF004D40),
  wordSize: 42,
  wordLongSize: 34,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'Bread',
    thaiPhonetics: 'เบรด',
    translation: 'ขนมปัง',
    imagePath: 'assets/images/vocabulary/food/Bread.png',
  ),
  VocabularyItem(
    word: 'Burger',
    thaiPhonetics: 'เบอร์ เกอร์',
    translation: 'เบอร์เกอร์',
    imagePath: 'assets/images/vocabulary/food/Burger.png',
  ),
  VocabularyItem(
    word: 'Cake',
    thaiPhonetics: 'เค้ก',
    translation: 'เค้ก',
    imagePath: 'assets/images/vocabulary/food/Cake.png',
  ),
  VocabularyItem(
    word: 'Candy',
    thaiPhonetics: 'แคน ดี',
    translation: 'ลูกอม / ท็อฟฟี่',
    imagePath: 'assets/images/vocabulary/food/Candy.png',
  ),
  VocabularyItem(
    word: 'Cheese',
    thaiPhonetics: 'ชีส',
    translation: 'เนยแข็ง / ชีส',
    imagePath: 'assets/images/vocabulary/food/Cheese.png',
  ),
  VocabularyItem(
    word: 'Chicken',
    thaiPhonetics: 'ชิก คิน',
    translation: 'ไก่ทอด / เนื้อไก่',
    imagePath: 'assets/images/vocabulary/food/Chicken.png',
  ),
  VocabularyItem(
    word: 'Chocolate',
    thaiPhonetics: 'ช็อก เคอะ ลิต',
    translation: 'ช็อกโกแลต',
    imagePath: 'assets/images/vocabulary/food/Chocolate.png',
  ),
  VocabularyItem(
    word: 'Cookie',
    thaiPhonetics: 'คุ้ก คี',
    translation: 'คุกกี้',
    imagePath: 'assets/images/vocabulary/food/Cookie.png',
  ),
  VocabularyItem(
    word: 'Corn',
    thaiPhonetics: 'คอร์น',
    translation: 'ข้าวโพด',
    imagePath: 'assets/images/vocabulary/food/Corn.png',
  ),
  VocabularyItem(
    word: 'Donut',
    thaiPhonetics: 'โด นัท',
    translation: 'โดนัท',
    imagePath: 'assets/images/vocabulary/food/Donut.png',
  ),
  VocabularyItem(
    word: 'Egg',
    thaiPhonetics: 'เอ้ก',
    translation: 'ไข่',
    imagePath: 'assets/images/vocabulary/food/Egg.png',
  ),
  VocabularyItem(
    word: 'Fish',
    thaiPhonetics: 'ฟิช',
    translation: 'ปลา',
    imagePath: 'assets/images/vocabulary/food/Fish.png',
  ),
  VocabularyItem(
    word: 'French fries',
    thaiPhonetics: 'เฟรนช์ ฟรายส์',
    translation: 'มันฝรั่งทอด',
    imagePath: 'assets/images/vocabulary/food/Frenchfries.png',
  ),
  VocabularyItem(
    word: 'Ice cream',
    thaiPhonetics: 'ไอซ์ ครีม',
    translation: 'ไอศกรีม',
    imagePath: 'assets/images/vocabulary/food/Icecream.png',
  ),
  VocabularyItem(
    word: 'Juice',
    thaiPhonetics: 'จูซ',
    translation: 'น้ำผลไม้',
    imagePath: 'assets/images/vocabulary/food/Juice.png',
  ),
  VocabularyItem(
    word: 'Meat',
    thaiPhonetics: 'มีท',
    translation: 'เนื้อสัตว์',
    imagePath: 'assets/images/vocabulary/food/Meat.png',
  ),
  VocabularyItem(
    word: 'Milk',
    thaiPhonetics: 'มิลก์',
    translation: 'นม',
    imagePath: 'assets/images/vocabulary/food/Milk.png',
  ),
  VocabularyItem(
    word: 'Noodle',
    thaiPhonetics: 'นู เดิล',
    translation: 'ก๋วยเตี๋ยว / บะหมี่',
    imagePath: 'assets/images/vocabulary/food/Noodle.png',
  ),
  VocabularyItem(
    word: 'Pizza',
    thaiPhonetics: 'พิท ซ่า',
    translation: 'พิซซ่า',
    imagePath: 'assets/images/vocabulary/food/Pizza.png',
  ),
  VocabularyItem(
    word: 'Potato',
    thaiPhonetics: 'พะ เท โท',
    translation: 'มันฝรั่ง',
    imagePath: 'assets/images/vocabulary/food/Potato.png',
  ),
  VocabularyItem(
    word: 'Rice',
    thaiPhonetics: 'ไรซ์',
    translation: 'ข้าว',
    imagePath: 'assets/images/vocabulary/food/Rice.png',
  ),
  VocabularyItem(
    word: 'Salad',
    thaiPhonetics: 'แซล เลิด',
    translation: 'สลัด',
    imagePath: 'assets/images/vocabulary/food/Salad.png',
  ),
  VocabularyItem(
    word: 'Salt',
    thaiPhonetics: 'ซอลต์',
    translation: 'เกลือ',
    imagePath: 'assets/images/vocabulary/food/Salt.png',
  ),
  VocabularyItem(
    word: 'Sandwich',
    thaiPhonetics: 'แซนด์ วิช',
    translation: 'แซนด์วิช',
    imagePath: 'assets/images/vocabulary/food/Sandwich.png',
  ),
  VocabularyItem(
    word: 'Sausage',
    thaiPhonetics: 'ซอ สิจ',
    translation: 'ไส้กรอก',
    imagePath: 'assets/images/vocabulary/food/Sausage.png',
  ),
  VocabularyItem(
    word: 'Soup',
    thaiPhonetics: 'ซุป',
    translation: 'ซุป / แกงจืด',
    imagePath: 'assets/images/vocabulary/food/Soup.png',
  ),
  VocabularyItem(
    word: 'Sugar',
    thaiPhonetics: 'ชู เกอะ',
    translation: 'น้ำตาล',
    imagePath: 'assets/images/vocabulary/food/Sugar.png',
  ),
  VocabularyItem(
    word: 'Tomato',
    thaiPhonetics: 'ทะ เม โท',
    translation: 'มะเขือเทศ',
    imagePath: 'assets/images/vocabulary/food/Tomato.png',
  ),
  VocabularyItem(
    word: 'Vegetable',
    thaiPhonetics: 'เวจ เทอะ เบิล',
    translation: 'ผัก',
    imagePath: 'assets/images/vocabulary/food/Vegetable.png',
  ),
  VocabularyItem(
    word: 'Water',
    thaiPhonetics: 'วอ เทอะ',
    translation: 'น้ำเปล่า',
    imagePath: 'assets/images/vocabulary/food/Water.png',
  ),
];
