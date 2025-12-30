import 'verse.dart';

class SurahData {
  final int number;
  final String nameAr;
  final String nameEn;
  final String transliteration;
  final String revelationPlaceAr;
  final String revelationPlaceEn;
  final int versesCount;
  final int wordsCount;
  final int lettersCount;
  final List<Verse> verses;

  const SurahData({
    required this.number,
    required this.nameAr,
    required this.nameEn,
    required this.transliteration,
    required this.revelationPlaceAr,
    required this.revelationPlaceEn,
    required this.versesCount,
    required this.wordsCount,
    required this.lettersCount,
    required this.verses,
  });

  factory SurahData.fromJson(Map<String, dynamic> json) {
    final verses = (json['verses'] as List)
        .map((verseJson) => Verse.fromJson(verseJson as Map<String, dynamic>))
        .toList();

    return SurahData(
      number: json['number'] as int,
      nameAr: json['name']['ar'] as String,
      nameEn: json['name']['en'] as String,
      transliteration: json['name']['transliteration'] as String,
      revelationPlaceAr: json['revelation_place']['ar'] as String,
      revelationPlaceEn: json['revelation_place']['en'] as String,
      versesCount: json['verses_count'] as int,
      wordsCount: json['words_count'] as int,
      lettersCount: json['letters_count'] as int,
      verses: verses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'name': {
        'ar': nameAr,
        'en': nameEn,
        'transliteration': transliteration,
      },
      'revelation_place': {
        'ar': revelationPlaceAr,
        'en': revelationPlaceEn,
      },
      'verses_count': versesCount,
      'words_count': wordsCount,
      'letters_count': lettersCount,
      'verses': verses.map((verse) => verse.toJson()).toList(),
    };
  }
}
