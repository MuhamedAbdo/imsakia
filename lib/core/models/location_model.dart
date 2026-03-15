class LocationModel {
  final double latitude;
  final double longitude;
  final String cityName;
  final String countryName;
  final String? countryCode;

  const LocationModel({
    required this.latitude,
    required this.longitude,
    required this.cityName,
    required this.countryName,
    this.countryCode,
  });

  LocationModel copyWith({
    double? latitude,
    double? longitude,
    String? cityName,
    String? countryName,
    String? countryCode,
  }) {
    return LocationModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      cityName: cityName ?? this.cityName,
      countryName: countryName ?? this.countryName,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'cityName': cityName,
        'countryName': countryName,
        'countryCode': countryCode,
      };

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        cityName: json['cityName'] as String,
        countryName: json['countryName'] as String,
        countryCode: json['countryCode'] as String?,
      );

  @override
  String toString() => '$cityName, $countryName';
}
