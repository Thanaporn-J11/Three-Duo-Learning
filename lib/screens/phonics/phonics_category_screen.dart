import 'package:flutter/material.dart';
import 'phonics_practice_screen.dart';
import '../../services/phonics_progress_service.dart';

class PhonicsCategoryModel {
  final String id;
  final String title;
  final String thaiDesc;
  final String iconImagePath;
  final Color cardBg;
  final Color accentColor;
  final Color bevelColor;
  final List<PhonicsCardItem> items;

  const PhonicsCategoryModel({
    required this.id,
    required this.title,
    required this.thaiDesc,
    required this.iconImagePath,
    required this.cardBg,
    required this.accentColor,
    required this.bevelColor,
    required this.items,
  });
}

class PhonicsCategoryScreen extends StatefulWidget {
  const PhonicsCategoryScreen({Key? key}) : super(key: key);

  static const String _basePath = 'assets/images/phonics';

  static const List<PhonicsCategoryModel> categories = [
    PhonicsCategoryModel(
      id: '01',
      title: 'เสียงพยัญชนะ A-Z',
      thaiDesc: 'ฝึกออกเสียงตัวอักษร',
      iconImagePath: '$_basePath/A-Z.png',
      cardBg: Color(0xFFFFF4F2),
      accentColor: Color(0xFFFF5252),
      bevelColor: Color(0xFFC62828),
      items: [
        PhonicsCardItem(symbol: '/b/', sampleWord: 'Bat', thaiSound: 'เบอะ', emoji: '🦇', imagePath: '$_basePath/Bat.png'),
        PhonicsCardItem(symbol: '/d/', sampleWord: 'Dog', thaiSound: 'เดอะ', emoji: '🐶', imagePath: '$_basePath/Dog.png'),
        PhonicsCardItem(symbol: '/f/', sampleWord: 'Fish', thaiSound: 'เฟอะ', emoji: '🐟', imagePath: '$_basePath/Fish.png'),
        PhonicsCardItem(symbol: '/g/', sampleWord: 'Goat', thaiSound: 'เกอะ', emoji: '🐐', imagePath: '$_basePath/Goat.png'),
        PhonicsCardItem(symbol: '/h/', sampleWord: 'Hat', thaiSound: 'เฮอะ', emoji: '👒', imagePath: '$_basePath/Hat.png'),
        PhonicsCardItem(symbol: '/j/', sampleWord: 'Jam', thaiSound: 'เจอะ', emoji: '🍓', imagePath: '$_basePath/Jam.png'),
        PhonicsCardItem(symbol: '/k/', sampleWord: 'Cat', thaiSound: 'เคอะ', emoji: '🐱', imagePath: '$_basePath/Cat.png'),
        PhonicsCardItem(symbol: '/l/', sampleWord: 'Lion', thaiSound: 'เลอะ', emoji: '🦁', imagePath: '$_basePath/Lion.png'),
        PhonicsCardItem(symbol: '/m/', sampleWord: 'Moon', thaiSound: 'เมอะ', emoji: '🌙', imagePath: '$_basePath/Moon.png'),
        PhonicsCardItem(symbol: '/n/', sampleWord: 'Nose', thaiSound: 'เนอะ', emoji: '👃', imagePath: '$_basePath/Nose.png'),
        PhonicsCardItem(symbol: '/p/', sampleWord: 'Pig', thaiSound: 'เพอะ', emoji: '🐷', imagePath: '$_basePath/Pig.png'),
        PhonicsCardItem(symbol: '/r/', sampleWord: 'Rabbit', thaiSound: 'เรอะ', emoji: '🐰', imagePath: '$_basePath/Rabbit.png'),
        PhonicsCardItem(symbol: '/s/', sampleWord: 'Sun', thaiSound: 'เสอะ', emoji: '☀️', imagePath: '$_basePath/Sun.png'),
        PhonicsCardItem(symbol: '/t/', sampleWord: 'Tiger', thaiSound: 'เทอะ', emoji: '🐯', imagePath: '$_basePath/Tiger.png'),
        PhonicsCardItem(symbol: '/v/', sampleWord: 'Van', thaiSound: 'เวอะ (ริมฝีปากแตะฟัน)', emoji: '🚐', imagePath: '$_basePath/Van.png'),
        PhonicsCardItem(symbol: '/w/', sampleWord: 'Water', thaiSound: 'เวอะ (ปากจู๋)', emoji: '💧', imagePath: '$_basePath/Water.png'),
        PhonicsCardItem(symbol: '/z/', sampleWord: 'Zebra', thaiSound: 'ซึ/เซอะ (สั่นคอ)', emoji: '🦓', imagePath: '$_basePath/Zebar.png'),
        PhonicsCardItem(symbol: '/c/', sampleWord: 'Cup', thaiSound: 'เคอะ', emoji: '☕', imagePath: '$_basePath/Cup.png'),
        PhonicsCardItem(symbol: '/q/', sampleWord: 'Queen', thaiSound: 'เควอะ', emoji: '👑', imagePath: '$_basePath/Queen.png'),
        PhonicsCardItem(symbol: '/x/', sampleWord: 'Box', thaiSound: 'กซึ (ท้ายคำ)', emoji: '📦', imagePath: '$_basePath/Box.png'),
        PhonicsCardItem(symbol: '/y/', sampleWord: 'Yes', thaiSound: 'เยอะ', emoji: '👍', imagePath: '$_basePath/Yes.png'),
      ],
    ),
    PhonicsCategoryModel(
      id: '02',
      title: 'เสียงสระสั้น - ยาว',
      thaiDesc: 'แยกเสียงสั้นและยาว',
      iconImagePath: '$_basePath/megaphone.png',
      cardBg: Color(0xFFFFFBEA),
      accentColor: Color(0xFFFFB300),
      bevelColor: Color(0xFFB27B00),
      items: [
        PhonicsCardItem(symbol: 'Short A /æ/', sampleWord: 'Apple', thaiSound: 'แอะ', emoji: '🍎', imagePath: '$_basePath/Apple.png'),
        PhonicsCardItem(symbol: 'Short E /ɛ/', sampleWord: 'Egg', thaiSound: 'เอะ', emoji: '🥚', imagePath: '$_basePath/Egg.png'),
        PhonicsCardItem(symbol: 'Short I /ɪ/', sampleWord: 'Pig', thaiSound: 'อิ', emoji: '🐷', imagePath: '$_basePath/Pig.png'),
        PhonicsCardItem(symbol: 'Short O /ɒ/', sampleWord: 'Octopus', thaiSound: 'เอาะ', emoji: '🐙', imagePath: '$_basePath/Octopus.png'),
        PhonicsCardItem(symbol: 'Short U /ʌ/', sampleWord: 'Umbrella', thaiSound: 'อะ', emoji: '☂️', imagePath: '$_basePath/Umbrella.png'),
        PhonicsCardItem(symbol: 'Long A /eɪ/', sampleWord: 'Cake', thaiSound: 'เอ', emoji: '🎂', imagePath: '$_basePath/Cake.png'),
        PhonicsCardItem(symbol: 'Long E /iː/', sampleWord: 'Bee', thaiSound: 'อี', emoji: '🐝', imagePath: '$_basePath/Bee.png'),
        PhonicsCardItem(symbol: 'Long I /aɪ/', sampleWord: 'Bike', thaiSound: 'ไอ', emoji: '🚲', imagePath: '$_basePath/Bike.png'),
        PhonicsCardItem(symbol: 'Long O /oʊ/', sampleWord: 'Home', thaiSound: 'โอ', emoji: '🏠', imagePath: '$_basePath/Home.png'),
        PhonicsCardItem(symbol: 'Long U /uː/', sampleWord: 'Cube', thaiSound: 'อู/ยู', emoji: '🧊', imagePath: '$_basePath/Cube.png'),
      ],
    ),
    PhonicsCategoryModel(
      id: '03',
      title: 'เสียงพยัญชนะคู่',
      thaiDesc: 'ฝึกเสียง sh, ch, th',
      iconImagePath: '$_basePath/magnet.png',
      cardBg: Color(0xFFEFFBFF),
      accentColor: Color(0xFF00B4D8),
      bevelColor: Color(0xFF007791),
      items: [
        PhonicsCardItem(symbol: 'sh /ʃ/', sampleWord: 'Ship', thaiSound: 'เชอะ (ลาก ลมยาว)', emoji: '🚢', imagePath: '$_basePath/Ship.png'),
        PhonicsCardItem(symbol: 'ch /tʃ/', sampleWord: 'Chair', thaiSound: 'เชอะ (หยุดลม)', emoji: '🪑', imagePath: '$_basePath/Chair.png'),
        PhonicsCardItem(symbol: 'th /θ/', sampleWord: 'Think', thaiSound: 'เธอะ (ฟันแตะลิ้น)', emoji: '💭', imagePath: '$_basePath/Think.png'),
        PhonicsCardItem(symbol: 'th /ð/', sampleWord: 'This', thaiSound: 'เธอะ (ก้องในคอ)', emoji: '👉', imagePath: '$_basePath/This.png'),
        PhonicsCardItem(symbol: 'ph /f/', sampleWord: 'Phone', thaiSound: 'เฟอะ', emoji: '📱', imagePath: '$_basePath/Phone.png'),
        PhonicsCardItem(symbol: 'wh /w/', sampleWord: 'Whale', thaiSound: 'เวอะ', emoji: '🐳', imagePath: '$_basePath/Whale.png'),
        PhonicsCardItem(symbol: 'ng /ŋ/', sampleWord: 'Ring', thaiSound: 'งึ (เสียงท้ายคำ)', emoji: '💍', imagePath: '$_basePath/Ring.png'),
        PhonicsCardItem(symbol: 'ck /k/', sampleWord: 'Duck', thaiSound: 'เคอะ (เสียงท้ายคำ)', emoji: '🦆', imagePath: '$_basePath/Duck.png'),
      ],
    ),
    PhonicsCategoryModel(
      id: '04',
      title: 'เสียงสระคู่',
      thaiDesc: 'ฝึกเสียง ai, ee, oa',
      iconImagePath: '$_basePath/trophy.png',
      cardBg: Color(0xFFF7F2FF),
      accentColor: Color(0xFF9D4EDD),
      bevelColor: Color(0xFF6A1B9A),
      items: [
        PhonicsCardItem(symbol: 'ai', sampleWord: 'Rain', thaiSound: 'เอ', emoji: '🌧️', imagePath: '$_basePath/Rain.png'),
        PhonicsCardItem(symbol: 'ay', sampleWord: 'Play', thaiSound: 'เอ', emoji: '🎮', imagePath: '$_basePath/Play.png'),
        PhonicsCardItem(symbol: 'ee', sampleWord: 'Tree', thaiSound: 'อี', emoji: '🌳', imagePath: '$_basePath/Tree.png'),
        PhonicsCardItem(symbol: 'ea', sampleWord: 'Beach', thaiSound: 'อี', emoji: '🏖️', imagePath: '$_basePath/Beach.png'),
        PhonicsCardItem(symbol: 'oa', sampleWord: 'Boat', thaiSound: 'โอ', emoji: '⛵', imagePath: '$_basePath/Boat.png'),
        PhonicsCardItem(symbol: 'ow', sampleWord: 'Snow', thaiSound: 'โอ', emoji: '❄️', imagePath: '$_basePath/Snow.png'),
        PhonicsCardItem(symbol: 'oi', sampleWord: 'Coin', thaiSound: 'ออย', emoji: '🪙', imagePath: '$_basePath/Coin.png'),
        PhonicsCardItem(symbol: 'oy', sampleWord: 'Toy', thaiSound: 'ออย', emoji: '🧸', imagePath: '$_basePath/Toy.png'),
        PhonicsCardItem(symbol: 'ou', sampleWord: 'House', thaiSound: 'เอา', emoji: '🏡', imagePath: '$_basePath/House.png'),
        PhonicsCardItem(symbol: 'oo', sampleWord: 'Moon', thaiSound: 'อู/อุ', emoji: '🌕', imagePath: '$_basePath/Moon.png'),
      ],
    ),
    PhonicsCategoryModel(
      id: '05',
      title: 'ฝึกผสมเสียงอ่านคำ',
      thaiDesc: 'ฝึกรวมเสียงอ่านคำ',
      iconImagePath: '$_basePath/Lego.png',
      cardBg: Color(0xFFF0FDF4),
      accentColor: Color(0xFF10B981),
      bevelColor: Color(0xFF047857),
      items: [
        PhonicsCardItem(symbol: 'C-A-T', sampleWord: 'Cat', thaiSound: '/k/ + /æ/ + /t/', emoji: '🐱', imagePath: '$_basePath/Cat.png'),
        PhonicsCardItem(symbol: 'S-U-N', sampleWord: 'Sun', thaiSound: '/s/ + /ʌ/ + /n/', emoji: '☀️', imagePath: '$_basePath/Sun.png'),
        PhonicsCardItem(symbol: 'P-I-G', sampleWord: 'Pig', thaiSound: '/p/ + /ɪ/ + /g/', emoji: '🐷', imagePath: '$_basePath/Pig.png'),
        PhonicsCardItem(symbol: 'D-O-G', sampleWord: 'Dog', thaiSound: '/d/ + /ɒ/ + /g/', emoji: '🐶', imagePath: '$_basePath/Dog.png'),
        PhonicsCardItem(symbol: 'F-I-SH', sampleWord: 'Fish', thaiSound: '/f/ + /ɪ/ + /ʃ/', emoji: '🐟', imagePath: '$_basePath/Fish.png'),
      ],
    ),
    PhonicsCategoryModel(
      id: '06',
      title: 'รูปแบบคำและตัวสะกด',
      thaiDesc: 'ฝึก CVC และคำลงท้าย',
      iconImagePath: '$_basePath/Treasure.png',
      cardBg: Color(0xFFFFF0F5),
      accentColor: Color(0xFFFF4081),
      bevelColor: Color(0xFFB71C1C),
      items: [
        PhonicsCardItem(symbol: 'CVC Words', sampleWord: 'Cup', thaiSound: 'พยัญชนะ-สระ-พยัญชนะ', emoji: '🥤', imagePath: '$_basePath/Cup.png'),
        PhonicsCardItem(symbol: 'Blends (Bl-)', sampleWord: 'Blue', thaiSound: 'เสียงควบต้นคำ', emoji: '🔵', imagePath: '$_basePath/Blue.png'),
        PhonicsCardItem(symbol: 'Blends (St-)', sampleWord: 'Star', thaiSound: 'เสียงควบต้นคำ', emoji: '⭐', imagePath: '$_basePath/Star.png'),
        PhonicsCardItem(symbol: 'Ending (-nd)', sampleWord: 'Hand', thaiSound: 'เสียงควบท้ายคำ', emoji: '✋', imagePath: '$_basePath/Hand.png'),
        PhonicsCardItem(symbol: 'Ending (-st)', sampleWord: 'Best', thaiSound: 'เสียงควบท้ายคำ', emoji: '🥇', imagePath: '$_basePath/Best.png'),
        PhonicsCardItem(symbol: 'Silent E', sampleWord: 'Cake', thaiSound: 'สระเปลี่ยนเสียงเพราะ E ท้าย', emoji: '🍰', imagePath: '$_basePath/Cake.png'),
        PhonicsCardItem(symbol: 'R-controlled (ar)', sampleWord: 'Car', thaiSound: 'สระผสมตัว R', emoji: '🚗', imagePath: '$_basePath/Car.png'),
        PhonicsCardItem(symbol: 'R-controlled (ir)', sampleWord: 'Bird', thaiSound: 'สระผสมตัว R', emoji: '🐦', imagePath: '$_basePath/Bird.png'),
      ],
    ),
  ];

