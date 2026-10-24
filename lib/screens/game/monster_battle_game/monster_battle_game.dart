import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../services/coin_balance.dart';
import '../../../services/monster_battle_service.dart';
import '../../../services/guess_progress_service.dart' show GuessCoinResult;
import '../../../widgets/parent_pin_prompt.dart';
import 'package:threeduo_learning/screens/profile_screen.dart'
    show AvatarProfile, AvatarPainter, OutfitItem, kSkinTones, kHairColors, kMaleOutfits, kFemaleOutfits;

void main() {
  runApp(const MonsterBattleApp());
}

// ==========================================
// เอฟเฟกต์เสริมความสนุก: ตัวเลขดาเมจลอย + คอนเฟตติ์ฉลองชัยชนะ
// ==========================================
class _FloatingText {
  final int id;
  final String text;
  final Color color;
  final bool onRight; // true = แสดงฝั่งมอนสเตอร์, false = แสดงฝั่งฮีโร่
  final bool center; // true = แสดงกลางจอ (คำชม)
  final double size;

  _FloatingText({
    required this.id,
    required this.text,
    required this.color,
    required this.onRight,
    this.center = false,
    this.size = 22,
  });
}

class FloatingDamageText extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onDone;
  final double fontSize;

  const FloatingDamageText({
    super.key,
    required this.text,
    required this.color,
    required this.onDone,
    this.fontSize = 22,
  });

  @override
  State<FloatingDamageText> createState() => _FloatingDamageTextState();
}

class _FloatingDamageTextState extends State<FloatingDamageText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rise;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _rise = Tween<double>(begin: 0, end: -55)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.45, 1.0)),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _rise.value),
        child: Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _scale.value,
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w900,
                color: widget.color,
                shadows: const [
                  Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MonsterBattleApp extends StatelessWidget {
  const MonsterBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'สร้างมอนสเตอร์',
      theme: ThemeData(
        fontFamily: 'Mitr',
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFEFF6FF),
      ),
      home: const DifficultySelectionScreen(),
    );
  }
}

enum DifficultyLevel { easy, medium, hard }

class DifficultyConfig {
  final String title;
  final String description;
  final int timeLimit;
  final double monsterAtkMultiplier;
  final double rewardMultiplier;
  final Color color;
  final IconData icon;

  DifficultyConfig({
    required this.title,
    required this.description,
    required this.timeLimit,
    required this.monsterAtkMultiplier,
    required this.rewardMultiplier,
    required this.color,
    required this.icon,
  });
}

class VocabQuestion {
  final String word;
  final String correctMeaning;
  final List<String> choices;
  final String category;

  VocabQuestion({
    required this.word,
    required this.correctMeaning,
    required this.choices,
    required this.category,
  });
}

// ==========================================
// บุคลิก AI ของมอนสเตอร์ (ใช้ในการดวลความเร็ว)
// ==========================================
enum MonsterAI { speedy, smart, trickster, berserker }

class MonsterAIProfile {
  final String label;
  final String tip; // คำแนะนำกลยุทธ์สำหรับเด็ก
  final double minSec; // เวลาคิดพื้นฐาน (ระดับ Hard) – ระดับง่ายจะคูณให้ช้าลง
  final double maxSec;
  final double wrongChance;
  const MonsterAIProfile(this.label, this.tip, this.minSec, this.maxSec, this.wrongChance);
}

const Map<MonsterAI, MonsterAIProfile> kMonsterAI = {
  MonsterAI.speedy: MonsterAIProfile('สายสปีด', 'ตัวนี้ไวแต่พลาดบ่อย ใจเย็น ๆ ไม่ต้องกดมั่ว', 1.0, 2.0, 0.30),
  MonsterAI.smart: MonsterAIProfile('สายแม่นยำ', 'ตัวนี้ตอบถูกเกือบทุกข้อ ต้องอ่านให้ไวกว่าเลย', 4.0, 5.0, 0.03),
  MonsterAI.trickster: MonsterAIProfile('สายก่อกวน', 'ระวังโดนบังปุ่ม ตั้งสติอ่านให้ดีก่อนกด', 3.0, 4.5, 0.15),
  MonsterAI.berserker: MonsterAIProfile('สายคลั่ง', 'ยิ่งเลือดน้อยยิ่งไว รีบจบให้ไวก่อนมันเร่งสปีด', 3.5, 4.5, 0.12),
};

enum _Phase { ready, racing, grace, clash, resolved }

class Monster {
  final String name;
  final MonsterLook look;
  final MonsterAI ai;
  int maxHp;
  int currentHp;
  int atk;

  Monster({
    required this.name,
    required this.look,
    required this.ai,
    required this.maxHp,
    required this.currentHp,
    required this.atk,
  });
}

// ==========================================
// คลังคำศัพท์แบ่งตามหมวดหมู่และความยาก
// ==========================================
final Map<DifficultyLevel, List<Map<String, dynamic>>> categoryVocabBank = {
  DifficultyLevel.easy: [
    {'word': 'Apple', 'correct': 'แอปเปิ้ล', 'wrongs': ['กล้วย', 'ส้ม', 'มะม่วง'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Banana', 'correct': 'กล้วย', 'wrongs': ['มะพร้าว', 'ส้ม', 'องุ่น'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Orange', 'correct': 'ส้ม', 'wrongs': ['มะนาว', 'แอปเปิ้ล', 'กีวี'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Running', 'correct': 'การวิ่ง', 'wrongs': ['การว่ายน้ำ', 'การเดิน', 'การกระโดด'], 'cat': 'กีฬา ⚽'},
    {'word': 'Golf', 'correct': 'กอล์ฟ', 'wrongs': ['ฟุตบอล', 'เทนนิส', 'บาสเกตบอล'], 'cat': 'กีฬา ⚽'},
    {'word': 'Cat', 'correct': 'แมว', 'wrongs': ['สุนัข', 'หนู', 'กระต่าย'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Dog', 'correct': 'สุนัข', 'wrongs': ['แมว', 'เสือ', 'หมี'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Fish', 'correct': 'ปลา', 'wrongs': ['กุ้ง', 'ปู', 'หอย'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Cook', 'correct': 'พ่อครัว', 'wrongs': ['ครู', 'หมอ', 'ตำรวจ'], 'cat': 'อาชีพ 💼'},
    {'word': 'Doctor', 'correct': 'หมอ', 'wrongs': ['พยาบาล', 'ทหาร', 'วิศวกร'], 'cat': 'อาชีพ 💼'},
    {'word': 'Car', 'correct': 'รถยนต์', 'wrongs': ['รถจักรยาน', 'เรือ', 'เครื่องบิน'], 'cat': 'ยานพาหนะ 🚗'},
    {'word': 'Bus', 'correct': 'รถเมล์', 'wrongs': ['รถไฟ', 'รถตู้', 'รถแท็กซี่'], 'cat': 'ยานพาหนะ 🚗'},
    {'word': 'Park', 'correct': 'สวนสาธารณะ', 'wrongs': ['โรงเรียน', 'บ้าน', 'วัด'], 'cat': 'สถานที่ 📍'},
    {'word': 'Home', 'correct': 'บ้าน', 'wrongs': ['ร้านค้า', 'โรงแรม', 'ตลาด'], 'cat': 'สถานที่ 📍'},
    {'word': 'Mango', 'correct': 'มะม่วง', 'wrongs': ['ทุเรียน', 'มะละกอ', 'ลำไย'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Jumping', 'correct': 'การกระโดด', 'wrongs': ['การวิ่ง', 'การนั่ง', 'การนอน'], 'cat': 'กีฬา ⚽'},
    {'word': 'Bird', 'correct': 'นก', 'wrongs': ['ปลา', 'ผีเสื้อ', 'กบ'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Cow', 'correct': 'วัว', 'wrongs': ['ม้า', 'แพะ', 'หมู'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Police', 'correct': 'ตำรวจ', 'wrongs': ['ทหาร', 'ครู', 'ชาวนา'], 'cat': 'อาชีพ 💼'},
    {'word': 'Boat', 'correct': 'เรือ', 'wrongs': ['รถไฟ', 'รถบรรทุก', 'เครื่องบิน'], 'cat': 'ยานพาหนะ 🚗'},
    {'word': 'Train', 'correct': 'รถไฟ', 'wrongs': ['รถเมล์', 'เรือ', 'จักรยาน'], 'cat': 'ยานพาหนะ 🚗'},
    {'word': 'School', 'correct': 'โรงเรียน', 'wrongs': ['โรงพยาบาล', 'ตลาด', 'สนามบิน'], 'cat': 'สถานที่ 📍'},
    {'word': 'Red', 'correct': 'สีแดง', 'wrongs': ['สีเขียว', 'สีเหลือง', 'สีดำ'], 'cat': 'สี 🎨'},
    {'word': 'Green', 'correct': 'สีเขียว', 'wrongs': ['สีแดง', 'สีดำ', 'สีขาว'], 'cat': 'สี 🎨'},
    {'word': 'Yellow', 'correct': 'สีเหลือง', 'wrongs': ['สีส้ม', 'สีม่วง', 'สีชมพู'], 'cat': 'สี 🎨'},
    {'word': 'Mother', 'correct': 'แม่', 'wrongs': ['พ่อ', 'ป้า', 'ยาย'], 'cat': 'ครอบครัว 👨‍👩‍👧'},
    {'word': 'Father', 'correct': 'พ่อ', 'wrongs': ['แม่', 'ลุง', 'ตา'], 'cat': 'ครอบครัว 👨‍👩‍👧'},
  ],
  DifficultyLevel.medium: [
    {'word': 'Pineapple', 'correct': 'สับปะรด', 'wrongs': ['แตงโม', 'มะละกอ', 'ขนุน'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Strawberry', 'correct': 'สตรอว์เบอร์รี', 'wrongs': ['เชอร์รี่', 'บลูเบอร์รี่', 'องุ่น'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Football', 'correct': 'ฟุตบอล', 'wrongs': ['วอลเลย์บอล', 'แฮนด์บอล', 'เบสบอล'], 'cat': 'กีฬา ⚽'},
    {'word': 'Swimming', 'correct': 'การว่ายน้ำ', 'wrongs': ['การดำน้ำ', 'การโต้คลื่น', 'การพายเรือ'], 'cat': 'กีฬา ⚽'},
    {'word': 'Elephant', 'correct': 'ช้าง', 'wrongs': ['ยีราฟ', 'แรด', 'ฮิปโป'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Dolphin', 'correct': 'โลมา', 'wrongs': ['ฉลาม', 'วาฬ', 'แมวน้ำ'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Teacher', 'correct': 'ครู', 'wrongs': ['นักเรียน', 'ศาสตราจารย์', 'บรรณารักษ์'], 'cat': 'อาชีพ 💼'},
    {'word': 'Engineer', 'correct': 'วิศวกร', 'wrongs': ['สถาปนิก', 'ช่างไฟ', 'ช่างยนต์'], 'cat': 'อาชีพ 💼'},
    {'word': 'Bicycle', 'correct': 'รถจักรยาน', 'wrongs': ['จักรยานยนต์', 'รถสามล้อ', 'รถสกู๊ตเตอร์'], 'cat': 'ยานพาหนะ 🚗'},
    {'word': 'Airplane', 'correct': 'เครื่องบิน', 'wrongs': ['เฮลิคอปเตอร์', 'บอลลูน', 'จรวด'], 'cat': 'ยานพาหนะ 🚗'},
    {'word': 'Hospital', 'correct': 'โรงพยาบาล', 'wrongs': ['คลินิก', 'ร้านขายยา', 'สถานีตำรวจ'], 'cat': 'สถานที่ 📍'},
    {'word': 'Library', 'correct': 'ห้องสมุด', 'wrongs': ['ร้านหนังสือ', 'โรงเรียน', 'พิพิธภัณฑ์'], 'cat': 'สถานที่ 📍'},
    {'word': 'Watermelon', 'correct': 'แตงโม', 'wrongs': ['เมลอน', 'ฟักทอง', 'แคนตาลูป'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Grapes', 'correct': 'องุ่น', 'wrongs': ['เชอร์รี่', 'พลัม', 'ลูกพีช'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Basketball', 'correct': 'บาสเกตบอล', 'wrongs': ['วอลเลย์บอล', 'เทนนิส', 'แบดมินตัน'], 'cat': 'กีฬา ⚽'},
    {'word': 'Badminton', 'correct': 'แบดมินตัน', 'wrongs': ['เทนนิส', 'ปิงปอง', 'สควอช'], 'cat': 'กีฬา ⚽'},
    {'word': 'Giraffe', 'correct': 'ยีราฟ', 'wrongs': ['ม้าลาย', 'อูฐ', 'กวาง'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Penguin', 'correct': 'เพนกวิน', 'wrongs': ['นกกระทุง', 'นกฮูก', 'นกอินทรี'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Firefighter', 'correct': 'นักดับเพลิง', 'wrongs': ['ตำรวจ', 'ทหาร', 'พยาบาล'], 'cat': 'อาชีพ 💼'},
    {'word': 'Pilot', 'correct': 'นักบิน', 'wrongs': ['กัปตันเรือ', 'วิศวกร', 'พ่อครัว'], 'cat': 'อาชีพ 💼'},
    {'word': 'Motorcycle', 'correct': 'จักรยานยนต์', 'wrongs': ['รถจักรยาน', 'รถบรรทุก', 'รถแทรกเตอร์'], 'cat': 'ยานพาหนะ 🚗'},
    {'word': 'Airport', 'correct': 'สนามบิน', 'wrongs': ['ท่าเรือ', 'สถานีรถไฟ', 'ท่ารถ'], 'cat': 'สถานที่ 📍'},
    {'word': 'Museum', 'correct': 'พิพิธภัณฑ์', 'wrongs': ['ห้องสมุด', 'โรงละคร', 'หอศิลป์'], 'cat': 'สถานที่ 📍'},
    {'word': 'Bakery', 'correct': 'ร้านเบเกอรี่', 'wrongs': ['ร้านขายผัก', 'ร้านตัดผม', 'ร้านขายยา'], 'cat': 'สถานที่ 📍'},
  ],
  DifficultyLevel.hard: [
    {'word': 'Pomegranate', 'correct': 'ทับทิม', 'wrongs': ['มังคุด', 'ลองกอง', 'ส้มโอ'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Dragon Fruit', 'correct': 'แก้วมังกร', 'wrongs': ['เสาวรส', 'มะเฟือง', 'ลูกพลับ'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Taekwondo', 'correct': 'เทควันโด', 'wrongs': ['คาราเต้', 'ยูโด', 'มวยไทย'], 'cat': 'กีฬา ⚽'},
    {'word': 'Gymnastics', 'correct': 'ยิมนาสติก', 'wrongs': ['กรีฑา', 'เต้นรำ', 'บัลเลต์'], 'cat': 'กีฬา ⚽'},
    {'word': 'Chameleon', 'correct': 'กิ้งก่าเปลี่ยนสี', 'wrongs': ['อีกัวน่า', 'จิ้งจก', 'ตุ๊กแก'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Rhinoceros', 'correct': 'แรด', 'wrongs': ['ฮิปโปโปเตมัส', 'ช้างเผือก', 'ควายป่า'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Archaeologist', 'correct': 'นักโบราณคดี', 'wrongs': ['นักวิทยาศาสตร์', 'นักธรณีวิทยา', 'นักดาราศาสตร์'], 'cat': 'อาชีพ 💼'},
    {'word': 'Entrepreneur', 'correct': 'ผู้ประกอบการ', 'wrongs': ['นักลงทุน', 'ผู้จัดการ', 'พนักงานบัญชี'], 'cat': 'อาชีพ 💼'},
    {'word': 'Submarine', 'correct': 'เรือดำน้ำ', 'wrongs': ['เรือรบ', 'เรือบรรทุกสินค้า', 'เรือยอชต์'], 'cat': 'ยานพาหนะ 🚗'},
    {'word': 'Hovercraft', 'correct': 'เรือสะเทินน้ำสะเทินบก', 'wrongs': ['เจ็ทสกี', 'เรือหางยาว', 'เรือเร็ว'], 'cat': 'ยานพาหนะ 🚗'},
    {'word': 'Amphitheater', 'correct': 'อัฒจันทร์กลางแจ้ง', 'wrongs': ['โรงละคร', 'สนามกีฬา', 'หอประชุม'], 'cat': 'สถานที่ 📍'},
    {'word': 'Observatory', 'correct': 'หอดูดาว', 'wrongs': ['ท้องฟ้าจำลอง', 'หอคอย', 'สถานีอุตุนิยมวิทยา'], 'cat': 'สถานที่ 📍'},
    {'word': 'Persimmon', 'correct': 'ลูกพลับ', 'wrongs': ['ลูกท้อ', 'ลูกพรุน', 'ลูกแพร์'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Mangosteen', 'correct': 'มังคุด', 'wrongs': ['เงาะ', 'ลางสาด', 'ระกำ'], 'cat': 'ผลไม้ 🍎'},
    {'word': 'Fencing', 'correct': 'ฟันดาบ', 'wrongs': ['ยิงธนู', 'ยิงปืน', 'พายเรือ'], 'cat': 'กีฬา ⚽'},
    {'word': 'Archery', 'correct': 'ยิงธนู', 'wrongs': ['ฟันดาบ', 'ขว้างหอก', 'ยิงปืน'], 'cat': 'กีฬา ⚽'},
    {'word': 'Platypus', 'correct': 'ตุ่นปากเป็ด', 'wrongs': ['ตัวนิ่ม', 'เม่น', 'ตัวกินมด'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Flamingo', 'correct': 'นกฟลามิงโก', 'wrongs': ['นกกระเรียน', 'นกกระทุง', 'นกกระสา'], 'cat': 'สัตว์ 🐾'},
    {'word': 'Veterinarian', 'correct': 'สัตวแพทย์', 'wrongs': ['เภสัชกร', 'ทันตแพทย์', 'พยาบาล'], 'cat': 'อาชีพ 💼'},
    {'word': 'Architect', 'correct': 'สถาปนิก', 'wrongs': ['วิศวกร', 'มัณฑนากร', 'นักออกแบบกราฟิก'], 'cat': 'อาชีพ 💼'},
    {'word': 'Ambulance', 'correct': 'รถพยาบาล', 'wrongs': ['รถดับเพลิง', 'รถตำรวจ', 'รถขยะ'], 'cat': 'ยานพาหนะ 🚗'},
    {'word': 'Lighthouse', 'correct': 'ประภาคาร', 'wrongs': ['หอนาฬิกา', 'เจดีย์', 'หอคอย'], 'cat': 'สถานที่ 📍'},
    {'word': 'Skyscraper', 'correct': 'ตึกระฟ้า', 'wrongs': ['บังกะโล', 'โกดัง', 'กระท่อม'], 'cat': 'สถานที่ 📍'},
  ],
};

final Map<DifficultyLevel, DifficultyConfig> kDifficultyConfigs = {
  DifficultyLevel.easy: DifficultyConfig(
    title: 'ระดับง่าย',
    description: 'คำศัพท์พื้นฐาน / มีเวลา 15 วินาที / มอนสเตอร์โจมตีเบา',
    timeLimit: 15,
    monsterAtkMultiplier: 0.8,
    rewardMultiplier: 1.0,
    color: const Color(0xFF0284C7),
    icon: Icons.sentiment_satisfied_alt_rounded,
  ),
  DifficultyLevel.medium: DifficultyConfig(
    title: 'ระดับปานกลาง',
    description: 'คำศัพท์ทั่วไป / มีเวลา 10 วินาที / ความท้าทายปกติ',
    timeLimit: 10,
    monsterAtkMultiplier: 1.0,
    rewardMultiplier: 1.25,
    color: const Color(0xFF2563EB),
    icon: Icons.bolt_rounded,
  ),
  DifficultyLevel.hard: DifficultyConfig(
    title: 'ระดับยาก',
    description: 'คำศัพท์เฉพาะทาง / มีเวลา 6 วินาที / มอนสเตอร์โจมตีแรง',
    timeLimit: 6,
    monsterAtkMultiplier: 1.4,
    rewardMultiplier: 1.6,
    color: const Color(0xFF1D4ED8),
    icon: Icons.local_fire_department_rounded,
  ),
};


enum MonsterBody { round, egg, ghost, furry }

enum HornStyle { none, cone, curl, bull, ears, unicorn }

enum MouthStyle { grin, toothy, open, fangs, grumpy, smile }

enum MonsterMood { normal, hurt, angry, thinking, laugh, shocked }

class MonsterLook {
  final MonsterBody body;
  final Color main;
  final Color? belly;
  final Color? spots;
  final Color? hair;
  final Color? ears;
  final HornStyle horn;
  final Color hornA;
  final Color hornB;
  final int eyes; // 1 = ตาเดียว, 2 = สองตา, 3 = สามตา
  final bool stalks; // ตาอยู่บนก้าน
  final bool lidded; // หนังตาตก (ทำหน้าบึ้ง)
  final bool blush; // แก้มแดง
  final MouthStyle mouth;
  final Color pupil;
  final bool arms;

  const MonsterLook({
    required this.body,
    required this.main,
    this.belly,
    this.spots,
    this.hair,
    this.ears,
    this.horn = HornStyle.none,
    this.hornA = const Color(0xFFF59E0B),
    this.hornB = const Color(0xFFFDE68A),
    this.eyes = 2,
    this.stalks = false,
    this.lidded = false,
    this.blush = false,
    this.mouth = MouthStyle.grin,
    this.pupil = const Color(0xFF3B2A5A),
    this.arms = true,
  });
}

// ---------- ชุดมอนสเตอร์ (อ้างอิงจากรูปตัวอย่าง) ----------
// ผีเขียวหัวเราะ + เขาเกลียวส้ม
const MonsterLook kLookGreenBlob = MonsterLook(
  body: MonsterBody.ghost,
  main: Color(0xFF4E9A1E),
  horn: HornStyle.curl,
  hornA: Color(0xFFF08A3C),
  eyes: 2,
  mouth: MouthStyle.grin,
);

// ตัวเขียวน้ำทะเล เขาลายส้ม-เหลือง
const MonsterLook kLookTealBull = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFF2FA99A),
  belly: Color(0xFFF3D679),
  spots: Color(0xFFF3D679),
  horn: HornStyle.bull,
  hornA: Color(0xFFF59E0B),
  hornB: Color(0xFFFDE68A),
  eyes: 2,
  mouth: MouthStyle.grin,
);

// ขนฟูสีฟ้า ยิ้มกว้างฟันขาว
const MonsterLook kLookFuzzyBlue = MonsterLook(
  body: MonsterBody.furry,
  main: Color(0xFF6CC4F2),
  horn: HornStyle.curl,
  hornA: Color(0xFF4FA9E0),
  eyes: 2,
  mouth: MouthStyle.toothy,
  pupil: Color(0xFF2E7BC0),
);

// ขนฟูสีฟ้าอมม่วง (โลกปราสาท)
const MonsterLook kLookFuzzyCloud = MonsterLook(
  body: MonsterBody.furry,
  main: Color(0xFF9DB4FF),
  horn: HornStyle.curl,
  hornA: Color(0xFF7C8CF2),
  eyes: 2,
  mouth: MouthStyle.toothy,
  pupil: Color(0xFF4451B8),
);

// ผีม่วง 3 ตา เขี้ยวแหลม
const MonsterLook kLookPurpleFang = MonsterLook(
  body: MonsterBody.ghost,
  main: Color(0xFF6C52D9),
  horn: HornStyle.curl,
  hornA: Color(0xFF3C6FE0),
  eyes: 3,
  mouth: MouthStyle.fangs,
  pupil: Color(0xFF1B1030),
);

// ตาเดียวสีม่วง มียูนิคอร์นบนหัว
const MonsterLook kLookPurpleUnicorn = MonsterLook(
  body: MonsterBody.egg,
  main: Color(0xFF7A57C4),
  spots: Color(0xFF6244AD),
  horn: HornStyle.unicorn,
  hornA: Color(0xFFF0A44B),
  hornB: Color(0xFFFFE2A8),
  eyes: 1,
  mouth: MouthStyle.smile,
  pupil: Color(0xFF3B2A5A),
);

// สีฟ้า หูชมพูฟูฟ่อง
const MonsterLook kLookBlueEars = MonsterLook(
  body: MonsterBody.egg,
  main: Color(0xFF2FA5E0),
  belly: Color(0xFFF79AB6),
  ears: Color(0xFFF79AB6),
  eyes: 2,
  mouth: MouthStyle.grin,
);

// ส้มขี้บ่น ตาตก
const MonsterLook kLookOrangeGrumpy = MonsterLook(
  body: MonsterBody.ghost,
  main: Color(0xFFF7A030),
  horn: HornStyle.curl,
  hornA: Color(0xFF6BA82D),
  eyes: 2,
  lidded: true,
  mouth: MouthStyle.grumpy,
);

// แดง 3 ตาบนก้าน อ้าปากกว้าง
const MonsterLook kLookRedStalk = MonsterLook(
  body: MonsterBody.ghost,
  main: Color(0xFFC8352B),
  belly: Color(0xFFEFAF3A),
  eyes: 3,
  stalks: true,
  mouth: MouthStyle.open,
  arms: false,
);

// แดงหนามจี๊ด หูเหลือง 3 ตา
const MonsterLook kLookRedSpiky = MonsterLook(
  body: MonsterBody.furry,
  main: Color(0xFFE8574F),
  horn: HornStyle.ears,
  hornA: Color(0xFFF4C84A),
  hornB: Color(0xFFFDE68A),
  eyes: 3,
  mouth: MouthStyle.grin,
);

// ผีชมพู เขาเกลียวม่วงแดง
const MonsterLook kLookPinkGhost = MonsterLook(
  body: MonsterBody.ghost,
  main: Color(0xFFF26BA8),
  horn: HornStyle.curl,
  hornA: Color(0xFFA01D5E),
  eyes: 2,
  mouth: MouthStyle.grin,
  pupil: Color(0xFF3A8FE0),
);

// ส้มแก้มแดง เขาลายเขียว-ม่วง
const MonsterLook kLookOrangeBull = MonsterLook(
  body: MonsterBody.egg,
  main: Color(0xFFF2A233),
  horn: HornStyle.bull,
  hornA: Color(0xFF3C9E8F),
  hornB: Color(0xFF7A57C4),
  eyes: 2,
  blush: true,
  mouth: MouthStyle.smile,
);

const MonsterLook kLookBossTeal = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFF33C1C6),
  belly: Color(0xFFD6F27A),
  spots: Color(0xFF8E55C7),
  hair: Color(0xFF8E55C7),
  horn: HornStyle.cone,
  hornA: Color(0xFFC9C08A),
  hornB: Color(0xFFF1EBC4),
  eyes: 1,
  mouth: MouthStyle.grin,
  pupil: Color(0xFF7A3FC0),
);

const MonsterLook kLookBossPurple = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFF8E55C7),
  belly: Color(0xFFE9D5FF),
  spots: Color(0xFF33C1C6),
  hair: Color(0xFF33C1C6),
  horn: HornStyle.cone,
  hornA: Color(0xFFC9C08A),
  hornB: Color(0xFFF1EBC4),
  eyes: 1,
  mouth: MouthStyle.grin,
  pupil: Color(0xFF2A9DA2),
);

const MonsterLook kLookBossRed = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFFE5533D),
  belly: Color(0xFFFFD36B),
  spots: Color(0xFFB3261E),
  hair: Color(0xFF6B1D12),
  horn: HornStyle.cone,
  hornA: Color(0xFFFDE68A),
  hornB: Color(0xFFFFFFFF),
  eyes: 1,
  mouth: MouthStyle.fangs,
  pupil: Color(0xFF7F1D1D),
);

const MonsterLook kLookBossDark = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFF5B3FA8),
  belly: Color(0xFFC4B5FD),
  spots: Color(0xFF3B2A78),
  hair: Color(0xFF1E1B4B),
  horn: HornStyle.cone,
  hornA: Color(0xFFFDE68A),
  hornB: Color(0xFFFFFFFF),
  eyes: 1,
  mouth: MouthStyle.fangs,
  pupil: Color(0xFFDC2626),
);

// ==========================================================
// มอนสเตอร์โลกใหม่ (โลกที่ 5-10 → ด่าน 21-50)
// ==========================================================

// ---- Candy Land 🍭 ----
const MonsterLook kLookCandyPuff = MonsterLook(
  body: MonsterBody.egg,
  main: Color(0xFFFF8FB1),
  belly: Color(0xFFFFE4EC),
  blush: true,
  mouth: MouthStyle.smile,
  pupil: Color(0xFF9D174D),
);
const MonsterLook kLookCandyJelly = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFFFBBF24),
  horn: HornStyle.cone,
  hornA: Color(0xFFF472B6),
  hornB: Color(0xFFFFE4EC),
  eyes: 2,
  mouth: MouthStyle.grin,
);
const MonsterLook kLookCandyCotton = MonsterLook(
  body: MonsterBody.furry,
  main: Color(0xFFF9A8D4),
  horn: HornStyle.curl,
  hornA: Color(0xFFEC4899),
  eyes: 2,
  mouth: MouthStyle.toothy,
  pupil: Color(0xFF9D174D),
);
const MonsterLook kLookBossCandy = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFFF43F5E),
  belly: Color(0xFFFFE4E6),
  spots: Color(0xFFFDBA74),
  hair: Color(0xFFFB7185),
  horn: HornStyle.cone,
  hornA: Color(0xFFFDE68A),
  hornB: Color(0xFFFFFFFF),
  eyes: 1,
  mouth: MouthStyle.grin,
  pupil: Color(0xFF9F1239),
);

// ---- Ocean Deep 🌊 ----
const MonsterLook kLookOceanFish = MonsterLook(
  body: MonsterBody.egg,
  main: Color(0xFF22D3EE),
  belly: Color(0xFFCFFAFE),
  ears: Color(0xFF67E8F9),
  blush: true,
  mouth: MouthStyle.smile,
  pupil: Color(0xFF155E75),
);
const MonsterLook kLookOceanCrab = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFFFB923C),
  horn: HornStyle.ears,
  hornA: Color(0xFFFDBA74),
  hornB: Color(0xFFFFEDD5),
  eyes: 3,
  stalks: true,
  mouth: MouthStyle.open,
  arms: false,
);
const MonsterLook kLookOceanJelly = MonsterLook(
  body: MonsterBody.furry,
  main: Color(0xFFA78BFA),
  horn: HornStyle.curl,
  hornA: Color(0xFF7C3AED),
  eyes: 2,
  mouth: MouthStyle.toothy,
  pupil: Color(0xFF4C1D95),
);
const MonsterLook kLookBossOcean = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFF0D9488),
  belly: Color(0xFF99F6E4),
  spots: Color(0xFF134E4A),
  hair: Color(0xFF0F766E),
  horn: HornStyle.cone,
  hornA: Color(0xFFFDE68A),
  hornB: Color(0xFFFFFFFF),
  eyes: 1,
  mouth: MouthStyle.fangs,
  pupil: Color(0xFF134E4A),
);

// ---- Desert Ruins 🏜️ ----
const MonsterLook kLookDesertSphinx = MonsterLook(
  body: MonsterBody.egg,
  main: Color(0xFFFBBF24),
  belly: Color(0xFFFEF3C7),
  horn: HornStyle.ears,
  hornA: Color(0xFFD97706),
  hornB: Color(0xFFFDE68A),
  blush: true,
  mouth: MouthStyle.smile,
  pupil: Color(0xFF78350F),
);
const MonsterLook kLookDesertScorpion = MonsterLook(
  body: MonsterBody.ghost,
  main: Color(0xFFD97706),
  horn: HornStyle.bull,
  hornA: Color(0xFF78350F),
  hornB: Color(0xFFFDE68A),
  eyes: 2,
  lidded: true,
  mouth: MouthStyle.grumpy,
);
const MonsterLook kLookDesertMummy = MonsterLook(
  body: MonsterBody.furry,
  main: Color(0xFFFDE68A),
  eyes: 3,
  mouth: MouthStyle.toothy,
  pupil: Color(0xFF92400E),
);
const MonsterLook kLookBossDesert = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFFCA8A04),
  belly: Color(0xFFFEF3C7),
  spots: Color(0xFF92400E),
  hair: Color(0xFF78350F),
  horn: HornStyle.cone,
  hornA: Color(0xFF38BDF8),
  hornB: Color(0xFFE0F2FE),
  eyes: 1,
  mouth: MouthStyle.fangs,
  pupil: Color(0xFF78350F),
);

