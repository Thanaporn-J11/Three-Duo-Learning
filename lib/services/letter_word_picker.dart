import 'dart:math';

import 'user_account_preferences.dart';

/// Words the child just met in the "First Letter" game, per category, newest
/// last. Kept in memory only (cleared on logout): it is just there so the next
/// levels do not show the same few words again and again.
class LetterRecentWords {
  LetterRecentWords._();

  static final Map<String, List<String>> _byCategory = <String, List<String>>{};
  static bool _registered = false;

  static List<String> of(String category) {
    if (!_registered) {
      _registered = true;
      UserAccountPreferences.registerMemoryResetter(_byCategory.clear);
    }
    return List<String>.unmodifiable(_byCategory[category] ?? const <String>[]);
  }

  /// Adds [words] as the newest ones and forgets the oldest above [keep].
  static void remember(String category, Iterable<String> words, int keep) {
    final list = _byCategory.putIfAbsent(category, () => <String>[]);
    final added = words.toSet();
    list.removeWhere(added.contains);
    list.addAll(words);
    if (list.length > keep) list.removeRange(0, list.length - keep);
  }
}

/// Words per level for the "First Letter" game.
///
/// Easy (short) words come first and long ones later, so each level draws
/// from a window of the length-sorted list that slides with the level. The
/// windows of neighbouring levels overlap a lot, and a category has only
/// about 30 words for many levels, so words that were [recent]ly shown are
/// left out while there are enough others: first from the level's window,
/// then the closest in difficulty outside it. Only when too few words are
/// left do the oldest recent ones come back.
List<String> pickLevelWords({
  required List<String> words,
  required int level,
  required int levelCount,
  required int count,
  required List<String> recent,
  required Random random,
}) {
  int len(String w) => w.replaceAll(' ', '').length;
  final all = List<String>.from(words)
    ..sort((a, b) {
      final c = len(a).compareTo(len(b));
      return c != 0 ? c : a.compareTo(b);
    });
  final n = all.length;
  final take = min(count, n);
  if (take == 0) return <String>[];

  final window = min(n, max(take, (n * 0.4).ceil()));
  final d = levelCount > 1 ? (level - 1) / (levelCount - 1) : 0.0;
  final start = ((n - window) * d).round();
  final center = start + (window - 1) / 2;
  final seen = recent.toSet();

  final picked = <String>[];
  final inWindow = all.sublist(start, start + window);
  final fresh = inWindow.where((w) => !seen.contains(w)).toList()
    ..shuffle(random);
  picked.addAll(fresh.take(take));

  if (picked.length < take) {
    final outside = <int>[
      for (var i = 0; i < n; i++)
        if (!seen.contains(all[i]) && !picked.contains(all[i])) i,
    ]..sort((a, b) => (a - center).abs().compareTo((b - center).abs()));
    for (final i in outside) {
      if (picked.length >= take) break;
      picked.add(all[i]);
    }
  }
  if (picked.length < take) {
    // Everything was shown lately: the longest ago first.
    for (final w in recent) {
      if (picked.length >= take) break;
      if (all.contains(w) && !picked.contains(w)) picked.add(w);
    }
  }
  return picked..sort((a, b) => len(a).compareTo(len(b)));
}
