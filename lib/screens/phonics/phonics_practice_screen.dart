import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/phonics_progress_service.dart';

class PhonicsCardItem {
  final String symbol;      // เช่น sh /ʃ/, th /θ/, C-A-T, ai, CVC Words, /b/
  final String sampleWord;  // คำศัพท์ตัวอย่าง เช่น Ship, Cat, Rain, Cup
  final String thaiSound;   // เสียงอ่านภาษาไทย
  final String emoji;       
  final String imagePath;   

  const PhonicsCardItem({
    required this.symbol,
    required this.sampleWord,
    required this.thaiSound,
    required this.emoji,
    this.imagePath = '',
  });

  String get upperLetter {
    if (sampleWord.isNotEmpty) {
      return sampleWord[0].toUpperCase();
    }
    return symbol.replaceAll('/', '').trim().toUpperCase();
  }

  String get letterPair {
    final up = upperLetter;
    return '$up${up.toLowerCase()}';
  }

  // ตัวอักษรหรือข้อความหลักที่จะโชว์ตัวใหญ่บน Flashcard Dialog
  String get flashcardTitle {
    // 1. หมวดรูปแบบคำและตัวสะกดที่มีวงเล็บ เช่น "Blends (Bl-)" -> "Bl-", "Ending (-nd)" -> "-nd"
    if (symbol.contains('(') && symbol.contains(')')) {
      final startIndex = symbol.indexOf('(') + 1;
      final endIndex = symbol.indexOf(')');
      final content = symbol.substring(startIndex, endIndex).trim();
      if (content.isNotEmpty) {
        return content;
      }
    }

    // 2. หมวด CVC Words
    if (symbol.toUpperCase().contains('CVC')) {
      return 'CVC';
    }

    // 3. หมวด Silent E
    if (symbol.toLowerCase().contains('silent e')) {
      return '-e';
    }

    // 4. หมวด R-controlled
    if (symbol.toLowerCase().contains('r-controlled')) {
      if (sampleWord.toLowerCase().contains('car')) return 'ar';
      if (sampleWord.toLowerCase().contains('bird')) return 'ir';
      return 'r-sound';
    }

    // 5. หมวดฝึกผสมเสียงอ่านคำ เช่น "C-A-T" -> "Cat", "F-I-SH" -> "Fish"
    if (symbol.contains('-')) {
      return sampleWord.isNotEmpty ? sampleWord : symbol;
    }

    // 6. หมวดพยัญชนะคู่ เช่น "th /θ/" -> "Th", "sh /ʃ/" -> "Sh", "wh /w/" -> "Wh"
    if (symbol.contains('/')) {
      final lead = symbol.split('/')[0].trim();
      if (lead.isNotEmpty && lead.length <= 4 && !lead.contains('Short') && !lead.contains('Long')) {
        return lead[0].toUpperCase() + lead.substring(1);
      }
    }

    // 7. หมวดสระคู่ เช่น "ai" -> "Ai", "ee" -> "Ee"
    if (!symbol.contains('/') && symbol.length <= 3) {
      return symbol[0].toUpperCase() + symbol.substring(1);
    }

    // 8. หมวดพยัญชนะเดี่ยวและสระทั่วไป เช่น "A" -> "Aa", "B" -> "Bb"
    if (sampleWord.isNotEmpty) {
      final up = sampleWord[0].toUpperCase();
      return '$up${up.toLowerCase()}';
    }

    return symbol;
  }

  // ดึงเฉพาะเสียง Phonics เช่น "/θ/", "/w/", "/ʃ/", "/æ/"
  String get displayPhonicsOnly {
    if (symbol.contains('/')) {
      final startIndex = symbol.indexOf('/');
      return symbol.substring(startIndex).trim();
    }
    return symbol;
  }

  // ดึงป้ายกำกับด้านบน
  String get tagLabel {
    if (symbol.contains('/')) {
      final startIndex = symbol.indexOf('/');
      return symbol.substring(0, startIndex).trim();
    }
    return symbol;
  }
}