// ---- Frozen Peak ❄️ ----
const MonsterLook kLookFrostSnow = MonsterLook(
  body: MonsterBody.ghost,
  main: Color(0xFF7DD3FC),
  belly: Color(0xFFF0F9FF),
  blush: true,
  mouth: MouthStyle.smile,
  pupil: Color(0xFF0C4A6E),
);
const MonsterLook kLookFrostPenguin = MonsterLook(
  body: MonsterBody.egg,
  main: Color(0xFF475569),
  belly: Color(0xFFF8FAFC),
  horn: HornStyle.cone,
  hornA: Color(0xFF38BDF8),
  hornB: Color(0xFFE0F2FE),
  eyes: 2,
  mouth: MouthStyle.grin,
);
const MonsterLook kLookFrostYeti = MonsterLook(
  body: MonsterBody.furry,
  main: Color(0xFF93C5FD),
  horn: HornStyle.ears,
  hornA: Color(0xFF60A5FA),
  hornB: Color(0xFFDBEAFE),
  eyes: 2,
  mouth: MouthStyle.toothy,
  pupil: Color(0xFF1E3A8A),
);
const MonsterLook kLookBossFrost = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFF38BDF8),
  belly: Color(0xFFE0F2FE),
  spots: Color(0xFF0369A1),
  hair: Color(0xFF1D4ED8),
  horn: HornStyle.cone,
  hornA: Color(0xFFE0F2FE),
  hornB: Color(0xFFFFFFFF),
  eyes: 1,
  mouth: MouthStyle.fangs,
  pupil: Color(0xFF1E3A8A),
);

// ---- Starry Space 🚀 ----
const MonsterLook kLookSpaceAlien = MonsterLook(
  body: MonsterBody.ghost,
  main: Color(0xFFA3E635),
  eyes: 3,
  stalks: true,
  mouth: MouthStyle.open,
  arms: false,
  pupil: Color(0xFF365314),
);
const MonsterLook kLookSpaceComet = MonsterLook(
  body: MonsterBody.furry,
  main: Color(0xFF818CF8),
  horn: HornStyle.curl,
  hornA: Color(0xFF4F46E5),
  eyes: 2,
  mouth: MouthStyle.toothy,
  pupil: Color(0xFF312E81),
);
const MonsterLook kLookSpaceUnicorn = MonsterLook(
  body: MonsterBody.egg,
  main: Color(0xFF6366F1),
  spots: Color(0xFF4F46E5),
  horn: HornStyle.unicorn,
  hornA: Color(0xFFFACC15),
  hornB: Color(0xFFFEF9C3),
  eyes: 1,
  mouth: MouthStyle.smile,
  pupil: Color(0xFF1E1B4B),
);
const MonsterLook kLookBossSpace = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFF4338CA),
  belly: Color(0xFFC7D2FE),
  spots: Color(0xFF312E81),
  hair: Color(0xFF1E1B4B),
  horn: HornStyle.cone,
  hornA: Color(0xFFFDE68A),
  hornB: Color(0xFFFFFFFF),
  eyes: 1,
  mouth: MouthStyle.fangs,
  pupil: Color(0xFFFACC15),
);

// ---- Rainbow Palace 🌈 (โลกสุดท้าย) ----
const MonsterLook kLookRainbowGhost = MonsterLook(
  body: MonsterBody.ghost,
  main: Color(0xFFE879F9),
  horn: HornStyle.curl,
  hornA: Color(0xFF22D3EE),
  eyes: 2,
  mouth: MouthStyle.grin,
  pupil: Color(0xFF4A044E),
);
const MonsterLook kLookRainbowDeer = MonsterLook(
  body: MonsterBody.egg,
  main: Color(0xFFFACC15),
  horn: HornStyle.bull,
  hornA: Color(0xFF22C55E),
  hornB: Color(0xFFA855F7),
  eyes: 2,
  blush: true,
  mouth: MouthStyle.grin,
  pupil: Color(0xFF78350F),
);
const MonsterLook kLookRainbowCloud = MonsterLook(
  body: MonsterBody.furry,
  main: Color(0xFF5EEAD4),
  horn: HornStyle.ears,
  hornA: Color(0xFFF472B6),
  hornB: Color(0xFFFBCFE8),
  eyes: 3,
  mouth: MouthStyle.toothy,
  pupil: Color(0xFF134E4A),
);
const MonsterLook kLookBossRainbow = MonsterLook(
  body: MonsterBody.round,
  main: Color(0xFFC026D3),
  belly: Color(0xFFFAE8FF),
  spots: Color(0xFFFACC15),
  hair: Color(0xFFFACC15),
  horn: HornStyle.cone,
  hornA: Color(0xFFFDE68A),
  hornB: Color(0xFFFFFFFF),
  eyes: 1,
  mouth: MouthStyle.fangs,
  pupil: Color(0xFF701A75),
);

class MonsterAvatar extends StatelessWidget {
  final MonsterLook look;
  final double size;
  final MonsterMood mood;
  final double blink;

  const MonsterAvatar({
    super.key,
    required this.look,
    this.size = 80,
    this.mood = MonsterMood.normal,
    this.blink = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: MonsterPainter(look, mood: mood, blink: blink)),
    );
  }
}

class MonsterPainter extends CustomPainter {
  final MonsterLook look;
  final MonsterMood mood;
  final double blink; // 0 = ตาเปิด, 1 = ตาหลับ

  MonsterPainter(this.look, {this.mood = MonsterMood.normal, this.blink = 0});

  static const Color _ink = Color(0xFF2B1B3D);

  static Color _shade(Color c, double delta) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  double get _topY {
    if (look.body == MonsterBody.egg) return 16;
    if (look.body == MonsterBody.ghost) return 14;
    return 26;
  }

