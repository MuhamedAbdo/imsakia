class Aya {
  final int id;
  final int jozz;
  final int suraNo;
  final String suraNameEn;
  final String suraNameAr;
  final int page;
  final int lineStart;
  final int lineEnd;
  final int ayaNo;
  final String ayaText;
  final String ayaTextEmlaey;

  Aya({
    required this.id,
    required this.jozz,
    required this.suraNo,
    required this.suraNameEn,
    required this.suraNameAr,
    required this.page,
    required this.lineStart,
    required this.lineEnd,
    required this.ayaNo,
    required this.ayaText,
    required this.ayaTextEmlaey,
  });

  factory Aya.fromJson(Map<String, dynamic> json) {
    return Aya(
      id: json['id'],
      jozz: json['jozz'],
      suraNo: json['sura_no'],
      suraNameEn: json['sura_name_en'],
      suraNameAr: json['sura_name_ar'],
      page: json['page'],
      lineStart: json['line_start'],
      lineEnd: json['line_end'],
      ayaNo: json['aya_no'],
      ayaText: json['aya_text'],
      ayaTextEmlaey: json['aya_text_emlaey'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jozz': jozz,
      'sura_no': suraNo,
      'sura_name_en': suraNameEn,
      'sura_name_ar': suraNameAr,
      'page': page,
      'line_start': lineStart,
      'line_end': lineEnd,
      'aya_no': ayaNo,
      'aya_text': ayaText,
      'aya_text_emlaey': ayaTextEmlaey,
    };
  }
}
