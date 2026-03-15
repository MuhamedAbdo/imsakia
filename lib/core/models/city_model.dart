class CityModel {
  final String name;
  final String nameAr;
  final String country;
  final String countryAr;
  final String countryCode;
  final double latitude;
  final double longitude;

  const CityModel({
    required this.name,
    required this.nameAr,
    required this.country,
    required this.countryAr,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) => CityModel(
        name: json['name'] as String,
        nameAr: json['nameAr'] as String? ?? json['name'] as String,
        country: json['country'] as String,
        countryAr: json['countryAr'] as String? ?? json['country'] as String,
        countryCode: json['countryCode'] as String,
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lon'] as num).toDouble(),
      );

  String displayName(String locale) =>
      locale == 'ar' ? '$nameAr، $countryAr' : '$name, $country';
}
