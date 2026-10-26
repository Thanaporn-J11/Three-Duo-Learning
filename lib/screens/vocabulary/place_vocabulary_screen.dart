import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "สถานที่" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class PlaceVocabularyScreen extends StatelessWidget {
  const PlaceVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'place',
      categoryTitle: 'สถานที่',
      words: kPlaceWords,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดสถานที่',
  badge: 'สถานที่',
  icon: Icons.place_rounded,
  background: Color(0xFFC2185B),
  border: Color(0xFF970B55),
  shadow: Color(0xFF560027),
  imageBackground: Color(0xFFC8C5FF),
  speakerShadow: Color(0xFF880E4F),
  wordSize: 42,
);

/// The words of this category (also used by the first-letter game).
const List<VocabularyItem> kPlaceWords = [
  VocabularyItem(
    word: 'Airport',
    thaiPhonetics: 'แอร์ พอร์ต',
    translation: 'สนามบิน / ท่าอากาศยาน',
    imagePath: 'assets/images/vocabulary/places/Airport.png',
  ),
  VocabularyItem(
    word: 'Bakery',
    thaiPhonetics: 'เบ เกอ รี',
    translation: 'ร้านเบเกอรี่ / ร้านขนมปัง',
    imagePath: 'assets/images/vocabulary/places/Bakery.png',
  ),
  VocabularyItem(
    word: 'Bank',
    thaiPhonetics: 'แบงก์',
    translation: 'ธนาคาร',
    imagePath: 'assets/images/vocabulary/places/Bank.png',
  ),
  VocabularyItem(
    word: 'Beach',
    thaiPhonetics: 'บีช',
    translation: 'ชายหาด',
    imagePath: 'assets/images/vocabulary/places/Beach.png',
  ),
  VocabularyItem(
    word: 'Bus Station',
    thaiPhonetics: 'บัส สเต เชิน',
    translation: 'สถานีขนส่ง / ท่ารถประจำทาง',
    imagePath: 'assets/images/vocabulary/places/Bus Station.png',
  ),
  VocabularyItem(
    word: 'Cafe',
    thaiPhonetics: 'คา เฟ่',
    translation: 'ร้านกาแฟ / คาเฟ่',
    imagePath: 'assets/images/vocabulary/places/Cafe.png',
  ),
  VocabularyItem(
    word: 'Church',
    thaiPhonetics: 'เชิร์ช',
    translation: 'โบสถ์',
    imagePath: 'assets/images/vocabulary/places/Church.png',
  ),
  VocabularyItem(
    word: 'Cinema',
    thaiPhonetics: 'ซิ เน มา',
    translation: 'โรงภาพยนตร์ / โรงหนัง',
    imagePath: 'assets/images/vocabulary/places/Cinema.png',
  ),
  VocabularyItem(
    word: 'Factory',
    thaiPhonetics: 'แฟก ทอ รี',
    translation: 'โรงงาน',
    imagePath: 'assets/images/vocabulary/places/Factory.png',
  ),
  VocabularyItem(
    word: 'Fire Station',
    thaiPhonetics: 'ไฟร์ สเต เชิน',
    translation: 'สถานีดับเพลิง',
    imagePath: 'assets/images/vocabulary/places/Fire Station.png',
  ),
  VocabularyItem(
    word: 'Gas Station',
    thaiPhonetics: 'แก๊ส สเต เชิน',
    translation: 'ปั๊มน้ำมัน / สถานีบริการน้ำมัน',
    imagePath: 'assets/images/vocabulary/places/Gasstation.png',
  ),
  VocabularyItem(
    word: 'Gym',
    thaiPhonetics: 'ยิม',
    translation: 'ห้องออกกำลังกาย / ยิม',
    imagePath: 'assets/images/vocabulary/places/Gym.png',
  ),
  VocabularyItem(
    word: 'Home',
    thaiPhonetics: 'โฮม',
    translation: 'บ้าน',
    imagePath: 'assets/images/vocabulary/places/Home.png',
  ),
  VocabularyItem(
    word: 'Hospital',
    thaiPhonetics: 'ฮอส พิ เทิล',
    translation: 'โรงพยาบาล',
    imagePath: 'assets/images/vocabulary/places/Hospital.png',
  ),
  VocabularyItem(
    word: 'Hotel',
    thaiPhonetics: 'โฮ เทล',
    translation: 'โรงแรม',
    imagePath: 'assets/images/vocabulary/places/Hotel.png',
  ),
  VocabularyItem(
    word: 'Library',
    thaiPhonetics: 'ไล บรา รี',
    translation: 'ห้องสมุด',
    imagePath: 'assets/images/vocabulary/places/Library.png',
  ),
  VocabularyItem(
    word: 'Market',
    thaiPhonetics: 'มาร์ เก็ต',
    translation: 'ตลาด',
    imagePath: 'assets/images/vocabulary/places/Market.png',
  ),
  VocabularyItem(
    word: 'Mosque',
    thaiPhonetics: 'มอสค์',
    translation: 'มัสยิด',
    imagePath: 'assets/images/vocabulary/places/Mosque.png',
  ),
  VocabularyItem(
    word: 'Mountain',
    thaiPhonetics: 'เมาน์ เทิน',
    translation: 'ภูเขา',
    imagePath: 'assets/images/vocabulary/places/Mountain.png',
  ),
  VocabularyItem(
    word: 'Museum',
    thaiPhonetics: 'มิว เซียม',
    translation: 'พิพิธภัณฑ์',
    imagePath: 'assets/images/vocabulary/places/Museum.png',
  ),
  VocabularyItem(
    word: 'Office',
    thaiPhonetics: 'ออฟ ฟิศ',
    translation: 'สำนักงาน / ที่ทำงาน',
    imagePath: 'assets/images/vocabulary/places/office.png',
  ),
  VocabularyItem(
    word: 'Park',
    thaiPhonetics: 'พาร์ค',
    translation: 'สวนสาธารณะ',
    imagePath: 'assets/images/vocabulary/places/Park.png',
  ),
  VocabularyItem(
    word: 'Pharmacy',
    thaiPhonetics: 'ฟาร์ มะ ซี',
    translation: 'ร้านขายยา',
    imagePath: 'assets/images/vocabulary/places/Pharmacy.png',
  ),
  VocabularyItem(
    word: 'Police Station',
    thaiPhonetics: 'พะ ลิส สเต เชิน',
    translation: 'สถานีตำรวจ',
    imagePath: 'assets/images/vocabulary/places/Police Station.png',
  ),
  VocabularyItem(
    word: 'Post Office',
    thaiPhonetics: 'โพสต์ ออฟ ฟิศ',
    translation: 'ที่ทำการไปรษณีย์',
    imagePath: 'assets/images/vocabulary/places/Post Office.png',
  ),
  VocabularyItem(
    word: 'Restaurant',
    thaiPhonetics: 'เรส โต รองต์',
    translation: 'ร้านอาหาร / ภัตตาคาร',
    imagePath: 'assets/images/vocabulary/places/Restaurant.png',
  ),
  VocabularyItem(
    word: 'School',
    thaiPhonetics: 'สคูล',
    translation: 'โรงเรียน',
    imagePath: 'assets/images/vocabulary/places/School.png',
  ),
  VocabularyItem(
    word: 'Shopping Mall',
    thaiPhonetics: 'ช็อป ปิง มอลล์',
    translation: 'ห้างสรรพสินค้า',
    imagePath: 'assets/images/vocabulary/places/Shopping Mall.png',
  ),
  VocabularyItem(
    word: 'Supermarket',
    thaiPhonetics: 'ซู เปอร์ มาร์ เก็ต',
    translation: 'ซูเปอร์มาร์เก็ต',
    imagePath: 'assets/images/vocabulary/places/Supermarket.png',
  ),
  VocabularyItem(
    word: 'Temple',
    thaiPhonetics: 'เทม เพิล',
    translation: 'วัด',
    imagePath: 'assets/images/vocabulary/places/Temple.png',
  ),
  VocabularyItem(
    word: 'Train Station',
    thaiPhonetics: 'เทรน สเต เชิน',
    translation: 'สถานีรถไฟ',
    imagePath: 'assets/images/vocabulary/places/Train Station.png',
  ),
  VocabularyItem(
    word: 'Zoo',
    thaiPhonetics: 'ซู',
    translation: 'สวนสัตว์',
    imagePath: 'assets/images/vocabulary/places/Zoo.png',
  ),
];