  @override
  State<PhonicsCategoryScreen> createState() => _PhonicsCategoryScreenState();
}

class _PhonicsCategoryScreenState extends State<PhonicsCategoryScreen> {
  static const List<PhonicsCategoryModel> categories =
      PhonicsCategoryScreen.categories;

  /// Practiced cards ('categoryId|word') for the "x/y" progress on each card.
  Set<String> _practiced = <String>{};

  @override
  void initState() {
    super.initState();
    _loadProgress();
    // Bring in progress saved from another phone, then refresh.
    PhonicsProgress.sync().then((_) => _loadProgress());
  }

  Future<void> _loadProgress() async {
    final done = await PhonicsProgress.practiced();
    if (mounted) setState(() => _practiced = done);
  }

  @override
  Widget build(BuildContext context) {
    // 1. สีน้ำเงินสดใส มีชีวิตชีวา สไตล์โมเดิร์น
    const Color vibrantBlue = Color(0xFF1976D2);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF90CAF9),
              Color(0xFFBCE3FD),
              Color(0xFFDDF2FD),
              Color(0xFFF0F9FF),
            ],
            stops: [0.0, 0.35, 0.70, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              // --- 1. AppBar สี่เหลี่ยมตัดตรง สีน้ำเงินสดใส ---
              AppBar(
                backgroundColor: vibrantBlue,
                elevation: 3,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'ฝึกออกเสียง',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              // --- 2. ส่วนหัวข้อ ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Text(
                      'เลือกด่านฝึกออกเสียง',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'แตะเพื่อเริ่มต้นฝึกออกเสียงทีละด่าน',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),

              // --- 3. รายการการ์ด 3D เควสด่านฝึกออกเสียง ---
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isLast = index == categories.length - 1;
                    return _buildColorfulQuestCard(context, cat, isLast);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressPill(PhonicsCategoryModel cat) {
    final done = cat.items
        .where((item) => PhonicsProgress.isDone(_practiced, cat.id, item.sampleWord))
        .length;
    return _progressPill(done: done, total: cat.items.length, accent: cat.accentColor);
  }

  Widget _buildColorfulQuestCard(BuildContext context, PhonicsCategoryModel cat, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 2. เส้นประปรับเป็นสีน้ำเงินตัดกับพื้นหลัง เห็นชัด ไม่กลืน
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3.5),
                    color: cat.accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: CustomPaint(
                      painter: DashedLinePainter(
                        // ใช้สีฟ้าน้ำทะเลเข้ม คมชัดบนพื้นสว่าง
                        color: const Color(0xFF0277BD).withOpacity(0.45),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ตัวการ์ด 3D
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: cat.cardBg,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: cat.bevelColor.withOpacity(0.85),
                    offset: const Offset(0, 6.5),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(26),
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhonicsPracticeScreen(
                          categoryId: cat.id,
                          categoryTitle: cat.title,
                          badgeColor: cat.accentColor,
                          items: cat.items,
                        ),
                      ),
                    ).then((_) => _loadProgress());
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        // วงกลมสีขาวโปร่งแสงรองหลังรูปภาพ
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Image.asset(
                            cat.iconImagePath,
                            width: 44,
                            height: 44,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.star_rounded, color: cat.accentColor, size: 32),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // ชื่อหมวดหมู่ + คำอธิบาย
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cat.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                cat.thaiDesc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildProgressPill(cat),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // ปุ่มลูกศร 3D นูน
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cat.accentColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: cat.bevelColor,
                                offset: const Offset(0, 3.5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// "ฝึกแล้ว x/y" pill; turns green with a tick when every card is done.
Widget _progressPill({
  required int done,
  required int total,
  required Color accent,
}) {
  final complete = total > 0 && done >= total;
  final color = complete ? const Color(0xFF16A34A) : accent;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          complete ? 'ฝึกครบแล้ว $done / $total' : 'ฝึกแล้ว $done / $total',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  const DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5 // เพิ่มความหนาของเส้นให้คมชัด
      ..strokeCap = StrokeCap.round // ปลายเส้นมน สวยงาม
      ..style = PaintingStyle.stroke;

    const dashHeight = 6.0;
    const dashSpace = 6.0;
    double startY = 4;

    while (startY < size.height - 4) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) => false;
}