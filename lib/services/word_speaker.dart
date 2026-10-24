import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads a word aloud with the phone's own text-to-speech. Used as a backup
/// when the online voice (Google Translate) can't be played: no internet,
/// blocked, slow, etc.
class WordSpeaker {
  WordSpeaker._();

  static final FlutterTts _tts = FlutterTts();
  static String? _language;

  /// [language]: 'en-US' or 'th-TH'.
  static Future<void> speak(String text, {String language = 'en-US'}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    try {
      await _tts.stop();
      if (_language != language) {
        await _tts.setLanguage(language);
        await _tts.setSpeechRate(0.42);
        _language = language;
      }
      await _tts.speak(clean);
    } catch (e) {
      debugPrint('WordSpeaker error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
