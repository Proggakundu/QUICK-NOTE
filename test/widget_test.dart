import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes_app/main.dart';

void main() {

  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    
    // Wait for initialization
    await tester.pumpAndSettle();
    
    // Verify that the app loads (should show login or notes screen)
    // Looking for common widgets in your app
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
