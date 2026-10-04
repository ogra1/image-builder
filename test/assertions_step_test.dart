import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';
import 'package:ubuntu_image_gui/views/step3_assertions_step.dart';

void main() {
  testWidgets(
    'Add button enables once the name is filled; sequence is optional',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Step3AssertionsStep(config: BuildConfig())),
        ),
      );
      await tester.pumpAndSettle();

      final addButton = find
          .ancestor(of: find.text('Add'), matching: find.byType(FilledButton))
          .first;

      // Disabled while the name field is empty.
      expect(addButton, findsOneWidget);
      expect(tester.widget<FilledButton>(addButton).onPressed, isNull);

      // The name alone enables the button — a validation set is a valid
      // `--sequence` value on its own; the sequence number is optional.
      await tester.enterText(find.byType(TextField).first, 'canonical');
      await tester.pump();
      expect(tester.widget<FilledButton>(addButton).onPressed, isNotNull);

      // Add name-only: lands in the list without a sequence suffix.
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.text('canonical'), findsOneWidget);
      expect(find.text('canonical:42'), findsNothing);
    },
  );

  testWidgets('adding with a sequence number appends the name:sequence form', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Step3AssertionsStep(config: BuildConfig())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'canonical');
    await tester.enterText(find.byType(TextField).at(1), '42');
    await tester.pump();
    await tester.tap(
      find
          .ancestor(of: find.text('Add'), matching: find.byType(FilledButton))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('canonical:42'), findsOneWidget);
  });
}
