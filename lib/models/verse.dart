class Verse {
  final int number;
  final String arabicText;
  final String englishText;
  final int juz;
  final int page;
  final bool sajda;

  const Verse({
    required this.number,
    required this.arabicText,
    required this.englishText,
    required this.juz,
    required this.page,
    required this.sajda,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      number: json['number'] as int,
      arabicText: json['text']['ar'] as String,
      englishText: json['text']['en'] as String,
      juz: json['juz'] as int,
      page: json['page'] as int,
      sajda: json['sajda'] as bool,
    );
  }

  // Constructor for quran2 format
  Verse.fromQuran2({
    required this.number,
    required this.arabicText,
    this.englishText = '',
    this.juz = 0,
    this.page = 0,
    this.sajda = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'text': {
        'ar': arabicText,
        'en': englishText,
      },
      'juz': juz,
      'page': page,
      'sajda': sajda,
    };
  }
}
