import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../services/lesson_progress.dart';
import '../../services/listening_results_service.dart';
import '../../services/sfx.dart';

// -------------------------------------------------------------
// 1. Data Models
// -------------------------------------------------------------
class AudioFillLessonItem {
  final String title;
  final String placeholderImage;
  final String prefixText;
  final String missingWord;
  final String suffixText;
  final List<String> choices;
  final String thaiTranslation;

  const AudioFillLessonItem({
    required this.title,
    required this.placeholderImage,
    required this.prefixText,
    required this.missingWord,
    required this.suffixText,
    required this.choices,
    required this.thaiTranslation,
  });

  static final RegExp _leadingPunctuation = RegExp(r'^[.,!?;:]+');

  /// Punctuation that must stick to the blank word, e.g. "." in "I like ___."
  String get suffixPunctuation =>
      _leadingPunctuation.firstMatch(suffixText.trimLeft())?.group(0) ?? '';

  /// The rest of the suffix after that punctuation, e.g. "songs." stays whole.
  String get suffixRest =>
      suffixText.trimLeft().substring(suffixPunctuation.length).trim();

  String get fullSentence {
    // No space before punctuation: "I like swimming." not "I like swimming ."
    final rest = suffixRest.isEmpty ? '' : ' $suffixRest';
    final combined = '$prefixText $missingWord$suffixPunctuation$rest'.trim();
    return combined.replaceAll(RegExp(r'\s+'), ' ');
  }
}

class FillBlankTopic {
  final String id;
  final String titleTh;
  final String titleEn;
  final String imageAsset;
  final List<Color> gradientColors;
  final Color shadowColor;
  final List<AudioFillLessonItem> lessons;

  const FillBlankTopic({
    required this.id,
    required this.titleTh,
    required this.titleEn,
    required this.imageAsset,
    required this.gradientColors,
    required this.shadowColor,
    required this.lessons,
  });
}

// -------------------------------------------------------------
// 2. หน้าเลือกบทเรียน (Topic Selector)
// -------------------------------------------------------------
class VideoFillBlankScreen extends StatefulWidget {
  final List<AudioFillLessonItem>? topicLessons;
  final String? topicTitle;

  const VideoFillBlankScreen({
    super.key,
    this.topicLessons,
    this.topicTitle,
  });

  @override
  State<VideoFillBlankScreen> createState() => _VideoFillBlankScreenState();
}

