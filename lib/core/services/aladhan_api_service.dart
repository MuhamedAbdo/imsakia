import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hijri_date_model.dart';

class AladhanApiService {
  static const _baseUrl = 'https://api.aladhan.com/v1';

  /// Fetch Hijri date for a given Gregorian date.
  Future<HijriDateModel> fetchHijriDate({
    required DateTime gregorian,
    String? country,
  }) async {
    final dateStr =
        '${gregorian.day.toString().padLeft(2, '0')}-${gregorian.month.toString().padLeft(2, '0')}-${gregorian.year}';

    final uri = Uri.parse('$_baseUrl/gToH/$dateStr');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Aladhan API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final hijri = data['data']['hijri'] as Map<String, dynamic>;
    final year = int.parse(hijri['year'] as String);
    final month = int.parse(hijri['month']['number'].toString());
    final day = int.parse(hijri['day'] as String);

    return HijriDateModel.create(year, month, day, isOnlineSynced: true);
  }
}
