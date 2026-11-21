class HistoryEvent {
  final String id;
  final int sequence;
  final int chronoOrder;
  final String category; // rashidun | fitna | umayyad | abbasid | contemporary | ottoman | andalus | crusades | mongols
  final String categoryTitle;
  final String title;
  final String period;
  final String location;
  final String keyFigures;
  final String summary;
  final List<String> details;
  final String impact;
  final String source;

  const HistoryEvent({
    required this.id,
    required this.sequence,
    required this.chronoOrder,
    required this.category,
    required this.categoryTitle,
    required this.title,
    required this.period,
    required this.location,
    required this.keyFigures,
    required this.summary,
    required this.details,
    required this.impact,
    required this.source,
  });

  factory HistoryEvent.fromJson(Map<String, dynamic> json) {
    return HistoryEvent(
      id: json['id'] as String? ?? '',
      sequence: json['sequence'] as int? ?? 0,
      chronoOrder: json['chronoOrder'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      categoryTitle: json['categoryTitle'] as String? ?? '',
      title: json['title'] as String? ?? '',
      period: json['period'] as String? ?? '',
      location: json['location'] as String? ?? '',
      keyFigures: json['keyFigures'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      details: (json['details'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      impact: json['impact'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sequence': sequence,
      'chronoOrder': chronoOrder,
      'category': category,
      'categoryTitle': categoryTitle,
      'title': title,
      'period': period,
      'location': location,
      'keyFigures': keyFigures,
      'summary': summary,
      'details': details,
      'impact': impact,
      'source': source,
    };
  }
}
