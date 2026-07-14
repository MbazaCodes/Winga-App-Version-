import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winga_app_v3/features/history/presentation/ride_history_screen.dart';

void main() {
  testWidgets('RideHistoryScreen shows recent rides', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RideHistoryScreen()));

    expect(find.text('Ride history'), findsOneWidget);
    expect(find.text('Airport transfer'), findsOneWidget);
  });
}
