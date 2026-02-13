import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/app_constants.dart';
import 'hijri_date_service.dart';

class PrayerTimesService {
  static PrayerTimesService? _instance;
  static PrayerTimesService get instance =>
      _instance ??= PrayerTimesService._();

  PrayerTimesService._();

  Map<String, DateTime>? _currentPrayerTimes;
  StreamController<Map<String, DateTime>>? _prayerTimesController;
  Timer? _updateTimer;
  SharedPreferences? _sharedPreferences;

  Duration? _cachedTimeUntilRamadan;
  DateTime? _lastRamadanCalculation;

  Stream<Map<String, DateTime>> get prayerTimesStream =>
      (_prayerTimesController ??=
              StreamController<Map<String, DateTime>>.broadcast())
          .stream;

  Future<Map<String, DateTime>?> getCurrentPrayerTimes() async {
    final location = await _getCurrentLocation();
    if (location == null) return null;

    _sharedPreferences ??= await SharedPreferences.getInstance();
    final calculationMethod =
        _sharedPreferences!.getString(AppConstants.calculationMethodKey) ??
        AppConstants.defaultCalculationMethod;
    final madhab =
        _sharedPreferences!.getString(AppConstants.madhabKey) ??
        AppConstants.defaultMadhab;
    final dstEnabled =
        _sharedPreferences!.getBool(AppConstants.dstKey) ??
        AppConstants.defaultDST;

    final now = DateTime.now();
    final date = DateComponents(now.year, now.month, now.day);
    final coordinates = Coordinates(location.latitude, location.longitude);

    CalculationParameters params;
    switch (calculationMethod) {
      case 'egyptian':
        params = CalculationMethod.egyptian.getParameters();
        break;
      case 'turkey':
        params = CalculationMethod.turkey.getParameters();
        break;
      case 'karachi':
        params = CalculationMethod.karachi.getParameters();
        break;
      case 'umm_al_qura':
        params = CalculationMethod.umm_al_qura.getParameters();
        break;
      case 'dubai':
        params = CalculationMethod.dubai.getParameters();
        break;
      case 'kuwait':
        params = CalculationMethod.kuwait.getParameters();
        break;
      case 'qatar':
        params = CalculationMethod.qatar.getParameters();
        break;
      case 'muslim_world_league':
        params = CalculationMethod.muslim_world_league.getParameters();
        break;
      case 'north_america':
        params = CalculationMethod.north_america.getParameters();
        break;
      default:
        params = CalculationMethod.egyptian.getParameters();
    }

    params.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    final prayerTimes = PrayerTimes(coordinates, date, params);

    final deviceOffsetHours = now.timeZoneOffset.inHours;
    int targetOffsetHours = deviceOffsetHours;
    String country = location.country.toLowerCase();

    // تصحيح فوارق التوقيت للدول
    if (country.contains("turkey")) {
      targetOffsetHours = 3;
    } else if (country.contains("algeria") || country.contains("morocco")) {
      targetOffsetHours = 1;
    } else if (country.contains("egypt")) {
      targetOffsetHours = 2;
    } else if (country.contains("saudi") ||
        country.contains("qatar") ||
        country.contains("kuwait")) {
      targetOffsetHours = 3;
    } else if (country.contains("united arab emirates") ||
        country.contains("emirates") ||
        country.contains("uae")) {
      targetOffsetHours = 4; // الإمارات GMT+4
    }

    final timezoneCorrection = Duration(
      hours: targetOffsetHours - deviceOffsetHours,
    );
    final totalOffset =
        timezoneCorrection +
        (dstEnabled ? const Duration(hours: 1) : Duration.zero);

    _currentPrayerTimes = {
      'fajr': prayerTimes.fajr.add(totalOffset),
      'sunrise': prayerTimes.sunrise.add(totalOffset),
      'dhuhr': prayerTimes.dhuhr.add(totalOffset),
      'asr': prayerTimes.asr.add(totalOffset),
      'maghrib': prayerTimes.maghrib.add(totalOffset),
      'isha': prayerTimes.isha.add(totalOffset),
    };

    _prayerTimesController?.add(_currentPrayerTimes!);
    _startUpdateTimer();
    return _currentPrayerTimes;
  }

