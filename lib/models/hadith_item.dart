class HadithItem {
  final int number;
  final String hadith;
  final String description;
  final String searchTerm;
  final String? bookKey;

  const HadithItem({
    required this.number,
    required this.hadith,
    required this.description,
    required this.searchTerm,
    this.bookKey,
  });

  factory HadithItem.fromJson(Map<String, dynamic> json) {
    return HadithItem(
      number: json['number'] as int,
      hadith: json['hadith'] as String,
      description: json['description'] as String,
      searchTerm: json['searchTerm'] as String,
      bookKey: json['bookKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'hadith': hadith,
      'description': description,
      'searchTerm': searchTerm,
      'bookKey': bookKey,
    };
  }

  /// الحصول على معاينة مختصرة للحديث (سطرين فقط)
  String get preview {
    final lines = hadith.split('\n');
    if (lines.length <= 2) return hadith;
    return '${lines[0]}\n${lines[1]}...';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HadithItem &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          hadith == other.hadith;

  @override
  int get hashCode => number.hashCode ^ hadith.hashCode;
}