class PhonicsPracticeScreen extends StatefulWidget {
  /// '01'..'06', used to save progress (see PhonicsProgress).
  final String categoryId;
  final String categoryTitle;
  final Color badgeColor;
  final List<PhonicsCardItem> items;

  const PhonicsPracticeScreen({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    required this.badgeColor,
    required this.items,
  });

  @override
  State<PhonicsPracticeScreen> createState() => _PhonicsPracticeScreenState();
}

class _PhonicsPracticeScreenState extends State<PhonicsPracticeScreen> {
  final FlutterTts flutterTts = FlutterTts();

  final List<Map<String, Color>> toyColors = const [
    {'top': Color(0xFFE53935), 'bevel': Color(0xFFB71C1C)}, // แดง
    {'top': Color(0xFF0288D1), 'bevel': Color(0xFF01579B)}, // ฟ้า
    {'top': Color(0xFF2E7D32), 'bevel': Color(0xFF1B5E20)}, // เขียว
    {'top': Color(0xFFF57C00), 'bevel': Color(0xFFE65100)}, // ส้ม
    {'top': Color(0xFF7B1FA2), 'bevel': Color(0xFF4A148C)}, // ม่วง
    {'top': Color(0xFFC2185B), 'bevel': Color(0xFF880E4F)}, // ชมพู
    {'top': Color(0xFF0097A7), 'bevel': Color(0xFF006064)}, // เขียวน้ำทะเล
  ];

