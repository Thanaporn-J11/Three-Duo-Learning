import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../services/coin_balance.dart';
import '../../widgets/coin_balance_chip.dart';
import '../../models/exercise_attempt.dart';
import '../../services/exercise_api_service.dart';
import 'quiz_result_screen.dart';

class VocabularyQuizScreen extends StatefulWidget {
  final String categoryTitle;
  final ExerciseAttempt attempt;

  const VocabularyQuizScreen({
    super.key,
    required this.categoryTitle,
    required this.attempt,
  });

  @override
  State<VocabularyQuizScreen> createState() => _VocabularyQuizScreenState();
}

class _VocabularyQuizScreenState extends State<VocabularyQuizScreen> {
  int currentIndex = 0;
  String? selectedOptionId;
  ExerciseAnswerFeedback? answerFeedback;
  bool isSavingAnswer = false;
  bool isSubmittingAttempt = false;
  String? answerError;
  String? submitError;
  final Set<String> answeredQuestionIds = <String>{};

  static const _ink = Color(0xFF0D5C9E);

  @override
  void initState() {
    super.initState();
    final unansweredIndex =
        widget.attempt.questions.indexWhere((question) => question.feedback == null);
    answeredQuestionIds.addAll(
      widget.attempt.questions
          .where((question) => question.feedback != null)
          .map((question) => question.id),
    );
    currentIndex = unansweredIndex >= 0
        ? unansweredIndex
        : widget.attempt.questions.length - 1;
    answerFeedback = widget.attempt.questions[currentIndex].feedback;
    selectedOptionId = answerFeedback?.selectedOptionId;
  }

  // ฟังก์ชันตัวช่วยสำหรับแสดงได้ทั้ง รูปภาพไฟล์ และ แผ่นสี (Color Box)
  Widget _buildMediaContent(String? mediaPath,
      {double? width, double? height, double radius = 18}) {
    if (mediaPath == null || mediaPath.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    // กรณีเป็นแผ่นสีของหมวดสีสัน (color:xxxxxxx)
    if (mediaPath.startsWith('color:')) {
      final colorHexStr = mediaPath.replaceFirst('color:', '');
      final int? colorInt = int.tryParse(colorHexStr);
      final boxColor = colorInt != null ? Color(colorInt) : Colors.transparent;

      return Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: boxColor == const Color(0xFFFFFFFF)
                ? const Color(0xFFE2E8F0)
                : Colors.white,
            width: 3.5,
          ),
          boxShadow: [
            BoxShadow(
              color: boxColor.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
      );
    }

    // กรณีเป็นไฟล์ภาพของหมวดอื่นๆ ปกติ
    return Image.asset(
      mediaPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.image_not_supported_rounded,
          size: 48,
          color: Colors.grey),
    );
  }

