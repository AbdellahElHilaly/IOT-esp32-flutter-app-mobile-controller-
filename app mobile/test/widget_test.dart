import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_app/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaApp());
    expect(find.byType(LuminaApp), findsOneWidget);
  });
}
