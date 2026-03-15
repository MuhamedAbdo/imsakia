import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imsakia/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that app loads
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
