class BukhariSection {
  final int id;
  final String title;
  final List<BukhariHadith> hadiths;

  BukhariSection({required this.id, required this.title, required this.hadiths});
}

class BukhariHadith {
  final int id;
  final String text;

  BukhariHadith({required this.id, required this.text});

  factory BukhariHadith.fromMap(Map<String, dynamic> map) {
    return BukhariHadith(
      id: map['id'],
      text: map['text'],
    );
  }
}