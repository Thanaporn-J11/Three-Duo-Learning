import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:threeduo_learning/services/letter_word_picker.dart';

final List<String> _words = <String>[
  for (var i = 0; i < 30; i++) 'WORD${String.fromCharCode(65 + i % 26)}${'X' * (i % 7)}$i',
];

void main() {
  setUp(() => LetterRecentWords.remember('test', <String>[], 0));

  group('pickLevelWords', () {
    List<String> pick(int level, List<String> recent, {int count = 5}) =>
        pickLevelWords(
          words: _words,
          level: level,
          levelCount: 30,
          count: count,
          recent: recent,
          random: Random(level),
        );

    test('gives distinct words, easiest (shortest) first', () {
      final picked = pick(10, const <String>[]);
      expect(picked, hasLength(5));
      expect(picked.toSet(), hasLength(5));
      int len(String w) => w.length;
      for (var i = 1; i < picked.length; i++) {
        expect(len(picked[i]), greaterThanOrEqualTo(len(picked[i - 1])));
      }
    });

    test('keeps out words shown lately while others are available', () {
      final recent = <String>[];
      final fromEachLevel = <List<String>>[];
      for (var level = 1; level <= 6; level++) {
        final picked = pick(level, recent);
        // Nothing of the last three levels again.
        for (final earlier in fromEachLevel.reversed.take(3)) {
          expect(picked.where(earlier.contains), isEmpty,
              reason: 'level $level repeated a word of a recent level');
        }
        fromEachLevel.add(picked);
        recent
          ..removeWhere(picked.contains)
          ..addAll(picked);
        if (recent.length > 15) recent.removeRange(0, recent.length - 15);
      }
    });

    test('takes the oldest recent words back when too few are left', () {
      final recent = List<String>.from(_words); // everything was shown
      final picked = pick(5, recent);
      expect(picked, hasLength(5));
      expect(picked.toSet(), hasLength(5));
      // The longest ago (front of the list) come back first.
      expect(recent.take(5).toSet(), picked.toSet());
    });

    test('a category with fewer words than a level needs gives them all', () {
      final picked = pickLevelWords(
        words: <String>['CAT', 'DOG', 'PIG'],
        level: 20,
        levelCount: 30,
        count: 8,
        recent: const <String>['CAT'],
        random: Random(1),
      );
      expect(picked.toSet(), <String>{'CAT', 'DOG', 'PIG'});
    });

    test('no words gives an empty level', () {
      expect(
        pickLevelWords(
          words: const <String>[],
          level: 1,
          levelCount: 30,
          count: 5,
          recent: const <String>[],
          random: Random(1),
        ),
        isEmpty,
      );
    });
  });

  group('LetterRecentWords', () {
    test('remembers newest last and forgets the oldest above the limit', () {
      LetterRecentWords.remember('a', <String>['ONE', 'TWO', 'THREE'], 4);
      LetterRecentWords.remember('a', <String>['FOUR', 'TWO'], 4);
      expect(LetterRecentWords.of('a'), <String>['ONE', 'THREE', 'FOUR', 'TWO']);
      LetterRecentWords.remember('a', <String>['FIVE'], 4);
      expect(LetterRecentWords.of('a'), <String>['THREE', 'FOUR', 'TWO', 'FIVE']);
      expect(LetterRecentWords.of('other'), isEmpty);
    });
  });
}
