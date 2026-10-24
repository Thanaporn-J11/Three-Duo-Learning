import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_tts/flutter_tts.dart';

// ============================================================================
// 1. หน้าเรียนรู้แฟลชการ์ด (OccupationsFlashcardsScreen)
// ============================================================================
class OccupationsFlashcardsScreen extends StatefulWidget {
  const OccupationsFlashcardsScreen({super.key});

  @override
  State<OccupationsFlashcardsScreen> createState() =>
      _OccupationsFlashcardsScreenState();
}

class _OccupationsFlashcardsScreenState
    extends State<OccupationsFlashcardsScreen>
    with SingleTickerProviderStateMixin {
  final FlutterTts flutterTts = FlutterTts();

  int currentCard = 0;
  bool isFlipped = false;
  bool isSpeaking = false;
  bool _ttsReady = false;

  late AnimationController _speakerPulseController;

  // รายการคำศัพท์แฟลชการ์ด
  late List<Map<String, String>> flashcards;

  final List<Map<String, String>> initialFlashcards = const [
    {
      'word': 'Accountant',
      'meaning': 'นักบัญชี',
      'image': 'assets/images/vocabulary/careers/Accountant.png',
    },
    {
      'word': 'Architect',
      'meaning': 'สถาปนิก',
      'image': 'assets/images/vocabulary/careers/Architect.png',
    },
    {
      'word': 'Artist',
      'meaning': 'ศิลปิน',
      'image': 'assets/images/vocabulary/careers/Artist.png',
    },
    {
      'word': 'Athlete',
      'meaning': 'นักกีฬา',
      'image': 'assets/images/vocabulary/careers/Athlete.png',
    },
    {
      'word': 'Carpenter',
      'meaning': 'ช่างไม้',
      'image': 'assets/images/vocabulary/careers/Carpenter.png',
    },
    {
      'word': 'Cashier',
      'meaning': 'แคชเชียร์',
      'image': 'assets/images/vocabulary/careers/Cashier.png',
    },
    {
      'word': 'Chef',
      'meaning': 'เชฟ / พ่อครัว',
      'image': 'assets/images/vocabulary/careers/Chef.png',
    },
    {
      'word': 'Dancer',
      'meaning': 'นักเต้น',
      'image': 'assets/images/vocabulary/careers/Dancer.png',
    },
    {
      'word': 'Dentist',
      'meaning': 'ทันตแพทย์',
      'image': 'assets/images/vocabulary/careers/Dentist.png',
    },
    {
      'word': 'Doctor',
      'meaning': 'หมอ',
      'image': 'assets/images/vocabulary/careers/Doctor.png',
    },
    {
      'word': 'Driver',
      'meaning': 'คนขับรถ',
      'image': 'assets/images/vocabulary/careers/Driver.png',
    },
    {
      'word': 'Electrician',
      'meaning': 'ช่างไฟ',
      'image': 'assets/images/vocabulary/careers/Electrician.png',
    },
    {
      'word': 'Engineer',
      'meaning': 'วิศวกร',
      'image': 'assets/images/vocabulary/careers/Engineer.png',
    },
    {
      'word': 'Farmer',
      'meaning': 'เกษตรกร',
      'image': 'assets/images/vocabulary/careers/Farmer.png',
    },
    {
      'word': 'Firefighter',
      'meaning': 'นักดับเพลิง',
      'image': 'assets/images/vocabulary/careers/Firefighter.png',
    },
    {
      'word': 'Fisherman',
      'meaning': 'ชาวประมง',
      'image': 'assets/images/vocabulary/careers/Fisherman.png',
    },
    {
      'word': 'Flight Attendant',
      'meaning': 'พนักงานต้อนรับบนเครื่องบิน',
      'image': 'assets/images/vocabulary/careers/Flight Attendant.png',
    },
    {
      'word': 'Journalist',
      'meaning': 'นักข่าว',
      'image': 'assets/images/vocabulary/careers/Journalist.png',
    },
    {
      'word': 'Lawyer',
      'meaning': 'ทนายความ',
      'image': 'assets/images/vocabulary/careers/Lawyer.png',
    },
    {
      'word': 'Mechanic',
      'meaning': 'ช่างเครื่องยนต์',
      'image': 'assets/images/vocabulary/careers/Mechanic.png',
    },
    {
      'word': 'Musician',
      'meaning': 'นักดนตรี',
      'image': 'assets/images/vocabulary/careers/Musician.png',
    },
    {
      'word': 'Nurse',
      'meaning': 'พยาบาล',
      'image': 'assets/images/vocabulary/careers/Nurse.png',
    },
    {
      'word': 'Pharmacist',
      'meaning': 'เภสัชกร',
      'image': 'assets/images/vocabulary/careers/Pharmacist.png',
    },
    {
      'word': 'Photographer',
      'meaning': 'ช่างภาพ',
      'image': 'assets/images/vocabulary/careers/Photographer.png',
    },
    {
      'word': 'Pilot',
      'meaning': 'นักบิน',
      'image': 'assets/images/vocabulary/careers/Pilot.png',
    },
    {
      'word': 'Plumber',
      'meaning': 'ช่างประปา',
      'image': 'assets/images/vocabulary/careers/Plumber.png',
    },
    {
      'word': 'Police Officer',
      'meaning': 'ตำรวจ',
      'image': 'assets/images/vocabulary/careers/Police Officer.png',
    },
    {
      'word': 'Postman',
      'meaning': 'บุรุษไปรษณีย์',
      'image': 'assets/images/vocabulary/careers/Postman.png',
    },
    {
      'word': 'Programmer',
      'meaning': 'โปรแกรมเมอร์',
      'image': 'assets/images/vocabulary/careers/Programmer.png',
    },
    {
      'word': 'Scientist',
      'meaning': 'นักวิทยาศาสตร์',
      'image': 'assets/images/vocabulary/careers/Scientist.png',
    },
    {
      'word': 'Singer',
      'meaning': 'นักร้อง',
      'image': 'assets/images/vocabulary/careers/Singer.png',
    },
    {
      'word': 'Soldier',
      'meaning': 'ทหาร',
      'image': 'assets/images/vocabulary/careers/Soldier.png',
    },
    {
      'word': 'Teacher',
      'meaning': 'ครู',
      'image': 'assets/images/vocabulary/careers/Teacher.png',
    },
    {
      'word': 'Veterinarian',
      'meaning': 'สัตวแพทย์',
      'image': 'assets/images/vocabulary/careers/Veterinarian.png',
    },
    {
      'word': 'Waiter',
      'meaning': 'พนักงานเสิร์ฟชาย',
      'image': 'assets/images/vocabulary/careers/Waiter.png',
    },
    {
      'word': 'Waitress',
      'meaning': 'พนักงานเสิร์ฟหญิง',
      'image': 'assets/images/vocabulary/careers/Waitress.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    flashcards = List.from(initialFlashcards);
    _speakerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      flutterTts.setStartHandler(() {
        if (!mounted) return;
        setState(() => isSpeaking = true);
      });

      flutterTts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() => isSpeaking = false);
      });

      flutterTts.setCancelHandler(() {
        if (!mounted) return;
        setState(() => isSpeaking = false);
      });

      flutterTts.setErrorHandler((message) {
        if (!mounted) return;
        setState(() => isSpeaking = false);
        debugPrint('TTS Error: $message');
      });

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await flutterTts.setSharedInstance(true);
        await flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }

      final isAvailable =
          await flutterTts.isLanguageAvailable('en-US') as bool? ?? true;

      await flutterTts.setLanguage(isAvailable ? 'en-US' : 'en-GB');
      await flutterTts.setSpeechRate(0.40);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.1);
      await flutterTts.setQueueMode(0);

      _ttsReady = true;
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      _ttsReady = false;
    }
  }

  @override
  void dispose() {
    _speakerPulseController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  Future<void> speakWord() async {
    final word = flashcards[currentCard]['word']!;
    try {
      if (isSpeaking) {
        await flutterTts.stop();
        if (mounted) setState(() => isSpeaking = false);
        return;
      }
      if (!_ttsReady) await _initTts();

      await flutterTts.stop();
      await flutterTts.setLanguage('en-US');
      await flutterTts.setSpeechRate(0.40);
      await flutterTts.setPitch(1.1);
      await flutterTts.speak(word);
    } catch (e) {
      debugPrint('Speak word error: $e');
      if (mounted) setState(() => isSpeaking = false);
    }
  }

  Future<void> speakThaiWord() async {
    final meaning = flashcards[currentCard]['meaning']!;
    try {
      if (isSpeaking) {
        await flutterTts.stop();
        if (mounted) setState(() => isSpeaking = false);
        return;
      }
      if (!_ttsReady) await _initTts();

      await flutterTts.stop();
      final isThaiAvailable =
          await flutterTts.isLanguageAvailable('th-TH') as bool? ?? false;

      if (!isThaiAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFFF7043),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: const Text(
                'เครื่องนี้ยังไม่มีระบบเสียงภาษาไทย',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
        return;
      }

      await flutterTts.setLanguage('th-TH');
      await flutterTts.setSpeechRate(0.40);
      await flutterTts.setPitch(1.1);
      await flutterTts.speak(meaning);
    } catch (e) {
      debugPrint('Speak Thai error: $e');
      if (mounted) setState(() => isSpeaking = false);
    }
  }

  // ฟังก์ชันย้อนกลับไปคำศัพท์ก่อนหน้า
  Future<void> previousCard() async {
    await flutterTts.stop();
    if (currentCard > 0) {
      setState(() {
        currentCard--;
        isFlipped = false;
        isSpeaking = false;
      });
      speakWord();
    }
  }

  // ฟังก์ชันถัดไป
  Future<void> handleNextOrFinish() async {
    await flutterTts.stop();
    if (currentCard < flashcards.length - 1) {
      setState(() {
        currentCard++;
        isFlipped = false;
        isSpeaking = false;
      });
      speakWord();
    } else {
      if (context.mounted) {
        _showCompletionDialog();
      }
    }
  }

  // ฟังก์ชันสุ่มการ์ด (Shuffle)
  void shuffleCards() {
    flutterTts.stop();
    setState(() {
      flashcards.shuffle();
      currentCard = 0;
      isFlipped = false;
      isSpeaking = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFFF7043),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text(
          '🎲 สุ่มคำศัพท์เรียบร้อยแล้ว!',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
    speakWord();
  }

  void flipCard() {
    setState(() {
      isFlipped = !isFlipped;
    });
    if (isFlipped) {
      speakThaiWord();
    } else {
      speakWord();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        backgroundColor: const Color(0xFFFFFBEB),
        title: const Column(
          children: [
            Text(
              'เก่งมากเลยเด็ก ๆ',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFF7043),
              ),
            ),
          ],
        ),
        content: const Text(
          'เรียนรู้คำศัพท์หมวดอาชีพครบแล้ว!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 6,
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                'กลับหน้าหลัก',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = flashcards[currentCard];
    final bool isLastCard = currentCard == flashcards.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      body: _GameScaffoldBody(
        title: 'อาชีพในฝัน',
        color: const Color(0xFFFF7043),
        onBack: () async {
          await flutterTts.stop();
          if (context.mounted) Navigator.pop(context);
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              children: [
                // แถวบน: Progress Bar + ตัวเลข + ปุ่มสุ่ม + เหรียญ
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 14,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFFCC80), width: 1.5),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final progressWidth = (constraints.maxWidth *
                                ((currentCard + 1) / flashcards.length));
                            return Stack(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: progressWidth,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF00E676),
                                        Color(0xFF00C853)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7043),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${currentCard + 1} / ${flashcards.length}', // เพิ่มช่องว่างข้างเครื่องหมาย /
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: shuffleCards,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFFFB74D), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6D00).withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shuffle_rounded,
                          color: Color(0xFFFF6D00),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _CoinPill(fontSize: 14),
                  ],
                ),

                const SizedBox(height: 14),

                // Main Interactive Flashcard
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360, maxHeight: 520),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: GestureDetector(
                    onTap: flipCard,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: Tween<double>(begin: 0.90, end: 1.0)
                              .animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        key: ValueKey('${currentCard}_$isFlipped'),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isFlipped
                                ? const Color(0xFF00C853)
                                : const Color(0xFFFF7043),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isFlipped
                                      ? const Color(0xFF00C853)
                                      : const Color(0xFFFF7043))
                                  .withOpacity(0.22),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: isFlipped
                                ? _buildBackCard(card)
                                : _buildFrontCard(card),
                          ),
                        ),
                      ),
                    ),
                  ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ปุ่มนำทางด้านล่าง (ก่อนหน้า / คำถัดไป) ตามดีไซน์
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (currentCard > 0) ...[
                      _NavPillButton(
                        label: 'ก่อนหน้า',
                        width: 132,
                        onTap: previousCard,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE6F1FF), Color(0xFFD6E8FF)],
                        ),
                        borderColor: const Color(0xFF7FB2F5),
                        textColor: const Color(0xFF1D4ED8),
                        shadowColor: const Color(0xFF7FB2F5),
                      ),
                      const SizedBox(width: 18),
                    ],
                    _NavPillButton(
                      label: isLastCard ? 'เสร็จสิ้น' : 'คำถัดไป',
                      width: isLastCard ? 170 : 140,
                      onTap: handleNextOrFinish,
                      gradient: isLastCard
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF00E676), Color(0xFF00C853)],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF78F6E), Color(0xFFFF3E01)],
                            ),
                      borderColor: null,
                      textColor: Colors.white,
                      shadowColor: isLastCard
                          ? const Color(0xFF00C853)
                          : const Color(0xFFFF511A),
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

  Widget _buildFrontCard(Map<String, String> card) {
    return Column(
      children: [
        // กรอบกระดาษรูปภาพสีขาวล้วน
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFFF1F5F9),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: const Alignment(0, 0.55),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FractionallySizedBox(
                      widthFactor: 0.74,
                      heightFactor: 0.74,
                      child: Image.asset(
                        card['image']!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.work_rounded,
                            size: 56,
                            color: Color(0xFFFF7043),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFFFB74D), width: 1.5),
                    ),
                    child: const Text(
                      'English',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF57C00),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ศัพท์อังกฤษ + ปุ่มลำโพง
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  card['word']!,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: speakWord,
              child: AnimatedBuilder(
                animation: _speakerPulseController,
                builder: (context, child) {
                  final scale = isSpeaking
                      ? 1.0 + (_speakerPulseController.value * 0.15)
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7043), Color(0xFFFF511A)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF7043).withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isSpeaking
                            ? Icons.volume_up_rounded
                            : Icons.volume_up_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // แถบสัมผัสเพื่อดูคำแปล
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_rounded,
                  color: Color(0xFFF57C00), size: 18),
              SizedBox(width: 6),
              Text(
                'แตะการ์ดเพื่อดูคำแปล',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF57C00),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildBackCard(Map<String, String> card) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFFF1F5F9),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: const Alignment(0, 0.55),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FractionallySizedBox(
                      widthFactor: 0.74,
                      heightFactor: 0.74,
                      child: Image.asset(
                        card['image']!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.work_rounded,
                            size: 56,
                            color: Color(0xFF00C853),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF81C784), width: 1.5),
                    ),
                    child: const Text(
                      'ภาษาไทย',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // คำแปลไทย
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  card['meaning']!,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF00C853),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: speakThaiWord,
              child: AnimatedBuilder(
                animation: _speakerPulseController,
                builder: (context, child) {
                  final scale = isSpeaking
                      ? 1.0 + (_speakerPulseController.value * 0.15)
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E676), Color(0xFF00C853)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C853).withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isSpeaking
                            ? Icons.volume_up_rounded
                            : Icons.volume_up_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF81C784), width: 1.5),
          ),
          child: const Text(
            'แตะเพื่อพลิกกลับ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF00C853),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ---------------------------------------------------------------
// ปุ่มทรงแคปซูลสำหรับ ก่อนหน้า / คำถัดไป
// ---------------------------------------------------------------
class _NavPillButton extends StatelessWidget {
  final String label;
  final double width;
  final VoidCallback onTap;
  final Gradient gradient;
  final Color? borderColor;
  final Color textColor;
  final Color shadowColor;

  const _NavPillButton({
    required this.label,
    required this.width,
    required this.onTap,
    required this.gradient,
    required this.borderColor,
    required this.textColor,
    required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 46,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(30),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// ป้ายแสดงเหรียญ (UI อย่างเดียว ไม่มีระบบเก็บเหรียญ)
// ---------------------------------------------------------------
class _CoinPill extends StatelessWidget {
  final int coins;
  final Color color;
  final double fontSize;

  const _CoinPill({
    // ignore: unused_element_parameter
    this.coins = 0,
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
            color: Colors.black.withOpacity(0.12),
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
          Text(
            '$coins',
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
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