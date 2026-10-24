import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "เดือน" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class MonthVocabularyScreen extends StatelessWidget {
  const MonthVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'month',
      categoryTitle: 'เดือน',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดเดือน',
  badge: 'เดือน',
  icon: Icons.calendar_month_rounded,
  background: Color(0xFFE65100),
  border: Color(0xFFBF360C),
  shadow: Color(0xFF5D1A06),
  imageBackground: Color(0xFFE1F5FE),
  speakerShadow: Color(0xFFBF360C),
  wordSize: 44,
  wordLongLength: 8,
  wordLongSize: 36,
  translationSize: 36,
  translationLongLength: 999,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'January',
    thaiPhonetics: 'แจน ยู เอ รอ รี',
    translation: 'มกราคม',
    imagePath: 'assets/images/vocabulary/months/January.png',
  ),
  VocabularyItem(
    word: 'February',
    thaiPhonetics: 'เฟบ รู เอ รอ รี',
    translation: 'กุมภาพันธ์',
    imagePath: 'assets/images/vocabulary/months/February.png',
  ),
  VocabularyItem(
    word: 'March',
    thaiPhonetics: 'มาร์ช',
    translation: 'มีนาคม',
    imagePath: 'assets/images/vocabulary/months/March.png',
  ),
  VocabularyItem(
    word: 'April',
    thaiPhonetics: 'เอ พริล',
    translation: 'เมษายน',
    imagePath: 'assets/images/vocabulary/months/April.png',
  ),
  VocabularyItem(
    word: 'May',
    thaiPhonetics: 'เมย์',
    translation: 'พฤษภาคม',
    imagePath: 'assets/images/vocabulary/months/May.png',
  ),
  VocabularyItem(
    word: 'June',
    thaiPhonetics: 'จูน',
    translation: 'มิถุนายน',
    imagePath: 'assets/images/vocabulary/months/June.png',
  ),
  VocabularyItem(
    word: 'July',
    thaiPhonetics: 'จู ลาย',
    translation: 'กรกฎาคม',
    imagePath: 'assets/images/vocabulary/months/July.png',
  ),
  VocabularyItem(
    word: 'August',
    thaiPhonetics: 'ออ กัสต์',
    translation: 'สิงหาคม',
    imagePath: 'assets/images/vocabulary/months/August.png',
  ),
  VocabularyItem(
    word: 'September',
    thaiPhonetics: 'เซพ เทม เบอร์',
    translation: 'กันยายน',
    imagePath: 'assets/images/vocabulary/months/September.png',
  ),
  VocabularyItem(
    word: 'October',
    thaiPhonetics: 'อ็อก โท เบอร์',
    translation: 'ตุลาคม',
    imagePath: 'assets/images/vocabulary/months/October.png',
  ),
  VocabularyItem(
    word: 'November',
    thaiPhonetics: 'โน เวม เบอร์',
    translation: 'พฤศจิกายน',
    imagePath: 'assets/images/vocabulary/months/November.png',
  ),
  VocabularyItem(
    word: 'December',
    thaiPhonetics: 'ดิ เซม เบอร์',
    translation: 'ธันวาคม',
    imagePath: 'assets/images/vocabulary/months/December.png',
  ),
];
