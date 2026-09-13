import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma/design_system/components/primary_button.dart';
import 'package:forma/design_system/theme.dart';

Widget _wrap(Widget child, {bool dark = false}) => MaterialApp(
      theme: buildFormaTheme(dark ? Brightness.dark : Brightness.light),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('tap fires onPressed; disabled does not', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(PrimaryButton(label: 'Scan', onPressed: () => taps++)),
    );
    await tester.tap(find.text('Scan'));
    await tester.pump();
    expect(taps, 1);

    await tester.pumpWidget(_wrap(const PrimaryButton(label: 'Scan')));
    await tester.tap(find.text('Scan'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('loading state swaps label for a spinner', (tester) async {
    await tester.pumpWidget(
      _wrap(const PrimaryButton(label: 'Scan', isLoading: true)),
    );
    await tester.pump();
    expect(find.text('Scan'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('golden light', (tester) async {
    await tester.pumpWidget(
      _wrap(PrimaryButton(label: 'Start Scan', onPressed: () {})),
    );
    await expectLater(
      find.byType(PrimaryButton),
      matchesGoldenFile('goldens/primary_button_light.png'),
    );
  });

  testWidgets('golden dark', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PrimaryButton(label: 'Start Scan', onPressed: () {}),
        dark: true,
      ),
    );
    await expectLater(
      find.byType(PrimaryButton),
      matchesGoldenFile('goldens/primary_button_dark.png'),
    );
  });
}
