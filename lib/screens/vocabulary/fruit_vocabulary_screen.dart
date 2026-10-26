import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "ผลไม้" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class FruitVocabularyScreen extends StatelessWidget {
  const FruitVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'fruit',
      categoryTitle: 'ผลไม้',
      words: kFruitWords,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดผลไม้',
  badge: 'ผลไม้',
  icon: Icons.eco_rounded,
  background: Color(0xFF4A148C),
  border: Color(0xFF7C41D4),
  shadow: Color(0xFF1B053C),
  imageBackground: Color(0xFFE8E7FF),
  speakerShadow: Color(0xFF2A085C),
  wordSize: 42,
  wordLongSize: 32,
);

/// The words of this category (also used by the first-letter game).
const List<VocabularyItem> kFruitWords = [
  VocabularyItem(
    word: 'Apple',
    thaiPhonetics: 'แอป เปิล',
    translation: 'แอปเปิ้ล',
    imagePath: 'assets/images/vocabulary/fruits/Apple.png',
  ),
  VocabularyItem(
    word: 'Avocado',
    thaiPhonetics: 'อะ โว คา โด',
    translation: 'อะโวคาโด',
    imagePath: 'assets/images/vocabulary/fruits/Avocado.png',
  ),
  VocabularyItem(
    word: 'Banana',
    thaiPhonetics: 'บะ แนน นะ',
    translation: 'กล้วย',
    imagePath: 'assets/images/vocabulary/fruits/Banana.png',
  ),
  VocabularyItem(
    word: 'Blackberry',
    thaiPhonetics: 'แบล็ก เบอร์ รี',
    translation: 'แบล็กเบอร์รี',
    imagePath: 'assets/images/vocabulary/fruits/Blackberry.png',
  ),
  VocabularyItem(
    word: 'Blueberry',
    thaiPhonetics: 'บลู เบอร์ รี',
    translation: 'บลูเบอร์รี',
    imagePath: 'assets/images/vocabulary/fruits/Blueberry.png',
  ),
  VocabularyItem(
    word: 'Cherry',
    thaiPhonetics: 'เชอร์ รี',
    translation: 'เชอร์รี',
    imagePath: 'assets/images/vocabulary/fruits/Cherry.png',
  ),
  VocabularyItem(
    word: 'Coconut',
    thaiPhonetics: 'โค โค นัท',
    translation: 'มะพร้าว',
    imagePath: 'assets/images/vocabulary/fruits/Coconut.png',
  ),
  VocabularyItem(
    word: 'Dragon Fruit',
    thaiPhonetics: 'แดร็ก เกิน ฟรุต',
    translation: 'แก้วมังกร',
    imagePath: 'assets/images/vocabulary/fruits/Dragon Fruit.png',
  ),
  VocabularyItem(
    word: 'Durian',
    thaiPhonetics: 'ดู เรียน',
    translation: 'ทุเรียน',
    imagePath: 'assets/images/vocabulary/fruits/Durian.png',
  ),
  VocabularyItem(
    word: 'Grapes',
    thaiPhonetics: 'เกรพส์',
    translation: 'องุ่น',
    imagePath: 'assets/images/vocabulary/fruits/Grapes.png',
  ),
  VocabularyItem(
    word: 'Guava',
    thaiPhonetics: 'กวา วา',
    translation: 'ฝรั่ง',
    imagePath: 'assets/images/vocabulary/fruits/Guava.png',
  ),
  VocabularyItem(
    word: 'Jackfruit',
    thaiPhonetics: 'แจ็ก ฟรุต',
    translation: 'ขนุน',
    imagePath: 'assets/images/vocabulary/fruits/Jackfruit.png',
  ),
  VocabularyItem(
    word: 'Kiwi',
    thaiPhonetics: 'คี วี',
    translation: 'กีวี่',
    imagePath: 'assets/images/vocabulary/fruits/Kiwi.png',
  ),
  VocabularyItem(
    word: 'Lemon',
    thaiPhonetics: 'เลม เอิน',
    translation: 'เลมอน',
    imagePath: 'assets/images/vocabulary/fruits/Lemon.png',
  ),
  VocabularyItem(
    word: 'Lime',
    thaiPhonetics: 'ไลม์',
    translation: 'มะนาว',
    imagePath: 'assets/images/vocabulary/fruits/Lime.png',
  ),
  VocabularyItem(
    word: 'Longan',
    thaiPhonetics: 'ลอง แกน',
    translation: 'ลำไย',
    imagePath: 'assets/images/vocabulary/fruits/Longan.png',
  ),
  VocabularyItem(
    word: 'Lychee',
    thaiPhonetics: 'ไล ชี',
    translation: 'ลิ้นจี่',
    imagePath: 'assets/images/vocabulary/fruits/Lychee.png',
  ),
  VocabularyItem(
    word: 'Mango',
    thaiPhonetics: 'แมง โก',
    translation: 'มะม่วง',
    imagePath: 'assets/images/vocabulary/fruits/Mango.png',
  ),
  VocabularyItem(
    word: 'Mangosteen',
    thaiPhonetics: 'แมง โก สทีน',
    translation: 'มังคุด',
    imagePath: 'assets/images/vocabulary/fruits/Mangosteen.png',
  ),
  VocabularyItem(
    word: 'Orange',
    thaiPhonetics: 'ออ รินจ์',
    translation: 'ส้ม',
    imagePath: 'assets/images/vocabulary/fruits/Orange.png',
  ),
  VocabularyItem(
    word: 'Papaya',
    thaiPhonetics: 'พะ พาย ยะ',
    translation: 'มะละกอ',
    imagePath: 'assets/images/vocabulary/fruits/Papaya.png',
  ),
  VocabularyItem(
    word: 'Passion Fruit',
    thaiPhonetics: 'แพช เชิน ฟรุต',
    translation: 'เสาวรส',
    imagePath: 'assets/images/vocabulary/fruits/Passion Fruit.png',
  ),
  VocabularyItem(
    word: 'Peach',
    thaiPhonetics: 'พีช',
    translation: 'ลูกพีช',
    imagePath: 'assets/images/vocabulary/fruits/Peach.png',
  ),
  VocabularyItem(
    word: 'Pear',
    thaiPhonetics: 'แพร์',
    translation: 'ลูกแพร์',
    imagePath: 'assets/images/vocabulary/fruits/Pear.png',
  ),
  VocabularyItem(
    word: 'Pineapple',
    thaiPhonetics: 'ไพน์ แอป เปิล',
    translation: 'สับปะรด',
    imagePath: 'assets/images/vocabulary/fruits/Pineapple.png',
  ),
  VocabularyItem(
    word: 'Pomegranate',
    thaiPhonetics: 'พอม แกรน หนิต',
    translation: 'ทับทิม',
    imagePath: 'assets/images/vocabulary/fruits/Pomegranate.png',
  ),
  VocabularyItem(
    word: 'Rambutan',
    thaiPhonetics: 'แรม บู แทน',
    translation: 'เงาะ',
    imagePath: 'assets/images/vocabulary/fruits/Rambutan.png',
  ),
  VocabularyItem(
    word: 'Raspberry',
    thaiPhonetics: 'ราส เบอร์ รี',
    translation: 'ราสเบอร์รี',
    imagePath: 'assets/images/vocabulary/fruits/Raspberry.png',
  ),
  VocabularyItem(
    word: 'Strawberry',
    thaiPhonetics: 'สตรอว์ เบอร์ รี',
    translation: 'สตรอว์เบอร์รี',
    imagePath: 'assets/images/vocabulary/fruits/Strawberry.png',
  ),
  VocabularyItem(
    word: 'Watermelon',
    thaiPhonetics: 'วอ เทอร์ เมล เลิน',
    translation: 'แตงโม',
    imagePath: 'assets/images/vocabulary/fruits/Watermelon.png',
  ),
  VocabularyItem(
    word: 'Apricot',
    thaiPhonetics: 'เอ พริ ค็อต',
    translation: 'แอปริคอต',
    imagePath: 'assets/images/vocabulary/fruits/Apricot.png',
  ),
  VocabularyItem(
    word: 'Cantaloupe',
    thaiPhonetics: 'แคน ทะ ลูป',
    translation: 'แคนตาลูป',
    imagePath: 'assets/images/vocabulary/fruits/Cantaloupe.png',
  ),
  VocabularyItem(
    word: 'Rose Apple',
    thaiPhonetics: 'โรส แอป เปิล',
    translation: 'ชมพู่',
    imagePath: 'assets/images/vocabulary/fruits/Roseapple.png',
  ),
  VocabularyItem(
    word: 'Starfruit',
    thaiPhonetics: 'สตาร์ ฟรุต',
    translation: 'มะเฟือง',
    imagePath: 'assets/images/vocabulary/fruits/Starfruit.png',
  ),
];
