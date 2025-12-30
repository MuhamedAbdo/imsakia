class Surah {
  final int number;
  final String name;
  final String englishName;
  final int totalAyahs;
  final String revelationType;
  final int startPage;

  const Surah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.totalAyahs,
    required this.revelationType,
    required this.startPage,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      number: json['number'],
      name: json['name'],
      englishName: json['englishName'],
      totalAyahs: json['totalAyahs'],
      revelationType: json['type'],
      startPage: json['startPage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'name': name,
      'englishName': englishName,
      'totalAyahs': totalAyahs,
      'type': revelationType,
      'startPage': startPage,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Surah &&
          runtimeType == other.runtimeType &&
          number == other.number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() {
    return 'Surah{number: $number, name: $name, englishName: $englishName, totalAyahs: $totalAyahs, revelationType: $revelationType, startPage: $startPage}';
  }
}
