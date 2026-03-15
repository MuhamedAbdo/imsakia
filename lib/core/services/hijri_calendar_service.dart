import 'package:hijri/hijri_calendar.dart';
import '../models/hijri_date_model.dart';
import 'aladhan_api_service.dart';

class HijriCalendarService {
  final AladhanApiService _api;

  HijriCalendarService(this._api);

  /// Get today's Hijri date — tries online first, falls back to offline.
  Future<HijriDateModel> getHijriDate({
    DateTime? date,
    int offset = 0,
    String? isoCountryCode,
  }) async {
    final target = date ?? DateTime.now();

    // Try online sync first
    try {
      final online = await _api.fetchHijriDate(
        gregorian: target,
        country: isoCountryCode,
      );
      return online.withOffset(offset);
    } catch (_) {
      // Fall back to offline calculation
    }

    return _offlineHijriDate(target, offset: offset);
  }

  HijriDateModel _offlineHijriDate(DateTime date, {int offset = 0}) {
    final hd = HijriCalendar.fromDate(date);
    return HijriDateModel.create(hd.hYear, hd.hMonth, hd.hDay,
            isOnlineSynced: false)
        .withOffset(offset);
  }
}
