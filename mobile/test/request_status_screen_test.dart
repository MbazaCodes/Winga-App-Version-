import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winga_app_v3/features/requests/presentation/request_status_screen.dart';

void main() {
  testWidgets('RequestStatusScreen shows status summary', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RequestStatusScreen()));

    expect(find.text('Request status'), findsOneWidget);
    expect(find.text('Pending assignment'), findsOneWidget);
  });
}
