class VocabularyCategory {
  const VocabularyCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.sortOrder,
    required this.wordCount,
  });

  /// BIGSERIAL identifiers may be encoded as either JSON numbers or strings.
  final String id;
  final String slug;
  final String name;
  final int sortOrder;
  final int wordCount;

  factory VocabularyCategory.fromJson(Map<String, dynamic> json) {
    return VocabularyCategory(
      id: _requiredId(json, 'id'),
      slug: _requiredString(json, 'slug'),
      name: _requiredString(json, 'name'),
      sortOrder: _requiredInt(json, 'sort_order'),
      wordCount: _requiredInt(json, 'word_count'),
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
