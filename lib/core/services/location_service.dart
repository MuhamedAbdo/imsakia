import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/location_model.dart';

class LocationService {
  /// Request GPS permission and get current position.
  Future<LocationModel> getCurrentLocation({
    String locale = 'ar',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationServiceException('Location permissions denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
          'Location permissions are permanently denied.');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(timeout);

      return _reverseGeocode(
        position.latitude,
        position.longitude,
        locale: locale,
      );
    } catch (e) {
      // Critical Fallback: If GPS fails or times out, default to Cairo
      return const LocationModel(
        latitude: 30.0444,
        longitude: 31.2357,
        cityName: 'القاهرة',
        countryName: 'مصر',
        countryCode: 'EG',
      );
    }
  }

  /// Reverse-geocode coordinates to a [LocationModel].
  Future<LocationModel> _reverseGeocode(
    double lat,
    double lon, {
    String locale = 'ar',
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return LocationModel(
          latitude: lat,
          longitude: lon,
          cityName: p.locality ?? p.subAdministrativeArea ?? 'Unknown',
          countryName: p.country ?? 'Unknown',
          countryCode: p.isoCountryCode,
        );
      }
    } catch (_) {}
    return LocationModel(
      latitude: lat,
      longitude: lon,
      cityName: 'Unknown',
      countryName: 'Unknown',
    );
  }

  /// Get location model from manual coordinates (e.g., city selection).
  Future<LocationModel> fromCoordinates(
    double lat,
    double lon, {
    required String cityName,
    required String countryName,
    String? countryCode,
  }) async {
    return LocationModel(
      latitude: lat,
      longitude: lon,
      cityName: cityName,
      countryName: countryName,
      countryCode: countryCode,
    );
  }
}

class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);
  @override
  String toString() => 'LocationServiceException: $message';
}