  Path _bodyPath() {
    if (look.body == MonsterBody.round) {
      return Path()..addOval(const Rect.fromLTRB(19, 26, 81, 89));
    }
    if (look.body == MonsterBody.egg) {
      return Path()
        ..moveTo(50, 16)
        ..cubicTo(78, 16, 86, 52, 82, 80)
        ..quadraticBezierTo(80, 90, 50, 90)
        ..quadraticBezierTo(20, 90, 18, 80)
        ..cubicTo(14, 52, 22, 16, 50, 16)
        ..close();
    }
    if (look.body == MonsterBody.ghost) {
      final Path p = Path()..moveTo(17, 86);
      p.cubicTo(8, 56, 12, 14, 50, 14);
      p.cubicTo(88, 14, 92, 56, 83, 86);
      const int n = 4;
      const double xStart = 83;
      const double xEnd = 17;
      const double step = (xStart - xEnd) / n;
      for (int i = 0; i < n; i++) {
        final double xa = xStart - step * i;
        final double xb = xa - step;
        p.quadraticBezierTo((xa + xb) / 2, 102, xb, 86);
      }
      p.close();
      return p;
    }
    // furry: ขอบเป็นขนฟู
    final Path p = Path();
    const double cx = 50;
    const double cy = 58;
    const double rx = 33;
    const double ry = 31;
    const int n = 26;
    for (int i = 0; i <= n * 2; i++) {
      final double a = i * math.pi / n - math.pi / 2;
      final double r = i.isEven ? 1.0 : 1.08;
      final double x = cx + math.cos(a) * rx * r;
      final double y = cy + math.sin(a) * ry * r;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    return p;
  }

  List<Offset> _eyePositions() {
    if (look.stalks) return const [Offset(26, 15), Offset(50, 10), Offset(74, 15)];
    if (look.eyes == 1) return const [Offset(50, 43)];
    if (look.eyes == 3) return const [Offset(33, 47), Offset(67, 47), Offset(50, 31)];
    return const [Offset(37, 43), Offset(63, 43)];
  }

  double _eyeRadius() {
    if (look.stalks) return 7.5;
    if (look.eyes == 1) return look.body == MonsterBody.ghost ? 13 : 14;
    if (look.eyes == 3) return 7.5;
    return 10;
  }

  double _mouthTop() {
    if (look.stalks) return 46;
    if (look.eyes == 1) return 63;
    if (look.eyes == 3) return 61;
    return 60;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final MonsterLook l = look;
    final Color outline = _shade(l.main, -0.30);
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..color = outline;
    final double top = _topY;
    final List<Offset> eyePos = _eyePositions();
    final double eyeR = _eyeRadius();

    // เงาใต้ตัว
    canvas.drawOval(const Rect.fromLTRB(18, 89, 82, 99), Paint()..color = const Color(0x26000000));

    // หูข้างหัว
    if (l.ears != null) {
      for (final double x in const [15.0, 85.0]) {
        final Rect r = Rect.fromCenter(center: Offset(x, 44), width: 15, height: 19);
        canvas.drawOval(r, Paint()..color = l.ears!);
        canvas.drawOval(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = _shade(l.ears!, -0.25),
        );
      }
    }

    // ก้านตา
    if (l.stalks) {
      final Paint sp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round
        ..color = outline;
      final Paint sp2 = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = l.main;
      const List<Offset> bases = [Offset(36, 32), Offset(50, 26), Offset(64, 32)];
      for (int i = 0; i < 3; i++) {
        canvas.drawLine(bases[i], eyePos[i], sp);
        canvas.drawLine(bases[i], eyePos[i], sp2);
      }
    }

    // เขา / หู (วาดไว้หลังลำตัว)
    _horns(canvas, top);

    // เท้า
    if (l.body != MonsterBody.ghost) {
      final Paint fp = Paint()..color = _shade(l.main, -0.06);
      for (final double x in const [35.0, 65.0]) {
        final Rect r = Rect.fromCenter(center: Offset(x, 89), width: 24, height: 13);
        canvas.drawOval(r, fp);
        canvas.drawOval(r, line);
      }
    }

    // แขน
    if (l.arms) {
      final bool ghost = l.body == MonsterBody.ghost;
      final Paint ap = Paint()..color = _shade(l.main, -0.04);
      for (final int s in const [-1, 1]) {
        canvas.save();
        canvas.translate(50.0 + s * (ghost ? 41.0 : 35.0), ghost ? 64.0 : 62.0);
        canvas.rotate(-s * 0.35);
        final Rect r = Rect.fromCenter(center: Offset.zero, width: ghost ? 10.0 : 14.0, height: ghost ? 20.0 : 28.0);
        canvas.drawOval(r, ap);
        canvas.drawOval(r, line);
        canvas.restore();
      }
    }

    // ลำตัว
    final Path body = _bodyPath();
    final Rect bb = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          radius: 1.0,
          colors: [_shade(l.main, 0.10), l.main, _shade(l.main, -0.08)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bb),
    );

    // ท้อง + ลายจุด (ตัดขอบด้วยลำตัว)
    canvas.save();
    canvas.clipPath(body);
    if (l.belly != null) {
      canvas.drawOval(
        l.stalks ? const Rect.fromLTRB(24, 62, 76, 102) : const Rect.fromLTRB(29, 55, 71, 93),
        Paint()..color = l.belly!,
      );
    }
    if (l.spots != null) {
      final Paint spp = Paint()..color = l.spots!;
      for (final List<double> s in const [
        [27.0, 50.0, 5.5],
        [74.0, 47.0, 4.5],
        [24.0, 70.0, 4.5],
        [77.0, 68.0, 6.0],
        [64.0, 33.0, 3.5],
        [38.0, 32.0, 3.2],
      ]) {
        canvas.drawCircle(Offset(s[0], s[1]), s[2], spp);
      }
    }
    canvas.restore();
    canvas.drawPath(body, line);

    // ผมชี้ตั้งบนหัว
    if (l.hair != null) {
      final Paint hp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.4
        ..strokeCap = StrokeCap.round
        ..color = l.hair!;
      for (int i = -2; i <= 2; i++) {
        final double x = 50.0 + i * 6;
        canvas.drawLine(Offset(x, top + 4), Offset(x + i * 2.5, top - 7 - (2 - i.abs()) * 2.5), hp);
      }
    }

    // แก้มแดง
    if (l.blush) {
      final Paint bp = Paint()..color = const Color(0x66F43F5E);
      canvas.drawCircle(const Offset(27, 60), 5.5, bp);
      canvas.drawCircle(const Offset(73, 60), 5.5, bp);
    }

    // ตา
    for (final Offset p in eyePos) {
      _eye(canvas, p, eyeR);
    }
    if (mood == MonsterMood.angry || mood == MonsterMood.thinking) {
      _brows(canvas, eyePos, eyeR);
    }

    // ปาก
    _mouth(canvas, _mouthTop());

    canvas.restore();
  }

  void _stripedStroke(Canvas canvas, Path path, double width, Color a, Color b, double seg) {
    final Paint pa = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = a;
    final Paint pb = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = b;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      bool flip = false;
      while (d < metric.length) {
        final double end = math.min(d + seg, metric.length);
        canvas.drawPath(metric.extractPath(d, end), flip ? pb : pa);
        d = end;
        flip = !flip;
      }
    }
  }

  void _sym(Canvas canvas, void Function() drawLeft) {
    drawLeft();
    canvas.save();
    canvas.translate(100, 0);
    canvas.scale(-1, 1);
    drawLeft();
    canvas.restore();
  }

  void _horns(Canvas canvas, double top) {
    final MonsterLook l = look;
    if (l.horn == HornStyle.none) return;

    if (l.horn == HornStyle.cone) {
      final Path p = Path()
        ..moveTo(24, top + 16)
        ..quadraticBezierTo(12, top - 2, 17, top - 18)
        ..quadraticBezierTo(33, top - 6, 43, top + 12)
        ..close();
      final Path ridge = Path()
        ..moveTo(22, top + 6)
        ..quadraticBezierTo(20, top - 4, 21, top - 10);
      _sym(canvas, () {
        canvas.drawPath(p, Paint()..color = l.hornA);
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeJoin = StrokeJoin.round
            ..color = _shade(l.hornA, -0.32),
        );
        canvas.drawPath(
          ridge,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = l.hornB,
        );
      });
    } else if (l.horn == HornStyle.curl) {
      final Path p = Path()
        ..moveTo(33, top + 12)
        ..quadraticBezierTo(15, top + 4, 19, top - 12)
        ..quadraticBezierTo(23, top - 22, 32, top - 14);
      _sym(canvas, () {
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9.4
            ..strokeCap = StrokeCap.round
            ..color = _shade(l.hornA, -0.28),
        );
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..color = l.hornA,
        );
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round
            ..color = _shade(l.hornA, 0.22),
        );
      });
    } else if (l.horn == HornStyle.bull) {
      final Path p = Path()
        ..moveTo(34, top + 12)
        ..cubicTo(16, top + 10, 10, top - 2, 15, top - 17);
      _sym(canvas, () {
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9.4
            ..strokeCap = StrokeCap.round
            ..color = _shade(l.hornA, -0.30),
        );
        _stripedStroke(canvas, p, 7, l.hornA, l.hornB, 4.5);
      });
    } else if (l.horn == HornStyle.ears) {
      final Path p = Path()
        ..moveTo(27, top + 18)
        ..lineTo(20, top - 8)
        ..lineTo(44, top + 10)
        ..close();
      final Path inner = Path()
        ..moveTo(28, top + 10)
        ..lineTo(24, top - 1)
        ..lineTo(36, top + 8)
        ..close();
      _sym(canvas, () {
        canvas.drawPath(p, Paint()..color = l.hornA);
        canvas.drawPath(inner, Paint()..color = l.hornB);
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeJoin = StrokeJoin.round
            ..color = _shade(l.hornA, -0.32),
        );
      });
    } else if (l.horn == HornStyle.unicorn) {
      final Path p = Path()
        ..moveTo(44, top + 6)
        ..lineTo(50, top - 15)
        ..lineTo(56, top + 6)
        ..close();
      canvas.save();
      canvas.clipPath(p);
      for (int i = 0; i < 4; i++) {
        canvas.drawRect(
          Rect.fromLTWH(40, top - 15 + i * 6.0, 20, 6),
          Paint()..color = i.isEven ? l.hornA : l.hornB,
        );
      }
      canvas.restore();
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round
          ..color = _shade(l.hornA, -0.32),
      );
    }
  }

  void _eye(Canvas canvas, Offset c, double r) {
    if (mood == MonsterMood.hurt) {
      final Paint xp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = _ink;
      final double d = r * 0.55;
      canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), xp);
      canvas.drawLine(c + Offset(d, -d), c + Offset(-d, d), xp);
      return;
    }
    if (mood == MonsterMood.laugh) {
      // ตาหัวเราะ ^ ^
      final Path arc = Path()
        ..moveTo(c.dx - r * 0.8, c.dy + r * 0.3)
        ..quadraticBezierTo(c.dx, c.dy - r * 0.95, c.dx + r * 0.8, c.dy + r * 0.3);
      canvas.drawPath(
        arc,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round
          ..color = _ink,
      );
      return;
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, (1 - blink * 0.9).clamp(0.1, 1.0));
    canvas.drawCircle(Offset.zero, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x552B1B3D),
    );
    final double pr = r * (mood == MonsterMood.shocked ? 0.28 : 0.52);
    final Offset po = Offset(-r * 0.14, r * 0.05);
    canvas.drawCircle(po, pr, Paint()..color = look.pupil);
    canvas.drawCircle(po, pr * 0.55, Paint()..color = const Color(0xFF1B1030));
    canvas.drawCircle(po + Offset(pr * 0.35, -pr * 0.4), pr * 0.32, Paint()..color = Colors.white);
    if (look.lidded) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r + 0.6),
        math.pi,
        math.pi,
        true,
        Paint()..color = look.main,
      );
      final Paint lp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = _ink;
      canvas.drawLine(Offset(-r, 0), Offset(r, 0), lp);
      for (int i = -1; i <= 1; i++) {
        canvas.drawLine(Offset(i * r * 0.55, -r * 0.35), Offset(i * r * 0.75, -r * 0.85), lp);
      }
    }
    canvas.restore();
  }

  void _brows(Canvas canvas, List<Offset> pts, double r) {
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..color = _ink;
    for (final Offset c in pts) {
      if (c.dx < 45) {
        canvas.drawLine(Offset(c.dx - r, c.dy - r - 1), Offset(c.dx + r * 0.9, c.dy - r * 0.55), p);
      } else if (c.dx > 55) {
        canvas.drawLine(Offset(c.dx + r, c.dy - r - 1), Offset(c.dx - r * 0.9, c.dy - r * 0.55), p);
      } else {
        canvas.drawLine(Offset(c.dx - r, c.dy - r - 1), Offset(c.dx, c.dy - r * 0.6), p);
        canvas.drawLine(Offset(c.dx + r, c.dy - r - 1), Offset(c.dx, c.dy - r * 0.6), p);
      }
    }
  }

  Path _bowl(double mt, double w, double h) {
    final double x0 = 50 - w / 2;
    final double x1 = 50 + w / 2;
    return Path()
      ..moveTo(x0, mt)
      ..quadraticBezierTo(50, mt + 2.5, x1, mt)
      ..cubicTo(x1 - 1, mt + h * 1.2, x0 + 1, mt + h * 1.2, x0, mt)
      ..close();
  }

  void _mouth(Canvas canvas, double mt) {
    final Paint ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _ink;
    final Paint white = Paint()..color = Colors.white;
    final Paint tongue = Paint()..color = const Color(0xFFF472B6);

    // โดนตี -> ร้องโอ๊ย
    if (mood == MonsterMood.hurt) {
      final Rect r = Rect.fromCenter(center: Offset(50, mt + 9), width: 15, height: 17);
      canvas.drawOval(r, Paint()..color = const Color(0xFF4A1230));
      canvas.drawOval(Rect.fromCenter(center: Offset(50, mt + 14), width: 9, height: 6), tongue);
      canvas.drawOval(r, ink);
      return;
    }

    if (mood == MonsterMood.laugh) {
      final Path lm = _bowl(mt, 44, 26);
      canvas.drawPath(lm, Paint()..color = const Color(0xFF5B1A3A));
      canvas.save();
      canvas.clipPath(lm);
      canvas.drawOval(Rect.fromCenter(center: Offset(50, mt + 22), width: 24, height: 14), tongue);
      canvas.drawRect(Rect.fromLTRB(26, mt - 1, 74, mt + 5), white);
      canvas.restore();
      canvas.drawPath(lm, ink);
      return;
    }
    if (mood == MonsterMood.shocked) {
      final Rect sr = Rect.fromCenter(center: Offset(50, mt + 8), width: 12, height: 15);
      canvas.drawOval(sr, Paint()..color = const Color(0xFF4A1230));
      canvas.drawOval(sr, ink);
      return;
    }
    if (mood == MonsterMood.thinking) {
      final Path tm = Path()
        ..moveTo(40, mt + 8)
        ..quadraticBezierTo(46, mt + 4, 50, mt + 8)
        ..quadraticBezierTo(54, mt + 12, 60, mt + 8);
      canvas.drawPath(tm, ink..strokeWidth = 2.2);
      return;
    }

    switch (look.mouth) {
      case MouthStyle.grin: {
        final Path m = _bowl(mt, 38, 20);
        canvas.drawPath(m, Paint()..color = const Color(0xFF5B1A3A));
        canvas.save();
        canvas.clipPath(m);
        canvas.drawOval(Rect.fromCenter(center: Offset(50, mt + 19), width: 22, height: 12), tongue);
        canvas.drawRect(Rect.fromLTRB(28, mt - 1, 72, mt + 5), white);
        final Paint gap = Paint()
          ..strokeWidth = 0.9
          ..color = const Color(0x552B1B3D);
        for (final double x in const [42.0, 50.0, 58.0]) {
          canvas.drawLine(Offset(x, mt), Offset(x, mt + 5), gap);
        }
        canvas.restore();
        canvas.drawPath(m, ink);
        break;
      }
      case MouthStyle.toothy: {
        final Path m = _bowl(mt, 48, 24);
        canvas.drawPath(m, white);
        canvas.save();
        canvas.clipPath(m);
        final Paint gap = Paint()
          ..strokeWidth = 1.0
          ..color = const Color(0x552B1B3D);
        for (int i = 1; i < 8; i++) {
          final double x = 26 + i * 6.0;
          canvas.drawLine(Offset(x, mt), Offset(x, mt + 26), gap);
        }
        canvas.drawLine(Offset(24, mt + 9), Offset(76, mt + 9), gap);
        canvas.restore();
        canvas.drawPath(m, ink);
        break;
      }
      case MouthStyle.fangs: {
        final Path m = _bowl(mt, 42, 22);
        canvas.drawPath(m, Paint()..color = const Color(0xFF1B1030));
        canvas.save();
        canvas.clipPath(m);
        for (int i = 0; i < 6; i++) {
          final double x = 29 + i * 7.0;
          canvas.drawPath(
            Path()
              ..moveTo(x, mt - 1)
              ..lineTo(x + 7, mt - 1)
              ..lineTo(x + 3.5, mt + 7.5)
              ..close(),
            white,
          );
        }
        canvas.restore();
        canvas.drawPath(m, ink);
        break;
      }
      case MouthStyle.open: {
        final bool big = look.stalks;
        final Rect r = big ? Rect.fromLTWH(30, mt, 40, 32) : Rect.fromLTWH(38, mt, 24, 20);
        final Path m = Path()..addOval(r);
        canvas.drawPath(m, Paint()..color = const Color(0xFF4A0E0E));
        canvas.save();
        canvas.clipPath(m);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(50, r.bottom - 2), width: r.width * 0.6, height: r.height * 0.42),
          Paint()..color = const Color(0xFFEF7B6B),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(r.left + r.width * 0.22, r.top, r.width * 0.16, r.height * 0.2), const Radius.circular(1.5)),
          white,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(r.right - r.width * 0.38, r.top, r.width * 0.16, r.height * 0.2), const Radius.circular(1.5)),
          white,
        );
        canvas.restore();
        canvas.drawPath(m, ink);
        break;
      }
      case MouthStyle.grumpy: {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(46.5, mt + 3.5, 7, 5.5), const Radius.circular(1.2)),
          white,
        );
        final Path m = Path()
          ..moveTo(37, mt + 10)
          ..quadraticBezierTo(50, mt - 3, 63, mt + 10);
        canvas.drawPath(m, ink..strokeWidth = 2.4);
        break;
      }
      case MouthStyle.smile: {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(47.5, mt + 5.5, 5, 6), const Radius.circular(1.2)),
          white,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(47.5, mt + 5.5, 5, 6), const Radius.circular(1.2)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = _ink,
        );
        final Path m = Path()
          ..moveTo(37, mt + 2)
          ..quadraticBezierTo(50, mt + 13, 63, mt + 2);
        canvas.drawPath(m, ink..strokeWidth = 2.4);
        break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant MonsterPainter old) =>
      old.look != look || old.mood != mood || old.blink != blink;
}

// ==========================================
// รูปภาพประกอบคำศัพท์ (อีโมจิ) ช่วยให้เด็กจำคำได้ง่ายขึ้น
// ==========================================
const Map<String, String> kWordEmoji = {
  'Apple': '🍎', 'Banana': '🍌', 'Orange': '🍊', 'Running': '🏃', 'Golf': '⛳',
  'Cat': '🐱', 'Dog': '🐶', 'Fish': '🐟', 'Cook': '👨‍🍳', 'Doctor': '🧑‍⚕️',
  'Car': '🚗', 'Bus': '🚌', 'Park': '🏞️', 'Home': '🏠', 'Mango': '🥭',
  'Jumping': '🤸', 'Bird': '🐦', 'Cow': '🐮', 'Police': '👮', 'Boat': '⛵',
  'Train': '🚆', 'School': '🏫', 'Red': '🔴', 'Green': '🟢', 'Yellow': '🟡',
  'Mother': '👩', 'Father': '👨',
  'Pineapple': '🍍', 'Strawberry': '🍓', 'Football': '⚽', 'Swimming': '🏊',
  'Elephant': '🐘', 'Dolphin': '🐬', 'Teacher': '👩‍🏫', 'Engineer': '👷',
  'Bicycle': '🚲', 'Airplane': '✈️', 'Hospital': '🏥', 'Library': '📚',
  'Watermelon': '🍉', 'Grapes': '🍇', 'Basketball': '🏀', 'Badminton': '🏸',
  'Giraffe': '🦒', 'Penguin': '🐧', 'Firefighter': '🧑‍🚒', 'Pilot': '🧑‍✈️',
  'Motorcycle': '🏍️', 'Airport': '🛫', 'Museum': '🏛️', 'Bakery': '🥖',
  'Taekwondo': '🥋', 'Gymnastics': '🤸‍♀️', 'Chameleon': '🦎', 'Rhinoceros': '🦏',
  'Archaeologist': '🏺', 'Entrepreneur': '💼', 'Amphitheater': '🏟️',
  'Observatory': '🔭', 'Fencing': '🤺', 'Archery': '🏹', 'Flamingo': '🦩',
  'Veterinarian': '🩺', 'Architect': '📐', 'Ambulance': '🚑', 'Skyscraper': '🏙️',
};

String _emojiFor(VocabQuestion q) => kWordEmoji[q.word] ?? q.category.split(' ').last;


const int kMonsterLevels = 40; // 40 ด่าน (ด่านที่หาร 5 ลงตัวคือบอส)

class MonsterTemplate {
  final String name;
  final MonsterLook look;
  const MonsterTemplate(this.name, this.look);
}

class WorldTheme {
  final String name;
  final String emoji;
  final List<Color> colors; // พื้นหลังสนามรบ
  final Color accent;
  final List<String> deco; // ของตกแต่งฉาก
  final List<MonsterTemplate> minions;
  final MonsterTemplate boss;
  const WorldTheme({
    required this.name,
    required this.emoji,
    required this.colors,
    required this.accent,
    required this.deco,
    required this.minions,
    required this.boss,
  });
}

