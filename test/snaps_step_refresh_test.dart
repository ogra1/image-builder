import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';
import 'package:ubuntu_image_gui/models/model_assertion.dart';
import 'package:ubuntu_image_gui/views/step2_snaps_step.dart';
import 'package:ubuntu_image_gui/widgets/shared.dart';

/// Regression test: after adding a snap via the add dialog, the snaps
/// list (and its counter) must update immediately — without switching
/// steps.
void main() {
  BuildConfig dangerousConfig() => BuildConfig()
    ..model = ModelAssertion('/tmp/model.assert', {
      'model': 'test-model',
      'grade': 'dangerous',
    }, parsed: true);

  Finder sectionTitle(String text) =>
      find.descendant(of: find.byType(SectionTitle), matching: find.text(text));

  Widget harness(BuildConfig config) => MaterialApp(
    home: Scaffold(body: Step2SnapsStep(config: config)),
  );

  testWidgets('store snap appears in list immediately after add dialog', (
    tester,
  ) async {
    final config = dangerousConfig();
    await tester.pumpWidget(harness(config));
    await tester.pumpAndSettle();

    // Initial state: no snaps.
    expect(sectionTitle('Snaps'), findsOneWidget);
    expect(find.text('No additional snaps selected.'), findsOneWidget);

    // Open the "Add from store" dialog and add a snap.
    await tester.tap(find.text('Add from store'));
    await tester.pumpAndSettle();
    expect(find.text('Add snap'), findsOneWidget); // dialog is open

    await tester.enterText(find.byType(TextField).first, 'firefox');
    await tester.pump();
    expect(find.text('Add').evaluate().length, greaterThan(0));
    await tester.tap(find.text('Add').last); // dialog action, not section
    await tester.pumpAndSettle(); // dialog closes, outer setState runs

    // The list must reflect the addition without any step switch.
    expect(find.text('Add snap'), findsNothing); // dialog closed
    expect(config.snaps.length, 1);
    expect(sectionTitle('Snaps'), findsOneWidget);
    expect(find.text('firefox'), findsOneWidget);
    expect(find.text('No additional snaps selected.'), findsNothing);
  });

  testWidgets('local .snap appears in list immediately after add dialog', (
    tester,
  ) async {
    final config = dangerousConfig();
    await tester.pumpWidget(harness(config));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add local .snap'));
    await tester.pumpAndSettle();
    expect(find.text('Add snap'), findsOneWidget);

    // The first field of the local tab is the .snap file path.
    await tester.enterText(find.byType(TextField).first, '/tmp/foo.snap');
    await tester.pump();
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    expect(find.text('Add snap'), findsNothing);
    expect(config.snaps.length, 1);
    expect(sectionTitle('Snaps'), findsOneWidget);
    expect(find.text('/tmp/foo.snap'), findsOneWidget);
  });

  testWidgets('step content is anchored at the top, not vertically centered', (
    tester,
  ) async {
    final config = dangerousConfig();
    await tester.pumpWidget(harness(config));
    await tester.pumpAndSettle();

    // The first content row is the page title.
    final caption = tester.getTopLeft(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data == 'Additional snaps' &&
            (w.style?.fontSize ?? 0) >= 18,
      ),
    );
    // StepBody applies 24px padding at the top.
    expect(
      caption.dy,
      closeTo(24, 2),
      reason: 'content must start at the top padding, not mid-viewport',
    );
    expect(
      caption.dy,
      lessThan(100),
      reason:
          'if vertically centered, the caption would sit much lower on '
          'an 800px-tall test viewport',
    );
  });
}
