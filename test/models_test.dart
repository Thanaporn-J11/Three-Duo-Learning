import 'package:flutter_test/flutter_test.dart';
import 'package:threeduo_learning/models/quiz_vocabulary_item.dart';
import 'package:threeduo_learning/models/vocabulary_category.dart';
import 'package:threeduo_learning/models/vocabulary_word.dart';

void main() {
  group('VocabularyWord.fromJson', () {
    Map<String, dynamic> valid() => <String, dynamic>{
      'id': 7,
      'category_slug': 'animals',
      'term': 'cat',
      'translation': 'แมว',
      'thai_pronunciation': 'แคท',
      'image_url': 'assets/cat.png',
      'audio_url': 'https://example.test/cat.mp3',
      'sort_order': 3,
    };

    test('reads every field and exposes the view getters', () {
      final word = VocabularyWord.fromJson(valid());

      expect(word.id, '7');
      expect(word.categorySlug, 'animals');
      expect(word.term, 'cat');
      expect(word.word, 'cat');
      expect(word.translation, 'แมว');
      expect(word.thaiPronunciation, 'แคท');
      expect(word.thaiPhonetics, 'แคท');
      expect(word.imageUrl, 'assets/cat.png');
      expect(word.imagePath, 'assets/cat.png');
      expect(word.audioUrl, 'https://example.test/cat.mp3');
      expect(word.sortOrder, 3);
      expect(word.phonetics, '');
    });

    test('accepts string ids and numeric strings for sort_order', () {
      final json = valid()
        ..['id'] = '12'
        ..['sort_order'] = '5';
      final word = VocabularyWord.fromJson(json);

      expect(word.id, '12');
      expect(word.sortOrder, 5);
    });

    test('accepts a whole double for sort_order', () {
      final word = VocabularyWord.fromJson(valid()..['sort_order'] = 4.0);

      expect(word.sortOrder, 4);
    });

    test('optional fields may be null and fall back to empty strings', () {
      final json = valid()
        ..['thai_pronunciation'] = null
        ..['image_url'] = null
        ..['audio_url'] = null;
      final word = VocabularyWord.fromJson(json);

      expect(word.thaiPronunciation, isNull);
      expect(word.thaiPhonetics, '');
      expect(word.imageUrl, isNull);
      expect(word.imagePath, '');
      expect(word.audioUrl, isNull);
    });

    test('rejects missing or badly typed required fields', () {
      for (final key in <String>[
        'id',
        'category_slug',
        'term',
        'translation',
        'sort_order',
      ]) {
        final json = valid()..remove(key);
        expect(
          () => VocabularyWord.fromJson(json),
          throwsFormatException,
          reason: 'missing $key',
        );
      }
      expect(
        () => VocabularyWord.fromJson(valid()..['id'] = ''),
        throwsFormatException,
      );
      expect(
        () => VocabularyWord.fromJson(valid()..['term'] = 5),
        throwsFormatException,
      );
      expect(
        () => VocabularyWord.fromJson(valid()..['sort_order'] = 1.5),
        throwsFormatException,
      );
      expect(
        () => VocabularyWord.fromJson(valid()..['sort_order'] = 'abc'),
        throwsFormatException,
      );
    });

    test('rejects a badly typed optional field', () {
      expect(
        () => VocabularyWord.fromJson(valid()..['audio_url'] = 5),
        throwsFormatException,
      );
    });
  });

  group('VocabularyCategory.fromJson', () {
    Map<String, dynamic> valid() => <String, dynamic>{
      'id': 2,
      'slug': 'fruit',
      'name': 'ผลไม้',
      'sort_order': 1,
      'word_count': 10,
    };

    test('reads every field', () {
      final category = VocabularyCategory.fromJson(valid());

      expect(category.id, '2');
      expect(category.slug, 'fruit');
      expect(category.name, 'ผลไม้');
      expect(category.sortOrder, 1);
      expect(category.wordCount, 10);
    });

    test('accepts string ids and numeric strings', () {
      final category = VocabularyCategory.fromJson(
        valid()
          ..['id'] = 'abc'
          ..['word_count'] = '8',
      );

      expect(category.id, 'abc');
      expect(category.wordCount, 8);
    });

    test('rejects missing or badly typed fields', () {
      for (final key in <String>[
        'id',
        'slug',
        'name',
        'sort_order',
        'word_count',
      ]) {
        final json = valid()..remove(key);
        expect(
          () => VocabularyCategory.fromJson(json),
          throwsFormatException,
          reason: 'missing $key',
        );
      }
      expect(
        () => VocabularyCategory.fromJson(valid()..['slug'] = 3),
        throwsFormatException,
      );
      expect(
        () => VocabularyCategory.fromJson(valid()..['word_count'] = 2.5),
        throwsFormatException,
      );
    });
  });

  test('QuizItem keeps the values it was built with', () {
    final item = QuizItem(
      questionText: 'Which one is a cat?',
      questionImage: 'assets/q.png',
      targetWord: 'cat',
      correctWord: 'cat',
      correctTranslation: 'แมว',
      correctImage: 'assets/cat.png',
      options: <String>['cat', 'dog'],
      isImageOption: true,
    );

    expect(item.questionText, 'Which one is a cat?');
    expect(item.questionImage, 'assets/q.png');
    expect(item.targetWord, 'cat');
    expect(item.correctWord, 'cat');
    expect(item.correctTranslation, 'แมว');
    expect(item.correctImage, 'assets/cat.png');
    expect(item.options, <String>['cat', 'dog']);
    expect(item.isImageOption, isTrue);

    final minimal = QuizItem(
      questionText: 'q',
      correctWord: 'a',
      correctTranslation: 't',
      correctImage: 'i',
      options: const <String>[],
      isImageOption: false,
    );
    expect(minimal.questionImage, isNull);
    expect(minimal.targetWord, isNull);
  });
}
