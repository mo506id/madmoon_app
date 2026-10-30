import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic widget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Madmoon App'),
          ),
        ),
      ),
    );

    expect(find.text('Madmoon App'), findsOneWidget);
  });
}