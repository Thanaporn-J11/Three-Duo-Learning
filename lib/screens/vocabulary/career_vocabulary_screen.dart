import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "อาชีพ" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class CareerVocabularyScreen extends StatelessWidget {
  const CareerVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'career',
      categoryTitle: 'อาชีพ',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดอาชีพ',
  badge: 'อาชีพ',
  icon: Icons.work_rounded,
  background: Color(0xFF3346A2),
  border: Color(0xFF1A237E),
  shadow: Color(0xFF0F1654),
  imageBackground: Color(0xFFF3E5F5),
  speakerShadow: Color(0xFF1A237E),
  wordSize: 42,
  wordLongSize: 34,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'Accountant',
    thaiPhonetics: 'อะ เคาท์ เทินท์',
    translation: 'นักบัญชี',
    imagePath: 'assets/images/vocabulary/careers/Accountant.png',
  ),
  VocabularyItem(
    word: 'Architect',
    thaiPhonetics: 'อาร์ คิ เท็คท์',
    translation: 'สถาปนิก',
    imagePath: 'assets/images/vocabulary/careers/Architect.png',
  ),
  VocabularyItem(
    word: 'Artist',
    thaiPhonetics: 'อาร์ ทิสท์',
    translation: 'ศิลปิน / จิตรกร',
    imagePath: 'assets/images/vocabulary/careers/Artist.png',
  ),
  VocabularyItem(
    word: 'Carpenter',
    thaiPhonetics: 'คาร์ เพน เทอร์',
    translation: 'ช่างไม้',
    imagePath: 'assets/images/vocabulary/careers/Carpenter.png',
  ),
  VocabularyItem(
    word: 'Cashier',
    thaiPhonetics: 'แคช เชียร์',
    translation: 'พนักงานคิดเงิน',
    imagePath: 'assets/images/vocabulary/careers/Cashier.png',
  ),
  VocabularyItem(
    word: 'Chef',
    thaiPhonetics: 'เชฟ',
    translation: 'พ่อครัว / เชฟ',
    imagePath: 'assets/images/vocabulary/careers/Chef.png',
  ),
  VocabularyItem(
    word: 'Dentist',
    thaiPhonetics: 'เดน ทิสท์',
    translation: 'ทันตแพทย์ / หมอฟัน',
    imagePath: 'assets/images/vocabulary/careers/Dentist.png',
  ),
  VocabularyItem(
    word: 'Doctor',
    thaiPhonetics: 'ด็อก เตอร์',
    translation: 'แพทย์ / หมอ',
    imagePath: 'assets/images/vocabulary/careers/Doctor.png',
  ),
  VocabularyItem(
    word: 'Electrician',
    thaiPhonetics: 'อิ เล็ก ทริช เชิน',
    translation: 'ช่างไฟฟ้า',
    imagePath: 'assets/images/vocabulary/careers/Electrician.png',
  ),
  VocabularyItem(
    word: 'Engineer',
    thaiPhonetics: 'เอน จิ เนียร์',
    translation: 'วิศวกร',
    imagePath: 'assets/images/vocabulary/careers/Engineer.png',
  ),
  VocabularyItem(
    word: 'Farmer',
    thaiPhonetics: 'ฟาร์ม เมอร์',
    translation: 'ชาวนา / เกษตรกร',
    imagePath: 'assets/images/vocabulary/careers/Farmer.png',
  ),
  VocabularyItem(
    word: 'Firefighter',
    thaiPhonetics: 'ไฟร์ ไฟท์ เทอร์',
    translation: 'นักดับเพลิง',
    imagePath: 'assets/images/vocabulary/careers/Firefighter.png',
  ),
  VocabularyItem(
    word: 'Flight Attendant',
    thaiPhonetics: 'ไฟลต์ อะ เทน เดินท์',
    translation: 'พนักงานต้อนรับบนเครื่องบิน',
    imagePath: 'assets/images/vocabulary/careers/Flight Attendant.png',
  ),
  VocabularyItem(
    word: 'Journalist',
    thaiPhonetics: 'เจอร์ นะ ลิสท์',
    translation: 'นักข่าว / นักหนังสือพิมพ์',
    imagePath: 'assets/images/vocabulary/careers/Journalist.png',
  ),
  VocabularyItem(
    word: 'Lawyer',
    thaiPhonetics: 'ลอ เยอร์',
    translation: 'ทนายความ',
    imagePath: 'assets/images/vocabulary/careers/Lawyer.png',
  ),
  VocabularyItem(
    word: 'Mechanic',
    thaiPhonetics: 'มะ แคน นิก',
    translation: 'ช่างยนต์ / ช่างเครื่อง',
    imagePath: 'assets/images/vocabulary/careers/Mechanic.png',
  ),
  VocabularyItem(
    word: 'Musician',
    thaiPhonetics: 'มิว ซิช เชิน',
    translation: 'นักดนตรี',
    imagePath: 'assets/images/vocabulary/careers/Musician.png',
  ),
  VocabularyItem(
    word: 'Nurse',
    thaiPhonetics: 'เนิร์ส',
    translation: 'พยาบาล',
    imagePath: 'assets/images/vocabulary/careers/Nurse.png',
  ),
  VocabularyItem(
    word: 'Pharmacist',
    thaiPhonetics: 'ฟาร์ มะ ซิสท์',
    translation: 'เภสัชกร',
    imagePath: 'assets/images/vocabulary/careers/Pharmacist.png',
  ),
  VocabularyItem(
    word: 'Photographer',
    thaiPhonetics: 'ฟะ ท็อก ระ เฟอร์',
    translation: 'ช่างภาพ',
    imagePath: 'assets/images/vocabulary/careers/Photographer.png',
  ),
  VocabularyItem(
    word: 'Pilot',
    thaiPhonetics: 'ไพ ลัท',
    translation: 'นักบิน',
    imagePath: 'assets/images/vocabulary/careers/Pilot.png',
  ),
  VocabularyItem(
    word: 'Plumber',
    thaiPhonetics: 'พลัม เมอร์',
    translation: 'ช่างประปา',
    imagePath: 'assets/images/vocabulary/careers/Plumber.png',
  ),
  VocabularyItem(
    word: 'Police Officer',
    thaiPhonetics: 'พะ ลิส ออฟ ฟิ เซอร์',
    translation: 'เจ้าหน้าที่ตำรวจ',
    imagePath: 'assets/images/vocabulary/careers/Police Officer.png',
  ),
  VocabularyItem(
    word: 'Programmer',
    thaiPhonetics: 'โปร แกรม เมอร์',
    translation: 'โปรแกรมเมอร์',
    imagePath: 'assets/images/vocabulary/careers/Programmer.png',
  ),
  VocabularyItem(
    word: 'Scientist',
    thaiPhonetics: 'ไซ เอิน ทิสท์',
    translation: 'นักวิทยาศาสตร์',
    imagePath: 'assets/images/vocabulary/careers/Scientist.png',
  ),
  VocabularyItem(
    word: 'Soldier',
    thaiPhonetics: 'โซล เจอร์',
    translation: 'ทหาร',
    imagePath: 'assets/images/vocabulary/careers/Soldier.png',
  ),
  VocabularyItem(
    word: 'Teacher',
    thaiPhonetics: 'ทีช เฉอร์',
    translation: 'ครู / อาจารย์',
    imagePath: 'assets/images/vocabulary/careers/Teacher.png',
  ),
  VocabularyItem(
    word: 'Veterinarian',
    thaiPhonetics: 'เวท เทอ ริ แน เรียน',
    translation: 'สัตวแพทย์',
    imagePath: 'assets/images/vocabulary/careers/Veterinarian.png',
  ),
  VocabularyItem(
    word: 'Waiter',
    thaiPhonetics: 'เวท เทอร์',
    translation: 'บริกรชาย',
    imagePath: 'assets/images/vocabulary/careers/Waiter.png',
  ),
  VocabularyItem(
    word: 'Waitress',
    thaiPhonetics: 'เวท เทรส',
    translation: 'บริกรหญิง',
    imagePath: 'assets/images/vocabulary/careers/Waitress.png',
  ),
  VocabularyItem(
    word: 'Athlete',
    thaiPhonetics: 'แอธ ลีท',
    translation: 'นักกีฬา',
    imagePath: 'assets/images/vocabulary/careers/Athlete.png',
  ),
  VocabularyItem(
    word: 'Dancer',
    thaiPhonetics: 'แดน เซอร์',
    translation: 'นักเต้น',
    imagePath: 'assets/images/vocabulary/careers/Dancer.png',
  ),
  VocabularyItem(
    word: 'Driver',
    thaiPhonetics: 'ไดรฟ์ เวอร์',
    translation: 'คนขับรถ',
    imagePath: 'assets/images/vocabulary/careers/Driver.png',
  ),
  VocabularyItem(
    word: 'Fisherman',
    thaiPhonetics: 'ฟิช เชอร์ แมน',
    translation: 'ชาวประมง',
    imagePath: 'assets/images/vocabulary/careers/Fisherman.png',
  ),
  VocabularyItem(
    word: 'Postman',
    thaiPhonetics: 'โพสต์ แมน',
    translation: 'บุรุษไปรษณีย์',
    imagePath: 'assets/images/vocabulary/careers/Postman.png',
  ),
  VocabularyItem(
    word: 'Singer',
    thaiPhonetics: 'ซิง เกอร์',
    translation: 'นักร้อง',
    imagePath: 'assets/images/vocabulary/careers/Singer.png',
  ),
];
