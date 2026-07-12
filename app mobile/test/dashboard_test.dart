import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_app/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen UI layout and LED interaction', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );

    expect(find.text('SMART HOME'), findsOneWidget);
    expect(find.text('2-STORY RESIDENCE'), findsOneWidget);

    expect(find.text('Room 1'), findsOneWidget);
    expect(find.text('Room 2'), findsOneWidget);
    expect(find.text('Room 3'), findsOneWidget);
    expect(find.text('Room 4'), findsOneWidget);

    expect(find.text('LED 1'), findsOneWidget);
    expect(find.text('LED 8'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);

    await tester.tap(find.text('LED 1'), warnIfMissed: false);
    await tester.pump();
  });
}
