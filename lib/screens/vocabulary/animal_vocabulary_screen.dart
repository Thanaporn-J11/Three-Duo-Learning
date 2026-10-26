import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "สัตว์" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class AnimalVocabularyScreen extends StatelessWidget {
  const AnimalVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'animal',
      categoryTitle: 'สัตว์',
      words: kAnimalWords,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดสัตว์',
  badge: 'สัตว์',
  icon: Icons.pets_rounded,
  background: Color(0xFF1886E4),
  border: Color(0xFF0962C2),
  shadow: Color(0xFF0E6FC9),
  imageBackground: Color(0xFFFFE8C5),
  speakerShadow: Color(0xFF0D47A1),
  wordSize: 44,
  wordLongLength: 999,
  translationSize: 36,
  translationLongLength: 999,
);

/// The words of this category (also used by the first-letter game).
const List<VocabularyItem> kAnimalWords = [
  VocabularyItem(
    word: 'Bear',
    thaiPhonetics: 'แบร์',
    translation: 'หมี',
    imagePath: 'assets/images/vocabulary/animals/Bear.png',
  ),
  VocabularyItem(
    word: 'Bee',
    thaiPhonetics: 'บี',
    translation: 'ผึ้ง',
    imagePath: 'assets/images/vocabulary/animals/Bee.png',
  ),
  VocabularyItem(
    word: 'Bird',
    thaiPhonetics: 'เบิร์ด',
    translation: 'นก',
    imagePath: 'assets/images/vocabulary/animals/Bird.png',
  ),
  VocabularyItem(
    word: 'Butterfly',
    thaiPhonetics: 'บัต เตอร์ ฟลาย',
    translation: 'ผีเสื้อ',
    imagePath: 'assets/images/vocabulary/animals/Butterfly.png',
  ),
  VocabularyItem(
    word: 'Cat',
    thaiPhonetics: 'แคท',
    translation: 'แมว',
    imagePath: 'assets/images/vocabulary/animals/Cat.png',
  ),
  VocabularyItem(
    word: 'Chicken',
    thaiPhonetics: 'ชิค เก้น',
    translation: 'ไก่',
    imagePath: 'assets/images/vocabulary/animals/Chicken.png',
  ),
  VocabularyItem(
    word: 'Cow',
    thaiPhonetics: 'คาว',
    translation: 'วัว',
    imagePath: 'assets/images/vocabulary/animals/Cow.png',
  ),
  VocabularyItem(
    word: 'Dog',
    thaiPhonetics: 'ด็อก',
    translation: 'สุนัข',
    imagePath: 'assets/images/vocabulary/animals/Dog.png',
  ),
  VocabularyItem(
    word: 'Dolphin',
    thaiPhonetics: 'ดอล เฟิน',
    translation: 'โลมา',
    imagePath: 'assets/images/vocabulary/animals/Dolphin.png',
  ),
  VocabularyItem(
    word: 'Duck',
    thaiPhonetics: 'ดัค',
    translation: 'เป็ด',
    imagePath: 'assets/images/vocabulary/animals/Duck.png',
  ),
  VocabularyItem(
    word: 'Elephant',
    thaiPhonetics: 'เอล เล เฟินท์',
    translation: 'ช้าง',
    imagePath: 'assets/images/vocabulary/animals/Elephant.png',
  ),
  VocabularyItem(
    word: 'Fish',
    thaiPhonetics: 'ฟิช',
    translation: 'ปลา',
    imagePath: 'assets/images/vocabulary/animals/Fish.png',
  ),
  VocabularyItem(
    word: 'Frog',
    thaiPhonetics: 'ฟรอก',
    translation: 'กบ',
    imagePath: 'assets/images/vocabulary/animals/Frog.png',
  ),
  VocabularyItem(
    word: 'Giraffe',
    thaiPhonetics: 'จิ ราฟ',
    translation: 'ยีราฟ',
    imagePath: 'assets/images/vocabulary/animals/Giraffe.png',
  ),
  VocabularyItem(
    word: 'Hippo',
    thaiPhonetics: 'ฮิป โป',
    translation: 'ฮิปโปโปเตมัส',
    imagePath: 'assets/images/vocabulary/animals/Hippo.png',
  ),
  VocabularyItem(
    word: 'Horse',
    thaiPhonetics: 'ฮอร์ส',
    translation: 'ม้า',
    imagePath: 'assets/images/vocabulary/animals/Horse.png',
  ),
  VocabularyItem(
    word: 'Kangaroo',
    thaiPhonetics: 'แคง กะ รู',
    translation: 'จิงโจ้',
    imagePath: 'assets/images/vocabulary/animals/Kangaroo.png',
  ),
  VocabularyItem(
    word: 'Lion',
    thaiPhonetics: 'ไล เอิน',
    translation: 'สิงโต',
    imagePath: 'assets/images/vocabulary/animals/Lion.png',
  ),
  VocabularyItem(
    word: 'Monkey',
    thaiPhonetics: 'มัง คี',
    translation: 'ลิง',
    imagePath: 'assets/images/vocabulary/animals/Monkey.png',
  ),
  VocabularyItem(
    word: 'Octopus',
    thaiPhonetics: 'อ็อค โท พุส',
    translation: 'ปลาหมึกยักษ์',
    imagePath: 'assets/images/vocabulary/animals/Octopus.png',
  ),
  VocabularyItem(
    word: 'Owl',
    thaiPhonetics: 'เอาล์',
    translation: 'นกฮูก',
    imagePath: 'assets/images/vocabulary/animals/Owl.png',
  ),
  VocabularyItem(
    word: 'Panda',
    thaiPhonetics: 'แพน ด้า',
    translation: 'แพนด้า',
    imagePath: 'assets/images/vocabulary/animals/Panda.png',
  ),
  VocabularyItem(
    word: 'Penguin',
    thaiPhonetics: 'เพน กวิน',
    translation: 'เพนกวิน',
    imagePath: 'assets/images/vocabulary/animals/Penguin.png',
  ),
  VocabularyItem(
    word: 'Pig',
    thaiPhonetics: 'พิก',
    translation: 'หมู',
    imagePath: 'assets/images/vocabulary/animals/Pig.png',
  ),
  VocabularyItem(
    word: 'Rabbit',
    thaiPhonetics: 'แรบ บิท',
    translation: 'กระต่าย',
    imagePath: 'assets/images/vocabulary/animals/Rabbit.png',
  ),
  VocabularyItem(
    word: 'Sheep',
    thaiPhonetics: 'ชีพ',
    translation: 'แกะ',
    imagePath: 'assets/images/vocabulary/animals/Sheep.png',
  ),
  VocabularyItem(
    word: 'Tiger',
    thaiPhonetics: 'ไท เกอร์',
    translation: 'เสือ',
    imagePath: 'assets/images/vocabulary/animals/Tiger.png',
  ),
  VocabularyItem(
    word: 'Turtle',
    thaiPhonetics: 'เทอร์ เทิล',
    translation: 'เต่า',
    imagePath: 'assets/images/vocabulary/animals/Turtle.png',
  ),
  VocabularyItem(
    word: 'Whale',
    thaiPhonetics: 'เวล',
    translation: 'วาฬ',
    imagePath: 'assets/images/vocabulary/animals/Whale.png',
  ),
  VocabularyItem(
    word: 'Zebra',
    thaiPhonetics: 'ซี บรา',
    translation: 'ม้าลาย',
    imagePath: 'assets/images/vocabulary/animals/Zebra.png',
  ),
  VocabularyItem(
    word: 'Crocodile',
    thaiPhonetics: 'ครอค โค ไดล์',
    translation: 'จระเข้',
    imagePath: 'assets/images/vocabulary/animals/Crocodile.png',
  ),
  VocabularyItem(
    word: 'Koala',
    thaiPhonetics: 'โค อา ลา',
    translation: 'โคอาลา',
    imagePath: 'assets/images/vocabulary/animals/Koala.png',
  ),
  VocabularyItem(
    word: 'Mosquito',
    thaiPhonetics: 'มอส คี โท',
    translation: 'ยุง',
    imagePath: 'assets/images/vocabulary/animals/Mosquito.png',
  ),
  VocabularyItem(
    word: 'Peacock',
    thaiPhonetics: 'พี ค็อก',
    translation: 'นกยูง',
    imagePath: 'assets/images/vocabulary/animals/Peacock.png',
  ),
  VocabularyItem(
    word: 'Shrimp',
    thaiPhonetics: 'ชริมพ์',
    translation: 'กุ้ง',
    imagePath: 'assets/images/vocabulary/animals/Shrimp.png',
  ),
  VocabularyItem(
    word: 'Snake',
    thaiPhonetics: 'สเนค',
    translation: 'งู',
    imagePath: 'assets/images/vocabulary/animals/Snake.png',
  ),
  VocabularyItem(
    word: 'Spider',
    thaiPhonetics: 'สไป เดอร์',
    translation: 'แมงมุม',
    imagePath: 'assets/images/vocabulary/animals/Spider.png',
  ),
];
