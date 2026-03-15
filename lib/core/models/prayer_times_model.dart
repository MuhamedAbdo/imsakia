/// Prayer names and times model
class PrayerTimesModel {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime date;

  const PrayerTimesModel({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
  });

  List<PrayerEntry> toList() => [
        PrayerEntry(name: Prayer.imsak, time: fajr.subtract(const Duration(minutes: 15))),
        PrayerEntry(name: Prayer.fajr, time: fajr),
        PrayerEntry(name: Prayer.sunrise, time: sunrise),
        PrayerEntry(name: Prayer.dhuhr, time: dhuhr),
        PrayerEntry(name: Prayer.asr, time: asr),
        PrayerEntry(name: Prayer.maghrib, time: maghrib),
        PrayerEntry(name: Prayer.isha, time: isha),
      ];

  PrayerEntry? get currentPrayer {
    final now = DateTime.now();
    PrayerEntry? current;
    for (final entry in toList()) {
      if (entry.time.isBefore(now)) {
        current = entry;
      }
    }
    // If it's before Fajr today, the current prayer is yesterday's Isha.
    // However, since we only have today's times, we'll return Isha of today minus 1 day.
    return current ?? PrayerEntry(
      name: Prayer.isha,
      time: isha.subtract(const Duration(days: 1)),
    );
  }

  PrayerEntry? get nextPrayer {
    final now = DateTime.now();
    for (final entry in toList()) {
      // Imsak does not have an Athan — skip so countdown jumps straight to Fajr.
      // Sunrise IS a valid countdown target (no Athan; background service handles
      // it as a silent notification).
      if (entry.name == Prayer.imsak) continue;
      if (entry.time.isAfter(now)) return entry;
    }
    // If all today's prayers have passed, the next prayer is tomorrow's Fajr
    return PrayerEntry(
      name: Prayer.fajr,
      time: fajr.add(const Duration(days: 1)),
    );
  }
}

enum Prayer { imsak, fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerExtension on Prayer {
  String get nameEn {
    switch (this) {
      case Prayer.imsak:
        return 'Imsak';
      case Prayer.fajr:
        return 'Fajr';
      case Prayer.sunrise:
        return 'Sunrise';
      case Prayer.dhuhr:
        return 'Dhuhr';
      case Prayer.asr:
        return 'Asr';
      case Prayer.maghrib:
        return 'Maghrib';
      case Prayer.isha:
        return 'Isha';
    }
  }

  String get nameAr {
    switch (this) {
      case Prayer.imsak:
        return 'الإمساك';
      case Prayer.fajr:
        return 'الفجر';
      case Prayer.sunrise:
        return 'الشروق';
      case Prayer.dhuhr:
        return 'الظهر';
      case Prayer.asr:
        return 'العصر';
      case Prayer.maghrib:
        return 'المغرب';
      case Prayer.isha:
        return 'العشاء';
    }
  }

  String get iconAsset {
    switch (this) {
      case Prayer.imsak:
        return 'assets/images/imsak.png';
      case Prayer.fajr:
        return 'assets/images/fajr.png';
      case Prayer.sunrise:
        return 'assets/images/sunrise.png';
      case Prayer.dhuhr:
        return 'assets/images/dhuhr.png';
      case Prayer.asr:
        return 'assets/images/asr.png';
      case Prayer.maghrib:
        return 'assets/images/maghrib.png';
      case Prayer.isha:
        return 'assets/images/isha.png';
    }
  }
}

class PrayerEntry {
  final Prayer name;
  final DateTime time;

  const PrayerEntry({required this.name, required this.time});
}
