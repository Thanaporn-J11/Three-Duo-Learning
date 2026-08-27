import 'package:flutter/material.dart';
import '../../models/quiz_vocabulary_item.dart';
import 'quiz_result_screen.dart';

class VocabularyQuizScreen extends StatefulWidget {
  final String categoryTitle;
  final List<QuizItem> quizItems;

  const VocabularyQuizScreen({
    super.key,
    required this.categoryTitle,
    required this.quizItems,
  });

  @override
  State<VocabularyQuizScreen> createState() => _VocabularyQuizScreenState();
}

class _VocabularyQuizScreenState extends State<VocabularyQuizScreen> {
  int currentIndex = 0;
  String? selectedOption;
  int correctScore = 0;

  void _checkAnswer() {
    if (selectedOption == null) return;

    final currentQuiz = widget.quizItems[currentIndex];
    final isCorrect = currentQuiz.isImageOption
        ? selectedOption == currentQuiz.correctImage
        : selectedOption == currentQuiz.correctWord;

    if (isCorrect) correctScore++;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: BoxDecoration(
          color: isCorrect ? const Color(0xFFE8F8EE) : const Color(0xFFFFECEC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isCorrect ? const Color(0xFF00C853) : const Color(0xFFFF3B30),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  isCorrect ? 'ถูกต้อง' : 'ผิด',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isCorrect ? const Color(0xFF1B5E20) : const Color(0xFFD32F2F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isCorrect
                  ? 'รูปนี้ คือ ${currentQuiz.correctWord} (${currentQuiz.correctTranslation})'
                  : 'คำตอบที่ถูกต้อง คือ ${currentQuiz.correctWord} (${currentQuiz.correctTranslation})',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 76,
              width: 76,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(currentQuiz.correctImage, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (currentIndex < widget.quizItems.length - 1) {
                    setState(() {
                      currentIndex++;
                      selectedOption = null;
                    });
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizResultScreen(
                          totalScore: correctScore,
                          totalQuestions: widget.quizItems.length,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCorrect ? const Color(0xFF00C853) : const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                child: Text(
                  currentIndex == widget.quizItems.length - 1 ? 'ดูคะแนนรวม' : 'ข้อถัดไป',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuiz = widget.quizItems[currentIndex];
    final progress = (currentIndex + 1) / widget.quizItems.length;

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
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF0D5C9E), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'แบบฝึกหัดหมวด${widget.categoryTitle}',
          style: const TextStyle(color: Color(0xFF0D5C9E), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ข้อที่ ${currentIndex + 1} จาก ${widget.quizItems.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5A789A)),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0088FF)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 16),

              // Question Heading Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D5C9E).withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  currentQuiz.questionText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Dynamic Body Area
              if (!currentQuiz.isImageOption && currentQuiz.questionImage != null) ...[
                // Case 1: รูปภาพโจทย์อยู่ตรงกลาง (ขยายใหญ่)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D5C9E).withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(currentQuiz.questionImage!, fit: BoxFit.contain),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.3,
                  ),
                  itemCount: currentQuiz.options.length,
                  itemBuilder: (context, index) {
                    final word = currentQuiz.options[index];
                    final isSelected = selectedOption == word;
                    return GestureDetector(
                      onTap: () => setState(() => selectedOption = word),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0088FF) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0088FF) : const Color(0xFFCCE2F7),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? const Color(0xFF0088FF).withOpacity(0.25) : Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            word,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : const Color(0xFF0D5C9E),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ] else ...[
                // Case 2: รูปภาพเป็น 4 ตัวเลือก (ขยายเต็มพื้นที่ตรงกลาง ไม่ให้มีที่ว่างโล่ง)
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.96,
                    ),
                    itemCount: currentQuiz.options.length,
                    itemBuilder: (context, index) {
                      final imgPath = currentQuiz.options[index];
                      final isSelected = selectedOption == imgPath;
                      return GestureDetector(
                        onTap: () => setState(() => selectedOption = imgPath),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0088FF) : const Color(0xFFE2E8F0),
                              width: isSelected ? 3.0 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected ? const Color(0xFF0088FF).withOpacity(0.18) : Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.asset(imgPath, fit: BoxFit.contain),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Bottom Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: selectedOption != null ? _checkAnswer : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD4E3EE),
                    disabledForegroundColor: const Color(0xFF8CA6BD),
                    elevation: selectedOption != null ? 3 : 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                  ),
                  child: const Text('ตรวจคำตอบ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}