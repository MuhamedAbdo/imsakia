import 'package:adhan/adhan.dart' as adhan;
import '../models/prayer_times_model.dart';
import '../models/location_model.dart';
import '../models/settings_model.dart';

class PrayerTimesService {
  PrayerTimesModel calculate(
    LocationModel location,
    CalculationMethod method, {
    DateTime? date,
  }) {
    final target = date ?? DateTime.now();
    final coordinates = adhan.Coordinates(location.latitude, location.longitude);
    final params = _getParameters(method);
    final dateComponents =
        adhan.DateComponents(target.year, target.month, target.day);
    final prayerTimes =
        adhan.PrayerTimes(coordinates, dateComponents, params);

    return PrayerTimesModel(
      fajr: prayerTimes.fajr,
      sunrise: prayerTimes.sunrise,
      dhuhr: prayerTimes.dhuhr,
      asr: prayerTimes.asr,
      maghrib: prayerTimes.maghrib,
      isha: prayerTimes.isha,
      date: target,
    );
  }

  adhan.CalculationParameters _getParameters(CalculationMethod method) {
    switch (method) {
      case CalculationMethod.egyptian:
        return adhan.CalculationMethod.egyptian.getParameters();
      case CalculationMethod.ummAlQura:
        return adhan.CalculationMethod.umm_al_qura.getParameters();
      case CalculationMethod.muslimWorldLeague:
        return adhan.CalculationMethod.muslim_world_league.getParameters();
      case CalculationMethod.northAmerica:
        return adhan.CalculationMethod.north_america.getParameters();
      case CalculationMethod.karachi:
        return adhan.CalculationMethod.karachi.getParameters();
      case CalculationMethod.dubai:
        return adhan.CalculationMethod.dubai.getParameters();
      case CalculationMethod.kuwait:
        return adhan.CalculationMethod.kuwait.getParameters();
      case CalculationMethod.qatar:
        return adhan.CalculationMethod.qatar.getParameters();
      case CalculationMethod.singapore:
        return adhan.CalculationMethod.singapore.getParameters();
      case CalculationMethod.tehran:
        return adhan.CalculationMethod.tehran.getParameters();
      case CalculationMethod.turkey:
        return adhan.CalculationMethod.turkey.getParameters();
    }
  }
}