  Future<LocationSettings?> _getCurrentLocation() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
    final selectedCity =
        _sharedPreferences!.getString(AppConstants.selectedCityKey) ??
        "Cairo, Egypt";

    double? cachedLat = _sharedPreferences!.getDouble('last_lat');
    double? cachedLng = _sharedPreferences!.getDouble('last_lng');

    if (cachedLat != null && cachedLng != null) {
      return LocationSettings(
        latitude: cachedLat,
        longitude: cachedLng,
        city: selectedCity.split(',').first.trim(),
        country: selectedCity.split(',').last.trim(),
      );
    }

    try {
      List<Location> locations = await locationFromAddress(selectedCity);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        await _sharedPreferences!.setDouble('last_lat', loc.latitude);
        await _sharedPreferences!.setDouble('last_lng', loc.longitude);
        return LocationSettings(
          latitude: loc.latitude,
          longitude: loc.longitude,
          city: selectedCity.split(',').first.trim(),
          country: selectedCity.split(',').last.trim(),
        );
      }
    } catch (e) {
      print("Geocoding Error: $e");
    }

    return LocationSettings(
      latitude: 30.0444,
      longitude: 31.2357,
      city: "Cairo",
      country: "Egypt",
    );
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      AppConstants.countdownUpdateInterval,
      (timer) => _updatePrayerTimes(),
    );
  }

  Future<void> _updatePrayerTimes() async => await getCurrentPrayerTimes();

  String? getNextPrayer() {
    if (_currentPrayerTimes == null) return null;
    final now = DateTime.now();
    for (final entry in _currentPrayerTimes!.entries) {
      if (entry.value.isAfter(now)) return entry.key;
    }
    return 'fajr';
  }

  DateTime? getNextPrayerTime() {
    if (_currentPrayerTimes == null) return null;
    final nextPrayer = getNextPrayer();
    final prayerTime = _currentPrayerTimes![nextPrayer];
    if (prayerTime == null) return null;

    if (prayerTime.isBefore(DateTime.now())) {
      return prayerTime.add(const Duration(days: 1));
    }
    return prayerTime;
  }

  Duration? getTimeUntilNextPrayer() {
    final nextTime = getNextPrayerTime();
    return nextTime?.difference(DateTime.now());
  }

  Future<Duration?> getTimeUntilRamadan() async {
    final now = DateTime.now();
    _sharedPreferences ??= await SharedPreferences.getInstance();
    final adj = _sharedPreferences!.getInt('hijri_adjustment') ?? 0;

    DateTime start = HijriDateService.getNextRamadanStart(now, adj);
    Duration diff = start.difference(now);

    // معالجة مشكلة القفز للسنة القادمة (إذا كان الفارق يقارب سنة كاملة ونحن في شعبان)
    if (diff.inDays > 350) {
      // طرح سنة هجرية (354 يوم تقريباً) للحصول على موعد رمضان الحالي المتوقع
      start = start.subtract(const Duration(days: 354));
      diff = start.difference(now);
    }

    _cachedTimeUntilRamadan = diff;
    _lastRamadanCalculation = now;
    return _cachedTimeUntilRamadan;
  }

  void dispose() {
    _updateTimer?.cancel();
    _prayerTimesController?.close();
  }
}

class LocationSettings {
  final double latitude;
  final double longitude;
  final String city;
  final String country;
  LocationSettings({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
  });
}

extension PrayerTimeFormatting on DateTime? {
  String getFormattedTime() =>
      this == null ? '--:--' : DateFormat('h:mm a', 'en_US').format(this!);
}
