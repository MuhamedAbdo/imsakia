/// نموذج بيانات الأذان المُجلَب من الـ API أو المدمج في التطبيق
class AthanModel {
  final String id;
  final String name;
  final String url;
  final bool isFajr;
  final String? assetPath;

  const AthanModel({
    required this.id,
    required this.name,
    required this.url,
    required this.isFajr,
    this.assetPath,
  });

  /// هل هذا الصوت مدمج محلياً في الـ assets
  bool get isAsset => assetPath != null && assetPath!.isNotEmpty;

  factory AthanModel.fromJson(Map<String, dynamic> json) {
    return AthanModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      isFajr: json['isFajr'] as bool? ?? false,
      assetPath: json['assetPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'isFajr': isFajr,
        if (assetPath != null) 'assetPath': assetPath,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AthanModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
