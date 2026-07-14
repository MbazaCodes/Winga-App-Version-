import 'package:flutter_test/flutter_test.dart';
import 'package:winga_app_v3/main.dart';

void main() {
  testWidgets('app boots with onboarding screen', (tester) async {
    await tester.pumpWidget(const WingaApp());
    expect(find.text('Welcome to Winga'), findsOneWidget);
  });
}
