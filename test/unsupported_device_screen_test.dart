import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forma/core/strings.dart';
import 'package:forma/design_system/theme.dart';
import 'package:forma/features/unsupported_device/unsupported_device_screen.dart';

void main() {
  testWidgets('renders the explainer with no scan entry point', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFormaTheme(Brightness.light),
        darkTheme: buildFormaTheme(Brightness.dark),
        home: const UnsupportedDeviceScreen(),
      ),
    );

    expect(find.text(Strings.unsupportedTitle), findsOneWidget);
    expect(find.text(Strings.unsupportedBody), findsOneWidget);
    expect(find.text(Strings.unsupportedDevicesTitle), findsOneWidget);
    expect(find.text(Strings.unsupportedDevicesBody), findsOneWidget);
    expect(find.text(Strings.startScan), findsNothing);
    expect(find.text(Strings.scanCta), findsNothing);
  });

  testWidgets('renders identically in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFormaTheme(Brightness.dark),
        home: const UnsupportedDeviceScreen(),
      ),
    );

    expect(find.text(Strings.unsupportedTitle), findsOneWidget);
    expect(find.text(Strings.unsupportedDevicesTitle), findsOneWidget);
  });
}
