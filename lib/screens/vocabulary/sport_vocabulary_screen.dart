import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "กีฬา" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class SportVocabularyScreen extends StatelessWidget {
  const SportVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'sport',
      categoryTitle: 'กีฬา',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดกีฬา',
  badge: 'กีฬา',
  icon: Icons.sports_basketball_rounded,
  background: Color(0xFFD81B60),
  border: Color(0xFF880E4F),
  shadow: Color(0xFF560027),
  imageBackground: Color(0xFFF7F0E0),
  speakerShadow: Color(0xFF880E4F),
  wordSize: 42,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'Badminton',
    thaiPhonetics: 'แบด มิน เทิน',
    translation: 'แบดมินตัน',
    imagePath: 'assets/images/vocabulary/sports/Badminton.png',
  ),
  VocabularyItem(
    word: 'Baseball',
    thaiPhonetics: 'เบส บอล',
    translation: 'เบสบอล',
    imagePath: 'assets/images/vocabulary/sports/Baseball.png',
  ),
  VocabularyItem(
    word: 'Basketball',
    thaiPhonetics: 'บาส เก็ต บอล',
    translation: 'บาสเกตบอล',
    imagePath: 'assets/images/vocabulary/sports/Basketball.png',
  ),
  VocabularyItem(
    word: 'Cycling',
    thaiPhonetics: 'ไซ คลิง',
    translation: 'การปั่นจักรยาน',
    imagePath: 'assets/images/vocabulary/sports/Cycling.png',
  ),
  VocabularyItem(
    word: 'Running',
    thaiPhonetics: 'รัน นิง',
    translation: 'การวิ่ง',
    imagePath: 'assets/images/vocabulary/sports/Running.png',
  ),
  VocabularyItem(
    word: 'Soccer',
    thaiPhonetics: 'ซอก เคอร์',
    translation: 'ฟุตบอล',
    imagePath: 'assets/images/vocabulary/sports/Soccer.png',
  ),
  VocabularyItem(
    word: 'Swimming',
    thaiPhonetics: 'สวิม มิง',
    translation: 'การว่ายน้ำ',
    imagePath: 'assets/images/vocabulary/sports/Swimming.png',
  ),
  VocabularyItem(
    word: 'Table Tennis',
    thaiPhonetics: 'เท เบิล เทน นิส',
    translation: 'เทเบิลเทนนิส / ปิงปอง',
    imagePath: 'assets/images/vocabulary/sports/Table Tennis.png',
  ),
  VocabularyItem(
    word: 'Tennis',
    thaiPhonetics: 'เทน นิส',
    translation: 'เทนนิส',
    imagePath: 'assets/images/vocabulary/sports/Tennis.png',
  ),
  VocabularyItem(
    word: 'Volleyball',
    thaiPhonetics: 'วอล เลย์ บอล',
    translation: 'วอลเลย์บอล',
    imagePath: 'assets/images/vocabulary/sports/Volleyball.png',
  ),
  VocabularyItem(
    word: 'Archery',
    thaiPhonetics: 'อาร์ เชอ รี',
    translation: 'ยิงธนู',
    imagePath: 'assets/images/vocabulary/sports/Archery.png',
  ),
  VocabularyItem(
    word: 'Bowling',
    thaiPhonetics: 'โบว์ ลิง',
    translation: 'โบว์ลิ่ง',
    imagePath: 'assets/images/vocabulary/sports/Bowling.png',
  ),
  VocabularyItem(
    word: 'Boxing',
    thaiPhonetics: 'บ็อก ซิง',
    translation: 'มวยสากล / ชกมวย',
    imagePath: 'assets/images/vocabulary/sports/Boxing.png',
  ),
  VocabularyItem(
    word: 'Golf',
    thaiPhonetics: 'กอล์ฟ',
    translation: 'กอล์ฟ',
    imagePath: 'assets/images/vocabulary/sports/Golf.png',
  ),
  VocabularyItem(
    word: 'Gymnastics',
    thaiPhonetics: 'จิม แนส ติกส์',
    translation: 'ยิมนาสติก',
    imagePath: 'assets/images/vocabulary/sports/Gymnastics.png',
  ),
  VocabularyItem(
    word: 'Hockey',
    thaiPhonetics: 'ฮ็อก กี',
    translation: 'ฮอกกี้',
    imagePath: 'assets/images/vocabulary/sports/Hockey.png',
  ),
  VocabularyItem(
    word: 'Rugby',
    thaiPhonetics: 'รัก บี',
    translation: 'รักบี้',
    imagePath: 'assets/images/vocabulary/sports/Rugby.png',
  ),
  VocabularyItem(
    word: 'Skateboarding',
    thaiPhonetics: 'สเกต บอร์ด ดิง',
    translation: 'สเกตบอร์ด',
    imagePath: 'assets/images/vocabulary/sports/Skateboarding.png',
  ),
  VocabularyItem(
    word: 'Surfing',
    thaiPhonetics: 'เซิร์ฟ ฟิง',
    translation: 'กระดานโต้คลื่น',
    imagePath: 'assets/images/vocabulary/sports/Surfing.png',
  ),
  VocabularyItem(
    word: 'Taekwondo',
    thaiPhonetics: 'เท ควัน โด',
    translation: 'เทควันโด',
    imagePath: 'assets/images/vocabulary/sports/Taekwondo.png',
  ),
];
