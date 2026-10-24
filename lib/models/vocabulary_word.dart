abstract interface class VocabularyWordView {
  String get word;
  String get thaiPhonetics;
  String get translation;
  String get imagePath;
  String get phonetics;
  String? get audioUrl;
}

class VocabularyWord implements VocabularyWordView {
  const VocabularyWord({
    required this.id,
    required this.categorySlug,
    required this.term,
    required this.translation,
    required this.thaiPronunciation,
    required this.imageUrl,
    required this.audioUrl,
    required this.sortOrder,
  });

  /// BIGSERIAL identifiers may be encoded as either JSON numbers or strings.
  final String id;
  final String categorySlug;
  final String term;
  @override
  final String translation;
  final String? thaiPronunciation;
  final String? imageUrl;
  @override
  final String? audioUrl;
  final int sortOrder;

  @override
  String get word => term;

  @override
  String get thaiPhonetics => thaiPronunciation ?? '';

  @override
  String get imagePath => imageUrl ?? '';

  /// The API does not currently provide an IPA field.
  @override
  String get phonetics => '';

  factory VocabularyWord.fromJson(Map<String, dynamic> json) {
    return VocabularyWord(
      id: _requiredId(json, 'id'),
      categorySlug: _requiredString(json, 'category_slug'),
      term: _requiredString(json, 'term'),
      translation: _requiredString(json, 'translation'),
      thaiPronunciation: _optionalString(json, 'thai_pronunciation'),
      imageUrl: _optionalString(json, 'image_url'),
      audioUrl: _optionalString(json, 'audio_url'),
      sortOrder: _requiredInt(json, 'sort_order'),
    );
  }
}

String _requiredId(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  if (value is int) return value.toString();
  throw FormatException('Invalid or missing "$key"');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Invalid or missing "$key"');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Invalid "$key"');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid or missing "$key"');
}
