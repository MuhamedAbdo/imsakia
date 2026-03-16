class Reciter {
  final String id;
  final String name;
  final String serverUrl;
  final String rewaya;

  Reciter({
    required this.id,
    required this.name,
    required this.serverUrl,
    required this.rewaya,
  });

  factory Reciter.fromJson(Map<String, dynamic> json) {
    String server = "";
    String rewayaName = "";
    if (json['moshaf'] != null && (json['moshaf'] as List).isNotEmpty) {
      server = json['moshaf'][0]['server'].toString();
      rewayaName = json['moshaf'][0]['name'].toString();
    }
    return Reciter(
      id: json['id'].toString(),
      name: json['name'].toString(),
      serverUrl: server,
      rewaya: rewayaName,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'serverUrl': serverUrl, 'rewaya': rewaya};
  }

  factory Reciter.fromLocalJson(Map<String, dynamic> json) {
    return Reciter(
      id: json['id'].toString(),
      name: json['name'].toString(),
      serverUrl: json['serverUrl'].toString(),
      rewaya: json['rewaya'].toString(),
    );
  }
}
