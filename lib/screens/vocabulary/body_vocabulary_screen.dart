import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "ร่างกาย" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class BodyVocabularyScreen extends StatelessWidget {
  const BodyVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'body',
      categoryTitle: 'ร่างกาย',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดร่างกาย',
  badge: 'ร่างกาย',
  icon: Icons.accessibility_new_rounded,
  background: Color(0xFF00897B),
  border: Color(0xFF004D40),
  shadow: Color(0xFF00332C),
  imageBackground: Color(0xFFFFF0E6),
  speakerShadow: Color(0xFF004D40),
  wordSize: 44,
  wordLongLength: 999,
  translationSize: 36,
  translationLongLength: 999,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'Arm',
    thaiPhonetics: 'อาร์ม',
    translation: 'แขน',
    imagePath: 'assets/images/vocabulary/body/Arm.png',
  ),
  VocabularyItem(
    word: 'Ear',
    thaiPhonetics: 'เอียร์',
    translation: 'หู',
    imagePath: 'assets/images/vocabulary/body/Ear.png',
  ),
  VocabularyItem(
    word: 'Eye',
    thaiPhonetics: 'อาย',
    translation: 'ตา',
    imagePath: 'assets/images/vocabulary/body/Eye.png',
  ),
  VocabularyItem(
    word: 'Foot',
    thaiPhonetics: 'ฟุต',
    translation: 'เท้า',
    imagePath: 'assets/images/vocabulary/body/Foot.png',
  ),
  VocabularyItem(
    word: 'Hair',
    thaiPhonetics: 'แฮร์',
    translation: 'ผม',
    imagePath: 'assets/images/vocabulary/body/Hair.png',
  ),
  VocabularyItem(
    word: 'Hand',
    thaiPhonetics: 'แฮนด์',
    translation: 'มือ',
    imagePath: 'assets/images/vocabulary/body/Hand.png',
  ),
  VocabularyItem(
    word: 'Head',
    thaiPhonetics: 'เฮด',
    translation: 'ศีรษะ / หัว',
    imagePath: 'assets/images/vocabulary/body/Head.png',
  ),
  VocabularyItem(
    word: 'Leg',
    thaiPhonetics: 'เลก',
    translation: 'ขา',
    imagePath: 'assets/images/vocabulary/body/Leg.png',
  ),
  VocabularyItem(
    word: 'Mouth',
    thaiPhonetics: 'เมาธ์',
    translation: 'ปาก',
    imagePath: 'assets/images/vocabulary/body/Mouth.png',
  ),
  VocabularyItem(
    word: 'Nose',
    thaiPhonetics: 'โนส',
    translation: 'จมูก',
    imagePath: 'assets/images/vocabulary/body/Nose.png',
  ),
  VocabularyItem(
    word: 'Belly',
    thaiPhonetics: 'เบล ลี่',
    translation: 'ท้อง / พุง',
    imagePath: 'assets/images/vocabulary/body/Belly.png',
  ),
  VocabularyItem(
    word: 'Bone',
    thaiPhonetics: 'โบน',
    translation: 'กระดูก',
    imagePath: 'assets/images/vocabulary/body/Bone.png',
  ),
  VocabularyItem(
    word: 'Brain',
    thaiPhonetics: 'เบรน',
    translation: 'สมอง',
    imagePath: 'assets/images/vocabulary/body/Brain.png',
  ),
  VocabularyItem(
    word: 'Cheek',
    thaiPhonetics: 'ชีค',
    translation: 'แก้ม',
    imagePath: 'assets/images/vocabulary/body/Cheek.png',
  ),
  VocabularyItem(
    word: 'Chest',
    thaiPhonetics: 'เชสต์',
    translation: 'หน้าอก',
    imagePath: 'assets/images/vocabulary/body/Chest.png',
  ),
  VocabularyItem(
    word: 'Chin',
    thaiPhonetics: 'ชิน',
    translation: 'คาง',
    imagePath: 'assets/images/vocabulary/body/Chin.png',
  ),
  VocabularyItem(
    word: 'Eyebrow',
    thaiPhonetics: 'อาย เบรา',
    translation: 'คิ้ว',
    imagePath: 'assets/images/vocabulary/body/Eyebrow.png',
  ),
  VocabularyItem(
    word: 'Eyelash',
    thaiPhonetics: 'อาย แลช',
    translation: 'ขนตา',
    imagePath: 'assets/images/vocabulary/body/Eyelash.png',
  ),
  VocabularyItem(
    word: 'Face',
    thaiPhonetics: 'เฟซ',
    translation: 'ใบหน้า',
    imagePath: 'assets/images/vocabulary/body/Face.png',
  ),
  VocabularyItem(
    word: 'Finger',
    thaiPhonetics: 'ฟิง เกอร์',
    translation: 'นิ้วมือ',
    imagePath: 'assets/images/vocabulary/body/Finger.png',
  ),
  VocabularyItem(
    word: 'Forehead',
    thaiPhonetics: 'ฟอร์ เฮด',
    translation: 'หน้าผาก',
    imagePath: 'assets/images/vocabulary/body/Forehead.png',
  ),
  VocabularyItem(
    word: 'Heart',
    thaiPhonetics: 'ฮาร์ท',
    translation: 'หัวใจ',
    imagePath: 'assets/images/vocabulary/body/Heart.png',
  ),
  VocabularyItem(
    word: 'Lip',
    thaiPhonetics: 'ลิป',
    translation: 'ริมฝีปาก',
    imagePath: 'assets/images/vocabulary/body/Lip.png',
  ),
  VocabularyItem(
    word: 'Lungs',
    thaiPhonetics: 'ลังส์',
    translation: 'ปอด',
    imagePath: 'assets/images/vocabulary/body/Lungs.png',
  ),
  VocabularyItem(
    word: 'Nail',
    thaiPhonetics: 'เนล',
    translation: 'เล็บ',
    imagePath: 'assets/images/vocabulary/body/Nail.png',
  ),
  VocabularyItem(
    word: 'Neck',
    thaiPhonetics: 'เน็ค',
    translation: 'คอ',
    imagePath: 'assets/images/vocabulary/body/Neck.png',
  ),
  VocabularyItem(
    word: 'Shoulder',
    thaiPhonetics: 'โชล เดอร์',
    translation: 'ไหล่',
    imagePath: 'assets/images/vocabulary/body/Shoulder.png',
  ),
  VocabularyItem(
    word: 'Thigh',
    thaiPhonetics: 'ทาย',
    translation: 'ต้นขา',
    imagePath: 'assets/images/vocabulary/body/Thigh.png',
  ),
  VocabularyItem(
    word: 'Tongue',
    thaiPhonetics: 'ทัง',
    translation: 'ลิ้น',
    imagePath: 'assets/images/vocabulary/body/Tongue.png',
  ),
  VocabularyItem(
    word: 'Tooth',
    thaiPhonetics: 'ทูธ',
    translation: 'ฟัน',
    imagePath: 'assets/images/vocabulary/body/Tooth.png',
  ),
];
