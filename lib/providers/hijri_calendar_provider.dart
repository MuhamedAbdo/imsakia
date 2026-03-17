import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';
import '../core/models/hijri_date_model.dart';
import '../core/models/islamic_event_model.dart';
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

  List<Map<String, dynamic>> getUpcomingEvents(int offset) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final currentHijri = HijriCalendar.fromDate(todayMidnight.add(Duration(days: offset)));
    
    List<Map<String, dynamic>> upcoming = [];

    // Check events in current Hijri year and next year
    for (int yearOffset = 0; yearOffset <= 1; yearOffset++) {
      int hYear = currentHijri.hYear + yearOffset;
      for (var event in IslamicEvent.allEvents) {
        final eventDate = event.toGregorian(hYear, offset);
        if (eventDate.isAfter(todayMidnight) || eventDate.isAtSameMomentAs(todayMidnight)) {
          final diff = eventDate.difference(todayMidnight).inDays;
          upcoming.add({
            'event': event,
            'daysLeft': diff,
            'date': eventDate,
          });
        }
      }
    }

    // Sort by days left and take the top 4 unique events (by name and date)
    upcoming.sort((a, b) => (a['daysLeft'] as int).compareTo(b['daysLeft'] as int));
    
    // Simple deduplication if any (especially for multi-day events if they are listed separately)
    final seen = <String>{};
    return upcoming.where((e) {
      final key = "${(e['event'] as IslamicEvent).name}-${e['daysLeft']}";
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).take(4).toList();
  }

  IslamicEvent? getEventForDate(DateTime date, int offset) {
    final hDate = HijriCalendar.fromDate(date.add(Duration(days: offset)));
    try {
      return IslamicEvent.allEvents.firstWhere(
        (e) => e.month == hDate.hMonth && e.day == hDate.hDay,
      );
    } catch (_) {
      return null;
    }
  }
}
