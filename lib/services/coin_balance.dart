import 'package:flutter/foundation.dart';

import 'rewards_api_service.dart';

/// Coins for each right word in the word games (ทายภาพ, จับคู่เงา,
/// ปริศนาทายคำ, ค้นหาคำศัพท์, พยัญชนะต้น), once per word per day.
/// Must match COINS_PER_CORRECT in the backend (routes/games.js).
const int kGameCoinsPerWord = 2;

/// Coins for each right answer of a vocabulary quiz. The server adds them all
/// when the quiz is submitted (score * 10, routes/exercises.js); the quiz
/// screen shows them going up while the child answers.
const int kQuizCoinsPerCorrect = 10;

/// The signed-in child's coin balance, shared by every screen that shows it
/// (CoinBalanceChip). Games update it right away from the server's reply
/// when a coin is earned, so the number at the top goes up immediately.
class CoinBalance {
  CoinBalance._();

  /// null = not loaded yet (or not signed in / offline).
  static final ValueNotifier<int?> value = ValueNotifier<int?>(null);

  static Future<void> refresh() async {
    try {
      value.value = await RewardsApiService.getBalance();
    } catch (_) {
      // Offline: keep the last known number.
    }
  }

  /// A balance returned by the server (e.g. after a coin was given).
  static void set(Object? balance) {
    if (balance is int && balance >= 0) value.value = balance;
  }

  /// Forget it on logout.
  static void clear() => value.value = null;
}
