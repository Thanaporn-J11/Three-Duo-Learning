import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class PlaceItem {
  final String word;
  final String phonetics; // คำอ่าน
  final String translation;
  final String imagePath;

  PlaceItem({
    required this.word,
    required this.phonetics,
    required this.translation,
    required this.imagePath,
  });
}

class PlaceVocabularyScreen extends StatefulWidget {
  const PlaceVocabularyScreen({super.key});

  @override
  State<PlaceVocabularyScreen> createState() => _PlaceVocabularyScreenState();
}

class _PlaceVocabularyScreenState extends State<PlaceVocabularyScreen> {
  int currentIndex = 0;
  late FlutterTts flutterTts;
  bool isSpeaking = false;

  // 🏙️ ข้อมูลคำศัพท์หมวดสถานที่ (Place) ทั้ง 25 คำตรงตามไฟล์รูปภาพ
  final List<PlaceItem> places = [
    PlaceItem(
      word: 'Airport',
      phonetics: 'แอร์-พอร์ต',
      translation: 'สนามบิน / ท่าอากาศยาน',
      imagePath: 'assets/images/vocabulary/places/Airport.png',
    ),
    PlaceItem(
      word: 'Bakery',
      phonetics: 'เบ-เกอ-รี',
      translation: 'ร้านเบเกอรี่ / ร้านขนมปัง',
      imagePath: 'assets/images/vocabulary/places/Bakery.jpg',
    ),
    PlaceItem(
      word: 'Bank',
      phonetics: 'แบงก์',
      translation: 'ธนาคาร',
      imagePath: 'assets/images/vocabulary/places/Bank.png',
    ),
    PlaceItem(
      word: 'Beach',
      phonetics: 'บีช',
      translation: 'ชายหาด',
      imagePath: 'assets/images/vocabulary/places/Beach.jpg',
    ),
    PlaceItem(
      word: 'Bus Station',
      phonetics: 'บัส-สเต-เชิน',
      translation: 'สถานีขนส่ง / ท่ารถประจำทาง',
      imagePath: 'assets/images/vocabulary/places/Bus Station.jpg',
    ),
    PlaceItem(
      word: 'Cafe',
      phonetics: 'คา-เฟ่',
      translation: 'ร้านกาแฟ / คาเฟ่',
      imagePath: 'assets/images/vocabulary/places/Cafe.png',
    ),
    PlaceItem(
      word: 'Cinema',
      phonetics: 'ซิ-เน-มา',
      translation: 'โรงภาพยนตร์ / โรงหนัง',
      imagePath: 'assets/images/vocabulary/places/Cinema.png',
    ),
    PlaceItem(
      word: 'Factory',
      phonetics: 'แฟค-โท-รี',
      translation: 'โรงงาน',
      imagePath: 'assets/images/vocabulary/places/Factory.png',
    ),
    PlaceItem(
      word: 'Fire Station',
      phonetics: 'ไฟร์-สเต-เชิน',
      translation: 'สถานีดับเพลิง',
      imagePath: 'assets/images/vocabulary/places/Fire Station.png',
    ),
    PlaceItem(
      word: 'Gym',
      phonetics: 'ยิม',
      translation: 'โรงยิม / ฟิตเนส',
      imagePath: 'assets/images/vocabulary/places/Gym.jpg',
    ),
    PlaceItem(
      word: 'Hospital',
      phonetics: 'ฮอส-พิ-เทิล',
      translation: 'โรงพยาบาล',
      imagePath: 'assets/images/vocabulary/places/Hospital.jpg',
    ),
    PlaceItem(
      word: 'Hotel',
      phonetics: 'โฮ-เทล',
      translation: 'โรงแรม',
      imagePath: 'assets/images/vocabulary/places/Hotel.png',
    ),
    PlaceItem(
      word: 'Library',
      phonetics: 'ไล-บรา-รี',
      translation: 'ห้องสมุด',
      imagePath: 'assets/images/vocabulary/places/Library.jpg',
    ),
    PlaceItem(
      word: 'Mountain',
      phonetics: 'เมาน์-เทิน',
      translation: 'ภูเขา',
      imagePath: 'assets/images/vocabulary/places/Mountain.jpg',
    ),
    PlaceItem(
      word: 'Office',
      phonetics: 'ออฟ-ฟิศ',
      translation: 'สำนักงาน / ที่ทำงาน',
      imagePath: 'assets/images/vocabulary/places/Office.jpg',
    ),
    PlaceItem(
      word: 'Park',
      phonetics: 'พาร์ค',
      translation: 'สวนสาธารณะ',
      imagePath: 'assets/images/vocabulary/places/Park.png',
    ),
    PlaceItem(
      word: 'Pharmacy',
      phonetics: 'ฟาร์-มะ-ซี',
      translation: 'ร้านขายยา',
      imagePath: 'assets/images/vocabulary/places/Pharmacy.jpg',
    ),
    PlaceItem(
      word: 'Police Station',
      phonetics: 'พะ-ลิส-สเต-เชิน',
      translation: 'สถานีตำรวจ',
      imagePath: 'assets/images/vocabulary/places/Police Station.jpg',
    ),
    PlaceItem(
      word: 'Post Office',
      phonetics: 'โพสต์-ออฟ-ฟิศ',
      translation: 'ที่ทำการไปรษณีย์',
      imagePath: 'assets/images/vocabulary/places/Post Office.jpg',
    ),
    PlaceItem(
      word: 'Restaurant',
      phonetics: 'เรส-โต-รองต์',
      translation: 'ร้านอาหาร / ภัตตาคาร',
      imagePath: 'assets/images/vocabulary/places/Restaurant.png',
    ),
    PlaceItem(
      word: 'School',
      phonetics: 'สคูล',
      translation: 'โรงเรียน',
      imagePath: 'assets/images/vocabulary/places/School.png',
    ),
    PlaceItem(
      word: 'Shopping Mall',
      phonetics: 'ช็อป-ปิง-มอลล์',
      translation: 'ห้างสรรพสินค้า',
      imagePath: 'assets/images/vocabulary/places/Shopping Mall.jpg',
    ),
    PlaceItem(
      word: 'Supermarket',
      phonetics: 'ซู-เปอร์-มาร์-เก็ต',
      translation: 'ซูเปอร์มาร์เก็ต',
      imagePath: 'assets/images/vocabulary/places/Supermarket.jpg',
    ),
    PlaceItem(
      word: 'Temple',
      phonetics: 'เทม-เพิล',
      translation: 'วัด',
      imagePath: 'assets/images/vocabulary/places/Temple.jpg',
    ),
    PlaceItem(
      word: 'Train Station',
      phonetics: 'เทรน-สเต-เชิน',
      translation: 'สถานีรถไฟ',
      imagePath: 'assets/images/vocabulary/places/Train Station.png',
    ),
    PlaceItem(
      word: 'Zoo',
      phonetics: 'ซู',
      translation: 'สวนสัตว์',
      imagePath: 'assets/images/vocabulary/places/Zoo.jpg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() {
    flutterTts = FlutterTts();
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.45);
    flutterTts.setVolume(1.0);
    flutterTts.setPitch(1.0);

    flutterTts.setStartHandler(() => setState(() => isSpeaking = true));
    flutterTts.setCompletionHandler(() => setState(() => isSpeaking = false));
    flutterTts.setErrorHandler((msg) => setState(() => isSpeaking = false));
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  void _nextWord() {
    if (currentIndex < places.length - 1) {
      setState(() => currentIndex++);
    } else {
      _showCompletionDialog();
    }
  }

  void _previousWord() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8F5FE),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0088FF).withOpacity(0.12),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/character/bravo.png',
                    height: 145,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.stars_rounded, size: 80, color: Color(0xFF0088FF)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'เยี่ยมมาก!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: Color(0xFF0D5C9E),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'คุณเรียนรู้คำศัพท์ครบทั้ง ${places.length} คำแล้ว',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // ปิด Dialog
                    Navigator.pop(context); // กลับหน้า Category
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadowColor: const Color(0xFF0088FF).withOpacity(0.35),
                  ),
                  child: const Text(
                    'กลับหน้าหลัก',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPlace = places[currentIndex];
    final progress = (currentIndex + 1) / places.length;

    return Scaffold(
      backgroundColor: const Color(0xFFEDF5FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF0D5C9E), size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'คำศัพท์หมวดสถานที่',
          style: TextStyle(
            color: Color(0xFF0D5C9E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6FAFD),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D5C9E).withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header Progress & Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Text(
                              'คำศัพท์',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0088FF),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Text(
                            '${currentIndex + 1} / ${places.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5A789A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // แถบ Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          tween: Tween<double>(begin: 0, end: progress),
                          builder: (context, value, _) => LinearProgressIndicator(
                            value: value,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFDCEAF7),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0088FF)),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // กล่องพื้นหลังรูปภาพ (สี่เหลี่ยมมุมมน ความสูง 360)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Container(
                          key: ValueKey<int>(currentIndex),
                          height: 360,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D5C9E).withOpacity(0.08),
                                blurRadius: 16,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Image.asset(
                                currentPlace.imagePath,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.image_not_supported_rounded, size: 80, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // คำศัพท์ + ปุ่มกดฟังเสียง
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey<int>(currentIndex),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    currentPlace.word,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => _speak(currentPlace.word),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSpeaking ? const Color(0xFF00C853) : const Color(0xFF0088FF),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isSpeaking ? const Color(0xFF00C853) : const Color(0xFF0088FF)).withOpacity(0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // คำอ่าน
                            Text(
                              currentPlace.phonetics,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // คำแปลภาษาไทย
                            Text(
                              currentPlace.translation,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D5C9E),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 2),

                      // ปุ่มย้อนกลับและถัดไป
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: currentIndex > 0 ? _previousWord : null,
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text('ย้อนกลับ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0D5C9E),
                                side: const BorderSide(color: Color(0xFFCCE0F2), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _nextWord,
                              icon: Icon(
                                currentIndex == places.length - 1 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(
                                currentIndex == places.length - 1 ? 'เสร็จสิ้น' : 'ถัดไป',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0088FF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                shadowColor: const Color(0xFF0088FF).withOpacity(0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}