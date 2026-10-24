import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "บ้าน" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class HouseVocabularyScreen extends StatelessWidget {
  const HouseVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'house',
      categoryTitle: 'บ้าน',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดบ้าน',
  badge: 'บ้าน',
  icon: Icons.home_rounded,
  background: Color(0xFF0077C2),
  border: Color(0xFF004BA0),
  shadow: Color(0xFF002F6C),
  imageBackground: Color(0xFFFDEDF9),
  speakerShadow: Color(0xFF004BA0),
  wordSize: 42,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'Bathroom',
    thaiPhonetics: 'บาธ รูม',
    translation: 'ห้องน้ำ',
    imagePath: 'assets/images/vocabulary/house/Bathroom.png',
  ),
  VocabularyItem(
    word: 'Bed',
    thaiPhonetics: 'เบด',
    translation: 'เตียงนอน',
    imagePath: 'assets/images/vocabulary/house/Bed.png',
  ),
  VocabularyItem(
    word: 'Bedroom',
    thaiPhonetics: 'เบด รูม',
    translation: 'ห้องนอน',
    imagePath: 'assets/images/vocabulary/house/Bedroom.png',
  ),
  VocabularyItem(
    word: 'Blanket',
    thaiPhonetics: 'แบล็ง คิท',
    translation: 'ผ้าห่ม',
    imagePath: 'assets/images/vocabulary/house/Blanket.png',
  ),
  VocabularyItem(
    word: 'Chair',
    thaiPhonetics: 'แชร์',
    translation: 'เก้าอี้',
    imagePath: 'assets/images/vocabulary/house/Chair.png',
  ),
  VocabularyItem(
    word: 'Clock',
    thaiPhonetics: 'คล็อก',
    translation: 'นาฬิกา',
    imagePath: 'assets/images/vocabulary/house/Clock.png',
  ),
  VocabularyItem(
    word: 'Closet',
    thaiPhonetics: 'คลอ ซิต',
    translation: 'ตู้เสื้อผ้า',
    imagePath: 'assets/images/vocabulary/house/Closet.png',
  ),
  VocabularyItem(
    word: 'Diningroom',
    thaiPhonetics: 'ได นิง รูม',
    translation: 'ห้องรับประทานอาหาร',
    imagePath: 'assets/images/vocabulary/house/Diningroom.png',
  ),
  VocabularyItem(
    word: 'Door',
    thaiPhonetics: 'ดอร์',
    translation: 'ประตู',
    imagePath: 'assets/images/vocabulary/house/Door.png',
  ),
  VocabularyItem(
    word: 'Fan',
    thaiPhonetics: 'แฟน',
    translation: 'พัดลม',
    imagePath: 'assets/images/vocabulary/house/Fan.png',
  ),
  VocabularyItem(
    word: 'Floor',
    thaiPhonetics: 'ฟลอร์',
    translation: 'พื้นห้อง',
    imagePath: 'assets/images/vocabulary/house/Floor.png',
  ),
  VocabularyItem(
    word: 'Fork',
    thaiPhonetics: 'ฟอร์ก',
    translation: 'ส้อม',
    imagePath: 'assets/images/vocabulary/house/Fork.png',
  ),
  VocabularyItem(
    word: 'Garden',
    thaiPhonetics: 'การ์ เดิน',
    translation: 'สวน',
    imagePath: 'assets/images/vocabulary/house/Garden.png',
  ),
  VocabularyItem(
    word: 'House',
    thaiPhonetics: 'เฮาส์',
    translation: 'บ้าน',
    imagePath: 'assets/images/vocabulary/house/House.png',
  ),
  VocabularyItem(
    word: 'Kitchen',
    thaiPhonetics: 'คิท ชิน',
    translation: 'ห้องครัว',
    imagePath: 'assets/images/vocabulary/house/Kitchen.png',
  ),
  VocabularyItem(
    word: 'Lamp',
    thaiPhonetics: 'แลมป์',
    translation: 'โคมไฟ',
    imagePath: 'assets/images/vocabulary/house/Lamp.png',
  ),
  VocabularyItem(
    word: 'Livingroom',
    thaiPhonetics: 'ลิฟ วิง รูม',
    translation: 'ห้องนั่งเล่น',
    imagePath: 'assets/images/vocabulary/house/Livingroom.png',
  ),
  VocabularyItem(
    word: 'Mirror',
    thaiPhonetics: 'มิร เรอร์',
    translation: 'กระจกเงา',
    imagePath: 'assets/images/vocabulary/house/Mirror.png',
  ),
  VocabularyItem(
    word: 'Pillow',
    thaiPhonetics: 'พิล โล',
    translation: 'หมอน',
    imagePath: 'assets/images/vocabulary/house/Pillow.png',
  ),
  VocabularyItem(
    word: 'Plate',
    thaiPhonetics: 'เพลท',
    translation: 'จาน',
    imagePath: 'assets/images/vocabulary/house/Plate.png',
  ),
  VocabularyItem(
    word: 'Refrigerator',
    thaiPhonetics: 'รี ฟริจ เจอะ เร เทอะ',
    translation: 'ตู้เย็น',
    imagePath: 'assets/images/vocabulary/house/Refrigerator.png',
  ),
  VocabularyItem(
    word: 'Roof',
    thaiPhonetics: 'รูฟ',
    translation: 'หลังคา',
    imagePath: 'assets/images/vocabulary/house/Roof.png',
  ),
  VocabularyItem(
    word: 'Room',
    thaiPhonetics: 'รูม',
    translation: 'ห้อง',
    imagePath: 'assets/images/vocabulary/house/Room.png',
  ),
  VocabularyItem(
    word: 'Shower',
    thaiPhonetics: 'เชา เวอะ',
    translation: 'ฝักบัวอาบน้ำ',
    imagePath: 'assets/images/vocabulary/house/Shower.png',
  ),
  VocabularyItem(
    word: 'Soap',
    thaiPhonetics: 'โซพ',
    translation: 'สบู่',
    imagePath: 'assets/images/vocabulary/house/Soap.png',
  ),
  VocabularyItem(
    word: 'Sofa',
    thaiPhonetics: 'โซ ฟา',
    translation: 'โซฟา',
    imagePath: 'assets/images/vocabulary/house/Sofa.png',
  ),
  VocabularyItem(
    word: 'Spoon',
    thaiPhonetics: 'สพูน',
    translation: 'ช้อน',
    imagePath: 'assets/images/vocabulary/house/Spoon.png',
  ),
  VocabularyItem(
    word: 'Stairs',
    thaiPhonetics: 'สแตร์ส',
    translation: 'บันได',
    imagePath: 'assets/images/vocabulary/house/Stairs.png',
  ),
  VocabularyItem(
    word: 'Table',
    thaiPhonetics: 'เท เบิล',
    translation: 'โต๊ะ',
    imagePath: 'assets/images/vocabulary/house/Table.png',
  ),
  VocabularyItem(
    word: 'Television',
    thaiPhonetics: 'เทล เลอะ วิช เชิน',
    translation: 'โทรทัศน์',
    imagePath: 'assets/images/vocabulary/house/Television.png',
  ),
  VocabularyItem(
    word: 'Toilet',
    thaiPhonetics: 'ทอย ลิท',
    translation: 'ชักโครก',
    imagePath: 'assets/images/vocabulary/house/Toilet.png',
  ),
  VocabularyItem(
    word: 'Towel',
    thaiPhonetics: 'ทาว เอิล',
    translation: 'ผ้าขนหนู',
    imagePath: 'assets/images/vocabulary/house/Towel.png',
  ),
  VocabularyItem(
    word: 'Wall',
    thaiPhonetics: 'วอลล์',
    translation: 'ฝาผนัง / กำแพง',
    imagePath: 'assets/images/vocabulary/house/Wall.png',
  ),
  VocabularyItem(
    word: 'Washingmachine',
    thaiPhonetics: 'วอช ชิง มะ ชีน',
    translation: 'เครื่องซักผ้า',
    imagePath: 'assets/images/vocabulary/house/Washingmachine.png',
  ),
  VocabularyItem(
    word: 'Window',
    thaiPhonetics: 'วิน โดว์',
    translation: 'หน้าต่าง',
    imagePath: 'assets/images/vocabulary/house/Window.png',
  ),
];
