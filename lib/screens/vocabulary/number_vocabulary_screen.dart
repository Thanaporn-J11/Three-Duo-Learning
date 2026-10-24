import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "ตัวเลข" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class NumberVocabularyScreen extends StatelessWidget {
  const NumberVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'number',
      categoryTitle: 'ตัวเลข',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดตัวเลข',
  badge: 'ตัวเลข',
  icon: Icons.format_list_numbered_rounded,
  background: Color(0xFF2E7D32),
  border: Color(0xFF29672C),
  shadow: Color(0xFF0F3813),
  imageBackground: Color(0xFFE3FFD0),
  speakerShadow: Color(0xFF1B5E20),
  wordSize: 42,
  wordLongLength: 11,
  wordLongSize: 32,
  translationSize: 34,
  translationLongLength: 999,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'Zero',
    thaiPhonetics: 'ซี โร',
    translation: '0 (ศูนย์)',
    imagePath: 'assets/images/vocabulary/numbers/Zero.png',
  ),
  VocabularyItem(
    word: 'One',
    thaiPhonetics: 'วัน',
    translation: '1 (หนึ่ง)',
    imagePath: 'assets/images/vocabulary/numbers/One.png',
  ),
  VocabularyItem(
    word: 'Two',
    thaiPhonetics: 'ทู',
    translation: '2 (สอง)',
    imagePath: 'assets/images/vocabulary/numbers/Two.png',
  ),
  VocabularyItem(
    word: 'Three',
    thaiPhonetics: 'ทรี',
    translation: '3 (สาม)',
    imagePath: 'assets/images/vocabulary/numbers/Three.png',
  ),
  VocabularyItem(
    word: 'Four',
    thaiPhonetics: 'ฟอร์',
    translation: '4 (สี่)',
    imagePath: 'assets/images/vocabulary/numbers/Four.png',
  ),
  VocabularyItem(
    word: 'Five',
    thaiPhonetics: 'ไฟฟ์',
    translation: '5 (ห้า)',
    imagePath: 'assets/images/vocabulary/numbers/Five.png',
  ),
  VocabularyItem(
    word: 'Six',
    thaiPhonetics: 'ซิกส์',
    translation: '6 (หก)',
    imagePath: 'assets/images/vocabulary/numbers/Six.png',
  ),
  VocabularyItem(
    word: 'Seven',
    thaiPhonetics: 'เซฟ เวิน',
    translation: '7 (เจ็ด)',
    imagePath: 'assets/images/vocabulary/numbers/Seven.png',
  ),
  VocabularyItem(
    word: 'Eight',
    thaiPhonetics: 'เอท',
    translation: '8 (แปด)',
    imagePath: 'assets/images/vocabulary/numbers/Eight.png',
  ),
  VocabularyItem(
    word: 'Nine',
    thaiPhonetics: 'ไนน์',
    translation: '9 (เก้า)',
    imagePath: 'assets/images/vocabulary/numbers/Nine.png',
  ),
  VocabularyItem(
    word: 'Ten',
    thaiPhonetics: 'เทน',
    translation: '10 (สิบ)',
    imagePath: 'assets/images/vocabulary/numbers/Ten.png',
  ),
  VocabularyItem(
    word: 'Eleven',
    thaiPhonetics: 'อิ เลฟ เวิน',
    translation: '11 (สิบเอ็ด)',
    imagePath: 'assets/images/vocabulary/numbers/Eleven.png',
  ),
  VocabularyItem(
    word: 'Twelve',
    thaiPhonetics: 'ทเวลฟ์',
    translation: '12 (สิบสอง)',
    imagePath: 'assets/images/vocabulary/numbers/Twelve.png',
  ),
  VocabularyItem(
    word: 'Thirteen',
    thaiPhonetics: 'เธิร์ ทีน',
    translation: '13 (สิบสาม)',
    imagePath: 'assets/images/vocabulary/numbers/Thirteen.png',
  ),
  VocabularyItem(
    word: 'Fourteen',
    thaiPhonetics: 'ฟอร์ ทีน',
    translation: '14 (สิบสี่)',
    imagePath: 'assets/images/vocabulary/numbers/Fourteen.png',
  ),
  VocabularyItem(
    word: 'Fifteen',
    thaiPhonetics: 'ฟิฟ ทีน',
    translation: '15 (สิบห้า)',
    imagePath: 'assets/images/vocabulary/numbers/Fifteen.png',
  ),
  VocabularyItem(
    word: 'Sixteen',
    thaiPhonetics: 'ซิกส์ ทีน',
    translation: '16 (สิบหก)',
    imagePath: 'assets/images/vocabulary/numbers/Sixteen.png',
  ),
  VocabularyItem(
    word: 'Seventeen',
    thaiPhonetics: 'เซฟ เวิน ทีน',
    translation: '17 (สิบเจ็ด)',
    imagePath: 'assets/images/vocabulary/numbers/Seventeen.png',
  ),
  VocabularyItem(
    word: 'Eighteen',
    thaiPhonetics: 'เอท ทีน',
    translation: '18 (สิบแปด)',
    imagePath: 'assets/images/vocabulary/numbers/Eighteen.png',
  ),
  VocabularyItem(
    word: 'Nineteen',
    thaiPhonetics: 'ไนน์ ทีน',
    translation: '19 (สิบเก้า)',
    imagePath: 'assets/images/vocabulary/numbers/Nineteen.png',
  ),
  VocabularyItem(
    word: 'Twenty',
    thaiPhonetics: 'ทเวน ที',
    translation: '20 (ยี่สิบ)',
    imagePath: 'assets/images/vocabulary/numbers/Twenty.png',
  ),
  VocabularyItem(
    word: 'Twenty-one',
    thaiPhonetics: 'ทเวน ที วัน',
    translation: '21 (ยี่สิบเอ็ด)',
    imagePath: 'assets/images/vocabulary/numbers/Twenty-one.png',
  ),
  VocabularyItem(
    word: 'Twenty-two',
    thaiPhonetics: 'ทเวน ที ทู',
    translation: '22 (ยี่สิบสอง)',
    imagePath: 'assets/images/vocabulary/numbers/Twenty-two.png',
  ),
  VocabularyItem(
    word: 'Twenty-three',
    thaiPhonetics: 'ทเวน ที ทรี',
    translation: '23 (ยี่สิบสาม)',
    imagePath: 'assets/images/vocabulary/numbers/Twenty-three.png',
  ),
  VocabularyItem(
    word: 'Twenty-four',
    thaiPhonetics: 'ทเวน ที ฟอร์',
    translation: '24 (ยี่สิบสี่)',
    imagePath: 'assets/images/vocabulary/numbers/Twenty-four.png',
  ),
  VocabularyItem(
    word: 'Twenty-five',
    thaiPhonetics: 'ทเวน ที ไฟฟ์',
    translation: '25 (ยี่สิบห้า)',
    imagePath: 'assets/images/vocabulary/numbers/Twenty-five.png',
  ),
  VocabularyItem(
    word: 'Twenty-six',
    thaiPhonetics: 'ทเวน ที ซิกส์',
    translation: '26 (ยี่สิบหก)',
    imagePath: 'assets/images/vocabulary/numbers/Twenty-six.png',
  ),
  VocabularyItem(
    word: 'Twenty-seven',
    thaiPhonetics: 'ทเวน ที เซฟ เวิน',
    translation: '27 (ยี่สิบเจ็ด)',
    imagePath: 'assets/images/vocabulary/numbers/Twenty-seven.png',
  ),
  VocabularyItem(
    word: 'Twenty-eight',
    thaiPhonetics: 'ทเวน ที เอท',
    translation: '28 (ยี่สิบแปด)',
    imagePath: 'assets/images/vocabulary/numbers/Twenty-eight.png',
  ),
  VocabularyItem(
    word: 'Twenty-nine',
    thaiPhonetics: 'ทเวน ที ไนน์',
    translation: '29 (ยี่สิบเก้า)',
    imagePath: 'assets/images/vocabulary/numbers/Twenty-nine.png',
  ),
  VocabularyItem(
    word: 'Thirty',
    thaiPhonetics: 'เธิร์ ที',
    translation: '30 (สามสิบ)',
    imagePath: 'assets/images/vocabulary/numbers/Thirty.png',
  ),
  VocabularyItem(
    word: 'Forty',
    thaiPhonetics: 'ฟอร์ ที',
    translation: '40 (สี่สิบ)',
    imagePath: 'assets/images/vocabulary/numbers/Forty.png',
  ),
  VocabularyItem(
    word: 'Fifty',
    thaiPhonetics: 'ฟิฟ ที',
    translation: '50 (ห้าสิบ)',
    imagePath: 'assets/images/vocabulary/numbers/Fifty.png',
  ),
  VocabularyItem(
    word: 'Sixty',
    thaiPhonetics: 'ซิกส์ ที',
    translation: '60 (หกสิบ)',
    imagePath: 'assets/images/vocabulary/numbers/Sixty.png',
  ),
  VocabularyItem(
    word: 'Seventy',
    thaiPhonetics: 'เซฟ เวิน ที',
    translation: '70 (เจ็ดสิบ)',
    imagePath: 'assets/images/vocabulary/numbers/Seventy.png',
  ),
  VocabularyItem(
    word: 'Eighty',
    thaiPhonetics: 'เอท ที',
    translation: '80 (แปดสิบ)',
    imagePath: 'assets/images/vocabulary/numbers/Eighty.png',
  ),
  VocabularyItem(
    word: 'Ninety',
    thaiPhonetics: 'ไนน์ ที',
    translation: '90 (เก้าสิบ)',
    imagePath: 'assets/images/vocabulary/numbers/Ninety.png',
  ),
  VocabularyItem(
    word: 'One hundred',
    thaiPhonetics: 'วัน ฮัน เดริด',
    translation: '100 (หนึ่งร้อย)',
    imagePath: 'assets/images/vocabulary/numbers/One hundred.png',
  ),
];
