class Hadith {
  final int id;
  final String text;
  final String source;
  
  Hadith({
    required this.id,
    required this.text,
    required this.source,
  });
  
  factory Hadith.fromJson(Map<String, dynamic> json) {
    return Hadith(
      id: json['id'] as int,
      text: json['text'] as String,
      source: json['source'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'source': source,
    };
  }
}
