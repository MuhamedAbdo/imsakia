/// نموذج بيانات الأذان المُجلَب من الـ API
class AthanModel {
  final String id;
  final String name;
  final String url;
  final bool isFajr;

  const AthanModel({
    required this.id,
    required this.name,
    required this.url,
    required this.isFajr,
  });

  factory AthanModel.fromJson(Map<String, dynamic> json) {
    return AthanModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      isFajr: json['isFajr'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'isFajr': isFajr,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AthanModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
