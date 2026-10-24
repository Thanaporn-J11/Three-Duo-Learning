class ExerciseAttempt {
  const ExerciseAttempt({
    required this.id,
    required this.exerciseId,
    required this.categorySlug,
    required this.status,
    required this.questionCount,
    required this.questions,
    this.score,
    this.totalQuestions,
    this.coinsAwarded,
  });

  final String id;
  final String exerciseId;
  final String categorySlug;
  final String status;
  final int questionCount;
  final List<ExerciseQuestion> questions;
  final int? score;
  final int? totalQuestions;
  final int? coinsAwarded;

  factory ExerciseAttempt.fromResponse(Map<String, dynamic> json) {
    final attempt = _map(json['attempt'], 'attempt');
    final rawQuestions = json['questions'];
    if (rawQuestions is! List) {
      throw const FormatException('Missing attempt questions');
    }
    final questions = rawQuestions
        .map((item) => ExerciseQuestion.fromJson(_map(item, 'question')))
        .toList(growable: false);
    if (questions.isEmpty) {
      throw const FormatException('Attempt has no questions');
    }
    return ExerciseAttempt(
      id: _string(attempt['id'], 'attempt.id'),
      exerciseId: _string(attempt['exerciseId'], 'attempt.exerciseId'),
      categorySlug: _string(attempt['categorySlug'], 'attempt.categorySlug'),
      status: _string(attempt['status'], 'attempt.status'),
      questionCount: _integer(attempt['questionCount'], 'attempt.questionCount'),
      questions: questions,
      score: _optionalInteger(attempt['score']),
      totalQuestions: _optionalInteger(attempt['totalQuestions']),
      coinsAwarded: _optionalInteger(attempt['coinsAwarded']),
    );
  }
}

class ExerciseQuestion {
  const ExerciseQuestion({
    required this.id,
    required this.prompt,
    required this.type,
    required this.options,
    this.targetWord,
    this.feedback,
  });

  final String id;
  final String prompt;
  final String type;
  final List<ExerciseOption> options;
  final ExerciseTargetWord? targetWord;
  final ExerciseAnswerFeedback? feedback;

  bool get usesImageOptions => type == 'word_to_image';

  factory ExerciseQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    if (rawOptions is! List || rawOptions.length != 4) {
      throw const FormatException('A quiz question must have four options');
    }
    final type = _string(json['type'], 'question.type');
    if (type != 'image_to_word' && type != 'word_to_image') {
      throw const FormatException('Unsupported question type');
    }
    final target = json['targetWord'];
    final feedback = json['feedback'];
    return ExerciseQuestion(
      id: _string(json['id'], 'question.id'),
      prompt: _string(json['prompt'], 'question.prompt'),
      type: type,
      options: rawOptions
          .map((item) => ExerciseOption.fromJson(_map(item, 'option')))
          .toList(growable: false),
      targetWord: target == null
          ? null
          : ExerciseTargetWord.fromJson(_map(target, 'targetWord')),
      feedback: feedback == null
          ? null
          : ExerciseAnswerFeedback.fromJson(_map(feedback, 'feedback')),
    );
  }
}

class ExerciseOption {
  const ExerciseOption({required this.id, required this.label});

  final String id;
  final String label;

  factory ExerciseOption.fromJson(Map<String, dynamic> json) => ExerciseOption(
        id: _string(json['id'], 'option.id'),
        label: _string(json['label'], 'option.label'),
      );
}

class ExerciseTargetWord {
  const ExerciseTargetWord({
    this.imageUrl,
    this.term,
    this.translation,
    this.thaiPronunciation,
  });

  final String? imageUrl;
  final String? term;
  final String? translation;
  final String? thaiPronunciation;

  factory ExerciseTargetWord.fromJson(Map<String, dynamic> json) =>
      ExerciseTargetWord(
        imageUrl: _optionalString(json['imageUrl']),
        term: _optionalString(json['term']),
        translation: _optionalString(json['translation']),
        thaiPronunciation: _optionalString(json['thaiPronunciation']),
      );
}

class ExerciseAnswerFeedback {
  const ExerciseAnswerFeedback({
    this.selectedOptionId,
    required this.isCorrect,
    required this.correctOption,
    this.translation,
    this.thaiPronunciation,
  });

