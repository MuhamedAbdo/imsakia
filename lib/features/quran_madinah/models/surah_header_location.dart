class SurahHeaderLocation {
  final int number;
  final int pageNumber;
  final double headerPosition;
  final String nameArabic;
  final String nameEnglish;

  SurahHeaderLocation({
    required this.number,
    required this.pageNumber,
    required this.headerPosition,
    required this.nameArabic,
    required this.nameEnglish,
  });

  factory SurahHeaderLocation.fromJson(Map<String, dynamic> json) {
    return SurahHeaderLocation(
      number: json['number'] as int,
      pageNumber: json['pageNumber'] as int,
      headerPosition: (json['headerPosition'] as num).toDouble(),
      nameArabic: json['nameArabic'] as String,
      nameEnglish: json['nameEnglish'] as String,
    );
  }
}
