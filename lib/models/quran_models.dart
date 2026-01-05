class QuranAyah {
  final int surahNumber;
  final int ayahNumber;
  final String arabicText;
  String? tafsir;
  int? juz;
  int? hizbQuarter;

  QuranAyah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.arabicText,
    this.tafsir,
    this.juz,
    this.hizbQuarter,
  });

  factory QuranAyah.fromJson(Map<String, dynamic> json) {
    return QuranAyah(
      surahNumber: json['surahNumber'] ?? 0,
      ayahNumber: json['ayahNumber'] ?? 0,
      arabicText: json['arabicText'] ?? '',
      tafsir: json['tafsir'],
      juz: json['juz'],
      hizbQuarter: json['hizbQuarter'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surahNumber': surahNumber,
      'ayahNumber': ayahNumber,
      'arabicText': arabicText,
      'tafsir': tafsir,
      'juz': juz,
      'hizbQuarter': hizbQuarter,
    };
  }

  String get ayahIdentifier => '$surahNumber:$ayahNumber';
}

class QuranSurah {
  final int number;
  final String name;
  final String englishName;
  final String revelationType;
  final int ayahCount;
  final List<QuranAyah> ayahs;

  QuranSurah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.revelationType,
    required this.ayahCount,
    required this.ayahs,
  });

  factory QuranSurah.fromJson(Map<String, dynamic> json) {
    var ayahsList = json['ayahs'] as List?;
    List<QuranAyah> ayahs = ayahsList?.map((i) => QuranAyah.fromJson(i)).toList() ?? [];

    return QuranSurah(
      number: json['number'] ?? 0,
      name: json['name'] ?? '',
      englishName: json['englishName'] ?? '',
      revelationType: json['revelationType'] ?? '',
      ayahCount: json['ayahCount'] ?? 0,
      ayahs: ayahs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'name': name,
      'englishName': englishName,
      'revelationType': revelationType,
      'ayahCount': ayahCount,
      'ayahs': ayahs.map((ayah) => ayah.toJson()).toList(),
    };
  }

  bool get hasBasmala => number != 1 && number != 9;
}
