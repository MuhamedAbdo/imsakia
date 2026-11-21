class BattleEvent {
  final String id;
  final int sequence;
  final int chronoOrder;
  final bool hasFighting;
  final String type;
  final String typeTitle;
  final String name;
  final String dateLabel;
  final String location;
  final String commander;
  final String enemyCommander;
  final String muslimsCount;
  final String enemiesCount;
  final String muslimsMartyrs;
  final String enemiesCasualties;
  final String prisoners;
  final String summary;
  final String causes;
  final List<String> events;
  final String outcome;
  final List<String> lessons;
  final String source;

  const BattleEvent({
    required this.id,
    required this.sequence,
    this.chronoOrder = 0,
    this.hasFighting = false,
    required this.type,
    required this.typeTitle,
    required this.name,
    required this.dateLabel,
    required this.location,
    required this.commander,
    this.enemyCommander = '',
    required this.muslimsCount,
    required this.enemiesCount,
    this.muslimsMartyrs = '',
    this.enemiesCasualties = '',
    this.prisoners = '',
    required this.summary,
    required this.causes,
    required this.events,
    required this.outcome,
    required this.lessons,
    required this.source,
  });

  factory BattleEvent.fromJson(Map<String, dynamic> json) {
    return BattleEvent(
      id: json['id'] as String? ?? '',
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      chronoOrder: (json['chrono_order'] as num?)?.toInt() ?? 0,
      hasFighting: json['has_fighting'] as bool? ?? false,
      type: json['type'] as String? ?? '',
      typeTitle: json['type_title'] as String? ?? '',
      name: json['name'] as String? ?? '',
      dateLabel: json['date_label'] as String? ?? '',
      location: json['location'] as String? ?? '',
      commander: json['commander'] as String? ?? '',
      enemyCommander: json['enemy_commander'] as String? ?? '',
      muslimsCount: json['muslims_count'] as String? ?? '',
      enemiesCount: json['enemies_count'] as String? ?? '',
      muslimsMartyrs: json['muslims_martyrs'] as String? ?? '',
      enemiesCasualties: json['enemies_casualties'] as String? ?? '',
      prisoners: json['prisoners'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      causes: json['causes'] as String? ?? '',
      events: (json['events'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      outcome: json['outcome'] as String? ?? '',
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
      'chrono_order': chronoOrder,
      'has_fighting': hasFighting,
      'type': type,
      'type_title': typeTitle,
      'name': name,
      'date_label': dateLabel,
      'location': location,
      'commander': commander,
      'enemy_commander': enemyCommander,
      'muslims_count': muslimsCount,
      'enemies_count': enemiesCount,
      'muslims_martyrs': muslimsMartyrs,
      'enemies_casualties': enemiesCasualties,
      'prisoners': prisoners,
      'summary': summary,
      'causes': causes,
      'events': events,
      'outcome': outcome,
      'lessons': lessons,
      'source': source,
    };
  }
}
