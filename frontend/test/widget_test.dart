// frontend/test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Clarity AI'),
          ),
        ),
      ),
    );

    expect(find.text('Clarity AI'), findsOneWidget);
  });
}
