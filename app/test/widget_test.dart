import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wakemate/features/splash/splash_screen.dart';

void main() {
  testWidgets('Splash shows the WakeMate wordmark', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SplashScreen()),
      ),
    );

    // First frame — logo + wordmark are present before navigation fires.
    expect(find.text('WakeMate'), findsOneWidget);
    expect(find.text('Never miss your stop'), findsOneWidget);
  });
}
