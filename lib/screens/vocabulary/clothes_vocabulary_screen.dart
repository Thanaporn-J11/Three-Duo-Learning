import 'package:flutter/material.dart';

import 'vocabulary_lesson_screen.dart';

/// Vocabulary lesson of the "เสื้อผ้า" category: the words and the colours; the page itself is
/// [VocabularyLessonScreen].
class ClothesVocabularyScreen extends StatelessWidget {
  const ClothesVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VocabularyLessonScreen(
      slug: 'clothes',
      categoryTitle: 'เสื้อผ้า',
      words: _words,
      theme: _theme,
    );
  }
}

const VocabularyTheme _theme = VocabularyTheme(
  title: 'คำศัพท์หมวดเสื้อผ้า',
  badge: 'เสื้อผ้า',
  icon: Icons.checkroom_rounded,
  background: Color(0xFF1565C0),
  border: Color(0xFF0D47A1),
  shadow: Color(0xFF082B61),
  imageBackground: Color(0xFFFCE4EC),
  speakerShadow: Color(0xFF0D47A1),
  wordSize: 42,
  wordLongSize: 34,
);

const List<VocabularyItem> _words = [
  VocabularyItem(
    word: 'Dress',
    thaiPhonetics: 'เดรส',
    translation: 'ชุดกระโปรง / ชุดเดรส',
    imagePath: 'assets/images/vocabulary/clothes/Dress.png',
  ),
  VocabularyItem(
    word: 'Hat',
    thaiPhonetics: 'แฮท',
    translation: 'หมวก',
    imagePath: 'assets/images/vocabulary/clothes/Hat.png',
  ),
  VocabularyItem(
    word: 'Jacket',
    thaiPhonetics: 'แจ็ก กิต',
    translation: 'เสื้อแจ็คเก็ต',
    imagePath: 'assets/images/vocabulary/clothes/Jacket.png',
  ),
  VocabularyItem(
    word: 'Pants',
    thaiPhonetics: 'แพนทส์',
    translation: 'กางเกงขายาว',
    imagePath: 'assets/images/vocabulary/clothes/Pants.png',
  ),
  VocabularyItem(
    word: 'Shirt',
    thaiPhonetics: 'เชิร์ต',
    translation: 'เสื้อเชิ้ต',
    imagePath: 'assets/images/vocabulary/clothes/Shirt.png',
  ),
  VocabularyItem(
    word: 'Shoes',
    thaiPhonetics: 'ชูส์',
    translation: 'รองเท้า',
    imagePath: 'assets/images/vocabulary/clothes/Shoes.png',
  ),
  VocabularyItem(
    word: 'Shorts',
    thaiPhonetics: 'ชอร์ทส์',
    translation: 'กางเกงขาสั้น',
    imagePath: 'assets/images/vocabulary/clothes/Shorts.png',
  ),
  VocabularyItem(
    word: 'Skirt',
    thaiPhonetics: 'สเกิร์ต',
    translation: 'กระโปรง',
    imagePath: 'assets/images/vocabulary/clothes/Skirt.png',
  ),
  VocabularyItem(
    word: 'Sock',
    thaiPhonetics: 'ซ็อก',
    translation: 'ถุงเท้า',
    imagePath: 'assets/images/vocabulary/clothes/Sock.png',
  ),
  VocabularyItem(
    word: 'T Shirt',
    thaiPhonetics: 'ที เชิร์ต',
    translation: 'เสื้อยืด',
    imagePath: 'assets/images/vocabulary/clothes/T Shirt.png',
  ),
  VocabularyItem(
    word: 'Bag',
    thaiPhonetics: 'แบ็ก',
    translation: 'กระเป๋า',
    imagePath: 'assets/images/vocabulary/clothes/Bag.png',
  ),
  VocabularyItem(
    word: 'Belt',
    thaiPhonetics: 'เบลท์',
    translation: 'เข็มขัด',
    imagePath: 'assets/images/vocabulary/clothes/Belt.png',
  ),
  VocabularyItem(
    word: 'Boots',
    thaiPhonetics: 'บูทส์',
    translation: 'รองเท้าบูท',
    imagePath: 'assets/images/vocabulary/clothes/Boots.png',
  ),
  VocabularyItem(
    word: 'Cap',
    thaiPhonetics: 'แคป',
    translation: 'หมวกแก๊ป',
    imagePath: 'assets/images/vocabulary/clothes/Cap.png',
  ),
  VocabularyItem(
    word: 'Earrings',
    thaiPhonetics: 'เอียร์ ริงส์',
    translation: 'ต่างหู',
    imagePath: 'assets/images/vocabulary/clothes/Earrings.png',
  ),
  VocabularyItem(
    word: 'Glasses',
    thaiPhonetics: 'แกลส ซิส',
    translation: 'แว่นตา',
    imagePath: 'assets/images/vocabulary/clothes/Glasses.png',
  ),
  VocabularyItem(
    word: 'Hoodie',
    thaiPhonetics: 'ฮู้ด ดี้',
    translation: 'เสื้อมีฮู้ด',
    imagePath: 'assets/images/vocabulary/clothes/Hoodie.png',
  ),
  VocabularyItem(
    word: 'Jeans',
    thaiPhonetics: 'ยีนส์',
    translation: 'กางเกงยีนส์',
    imagePath: 'assets/images/vocabulary/clothes/Jeans.png',
  ),
  VocabularyItem(
    word: 'Necklace',
    thaiPhonetics: 'เน็ค เลิส',
    translation: 'สร้อยคอ',
    imagePath: 'assets/images/vocabulary/clothes/Necklace.png',
  ),
  VocabularyItem(
    word: 'Pajamas',
    thaiPhonetics: 'พะ จา มัส',
    translation: 'ชุดนอน',
    imagePath: 'assets/images/vocabulary/clothes/Pajamas.png',
  ),
  VocabularyItem(
    word: 'Raincoat',
    thaiPhonetics: 'เรน โค้ท',
    translation: 'เสื้อกันฝน',
    imagePath: 'assets/images/vocabulary/clothes/Raincoat.png',
  ),
  VocabularyItem(
    word: 'Ring',
    thaiPhonetics: 'ริง',
    translation: 'แหวน',
    imagePath: 'assets/images/vocabulary/clothes/Ring.png',
  ),
  VocabularyItem(
    word: 'Scarf',
    thaiPhonetics: 'สคาร์ฟ',
    translation: 'ผ้าพันคอ',
    imagePath: 'assets/images/vocabulary/clothes/Scarf.png',
  ),
  VocabularyItem(
    word: 'Sunglasses',
    thaiPhonetics: 'ซัน แกลส ซิส',
    translation: 'แว่นตากันแดด',
    imagePath: 'assets/images/vocabulary/clothes/Sunglasses.png',
  ),
  VocabularyItem(
    word: 'Sweater',
    thaiPhonetics: 'สเวต เตอร์',
    translation: 'เสื้อกันหนาว / สเวตเตอร์',
    imagePath: 'assets/images/vocabulary/clothes/Sweater.png',
  ),
  VocabularyItem(
    word: 'Swimsuit',
    thaiPhonetics: 'สวิม สูท',
    translation: 'ชุดว่ายน้ำ',
    imagePath: 'assets/images/vocabulary/clothes/Swimsuit.png',
  ),
  VocabularyItem(
    word: 'Tie',
    thaiPhonetics: 'ไท',
    translation: 'เนคไท',
    imagePath: 'assets/images/vocabulary/clothes/Tie.png',
  ),
  VocabularyItem(
    word: 'Uniform',
    thaiPhonetics: 'ยู นิ ฟอร์ม',
    translation: 'เครื่องแบบ / ยูนิฟอร์ม',
    imagePath: 'assets/images/vocabulary/clothes/Uniform.png',
  ),
  VocabularyItem(
    word: 'Watch',
    thaiPhonetics: 'วอทช์',
    translation: 'นาฬิกาข้อมือ',
    imagePath: 'assets/images/vocabulary/clothes/Watch.png',
  ),
];