  final String? selectedOptionId;
  final bool isCorrect;
  final ExerciseCorrectOption correctOption;
  final String? translation;
  final String? thaiPronunciation;

  factory ExerciseAnswerFeedback.fromJson(Map<String, dynamic> json) {
    final correctOption = json['correctOption'];
    if (json['isCorrect'] is! bool || correctOption is! Map) {
      throw const FormatException('Invalid answer feedback');
    }
    return ExerciseAnswerFeedback(
      selectedOptionId: _optionalId(json['selectedOptionId']),
      isCorrect: json['isCorrect'] as bool,
      correctOption: ExerciseCorrectOption.fromJson(
        Map<String, dynamic>.from(correctOption),
      ),
      translation: _optionalString(json['translation']),
      thaiPronunciation: _optionalString(json['thaiPronunciation']),
    );
  }
}

class ExerciseCorrectOption {
  const ExerciseCorrectOption({
    required this.id,
    required this.label,
    this.word,
  });

  final String id;
  final String label;
  final ExerciseVocabularyWord? word;

  factory ExerciseCorrectOption.fromJson(Map<String, dynamic> json) {
    final word = json['word'];
    return ExerciseCorrectOption(
      id: _string(json['id'], 'correctOption.id'),
      label: _string(json['label'], 'correctOption.label'),
      word: word == null
          ? null
          : ExerciseVocabularyWord.fromJson(_map(word, 'correctOption.word')),
    );
  }
}

class ExerciseVocabularyWord {
  const ExerciseVocabularyWord({
    this.term,
    this.translation,
    this.thaiPronunciation,
    this.imageUrl,
  });

  final String? term;
  final String? translation;
  final String? thaiPronunciation;
  final String? imageUrl;

  factory ExerciseVocabularyWord.fromJson(Map<String, dynamic> json) =>
      ExerciseVocabularyWord(
        term: _optionalString(json['term']),
        translation: _optionalString(json['translation']),
        thaiPronunciation: _optionalString(json['thaiPronunciation']),
        imageUrl: _optionalString(json['imageUrl']),
      );
}

class ExerciseAnswerResult {
  const ExerciseAnswerResult({
    required this.questionId,
    required this.feedback,
    required this.replayed,
  });

  final String questionId;
  final ExerciseAnswerFeedback feedback;
  final bool replayed;

  factory ExerciseAnswerResult.fromJson(Map<String, dynamic> json) {
    return ExerciseAnswerResult(
      questionId: _string(json['questionId'], 'questionId'),
      feedback: ExerciseAnswerFeedback.fromJson(_map(json['feedback'], 'feedback')),
      replayed: json['replayed'] == true,
    );
  }
}

class ExerciseSubmitResult {
  const ExerciseSubmitResult({
    required this.attemptId,
    required this.score,
    required this.totalQuestions,
    required this.coinsAwarded,
  });

  final String attemptId;
  final int score;
  final int totalQuestions;
  final int coinsAwarded;

  factory ExerciseSubmitResult.fromJson(Map<String, dynamic> json) {
    final attempt = _map(json['attempt'], 'attempt');
    return ExerciseSubmitResult(
      attemptId: _string(attempt['id'], 'attempt.id'),
      score: _integer(attempt['score'], 'attempt.score'),
      totalQuestions: _integer(attempt['totalQuestions'], 'attempt.totalQuestions'),
      coinsAwarded: _integer(attempt['coinsAwarded'], 'attempt.coinsAwarded'),
    );
  }
}

Map<String, dynamic> _map(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Invalid $field');
}

String _string(Object? value, String field) {
  if (value is String && value.isNotEmpty) return value;
  if (value is int && value > 0) return value.toString();
  throw FormatException('Invalid $field');
}

String? _optionalString(Object? value) => value is String ? value : null;

String? _optionalId(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  if (value is int && value > 0) return value.toString();
  return null;
}

int _integer(Object? value, String field) {
  if (value is int && value >= 0) return value;
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed >= 0) return parsed;
  }
  throw FormatException('Invalid $field');
}

int? _optionalInteger(Object? value) => value is int ? value : null;