  /// Cards already practiced ('categoryId|word'), for the ticks.
  Set<String> _practiced = <String>{};

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadPracticed();
  }

  Future<void> _loadPracticed() async {
    final done = await PhonicsProgress.practiced();
    if (mounted) setState(() => _practiced = done);
  }

  Future<void> _initTts() async {
    await flutterTts.setSpeechRate(0.35);
    await flutterTts.setPitch(1.20);
  }

  Future<void> _openInteractiveFlashcard(int initialIndex) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PhonicsFlashcardDialog(
        items: widget.items,
        initialIndex: initialIndex,
        toyColors: toyColors,
        flutterTts: flutterTts,
        categoryId: widget.categoryId,
        categoryTitle: widget.categoryTitle,
      ),
    );
    _loadPracticed(); // refresh the ticks
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isBlending = widget.categoryTitle.contains('ผสม');
    final bool isPattern = widget.categoryTitle.contains('รูปแบบคำ') || widget.categoryTitle.contains('ตัวสะกด');
    final bool isVowelPair = widget.categoryTitle.contains('สระคู่');
    final bool isShortLongVowel = widget.categoryTitle.contains('สระสั้น');
    final bool isConsonantPair = widget.categoryTitle.contains('พยัญชนะคู่');

    // จัดการไล่เฉดสีพื้นหลังแยกตามแต่ละหมวดให้อ่อนนุ่ม ละมุนตา ไม่เข้มทึบและไม่ขาวโพลน
    List<Color> backgroundGradient;
    if (isPattern) {
      // หมวดที่ 6 (รูปแบบคำและตัวสะกด): ชมพูพีชพาสเทลอ่อนละมุน นุ่มนวลตา
      backgroundGradient = const [
        Color(0xFFFDE8E9),
        Color(0xFFFDF0F2),
        Color(0xFFFFF7F8),
      ];
    } else if (isBlending) {
      // หมวดที่ 5 (ฝึกผสมเสียงอ่านคำ): เขียวมินต์พาสเทลอ่อนๆ สดชื่นสบายตา
      backgroundGradient = const [
        Color(0xFFD1FAE5),
        Color(0xFFE6FBF0),
        Color(0xFFF2FDF7),
      ];
    } else if (isVowelPair) {
      // หมวดที่ 4 (เสียงสระคู่): ม่วงลาเวนเดอร์พาสเทล
      backgroundGradient = const [
        Color(0xFFE9D8FD),
        Color(0xFFF3E8FF),
        Color(0xFFFAF5FF),
      ];
    } else if (isShortLongVowel) {
      // หมวดที่ 2 (เสียงสระสั้น - ยาว): เหลืองทองอุ่น
      backgroundGradient = const [
        Color(0xFFFFECB3),
        Color(0xFFFFF3CD),
        Color(0xFFFFF8E1),
      ];
    } else if (isConsonantPair) {
      // หมวดที่ 3 (เสียงพยัญชนะคู่): ฟ้าสดชื่นพาสเทล
      backgroundGradient = const [
        Color(0xFFB2EBF2),
        Color(0xFFD0F4F7),
        Color(0xFFE0F7FA),
      ];
    } else {
      // หมวดที่ 1 (เสียงพยัญชนะ A-Z)
      backgroundGradient = [
        widget.badgeColor.withValues(alpha: 0.18),
        widget.badgeColor.withValues(alpha: 0.08),
        Colors.white.withValues(alpha: 0.95),
      ];
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: backgroundGradient,
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              AppBar(
                backgroundColor: widget.badgeColor,
                elevation: 2,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  widget.categoryTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              // ตาราง Grid การ์ด (หมวดผสมเสียงคำแสดง 2 คอลัมน์ หมวดอื่นแสดง 3 คอลัมน์)
              Expanded(
                child: GridView.builder(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isBlending ? 18 : 14,
                    16,
                    isBlending ? 18 : 14,
                    24,
                  ),
                  itemCount: widget.items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isBlending ? 2 : 3,
                    crossAxisSpacing: isBlending ? 16 : 12,
                    mainAxisSpacing: isBlending ? 16 : 14,
                    childAspectRatio: isBlending ? 0.80 : 0.72,
                  ),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final theme = toyColors[index % toyColors.length];

                    final done = PhonicsProgress.isDone(
                      _practiced,
                      widget.categoryId,
                      item.sampleWord,
                    );
                    return GestureDetector(
                      onTap: () => _openInteractiveFlashcard(index),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                      Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme['bevel'],
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: theme['bevel']!.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.only(bottom: 5.5),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme['top'],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: EdgeInsets.all(isBlending ? 10 : 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // ป้ายด้านบนในการ์ด
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  vertical: isBlending ? 5 : 4,
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1.5)),
                                  ],
                                ),
                                child: (isPattern || isShortLongVowel)
                                    ? Center(
                                        // หมวดรูปแบบคำ และ หมวดสระสั้น-ยาว แสดงชื่อสระ/รูปแบบตรงๆ กึ่งกลาง ไม่เอาอักษรหน้าคำศัพท์มาแปะซ้ำ
                                        child: Text(
                                          item.symbol,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: isShortLongVowel ? 12 : 11.5,
                                            fontWeight: FontWeight.w900,
                                            color: theme['top'],
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      )
                                    : (isVowelPair || isBlending || isConsonantPair)
                                        ? Center(
                                            // หมวดสระคู่, ผสมเสียงคำ และพยัญชนะคู่ แสดงสัญลักษณ์ตรงกลางพอดี ไม่ซ้ำตัวอักษรหน้า
                                            child: Text(
                                              item.symbol,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: isBlending ? 16 : (isConsonantPair ? 13 : 16),
                                                fontWeight: FontWeight.w900,
                                                color: theme['top'],
                                                letterSpacing: isBlending ? 0.8 : 0.2,
                                              ),
                                            ),
                                          )
                                        : Row(
                                            // หมวดที่ 1 (A-Z) แสดงคู่ตัวอักษรสีตามธีมและสัญลักษณ์เสียงอย่างถูกต้อง
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                item.upperLetter,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                  color: theme['top'],
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  item.symbol,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF0F172A),
                                                    letterSpacing: -0.3,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                              ),

                              Expanded(
                                child: Center(
                                  child: item.imagePath.isNotEmpty
                                      ? Image.asset(
                                          item.imagePath,
                                          width: isBlending ? 96 : 66,
                                          height: isBlending ? 96 : 66,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Icon(Icons.star_rounded, color: Colors.white, size: isBlending ? 46 : 34),
                                        )
                                      : Icon(Icons.star_rounded, color: Colors.white, size: isBlending ? 46 : 34),
                                ),
                              ),

                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: isBlending ? 5 : 3.5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1.5)),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item.sampleWord,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isBlending ? 16 : 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ),
                          // Practiced already: small green tick.
                          if (done)
                            Positioned(
                              top: -5,
                              right: -5,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1.5)),
                                  ],
                                ),
                                child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// Flashcard Dialog
