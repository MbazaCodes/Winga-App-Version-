import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winga_app_v3/main.dart';

void main() {
  testWidgets('app boots with onboarding screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WingaApp()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Winga'), findsOneWidget);
  });
}
