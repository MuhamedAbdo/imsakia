import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
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

  // Cache for Ramadan countdown
  Duration? _cachedTimeUntilRamadan;
  DateTime? _lastRamadanCalculation;

  Stream<Map<String, DateTime>> get prayerTimesStream =>
      (_prayerTimesController ??=
              StreamController<Map<String, DateTime>>.broadcast())
          .stream;

  Future<Map<String, DateTime>?> getCurrentPrayerTimes() async {
    final location = await _getCurrentLocation();
    if (location == null) return null;

    // Read user settings from SharedPreferences
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

    // Get the correct calculation method based on user setting
    CalculationParameters params;
    switch (calculationMethod) {
      case 'egyptian':
        params = CalculationMethod.egyptian.getParameters();
        break;
      case 'karachi':
        params = CalculationMethod.karachi.getParameters();
        break;
      case 'umm_al_qura':
        params = CalculationMethod.umm_al_qura.getParameters();
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

    // Set madhab for Asr calculation
    params.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

    final prayerTimes = PrayerTimes(coordinates, date, params);

    // Apply DST offset if enabled
    final dstOffset = dstEnabled ? const Duration(hours: 1) : Duration.zero;

    _currentPrayerTimes = {
      'fajr': prayerTimes.fajr.add(dstOffset),
      'sunrise': prayerTimes.sunrise.add(dstOffset),
      'dhuhr': prayerTimes.dhuhr.add(dstOffset),
      'asr': prayerTimes.asr.add(dstOffset),
      'maghrib': prayerTimes.maghrib.add(dstOffset),
      'isha': prayerTimes.isha.add(dstOffset),
    };

    _prayerTimesController?.add(_currentPrayerTimes!);

    _startUpdateTimer();

    return _currentPrayerTimes;
  }

  Future<LocationSettings?> _getCurrentLocation() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
    final selectedCityId =
        _sharedPreferences!.getString(AppConstants.selectedCityKey) ??
        AppConstants.defaultCity;

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
    _updateTimer = Timer.periodic(AppConstants.countdownUpdateInterval, (
      timer,
    ) {
      _updatePrayerTimes();
    });
  }

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
    final prefs = _sharedPreferences;
    final hijriAdjustment = prefs?.getInt('hijri_adjustment') ?? 0;
    return HijriDateService.isRamadan(date, hijriAdjustment);
  }

  Future<Duration?> getTimeUntilRamadan() async {
    final now = DateTime.now();

    if (_lastRamadanCalculation != null &&
        _cachedTimeUntilRamadan != null &&
        now.difference(_lastRamadanCalculation!).inSeconds < 60) {
      return _cachedTimeUntilRamadan;
    }

    _sharedPreferences ??= await SharedPreferences.getInstance();
    final hijriAdjustment = _sharedPreferences!.getInt('hijri_adjustment') ?? 0;

    final nextRamadanStart = HijriDateService.getNextRamadanStart(
      now,
      hijriAdjustment,
    );
    final result = nextRamadanStart.difference(now);

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