// ----------------------------------------------------
class PhonicsFlashcardDialog extends StatefulWidget {
  final List<PhonicsCardItem> items;
  final int initialIndex;
  final List<Map<String, Color>> toyColors;
  final FlutterTts flutterTts;
  final String categoryId;
  final String categoryTitle;

  const PhonicsFlashcardDialog({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.toyColors,
    required this.flutterTts,
    required this.categoryId,
    required this.categoryTitle,
  });

  @override
  State<PhonicsFlashcardDialog> createState() => _PhonicsFlashcardDialogState();
}

class _PhonicsFlashcardDialogState extends State<PhonicsFlashcardDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late int _currentIndex;
  bool _isBack = false;

  PhonicsCardItem get currentItem => widget.items[_currentIndex];
  Map<String, Color> get currentTheme =>
      widget.toyColors[_currentIndex % widget.toyColors.length];

  bool get isBlending => widget.categoryTitle.contains('ผสม');
  bool get isPattern =>
      widget.categoryTitle.contains('รูปแบบคำ') || widget.categoryTitle.contains('ตัวสะกด');
  bool get isConsonantPair => widget.categoryTitle.contains('พยัญชนะคู่');
  bool get isShortLongVowel => widget.categoryTitle.contains('สระสั้น') || widget.categoryTitle.contains('สระเดี่ยว');

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _speakPhonicsSound();
  }

  Future<void> _speakPhonicsSound() async {
    await widget.flutterTts.stop();
    await widget.flutterTts.setLanguage("th-TH");

    String soundToSpeak = currentItem.thaiSound;
    if (soundToSpeak.contains('(')) {
      soundToSpeak = soundToSpeak.split('(')[0].trim();
    }

    soundToSpeak = soundToSpeak.replaceAll('+', ' ผสม ');
    soundToSpeak = soundToSpeak.replaceAll('-', ' ');
    soundToSpeak = soundToSpeak.replaceAll('/', ' ');

    await widget.flutterTts.speak(soundToSpeak);
  }

  Future<void> _speakWordSound() async {
    await widget.flutterTts.stop();
    await widget.flutterTts.setLanguage("en-US");
    await widget.flutterTts.speak(currentItem.sampleWord);
  }

  void _flipCard() {
    if (_isBack) {
      _controller.reverse();
      _isBack = false;
      _speakPhonicsSound();
    } else {
      _controller.forward();
      _isBack = true;
      _speakWordSound();
      // Heard the sound and the word: counts as practiced.
      PhonicsProgress.markPracticed(widget.categoryId, currentItem.sampleWord);
    }
    setState(() {});
  }

  void _goToPreviousWord() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isBack = false;
        _controller.reset();
      });
      _speakPhonicsSound();
    }
  }

  void _goToNextWord() {
    // Moving on from a card also counts it as practiced.
    PhonicsProgress.markPracticed(widget.categoryId, currentItem.sampleWord);
    if (_currentIndex < widget.items.length - 1) {
      setState(() {
        _currentIndex++;
        _isBack = false;
        _controller.reset();
      });
      _speakPhonicsSound();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isUnder = angle > (pi / 2);

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isUnder
                ? Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildRealisticFlashcard(isBack: true),
                  )
                : _buildRealisticFlashcard(isBack: false),
          );
        },
      ),
    );
  }

  Widget _buildRealisticFlashcard({required bool isBack}) {
    final cardColor = currentTheme['top']!;
    final bevelColor = currentTheme['bevel']!;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 525,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: bevelColor,
            offset: const Offset(0, 7),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            offset: const Offset(0, 10),
            blurRadius: 16,
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: bevelColor,
                            offset: const Offset(0, 2.5),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),

                // ตัวอักษรใหญ่บน Flashcard (เช่น Th, Cat, -nd, Ba, Bb)
                Text(
                  currentItem.flashcardTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: (isBlending || isPattern) ? 52 : 68,
                    fontWeight: FontWeight.w900,
                    color: cardColor,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),

                const SizedBox(height: 16),

                isBack
                    ? _buildBackWordContent(cardColor, bevelColor)
                    : _buildFrontPhonicsContent(cardColor, bevelColor),
              ],
            ),

            const SizedBox(height: 28),

            if (!isBack)
              _currentIndex == 0
                  ? GestureDetector(
                      onTap: _flipCard,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: bevelColor,
                              offset: const Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'ตัวอย่างคำศัพท์',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _goToPreviousWord,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardColor.withValues(alpha: 0.6), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: cardColor.withValues(alpha: 0.35),
                                    offset: const Offset(0, 3.5),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'ตัวก่อนหน้า',
                                  style: TextStyle(
                                    color: cardColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: GestureDetector(
                            onTap: _flipCard,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: bevelColor,
                                    offset: const Offset(0, 3.5),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'ตัวอย่างคำศัพท์',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
            else
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _flipCard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardColor.withValues(alpha: 0.6), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: cardColor.withValues(alpha: 0.35),
                              offset: const Offset(0, 3.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'ฟังเสียงอ่าน',
                            style: TextStyle(
                              color: cardColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: GestureDetector(
                      onTap: _goToNextWord,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: bevelColor,
                              offset: const Offset(0, 3.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _currentIndex < widget.items.length - 1 ? 'คำถัดไป' : 'เสร็จสิ้น',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // หน้า 1: ออกเสียง Phonics
  Widget _buildFrontPhonicsContent(Color cardColor, Color bevelColor) {
    String rawSound = currentItem.thaiSound;
    String mainSound = rawSound;
    String subHint = '';

    // ตรวจสอบวงเล็บ (...) ทั่วไป
    if (rawSound.contains('(')) {
      final parts = rawSound.split('(');
      mainSound = parts[0].trim();
      subHint = '(${parts[1].trim()}';
    }

    // กรณีหมวดที่ 6 (รูปแบบคำ): ถ้าข้อความยาว เช่น "สระเปลี่ยนเสียงเพราะ E ท้าย" หรือ "พยัญชนะ-สระ-พยัญชนะ"
    // ให้แยกคำว่า "ออกเสียง" ไว้บรรทัดบน แล้วนำข้อความอธิบายทั้งหมดลงมาไว้บรรทัดล่างอย่างเป็นระเบียบ
    final bool isLongPatternDesc = isPattern && (rawSound.length > 10 || rawSound.contains('-') || rawSound.contains(' '));

    return Column(
      children: [
        GestureDetector(
          onTap: _speakPhonicsSound,
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: cardColor, width: 3.5),
            ),
            alignment: Alignment.center,
            child: isBlending
                ? _buildBlendingCircleContent(cardColor)
                : isPattern
                    ? _buildPatternCircleContent(cardColor, bevelColor)
                    : isConsonantPair
                        ? _buildConsonantPairCircleContent(cardColor)
                        : _buildGeneralCircleContent(cardColor, bevelColor),
          ),
        ),

        const SizedBox(height: 20),

        // ป้ายแสดงเสียงอ่านภาษาไทย
        GestureDetector(
          onTap: _speakPhonicsSound,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 310),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: bevelColor.withValues(alpha: 0.3),
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: isLongPatternDesc
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // บรรทัดบน: "ออกเสียง" พร้อมลำโพง
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ออกเสียง',
                            style: TextStyle(
                              fontSize: 18.5,
                              fontWeight: FontWeight.w900,
                              color: cardColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.volume_up_rounded, color: cardColor, size: 22),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // บรรทัดล่าง: ข้อความอธิบายรูปแบบคำกึ่งกลางพอดี ไม่หลุดคำเดี่ยวๆ
                      Text(
                        rawSound,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: cardColor.withValues(alpha: 0.95),
                          height: 1.15,
                        ),
                      ),
                    ],
                  )
                : subHint.isNotEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // บรรทัดที่ 1: เสียงหลัก + ลำโพง
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'ออกเสียง  $mainSound',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: (isBlending || isPattern) ? 17 : 20.5,
                                    fontWeight: FontWeight.w900,
                                    color: cardColor,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.volume_up_rounded, color: cardColor, size: 24),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // บรรทัดที่ 2: ข้อความในวงเล็บอยู่ตรงกลางพอดี
                          Text(
                            subHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: cardColor.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'ออกเสียง  $mainSound',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: (isBlending || isPattern) ? 16 : 20.5,
                                fontWeight: FontWeight.w900,
                                color: cardColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.volume_up_rounded, color: cardColor, size: 24),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  // วิดเจ็ตสำหรับหมวดพยัญชนะคู่
  Widget _buildConsonantPairCircleContent(Color cardColor) {
    return Center(
      child: Text(
        currentItem.displayPhonicsOnly,
        style: TextStyle(
          fontSize: 68,
          fontWeight: FontWeight.w900,
          color: cardColor,
          letterSpacing: -1.0,
          height: 1.0,
        ),
      ),
    );
  }

  // วิดเจ็ตสำหรับหมวดที่ 6 (รูปแบบคำและตัวสะกด): บล็อกคำกระชับสวยงาม ไม่ล้นวงกลม
  Widget _buildPatternCircleContent(Color cardColor, Color bevelColor) {
    String text = currentItem.symbol;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: bevelColor.withValues(alpha: 0.4),
                      offset: const Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // บล็อกสี่เหลี่ยมสีตามการ์ด ตัวอักษรสีขาวล้วน สไตล์ 3D หมวดที่ 5
  Widget _buildBlendingCircleContent(Color cardColor) {
    final letters = currentItem.symbol.split('-');
    final bevelColor = currentTheme['bevel']!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: letters.asMap().entries.map((entry) {
            final idx = entry.key;
            final char = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: bevelColor.withValues(alpha: 0.4),
                        offset: const Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    char,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
                if (idx < letters.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '-',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: cardColor,
                      ),
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGeneralCircleContent(Color cardColor, Color bevelColor) {
    final bool isPairVowel = !currentItem.symbol.contains('/') && currentItem.symbol.length <= 3;

    if (isPairVowel) {
      return Text(
        currentItem.symbol,
        style: TextStyle(
          fontSize: 62,
          fontWeight: FontWeight.w900,
          color: cardColor,
          letterSpacing: -1.0,
          height: 1.0,
        ),
      );
    }

    if (isShortLongVowel) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (currentItem.tagLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: bevelColor.withValues(alpha: 0.35),
                    offset: const Offset(0, 2.5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                currentItem.tagLabel,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  height: 1.0,
                ),
              ),
            ),
          Text(
            currentItem.displayPhonicsOnly,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: cardColor,
              letterSpacing: -1.0,
              height: 1.0,
            ),
          ),
        ],
      );
    }

    return Text(
      currentItem.symbol,
      style: TextStyle(
        fontSize: 66,
        fontWeight: FontWeight.w900,
        color: cardColor,
        letterSpacing: -1.0,
        height: 1.0,
      ),
    );
  }

  // หน้า 2: ตัวอย่างคำศัพท์
  Widget _buildBackWordContent(Color cardColor, Color bevelColor) {
    return Column(
      children: [
        GestureDetector(
          onTap: _speakWordSound,
          child: SizedBox(
            width: 170,
            height: 170,
            child: Center(
              child: currentItem.imagePath.isNotEmpty
                  ? Image.asset(
                      currentItem.imagePath,
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.image_outlined, size: 80, color: cardColor),
                    )
                  : Icon(Icons.image_outlined, size: 80, color: cardColor),
            ),
          ),
        ),

        const SizedBox(height: 18),

        GestureDetector(
          onTap: _speakWordSound,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                currentItem.sampleWord,
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  color: cardColor,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.volume_up_rounded,
                color: cardColor,
                size: 40,
              ),
            ],
          ),
        ),
      ],
    );
  }
}