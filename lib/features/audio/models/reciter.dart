class Reciter {
  final String id;
  final String name;
  final String serverUrl;
  final String rewaya;
  final List<int> availableSurahs;

  Reciter({
    required this.id,
    required this.name,
    required this.serverUrl,
    required this.rewaya,
    required this.availableSurahs,
  });

  factory Reciter.fromJson(Map<String, dynamic> json) {
    String server = "";
    String rewayaName = "";
    List<int> availableSurahs = [];
    
    if (json['moshaf'] != null && (json['moshaf'] as List).isNotEmpty) {
      server = json['moshaf'][0]['server'].toString();
      rewayaName = json['moshaf'][0]['name'].toString();
      
      final surahListStr = json['moshaf'][0]['surah_list']?.toString() ?? "";
      if (surahListStr.isNotEmpty) {
        availableSurahs = surahListStr
            .split(',')
            .map((e) => int.tryParse(e.trim()) ?? 0)
            .where((id) => id > 0 && id <= 114)
            .toList();
      }
    }
    
    if (availableSurahs.isEmpty) {
      availableSurahs = List.generate(114, (i) => i + 1);
    }
    
    return Reciter(
      id: json['id'].toString(),
      name: json['name'].toString(),
      serverUrl: server,
      rewaya: rewayaName,
      availableSurahs: availableSurahs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'serverUrl': serverUrl,
      'rewaya': rewaya,
      'availableSurahs': availableSurahs.join(','),
    };
  }

  factory Reciter.fromLocalJson(Map<String, dynamic> json) {
    List<int> surahs = [];
    final surahsStr = json['availableSurahs']?.toString() ?? "";
    if (surahsStr.isNotEmpty) {
      surahs = surahsStr
          .split(',')
          .map((e) => int.tryParse(e) ?? 0)
          .where((id) => id > 0 && id <= 114)
          .toList();
    } else {
      surahs = List.generate(114, (i) => i + 1);
    }
    
    return Reciter(
      id: json['id'].toString(),
      name: json['name'].toString(),
      serverUrl: json['serverUrl'].toString(),
      rewaya: json['rewaya'].toString(),
      availableSurahs: surahs,
    );
  }
}