const List<WorldTheme> kWorlds = [
  WorldTheme(
    name: 'ป่าเขียวขจี',
    emoji: '🌲',
    colors: [Color(0xFFF0FDF4), Color(0xFF86EFAC)],
    accent: Color(0xFF16A34A),
    deco: ['🌳', '☁️', '🍄', '🌼'],
    minions: [
      MonsterTemplate('เจ้าเขียวจอมซน', kLookGreenBlob),
      MonsterTemplate('เขาลายสีเขียว', kLookTealBull),
      MonsterTemplate('ขนฟูบลูบี้', kLookFuzzyBlue),
    ],
    boss: MonsterTemplate('ราชาตาเดียว', kLookBossTeal),
  ),
  WorldTheme(
    name: 'ถ้ำคริสตัล',
    emoji: '💎',
    colors: [Color(0xFFF5F3FF), Color(0xFFC4B5FD)],
    accent: Color(0xFF7C3AED),
    deco: ['💎', '🔮', '🦇', '✨'],
    minions: [
      MonsterTemplate('ผีเขี้ยวม่วง', kLookPurpleFang),
      MonsterTemplate('ยูนิตาเดียว', kLookPurpleUnicorn),
      MonsterTemplate('หูชมพูจอมขี้เล่น', kLookBlueEars),
    ],
    boss: MonsterTemplate('ราชาถ้ำคริสตัล', kLookBossPurple),
  ),
  WorldTheme(
    name: 'ภูเขาไฟลาวา',
    emoji: '🌋',
    colors: [Color(0xFFFFF7ED), Color(0xFFFDBA74)],
    accent: Color(0xFFEA580C),
    deco: ['🌋', '🔥', '☁️', '💫'],
    minions: [
      MonsterTemplate('ส้มจอมขี้บ่น', kLookOrangeGrumpy),
      MonsterTemplate('สามตาก้านแดง', kLookRedStalk),
      MonsterTemplate('แดงหนามจี๊ด', kLookRedSpiky),
    ],
    boss: MonsterTemplate('จ้าวภูเขาไฟ', kLookBossRed),
  ),
  WorldTheme(
    name: 'ปราสาทลอยฟ้า',
    emoji: '🏰',
    colors: [Color(0xFFF0F9FF), Color(0xFF93C5FD)],
    accent: Color(0xFF2563EB),
    deco: ['☁️', '🏰', '🌈', '⭐'],
    minions: [
      MonsterTemplate('ผีชมพูเขาเกลียว', kLookPinkGhost),
      MonsterTemplate('ส้มเขาลาย', kLookOrangeBull),
      MonsterTemplate('ขนฟูเมฆา', kLookFuzzyCloud),
    ],
    boss: MonsterTemplate('จอมราชาแห่งฟ้า', kLookBossDark),
  ),
  WorldTheme(
    name: 'ดินแดนขนมหวาน',
    emoji: '🍭',
    colors: [Color(0xFFFFF1F2), Color(0xFFFDA4AF)],
    accent: Color(0xFFE11D48),
    deco: ['🍭', '🍬', '🧁', '🍩'],
    minions: [
      MonsterTemplate('ก้อนขนมแก้มแดง', kLookCandyPuff),
      MonsterTemplate('เยลลี่เขาลูกอม', kLookCandyJelly),
      MonsterTemplate('ปุยฝ้ายชมพู', kLookCandyCotton),
    ],
    boss: MonsterTemplate('ราชินีเค้กยักษ์', kLookBossCandy),
  ),
  WorldTheme(
    name: 'ใต้มหาสมุทร',
    emoji: '🌊',
    colors: [Color(0xFFF0FDFA), Color(0xFF5EEAD4)],
    accent: Color(0xFF0D9488),
    deco: ['🌊', '🐠', '🐚', '🐙'],
    minions: [
      MonsterTemplate('ปลาจิ๋วจอมซน', kLookOceanFish),
      MonsterTemplate('ปูก้ามโต', kLookOceanCrab),
      MonsterTemplate('แมงกะพรุนขนฟู', kLookOceanJelly),
    ],
    boss: MonsterTemplate('จ้าวสมุทรตาเดียว', kLookBossOcean),
  ),
  WorldTheme(
    name: 'เมืองร้างกลางทะเลทราย',
    emoji: '🏜️',
    colors: [Color(0xFFFEFCE8), Color(0xFFFDE047)],
    accent: Color(0xFFCA8A04),
    deco: ['🏜️', '🌵', '☀️', '🐪'],
    minions: [
      MonsterTemplate('สฟิงซ์น้อยแก้มแดง', kLookDesertSphinx),
      MonsterTemplate('แมงป่องจอมบ่น', kLookDesertScorpion),
      MonsterTemplate('มัมมี่ขนฟู', kLookDesertMummy),
    ],
    boss: MonsterTemplate('ฟาโรห์ตาทอง', kLookBossDesert),
  ),
  WorldTheme(
    name: 'ยอดเขาน้ำแข็ง',
    emoji: '❄️',
    colors: [Color(0xFFF0F9FF), Color(0xFFBAE6FD)],
    accent: Color(0xFF0284C7),
    deco: ['❄️', '⛄', '🏔️', '✨'],
    minions: [
      MonsterTemplate('ก้อนหิมะยิ้มแป้น', kLookFrostSnow),
      MonsterTemplate('เพนกวินเขาน้ำแข็ง', kLookFrostPenguin),
      MonsterTemplate('เยติขนฟู', kLookFrostYeti),
    ],
    boss: MonsterTemplate('ราชันเยือกแข็ง', kLookBossFrost),
  ),
  WorldTheme(
    name: 'อวกาศดวงดาว',
    emoji: '🚀',
    colors: [Color(0xFFEEF2FF), Color(0xFF818CF8)],
    accent: Color(0xFF4F46E5),
    deco: ['🚀', '🪐', '⭐', '🌙'],
    minions: [
      MonsterTemplate('เอเลี่ยนตาสาม', kLookSpaceAlien),
      MonsterTemplate('ดาวหางขนฟู', kLookSpaceComet),
      MonsterTemplate('ไข่จักรวาลยูนิคอร์น', kLookSpaceUnicorn),
    ],
    boss: MonsterTemplate('ราชันดาวมืด', kLookBossSpace),
  ),
  WorldTheme(
    name: 'วังสายรุ้ง',
    emoji: '🌈',
    colors: [Color(0xFFFDF2F8), Color(0xFFF0ABFC)],
    accent: Color(0xFFC026D3),
    deco: ['🌈', '👑', '⭐', '💖'],
    minions: [
      MonsterTemplate('ผีสายรุ้งหัวเราะ', kLookRainbowGhost),
      MonsterTemplate('กวางเขาหรรษา', kLookRainbowDeer),
      MonsterTemplate('เมฆฝนสีรุ้ง', kLookRainbowCloud),
    ],
    boss: MonsterTemplate('จักรพรรดิรุ้งทองคำ', kLookBossRainbow),
  ),
];

WorldTheme worldOf(int level) => kWorlds[((level - 1) ~/ 5).clamp(0, kWorlds.length - 1).toInt()];
bool isBossLevel(int level) => level % 5 == 0;
DifficultyLevel difficultyOfLevel(int level) =>
    level <= 6 ? DifficultyLevel.easy : (level <= 13 ? DifficultyLevel.medium : DifficultyLevel.hard);
int wavesOfLevel(int level) => math.min(5, 2 + level ~/ 8); 
int heroMaxHpOf(int level) => 100 + (level - 1) * 6;

class PowerUpInfo {
  final String id;
  final String emoji;
  final String name;
  final String desc;
  final int price; // real coins (the server has the same prices)
  const PowerUpInfo({required this.id, required this.emoji, required this.name, required this.desc, required this.price});
}

const List<PowerUpInfo> kPowerUps = [
  PowerUpInfo(id: 'hint', emoji: '🧭', name: '50:50', desc: 'ตัดตัวเลือกผิดออก 2 ข้อ', price: 10),
  PowerUpInfo(id: 'freeze', emoji: '⏳', name: 'หยุดเวลา', desc: 'หยุดเวลาคิดของมอนสเตอร์ 3 วินาที', price: 10),
  PowerUpInfo(id: 'smoke', emoji: '💨', name: 'ระเบิดควัน', desc: 'มอนสเตอร์ลังเล ตอบช้าลง 2 วินาที', price: 8),
  PowerUpInfo(id: 'shield', emoji: '🛡️', name: 'โล่ป้องกัน', desc: 'กันดาเมจจากการโดนแย่งตอบ 1 ครั้ง', price: 12),
];

// ==========================================
// ความคืบหน้า (บันทึกลงเครื่อง): ดาว / เหรียญ / ไอเทม / รางวัลรายวัน
// ==========================================
class MonsterProgress extends ChangeNotifier {
  final List<int> stars = List<int>.filled(kMonsterLevels, 0);
  final Map<String, int> items = {'hint': 3, 'freeze': 3, 'smoke': 2, 'shield': 2};
  bool buying = false; // a purchase is being sent
  Set<int> unfinished = {}; // levels left in the middle (the "ต่อ" marks)

  Future<void> _loadUnfinished() async {
    final result = <int>{};
    for (int level = 1; level <= kMonsterLevels; level++) {
      final r = await MonsterResume.load(level, waves: wavesOfLevel(level), maxHp: heroMaxHpOf(level));
      if (r != null) result.add(level);
    }
    unfinished = result;
  }

  void markUnfinished(int level, bool on) {
    final changed = on ? unfinished.add(level) : unfinished.remove(level);
    if (changed) notifyListeners();
  }
  int bestCombo = 0;
  int kills = 0;
  int bossKills = 0;
  int dailyStreak = 0;
  String lastDaily = '';

  int get totalStars => stars.fold(0, (a, b) => a + b);
  bool isUnlocked(int level) => level == 1 || stars[level - 2] > 0;

  int get nextLevel {
    for (int i = 1; i <= kMonsterLevels; i++) {
      if (stars[i - 1] == 0) return i;
    }
    return kMonsterLevels;
  }

  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  bool get canClaimDaily => lastDaily != _key(DateTime.now());

  // ---------- saved per account, on the phone and on the server ----------

  void _setDefaults() {
    for (int i = 0; i < stars.length; i++) {
      stars[i] = 0;
    }
    items
      ..['hint'] = 3
      ..['freeze'] = 3
      ..['smoke'] = 2
      ..['shield'] = 2;
    bestCombo = 0;
    kills = 0;
    bossKills = 0;
    dailyStreak = 0;
    lastDaily = '';
  }

  Map<String, dynamic> _toJson() => {
        'stars': List<int>.of(stars),
        'items': Map<String, int>.of(items),
        'kills': kills,
        'bossKills': bossKills,
        'bestCombo': bestCombo,
        'dailyStreak': dailyStreak,
        'lastDaily': lastDaily,
      };

  void _apply(Map<String, dynamic> d) {
    int n(dynamic v, int max) => v is int ? v.clamp(0, max).toInt() : 0;
    final s = d['stars'];
    if (s is List) {
      for (int i = 0; i < kMonsterLevels; i++) {
        stars[i] = i < s.length ? n(s[i], 3) : 0;
      }
    }
    final it = d['items'];
    if (it is Map) {
      for (final id in items.keys.toList()) {
        if (it[id] is int) items[id] = n(it[id], 9999);
      }
    }
    kills = n(d['kills'], 10000000);
    bossKills = n(d['bossKills'], 10000000);
    bestCombo = n(d['bestCombo'], 100000);
    dailyStreak = n(d['dailyStreak'], 100000);
    lastDaily = d['lastDaily'] is String ? d['lastDaily'] as String : '';
  }

  /// Loads the signed-in account's game (called each time the level list
  /// opens, so another account never sees this one's progress).
  Future<void> load() async {
    if (CoinBalance.value.value == null) CoinBalance.refresh();
    _setDefaults();
    try {
      final local = await MonsterStateSync.loadLocal();
      if (local != null) {
        _apply(local);
      } else {
        // Played with the old phone-only version: move it to this account.
        final old = await MonsterStateSync.claimOldProgress();
        if (old != null) {
          _apply(old);
          await MonsterStateSync.save(_toJson());
        }
      }
      // Newer copy on the server (reinstalled / another phone)?
      final server = await MonsterStateSync.pull()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (server != null) _apply(server);
      await MonsterResume.sync().timeout(const Duration(seconds: 4), onTimeout: () {});
      await _loadUnfinished();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() => MonsterStateSync.save(_toJson());

  void _changed() {
    notifyListeners();
    _save();
  }

  /// Buys 1 item with the account's real coins (on the server).
  /// Returns a message to show when it didn't work.
  Future<String?> buy(PowerUpInfo item) async {
    if (buying) return null;
    buying = true;
    notifyListeners();
    final r = await MonsterShop.buy(item.id);
    buying = false;
    if (r.ok) {
      items[item.id] = (items[item.id] ?? 0) + 1;
      _changed();
    } else {
      notifyListeners();
    }
    return r.error;
  }

  bool useItem(String id) {
    final have = items[id] ?? 0;
    if (have <= 0) return false;
    items[id] = have - 1;
    _changed();
    return true;
  }

  void addItem(String id, [int n = 1]) {
    items[id] = (items[id] ?? 0) + n;
    _changed();
  }

  void recordKill({required bool boss}) {
    kills++;
    if (boss) bossKills++;
    _changed();
  }

  void noteCombo(int combo) {
    if (combo > bestCombo) {
      bestCombo = combo;
      _changed();
    }
  }

  void completeLevel(int level, int earnedStars) {
    if (earnedStars > stars[level - 1]) stars[level - 1] = earnedStars;
    _changed();
  }

  /// Today's reward: 1 item (a different one each day) and a free shield
  /// every 3rd day in a row. Returns what was given ('' = already taken).
  String claimDaily() {
    final now = DateTime.now();
    final today = _key(now);
    if (lastDaily == today) return '';
    final yesterday = _key(now.subtract(const Duration(days: 1)));
    dailyStreak = lastDaily == yesterday ? dailyStreak + 1 : 1;
    lastDaily = today;
    final id = dailyItemId(dailyStreak);
    items[id] = (items[id] ?? 0) + 1;
    if (dailyStreak % 3 == 0) items['shield'] = (items['shield'] ?? 0) + 1;
    _changed();
    return dailyRewardText(dailyStreak);
  }

  static String dailyItemId(int streak) => const ['hint', 'freeze', 'smoke'][(streak - 1) % 3];

  static String dailyRewardText(int streak) {
    final info = kPowerUps.firstWhere((p) => p.id == dailyItemId(streak));
    return '${info.name} 1 ชิ้น${streak % 3 == 0 ? ' + โล่ป้องกัน 1 อัน' : ''}';
  }

  Future<void> reset() async {
    _setDefaults();
    notifyListeners();
    await _save();
  }
}

final MonsterProgress monsterProgress = MonsterProgress();

class _GameButton extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color shadow;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final double radius;

  const _GameButton({
    required this.child,
    required this.color,
    required this.shadow,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: enabled ? color : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [BoxShadow(color: enabled ? shadow : const Color(0xFF94A3B8), offset: const Offset(0, 4))],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
          textAlign: TextAlign.center,
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
  }
}

class DifficultySelectionScreen extends StatefulWidget {
  const DifficultySelectionScreen({super.key});

  @override
  State<DifficultySelectionScreen> createState() => _DifficultySelectionScreenState();
}

class _DifficultySelectionScreenState extends State<DifficultySelectionScreen> {
  late final Future<void> _loading = monsterProgress.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return const _LevelSelectView();
      },
    );
  }
}

class _LevelSelectView extends StatelessWidget {
  const _LevelSelectView();

