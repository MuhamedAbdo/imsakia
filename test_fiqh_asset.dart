import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🔍 Testing Fiqh asset loading...');

    final String response = await rootBundle.loadString(
      'assets/data/fiqh/index.json',
    );
    print('✅ Asset loaded successfully!');
    print('📄 Response length: ${response.length}');

    final List<dynamic> data = json.decode(response);
    print('📊 Parsed ${data.length} books');

    if (data.isNotEmpty) {
      final firstBook = data[0];
      print('📚 First book: ${firstBook['title']} (ID: ${firstBook['id']})');
    }

    print('🎯 Asset loading test completed successfully!');
  } catch (e, stackTrace) {
    print('❌ Error loading asset: $e');
    print('📍 Stack trace: $stackTrace');
  }
}
