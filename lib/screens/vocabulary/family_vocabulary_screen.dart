import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "ครอบครัว" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class FamilyVocabularyScreen extends StatelessWidget {
  const FamilyVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'family',
      categoryTitle: 'ครอบครัว',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดครอบครัว',
  badge: 'ครอบครัว',
  icon: Icons.groups_rounded,
  background: Color(0xFF2E6F40),
  border: Color(0xFF1B4326),
  shadow: Color(0xFF112918),
  imageBackground: Color(0xFFFFF0E6),
  speakerShadow: Color(0xFF1B4326),
  wordSize: 40,
  wordLongLength: 11,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'Baby',
    thaiPhonetics: 'เบ บี',
    translation: 'เด็กทารก',
    imagePath: 'assets/images/vocabulary/family/Baby.png',
  ),
  VocabularyItem(
    word: 'Brother',
    thaiPhonetics: 'บรา เธอร์',
    translation: 'พี่ชาย / น้องชาย',
    imagePath: 'assets/images/vocabulary/family/Brother.png',
  ),
  VocabularyItem(
    word: 'Child',
    thaiPhonetics: 'ชายลด์',
    translation: 'เด็ก',
    imagePath: 'assets/images/vocabulary/family/Child.png',
  ),
  VocabularyItem(
    word: 'Daughter',
    thaiPhonetics: 'ดอ เทอร์',
    translation: 'ลูกสาว',
    imagePath: 'assets/images/vocabulary/family/Daughter.png',
  ),
  VocabularyItem(
    word: 'Family',
    thaiPhonetics: 'แฟม มะ ลี',
    translation: 'ครอบครัว',
    imagePath: 'assets/images/vocabulary/family/Family.png',
  ),
  VocabularyItem(
    word: 'Father',
    thaiPhonetics: 'ฟา เธอร์',
    translation: 'พ่อ',
    imagePath: 'assets/images/vocabulary/family/Father.png',
  ),
  VocabularyItem(
    word: 'Grandfather',
    thaiPhonetics: 'แกรนด์ ฟา เธอร์',
    translation: 'ปู่ / ตา',
    imagePath: 'assets/images/vocabulary/family/Grandfather.png',
  ),
  VocabularyItem(
    word: 'Grandmother',
    thaiPhonetics: 'แกรนด์ มา เธอร์',
    translation: 'ย่า / ยาย',
    imagePath: 'assets/images/vocabulary/family/Grandmother.png',
  ),
  VocabularyItem(
    word: 'Grandparents',
    thaiPhonetics: 'แกรนด์ แพ เรินท์ส',
    translation: 'ปู่ย่าตายาย',
    imagePath: 'assets/images/vocabulary/family/Grandparents.png',
  ),
  VocabularyItem(
    word: 'Mother',
    thaiPhonetics: 'มา เธอร์',
    translation: 'แม่',
    imagePath: 'assets/images/vocabulary/family/Mother.png',
  ),
  VocabularyItem(
    word: 'Parents',
    thaiPhonetics: 'แพ เรินท์ส',
    translation: 'พ่อแม่ / ผู้ปกครอง',
    imagePath: 'assets/images/vocabulary/family/Parents.png',
  ),
  VocabularyItem(
    word: 'Relative',
    thaiPhonetics: 'เรล ละ ทิฟ',
    translation: 'ญาติ',
    imagePath: 'assets/images/vocabulary/family/Relative.png',
  ),
  VocabularyItem(
    word: 'Sibling',
    thaiPhonetics: 'ซิบ ลิง',
    translation: 'พี่น้อง',
    imagePath: 'assets/images/vocabulary/family/Sibling.png',
  ),
  VocabularyItem(
    word: 'Sister',
    thaiPhonetics: 'ซิส เตอร์',
    translation: 'พี่สาว / น้องสาว',
    imagePath: 'assets/images/vocabulary/family/Sister.png',
  ),
  VocabularyItem(
    word: 'Son',
    thaiPhonetics: 'ซัน',
    translation: 'ลูกชาย',
    imagePath: 'assets/images/vocabulary/family/Son.png',
  ),
  VocabularyItem(
    word: 'Twin',
    thaiPhonetics: 'ทวิน',
    translation: 'ฝาแฝด',
    imagePath: 'assets/images/vocabulary/family/Twin.png',
  ),
];
