import 'package:flutter/foundation.dart';
import '../core/models/location_model.dart';
import '../core/models/city_model.dart';
import '../core/services/location_service.dart';
import '../core/services/storage_service.dart';

enum LocationStatus { idle, loading, loaded, error }

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;
  final StorageService _storage;

  LocationModel? _location;
  LocationStatus _status = LocationStatus.idle;
  String _errorMessage = '';

  LocationProvider(this._locationService, this._storage) {
    _location = _storage.getLastLocation();
    if (_location != null) _status = LocationStatus.loaded;
  }

  LocationModel? get location => _location;
  LocationStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get hasLocation => _location != null;

  Future<void> fetchGpsLocation({String locale = 'ar', Function(LocationModel)? onLocationChanged}) async {
    _status = LocationStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      _location = await _locationService.getCurrentLocation(
        locale: locale,
        timeout: const Duration(seconds: 10),
      );
      await _storage.saveLocation(_location!);
      _status = LocationStatus.loaded;
      if (onLocationChanged != null && _location != null) {
        onLocationChanged(_location!);
      }
    } catch (e) {
      _errorMessage = e.toString();
      // Service already handles Cairo fallback internally now, but we check storage too
      _location = _storage.getLastLocation();
      if (_location != null) {
        _status = LocationStatus.loaded;
        if (onLocationChanged != null) onLocationChanged(_location!);
      } else {
        _status = LocationStatus.error;
      }
    }
    notifyListeners();
  }

  Future<void> setManualLocation(CityModel city, {Function(LocationModel)? onLocationChanged}) async {
    _location = LocationModel(
      latitude: city.latitude,
      longitude: city.longitude,
      cityName: city.name,
      countryName: city.country,
      countryCode: city.countryCode,
    );
    await _storage.saveLocation(_location!);
    _status = LocationStatus.loaded;
    if (onLocationChanged != null) {
      onLocationChanged(_location!);
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    _status = _location != null ? LocationStatus.loaded : LocationStatus.idle;
    notifyListeners();
  }
}
