import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_app/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen UI layout and LED interaction', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('SMART HOME'), findsOneWidget);
    expect(find.text('RECTANGLE RESIDENCE'), findsOneWidget);

    expect(find.text('OPEN-PLAN LED LAYOUT'), findsOneWidget);

    final ledLabels = tester
        .widgetList<Text>(find.byType(Text))
        .where(
          (widget) =>
              widget.data != null &&
              RegExp(r'^LED [1-8]$').hasMatch(widget.data!),
        )
        .map((widget) => widget.data!)
        .toList();

    expect(ledLabels, [
      'LED 1',
      'LED 2',
      'LED 3',
      'LED 4',
      'LED 5',
      'LED 6',
      'LED 7',
      'LED 8',
    ]);

    expect(find.text('LED 1'), findsOneWidget);
    expect(find.text('LED 8'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);

    await tester.tap(find.text('LED 1'), warnIfMissed: false);
    await tester.pump();
  });
}
