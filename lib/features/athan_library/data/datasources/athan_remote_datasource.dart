import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/athan_model.dart';

/// العقد (Abstract contract) لمصدر بيانات الأذان
abstract class AthanRemoteDataSource {
  Future<List<AthanModel>> fetchAthans();
}

/// التطبيق الفعلي باستخدام حزمة http
class AthanRemoteDataSourceImpl implements AthanRemoteDataSource {
  static const String _apiUrl =
      'https://gist.githubusercontent.com/MuhamedAbdo/11e230a238e9648bcc22cb37f941555a/raw/bf796cd5641d4e862c69605c2eaa880fb4cb9b12/athan_api.json';

  final http.Client _client;

  AthanRemoteDataSourceImpl({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<List<AthanModel>> fetchAthans() async {
    final response = await _client
        .get(
          Uri.parse(_apiUrl),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return jsonList
          .map((e) => AthanModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
          'فشل تحميل قائمة الأذانات (كود الخطأ: ${response.statusCode})');
    }
  }
}
