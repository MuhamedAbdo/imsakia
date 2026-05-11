import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('🔍 Testing Fiqh asset loading...');

    final String response = await rootBundle.loadString(
      'assets/data/fiqh/index.json',
    );
    debugPrint('✅ Asset loaded successfully!');
    debugPrint('📄 Response length: ${response.length}');

    final List<dynamic> data = json.decode(response);
    debugPrint('📊 Parsed ${data.length} books');

    if (data.isNotEmpty) {
      final firstBook = data[0];
      debugPrint('📚 First book: ${firstBook['title']} (ID: ${firstBook['id']})');
    }

    debugPrint('🎯 Asset loading test completed successfully!');
  } catch (e, stackTrace) {
    debugPrint('❌ Error loading asset: $e');
    debugPrint('📍 Stack trace: $stackTrace');
  }
}
