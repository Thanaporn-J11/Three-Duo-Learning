class QuizItem {
  final String questionText;
  final String? questionImage;
  final String? targetWord;
  final String correctWord;
  final String correctTranslation;
  final String correctImage;
  final List<String> options;
  final bool isImageOption;

  QuizItem({
    required this.questionText,
    this.questionImage,
    this.targetWord,
    required this.correctWord,
    required this.correctTranslation,
    required this.correctImage,
    required this.options,
    required this.isImageOption,
  });
}