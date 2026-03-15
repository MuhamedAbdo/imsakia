import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/models/prayer_times_model.dart';
import '../core/models/location_model.dart';
import '../core/models/settings_model.dart';
import '../core/services/prayer_times_service.dart';
import 'package:home_widget/home_widget.dart';

enum PrayerTimesStatus { idle, loading, loaded, error }

class PrayerTimesProvider extends ChangeNotifier {
  final PrayerTimesService _service;

  PrayerTimesModel? _prayerTimes;
  PrayerTimesStatus _status = PrayerTimesStatus.idle;
  String _errorMessage = '';
  Duration _countdown = Duration.zero;
  Timer? _countdownTimer;

  PrayerTimesProvider(this._service);

  PrayerTimesModel? get prayerTimes => _prayerTimes;
  PrayerTimesStatus get status => _status;
  String get errorMessage => _errorMessage;
  Duration get countdown => _countdown;
  PrayerEntry? get nextPrayer => _prayerTimes?.nextPrayer;

  Future<void> calculate(
    LocationModel location,
    CalculationMethod method,
  ) async {
    _status = PrayerTimesStatus.loading;
    notifyListeners();
    try {
      _prayerTimes = _service.calculate(location, method);
      
      final next = _prayerTimes?.nextPrayer;
      final current = _prayerTimes?.currentPrayer;
      final diff = next?.time.difference(DateTime.now()) ?? Duration.zero;
      final countdown = diff.isNegative ? Duration.zero : diff;
      
      await _updateHomeWidget(current, next, countdown);
      
      _status = PrayerTimesStatus.loaded;
      _startCountdown();
    } catch (e) {
      _errorMessage = e.toString();
      _status = PrayerTimesStatus.error;
    }
    notifyListeners();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final next = _prayerTimes?.nextPrayer;
    if (next == null) {
      _countdown = Duration.zero;
      _updateHomeWidget(null, null, Duration.zero);
    } else {
      final diff = next.time.difference(DateTime.now());
      _countdown = diff.isNegative ? Duration.zero : diff;
      
      // Determine the previous (missed) prayer
      final current = _prayerTimes?.currentPrayer;
      
      _updateHomeWidget(current, next, _countdown);
    }
    notifyListeners();
  }

  Future<void> _updateHomeWidget(
    PrayerEntry? currentPrayer,
    PrayerEntry? nextPrayer,
    Duration countdown,
  ) async {
    // Format countdown — separate hour/minute keys for the split widget columns
    final hours = countdown.inHours.toString().padLeft(2, '0');
    final minutes = (countdown.inMinutes % 60).toString().padLeft(2, '0');

    String formatTime(DateTime time) {
      final hr = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final mn = time.minute.toString().padLeft(2, '0');
      return "$hr:$mn";
    }

    final nextName = nextPrayer != null ? "${nextPrayer.name.nameAr} ${formatTime(nextPrayer.time)}" : "";
    final currentName = currentPrayer != null ? "${currentPrayer.name.nameAr} ${formatTime(currentPrayer.time)}" : "";
    
    final missedStr = currentName;

    await HomeWidget.saveWidgetData<String>('widget_hours', hours);
    await HomeWidget.saveWidgetData<String>('widget_minutes', minutes);
    await HomeWidget.saveWidgetData<String>('next_prayer', nextName);
    await HomeWidget.saveWidgetData<String>('missed_prayer', missedStr);

    // Brief delay to ensure SharedPreferences flushes to disk
    await Future.delayed(const Duration(milliseconds: 50));

    await HomeWidget.updateWidget(
      name: 'PrayerWidgetProvider', // This is exactly what we named the kotlin class
      androidName: 'PrayerWidgetProvider',
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
