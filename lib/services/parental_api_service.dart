import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ParentalApiException implements Exception {
  const ParentalApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class CategoryProgress {
  const CategoryProgress({
    required this.name,
    required this.wordsLearned,
    required this.wordsTotal,
    required this.attempts,
    required this.averageScore,
  });

  final String name;
  final int wordsLearned;
  final int wordsTotal;
  final int attempts;
  final int? averageScore; // null = no exercises done in this category yet

  factory CategoryProgress.fromJson(Map<String, dynamic> j) => CategoryProgress(
    name: j['name']?.toString() ?? '-',
    wordsLearned: _int(j['wordsLearned']),
    wordsTotal: _int(j['wordsTotal']),
    attempts: _int(j['attempts']),
    averageScore: j['averageScore'] == null ? null : _int(j['averageScore']),
  );
}

/// One listening game in the report (score games: average/best in %).
class ListeningGameSummary {
  const ListeningGameSummary({
    required this.plays,
    this.averageScore,
    this.bestScore,
    this.lastPlayedAt,
  });

  final int plays;
  final int? averageScore;
  final int? bestScore;
  final String? lastPlayedAt;

  factory ListeningGameSummary.fromJson(Map<String, dynamic> j) =>
      ListeningGameSummary(
        plays: _int(j['plays']),
        averageScore: j['averageScore'] == null ? null : _int(j['averageScore']),
        bestScore: j['bestScore'] == null ? null : _int(j['bestScore']),
        lastPlayedAt: j['lastPlayedAt']?.toString(),
      );
}

class ListeningTopicScore {
  const ListeningTopicScore(this.topic, this.plays, this.bestScore, this.lastScore);

  final String topic;
  final int plays;
  final int? bestScore;
  final int? lastScore;
}

class ListeningSummary {
  const ListeningSummary({
    required this.minimalPairs,
    required this.fillBlank,
    required this.fillBlankTopics,
    required this.karaokeRecordings,
    required this.karaokeSongs,
    required this.karaokeSeconds,
    required this.animalSounds,
  });

  final ListeningGameSummary minimalPairs;
  final ListeningGameSummary fillBlank;
  final List<ListeningTopicScore> fillBlankTopics;
  final int karaokeRecordings;
  final int karaokeSongs;
  final int karaokeSeconds;

  /// "เสียงสัตว์" game (score = right answers out of 14).
  final ListeningGameSummary animalSounds;

  bool get isEmpty =>
      minimalPairs.plays == 0 &&
      fillBlank.plays == 0 &&
      karaokeRecordings == 0 &&
      animalSounds.plays == 0;

  factory ListeningSummary.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> map(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    final fill = map(j['fillBlank']);
    final karaoke = map(j['karaoke']);
    final topics = fill['topics'];
    return ListeningSummary(
      minimalPairs: ListeningGameSummary.fromJson(map(j['minimalPairs'])),
      fillBlank: ListeningGameSummary.fromJson(fill),
      fillBlankTopics:
          topics is List
              ? topics.whereType<Map>().map((t) {
                final m = Map<String, dynamic>.from(t);
                return ListeningTopicScore(
                  m['topic']?.toString() ?? '-',
                  _int(m['plays']),
                  m['bestScore'] == null ? null : _int(m['bestScore']),
                  m['lastScore'] == null ? null : _int(m['lastScore']),
                );
              }).toList()
              : const [],
      karaokeRecordings: _int(karaoke['recordings']),
      karaokeSongs: _int(karaoke['songs']),
      karaokeSeconds: _int(karaoke['totalSeconds']),
      animalSounds: ListeningGameSummary.fromJson(map(j['animalSounds'])),
    );
  }
}

/// One phonics level ('01'..'06') in the report.
class PhonicsCategoryProgress {
  const PhonicsCategoryProgress(this.title, this.practiced, this.total);

  final String title;
  final int practiced;
  final int total;
}

/// Phonics cards practiced (no scores: the child only listens).
class PhonicsSummary {
  const PhonicsSummary({
    required this.practiced,
    required this.total,
    required this.completedCategories,
    required this.lastPracticedAt,
    required this.categories,
  });

  final int practiced;
  final int total;
  final int completedCategories;
  final DateTime? lastPracticedAt;
  final List<PhonicsCategoryProgress> categories;

  factory PhonicsSummary.fromJson(Map<String, dynamic> j) {
    final cats = j['categories'];
    final last = j['lastPracticedAt'];
    return PhonicsSummary(
      practiced: _int(j['practiced']),
      total: _int(j['total']),
      completedCategories: _int(j['completedCategories']),
      lastPracticedAt: last is String ? DateTime.tryParse(last) : null,
      categories:
          cats is List
              ? cats
                  .whereType<Map>()
                  .map(
                    (c) => PhonicsCategoryProgress(
                      c['title']?.toString() ?? '-',
                      _int(c['practiced']),
                      _int(c['total']),
                    ),
                  )
                  .toList()
              : const [],
    );
  }
}

class WeakWord {
  const WeakWord(this.term, this.translation, this.wrongCount);

  final String term;
  final String translation;
  final int wrongCount;
}

/// GET /api/parent/report
class LearningReport {
  const LearningReport({
    required this.wordsLearned,
    required this.wordsLearning,
    required this.wordsTotal,
    required this.exercisesPassed,
    required this.exercisesTotal,
    required this.exerciseAttempts,
    required this.averageScore,
    required this.passPercent,
    required this.categories,
    required this.weakCategories,
    required this.weakWords,
    required this.currentStreak,
    required this.longestStreak,
    required this.checkinDaysLast7,
    required this.listening,
    required this.phonics,
    required this.alphabetLevelsPassed,
    required this.alphabetStars,
    required this.monsterLevelsPassed,
    required this.monsterStars,
    required this.monstersBeaten,
    required this.marketLevelsPassed,
    required this.marketStars,
    required this.marketItemsCollected,
    required this.bridgeLevelsPassed,
    required this.bridgeStars,
    required this.bridgeStickers,
  });

  final int wordsLearned;
  final int wordsLearning;
  final int wordsTotal;
  final int exercisesPassed;
  final int exercisesTotal;
  final int exerciseAttempts;
  final int? averageScore;
  final int passPercent;
  final List<CategoryProgress> categories;
  final List<CategoryProgress> weakCategories;
  final List<WeakWord> weakWords;
  final int currentStreak;
  final int longestStreak;
  final int checkinDaysLast7;
  final ListeningSummary listening;
  final PhonicsSummary phonics;

  /// "งูน้อยฉลาดเลือก": levels passed (of 50) and stars (of 150).
  final int alphabetLevelsPassed;
  final int alphabetStars;

  /// "สร้างมอนสเตอร์": levels passed (of 40), stars (of 120), monsters beaten.
  final int monsterLevelsPassed;
  final int monsterStars;
  final int monstersBeaten;

  /// "มินิมาร์เก็ต": levels passed (of 50), stars (of 150), different items collected.
  final int marketLevelsPassed;
  final int marketStars;
  final int marketItemsCollected;

  /// "สร้างสะพาน": levels passed (of 50), stars (of 150), stickers collected.
  final int bridgeLevelsPassed;
  final int bridgeStars;
  final int bridgeStickers;

  factory LearningReport.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> map(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    List<Map<String, dynamic>> list(dynamic v) =>
        v is List ? v.whereType<Map>().map(map).toList() : [];
    final words = map(j['words']);
    final ex = map(j['exercises']);
    final streak = map(j['streak']);
    return LearningReport(
      wordsLearned: _int(words['learned']),
      wordsLearning: _int(words['learning']),
      wordsTotal: _int(words['total']),
      exercisesPassed: _int(ex['passed']),
      exercisesTotal: _int(ex['total']),
      exerciseAttempts: _int(ex['attempts']),
      averageScore: ex['averageScore'] == null ? null : _int(ex['averageScore']),
      passPercent: ex['passPercent'] == null ? 60 : _int(ex['passPercent']),
      categories: list(j['categories']).map(CategoryProgress.fromJson).toList(),
      weakCategories:
          list(j['weakCategories']).map(CategoryProgress.fromJson).toList(),
      weakWords:
          list(j['weakWords'])
              .map(
                (w) => WeakWord(
                  w['term']?.toString() ?? '-',
                  w['translation']?.toString() ?? '',
                  _int(w['wrongCount']),
                ),
              )
              .toList(),
      currentStreak: _int(streak['current']),
      longestStreak: _int(streak['longest']),
      checkinDaysLast7: _int(streak['checkinDaysLast7']),
      listening: ListeningSummary.fromJson(map(j['listening'])),
      phonics: PhonicsSummary.fromJson(map(j['phonics'])),
      alphabetLevelsPassed: _int(map(j['alphabetTrain'])['levelsPassed']),
      alphabetStars: _int(map(j['alphabetTrain'])['stars']),
      monsterLevelsPassed: _int(map(j['monsterBattle'])['levelsPassed']),
      monsterStars: _int(map(j['monsterBattle'])['stars']),
      monstersBeaten: _int(map(j['monsterBattle'])['monstersBeaten']),
      marketLevelsPassed: _int(map(j['miniMarket'])['levelsPassed']),
      marketStars: _int(map(j['miniMarket'])['stars']),
      marketItemsCollected: _int(map(j['miniMarket'])['itemsCollected']),
      bridgeLevelsPassed: _int(map(j['bridgeBuilder'])['levelsPassed']),
      bridgeStars: _int(map(j['bridgeBuilder'])['stars']),
      bridgeStickers: _int(map(j['bridgeBuilder'])['stickers']),
    );
  }
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

class ParentalApiService {
  ParentalApiService._();

  static const Duration _timeout = Duration(seconds: 12);
  static const String _base = ApiConfig.api;

  static Future<LearningReport> getReport() async {
    final json = await _request('GET', '$_base/parent/report');
    return LearningReport.fromJson(json);
  }

  /// Checks the account password (POST /api/profile/verify-password).
  /// Returns normally when correct; throws [ParentalApiException] with code
  /// `WRONG_PASSWORD` or `TOO_MANY_ATTEMPTS` otherwise.
  static Future<void> verifyPassword(String password) async {
    await _request(
      'POST',
      '$_base/profile/verify-password',
      body: {'password': password},
    );
  }

  /// Permanently deletes the signed in account and all its data
  /// (POST /api/profile/delete-account). Needs the account password; throws
  /// [ParentalApiException] (`WRONG_PASSWORD`, `TOO_MANY_ATTEMPTS`, ...)
  /// when the account was not deleted.
  static Future<void> deleteAccount(String password) async {
    await _request(
      'POST',
      '$_base/profile/delete-account',
      body: {'password': password},
    );
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String url, {
    Map<String, Object?>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      throw const ParentalApiException(
        'กรุณาเข้าสู่ระบบใหม่',
        code: 'UNAUTHENTICATED',
      );
    }
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    late final http.Response response;
    try {
      response =
          method == 'POST'
              ? await http
                  .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
                  .timeout(_timeout)
              : await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
    } on TimeoutException {
      throw const ParentalApiException(
        'เชื่อมต่อใช้เวลานานเกินไป กรุณาลองอีกครั้ง',
        code: 'TIMEOUT',
      );
    } on http.ClientException {
      throw const ParentalApiException(
        'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบเครือข่าย',
        code: 'NETWORK_ERROR',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    final json =
        decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};

    if (response.statusCode == 401) {
      throw const ParentalApiException(
        'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
        code: 'UNAUTHENTICATED',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final code = error is Map ? error['code']?.toString() : null;
      throw ParentalApiException(switch (code) {
        'WRONG_PASSWORD' => 'รหัสผ่านไม่ถูกต้อง',
        'TOO_MANY_ATTEMPTS' => 'ใส่รหัสผ่านผิดหลายครั้งเกินไป กรุณารอ 15 นาที',
        'DELETE_ACCOUNT_FAILED' => 'ลบบัญชีไม่สำเร็จ กรุณาลองอีกครั้ง',
        'REPORT_LOAD_FAILED' => 'โหลดรายงานไม่สำเร็จ กรุณาลองอีกครั้ง',
        _ => 'ทำรายการไม่สำเร็จ (HTTP ${response.statusCode})',
      }, code: code);
    }
    if (decoded is! Map) {
      throw const ParentalApiException(
        'เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง',
        code: 'INVALID_RESPONSE',
      );
    }
    return json;
  }
}