class _VideoFillBlankScreenState extends State<VideoFillBlankScreen> {
  // Saved "continue from question N" per topic (see LessonProgress).
  Map<String, ({int index, int correct})> _progress = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final loaded = <String, ({int index, int correct})>{};
    for (final topic in _get5Topics()) {
      final saved = await LessonProgress.load(topic.id, topic.lessons.length);
      if (saved != null) loaded[topic.id] = saved;
    }
    if (mounted) setState(() => _progress = loaded);
  }

  Future<void> _openTopic(FillBlankTopic topic) async {
    final saved = _progress[topic.id];
    var startIndex = 0;
    var startCorrect = 0;
    if (saved != null) {
      final resume = await _askResume(topic, saved);
      if (resume == null || !mounted) return; // closed the dialog
      if (resume) {
        startIndex = saved.index;
        startCorrect = saved.correct;
      } else {
        await LessonProgress.clear(topic.id);
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoFillBlankExerciseScreen(
          lessons: topic.lessons,
          topicTitle: topic.titleTh,
          topicId: topic.id,
          startIndex: startIndex,
          startCorrect: startCorrect,
        ),
      ),
    );
    _loadProgress(); // refresh the "continue" badges
  }

  /// true = continue, false = start over, null = dismissed.
  Future<bool?> _askResume(
    FillBlankTopic topic,
    ({int index, int correct}) saved,
  ) {
    final total = topic.lessons.length;
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5F7),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFF8BBD0), width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Topic picture on the topic's own colours (same as its card)
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: topic.gradientColors,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: topic.shadowColor.withValues(alpha: 0.45),
                      blurRadius: 0,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Image.asset(
                  topic.imageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'เล่นต่อจากเดิมไหม ?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF33091B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${topic.titleTh} ค้างไว้ที่ข้อ ${saved.index + 1} จาก $total\n'
                'ตอบถูกไปแล้ว ${saved.correct} ข้อ',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7E7278),
                ),
              ),
              const SizedBox(height: 14),
              // Progress dots, like the "ข้อที่ x จาก y" pill in the game
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final done = i < saved.index;
                  final current = i == saved.index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: current ? 20 : 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: done || current
                          ? const Color(0xFFC2185B)
                          : const Color(0xFFF8BBD0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              _pinkButton(
                label: 'เล่นต่อข้อ ${saved.index + 1}',
                icon: Icons.play_arrow_rounded,
                primary: true,
                onTap: () => Navigator.pop(dialogContext, true),
              ),
              const SizedBox(height: 12),
              _pinkButton(
                label: 'เริ่มใหม่ตั้งแต่ข้อ 1',
                icon: Icons.replay_rounded,
                primary: false,
                onTap: () => Navigator.pop(dialogContext, false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3D pill button in the same style as the result screen's buttons:
  /// primary = pink gradient, secondary = white with pink border.
  Widget _pinkButton({
    required String label,
    required IconData icon,
    required bool primary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: primary ? 56 : 52,
        decoration: BoxDecoration(
          color: const Color(0xFF880E4F),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        padding: EdgeInsets.only(bottom: primary ? 5 : 4.5),
        child: Container(
          decoration: BoxDecoration(
            color: primary ? null : Colors.white,
            gradient: primary
                ? const LinearGradient(
                  colors: [Color(0xFFFF80AB), Color(0xFFFF4081)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
                : null,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: primary
                  ? Colors.white.withValues(alpha: 0.8)
                  : const Color(0xFFF8BBD0),
              width: 1.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: primary ? Colors.white : const Color(0xFFC2185B),
                size: primary ? 26 : 23,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: primary ? Colors.white : const Color(0xFFC2185B),
                  fontSize: primary ? 19 : 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  shadows: primary
                      ? const [
                        Shadow(
                          color: Color(0xFF880E4F),
                          offset: Offset(0, 1.5),
                          blurRadius: 2,
                        ),
                      ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<FillBlankTopic> _get5Topics() {
    return const [
      // 1. หมวดสีส้ม: กิจกรรมยามว่าง (รูป activities.png)
      FillBlankTopic(
        id: 'activities',
        titleTh: 'กิจกรรมยามว่าง',
        titleEn: 'ACTIVITIES',
        imageAsset: 'assets/images/sentence/activities.png',
        gradientColors: [Color(0xFFFF9E3D), Color(0xFFFF821C)],
        shadowColor: Color(0xFFD95B00),
        lessons: [
          AudioFillLessonItem(
            title: 'กิจกรรม 1',
            placeholderImage: 'assets/images/sentence/swimming.gif',
            prefixText: 'I like',
            missingWord: 'swimming',
            suffixText: '.',
            choices: ['swimming', 'running', 'sleeping'],
            thaiTranslation: 'ฉันชอบว่ายน้ำ',
          ),
          AudioFillLessonItem(
            title: 'กิจกรรม 2',
            placeholderImage: 'assets/images/sentence/running.gif',
            prefixText: 'We like',
            missingWord: 'running',
            suffixText: '.',
            choices: ['running', 'reading', 'jumping'],
            thaiTranslation: 'พวกเราชอบวิ่งเล่น',
          ),
          AudioFillLessonItem(
            title: 'กิจกรรม 3',
            placeholderImage: 'assets/images/sentence/singing.gif',
            prefixText: 'He likes',
            missingWord: 'singing',
            suffixText: 'songs.',
            choices: ['dancing', 'singing', 'cooking'],
            thaiTranslation: 'เขาชอบร้องเพลง',
          ),
          AudioFillLessonItem(
            title: 'กิจกรรม 4',
            placeholderImage: 'assets/images/sentence/football.gif',
            prefixText: 'They play',
            missingWord: 'football',
            suffixText: 'together.',
            choices: ['tennis', 'football', 'guitar'],
            thaiTranslation: 'พวกเขาเล่นฟุตบอลด้วยกัน',
          ),
          AudioFillLessonItem(
            title: 'กิจกรรม 5',
            placeholderImage: 'assets/images/sentence/runningfast.gif',
            prefixText: 'I can',
            missingWord: 'run',
            suffixText: 'very fast.',
            choices: ['swim', 'fly', 'run'],
            thaiTranslation: 'ฉันวิ่งเร็วมาก',
          ),
          AudioFillLessonItem(
            title: 'กิจกรรม 6',
            placeholderImage: 'assets/images/sentence/books.gif',
            prefixText: 'She loves to',
            missingWord: 'read',
            suffixText: 'books.',
            choices: ['read', 'cook', 'draw'],
            thaiTranslation: 'เธอชอบอ่านหนังสือ',
          ),
          AudioFillLessonItem(
            title: 'กิจกรรม 7',
            placeholderImage: 'assets/images/sentence/draw.gif',
            prefixText: 'I like to',
            missingWord: 'draw',
            suffixText: 'pictures.',
            choices: ['draw', 'sleep', 'jump'],
            thaiTranslation: 'ฉันชอบวาดรูป',
          ),
          AudioFillLessonItem(
            title: 'กิจกรรม 8',
            placeholderImage: 'assets/images/sentence/dance.gif',
            prefixText: 'We can',
            missingWord: 'dance',
            suffixText: 'happily.',
            choices: ['sing', 'dance', 'run'],
            thaiTranslation: 'พวกเราเต้นอย่างมีความสุข',
          ),
        ],
      ),

      // 2. หมวดสีม่วง: สัตว์น่ารักรอบตัว (รูป animals.png)
      FillBlankTopic(
        id: 'animals',
        titleTh: 'สัตว์น่ารักรอบตัว',
        titleEn: 'ANIMALS',
        imageAsset: 'assets/images/sentence/animals.png',
        gradientColors: [Color(0xFFBA68C8), Color(0xFFAB47BC)],
        shadowColor: Color(0xFF7B1FA2),
        lessons: [
          AudioFillLessonItem(
            title: 'สัตว์ 1',
            placeholderImage: 'assets/images/sentence/sleeping.gif',
            prefixText: 'The little cat is',
            missingWord: 'sleeping',
            suffixText: '.',
            choices: ['eating', 'sleeping', 'jumping'],
            thaiTranslation: 'ลูกแมวตัวน้อยกำลังนอนหลับ',
          ),
          AudioFillLessonItem(
            title: 'สัตว์ 2',
            placeholderImage: 'assets/images/sentence/bird.gif',
            prefixText: 'The blue bird can',
            missingWord: 'fly',
            suffixText: 'in the sky.',
            choices: ['run', 'sing', 'fly'],
            thaiTranslation: 'นกสีฟ้าสามารถบินบนท้องฟ้าได้',
          ),
          AudioFillLessonItem(
            title: 'สัตว์ 3',
            placeholderImage: 'assets/images/sentence/Kangaroo.gif',
            prefixText: 'A kangaroo can',
            missingWord: 'jump',
            suffixText: 'very high.',
            choices: ['fly', 'jump', 'swim'],
            thaiTranslation: 'จิงโจ้สามารถกระโดดได้สูงมาก',
          ),
          AudioFillLessonItem(
            title: 'สัตว์ 4',
            placeholderImage: 'assets/images/sentence/dog.gif',
            prefixText: 'The happy dog is',
            missingWord: 'running',
            suffixText: 'in the garden.',
            choices: ['running', 'swimming', 'climbing'],
            thaiTranslation: 'สุนัขแสนร่าเริงกำลังวิ่งเล่นในสวน',
          ),
          AudioFillLessonItem(
            title: 'สัตว์ 5',
            placeholderImage: 'assets/images/sentence/Duck.gif',
            prefixText: 'The little duck is',
            missingWord: 'swimming',
            suffixText: 'in the pond.',
            choices: ['sleeping', 'flying', 'swimming'],
            thaiTranslation: 'ลูกเป็ดกำลังว่ายน้ำอยู่ในสระ',
          ),
          AudioFillLessonItem(
            title: 'สัตว์ 6',
            placeholderImage: 'assets/images/sentence/Rabbit.gif',
            prefixText: 'The cute rabbit has',
            missingWord: 'long',
            suffixText: 'ears.',
            choices: ['short', 'long', 'small'],
            thaiTranslation: 'กระต่ายน่ารักมีหูยาว',
          ),
          AudioFillLessonItem(
            title: 'สัตว์ 7',
            placeholderImage: 'assets/images/sentence/bear.gif',
            prefixText: 'The baby bear is very',
            missingWord: 'cute',
            suffixText: '.',
            choices: ['cute', 'fast', 'tall'],
            thaiTranslation: 'ลูกหมีตัวนี้น่ารักมาก',
          ),
          AudioFillLessonItem(
            title: 'สัตว์ 8',
            placeholderImage: 'assets/images/sentence/Fish.gif',
            prefixText: 'A gold fish can',
            missingWord: 'swim',
            suffixText: 'in the water.',
            choices: ['jump', 'fly', 'swim'],
            thaiTranslation: 'ปลาทองสามารถว่ายน้ำได้',
          ),
        ],
      ),

      // 3. หมวดสีเขียว: อาหารและของโปรด (รูป food.png)
      FillBlankTopic(
        id: 'food',
        titleTh: 'อาหารและของโปรด',
        titleEn: 'FOOD & DRINK',
        imageAsset: 'assets/images/sentence/food.png',
        gradientColors: [Color(0xFF5CC672), Color(0xFF43B55A)],
        shadowColor: Color(0xFF2E8540),
        lessons: [
          AudioFillLessonItem(
            title: 'อาหาร 1',
            placeholderImage: 'assets/images/sentence/Milk.gif',
            prefixText: 'I drink',
            missingWord: 'milk',
            suffixText: 'every morning.',
            choices: ['juice', 'milk', 'water'],
            thaiTranslation: 'ฉันดื่มนมทุก ๆ เช้า',
          ),
          AudioFillLessonItem(
            title: 'อาหาร 2',
            placeholderImage: 'assets/images/sentence/apple.gif',
            prefixText: 'She eats an',
            missingWord: 'apple',
            suffixText: 'for breakfast.',
            choices: ['apple', 'egg', 'orange'],
            thaiTranslation: 'เธอทานแอปเปิ้ลเป็นอาหารเช้า',
          ),
          AudioFillLessonItem(
            title: 'อาหาร 3',
            placeholderImage: 'assets/images/sentence/soup.gif',
            prefixText: 'We have hot',
            missingWord: 'soup',
            suffixText: 'for dinner.',
            choices: ['rice', 'soup', 'bread'],
            thaiTranslation: 'พวกเราทานซุปร้อน ๆ เป็นมื้อเย็น',
          ),
          AudioFillLessonItem(
            title: 'อาหาร 4',
            placeholderImage: 'assets/images/sentence/banana.gif',
            prefixText: 'He loves sweet',
            missingWord: 'banana',
            suffixText: 'after lunch.',
            choices: ['lemon', 'banana', 'onion'],
            thaiTranslation: 'เขาชอบกล้วยหอมหวานหลังมื้อเที่ยง',
          ),
          AudioFillLessonItem(
            title: 'อาหาร 5',
            placeholderImage: 'assets/images/sentence/drink.gif',
            prefixText: 'They drink cold',
            missingWord: 'water',
            suffixText: 'after running.',
            choices: ['tea', 'coffee', 'water'],
            thaiTranslation: 'พวกเขาดื่มน้ำเย็นหลังจากวิ่ง',
          ),
          AudioFillLessonItem(
            title: 'อาหาร 6',
            placeholderImage: 'assets/images/sentence/Bread.gif',
            prefixText: 'I like to eat',
            missingWord: 'bread',
            suffixText: 'with jam.',
            choices: ['bread', 'fish', 'meat'],
            thaiTranslation: 'ฉันชอบทานขนมปังกับแยม',
          ),
          AudioFillLessonItem(
            title: 'อาหาร 7',
            placeholderImage: 'assets/images/sentence/Orangejuice.gif',
            prefixText: 'Orange juice is very',
            missingWord: 'sweet',
            suffixText: '.',
            choices: ['hot', 'sweet', 'salty'],
            thaiTranslation: 'น้ำส้มมีรสหวานมาก',
          ),
          AudioFillLessonItem(
            title: 'อาหาร 8',
            placeholderImage: 'assets/images/sentence/rice.gif',
            prefixText: 'We eat delicious',
            missingWord: 'rice',
            suffixText: 'every day.',
            choices: ['rice', 'cake', 'cookie'],
            thaiTranslation: 'พวกเราทานข้าวอร่อย ๆ ทุกวัน',
          ),
        ],
      ),

      // 4. หมวดสีฟ้า: ครอบครัวและบุคคล (รูป people.png)
      FillBlankTopic(
        id: 'people',
        titleTh: 'ครอบครัวและบุคคล',
        titleEn: 'PEOPLE',
        imageAsset: 'assets/images/sentence/people.png',
        gradientColors: [Color(0xFF4BA5E3), Color(0xFF2B8FD4)],
        shadowColor: Color(0xFF1368A3),
        lessons: [
          AudioFillLessonItem(
            title: 'บุคคล 1',
            placeholderImage: 'assets/images/sentence/teacher.gif',
            prefixText: 'My mother is a',
            missingWord: 'teacher',
            suffixText: '.',
            choices: ['teacher', 'doctor', 'nurse'],
            thaiTranslation: 'คุณแม่ของฉันเป็นคุณครู',
          ),
          AudioFillLessonItem(
            title: 'บุคคล 2',
            placeholderImage: 'assets/images/sentence/tall.gif',
            prefixText: 'My brother is very',
            missingWord: 'tall',
            suffixText: '.',
            choices: ['tall', 'short', 'small'],
            thaiTranslation: 'พี่ชายของฉันตัวสูงมาก',
          ),
          AudioFillLessonItem(
            title: 'บุคคล 3',
            placeholderImage: 'assets/images/sentence/Parents.gif',
            prefixText: 'We love our',
            missingWord: 'family',
            suffixText: 'very much.',
            choices: ['school', 'family', 'house'],
            thaiTranslation: 'พวกเรารักครอบครัวของเรามาก',
          ),
          AudioFillLessonItem(
            title: 'บุคคล 4',
            placeholderImage: 'assets/images/sentence/Doctor.gif',
            prefixText: 'The kind doctor helps',
            missingWord: 'children',
            suffixText: 'at the hospital.',
            choices: ['animals', 'children', 'birds'],
            thaiTranslation: 'คุณหมอใจดีช่วยเหลือเด็ก ๆ ที่โรงพยาบาล',
          ),
          AudioFillLessonItem(
            title: 'บุคคล 5',
            placeholderImage: 'assets/images/sentence/friend.gif',
            prefixText: 'She is my best',
            missingWord: 'friend',
            suffixText: 'at school.',
            choices: ['cat', 'friend', 'teacher'],
            thaiTranslation: 'เธอเป็นเพื่อนสนิทของฉันที่โรงเรียน',
          ),
          AudioFillLessonItem(
            title: 'บุคคล 6',
            placeholderImage: 'assets/images/sentence/fatherdrives.gif',
            prefixText: 'My father drives a',
            missingWord: 'car',
            suffixText: 'to work.',
            choices: ['car', 'boat', 'plane'],
            thaiTranslation: 'คุณพ่อขับรถยนต์ไปทำงาน',
          ),
          AudioFillLessonItem(
            title: 'บุคคล 7',
            placeholderImage: 'assets/images/sentence/littlebaby.gif',
            prefixText: 'The little baby is',
            missingWord: 'happy',
            suffixText: 'today.',
            choices: ['happy', 'angry', 'sad'],
            thaiTranslation: 'เด็กทารกมีความสุขในวันนี้',
          ),
          AudioFillLessonItem(
            title: 'บุคคล 8',
            placeholderImage: 'assets/images/sentence/Englishteacher.gif',
            prefixText: 'Our teacher teaches',
            missingWord: 'English',
            suffixText: 'in class.',
            choices: ['English', 'Thai', 'Music'],
            thaiTranslation: 'คุณครูสอนภาษาอังกฤษในห้องเรียน',
          ),
        ],
      ),

      // 5. หมวดสีชมพู: สถานที่และธรรมชาติ (รูป places.png)
      FillBlankTopic(
        id: 'places',
        titleTh: 'สถานที่และธรรมชาติ',
        titleEn: 'PLACES',
        imageAsset: 'assets/images/sentence/places.png',
        gradientColors: [Color(0xFFFF5E8B), Color(0xFFF43F5E)],
        shadowColor: Color(0xFFBE123C),
        lessons: [
          AudioFillLessonItem(
            title: 'สถานที่ 1',
            placeholderImage: 'assets/images/sentence/Truck.gif',
            prefixText: 'The big truck is',
            missingWord: 'red',
            suffixText: '.',
            choices: ['blue', 'red', 'yellow'],
            thaiTranslation: 'รถบรรทุกคันใหญ่มีสีแดง',
          ),
          AudioFillLessonItem(
            title: 'สถานที่ 2',
            placeholderImage: 'assets/images/sentence/sunshines.gif',
            prefixText: 'The sun shines in the',
            missingWord: 'sky',
            suffixText: '.',
            choices: ['sea', 'sky', 'ground'],
            thaiTranslation: 'พระอาทิตย์ส่องแสงบนท้องฟ้า',
          ),
          AudioFillLessonItem(
            title: 'สถานที่ 3',
            placeholderImage: 'assets/images/sentence/park.gif',
            prefixText: 'We go to the green',
            missingWord: 'park',
            suffixText: 'on Sunday.',
            choices: ['park', 'store', 'room'],
            thaiTranslation: 'พวกเราไปสวนสาธารณะในวันอาทิตย์',
          ),
          AudioFillLessonItem(
            title: 'สถานที่ 4',
            placeholderImage: 'assets/images/sentence/trees.gif',
            prefixText: 'There are many trees in the',
            missingWord: 'forest',
            suffixText: '.',
            choices: ['house', 'forest', 'car'],
            thaiTranslation: 'มีต้นไม้มากมายอยู่ในป่า',
          ),
          AudioFillLessonItem(
            title: 'สถานที่ 5',
            placeholderImage: 'assets/images/sentence/lake.gif',
            prefixText: 'The water in the lake is very',
            missingWord: 'clean',
            suffixText: '.',
            choices: ['hot', 'clean', 'dry'],
            thaiTranslation: 'น้ำในทะเลสาบใสสะอาดมาก',
          ),
          AudioFillLessonItem(
            title: 'สถานที่ 6',
            placeholderImage: 'assets/images/sentence/school.gif',
            prefixText: 'We learn lessons at the',
            missingWord: 'school',
            suffixText: '.',
            choices: ['park', 'school', 'zoo'],
            thaiTranslation: 'พวกเราเรียนหนังสือที่โรงเรียน',
          ),
          AudioFillLessonItem(
            title: 'สถานที่ 7',
            placeholderImage: 'assets/images/sentence/home.gif',
            prefixText: 'Our sweet home has a nice',
            missingWord: 'garden',
            suffixText: '.',
            choices: ['garden', 'lake', 'sea'],
            thaiTranslation: 'บ้านของเรามีสวนที่สวยงาม',
          ),
          AudioFillLessonItem(
            title: 'สถานที่ 8',
            placeholderImage: 'assets/images/sentence/clouds.gif',
            prefixText: 'White clouds float in the',
            missingWord: 'sky',
            suffixText: '.',
            choices: ['sky', 'water', 'forest'],
            thaiTranslation: 'เมฆสีขาวลอยอยู่บนท้องฟ้า',
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.topicLessons != null) {
      return VideoFillBlankExerciseScreen(
        lessons: widget.topicLessons!,
        topicTitle: widget.topicTitle ?? 'ฟังเสียงเติมคำ',
      );
    }

    final topics = _get5Topics();
    const headerColor = Color(0xFFC2185B);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: Column(
        children: [
          // 1. Header สีเบอร์รี่
          Container(
            color: headerColor,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'ฟังเสียงเติมคำ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // 2. ส่วนหัวคำอธิบาย
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'พร้อมฝึกฟังกันหรือยัง ?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF33091B),
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'แตะบทเรียนที่ต้องการเรียนรู้ได้เลย',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7E7278),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. รายการการ์ด 5 หมวดหมู่
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: topics.length,
              separatorBuilder: (_, __) => const SizedBox(height: 15),
              itemBuilder: (context, index) {
                final topic = topics[index];
                return _buildSampleStyleCard(context, topic);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleStyleCard(BuildContext context, FillBlankTopic topic) {
    return GestureDetector(
      onTap: () => _openTopic(topic),
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          color: topic.shadowColor,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: topic.shadowColor.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: topic.gradientColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 22,
                top: 0,
                bottom: 0,
                right: 125,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.titleTh,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${topic.titleEn} • ${topic.lessons.length} ประโยค',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.92),
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (_progress[topic.id] != null) ...[
                      const SizedBox(height: 6),
                      // "Continue" badge in the card's own colour
                      Container(
                        padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: topic.shadowColor.withValues(alpha: 0.6),
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_fill_rounded,
                              size: 16,
                              color: topic.shadowColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'เล่นต่อ ข้อ ${_progress[topic.id]!.index + 1} / ${topic.lessons.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: topic.shadowColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 14,
                top: 10,
                bottom: 10,
                child: SizedBox(
                  width: 95,
                  child: Image.asset(
                    topic.imageAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 58,
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
}

// -------------------------------------------------------------
// 3. หน้าจอทำแบบฝึกหัดฟังเสียงเติมคำ
// -------------------------------------------------------------
class VideoFillBlankExerciseScreen extends StatefulWidget {
  final List<AudioFillLessonItem> lessons;
  final String topicTitle;

  /// When set, progress is saved so the child can continue later.
  final String? topicId;
  final int startIndex;
  final int startCorrect;

  const VideoFillBlankExerciseScreen({
    super.key,
    required this.lessons,
    required this.topicTitle,
    this.topicId,
    this.startIndex = 0,
    this.startCorrect = 0,
  });

  @override
  State<VideoFillBlankExerciseScreen> createState() => _VideoFillBlankExerciseScreenState();
}

class _VideoFillBlankExerciseScreenState extends State<VideoFillBlankExerciseScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  int currentIndex = 0;
  String? selectedWord;
  bool isChecked = false;
  bool isCorrect = false;
  bool isPlayingAudio = false;
  int correctAnswersCount = 0;

  /// The result of this round was already sent (send it once only).
  bool _resultSent = false;

  static const Color primaryBerry = Color(0xFFC2185B);
  static const Color darkBerryShadow = Color(0xFF880E4F);

  @override
  void initState() {
    super.initState();
    if (widget.startIndex > 0 && widget.startIndex < widget.lessons.length) {
      currentIndex = widget.startIndex;
      correctAnswersCount = widget.startCorrect;
    }
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.36);
    await _flutterTts.setPitch(1.20);
  }

  Future<void> _speakFullSentence() async {
    if (isPlayingAudio) return;
    setState(() => isPlayingAudio = true);

    final item = widget.lessons[currentIndex];
    await _flutterTts.stop();
    await _flutterTts.speak(item.fullSentence);

    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      setState(() => isPlayingAudio = false);
    }
  }

  void _onSelectChoice(String word) {
    if (isChecked) return;
    setState(() {
      selectedWord = word;
    });
  }

  void _checkAnswer() {
    if (selectedWord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('แตะเลือกคำตอบก่อนนะจ๊ะ !'),
          backgroundColor: primaryBerry,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    final item = widget.lessons[currentIndex];
    final correct = (selectedWord!.trim().toLowerCase() == item.missingWord.trim().toLowerCase());

    setState(() {
      isChecked = true;
      isCorrect = correct;
      if (correct) {
        correctAnswersCount++;
      }
    });

    correct ? Sfx.correct() : Sfx.wrong();
    _showFeedbackSheet(correct);
  }

  void _showFeedbackSheet(bool correct) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final Color sheetBg = correct ? const Color(0xFF10B981) : const Color(0xFFEF4444);
        final Color sheetBorder = correct ? const Color(0xFF059669) : const Color(0xFFDC2626);

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: sheetBorder, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 10),
              Text(
                correct ? 'ถูกต้อง เก่งมาก !' : 'ยังไม่ถูกต้อง ลองอีกครั้งนะ !',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ประโยคที่ถูกต้อง คือ ${widget.lessons[currentIndex].fullSentence}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _nextLesson();
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, offset: Offset(0, 3), blurRadius: 4),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    currentIndex < widget.lessons.length - 1 ? 'ข้อต่อไป' : 'ดูสรุปผลการเรียน',
                    style: TextStyle(
                      color: sheetBorder,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _nextLesson() {
    if (currentIndex < widget.lessons.length - 1) {
      setState(() {
        currentIndex++;
        selectedWord = null;
        isChecked = false;
        isCorrect = false;
        isPlayingAudio = false;
      });
      // Remember where we are, so leaving now continues from this question.
      final topicId = widget.topicId;
      if (topicId != null) {
        LessonProgress.save(topicId, currentIndex, correctAnswersCount);
      }
    } else {
      // Finished: next time the topic starts from question 1.
      final topicId = widget.topicId;
      if (topicId != null) LessonProgress.clear(topicId);
      // Send the score for the parent report (no coins).
      if (!_resultSent) {
        _resultSent = true;
        ListeningResults.submit(
        game: 'fill_blank',
        topic: topicId ?? 'custom',
        score: correctAnswersCount,
        total: widget.lessons.length,
      );
      }
      _showCompletionDialog();
    }
  }

  // -------------------------------------------------------------
  // หน้าจอแสดงผลสรุปเมื่อทำครบ (ธีมชมพูหวานสดใส 3D)
  // -------------------------------------------------------------
  void _showCompletionDialog() {
    Sfx.complete();
    final int accuracyPercent = ((correctAnswersCount / widget.lessons.length) * 100).round();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) {
        // The phone's back button must not close it: that left the game on
        // the last question, and finishing again sent the result twice.
        return PopScope(
          canPop: false,
          child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFF6584), // ชมพูสดใสสว่างด้านบน
                  Color(0xFFE91E63), // ชมพูเบอร์รี่สดตรงกลาง
                  Color(0xFFAD1457), // บานเย็นเข้มอบอุ่นด้านล่าง
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                ..._buildConfettiBackground(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 10),

                        // 1. มาสคอตตัวการ์ตูนถือหนังสือ + รัศมีวงกลมสีขาวโปร่งแสง[cite: 1]
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.20),
                              ),
                            ),
                            SizedBox(
                              height: 190,
                              child: Image.asset(
                                'assets/images/character/yep.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.celebration_rounded,
                                  size: 130,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // 2. ดาว 3 ดวงสีทอง 3D[cite: 1]
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStar(size: 46, angle: -0.15),
                            const SizedBox(width: 8),
                            _buildStar(size: 64, angle: 0.0),
                            const SizedBox(width: 8),
                            _buildStar(size: 46, angle: 0.15),
                          ],
                        ),

                        // 3. หัวข้อ & ป้ายข้อความบอกหมวด[cite: 1]
                        Column(
                          children: [
                            const Text(
                              'เก่งมาก ยอดเยี่ยม',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 31,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF6A0D37),
                                    offset: Offset(0, 3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  width: 1.6,
                                ),
                              ),
                              child: Text(
                                'เรียนจบหมวด ${widget.topicTitle} แล้ว !',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // 4. การ์ดแสดงความแม่นยำ (โทนชมพูเข้ม 3D เข้าธีม)[cite: 1]
                        Container(
                          width: 205,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC2185B),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF880E4F).withValues(alpha: 0.65),
                                offset: const Offset(0, 6),
                                blurRadius: 0,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.40),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF10B981),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$accuracyPercent%',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'ความแม่นยำ',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 5. ปุ่ม "เล่นอีกครั้ง" และ "กลับสู่หน้าหัวข้อ" (โทนชมพู 3D)[cite: 1]
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  currentIndex = 0;
                                  selectedWord = null;
                                  isChecked = false;
                                  isCorrect = false;
                                  correctAnswersCount = 0;
                                  _resultSent = false;
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF880E4F),
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.only(bottom: 4.5),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color(0xFFF8BBD0),
                                      width: 1.8,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.replay_rounded, color: Color(0xFFC2185B), size: 23),
                                      SizedBox(width: 8),
                                      Text(
                                        'เล่นอีกครั้ง',
                                        style: TextStyle(
                                          color: Color(0xFFC2185B),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context); // ปิด Dialog[cite: 1]
                                Navigator.pop(context); // กลับสู่หน้าเลือกหัวข้อ[cite: 1]
                              },
                              child: Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF880E4F),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF80AB), Color(0xFFFF4081)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      width: 1.8,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.home_rounded, color: Colors.white, size: 25),
                                      SizedBox(width: 8),
                                      Text(
                                        'กลับสู่หน้าหัวข้อ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                          shadows: [
                                            Shadow(
                                              color: Color(0xFF880E4F),
                                              offset: Offset(0, 1.5),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
      },
    );
  }

  Widget _buildStar({required double size, required double angle}) {
    return Transform.rotate(
      angle: angle,
      child: Icon(
        Icons.star_rounded,
        size: size,
        color: const Color(0xFFFFD54F),
        shadows: const [
          Shadow(
            color: Color(0xFFC2185B),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildConfettiBackground() {
    final List<Map<String, dynamic>> confettis = [
      {'top': 60.0, 'left': 30.0, 'color': Colors.yellowAccent, 'w': 10.0, 'h': 6.0, 'angle': 0.4},
      {'top': 90.0, 'right': 40.0, 'color': Colors.white, 'w': 12.0, 'h': 7.0, 'angle': -0.3},
      {'top': 140.0, 'left': 60.0, 'color': Colors.pinkAccent, 'w': 14.0, 'h': 6.0, 'angle': 0.8},
      {'top': 180.0, 'right': 70.0, 'color': Colors.cyanAccent, 'w': 8.0, 'h': 8.0, 'angle': 0.2},
      {'top': 280.0, 'left': 25.0, 'color': Colors.amberAccent, 'w': 12.0, 'h': 6.0, 'angle': -0.5},
      {'top': 320.0, 'right': 30.0, 'color': Colors.white, 'w': 10.0, 'h': 10.0, 'angle': 0.6},
      {'top': 420.0, 'left': 40.0, 'color': Colors.yellow, 'w': 14.0, 'h': 7.0, 'angle': -0.2},
      {'top': 460.0, 'right': 45.0, 'color': Colors.purpleAccent, 'w': 9.0, 'h': 9.0, 'angle': 0.7},
    ];

    return confettis.map((c) {
      return Positioned(
        top: c['top'] as double?,
        left: c['left'] as double?,
        right: c['right'] as double?,
        child: Transform.rotate(
          angle: c['angle'] as double,
          child: Container(
            width: c['w'] as double,
            height: c['h'] as double,
            decoration: BoxDecoration(
              color: c['color'] as Color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.lessons[currentIndex];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF0F5),
              Color(0xFFFFF6F8),
              Color(0xFFFDE8EF),
            ],
          ),
        ),
        child: Column(
          children: [
            // 1. Header สีเบอร์รี่เดิม เปลี่ยนเฉพาะชื่อตามหมวด[cite: 10]
            Container(
              color: primaryBerry,
              width: double.infinity,
              child: SafeArea(
                bottom: false,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.topicTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),

            // 2. พื้นที่เนื้อหาแบบฝึกหัด
            Expanded(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildProgressCapsule(),
                      _buildMediaCard(item),
                      _buildQuestionCard(item),
                      _buildChoiceRow(item),
                      _buildCheckAnswerButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCapsule() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF48FB1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ข้อที่ ${currentIndex + 1} จาก ${widget.lessons.length}',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: darkBerryShadow,
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: List.generate(widget.lessons.length, (index) {
              final isCurrent = index == currentIndex;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                width: isCurrent ? 14 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isCurrent ? primaryBerry : const Color(0xFFF8BBD0),
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(AudioFillLessonItem item) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: double.infinity,
          height: 195,
          decoration: BoxDecoration(
            color: const Color(0xFFBAE6FD),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: primaryBerry.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              item.placeholderImage,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.music_note_rounded,
                  size: 80,
                  color: primaryBerry,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -28,
          child: GestureDetector(
            onTap: _speakFullSentence,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: darkBerryShadow,
                ),
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFE91E63), primaryBerry],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 36,
                    shadows: [
                      Shadow(color: Colors.black26, offset: Offset(0, 1.5), blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(AudioFillLessonItem item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF8BBD0), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: primaryBerry.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'ฟังแล้วเติมคำที่หายไป',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B4828),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (item.prefixText.isNotEmpty)
                Text(
                  '${item.prefixText} ',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF26190E),
                    letterSpacing: 0.2,
                  ),
                ),
              CustomPaint(
                painter: _DottedBorderPainter(color: primaryBerry),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 54, minHeight: 38),
                  alignment: Alignment.center,
                  child: Text(
                    selectedWord ?? '?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: selectedWord != null
                          ? const Color(0xFF1E293B)
                          : primaryBerry,
                    ),
                  ),
                ),
              ),
              if (item.suffixText.isNotEmpty)
                Text(
                  // No space before "." ("I like swimming.")
                  item.suffixPunctuation.isNotEmpty
                      ? item.suffixText.trimLeft()
                      : ' ${item.suffixText}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF26190E),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.thaiTranslation,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceRow(AudioFillLessonItem item) {
    final List<Map<String, Color>> colors = [
      {
        'bg': const Color(0xFFEDE9FE),
        'border': const Color(0xFF8B5CF6),
        'shadow': const Color(0xFF6D28D9),
        'selectedBg': const Color(0xFF7C3AED),
      },
      {
        'bg': const Color(0xFFE0F2FE),
        'border': const Color(0xFF0EA5E9),
        'shadow': const Color(0xFF0369A1),
        'selectedBg': const Color(0xFF0284C7),
      },
      {
        'bg': const Color(0xFFFEF3C7),
        'border': const Color(0xFFF59E0B),
        'shadow': const Color(0xFFB45309),
        'selectedBg': const Color(0xFFD97706),
      },
    ];

    final bool hasSelected = selectedWord != null;

    return Row(
      children: List.generate(item.choices.length, (index) {
        final choice = item.choices[index];
        final isSelected = selectedWord == choice;
        final colorSet = colors[index % colors.length];

        final double opacity = (!isSelected && hasSelected) ? 0.55 : 1.0;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 5,
              right: index == item.choices.length - 1 ? 0 : 5,
            ),
            child: GestureDetector(
              onTap: isChecked ? null : () => _onSelectChoice(choice),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: opacity,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 66,
                  decoration: BoxDecoration(
                    color: colorSet['shadow'],
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? colorSet['shadow']!.withValues(alpha: 0.6)
                            : colorSet['shadow']!.withValues(alpha: 0.2),
                        blurRadius: isSelected ? 10 : 4,
                        offset: Offset(0, isSelected ? 5 : 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.only(bottom: isSelected ? 6.5 : 5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? colorSet['selectedBg'] : colorSet['bg'],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.white : colorSet['border']!,
                        width: isSelected ? 2.5 : 2.0,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: colorSet['selectedBg'],
                                size: 13,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            choice,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isSelected ? 17.5 : 16.5,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? Colors.white : const Color(0xFF26190E),
                              letterSpacing: 0.2,
                              shadows: isSelected
                                  ? const [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(0, 1.2),
                                        blurRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCheckAnswerButton() {
    final bool isReady = selectedWord != null;

    final Color buttonShadow = isReady ? darkBerryShadow : const Color(0xFFCBD5E1);
    final List<Color> buttonGradient = isReady
        ? const [Color(0xFFE91E63), primaryBerry]
        : const [Color(0xFFF1F5F9), Color(0xFFE2E8F0)];
    final Color textColor = isReady ? Colors.white : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: isChecked ? null : _checkAnswer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: buttonShadow,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: buttonShadow.withValues(alpha: isReady ? 0.4 : 0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.only(bottom: 5),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: buttonGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: isReady ? 0.7 : 0.6),
              width: 1.6,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'ตรวจคำตอบ',
            style: TextStyle(
              color: textColor,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              shadows: isReady
                  ? const [
                      Shadow(
                        color: Color(0xFF560027),
                        offset: Offset(0, 1.5),
                        blurRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;

  _DottedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );

    final path = Path()..addRRect(rrect);
    final dashPath = Path();

    double distance = 0.0;
    const double dashWidth = 5.0;
    const double dashSpace = 3.5;

    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}