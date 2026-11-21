class Companion {
  final String id;
  final int sequence;
  final String category; // ashara | ahl_albayt_women | men
  final String categoryTitle;
  final String name;
  final String title; // اللقب الشهير
  final String caliphBadge; // اختياري، افتراضياً ''
  final String birthDeath; // تاريخ الميلاد والوفاة
  final String summary; // نبذة سريعة
  final String islamStory; // إسلامه ونشأته
  final List<String> virtues; // أبرز المناقب والفضائل
  final List<String> keyMoments; // مواقف خالدة من حياته
  final String famousQuote; // مقولة شهيرة له أو قيلت فيه
  final String source; // المصدر والتوثيق

  const Companion({
    required this.id,
    required this.sequence,
    required this.category,
    required this.categoryTitle,
    required this.name,
    required this.title,
    this.caliphBadge = '',
    required this.birthDeath,
    required this.summary,
    required this.islamStory,
    required this.virtues,
    required this.keyMoments,
    required this.famousQuote,
    required this.source,
  });

  bool get isFemale =>
      category == 'mothers' ||
      name.contains('بنت') ||
      name.startsWith('أم ');

  factory Companion.fromJson(Map<String, dynamic> json) {
    return Companion(
      id: json['id'] as String? ?? '',
      sequence: json['sequence'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      categoryTitle: json['categoryTitle'] as String? ?? '',
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      caliphBadge: json['caliphBadge'] as String? ?? '',
      birthDeath: json['birthDeath'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      islamStory: json['islamStory'] as String? ?? '',
      virtues: (json['virtues'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      keyMoments: (json['keyMoments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      famousQuote: json['famousQuote'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sequence': sequence,
      'category': category,
      'categoryTitle': categoryTitle,
      'name': name,
      'title': title,
      'caliphBadge': caliphBadge,
      'birthDeath': birthDeath,
      'summary': summary,
      'islamStory': islamStory,
      'virtues': virtues,
      'keyMoments': keyMoments,
      'famousQuote': famousQuote,
      'source': source,
    };
  }
}