  Future<void> _checkAnswer() async {
    final currentQuestion = widget.attempt.questions[currentIndex];
    final optionId = selectedOptionId;
    if (optionId == null || isSavingAnswer || answerFeedback != null) return;

    setState(() {
      isSavingAnswer = true;
      answerError = null;
    });
    try {
      final response = await ExerciseApiService.submitAnswer(
        attemptId: widget.attempt.id,
        questionId: currentQuestion.id,
        optionId: optionId,
      );
      if (!mounted) return;
      setState(() {
        answerFeedback = response.feedback;
        isSavingAnswer = false;
        answeredQuestionIds.add(currentQuestion.id);
      });
      await _showAnswerFeedback(currentQuestion, response.feedback);
    } on ExerciseApiException catch (error) {
      if (!mounted) return;
      setState(() {
        isSavingAnswer = false;
        answerError = error.message;
      });
      if (error.code == 'ATTEMPT_EXPIRED' || error.statusCode == 410) {
        await _showExpiredAttempt();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isSavingAnswer = false;
        answerError = 'บันทึกคำตอบไม่ได้ กรุณาลองส่งคำตอบเดิมอีกครั้ง';
      });
    }
  }

  Future<void> _showAnswerFeedback(
    ExerciseQuestion question,
    ExerciseAnswerFeedback feedback,
  ) async {
    final isCorrect = feedback.isCorrect;
    final correctWord = feedback.correctOption.word?.term ??
        (question.usesImageOptions ? question.targetWord?.term : null) ??
        feedback.correctOption.label;
    final translation = feedback.correctOption.word?.translation ??
        feedback.translation ??
        question.targetWord?.translation;
    final correctAnswerText = translation == null || translation.isEmpty
        ? correctWord
        : '$correctWord ($translation)';
    final correctImage = feedback.correctOption.word?.imageUrl ??
        (question.usesImageOptions
            ? feedback.correctOption.label
            : question.targetWord?.imageUrl ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final mainColor =
            isCorrect ? const Color(0xFF00C853) : const Color(0xFFFF3B30);
        final bgColor =
            isCorrect ? const Color(0xFFE8F8EE) : const Color(0xFFFFECEC);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 22,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // แถบจับเล็ก ๆ ด้านบน
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: mainColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),

                // ไอคอน + หัวข้อผลลัพธ์
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: mainColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: mainColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isCorrect ? 'ถูกต้อง เก่งมาก !' : 'ยังไม่ถูก ไม่เป็นไรนะ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isCorrect
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFD32F2F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isCorrect
                      ? 'คำตอบ คือ $correctAnswerText'
                      : 'คำตอบที่ถูกต้อง คือ $correctAnswerText',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                if (correctImage.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: mainColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Container(
                      height: 84,
                      width: 84,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildMediaContent(correctImage,
                            radius: 12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _Chunky3DButton(
                  height: 54,
                  color: isCorrect
                      ? const Color(0xFF00C853)
                      : const Color(0xFFFF9800),
                  edgeColor: isCorrect
                      ? const Color(0xFF00963E)
                      : const Color(0xFFE65100),
                  label: currentIndex == widget.attempt.questions.length - 1
                      ? 'ดูคะแนนรวม'
                      : 'ข้อถัดไป',
                  icon: currentIndex == widget.attempt.questions.length - 1
                      ? Icons.emoji_events_rounded
                      : Icons.arrow_forward_rounded,
                  onTap: () async {
                    Navigator.pop(context);
                    if (currentIndex < widget.attempt.questions.length - 1) {
                      setState(() {
                        currentIndex++;
                        selectedOptionId = null;
                        answerFeedback = null;
                        answerError = null;
                      });
                    } else {
                      await _submitAttempt();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitAttempt() async {
    if (isSubmittingAttempt) return;
    if (answeredQuestionIds.length != widget.attempt.questions.length) {
      setState(() => submitError = 'กรุณาตอบคำถามที่ได้รับมอบหมายให้ครบก่อนส่งผล');
      return;
    }
    setState(() {
      isSubmittingAttempt = true;
      submitError = null;
    });
    try {
      final result = await ExerciseApiService.submitAttempt(widget.attempt.id);
      CoinBalance.refresh(); // coins at the top of the screens
      // Finished: the next quiz of this category starts from the beginning.
      await ExerciseApiService.clearPendingQuiz(widget.attempt.categorySlug);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizResultScreen(
            totalScore: result.score,
            totalQuestions: result.totalQuestions,
            coinsAwarded: result.coinsAwarded,
          ),
        ),
      );
    } on ExerciseApiException catch (error) {
      if (!mounted) return;
      setState(() {
        isSubmittingAttempt = false;
        submitError = error.message;
      });
      if (error.code == 'ATTEMPT_EXPIRED' || error.statusCode == 410) {
        await ExerciseApiService.clearPendingQuiz(widget.attempt.categorySlug);
        await _showExpiredAttempt();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isSubmittingAttempt = false;
        submitError = 'ส่งผลแบบทดสอบไม่ได้ กรุณาลองอีกครั้ง';
      });
    }
  }

  Future<void> _showExpiredAttempt() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('แบบทดสอบหมดเวลา'),
        content: const Text('เวลาทำแบบทดสอบหมดแล้ว กรุณาเริ่มแบบทดสอบใหม่'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  String _questionPrompt(ExerciseQuestion question) {
    if (!question.usesImageOptions) {
      return 'รูปภาพนี้ตรงกับคำศัพท์ใด';
    }

    final targetWord = question.targetWord?.term;
    if (targetWord == null || targetWord.isEmpty) return question.prompt;
    return 'รูปภาพใด คือ $targetWord';
  }

  // ───────────────────────── Build ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentQuiz = widget.attempt.questions[currentIndex];
    final progress = (currentIndex + 1) / widget.attempt.questions.length;

    final questionImage = currentQuiz.targetWord?.imageUrl;
    final bool hasQuestionMedia =
        questionImage != null && questionImage.trim().isNotEmpty;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4FD1FF), Color(0xFF00A2FF), Color(0xFF0070DD)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // วงกลมตกแต่งพื้นหลัง (โทนเดียวกับหน้าก่อนเริ่มทำ)
            Positioned(
              top: -70,
              right: -60,
              child: _DecorativeCircle(
                size: 270,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              top: 260,
              left: -90,
              child: _DecorativeCircle(
                size: 200,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              bottom: 150,
              right: -80,
              child: _DecorativeCircle(
                size: 200,
                color: const Color(0xFFB3E5FC).withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -70,
              child: _DecorativeCircle(
                size: 260,
                color: const Color(0xFFB3E5FC).withValues(alpha: 0.16),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 14),
                    _buildProgressHeader(progress),
                    const SizedBox(height: 8),
                    _buildProgressBar(progress),
                    const SizedBox(height: 33),
                    _buildQuestionCard(_questionPrompt(currentQuiz)),
                    const SizedBox(height: 14),

                    // Dynamic Body Area
                    if (!currentQuiz.usesImageOptions) ...[
                      // Case 1: ตัวเลือก 4 ช่องเป็นตัวหนังสือ
                      Expanded(
                        child: _buildWordCard(currentQuiz, hasQuestionMedia),
                      ),
                      const SizedBox(height: 14),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: currentQuiz.options.length,
                        itemBuilder: (context, index) {
                          final option = currentQuiz.options[index];
                          final isSelected = selectedOptionId == option.id;
                          final pal = _palettes[index % _palettes.length];
                          return _OptionTile(
                            selected: isSelected,
                            radius: 20,
                            palette: pal,
                            vivid: true,
                            onTap: () {
                              // Can change their mind until "ตรวจคำตอบ" is pressed.
                              if (answerFeedback == null && !isSavingAnswer) {
                                setState(() => selectedOptionId = option.id);
                              }
                            },
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  option.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(0, 1.5),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      // Case 2: รูปภาพเป็น 4 ตัวเลือก (ขยายให้พอดีพื้นที่)
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            const spacing = 14.0;
                            final count = currentQuiz.options.length;
                            final rows = math.max(1, (count / 2).ceil());
                            final cellW = (c.maxWidth - spacing) / 2;
                            final maxH =
                                (c.maxHeight - spacing * (rows - 1)) / rows;
                            final cellH =
                                math.min(math.max(maxH, 80.0), cellW * 1.25);
                            final gridH = cellH * rows + spacing * (rows - 1);

                            return Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                height: gridH,
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: spacing,
                                    mainAxisSpacing: spacing,
                                    childAspectRatio: cellW / cellH,
                                  ),
                                  itemCount: count,
                                  itemBuilder: (context, index) {
                                    final option = currentQuiz.options[index];
                                    final imgPath = option.label;
                                    final isSelected = selectedOptionId == option.id;
                                    final pal =
                                        _palettes[index % _palettes.length];
                                    return _OptionTile(
                                      selected: isSelected,
                                      radius: 26,
                                      palette: pal,
                                      padding: const EdgeInsets.all(14),
                                      onTap: () {
                                        // Can change their mind until "ตรวจคำตอบ".
                                        if (answerFeedback == null &&
                                            !isSavingAnswer) {
                                          setState(() => selectedOptionId = option.id);
                                        }
                                      },
                                      child: _buildMediaContent(imgPath,
                                          radius: 16),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    if (answerError != null || submitError != null) ...[
                      Text(
                        answerError ?? submitError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Bottom Button
                    _Chunky3DButton(
                      height: 56,
                      color: const Color(0xFFFF9800),
                      edgeColor: const Color(0xFFE65100),
                      label: isSavingAnswer
                          ? 'กำลังตรวจคำตอบ'
                          : isSubmittingAttempt
                              ? 'กำลังบันทึกคะแนน'
                              : answerFeedback != null &&
                                      currentIndex == widget.attempt.questions.length - 1
                                  ? 'ลองส่งผลอีกครั้ง'
                                  : answerError != null
                                      ? 'ลองส่งคำตอบอีกครั้ง'
                                      : 'ตรวจคำตอบ',
                      icon: answerFeedback != null &&
                              currentIndex == widget.attempt.questions.length - 1
                          ? Icons.emoji_events_rounded
                          : Icons.check_circle_outline_rounded,
                      onTap: isSavingAnswer || isSubmittingAttempt
                          ? null
                          : answerFeedback != null
                              ? (currentIndex == widget.attempt.questions.length - 1
                                  ? _submitAttempt
                                  : null)
                              : selectedOptionId != null
                                  ? _checkAnswer
                                  : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Top bar ─────────────────────────
  Widget _buildTopBar() {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFB3E5FC),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.close_rounded,
                        color: Color(0xFF0091EA), size: 22),
                  ),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: CoinBalanceChip(),
          ),
          Padding(
            // Room for the back button (left) and the coins (right).
            padding: const EdgeInsets.symmetric(horizontal: CoinBalanceChip.width + 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'แบบฝึกหัดหมวด${widget.categoryTitle}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Progress ─────────────────────────
  Widget _buildProgressHeader(double progress) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFF8AC4), Color(0xFFFF4F9A)],
                ),
              ),
              child: const Icon(Icons.flag_rounded,
                  color: Colors.white, size: 15),
            ),
            const SizedBox(width: 8),
            Text(
              'ข้อที่ ${currentIndex + 1} จาก ${widget.attempt.questions.length}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD0A1), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFFC107), size: 16),
              const SizedBox(width: 4),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      height: 18,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          return Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0, end: progress),
              builder: (context, value, _) => Container(
                width: c.maxWidth * value,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFB74D),
                      Color(0xFFFF5FA2),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────── Question ─────────────────────────
  Widget _buildQuestionCard(String text) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA726),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFFFE0B8)],
          ),
        ),
        child: Row(
          children: [
            // มาสคอตนกฮูกถามคำถาม
            SizedBox(
              width: 88,
              height: 88,
              child: Image.asset(
                'assets/images/character/good.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  margin: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF4FD1FF), Color(0xFF0088FF)],
                    ),
                  ),
                  child: const Icon(Icons.question_mark_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Word card (โจทย์แบบเลือกคำ) ─────────────────────────
  Widget _buildWordCard(ExerciseQuestion quiz, bool hasQuestionMedia) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF8CC8F5),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF1F8FF)],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: hasQuestionMedia
                      ? _buildMediaContent(quiz.targetWord?.imageUrl, radius: 20)
                      : Text(
                          quiz.targetWord?.term ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                            letterSpacing: 0.5,
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

// ───────────────────────── Widgets ย่อย ─────────────────────────

/// ชุดสีของตัวเลือกแต่ละช่อง
class _Palette {
  final Color top; // ไล่สีด้านบน (แบบสด)
  final Color bottom; // ไล่สีด้านล่าง (แบบสด)
  final Color strong; // สีเด่น ใช้กับกรอบ/เครื่องหมายถูก
  final Color strongEdge; // ขอบล่าง 3D
  final Color tint; // พื้นอ่อน ตอนเลือก (แบบรูปภาพ)

  const _Palette({
    required this.top,
    required this.bottom,
    required this.strong,
    required this.strongEdge,
    required this.tint,
  });
}

const List<_Palette> _palettes = [
  // ชมพู
  _Palette(
    top: Color(0xFFFF8AC4),
    bottom: Color(0xFFFF4F9A),
    strong: Color(0xFFFF4F9A),
    strongEdge: Color(0xFFC21F6B),
    tint: Color(0xFFFFE3F0),
  ),
  // ม่วง
  _Palette(
    top: Color(0xFFB388FF),
    bottom: Color(0xFF7C4DFF),
    strong: Color(0xFF7C4DFF),
    strongEdge: Color(0xFF4A2BC4),
    tint: Color(0xFFEADFFF),
  ),
  // ส้ม
  _Palette(
    top: Color(0xFFFFB74D),
    bottom: Color(0xFFFF8F00),
    strong: Color(0xFFFF8F00),
    strongEdge: Color(0xFFD96A00),
    tint: Color(0xFFFFEBCF),
  ),
  // น้ำเงินอมม่วง
  _Palette(
    top: Color(0xFF7FB2FF),
    bottom: Color(0xFF3D6BFF),
    strong: Color(0xFF3D6BFF),
    strongEdge: Color(0xFF2447C9),
    tint: Color(0xFFDDE8FF),
  ),
];

/// กล่องตัวเลือก 3D
/// vivid = true  → ทั้งกล่องเป็นสีสดไล่เฉด (ใช้กับตัวเลือกคำ)
/// vivid = false → พื้นขาว กรอบสีสด (ใช้กับตัวเลือกรูปภาพ)
class _OptionTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double radius;
  final _Palette palette;
  final bool vivid;
  final EdgeInsets padding;

  const _OptionTile({
    required this.selected,
    required this.onTap,
    required this.child,
    required this.radius,
    required this.palette,
    this.vivid = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final BoxDecoration inner;
    if (vivid) {
      inner = BoxDecoration(
        borderRadius: BorderRadius.circular(radius - 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.top, palette.bottom],
        ),
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.35),
          width: selected ? 3.5 : 1.5,
        ),
      );
    } else {
      inner = BoxDecoration(
        borderRadius: BorderRadius.circular(radius - 2),
        color: selected ? palette.tint : Colors.white,
        border: Border.all(
          color: selected ? palette.strong : palette.top.withValues(alpha: 0.55),
          width: selected ? 4 : 2.5,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: palette.strongEdge,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? (vivid ? Colors.white : palette.strong)
                            .withValues(alpha: 0.55)
                        : Colors.black.withValues(alpha: 0.18),
                    blurRadius: selected ? 16 : 10,
                    offset: Offset(0, selected ? 2 : 5),
                  ),
                ],
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: padding,
                decoration: inner,
                child: child,
              ),
            ),
          ),
          // เครื่องหมายถูกเมื่อเลือก
          Positioned(
            top: -6,
            right: -6,
            child: AnimatedScale(
              scale: selected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: vivid ? Colors.white : palette.strong,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: vivid ? palette.strongEdge : Colors.white,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: vivid ? palette.strongEdge : Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ปุ่ม 3D สไตล์เกม กดแล้วจมลง (ปิดการใช้งานได้ด้วย onTap = null)
class _Chunky3DButton extends StatefulWidget {
  final VoidCallback? onTap;
  final String label;
  final IconData? icon;
  final double height;
  final Color color;
  final Color edgeColor;

  const _Chunky3DButton({
    required this.onTap,
    required this.label,
    required this.height,
    required this.color,
    required this.edgeColor,
    this.icon,
  });

  @override
  State<_Chunky3DButton> createState() => _Chunky3DButtonState();
}

class _Chunky3DButtonState extends State<_Chunky3DButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const depth = 5.0;
    final enabled = widget.onTap != null;

    final face = enabled ? widget.color : Colors.white.withValues(alpha: 0.28);
    final edge = enabled ? widget.edgeColor : Colors.white.withValues(alpha: 0.16);
    final fg = enabled ? Colors.white : Colors.white.withValues(alpha: 0.85);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      child: SizedBox(
        height: widget.height + depth,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: widget.height,
              child: Container(
                decoration: BoxDecoration(
                  color: edge,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: enabled
                      ? const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 80),
              left: 0,
              right: 0,
              top: _pressed ? depth : 0,
              height: widget.height,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      enabled ? Color.lerp(face, Colors.white, 0.18)! : face,
                      face,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: fg, size: 24),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: fg,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
