import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/app_constants.dart';
import 'athan_player_service.dart';

class PrayerTimesService {
  static PrayerTimesService? _instance;
  static PrayerTimesService get instance => _instance ??= PrayerTimesService._();

  PrayerTimesService._();

  Map<String, DateTime>? _currentPrayerTimes;
  StreamController<Map<String, DateTime>>? _prayerTimesController;
  Timer? _updateTimer;
  Timer? _preloadTimer;
  String? _lastPreloadedPrayer;
  
  // Cache for Ramadan countdown to avoid repeated calculations
  Duration? _cachedTimeUntilRamadan;
  DateTime? _lastRamadanCalculation;

  Stream<Map<String, DateTime>> get prayerTimesStream => 
      (_prayerTimesController ??= StreamController<Map<String, DateTime>>.broadcast()).stream;

  Future<Map<String, DateTime>?> getCurrentPrayerTimes() async {
    final location = await _getCurrentLocation();
    if (location == null) return null;

    final now = DateTime.now();
    final date = DateComponents(now.year, now.month, now.day);
    
    // Create coordinates for the selected city
    final coordinates = Coordinates(location.latitude, location.longitude);
    
    // Create basic calculation parameters (Egyptian method)
    final params = CalculationParameters(
      fajrAngle: 19.5,
      ishaAngle: 17.5,
    );
    
    // Calculate prayer times
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
    
    // Start timer for updates
    _startUpdateTimer();
    
    // Start preloading timer
    _startPreloadTimer();

    return _currentPrayerTimes;
  }

  Future<LocationSettings?> _getCurrentLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedCityId = prefs.getString(AppConstants.selectedCityKey) ?? AppConstants.defaultCity;
    
    // Find the selected city
    final city = AppConstants.cities.firstWhere(
      (city) => city['id'] == selectedCityId,
      orElse: () => AppConstants.cities.first, // Default to Cairo
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

  void _startPreloadTimer() {
    _preloadTimer?.cancel();
    _preloadTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndPreloadNextPrayer();
    });
  }

  void _checkAndPreloadNextPrayer() {
    if (_currentPrayerTimes == null) return;

    final now = DateTime.now();
    final nextPrayer = getNextPrayer();
    if (nextPrayer == null || nextPrayer == _lastPreloadedPrayer) return;

    final nextPrayerTime = _currentPrayerTimes![nextPrayer];
    if (nextPrayerTime == null) return;

    // Check if prayer is within 2 minutes
    final timeUntilPrayer = nextPrayerTime.difference(now);
    if (timeUntilPrayer.inMinutes <= 2 && timeUntilPrayer.inMinutes > 0) {
      // Preload the athan
      AthanPlayerService.instance.preloadAthan(nextPrayer);
      _lastPreloadedPrayer = nextPrayer;
      
      print('🚀 Preloaded athan for $nextPrayer (prayer in ${timeUntilPrayer.inMinutes}:${(timeUntilPrayer.inSeconds % 60).toString().padLeft(2, '0')})');
    }
  }

  Future<void> _updatePrayerTimes() async {
    await getCurrentPrayerTimes();
  }

  String? getNextPrayer() {
    if (_currentPrayerTimes == null) return null;

    final now = DateTime.now();
    final prayers = _currentPrayerTimes!;
    
    // Find the next prayer
    for (final entry in prayers.entries) {
      if (entry.value.isAfter(now)) {
        return entry.key;
      }
    }
    
    // If all prayers have passed, return fajr for tomorrow
    return 'fajr';
  }

  DateTime? getNextPrayerTime() {
    if (_currentPrayerTimes == null) return null;

    final nextPrayer = getNextPrayer();
    if (nextPrayer == null) return null;

    final prayerTime = _currentPrayerTimes![nextPrayer];
    if (prayerTime == null) return null;
    
    // If the prayer time has passed, calculate tomorrow's fajr
    if (prayerTime.isBefore(DateTime.now())) {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      
      // Use a simple approximation for tomorrow's fajr (same time as today)
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
    
    // Imsak is 10 minutes before Fajr
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
    // Check if current month is Ramadan (Islamic month 9)
    // This is a simplified check - in production, you'd want to use a proper Hijri calendar
    return _isIslamicRamadan(now);
  }

  bool _isIslamicRamadan(DateTime date) {
    // Simplified Ramadan detection
    // In 2026, Ramadan is expected to start around February 18
    // This is a rough approximation - for accurate calculation, use a Hijri calendar library
    final year = date.year;
    final month = date.month;
    final day = date.day;

    if (year == 2026) {
      return (month == 2 && day >= 18) || (month == 3 && day <= 19);
    }
    
    // For other years, return false for now
    // TODO: Implement proper Hijri calendar calculation
    return false;
  }

  Duration? getTimeUntilRamadan() {
    final now = DateTime.now();
    
    // Use cache if calculation was done recently (within last minute)
    if (_lastRamadanCalculation != null && 
        _cachedTimeUntilRamadan != null &&
        now.difference(_lastRamadanCalculation!).inSeconds < 60) {
      return _cachedTimeUntilRamadan;
    }
    
    // For 2026, Ramadan starts around February 18
    final ramadan2026 = DateTime(2026, 2, 18);
    
    Duration result;
    if (now.isAfter(ramadan2026)) {
      // If we've passed Ramadan 2026, calculate until next year
      final ramadan2027 = DateTime(2027, 2, 7); // Approximate
      result = ramadan2027.difference(now);
    } else {
      result = ramadan2026.difference(now);
    }
    
    // Cache the result
    _cachedTimeUntilRamadan = result;
    _lastRamadanCalculation = now;
    
    return result;
  }

  void dispose() {
    _updateTimer?.cancel();
    _preloadTimer?.cancel();
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

// Extension for formatting prayer times
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
