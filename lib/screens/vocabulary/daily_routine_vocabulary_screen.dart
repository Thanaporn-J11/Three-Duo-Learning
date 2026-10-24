import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "กิจวัตรประจำวัน" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class DailyRoutineVocabularyScreen extends StatelessWidget {
  const DailyRoutineVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'daily-routine',
      categoryTitle: 'กิจวัตรประจำวัน',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดกิจวัตรประจำวัน',
  badge: 'กิจวัตรประจำวัน',
  icon: Icons.schedule_rounded,
  background: Color(0xFF006D77),
  border: Color(0xFF00383D),
  shadow: Color(0xFF002226),
  imageBackground: Color(0xFFE1F5FE),
  speakerShadow: Color(0xFF00383D),
  titleSize: 20,
  badgeSize: 13,
  wordSize: 40,
  wordLongLength: 14,
  wordLongSize: 28,
  wordMidLength: 10,
  wordMidSize: 34,
  dashToSpace: true,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'Brush my teeth',
    phonetics: '/brʌʃ maɪ tiːθ/',
    thaiPhonetics: 'บรัช มาย ทีธ',
    translation: 'แปรงฟัน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Brushmyteeth.png',
  ),
  VocabularyItem(
    word: 'Clean my room',
    phonetics: '/kliːn maɪ ruːm/',
    thaiPhonetics: 'คลีน มาย รูม',
    translation: 'ทำความสะอาดห้อง',
    imagePath: 'assets/images/vocabulary/dailyroutine/Cleanmyroom.png',
  ),
  VocabularyItem(
    word: 'Comb my hair',
    phonetics: '/kəʊm maɪ heər/',
    thaiPhonetics: 'โคม มาย แฮร์',
    translation: 'หวีผม',
    imagePath: 'assets/images/vocabulary/dailyroutine/Combmyhair.png',
  ),
  VocabularyItem(
    word: 'Do homework',
    phonetics: '/duː ˈhəʊm.wɜːk/',
    thaiPhonetics: 'ดู โฮม เวิร์ก',
    translation: 'ทำการบ้าน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Dohomework.png',
  ),
  VocabularyItem(
    word: 'Dream',
    phonetics: '/driːm/',
    thaiPhonetics: 'ดรีม',
    translation: 'ฝัน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Dream.png',
  ),
  VocabularyItem(
    word: 'Drink water',
    phonetics: '/drɪŋk ˈwɔː.tər/',
    thaiPhonetics: 'ดริงก์ วอ เทอะ',
    translation: 'ดื่มน้ำ',
    imagePath: 'assets/images/vocabulary/dailyroutine/Drinkwater.png',
  ),
  VocabularyItem(
    word: 'Exercise',
    phonetics: '/ˈek.sə.saɪz/',
    thaiPhonetics: 'เอ็ก เซอะ ไซส์',
    translation: 'ออกกำลังกาย',
    imagePath: 'assets/images/vocabulary/dailyroutine/Exercise.png',
  ),
  VocabularyItem(
    word: 'Get dressed',
    phonetics: '/ɡet drest/',
    thaiPhonetics: 'เก็ต เดรสต์',
    translation: 'แต่งตัว',
    imagePath: 'assets/images/vocabulary/dailyroutine/Getdressed.png',
  ),
  VocabularyItem(
    word: 'Get up',
    phonetics: '/ɡet ʌp/',
    thaiPhonetics: 'เก็ต อัป',
    translation: 'ลุกขึ้นจากที่นอน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Getup.png',
  ),
  VocabularyItem(
    word: 'Go home',
    phonetics: '/ɡəʊ həʊm/',
    thaiPhonetics: 'โก โฮม',
    translation: 'กลับบ้าน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Gohome.png',
  ),
  VocabularyItem(
    word: 'Go shopping',
    phonetics: '/ɡəʊ ˈʃɒp.ɪŋ/',
    thaiPhonetics: 'โก ช็อป ปิง',
    translation: 'ไปซื้อของ',
    imagePath: 'assets/images/vocabulary/dailyroutine/Goshopping.png',
  ),
  VocabularyItem(
    word: 'Go to school',
    phonetics: '/ɡəʊ tuː skuːl/',
    thaiPhonetics: 'โก ทู สคูล',
    translation: 'ไปโรงเรียน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Gotoschool.png',
  ),
  VocabularyItem(
    word: 'Have breakfast',
    phonetics: '/hæv ˈbrek.fəst/',
    thaiPhonetics: 'แฮฟ เบรค เฟิสต์',
    translation: 'รับประทานอาหารเช้า',
    imagePath: 'assets/images/vocabulary/dailyroutine/Havebreakfast.png',
  ),
  VocabularyItem(
    word: 'Listen',
    phonetics: '/ˈlɪs.ən/',
    thaiPhonetics: 'ลิส เซิน',
    translation: 'ฟัง',
    imagePath: 'assets/images/vocabulary/dailyroutine/Listen.png',
  ),
  VocabularyItem(
    word: 'Make my bed',
    phonetics: '/meɪk maɪ bed/',
    thaiPhonetics: 'เมค มาย เบด',
    translation: 'จัดที่นอน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Makemybed.png',
  ),
  VocabularyItem(
    word: 'Meet my friends',
    phonetics: '/miːt maɪ frendz/',
    thaiPhonetics: 'มีท มาย เฟรนดส์',
    translation: 'พบปะเพื่อนๆ',
    imagePath: 'assets/images/vocabulary/dailyroutine/Meetmyfriends.png',
  ),
  VocabularyItem(
    word: 'Pack my bag',
    phonetics: '/pæk maɪ bæɡ/',
    thaiPhonetics: 'แพ็ก มาย แบ็ก',
    translation: 'จัดกระเป๋า',
    imagePath: 'assets/images/vocabulary/dailyroutine/Packmybag.png',
  ),
  VocabularyItem(
    word: 'Play games',
    phonetics: '/pleɪ ɡeɪmz/',
    thaiPhonetics: 'เพลย์ เกมส์',
    translation: 'เล่นเกม',
    imagePath: 'assets/images/vocabulary/dailyroutine/Playgames.png',
  ),
  VocabularyItem(
    word: 'Read',
    phonetics: '/riːd/',
    thaiPhonetics: 'รีด',
    translation: 'อ่าน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Read.png',
  ),
  VocabularyItem(
    word: 'Read a book',
    phonetics: '/riːd ə bʊk/',
    thaiPhonetics: 'รีด อะ บุ๊ก',
    translation: 'อ่านหนังสือ',
    imagePath: 'assets/images/vocabulary/dailyroutine/Readabook.png',
  ),
  VocabularyItem(
    word: 'Ride a bike',
    phonetics: '/raɪd ə baɪk/',
    thaiPhonetics: 'ไรด์ อะ ไบค์',
    translation: 'ปั่นจักรยาน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Rideabike.png',
  ),
  VocabularyItem(
    word: 'Sleep',
    phonetics: '/sliːp/',
    thaiPhonetics: 'สลีป',
    translation: 'นอนหลับ',
    imagePath: 'assets/images/vocabulary/dailyroutine/Sleep.png',
  ),
  VocabularyItem(
    word: 'Study',
    phonetics: '/ˈstʌd.i/',
    thaiPhonetics: 'สตัด ดี',
    translation: 'เรียนหนังสือ',
    imagePath: 'assets/images/vocabulary/dailyroutine/Study.png',
  ),
  VocabularyItem(
    word: 'Take a bath',
    phonetics: '/teɪk ə bɑːθ/',
    thaiPhonetics: 'เทค อะ บาธ',
    translation: 'แช่อ่างอาบน้ำ',
    imagePath: 'assets/images/vocabulary/dailyroutine/Takeabath.png',
  ),
  VocabularyItem(
    word: 'Take a shower',
    phonetics: '/teɪk ə ˈʃaʊ.ər/',
    thaiPhonetics: 'เทค อะ เชา เวอะ',
    translation: 'อาบน้ำฝักบัว',
    imagePath: 'assets/images/vocabulary/dailyroutine/Takeashower.png',
  ),
  VocabularyItem(
    word: 'Wake up',
    phonetics: '/weɪk ʌp/',
    thaiPhonetics: 'เวค อัป',
    translation: 'ตื่นนอน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Wakeup.png',
  ),
  VocabularyItem(
    word: 'Wash my face',
    phonetics: '/wɒʃ maɪ feɪs/',
    thaiPhonetics: 'วอช มาย เฟซ',
    translation: 'ล้างหน้า',
    imagePath: 'assets/images/vocabulary/dailyroutine/Washmyface.png',
  ),
  VocabularyItem(
    word: 'Wash the dishes',
    phonetics: '/wɒʃ ðə dɪʃ.ɪz/',
    thaiPhonetics: 'วอช เดอะ ดิช ชิซ',
    translation: 'ล้างจาน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Washthedishes.png',
  ),
  VocabularyItem(
    word: 'Watch TV',
    phonetics: '/wɒtʃ ˌtiːˈviː/',
    thaiPhonetics: 'วอทช์ ที วี',
    translation: 'ดูโทรทัศน์',
    imagePath: 'assets/images/vocabulary/dailyroutine/WatchTV.png',
  ),
  VocabularyItem(
    word: 'Write',
    phonetics: '/raɪt/',
    thaiPhonetics: 'ไรต์',
    translation: 'เขียน',
    imagePath: 'assets/images/vocabulary/dailyroutine/Write.png',
  ),
];