  // ignore: unused_field
  static const Color _gold = Color(0xFFFFC107);

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(duration: const Duration(milliseconds: 1600), content: Text(msg)));
  }

  void _openPreview(BuildContext context, int level) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LevelPreviewSheet(level: level),
    );
  }

  Widget _tile(BuildContext context, int level) {
    final p = monsterProgress;
    final unlocked = p.isUnlocked(level);
    final stars = p.stars[level - 1];
    final boss = isBossLevel(level);
    final current = unlocked && stars == 0;

    List<Color> face;
    Color edge;
    if (!unlocked) {
      face = const [Color(0xFFB4B7BD), Color(0xFF878B93)];
      edge = const Color(0xFF5F6369);
    } else if (boss) {
      face = const [Color(0xFFFF7566), Color(0xFFE03A30)];
      edge = const Color(0xFF9B1C1C);
    } else if (current) {
      face = const [Color(0xFF4ADE80), Color(0xFF16A34A)];
      edge = const Color(0xFF166534);
    } else {
      face = const [Color(0xFF9B6BFF), Color(0xFF6D3FE0)];
      edge = const Color(0xFF4C1D95);
    }

    return GestureDetector(
      onTap: unlocked
          ? () => _openPreview(context, level)
          : () => _snack(context, 'ผ่านด่าน ${level - 1} ก่อนเพื่อปลดล็อก !'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
          AspectRatio(
              aspectRatio: 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: face),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withAlpha(120), width: 2.5),
                        boxShadow: [
                          BoxShadow(color: edge, offset: const Offset(0, 4)),
                          const BoxShadow(color: Color(0x33000000), offset: Offset(0, 7), blurRadius: 6),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // เงาวาวด้านบนของปุ่ม
                          Positioned(
                            top: 3,
                            left: 6,
                            right: 6,
                            height: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(unlocked ? 60 : 45),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          Center(
                            child: unlocked
                                ? Text(
                                    '$level',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2))],
                                    ),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock_rounded, color: Color(0xFF4B5563), size: 22),
                                      Text('$level', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF4B5563))),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
              if (unlocked && p.unfinished.contains(level))
                Positioned(
                  top: -7,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDB2777),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Text('▶ ต่อ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 18,
            child: unlocked
                ? Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: stars > 0 ? const Color(0xFF22C55E) : const Color(0xFFD1D5DB),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// ด่าน 1–40 เรียงต่อกัน แถวละ 4 ด่าน (ไม่แบ่งเป็นโลก)
  Widget _levelGrid(BuildContext context) {
    const int perRow = 4;
    final int rows = (kMonsterLevels + perRow - 1) ~/ perRow;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFF9A8D4), width: 4),
        boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 4), blurRadius: 8)],
      ),
      child: Column(
        children: [
          for (int r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  for (int c = 0; c < perRow; c++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: r * perRow + c < kMonsterLevels
                            ? _tile(context, r * perRow + c + 1)
                            : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- ปุ่มย้อนกลับ ----------
  // ignore: unused_element
  Widget _backButton(BuildContext context) {
    return _GameButton(
      color: const Color(0xFFF59E0B),
      shadow: const Color(0xFFB45309),
      radius: 24,
      padding: const EdgeInsets.all(10),
      onPressed: () => _handleBack(context),
      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    final NavigatorState nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    // หน้านี้เป็นหน้าแรกของแอป -> ถามก่อนออกจากเกม
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('👋 ออกจากเกม ?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDB2777))),
        content: const Text('ความคืบหน้าถูกบันทึกไว้แล้วนะ', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('เล่นต่อ')),
          _GameButton(
            color: const Color(0xFFEF4444),
            shadow: const Color(0xFF991B1B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ออก'),
          ),
        ],
      ),
    );
    if (leave == true) SystemNavigator.pop();
  }

  void _openDaily(BuildContext context) {
    final p = monsterProgress;
    final canClaim = p.canClaimDaily;
    final nextStreak = canClaim ? p.dailyStreak + 1 : p.dailyStreak;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('รางวัลรายวัน', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDB2777))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('เข้าเล่นต่อเนื่อง $nextStreak วัน', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text(
              canClaim
                  ? 'วันนี้รับได้ ${MonsterProgress.dailyRewardText(nextStreak)}'
                  : 'วันนี้รับไปแล้ว พรุ่งนี้มาใหม่นะ !',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            const Text('ทุก 3 วันติดต่อกันได้โล่ป้องกันฟรี 1 อัน', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          _GameButton(
            color: const Color(0xFF22C55E),
            shadow: const Color(0xFF15803D),
            onPressed: canClaim
                ? () {
                    final reward = p.claimDaily();
                    Navigator.pop(ctx);
                    _snack(context, 'ได้รับ $reward');
                  }
                : null,
            child: Text(canClaim ? 'รับรางวัล' : 'รับแล้ว'),
          ),
        ],
      ),
    );
  }

  void _openAchievements(BuildContext context) {
    final p = monsterProgress;
    final int cleared = p.stars.where((s) => s > 0).length;
    final list = <List<dynamic>>[
      ['⚔️', 'ชัยชนะแรก', 'ผ่านด่านแรก', cleared > 0],
      ['⭐', 'ไร้ที่ติ !', 'ผ่านด่านโดยมีเลือดเหลือ 70% ขึ้นไป', p.stars.any((s) => s >= 3)],
      ['👑', 'นักล่าบอส', 'ล้มบอสครั้งแรก', p.bossKills >= 1],
      ['🔥', 'เซียนคอมโบ', 'ทำคอมโบ x8 ขึ้นไป', p.bestCombo >= 8],
      ['🗡️', 'นักล่ามอนสเตอร์', 'ล้มมอนสเตอร์ 50 ตัว (${p.kills} / 50)', p.kills >= 50],
      ['🌟', 'เจ้าแห่งด่าน', 'ผ่านครบ $kMonsterLevels ด่าน ($cleared / $kMonsterLevels)', cleared >= kMonsterLevels],
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🏅 ความสำเร็จ', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDB2777))),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: list.map((a) {
              final done = a[3] as bool;
              return ListTile(
                dense: true,
                leading: Opacity(opacity: done ? 1 : 0.35, child: Text(a[0] as String, style: const TextStyle(fontSize: 28))),
                title: Text(a[1] as String, style: TextStyle(fontWeight: FontWeight.w900, color: done ? const Color(0xFF1E293B) : const Color(0xFF94A3B8))),
                subtitle: Text(a[2] as String, style: const TextStyle(fontSize: 12)),
                trailing: Icon(done ? Icons.check_circle_rounded : Icons.lock_outline_rounded, color: done ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1)),
              );
            }).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด'))],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('ตั้งค่า', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDB2777))),
        content: const Text('รีเซ็ตความคืบหน้าและไอเทมทั้งหมดกลับเป็นค่าเริ่มต้น ?\n(เหรียญไม่หาย)\n(ต้องใช้รหัส PIN ผู้ปกครอง)', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          _GameButton(
            color: const Color(0xFFEF4444),
            shadow: const Color(0xFF991B1B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onPressed: () async {
              Navigator.pop(ctx);
              // Only a parent may wipe the child's progress.
              final allowed = await showParentPinPrompt(context, title: 'ผู้ปกครองยืนยันก่อนรีเซ็ต');
              if (!allowed) return;
              await monsterProgress.reset();
            },
            child: const Text('รีเซ็ต'),
          ),
        ],
      ),
    );
  }

  Widget _bottomIcon({required String label, required IconData icon, required List<Color> colors, required Color shadow, required VoidCallback onTap, bool badge = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(color: shadow, offset: const Offset(0, 4)),
                    const BoxShadow(color: Color(0x33000000), offset: Offset(0, 7), blurRadius: 6),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              if (badge)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A))),
        ],
      ),
    );
  }

  // แถบความคืบหน้ารวมของมอนสเตอร์ (นับจากด่านที่ผ่านแล้ว)
  Widget _overallProgress(int cleared) {
    final double v = (cleared / kMonsterLevels).clamp(0.0, 1.0).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ความคืบหน้าของมอนสเตอร์',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF4A2B3A)),
        ),
        const SizedBox(height: 4),
        FractionallySizedBox(
          widthFactor: 0.92,
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFB7A8D8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 3)],
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: v < 0.06 ? 0.06 : v,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6BE58A), Color(0xFF1FA84A)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectLevelBanner() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF6FB0), Color(0xFFE7388C)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(color: Color(0xFFBE185D), offset: Offset(0, 5)),
          BoxShadow(color: Color(0x33000000), offset: Offset(0, 9), blurRadius: 6),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withAlpha(90), width: 1.5),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'เลือกด่าน',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
              shadows: [Shadow(color: Color(0xFFBE185D), offset: Offset(0, 3))],
            ),
          ),
        ),
      ),
    );
  }

  Widget _backWideButton(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleBack(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5BE37A), Color(0xFF28A745)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFB8F5C6), width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0xFF166534), offset: Offset(0, 5)),
            BoxShadow(color: Color(0x33000000), offset: Offset(0, 9), blurRadius: 6),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ย้อนกลับ',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [Shadow(color: Color(0xFF166534), offset: Offset(0, 2))],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _GameScaffoldBody(
        title: 'สร้างมอนสเตอร์',
        color: const Color(0xFFE9478F),
        onBack: () => _handleBack(context),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFAD7E1), Color(0xFFF7C8D6)],
            ),
          ),
          child: AnimatedBuilder(
            animation: monsterProgress,
            builder: (context, _) {
              final int cleared = monsterProgress.stars.where((s) => s > 0).length;
              final double bottomInset = MediaQuery.of(context).padding.bottom;
              return Column(
                children: [
                  Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          // แถวบน: ความคืบหน้ารวม (กลาง) + เหรียญ (ขวา)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                            child: Row(
                              children: [
                                const SizedBox(width: 72),
                                Expanded(child: Center(child: _overallProgress(cleared))),
                                const _CoinPill(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: _selectLevelBanner()),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                              child: _levelGrid(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // แผงล่างสีชมพู: ปุ่มย้อนกลับ + DAILY / ACHIEVEMENTS / SETTINGS
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(36, 14, 36, 10 + bottomInset),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE594AC),
                      border: Border(top: BorderSide(color: Color(0xFFF4B6C8), width: 3)),
                      boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, -3))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _backWideButton(context),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _bottomIcon(
                              label: 'รายวัน',
                              icon: Icons.calendar_month_rounded,
                              colors: const [Color(0xFFFFB43A), Color(0xFFF08A0C)],
                              shadow: const Color(0xFFB45309),
                              badge: monsterProgress.canClaimDaily,
                              onTap: () => _openDaily(context),
                            ),
                            _bottomIcon(
                              label: 'ความสำเร็จ',
                              icon: Icons.emoji_events_rounded,
                              colors: const [Color(0xFFFF5FA8), Color(0xFFD9327F)],
                              shadow: const Color(0xFF9D174D),
                              onTap: () => _openAchievements(context),
                            ),
                            _bottomIcon(
                              label: 'ตั้งค่า',
                              icon: Icons.settings_rounded,
                              colors: const [Color(0xFF9B7BFF), Color(0xFF6D3FE0)],
                              shadow: const Color(0xFF4C1D95),
                              onTap: () => _openSettings(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// ลวดลายพื้นหลังการ์ดโลกในหน้าเลือกด่าน (วาดด้วยโค้ด ไม่ต้องใช้รูป)

// ==========================================
// หน้าต่างพรีวิวด่าน + ร้านไอเทม
// ==========================================
class _LevelPreviewSheet extends StatelessWidget {
  final int level;
  const _LevelPreviewSheet({required this.level});

  @override
  Widget build(BuildContext context) {
    final world = worldOf(level);
    final boss = isBossLevel(level);
    final cfg = kDifficultyConfigs[difficultyOfLevel(level)]!;
    final waves = wavesOfLevel(level);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: monsterProgress,
          builder: (context, _) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 12),
                  Text(
                    ' ด่าน $level${boss ? '  👑 บอส' : ''}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: boss ? const Color(0xFFDC2626) : const Color(0xFFDB2777)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final m in world.minions) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: MonsterAvatar(look: m.look, size: 56)),
                      if (boss) Padding(padding: const EdgeInsets.only(left: 6), child: MonsterAvatar(look: world.boss.look, size: 84)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      _chip('⚔️ $waves เลเวล'),
                      _chip(cfg.title.split(' ')[0]),
                      _chip('⏱️ ${cfg.timeLimit} วินาที / ข้อ'),
                    ],
                  ),
                  const Divider(height: 26),
                  Row(
                    children: [
                      const Expanded(child: Text('ไอเทมช่วยเล่น', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)))),
                      const _CoinPill(fontSize: 14),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final item in kPowerUps)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(item.emoji, style: const TextStyle(fontSize: 28)),
                      title: Text('${item.name}   x${monsterProgress.items[item.id] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(item.desc, style: const TextStyle(fontSize: 12)),
                      trailing: _GameButton(
                        color: const Color(0xFFF59E0B),
                        shadow: const Color(0xFFB45309),
                        radius: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        onPressed: monsterProgress.buying
                            ? null
                            : () async {
                                final error = await monsterProgress.buy(item);
                                if (error == null || !context.mounted) return;
                                showDialog<void>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    content: Text(error, textAlign: TextAlign.center),
                                    actionsAlignment: MainAxisAlignment.center,
                                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('ตกลง'))],
                                  ),
                                );
                              },
                        child: Text('${item.price} เหรียญ', style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _GameButton(
                      color: const Color(0xFF22C55E),
                      shadow: const Color(0xFF15803D),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        MonsterRound? resume = await MonsterResume.load(
                          level,
                          waves: wavesOfLevel(level),
                          maxHp: heroMaxHpOf(level),
                        );
                        if (resume != null) {
                          if (!context.mounted) return;
                          final bool? goOn = await _askMonsterResume(context, level, resume);
                          if (goOn == null) return;
                          if (!goOn) {
                            await MonsterResume.clear(level);
                            monsterProgress.markUnfinished(level, false);
                            resume = null;
                          }
                        }
                        final MonsterRound? start = resume;
                        nav.pop();
                        nav.push(MaterialPageRoute(builder: (_) => BattleScreen(level: level, resume: start)));
                      },
                      child: const Text('เริ่มเลย', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFFCE7F3), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF9D174D))),
    );
  }
}

// ==========================================
// หน้าจอหลักของเกมต่อสู้ (Battle Screen)
// ==========================================
// สีธีมหน้าต่อสู้ (กรอบไม้ / กระดาษ / ม่วงอ่อน)
class _BT {
  static const Color wood = Color(0xFF8A5A2B);
  static const Color woodDark = Color(0xFF5E3A1A);
  static const Color woodLight = Color(0xFFC89B5E);
  static const Color parchment = Color(0xFFF8EBCB);
  static const Color parchmentDark = Color(0xFFE6CE9C);
  static const Color ink = Color(0xFF4A2F1B);
  static const Color lilacTop = Color(0xFFE6D5EC);
  static const Color lilacBottom = Color(0xFFCDB3DA);
  static const Color mauve = Color(0xFF8E6B9A);
}

/// "ด่าน 9 เล่นค้างไว้ … เล่นต่อ / เริ่มใหม่": true = go on, false = start again.
Future<bool?> _askMonsterResume(BuildContext context, int level, MonsterRound r) {
  const Color color = Color(0xFFDB2777);
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('ด่าน $level เล่นค้างไว้', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: color)),
      content: Text(
        'ถึงเลเวล ${r.wave} / ${wavesOfLevel(level)} เลือดเหลือ ${r.heroHp} / ${heroMaxHpOf(level)}\nจะเล่นต่อเลยไหม ?',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('เริ่มใหม่')),
        _GameButton(
          color: const Color(0xFF22C55E),
          shadow: const Color(0xFF15803D),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('เล่นต่อ'),
        ),
      ],
    ),
  );
}

class BattleScreen extends StatefulWidget {
  final int level;

  /// The level left in the middle, to continue (null = start it fresh).
  final MonsterRound? resume;

  const BattleScreen({
    super.key,
    required this.level,
    this.resume,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _paused = false; // stopped while the app is away / the leave question is open
  bool _askingLeave = false; // "ออกจากด่าน ?" is on screen
  int _dialogs = 0; // result dialogs open (the battle is waiting anyway)
  final List<Future<GuessCoinResult>> _coinFutures = []; // real coins of this level
  int _coinsBefore = 0; // coins of this level earned before "เล่นต่อ"
  int _coinsNow = 0; // coins earned since the level was opened
  double _ui = 1.0; // size of the word card and answer buttons (bigger on tall screens)
  double get _gap => 8 * _ui; // one even gap between every part of the answer area

  late DifficultyConfig _diffConfig;

  final FlutterTts _flutterTts = FlutterTts();
  bool _suddenMusicOn = false; // ช่วงตัดสินเริ่มแล้ว

  String heroName = 'ฮีโร่'; // replaced by the account's name
  int heroMaxHp = 100;
  int heroCurrentHp = 100;
  int heroBaseAtk = 25;

  int currentStage = 1; // เวฟปัจจุบันในด่านนี้
  final Set<String> _hiddenChoices = {}; // ถูกตัดด้วย 50:50
  final Set<String> _triedWrong = {}; // เลือกผิดไปแล้ว (โหมดง่ายมีโอกาสลองใหม่)

  DifficultyLevel get _difficulty => difficultyOfLevel(widget.level);
  WorldTheme get _world => worldOf(widget.level);
  int get _totalWaves => wavesOfLevel(widget.level);
  bool get _isBossWave => isBossLevel(widget.level) && currentStage == _totalWaves;
  int get _monsterAtkNow => (currentMonster.atk * (_bossEnraged ? 1.5 : 1.0)).round();
  late Monster currentMonster;
  late VocabQuestion currentQuestion;

  final List<int> _usedQuestionIndices = [];

  // ---------- ระบบดวลความเร็ว (Speed Duel) ----------
  static const double _tickSec = 0.05;
  static const double _graceSec = 0.4; // ช่วงเสี้ยววินาทีที่ตอบพร้อมกันแล้วเกิด CLASH
  static const int _tugMax = 3;
  final math.Random _rnd = math.Random();
  Timer? _ticker;
  Timer? _readyTimer;
  Timer? _nextRoundTimer;
  Timer? _clashTimer;
  Timer? _moodTimer;
  final ValueNotifier<int> _tickN = ValueNotifier<int>(0);

  _Phase _phase = _Phase.ready;
  double _elapsed = 0; // เวลาที่ผู้เรียนใช้ไปในรอบนี้
  double _mClock = 0; // เวลาที่มอนสเตอร์คิดไปแล้ว
  double _limitSec = 15;
  double _monsterTime = 4; // มอนสเตอร์จะตอบเมื่อ _mClock ถึงค่านี้
  bool _monsterWillBeWrong = false;
  bool _monsterStunned = false; // มอนสเตอร์ตอบผิดเอง -> งงไปทั้งรอบ
  double _graceLeft = 0;
  double _freezeLeft = 0;
  bool _smokeUsed = false;
  bool _shield = false;
  bool _isSudden = false;
  int _tug = 0; // -3 (เราโดนดัน) .. +3 (ผลักมอนสเตอร์ตกเหว)
  int _retryLeft = 0;
  int _roundOfMonster = 0;
  int _spawnSeq = 0;
  bool _bonusRound = false;
  bool _trickDone = false;
  double _trickAt = 2;
  String? _fogChoice;
  double _fogUntil = 0;
  MonsterMood? _moodOverride;
  String? _bubble;
  String? _pendingCorrect;
  // Clash
  String _clashTarget = '';
  List<String> _clashLetters = [];
  final Set<String> _clashWrong = {};
  int _clashDurMs = 2000;

  bool get _answerLocked => _phase == _Phase.resolved;
  bool get _canAct => _phase == _Phase.racing || _phase == _Phase.grace;

  late int timeLeft;
  int _timeTotal = 15;

  String combatLog = "การประลองเริ่มต้นขึ้นแล้ว !";
  Color logColor = const Color(0xFFDB2777);

  int comboStreak = 0;
  int maxCombo = 0;

  final List<_FloatingText> _floatingTexts = [];
  int _floatingTextSeq = 0;

  String? _selectedAnswer;

  late AnimationController _shakeController;
  late AnimationController _idleController;
  late AnimationController _hitController; // มอนสเตอร์สั่นเมื่อโดนตี

  bool _bossEnraged = false; // บอสโกรธเมื่อ HP เหลือครึ่งเดียว
  String? _lastDrop; // ไอเทมที่ดรอปจากมอนสเตอร์ตัวล่าสุด

  late AnimationController _heroLunge; // ฮีโร่พุ่งเข้าโจมตี
  late AnimationController _monsterLunge; // มอนสเตอร์พุ่งเข้าโจมตี
  int _questionSeq = 0;
  int _correctCount = 0;
  final List<Map<String, String>> _missed = []; // คำที่ตอบพลาด ไว้ทบทวน

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHeroName();
    _diffConfig = kDifficultyConfigs[difficultyOfLevel(widget.level)]!;
    heroMaxHp = heroMaxHpOf(widget.level);
    heroCurrentHp = heroMaxHp;
    heroBaseAtk = 25 + (widget.level - 1) * 2;
    timeLeft = _diffConfig.timeLimit;
    _limitSec = _diffConfig.timeLimit.toDouble();

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _idleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _hitController = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _heroLunge = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _monsterLunge = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

    _initTts();

    AvatarProfile.instance.addListener(_onAvatarChanged);
    AvatarProfile.instance.load();

    final MonsterRound? resume = widget.resume;
    if (resume != null) {
      // Go on from the next monster, with the HP the hero had.
      currentStage = resume.wave.clamp(1, _totalWaves).toInt();
      heroCurrentHp = resume.heroHp.clamp(1, heroMaxHp).toInt();
      _correctCount = resume.correct;
      _coinsBefore = resume.coins;
    } else {
      _clearResume(); // a new game of this level
    }

    _spawnMonster();
    _startRound();
  }

  // ---------- เล่นต่อจากมอนสเตอร์ตัวถัดไป (แยกตามบัญชี เก็บบนเซิร์ฟเวอร์) ----------

  /// Saved after each monster (not the last one): leaving now, the child
  /// comes back to the next monster with the same HP.
  void _saveResume() {
    final int next = currentStage + 1;
    if (next > _totalWaves) return;
    MonsterResume.save(
      widget.level,
      MonsterRound(
        wave: next,
        heroHp: math.min(heroMaxHp, heroCurrentHp + 20).clamp(1, heroMaxHp).toInt(),
        correct: _correctCount,
        coins: math.min(_coinsBefore + _coinsNow, _correctCount * 3),
      ),
    );
    monsterProgress.markUnfinished(widget.level, true);
  }

  void _clearResume() {
    MonsterResume.clear(widget.level);
    monsterProgress.markUnfinished(widget.level, false);
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speakWord(String word) async {
    if (word.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.speak(word);
    }
  }



  void _onAvatarChanged() {
    if (mounted) setState(() {});
  }

  void _addFloatingText(String text, Color color, {required bool onRight, bool center = false, double size = 22}) {
    final id = _floatingTextSeq++;
    setState(() {
      _floatingTexts.add(_FloatingText(id: id, text: text, color: color, onRight: onRight, center: center, size: size));
    });
  }

  void _removeFloatingText(int id) {
    if (!mounted) return;
    setState(() {
      _floatingTexts.removeWhere((f) => f.id == id);
    });
  }

  OutfitItem get _heroOutfit {
    final AvatarProfile p = AvatarProfile.instance;
    final List<OutfitItem> outfits = p.gender == 'male' ? kMaleOutfits : kFemaleOutfits;
    final int idx = p.outfitIndex < outfits.length ? p.outfitIndex : 0;
    return outfits[idx];
  }

  Color get _heroSkinColor =>
      kSkinTones[AvatarProfile.instance.skinIndex.clamp(0, kSkinTones.length - 1).toInt()];

  Color get _heroHairColor =>
      kHairColors[AvatarProfile.instance.hairColorIndex.clamp(0, kHairColors.length - 1).toInt()];

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelRoundTimers();
    _moodTimer?.cancel();
    _tickN.dispose();
    _shakeController.dispose();
    _idleController.dispose();
    _hitController.dispose();
    _heroLunge.dispose();
    _monsterLunge.dispose();
    _flutterTts.stop();
    AvatarProfile.instance.removeListener(_onAvatarChanged);
    super.dispose();
  }

  void _spawnMonster() {
    final world = _world;
    final bool boss = _isBossWave;
    final int idx = (currentStage - 1) % world.minions.length;
    final MonsterTemplate tpl = boss ? world.boss : world.minions[idx];
    final double scale = 1 + (widget.level - 1) * 0.06;

    final int baseHp = boss ? 130 : 60 + 30 * idx;
    final int baseAtk = boss ? 20 : 10 + 5 * idx;

    final int maxHp = (baseHp * scale * (boss ? 2.0 : 1.0)).round();
    final int atk = (baseAtk * scale * (boss ? 1.3 : 1.0) * _diffConfig.monsterAtkMultiplier).round();

    // เวฟแรกเจอสายสปีด (ง่ายสุด) -> สายแม่นยำ -> สายก่อกวน, บอสเป็นสายคลั่งเสมอ
    const List<MonsterAI> order = [MonsterAI.speedy, MonsterAI.smart, MonsterAI.trickster];
    final MonsterAI ai = boss ? MonsterAI.berserker : order[idx % order.length];
    final MonsterAIProfile prof = kMonsterAI[ai]!;

    _bossEnraged = false;
    _isSudden = false;
    _roundOfMonster = 0;
    _spawnSeq++;
    _moodOverride = null;
    _bubble = null;
    _stopSuddenMusic();
    setState(() {
      currentMonster = Monster(
        name: boss ? '👑 ${tpl.name}' : tpl.name,
        look: tpl.look,
        ai: ai,
        maxHp: maxHp,
        currentHp: maxHp,
        atk: atk,
      );
      combatLog = boss
          ? 'บอส ${tpl.name} ท้าดวล ${prof.tip}'
          : '${tpl.name} ${prof.label} ท้าดวลความเร็ว ${prof.tip}';
      logColor = boss ? const Color(0xFFDC2626) : const Color(0xFFDB2777);
    });
    if (boss) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
    }
  }

  // ---------- ตัวช่วยจัดการ Timer / เสียง ----------
  void _cancelRoundTimers() {
    _ticker?.cancel();
    _readyTimer?.cancel();
    _nextRoundTimer?.cancel();
    _clashTimer?.cancel();
  }

  void _resetDuelState() {
    _cancelRoundTimers();
    _moodTimer?.cancel();
    _stopSuddenMusic();
    _tug = 0;
    _shield = false;
    _isSudden = false;
    _moodOverride = null;
    _bubble = null;
  }

  void _startSuddenMusic() {
    _suddenMusicOn = true;
  }

  void _stopSuddenMusic() {
    if (!_suddenMusicOn) return;
    _suddenMusicOn = false;
  }

