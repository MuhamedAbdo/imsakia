class CustomOccasion {
  final String id;
  final String title;
  final String description;
  final bool isHijri;
  final int month;
  final int day;

  CustomOccasion({
    required this.id,
    required this.title,
    required this.description,
    required this.isHijri,
    required this.month,
    required this.day,
  });

  factory CustomOccasion.fromJson(Map<String, dynamic> json) {
    return CustomOccasion(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      isHijri: json['isHijri'] as bool,
      month: json['month'] as int,
      day: json['day'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isHijri': isHijri,
      'month': month,
      'day': day,
    };
  }
}
