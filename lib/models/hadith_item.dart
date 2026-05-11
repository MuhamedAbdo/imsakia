class HadithItem {
  final int number;
  final String hadith;
  final String description;
  final String searchTerm;

  const HadithItem({
    required this.number,
    required this.hadith,
    required this.description,
    required this.searchTerm,
  });

  factory HadithItem.fromJson(Map<String, dynamic> json) {
    return HadithItem(
      number: json['number'] as int,
      hadith: json['hadith'] as String,
      description: json['description'] as String,
      searchTerm: json['searchTerm'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'hadith': hadith,
      'description': description,
      'searchTerm': searchTerm,
    };
  }

  /// الحصول على معاينة مختصرة للحديث (سطرين فقط)
  String get preview {
    final lines = hadith.split('\n');
    if (lines.length <= 2) return hadith;
    return '${lines[0]}\n${lines[1]}...';
  }
}
