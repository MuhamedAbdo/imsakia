import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imsakia/main.dart';
import 'package:imsakia/providers/settings_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MyApp(settingsProvider: SettingsProvider(), prefs: prefs),
    );

    // Verify that app loads
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