  void _setMonsterMood(MonsterMood mood, {String? bubble, int ms = 1300}) {
    _moodTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _moodOverride = mood;
      _bubble = bubble;
    });
    _moodTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() {
        _moodOverride = _monsterStunned ? MonsterMood.shocked : null;
        _bubble = null;
      });
    });
  }

  // ---------- วางแผนการตอบของ AI ----------
  void _planMonster() {
    final MonsterAIProfile p = kMonsterAI[currentMonster.ai]!;
    double base = p.minSec + _rnd.nextDouble() * (p.maxSec - p.minSec);
    // เด็กต้องฟังเสียง + อ่านโจทย์ -> ระดับง่ายมอนสเตอร์คิดช้าลงเยอะ
    final double diffScale = _difficulty == DifficultyLevel.easy
        ? 2.4
        : (_difficulty == DifficultyLevel.medium ? 1.6 : 1.0);
    base *= diffScale;
    if (currentMonster.ai == MonsterAI.berserker) {
      final double lost = 1 - currentMonster.currentHp / currentMonster.maxHp;
      base *= (1 - 0.5 * lost); // ยิ่ง HP ต่ำ ยิ่งคิดไว
    }
    if (_isSudden) base *= 0.75;
    _monsterTime = base.clamp(0.8, _limitSec * 0.85).toDouble();
    final double wrong = p.wrongChance + (_difficulty == DifficultyLevel.easy ? 0.10 : 0.0);
    _monsterWillBeWrong = _rnd.nextDouble() < wrong;
  }

  // ---------- เริ่มรอบใหม่: โจทย์ขึ้นพร้อมกันทั้งสองฝั่ง ----------
  void _startRound() {
    _cancelRoundTimers();
    final currentBank = categoryVocabBank[_difficulty] ?? categoryVocabBank[DifficultyLevel.easy]!;

    if (_usedQuestionIndices.length >= currentBank.length) {
      _usedQuestionIndices.clear();
    }
    int randomIndex;
    do {
      randomIndex = _rnd.nextInt(currentBank.length);
    } while (_usedQuestionIndices.contains(randomIndex));
    _usedQuestionIndices.add(randomIndex);

    final item = currentBank[randomIndex];
    final String word = item['word'];
    final String correct = item['correct'];
    final String cat = item['cat'];
    final List<String> wrongs = List<String>.from(item['wrongs']);
    final List<String> choices = [correct, ...wrongs]..shuffle();

    // Sudden Death: เมื่อมอนสเตอร์เหลือ HP 10% เวลาตอบจะสั้นลงมาก
    final bool sudden = currentMonster.currentHp > 0 && currentMonster.currentHp <= currentMonster.maxHp * 0.10;
    final double limit = sudden ? math.max(3.0, _diffConfig.timeLimit * 0.5) : _diffConfig.timeLimit.toDouble();
    final bool firstSudden = sudden && !_suddenMusicOn;
    final bool bonus = !sudden && _roundOfMonster > 0 && _rnd.nextDouble() < 0.12; // รอบโบนัส ⭐

    setState(() {
      _isSudden = sudden;
      _bonusRound = bonus;
      _limitSec = limit;
      _timeTotal = limit.round();
      timeLeft = limit.round();
      _elapsed = 0;
      _mClock = 0;
      _graceLeft = 0;
      _freezeLeft = 0;
      _smokeUsed = false;
      _monsterStunned = false;
      _trickDone = false;
      _trickAt = 1.0 + _rnd.nextDouble() * 1.5;
      _fogChoice = null;
      _retryLeft = _difficulty == DifficultyLevel.easy ? 1 : 0; // โหมดง่าย: ตอบผิดครั้งแรกลองใหม่ได้
      _phase = _Phase.ready;
      _selectedAnswer = null;
      _pendingCorrect = null;
      _hiddenChoices.clear();
      _triedWrong.clear();
      _clashWrong.clear();
      _questionSeq++;
      _moodOverride = null;
      _bubble = null;
      currentQuestion = VocabQuestion(word: word, correctMeaning: correct, choices: choices, category: cat);
      _planMonster();
      if (sudden) {
        combatLog = 'ช่วงตัดสิน เหลือเวลาแค่ ${limit.round()} วินาที ตั้งสติแล้วลุย';
        logColor = const Color(0xFFDC2626);
      } else if (_roundOfMonster > 0) {
        combatLog = 'แข่งกันตอบ ใครไวกว่าได้โจมตีก่อน';
        logColor = const Color(0xFFDB2777);
      }
    });
    _roundOfMonster++;

    if (firstSudden) _startSuddenMusic();
    _speakWord(word);
    _addFloatingText(sudden ? 'ช่วงตัดสิน' : (bonus ? 'โบนัส x2' : 'พร้อมไหม ?'),
        sudden ? const Color(0xFFDC2626) : (bonus ? const Color(0xFFD97706) : const Color(0xFFDB2777)),
        onRight: true, center: true, size: 26);
    _readyTimer = Timer(const Duration(milliseconds: 1000), _beginRace);
  }

  void _beginRace() {
    if (!mounted) return;
    setState(() => _phase = _Phase.racing);
    _addFloatingText('ลุย !', const Color(0xFF16A34A), onRight: true, center: true, size: 32);
    _ticker?.cancel();
    _ticker = Timer.periodic(Duration(milliseconds: (_tickSec * 1000).round()), (_) => _onTick());
  }

  void _onTick() {
    if (!mounted) return;
    if (_phase != _Phase.racing && _phase != _Phase.grace) return;

    _elapsed += _tickSec;
    final int left = math.max(0, (_limitSec - _elapsed).ceil());
    if (left != timeLeft) setState(() => timeLeft = left);
    if (_fogChoice != null && _elapsed >= _fogUntil) setState(() => _fogChoice = null);

    if (_phase == _Phase.grace) {
      _graceLeft -= _tickSec;
      _tickN.value++;
      if (_graceLeft <= 0) _monsterWinsRound(why: 'monster');
      return;
    }

    // เฟส racing
    if (_freezeLeft > 0) {
      _freezeLeft = math.max(0.0, _freezeLeft - _tickSec);
    } else if (!_monsterStunned) {
      _mClock += _tickSec;
    }
    if (!_trickDone && currentMonster.ai == MonsterAI.trickster && !_monsterStunned && _elapsed >= _trickAt) {
      _castTrick();
    }
    _tickN.value++;

    if (!_monsterStunned && _mClock >= _monsterTime) {
      _monsterFinished();
    } else if (_elapsed >= _limitSec) {
      _onTimeOut();
    }
  }

  // Trickster: บังปุ่มด้วยหมอก หรือสลับตำแหน่งปุ่ม
  void _castTrick() {
    _trickDone = true;
    final List<String> visible = currentQuestion.choices
        .where((c) => !_hiddenChoices.contains(c) && !_triedWrong.contains(c))
        .toList();
    if (_rnd.nextBool() && visible.length > 1) {
      final String pick = visible[_rnd.nextInt(visible.length)];
      setState(() {
        _fogChoice = pick;
        _fogUntil = _elapsed + 2.0;
        combatLog = '${currentMonster.name} ปล่อยหมอกบังปุ่ม รออีกนิดนะ';
        logColor = const Color(0xFF7C3AED);
      });
    } else {
      setState(() {
        currentQuestion.choices.shuffle(_rnd);
        combatLog = '${currentMonster.name} สลับตำแหน่งปุ่ม อ่านให้ดีก่อนกดนะ';
        logColor = const Color(0xFF7C3AED);
      });
    }
    _setMonsterMood(MonsterMood.laugh, bubble: 'ฮิฮิ ลองดูสิ');
  }

  // แถบความคิดของมอนสเตอร์เต็มแล้ว
  void _monsterFinished() {
    if (_monsterWillBeWrong) {
      // มอนสเตอร์ตอบผิดเอง -> งง ผู้เรียนยังตอบต่อได้
      setState(() {
        _monsterStunned = true;
        _moodOverride = MonsterMood.shocked;
        _bubble = 'ตอบผิดซะแล้ว';
        combatLog = '${currentMonster.name} ตอบผิดเอง รีบตอบเลย';
        logColor = const Color(0xFF16A34A);
      });
    } else {
      // ตอบถูก -> เปิดช่วง Clash 0.4 วินาที ถ้าผู้เรียนตอบถูกทันจะเกิดการปะทะ
      setState(() {
        _phase = _Phase.grace;
        _graceLeft = _graceSec;
        combatLog = '${currentMonster.name} กำลังจะตอบ รีบเลย';
        logColor = const Color(0xFFDC2626);
      });
    }
  }

  void _onTimeOut() {
    _ticker?.cancel();
    if (_monsterStunned || _monsterWillBeWrong) {
      _drawRound();
    } else {
      _monsterWinsRound(why: 'timeout');
    }
  }

  // ไม่มีใครตอบได้ทัน -> เสมอ ไม่เสียเลือดใคร
  void _drawRound() {
    _ticker?.cancel();
    _noteLearning(correct: false);
    setState(() {
      _phase = _Phase.resolved;
      combatLog = 'หมดเวลา ไม่มีใครตอบได้ (คำตอบ : ${currentQuestion.correctMeaning})';
      logColor = const Color(0xFF64748B);
    });
    _checkBattleStatus();
  }

  // ---------- ผู้เรียนกดตอบ ----------
  void _answerQuestion(String selected) {
    if (!_canAct) return;
    if (_triedWrong.contains(selected) || _hiddenChoices.contains(selected)) return;
    if (_fogChoice == selected) return;

    if (selected == currentQuestion.correctMeaning) {
      if (_phase == _Phase.grace) {
        _pendingCorrect = selected;
        _startClash();
      } else {
        _heroWinsRound(selected);
      }
      return;
    }

    // ตอบผิด
    if (_retryLeft > 0) {
      _retryLeft--;
      HapticFeedback.lightImpact();
      setState(() {
        _triedWrong.add(selected);
        combatLog = 'ยังไม่ใช่นะ ลองอีกครั้ง รีบก่อนมอนสเตอร์ตอบ';
        logColor = const Color(0xFFF59E0B);
      });
      return;
    }
    _monsterWinsRound(why: 'wrong', selected: selected);
  }

  // ---------- ผู้เรียนตอบถูกก่อน -> โจมตีมอนสเตอร์ ----------
  void _heroWinsRound(String selected, {bool clash = false}) {
    _ticker?.cancel();
    _clashTimer?.cancel();
    _noteLearning(correct: true);
    // Real coins: 3 per word per day (from the server).
    final coinFuture = MonsterCoins.submit(currentQuestion.word);
    _coinFutures.add(coinFuture);
    coinFuture.then((r) {
      _coinsNow += r.coins;
      if (mounted && r.coins > 0) {
        _addFloatingText('+${r.coins} เหรียญ', const Color(0xFFB45309), onRight: false, size: 16);
      }
    });
    _heroLunge.forward(from: 0.0);
    HapticFeedback.mediumImpact();

    final double t = _elapsed;
    final double critSec = _difficulty == DifficultyLevel.easy ? 4.0 : (_difficulty == DifficultyLevel.medium ? 2.5 : 1.5);
    double multiplier = 1.0;
    bool isCrit = false;
    if (t <= critSec) {
      multiplier = 2.0;
      isCrit = true;
    } else if (t <= _limitSec * 0.4) {
      multiplier = 1.4;
    }
    if (clash && multiplier < 1.4) multiplier = 1.4;

    comboStreak++;
    if (comboStreak > maxCombo) maxCombo = comboStreak;
    final double comboBonus = 1 + (comboStreak * 0.05).clamp(0.0, 0.5);
    final bool isUltimate = comboStreak % 5 == 0;
    int damage = (heroBaseAtk * multiplier * comboBonus * (isUltimate ? 2.5 : 1.0)).round();
    if (_bonusRound) {
      damage *= 2; // รอบโบนัส: ดาเมจ x2
    }

    // Tug-of-War: ชนะติดๆ จนแถบถึงขอบ -> ผลักมอนสเตอร์ตกเหว (โบนัสดาเมจ)
    _tug = math.min(_tugMax, _tug + 1);
    final bool pushed = _tug >= _tugMax;
    if (pushed) {
      damage += (currentMonster.maxHp * 0.2).round();
      Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _tug = 0);
      });
    }

    final bool stolen = !clash && !_monsterStunned;
    final Color dmgColor = isUltimate
        ? const Color(0xFF7C3AED)
        : (pushed ? const Color(0xFFDC2626) : (isCrit ? const Color(0xFFF59E0B) : const Color(0xFFDB2777)));
    _addFloatingText('-$damage', dmgColor, onRight: true);
    _hitController.forward(from: 0.0);
    _addFloatingText('${t.toStringAsFixed(1)} วิ', const Color(0xFF0EA5E9), onRight: false, size: 18);
    if (_bonusRound) _addFloatingText('โบนัส x2', const Color(0xFFD97706), onRight: false, size: 16);
    if (isUltimate || pushed) _shakeController.forward(from: 0.0);
    final String praise = pushed
        ? 'ผลักตกเหว'
        : (clash
            ? 'ชนะปะทะ'
            : (isUltimate ? 'สุดยอด' : (isCrit ? 'เยี่ยมมาก' : (multiplier > 1 ? 'เก่งมาก' : 'ดี'))));
    _addFloatingText(praise, isUltimate ? const Color(0xFF7C3AED) : const Color(0xFFF59E0B),
        onRight: true, center: true, size: 26);

    int healed = 0;
    bool justEnraged = false;
    bool enteredSudden = false;

    setState(() {
      _phase = _Phase.resolved;
      _selectedAnswer = selected;
      currentMonster.currentHp = math.max(0, currentMonster.currentHp - damage);

      if (_isBossWave && !_bossEnraged && currentMonster.currentHp > 0 && currentMonster.currentHp <= currentMonster.maxHp / 2) {
        _bossEnraged = true;
        justEnraged = true;
      }
      if (!_isSudden && currentMonster.currentHp > 0 && currentMonster.currentHp <= currentMonster.maxHp * 0.10) {
        enteredSudden = true;
      }
      if (isUltimate) {
        final int before = heroCurrentHp;
        heroCurrentHp = math.min(heroMaxHp, heroCurrentHp + 15);
        healed = heroCurrentHp - before;
      }

      final String stunNote = _monsterStunned ? ' (มอนสเตอร์พลาดเอง)' : '';
      if (enteredSudden) {
        combatLog = 'ช่วงตัดสิน ${currentMonster.name} เหลือเลือดนิดเดียว รอบหน้าเวลาสั้นลงนะ';
        logColor = const Color(0xFFDC2626);
      } else if (justEnraged) {
        combatLog = '${currentMonster.name} โกรธจัด พลังโจมตีเพิ่มขึ้น 1.5 เท่า ระวังให้ดี';
        logColor = const Color(0xFFDC2626);
      } else if (pushed) {
        combatLog = '$heroName ผลักมอนสเตอร์ตกเหว โบนัสดาเมจ รวม $damage';
        logColor = const Color(0xFFDC2626);
      } else if (clash) {
        combatLog = '$heroName แตะไวกว่าในการปะทะ ทำดาเมจ $damage';
        logColor = const Color(0xFF7C3AED);
      } else if (isUltimate) {
        combatLog = 'ท่าไม้ตาย คอมโบ x$comboStreak ทำดาเมจ $damage และฟื้นเลือด';
        logColor = const Color(0xFF7C3AED);
      } else if (comboStreak >= 3) {
        combatLog = 'คอมโบ x$comboStreak ตอบไวกว่า ${currentMonster.name} ทำดาเมจ $damage $stunNote';
        logColor = const Color(0xFFEA580C);
      } else if (isCrit) {
        combatLog = 'คริติคอล ! ตอบไวมาก $heroName ทำดาเมจ $damage $stunNote';
        logColor = const Color(0xFFBE185D);
      } else {
        combatLog = 'ตอบก่อน $heroName โจมตี ${currentMonster.name} $damage ดาเมจ $stunNote';
        logColor = const Color(0xFFDB2777);
      }
    });

    if (healed > 0) _addFloatingText('+$healed', const Color(0xFF16A34A), onRight: false);
    if (currentMonster.currentHp > 0 && stolen) {
      _setMonsterMood(MonsterMood.shocked, bubble: const ['ว้าย โดนแย่งตอบ', 'เร็วจัง', 'อ๊ะ ไม่ทันเลย'][math.Random().nextInt(3)]);
    }
    _checkBattleStatus();
  }

  // ---------- มอนสเตอร์ชนะรอบนี้ -> โจมตีผู้เรียนฟรี ----------
  void _monsterWinsRound({required String why, String? selected}) {
    _ticker?.cancel();
    _clashTimer?.cancel();
    _noteLearning(correct: false);
    _monsterLunge.forward(from: 0.0);
    _shakeController.forward(from: 0.0);

    _tug = math.max(-_tugMax, _tug - 1);
    int dmg = _monsterAtkNow;
    bool blocked = false;
    if (_shield) {
      _shield = false;
      blocked = true;
      dmg = 0;
    }
    if (blocked) {
      _addFloatingText('กันได้', const Color(0xFFDB2777), onRight: false);
    } else {
      _addFloatingText('-$dmg', const Color(0xFFDC2626), onRight: false);
    }
    final String ans = currentQuestion.correctMeaning;

    setState(() {
      _phase = _Phase.resolved;
      _selectedAnswer = selected;
      comboStreak = 0;
      heroCurrentHp = math.max(0, heroCurrentHp - dmg);
      if (blocked) {
        combatLog = 'โล่ช่วยไว้ ไม่เสียเลือด (คำตอบ : $ans)';
        logColor = const Color(0xFFDB2777);
      } else if (why == 'wrong') {
        combatLog = 'ตอบผิด ${currentMonster.name} ฉวยโอกาสโจมตี $dmg ดาเมจ (คำตอบ : $ans)';
        logColor = const Color(0xFFDC2626);
      } else if (why == 'timeout') {
        combatLog = 'หมดเวลา ${currentMonster.name} โจมตี $dmg ดาเมจ (คำตอบ : $ans)';
        logColor = const Color(0xFFDC2626);
      } else if (why == 'clash') {
        combatLog = 'ปะทะแพ้ไปนิดเดียว ${currentMonster.name} โจมตี $dmg ดาเมจ (คำตอบ : $ans)';
        logColor = const Color(0xFFDC2626);
      } else {
        combatLog = '${currentMonster.name} ตอบได้ก่อน โจมตี $dmg ดาเมจ (คำตอบ : $ans)';
        logColor = const Color(0xFFDC2626);
      }
    });
    _setMonsterMood(MonsterMood.laugh, bubble: blocked ? 'อ๊ะ มีโล่' : const ['ฮิฮิ ฉันไวกว่า', 'ช้าจัง~', 'เย้ ฉันชนะรอบนี้'][_rnd.nextInt(3)]);
    _checkBattleStatus();
  }

  // ---------- CLASH: ตอบถูกพร้อมกัน -> แย่งแตะตัวอักษรแรกของคำ ----------
  void _startClash() {
    _ticker?.cancel();
    HapticFeedback.heavyImpact();
    final String target = currentQuestion.word.trim().substring(0, 1).toUpperCase();
    const String abc = 'ABCDEFGHIJKLMNOPRSTW';
    final Set<String> letters = {target};
    while (letters.length < 3) {
      letters.add(abc[_rnd.nextInt(abc.length)]);
    }
    final List<String> list = letters.toList()..shuffle(_rnd);
    final double mult = _difficulty == DifficultyLevel.easy ? 1.7 : (_difficulty == DifficultyLevel.medium ? 1.3 : 1.0);
    final double qte = (1.3 + _rnd.nextDouble() * 0.8) * mult;
    setState(() {
      _phase = _Phase.clash;
      _clashTarget = target;
      _clashLetters = list;
      _clashWrong.clear();
      _clashDurMs = (qte * 1000).round();
      combatLog = 'ปะทะ ! ตอบถูกพร้อมกัน ! แย่งแตะให้ไวที่สุด !';
      logColor = const Color(0xFF7C3AED);
    });
    _clashTimer = Timer(Duration(milliseconds: _clashDurMs), () {
      if (mounted && _phase == _Phase.clash) _monsterWinsRound(why: 'clash');
    });
  }

  void _clashTap(String letter) {
    if (_phase != _Phase.clash) return;
    if (letter == _clashTarget) {
      _clashTimer?.cancel();
      _heroWinsRound(_pendingCorrect ?? currentQuestion.correctMeaning, clash: true);
    } else {
      HapticFeedback.lightImpact();
      setState(() => _clashWrong.add(letter));
    }
  }

  // ---------- ไอเทมช่วยเล่น ----------
  void _useHint() {
    if (!_canAct || _hiddenChoices.isNotEmpty) return;
    if (!monsterProgress.useItem('hint')) return;
    final wrongs = currentQuestion.choices
        .where((c) => c != currentQuestion.correctMeaning && !_triedWrong.contains(c))
        .toList()
      ..shuffle();
    setState(() {
      _hiddenChoices.addAll(wrongs.take(2));
      combatLog = 'ตัดตัวเลือกที่ผิดออกแล้ว ตอบให้ไวเลย';
      logColor = const Color(0xFFCA8A04);
    });
  }

  void _useFreeze() {
    if (!_canAct || _freezeLeft > 0 || _monsterStunned) return;
    if (!monsterProgress.useItem('freeze')) return;
    setState(() {
      _freezeLeft = 3.0;
      combatLog = 'หยุดเวลา มอนสเตอร์หยุดคิด 3 วินาที';
      logColor = const Color(0xFFBE185D);
    });
  }

  void _useSmoke() {
    if (!_canAct || _smokeUsed || _monsterStunned) return;
    if (!monsterProgress.useItem('smoke')) return;
    setState(() {
      _smokeUsed = true;
      _monsterTime = math.min(_monsterTime + 2.0, _limitSec - 0.3);
      combatLog = 'ระเบิดควัน ${currentMonster.name} ลังเล ตอบช้าลง 2 วินาที';
      logColor = const Color(0xFF64748B);
    });
    _setMonsterMood(MonsterMood.thinking, bubble: 'แค่ก ๆ มองไม่เห็น');
  }

  void _useShield() {
    if (!_canAct || _shield) return;
    if (!monsterProgress.useItem('shield')) return;
    setState(() {
      _shield = true;
      combatLog = 'เปิดโล่แล้ว ถ้าโดนแย่งตอบ โล่จะรับดาเมจให้ 1 ครั้ง';
      logColor = const Color(0xFFDB2777);
    });
  }

  Widget _powerUpButton(String id, String emoji, VoidCallback onTap, {bool active = false, double size = 46}) {
    final int count = monsterProgress.items[id] ?? 0;
    final bool enabled = count > 0 && _canAct;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled || active ? 1 : 0.5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: active ? const [Color(0xFFFFE9A8), Color(0xFFE0A63C)] : const [Color(0xFFE6B27A), Color(0xFF8B5A2B)],
                ),
                border: Border.all(color: active ? const Color(0xFFFFD54A) : _BT.woodDark, width: 2.5),
                boxShadow: [
                  const BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2)),
                  if (active) BoxShadow(color: const Color(0xFFFFD54A).withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
            ),
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B3A1F),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFE8C48A), width: 1.5),
                ),
                child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkBattleStatus() {
    _ticker?.cancel();
    if (currentMonster.currentHp <= 0) {
      _stopSuddenMusic();
      _nextRoundTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) _onDefeatMonster();
      });
    } else if (heroCurrentHp <= 0) {
      _stopSuddenMusic();
      _nextRoundTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) _showGameOverDialog();
      });
    } else {
      _nextRoundTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted && heroCurrentHp > 0 && currentMonster.currentHp > 0) _startRound();
      });
    }
  }

  void _onDefeatMonster() {
    // ไอเทมดรอป: มอนสเตอร์ทั่วไป 35% / บอสดรอปแน่นอน
    _lastDrop = null;
    final math.Random dropRnd = math.Random();
    if (_isBossWave || dropRnd.nextDouble() < 0.35) {
      const List<String> dropIds = ['hint', 'freeze', 'smoke', 'shield'];
      final String dropId = dropIds[dropRnd.nextInt(dropIds.length)];
      monsterProgress.addItem(dropId);
      _lastDrop = dropId;
    }

    monsterProgress.recordKill(boss: _isBossWave);
    monsterProgress.noteCombo(maxCombo);

    if (currentStage >= _totalWaves) {
      _onLevelCleared();
    } else {
      _saveResume();
      _showWaveDialog();
    }
  }

  Widget _dropChip() {
    final PowerUpInfo info = kPowerUps.firstWhere((p) => p.id == _lastDrop);
    return Chip(
      avatar: Text(info.emoji),
      label: Text('ดรอป ${info.name}', style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFFDCFCE7),
      side: BorderSide.none,
    );
  }

  Widget _rewardChips() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_lastDrop != null) _dropChip(),
      ],
    );
  }

  // dialog ที่ปุ่ม Back ของเครื่องปิดไม่ได้ (กันเกมค้าง/ตอบข้อเดิมซ้ำ)
  Future<void> _showLockedDialog(WidgetBuilder builder) async {
    _dialogs++;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(canPop: false, child: builder(ctx)),
      );
    } finally {
      _dialogs--;
    }
  }

  /// The hero is the child: shows the account's name (saved one first,
  /// then the latest from the server).
  Future<void> _loadHeroName() async {
    final saved = await AccountName.cached();
    if (saved != null && mounted) setState(() => heroName = saved);
    final latest = await AccountName.refresh();
    if (latest != null && latest.trim().isNotEmpty && mounted) {
      setState(() => heroName = latest.trim());
    }
  }

  // ---------- หยุดเกมชั่วคราว (สลับแอป / ถามก่อนออก) ----------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeBattle();
    } else {
      _pauseBattle();
    }
  }

  /// Stops the clock: the monster doesn't answer while the child is away.
  void _pauseBattle() {
    if (_paused || _dialogs > 0) return;
    _paused = true;
    _cancelRoundTimers();
    // No answering (or clash tapping) while stopped: the round is dropped
    // and a new question comes when the game goes on.
    if (mounted) setState(() => _phase = _Phase.resolved);
  }

  /// Goes on with a new question (or the win / lose that was coming).
  void _resumeBattle() {
    if (!_paused || _askingLeave) return; // wait for the answer to "ออกจากด่าน ?"
    _paused = false;
    if (mounted) _checkBattleStatus();
  }

  Future<void> _confirmLeave() async {
    if (_dialogs > 0 || _askingLeave) return;
    _pauseBattle();
    _askingLeave = true;
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('ออกจากด่าน ?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDB2777))),
        content: const Text(
          'การต่อสู้ในด่านนี้จะหายไป\nแต่เหรียญและไอเทมที่ได้แล้วยังอยู่ครบ',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('เล่นต่อ')),
          _GameButton(
            color: const Color(0xFFEF4444),
            shadow: const Color(0xFF991B1B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ออก'),
          ),
        ],
      ),
    );
    _askingLeave = false;
    if (!mounted) return;
    if (leave == true) {
      _paused = false;
      Navigator.pop(context);
    } else {
      _resumeBattle();
    }
  }

  void _showWaveDialog() {
    _showLockedDialog(
      (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'ชนะแล้ว',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFDB2777), fontWeight: FontWeight.bold, fontSize: 24),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ล้ม ${currentMonster.name} สำเร็จแล้ว', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF1E293B))),
            const SizedBox(height: 12),
            _rewardChips(),
            const SizedBox(height: 10),
            const Text('พักฟื้นเลือด +20 ก่อนเลเวลถัดไป', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDB2777),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                heroCurrentHp = math.min(heroMaxHp, heroCurrentHp + 20);
                currentStage++;
                _spawnMonster();
                _startRound();
              },
              child: Text(
                currentStage + 1 == _totalWaves && isBossLevel(widget.level)
                    ? 'ไปสู้กับบอส'
                    : 'เลเวลถัดไป (${currentStage + 1} / $_totalWaves)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calcStars() {
    final double r = heroCurrentHp / heroMaxHp;
    if (r >= 0.7) return 3;
    if (r >= 0.4) return 2;
    return 1;
  }

  void _onLevelCleared() {
    _clearResume();
    final int stars = _calcStars();
    monsterProgress.completeLevel(widget.level, stars);
    // Real coins for passing: 5 per star (+10 boss), once per level per day.
    _coinFutures.add(MonsterCoins.levelClear(widget.level, stars));
    final Future<List<GuessCoinResult>> levelCoins = Future.wait(_coinFutures);
    final bool hasNext = widget.level < kMonsterLevels;

    _showLockedDialog(
      (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SingleChildScrollView(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isBossLevel(widget.level) ? 'ล้มบอสสำเร็จ' : 'ผ่านด่าน ${widget.level} ',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFDB2777), fontWeight: FontWeight.w900, fontSize: 24),
                    ),
                    const SizedBox(height: 12),
                    Text('เลือดเหลือ $heroCurrentHp / $heroMaxHp', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_lastDrop != null) _dropChip(),
                        FutureBuilder<List<GuessCoinResult>>(
                          future: levelCoins,
                          builder: (_, snap) {
                            final list = snap.data;
                            final coins = _coinsBefore + (list?.fold<int>(0, (s, r) => s + r.coins) ?? 0);
                            final pending = list?.where((r) => r.pending).length ?? 0;
                            final String text = list == null
                                ? 'กำลังนับเหรียญ...'
                                : pending > 0
                                    ? '+$coins เหรียญ (รอต่อเน็ต)'
                                    : coins > 0
                                        ? '+$coins เหรียญ'
                                        : 'วันนี้ได้เหรียญด่านนี้ไปแล้ว';
                            return Chip(
                              avatar: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFB627), size: 20),
                              label: Text(text, style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                              backgroundColor: const Color(0xFFFFF7D6),
                              side: BorderSide.none,
                            );
                          },
                        ),
                        Chip(
                          avatar: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                          label: Text('ตอบถูก $_correctCount คำ', style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                          backgroundColor: const Color(0xFFDCFCE7),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                    _missedWordsPanel(),
                    if (widget.level == kMonsterLevels)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('คุณผ่านครบทุกด่านแล้ว', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900)),
                      ),
                    const SizedBox(height: 16),
                    if (hasNext)
                      SizedBox(
                        width: double.infinity,
                        child: _GameButton(
                          color: const Color(0xFF22C55E),
                          shadow: const Color(0xFF15803D),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => BattleScreen(level: widget.level + 1)),
                            );
                          },
                          child: const Text('ด่านถัดไป'),
                        ),
                      ),
                    if (hasNext) const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _GameButton(
                            color: const Color(0xFFF0589F),
                            shadow: const Color(0xFFBE185D),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _restartLevel();
                            },
                            child: const Text('เล่นอีกครั้ง', style: TextStyle(fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GameButton(
                            color: const Color(0xFF64748B),
                            shadow: const Color(0xFF334155),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                            },
                            child: const Text('เลือกด่าน', style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _restartLevel() {
    _resetDuelState();
    _clearResume();
    _coinsBefore = 0;
    _coinsNow = 0;
    heroMaxHp = heroMaxHpOf(widget.level);
    _coinFutures.clear();
    heroCurrentHp = heroMaxHp;
    heroBaseAtk = 25 + (widget.level - 1) * 2;
    currentStage = 1;
    comboStreak = 0;
    maxCombo = 0;
    _correctCount = 0;
    _missed.clear();
    _usedQuestionIndices.clear();
    _spawnMonster();
    _startRound();
  }

  void _showGameOverDialog() {
    _clearResume();
    monsterProgress.noteCombo(maxCombo);
    _showLockedDialog(
      (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        scrollable: true,
        title: const Center(
          child: Text('จบเกม', style: TextStyle(color: Color(0xFFDB2777), fontWeight: FontWeight.bold, fontSize: 26)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$heroName พ่ายแพ้ในการประลอง...', style: const TextStyle(color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text('ไปได้ไกลสุดถึง เลเวล $currentStage / $_totalWaves', style: const TextStyle(color: Color(0xFFDB2777), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _missedWordsPanel(),
            const SizedBox(height: 8),
            const Text('ลองซื้อไอเทมช่วยเล่นก่อนเข้าด่านดูนะ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDB2777),
                    side: const BorderSide(color: Color(0xFFDB2777)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: const Text('เลือกด่าน', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDB2777),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _restartLevel();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('ลองใหม่', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFFFE0EC),
      body: _GameScaffoldBody(
        title: 'สร้างมอนสเตอร์',
        color: const Color(0xFFE9478F),
        onBack: _confirmLeave,
        child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE2CBE6), Color(0xFFCFB1D9), Color(0xFFB892C7)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                _fitPanel(box.maxWidth, box.maxHeight);
                return Column(
              children: [
                _buildPlayerHeader(),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      const double offset = 0.0;
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: child,
                      );
                    },
                    child: _buildBattleArena(),
                  ),
                ),
                _buildCombatLog(),
                _buildQuestionPanel(),
              ],
            );
              },
            ),
          ),
          if (_phase == _Phase.clash) _clashOverlay(),
        ],
      ),
        ),
      ),
    ));
  }

  // ---------- หน้าจอปะทะ (CLASH!) ----------
  Widget _clashOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xEE1E1B4B),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ปะทะ !',
                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Color(0xFFFDE047))),
            const SizedBox(height: 6),
            Text('ตอบถูกพร้อมกันเลย แย่งแตะให้ไวกว่า ${currentMonster.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Text('${_emojiFor(currentQuestion)} ${currentQuestion.word}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('คำนี้ขึ้นต้นด้วยตัวอะไร ?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFC7D2FE))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final String l in _clashLetters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _GameButton(
                      color: const Color(0xFFF59E0B),
                      shadow: const Color(0xFFB45309),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      onPressed: _clashWrong.contains(l) ? null : () => _clashTap(l),
                      child: Text(l, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(_questionSeq),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: _clashDurMs),
                curve: Curves.linear,
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 12,
                    backgroundColor: Colors.white24,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('มอนสเตอร์กำลังแตะ... รีบเลย',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHeader() {
    return AnimatedBuilder(
      animation: monsterProgress,
      builder: (context, _) => Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEBDDEF), Color(0xFFD5BFDF)]),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // กรอบดาบ
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_BT.parchment, _BT.parchmentDark]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _BT.wood, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 2), blurRadius: 3)],
              ),
              child: const Text('🗡️', style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 12),
            // ชื่อฮีโร่
            Expanded(
              child: Text(
                heroName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _BT.ink),
              ),
            ),
            const SizedBox(width: 12),
            // เหรียญ (แบบเดียวกับหน้าเลือกด่าน)
            const _CoinPill(fontSize: 18),
          ],
        ),
      ),
    );
  }

  // ---------- บันทึกการเรียนรู้ ----------
  void _noteLearning({required bool correct}) {
    if (correct) {
      _correctCount++;
    } else {
      if (!_missed.any((m) => m['word'] == currentQuestion.word)) {
        _missed.add({'word': currentQuestion.word, 'meaning': currentQuestion.correctMeaning});
      }
      _speakWord(currentQuestion.word); // ให้ฟังเสียงคำที่ตอบพลาดอีกครั้ง
    }
  }

  Widget _missedWordsPanel() {
    if (_missed.isEmpty) return const SizedBox.shrink();
    final List<Map<String, String>> items = _missed.take(6).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          const Text(
            'คำที่ควรทบทวน (แตะเพื่อฟังเสียง)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: items.map((m) {
              return GestureDetector(
                onTap: () => _speakWord(m['word'] !),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${m['word']} = ${m['meaning']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------- สนามต่อสู้ ----------
  /// Shares the free height: part of it makes the word card and the answer
  /// buttons bigger, the rest goes to the arena, so nothing looks empty.
  void _fitPanel(double width, double height) {
    final double m = ((width - 83) / 1.85).clamp(56.0, 230.0).toDouble();
    final double arenaNeeds = m + 180; // characters, names, HP bars
    const double others = 64 + 56 + 200; // header, battle log, answer area
    final double spare = height - arenaNeeds - others;
    // All the spare height goes to the word card and the answer buttons
    // (up to 1.6x); the arena keeps just what the characters need.
    _ui = (1 + spare / 130).clamp(1.0, 1.6).toDouble();
  }

  Widget _buildBattleArena() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isSudden ? const [Color(0xFFEF4444), Color(0xFF991B1B)] : const [_BT.woodLight, _BT.woodDark],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F3D2E), // ฉากป่าวาดด้วย _BattlefieldPainter
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _BT.woodDark.withValues(alpha: 0.6), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BattlefieldPainter(accent: _world.accent, boss: _isBossWave),
                  ),
                ),
              ),
              // ป้ายด่าน / เวฟ / ความยาก
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_BT.parchment, _BT.parchmentDark]),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _BT.wood, width: 2),
                        boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 2), blurRadius: 3)],
                      ),
                      child: Text(
                        '${_isBossWave ? 'บอส ' : ''}ด่าน ${widget.level} • เลเวล $currentStage / $_totalWaves',
                        style: TextStyle(
                          color: _isBossWave ? const Color(0xFFB91C1C) : _BT.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFCFE3FA), Color(0xFF9CC3EE)]),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF2B4F86), width: 2),
                        boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 2), blurRadius: 3)],
                      ),
                      child: Text(
                        _diffConfig.title.split(' ')[0],
                        style: const TextStyle(color: Color(0xFF1B3A66), fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              // แถบดึงเชือก (Tug-of-War)
              Positioned(
                top: 46,
                left: 14,
                right: 14,
                child: _tugBar(),
              ),
              // ตัวละคร: คำนวณขนาดตามพื้นที่จริง ให้ใหญ่ที่สุดเท่าที่จะได้
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, cons) {
                    final double availW = cons.maxWidth - 16;
                    final double availH = cons.maxHeight - 74 - 4;
                    final double byH = availH - 70; // หักพื้นที่แถบคิด/ชื่อ/หลอดเลือด
                    final double byW = (availW - 30) / 1.85;
                    final double m = math.min(byH, byW).clamp(56.0, 230.0).toDouble();
                    final double monsterSize = _isBossWave ? m : m * 0.95;
                    final double heroSize = m * 0.9;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 72, 8, 4),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildCharacterCard(
                                name: heroName,
                                currentHp: heroCurrentHp,
                                maxHp: heroMaxHp,
                                isHero: true,
                                size: heroSize,
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: EdgeInsets.only(bottom: m * 0.55),
                                child: const Text(
                                  'ปะทะ',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFD9A441),
                                    fontStyle: FontStyle.italic,
                                    shadows: [
                                      Shadow(color: Color(0xFF5E3A1A), offset: Offset(2, 2)),
                                      Shadow(color: Colors.white, blurRadius: 5),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildCharacterCard(
                                name: currentMonster.name,
                                look: currentMonster.look,
                                currentHp: currentMonster.currentHp,
                                maxHp: currentMonster.maxHp,
                                isHero: false,
                                size: monsterSize,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // ตัวเลขดาเมจ / คำชม
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    children: _floatingTexts.map((f) {
                      return Align(
                        alignment: f.center
                            ? const Alignment(0.0, -0.2)
                            : (f.onRight ? const Alignment(0.5, 0.15) : const Alignment(-0.5, 0.15)),
                        child: FloatingDamageText(
                          key: ValueKey<int>(f.id),
                          text: f.text,
                          color: f.color,
                          fontSize: f.size,
                          onDone: () => _removeFloatingText(f.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroAvatar([double size = 96]) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFE9C27E), Color(0xFF8A5A2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF3B2410).withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 4)),
          if (comboStreak >= 3) BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.9), blurRadius: 24, spreadRadius: 4),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: const Color(0xFFFFF3E0),
          child: CustomPaint(
            painter: AvatarPainter(
              gender: AvatarProfile.instance.gender,
              skinColor: _heroSkinColor,
              hairStyle: AvatarProfile.instance.hairStyle,
              hairColor: _heroHairColor,
              outfit: _heroOutfit,
              glassesStyle: AvatarProfile.instance.glasses,
              hatStyle: AvatarProfile.instance.hat,
              clipStyle: AvatarProfile.instance.clip,
              earringStyle: AvatarProfile.instance.earring,
              neckStyle: AvatarProfile.instance.neck,
              extraStyle: AvatarProfile.instance.extra,
            ),
          ),
        ),
      ),
    );
  }

  Widget _hpBar(int currentHp, int maxHp) {
    final double pct = (currentHp / maxHp).clamp(0.0, 1.0).toDouble();
    final Color color = pct > 0.5
        ? const Color(0xFF3CCB4A)
        : (pct > 0.25 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    return SizedBox(
      width: 138,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 18,
            margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E3A24),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _BT.woodDark, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 3, offset: Offset(0, 1))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: pct),
                      duration: const Duration(milliseconds: 350),
                      builder: (context, v, _) => FractionallySizedBox(
                        widthFactor: v,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color.lerp(color, Colors.white, 0.3)!, color],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '$currentHp / $maxHp',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(left: 0, child: Text('❤️', style: TextStyle(fontSize: 18))),
        ],
      ),
    );
  }

  Widget _tugBar() {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_BT.parchment, _BT.parchmentDark]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _BT.wood, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 2), blurRadius: 3)],
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) {
                final double w = cons.maxWidth;
                final double x = (_tug + _tugMax) / (2 * _tugMax);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: const LinearGradient(colors: [
                              Color(0xFF4DA3F0),
                              Color(0xFF4DD0A0),
                              Color(0xFFFDE047),
                              Color(0xFFFB923C),
                              Color(0xFFEF4444),
                            ]),
                            border: Border.all(color: _BT.woodDark, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      left: (w - 22) * x,
                      top: 0,
                      bottom: 0,
                      width: 22,
                      child: const Center(child: Text('', style: TextStyle(fontSize: 18))),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          const Text('', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _monsterThinkBar() {
    final MonsterAIProfile p = kMonsterAI[currentMonster.ai] !;
    return AnimatedBuilder(
      animation: _tickN,
      builder: (context, _) {
        final bool frozen = _freezeLeft > 0;
        final double prog = _monsterTime <= 0 ? 1.0 : (_mClock / _monsterTime).clamp(0.0, 1.0).toDouble();
        final double remain = math.max(0.0, _monsterTime - _mClock);
        String label;
        if (_bubble != null) {
          label = _bubble !;
        } else if (_phase == _Phase.resolved || _phase == _Phase.ready) {
          label = p.label;
        } else if (_monsterStunned) {
          label = 'ตอบผิด !';
        } else if (frozen) {
          label = 'แช่แข็ง ${_freezeLeft.toStringAsFixed(1)}';
        } else if (_phase == _Phase.grace) {
          label = 'กำลังตอบ !';
        } else {
          label = 'คิดอยู่... ${remain.toStringAsFixed(1)} วิ';
        }
        final Color barColor = frozen
            ? const Color(0xFF38BDF8)
            : (prog > 0.7 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
        return SizedBox(
          width: 158,
          height: 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_BT.parchment, _BT.parchmentDark]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _BT.wood, width: 2),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _BT.ink)),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: _BT.woodDark.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _BT.woodDark, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _monsterStunned ? 0.0 : prog,
                      child: Container(color: barColor),
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

  Widget _buildCharacterCard({
    required String name,
    MonsterLook? look,
    required int currentHp,
    required int maxHp,
    required bool isHero,
    required double size,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idleController, _hitController, _heroLunge, _monsterLunge]),
      builder: (context, _) {
        // ตัวละครอยู่นิ่ง ไม่ลอย ไม่สั่น ไม่พุ่ง ไม่กะพริบตา
        const double bob = 0.0;
        const double shake = 0.0;
        const double lunge = 0.0;
        const double blink = 0.0;

        MonsterMood mood;
        if (_hitController.isAnimating || currentHp <= 0) {
          mood = MonsterMood.hurt;
        } else if (_moodOverride != null) {
          mood = _moodOverride!;
        } else if (_phase == _Phase.racing) {
          mood = _bossEnraged ? MonsterMood.angry : MonsterMood.thinking; // ขมวดคิ้วคิดอยู่
        } else {
          mood = _bossEnraged ? MonsterMood.angry : MonsterMood.normal;
        }

        return Transform.translate(
          offset: Offset(shake + lunge, -bob),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isHero) ...[
                _monsterThinkBar(),
                const SizedBox(height: 10),
              ],
              if (isHero)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _heroAvatar(size),
                    if (_shield) Positioned(right: -6, top: -6, child: Text('🛡️', style: TextStyle(fontSize: size * 0.32))),
                    if (comboStreak >= 2)
                      Positioned(
                        left: -10,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text('🔥 x$comboStreak',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                        ),
                      ),
                  ],
                )
              else
                TweenAnimationBuilder<double>(
                  key: ValueKey<int>(_spawnSeq),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.elasticOut,
                  builder: (context, v, child) => Transform.scale(scale: v, child: child),
                  child: AnimatedRotation(
                    turns: currentHp <= 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 650),
                    child: AnimatedScale(
                      scale: currentHp <= 0 ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeIn,
                      child: MonsterAvatar(look: look!, size: size, mood: mood, blink: blink),
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 0.58,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_BT.parchment, _BT.parchmentDark]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _BT.wood, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 2), blurRadius: 3)],
                  ),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _BT.ink),
                  ),
                ),
              ),
                    const SizedBox(height: 4),
                    _hpBar(currentHp, maxHp),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _scrollRoll() {
    return Container(
      width: 16,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFB98A4C), Color(0xFFEBCF94), Color(0xFFB98A4C)]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _BT.woodDark, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 2), blurRadius: 3)],
      ),
    );
  }

  Widget _buildCombatLog() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: _gap),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFAEFD2), Color(0xFFE9D3A2)]),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFB08A4A), width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 3), blurRadius: 4)],
            ),
            child: Text(
              combatLog,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _BT.ink, fontWeight: FontWeight.w800, fontSize: 13, height: 1.25),
            ),
          ),
          Positioned(left: 0, top: 2, bottom: 2, child: _scrollRoll()),
          Positioned(right: 0, top: 2, bottom: 2, child: _scrollRoll()),
        ],
      ),
    );
  }

  // ---------- แผงคำถาม ----------
  // [สีบน, สีล่าง, สีขอบ] ของปุ่มคำตอบแบบแผ่นหิน
  static const List<List<Color>> _stonePalette = [
    [Color(0xFF58A6F0), Color(0xFF2E64C0), Color(0xFF1B3F7E)],
    [Color(0xFFF59E42), Color(0xFFC8640F), Color(0xFF7A3A06)],
    [Color(0xFFAD74E4), Color(0xFF7438AC), Color(0xFF43206A)],
    [Color(0xFFEE5FA3), Color(0xFFB02E6A), Color(0xFF6A1440)],
  ];

  Widget _timerBar(Color color) {
    return AnimatedBuilder(
      animation: _tickN,
      builder: (context, _) {
        final double frac = (_limitSec <= 0 ? 0.0 : 1 - _elapsed / _limitSec).clamp(0.0, 1.0).toDouble();
        return Container(
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF4A3558).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF7D5A8C), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(color, Colors.white, 0.3)!, color],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _suddenBanner() {
    return AnimatedBuilder(
      animation: _idleController,
      builder: (context, _) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12 + 0.18 * _idleController.value),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'ช่วงตัดสิน ! เหลือแค่ ${_limitSec.round()} วินาที ',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
        ),
      ),
    );
  }

  Widget _wordCard() {
    final String emoji = _emojiFor(currentQuestion);
    return GestureDetector(
      onTap: () => _speakWord(currentQuestion.word),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _bonusRound ? const [Color(0xFFFEF3C7), Color(0xFFFDE68A)] : const [Color(0xFFF6EAF0), Color(0xFFE3D0DC)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _bonusRound ? const Color(0xFFF59E0B) : _BT.mauve, width: 2.5),
          boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 3)],
        ),
        child: Row(
          children: [
            // กรอบรูป (ใช้อีโมจิแทนรูปภาพ)
            Container(
              width: 84 * _ui,
              height: 44 * _ui,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9AD8F5), Color(0xFFB8E6A0)]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: TweenAnimationBuilder<double>(
                key: ValueKey<String>('emoji$_questionSeq'),
                tween: Tween<double>(begin: 0.3, end: 1.0),
                duration: const Duration(milliseconds: 550),
                curve: Curves.elasticOut,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: Text(emoji, style: TextStyle(fontSize: 28 * _ui)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  currentQuestion.word,
                  style: TextStyle(
                    fontSize: 30 * _ui,
                    fontWeight: FontWeight.w900,
                    color: _BT.ink,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFB08AC0), Color(0xFF6E4A80)]),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 3)],
              ),
              child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceButton(int index) {
    if (index >= currentQuestion.choices.length) return SizedBox(height: 36 * _ui);
    final String choice = currentQuestion.choices[index];
    if (_hiddenChoices.contains(choice)) return SizedBox(height: 36 * _ui);

    final bool isCorrect = choice == currentQuestion.correctMeaning;
    final bool isPicked = choice == _selectedAnswer;
    final bool tried = _triedWrong.contains(choice);
    final bool fogged = _fogChoice == choice && !_answerLocked;
    Color top = _stonePalette[index % 4][0];
    Color bottom = _stonePalette[index % 4][1];
    Color edge = _stonePalette[index % 4][2];
    IconData? icon;

    if (_answerLocked) {
      if (isCorrect) {
        top = const Color(0xFF6BE07A);
        bottom = const Color(0xFF2FA44A);
        edge = const Color(0xFF14532D);
        icon = Icons.check_circle_rounded;
      } else if (isPicked || tried) {
        top = const Color(0xFFF47272);
        bottom = const Color(0xFFD63B3B);
        edge = const Color(0xFF7F1D1D);
        icon = Icons.cancel_rounded;
      } else {
        top = const Color(0xFFCBD5E1);
        bottom = const Color(0xFFA8B4C5);
        edge = const Color(0xFF64748B);
      }
    } else if (tried) {
      top = const Color(0xFFFCA5A5);
      bottom = const Color(0xFFF87171);
      edge = const Color(0xFFB91C1C);
      icon = Icons.close_rounded;
    } else if (fogged) {
      top = const Color(0xFF94A3B8);
      bottom = const Color(0xFF7C8CA3);
      edge = const Color(0xFF475569);
    }

    return AnimatedScale(
      scale: (_answerLocked && (isCorrect || isPicked)) ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (_canAct && !tried && !fogged) ? () => _answerQuestion(choice) : null,
        child: Container(
          height: 36 * _ui,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: edge,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 3))],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 20 * _ui,
                  height: 20 * _ui,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: edge,
                    border: Border.all(color: Colors.white, width: 1.8),
                  ),
                  child: icon != null
                      ? Icon(icon, size: 13, color: Colors.white)
                      : Text(
                          String.fromCharCode(65 + index),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        fogged ? '' : choice,
                        style: TextStyle(
                          fontSize: 14 * _ui,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2))],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionPanel() {
    final bool urgent = timeLeft <= (_timeTotal * 0.3).ceil() && timeLeft > 0;
    final Color timerColor = urgent
        ? const Color(0xFFEF4444)
        : (timeLeft <= _timeTotal * 0.6 ? const Color(0xFFF59E0B) : const Color(0xFF22C55E));

    return Container(
      padding: EdgeInsets.fromLTRB(12, _gap, 12, _gap),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_BT.lilacTop, _BT.lilacBottom]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: const Color(0xFFF1E6F5), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7A5A88), Color(0xFF4E3359)]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFB59AC4), width: 1.5),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currentQuestion.category.split(' ').first, // ชื่อหมวดอย่างเดียว ไม่มีอีโมจิ
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _powerUpButton('hint', '🧭', _useHint, active: _hiddenChoices.isNotEmpty, size: 32),
              const SizedBox(width: 9),
              _powerUpButton('freeze', '⏳', _useFreeze, active: _freezeLeft > 0, size: 32),
              const SizedBox(width: 9),
              _powerUpButton('smoke', '💨', _useSmoke, active: _smokeUsed, size: 32),
              const SizedBox(width: 9),
              _powerUpButton('shield', '🛡️', _useShield, active: _shield, size: 32),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF6ECF8), Color(0xFFDCC8E4)]),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: urgent ? timerColor : _BT.mauve, width: 1.5),
                ),
                child: Text(
                  '⏳ $timeLeft วิ',
                  style: TextStyle(color: urgent ? timerColor : _BT.ink, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: _gap),
          _timerBar(timerColor),
          if (_isSudden) _suddenBanner(),
          SizedBox(height: _gap),
          _wordCard(),
          SizedBox(height: _gap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _choiceButton(0)),
                    SizedBox(width: _gap),
                    Expanded(child: _choiceButton(1)),
                  ],
                ),
                SizedBox(height: _gap),
                Row(
                  children: [
                    Expanded(child: _choiceButton(2)),
                    SizedBox(width: _gap),
                    Expanded(child: _choiceButton(3)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------
// ป้ายแสดงเหรียญจริงของบัญชี (เหมือนเกมอื่น ใช้ซื้อไอเทมช่วยเล่นด้วย)
// ---------------------------------------------------------------
class _CoinPill extends StatelessWidget {
  final Color color;
  final double fontSize;

  const _CoinPill({
    // ignore: unused_element_parameter
    this.color = const Color(0xFFB45309),
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final double fs = fontSize;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fs * 0.7, vertical: fs * 0.3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(fs * 1.6),
        border: Border.all(color: const Color(0xFFFFD43B), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.monetization_on_rounded,
            color: const Color(0xFFFFB627),
            size: fs * 1.45,
          ),
          SizedBox(width: fs * 0.35),
          ValueListenableBuilder<int?>(
            valueListenable: CoinBalance.value,
            builder: (_, coins, _) => Text(
            coins == null ? '-' : '$coins',
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          )),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _CoinPillBar extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final double fontSize;

  const _CoinPillBar({
    // ignore: unused_element_parameter
    this.padding = const EdgeInsets.only(bottom: 8),
    // ignore: unused_element_parameter
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: padding,
        child: _CoinPill(fontSize: fontSize),
      ),
    );
  }
}


// ---------------------------------------------------------------
// แถบหัวเรื่องด้านบนของเกม (ปุ่มย้อนกลับ + ชื่อเกม บนพื้นสีประจำเกม)
// ---------------------------------------------------------------
class _GameHeaderBar extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onBack;
  final bool showBack;

  const _GameHeaderBar({
    required this.title,
    required this.color,
    this.onBack,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (showBack)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onBack ?? () => Navigator.maybePop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                )
              else
                const SizedBox(width: 34),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameScaffoldBody extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onBack;
  final bool showBack;
  final Widget child;

  const _GameScaffoldBody({
    required this.title,
    required this.color,
    required this.child,
    this.onBack,
    // ignore: unused_element_parameter
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GameHeaderBar(
          title: title,
          color: color,
          onBack: onBack,
          showBack: showBack,
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// ฉากต่อสู้ในป่า: ป่าสนสองชั้น ลานดินกลางป่าล้อมด้วยก้อนหิน
// ธงของฮีโร่ (ฟ้า) กับธงมอนสเตอร์ (แดง)
// ด่านบอส: ป่ายามค่ำสีแดงเพลิง ดูน่ากลัวกว่า
// ---------------------------------------------------------------
class _BattlefieldPainter extends CustomPainter {
  final Color accent; // สีประจำโลก (ไม่ใช้ในฉากป่า เก็บไว้เผื่อปรับ)
  final bool boss;
  const _BattlefieldPainter({required this.accent, this.boss = false});

  double _r(int i, double k) {
    final double v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  void _pine(Canvas canvas, double x, double base, double th, double tw, Color color) {
    final Paint p = Paint()..color = color;
    for (int k = 0; k < 3; k++) {
      final double top = base - th + k * th * 0.22;
      final double bw = tw * (0.55 + k * 0.25);
      canvas.drawPath(
        Path()
          ..moveTo(x, top)
          ..lineTo(x - bw / 2, top + th * 0.42)
          ..lineTo(x + bw / 2, top + th * 0.42)
          ..close(),
        p,
      );
    }
    canvas.drawRect(Rect.fromLTWH(x - tw * 0.05, base - th * 0.2, tw * 0.1, th * 0.2), p);
  }

  void _roundTree(Canvas canvas, double x, double base, double r, Color color) {
    final Paint p = Paint()..color = color;
    canvas.drawCircle(Offset(x, base - r * 1.3), r, p);
    canvas.drawCircle(Offset(x - r * 0.6, base - r * 0.8), r * 0.7, p);
    canvas.drawCircle(Offset(x + r * 0.6, base - r * 0.8), r * 0.7, p);
    canvas.drawRect(Rect.fromLTWH(x - r * 0.1, base - r * 0.6, r * 0.2, r * 0.6), p);
  }

  void _bushes(Canvas canvas, double x, double y, double s, Color color) {
    final Paint p = Paint()..color = color;
    canvas.drawCircle(Offset(x, y), s, p);
    canvas.drawCircle(Offset(x + s * 0.9, y + s * 0.2), s * 0.8, p);
    canvas.drawCircle(Offset(x - s * 0.9, y + s * 0.25), s * 0.75, p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double hz = h * 0.60; // ขอบฟ้า
    final Paint p = Paint()..isAntiAlias = true;

    // ท้องฟ้าในป่า
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: boss
          ? const [Color(0xFF1B0F1F), Color(0xFF4A1D2E), Color(0xFFC2410C)]
          : const [Color(0xFF0F3D2E), Color(0xFF2F6B45), Color(0xFFB7E4A0)],
      stops: const [0.0, 0.6, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, hz));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);

    // ต้นไม้แถวหลัง
    final Color far = boss ? const Color(0xD93C1928) : const Color(0xD91F5135);
    for (int i = 0; i < 14; i++) {
      final double x = w * (i + 0.3 * _r(i, 2)) / 13;
      final double th = h * (0.16 + 0.12 * _r(i, 4));
      if (i.isOdd) {
        _pine(canvas, x, hz + 4, th, th * 0.55, far);
      } else {
        _roundTree(canvas, x, hz + 4, th * 0.32, far);
      }
    }

    // ต้นไม้แถวหน้า (ขอบซ้าย-ขวา)
    final Color near = boss ? const Color(0xFF2A1220) : const Color(0xFF143D28);
    _pine(canvas, w * 0.06, hz + h * 0.08, h * 0.5, h * 0.3, near);
    _pine(canvas, w * 0.20, hz + h * 0.06, h * 0.36, h * 0.22, near);
    _roundTree(canvas, w * 0.94, hz + h * 0.08, h * 0.15, near);
    _pine(canvas, w * 0.80, hz + h * 0.06, h * 0.38, h * 0.22, near);

    // พื้นหญ้า
    final Path ground = Path()
      ..moveTo(0, hz + h * 0.04)
      ..quadraticBezierTo(w / 2, hz - h * 0.02, w, hz + h * 0.04)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: boss ? const [Color(0xFF3F3A1E), Color(0xFF1F1A10)] : const [Color(0xFF4C8C3F), Color(0xFF24491F)],
    ).createShader(Rect.fromLTWH(0, hz, w, h - hz));
    canvas.drawPath(ground, p);
    p.shader = null;

    // ใบหญ้า
    final Paint grass = Paint()
      ..color = boss ? const Color(0x99786E3C) : const Color(0x998CC86E)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 40; i++) {
      final double x = _r(i, 13) * w;
      final double y = hz + h * 0.06 + _r(i, 17) * (h - hz - h * 0.08);
      canvas.drawLine(Offset(x, y), Offset(x - 2, y - 6), grass);
      canvas.drawLine(Offset(x, y), Offset(x + 2, y - 7), grass);
    }

    // ลานดินกลางป่า + ก้อนหินรอบลาน
    final Offset c = Offset(w / 2, h * 0.86);
    final Rect clearing = Rect.fromCenter(center: c, width: w * 0.88, height: h * 0.20);
    p.color = const Color(0x661E140A);
    canvas.drawOval(clearing.shift(const Offset(0, 4)), p);
    p.shader = const RadialGradient(colors: [Color(0xFFB08A5A), Color(0xFF7A5535)]).createShader(clearing);
    canvas.drawOval(clearing, p);
    p.shader = null;
    p.color = const Color(0xFF8D8A85);
    for (int i = 0; i < 10; i++) {
      final double a = i / 10 * math.pi * 2;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx + math.cos(a) * w * 0.44 * 0.98, c.dy + math.sin(a) * h * 0.10 * 0.98),
          width: 10,
          height: 7,
        ),
        p,
      );
    }

    // พุ่มไม้มุมล่าง
    final Color bush = boss ? const Color(0xFF24121C) : const Color(0xFF1E5A30);
    _bushes(canvas, w * 0.02, h * 0.98, h * 0.09, bush);
    _bushes(canvas, w * 0.98, h * 0.98, h * 0.09, bush);

    // ธงสองฝ่าย: ฮีโร่สีฟ้า (ซ้าย) มอนสเตอร์สีแดง (ขวา)
    _flag(canvas, Offset(w * 0.10, h * 0.82), h * 0.28, const Color(0xFF3B82F6), toRight: true);
    _flag(canvas, Offset(w * 0.90, h * 0.82), h * 0.28, const Color(0xFFDC2626), toRight: false);
  }

  void _flag(Canvas canvas, Offset foot, double height, Color color, {required bool toRight}) {
    final Paint pole = Paint()
      ..color = const Color(0xFF5B3A1E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final Offset top = foot.translate(0, -height);
    canvas.drawLine(foot, top, pole);
    final double d = toRight ? 1 : -1;
    final double fw = height * 0.42;
    final Path cloth = Path()
      ..moveTo(top.dx, top.dy + 2)
      ..quadraticBezierTo(top.dx + d * fw * 0.5, top.dy - 4, top.dx + d * fw, top.dy + 4)
      ..lineTo(top.dx + d * fw * 0.8, top.dy + height * 0.14)
      ..lineTo(top.dx + d * fw, top.dy + height * 0.24)
      ..quadraticBezierTo(top.dx + d * fw * 0.5, top.dy + height * 0.20, top.dx, top.dy + height * 0.24)
      ..close();
    canvas.drawPath(cloth, Paint()..color = color);
    canvas.drawCircle(top, 3.5, Paint()..color = const Color(0xFFFFD166));
  }

  @override
  bool shouldRepaint(covariant _BattlefieldPainter old) => old.accent != accent || old.boss != boss;
}
