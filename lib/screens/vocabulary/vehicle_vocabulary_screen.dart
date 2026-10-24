import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "ยานพาหนะ" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class VehicleVocabularyScreen extends StatelessWidget {
  const VehicleVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'vehicle',
      categoryTitle: 'ยานพาหนะ',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดยานพาหนะ',
  badge: 'ยานพาหนะ',
  icon: Icons.directions_car_rounded,
  background: Color(0xFF00796B),
  border: Color(0xFF1A6457),
  shadow: Color(0xFF00251F),
  imageBackground: Color(0xFFE6F1FF),
  speakerShadow: Color(0xFF003D33),
  wordSize: 42,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'Airplane',
    thaiPhonetics: 'แอร์ เพลน',
    translation: 'เครื่องบิน',
    imagePath: 'assets/images/vocabulary/vehicles/Airplane.png',
  ),
  VocabularyItem(
    word: 'Bike',
    thaiPhonetics: 'ไบค์',
    translation: 'จักรยาน',
    imagePath: 'assets/images/vocabulary/vehicles/Bike.png',
  ),
  VocabularyItem(
    word: 'Boat',
    thaiPhonetics: 'โบท',
    translation: 'เรือ',
    imagePath: 'assets/images/vocabulary/vehicles/Boat.png',
  ),
  VocabularyItem(
    word: 'Bus',
    thaiPhonetics: 'บัส',
    translation: 'รถประจำทาง / รถเมล์',
    imagePath: 'assets/images/vocabulary/vehicles/Bus.png',
  ),
  VocabularyItem(
    word: 'Car',
    thaiPhonetics: 'คาร์',
    translation: 'รถยนต์',
    imagePath: 'assets/images/vocabulary/vehicles/Car.png',
  ),
  VocabularyItem(
    word: 'Motorcycle',
    thaiPhonetics: 'โม เทอร์ ไซ เคิล',
    translation: 'รถจักรยานยนต์',
    imagePath: 'assets/images/vocabulary/vehicles/Motorcycle.png',
  ),
  VocabularyItem(
    word: 'Taxi',
    thaiPhonetics: 'แท็ก ซี',
    translation: 'รถแท็กซี่',
    imagePath: 'assets/images/vocabulary/vehicles/Taxi.png',
  ),
  VocabularyItem(
    word: 'Train',
    thaiPhonetics: 'เทรน',
    translation: 'รถไฟ',
    imagePath: 'assets/images/vocabulary/vehicles/Train.png',
  ),
  VocabularyItem(
    word: 'Truck',
    thaiPhonetics: 'ทรัค',
    translation: 'รถบรรทุก',
    imagePath: 'assets/images/vocabulary/vehicles/Truck.png',
  ),
  VocabularyItem(
    word: 'Van',
    thaiPhonetics: 'แวน',
    translation: 'รถตู้',
    imagePath: 'assets/images/vocabulary/vehicles/Van.png',
  ),
  VocabularyItem(
    word: 'Ambulance',
    thaiPhonetics: 'แอม บิว แลนซ์',
    translation: 'รถพยาบาล',
    imagePath: 'assets/images/vocabulary/vehicles/Ambulance.png',
  ),
  VocabularyItem(
    word: 'Firetruck',
    thaiPhonetics: 'ไฟร์ ทรัค',
    translation: 'รถดับเพลิง',
    imagePath: 'assets/images/vocabulary/vehicles/Firetruck.png',
  ),
  VocabularyItem(
    word: 'Helicopter',
    thaiPhonetics: 'เฮ ลิ ค็อป เตอร์',
    translation: 'เฮลิคอปเตอร์',
    imagePath: 'assets/images/vocabulary/vehicles/Helicopter.png',
  ),
  VocabularyItem(
    word: 'Rocket',
    thaiPhonetics: 'ร็อก เก็ต',
    translation: 'จรวด',
    imagePath: 'assets/images/vocabulary/vehicles/Rocket.png',
  ),
  VocabularyItem(
    word: 'Schoolbus',
    thaiPhonetics: 'สคูล บัส',
    translation: 'รถโรงเรียน',
    imagePath: 'assets/images/vocabulary/vehicles/Schoolbus.png',
  ),
  VocabularyItem(
    word: 'Ship',
    thaiPhonetics: 'ชิป',
    translation: 'เรือเดินสมุทร / เรือใหญ่',
    imagePath: 'assets/images/vocabulary/vehicles/Ship.png',
  ),
  VocabularyItem(
    word: 'Skytrain',
    thaiPhonetics: 'สกาย เทรน',
    translation: 'รถไฟฟ้า',
    imagePath: 'assets/images/vocabulary/vehicles/Skytrain.png',
  ),
  VocabularyItem(
    word: 'Submarine',
    thaiPhonetics: 'ซับ มะ รีน',
    translation: 'เรือดำน้ำ',
    imagePath: 'assets/images/vocabulary/vehicles/Submarine.png',
  ),
];
