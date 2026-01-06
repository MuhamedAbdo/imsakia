import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/logger.dart';
import '../utils/app_constants.dart';

class PrayerTimesService {
  static PrayerTimesService? _instance;
  static PrayerTimesService get instance => _instance ??= PrayerTimesService._();

  PrayerTimesService._();

  Map<String, DateTime>? _currentPrayerTimes;
  StreamController<Map<String, DateTime>>? _prayerTimesController;
  Timer? _updateTimer;
  
  // Cache for Ramadan countdown
  Duration? _cachedTimeUntilRamadan;
  DateTime? _lastRamadanCalculation;

  Stream<Map<String, DateTime>> get prayerTimesStream => 
      (_prayerTimesController ??= StreamController<Map<String, DateTime>>.broadcast()).stream;

  Future<Map<String, DateTime>?> getCurrentPrayerTimes() async {
    final location = await _getCurrentLocation();
    if (location == null) return null;

    final now = DateTime.now();
    final date = DateComponents(now.year, now.month, now.day);
    
    final coordinates = Coordinates(location.latitude, location.longitude);
    
    final params = CalculationParameters(
      fajrAngle: 19.5,
      ishaAngle: 17.5,
    );
    
    final prayerTimes = PrayerTimes(coordinates, date, params);
    
    _currentPrayerTimes = {
      'fajr': prayerTimes.fajr,
      'sunrise': prayerTimes.sunrise,
      'dhuhr': prayerTimes.dhuhr,
      'asr': prayerTimes.asr,
      'maghrib': prayerTimes.maghrib,
      'isha': prayerTimes.isha,
    };

    _prayerTimesController?.add(_currentPrayerTimes!);
    
    _startUpdateTimer();

    return _currentPrayerTimes;
  }

  Future<LocationSettings?> _getCurrentLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedCityId = prefs.getString(AppConstants.selectedCityKey) ?? AppConstants.defaultCity;
    
    final city = AppConstants.cities.firstWhere(
      (city) => city['id'] == selectedCityId,
      orElse: () => AppConstants.cities.first,
    );

    return LocationSettings(
      latitude: city['latitude'],
      longitude: city['longitude'],
      city: city['name'],
      country: city['country'],
      timezone: city['timezone'],
    );
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(AppConstants.countdownUpdateInterval, (timer) {
      _updatePrayerTimes();
    });
  }

  // تم حذف دالة _startPreloadTimer و _checkAndPreloadNextPrayer لأنها كانت تخص الأذان

  Future<void> _updatePrayerTimes() async {
    await getCurrentPrayerTimes();
  }

  String? getNextPrayer() {
    if (_currentPrayerTimes == null) return null;

    final now = DateTime.now();
    final prayers = _currentPrayerTimes!;
    
    for (final entry in prayers.entries) {
      if (entry.value.isAfter(now)) {
        return entry.key;
      }
    }
    return 'fajr';
  }

  DateTime? getNextPrayerTime() {
    if (_currentPrayerTimes == null) return null;

    final nextPrayer = getNextPrayer();
    if (nextPrayer == null) return null;

    final prayerTime = _currentPrayerTimes![nextPrayer];
    if (prayerTime == null) return null;
    
    if (prayerTime.isBefore(DateTime.now())) {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      
      final todayFajr = _currentPrayerTimes!['fajr'];
      if (todayFajr != null) {
        return DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          todayFajr.hour,
          todayFajr.minute,
        );
      }
    }
    
    return prayerTime;
  }

  Duration? getTimeUntilNextPrayer() {
    final nextPrayerTime = getNextPrayerTime();
    if (nextPrayerTime == null) return null;

    final now = DateTime.now();
    return nextPrayerTime.difference(now);
  }

  Map<String, DateTime?> getAllPrayerTimes() {
    if (_currentPrayerTimes == null) return {};
    return Map<String, DateTime?>.from(_currentPrayerTimes!);
  }

  DateTime? getImsakTime() {
    final fajrTime = _currentPrayerTimes?['fajr'];
    if (fajrTime == null) return null;
    return fajrTime.subtract(const Duration(minutes: 10));
  }

  Future<String> getCurrentCityName() async {
    final location = await _getCurrentLocation();
    return location?.city ?? 'القاهرة';
  }

  Future<String> getCurrentCountryName() async {
    final location = await _getCurrentLocation();
    return location?.country ?? 'مصر';
  }

  bool isRamadan() {
    final now = DateTime.now();
    return _isIslamicRamadan(now);
  }

  bool _isIslamicRamadan(DateTime date) {
    final year = date.year;
    final month = date.month;
    final day = date.day;

    if (year == 2026) {
      return (month == 2 && day >= 18) || (month == 3 && day <= 19);
    }
    return false;
  }

  Duration? getTimeUntilRamadan() {
    final now = DateTime.now();
    
    if (_lastRamadanCalculation != null && 
        _cachedTimeUntilRamadan != null &&
        now.difference(_lastRamadanCalculation!).inSeconds < 60) {
      return _cachedTimeUntilRamadan;
    }
    
    final ramadan2026 = DateTime(2026, 2, 18);
    
    Duration result;
    if (now.isAfter(ramadan2026)) {
      final ramadan2027 = DateTime(2027, 2, 7);
      result = ramadan2027.difference(now);
    } else {
      result = ramadan2026.difference(now);
    }
    
    _cachedTimeUntilRamadan = result;
    _lastRamadanCalculation = now;
    
    return result;
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
  final String timezone;

  LocationSettings({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    required this.timezone,
  });
}

extension PrayerTimeFormatting on DateTime? {
  String getFormattedTime() {
    if (this == null) return '--:--';
    return DateFormat('h:mm a').format(this!);
  }

  String getFormattedTime24() {
    if (this == null) return '--:--';
    return DateFormat('HH:mm').format(this!);
  }
}