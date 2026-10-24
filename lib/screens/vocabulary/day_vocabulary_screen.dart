import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "วัน" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class DayVocabularyScreen extends StatelessWidget {
  const DayVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'day',
      categoryTitle: 'วัน',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดวัน',
  badge: 'วัน',
  icon: Icons.calendar_today_rounded,
  background: Color(0xFF5E17EB),
  border: Color(0xFF38006B),
  shadow: Color(0xFF260049),
  imageBackground: Color(0xFFEDF7ED),
  speakerShadow: Color(0xFF38006B),
  wordSize: 44,
  wordLongLength: 999,
  translationSize: 36,
  translationLongLength: 999,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'Monday',
    thaiPhonetics: 'มัน เด',
    translation: 'วันจันทร์',
    imagePath: 'assets/images/vocabulary/days/Monday.png',
  ),
  VocabularyItem(
    word: 'Tuesday',
    thaiPhonetics: 'ทิวส์ เด',
    translation: 'วันอังคาร',
    imagePath: 'assets/images/vocabulary/days/Tuesday.png',
  ),
  VocabularyItem(
    word: 'Wednesday',
    thaiPhonetics: 'เวนส์ เด',
    translation: 'วันพุธ',
    imagePath: 'assets/images/vocabulary/days/Wednesday.png',
  ),
  VocabularyItem(
    word: 'Thursday',
    thaiPhonetics: 'เธิร์ซ เด',
    translation: 'วันพฤหัสบดี',
    imagePath: 'assets/images/vocabulary/days/Thursday.png',
  ),
  VocabularyItem(
    word: 'Friday',
    thaiPhonetics: 'ฟราย เด',
    translation: 'วันศุกร์',
    imagePath: 'assets/images/vocabulary/days/Friday.png',
  ),
  VocabularyItem(
    word: 'Saturday',
    thaiPhonetics: 'แซท เทอร์ เด',
    translation: 'วันเสาร์',
    imagePath: 'assets/images/vocabulary/days/Saturday.png',
  ),
  VocabularyItem(
    word: 'Sunday',
    thaiPhonetics: 'ซัน เด',
    translation: 'วันอาทิตย์',
    imagePath: 'assets/images/vocabulary/days/Sunday.png',
  ),
];
