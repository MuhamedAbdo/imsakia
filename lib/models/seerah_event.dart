class SeerahEvent {
  final String id;
  final int sequence;
  final String phase;
  final String phaseTitle;
  final String dateLabel;
  final String title;
  final String summary;
  final List<String> details;
  final List<String> lessons;
  final String source;

  const SeerahEvent({
    required this.id,
    required this.sequence,
    required this.phase,
    required this.phaseTitle,
    required this.dateLabel,
    required this.title,
    required this.summary,
    required this.details,
    required this.lessons,
    required this.source,
  });

  factory SeerahEvent.fromJson(Map<String, dynamic> json) {
    return SeerahEvent(
      id: json['id'] as String? ?? '',
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      phase: json['phase'] as String? ?? '',
      phaseTitle: json['phase_title'] as String? ?? '',
      dateLabel: json['date_label'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      details: (json['details'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      lessons: (json['lessons'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      source: json['source'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sequence': sequence,
      'phase': phase,
      'phase_title': phaseTitle,
      'date_label': dateLabel,
      'title': title,
      'summary': summary,
      'details': details,
      'lessons': lessons,
      'source': source,
    };
  }
}
