import 'package:flutter/foundation.dart';
import '../core/models/hijri_date_model.dart';
import '../core/services/hijri_calendar_service.dart';

class HijriCalendarProvider extends ChangeNotifier {
  final HijriCalendarService _service;

  HijriDateModel? _hijriDate;
  bool _isLoading = false;
  bool _isOnlineSynced = false;

  HijriCalendarProvider(this._service);

  HijriDateModel? get hijriDate => _hijriDate;
  bool get isLoading => _isLoading;
  bool get isOnlineSynced => _isOnlineSynced;

  Future<void> fetch({
    int offset = 0,
    String? countryCode,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _hijriDate = await _service.getHijriDate(
        offset: offset,
        isoCountryCode: countryCode,
      );
      _isOnlineSynced = _hijriDate?.isOnlineSynced ?? false;
    } catch (_) {
      // Use offline calculation as fallback
      _hijriDate = await _service.getHijriDate(offset: offset);
    }

    _isLoading = false;
    notifyListeners();
  }
}
