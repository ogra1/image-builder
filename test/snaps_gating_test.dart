import 'package:flutter/material.dart';

import 'test_tools.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/model_assertion.dart';
import 'package:ubuntu_image_gui/views/wizard_page.dart';

/// The Snaps step must disable its add buttons (and show a warning)
/// whenever the selected model is not of grade "dangerous", and re-enable
/// them as soon as a dangerous-grade model is selected.
void main() {
  Future<void> goToSnaps(WidgetTester tester) async {
    await tester.tap(find.text('Snaps'));
    await tester.pumpAndSettle();
  }

  testWidgets('signed model: add buttons disabled, warning without '
      'failure bluster', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final config = stubbedConfig()
      ..model = ModelAssertion('/tmp/signed.assert', {
        'model': 'test',
        'grade': 'signed',
      }, parsed: true);
    await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
    await tester.pumpAndSettle();
    await goToSnaps(tester);

    // Warning is shown and no longer claims the build would fail.
    final warning = find.textContaining(
      'Only models of grade "dangerous" allow additional',
    );
    expect(warning, findsOneWidget);
    expect(find.textContaining('will make the build fail'), findsNothing);

    // Both add buttons are disabled.
    final storeBtn = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text('Add from store'),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    expect(
      storeBtn.onPressed,
      isNull,
      reason: 'Add from store must be disabled for signed models',
    );
    final localBtn = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text('Add local .snap'),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    expect(
      localBtn.onPressed,
      isNull,
      reason: 'Add local must be disabled for signed models',
    );
  });

  testWidgets('no model selected: add buttons disabled with a hint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final config = stubbedConfig(); // no model
    await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
    await tester.pumpAndSettle();
    await goToSnaps(tester);

    // Both add buttons are disabled until a model is selected.
    final storeBtn = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text('Add from store'),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    expect(
      storeBtn.onPressed,
      isNull,
      reason: 'Add from store must be disabled with no model',
    );
    final localBtn = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text('Add local .snap'),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    expect(
      localBtn.onPressed,
      isNull,
      reason: 'Add local must be disabled with no model',
    );
  });

  testWidgets('dangerous model: add buttons enabled', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final config = stubbedConfig()
      ..model = ModelAssertion('/tmp/dangerous.assert', {
        'model': 'test',
        'grade': 'dangerous',
      }, parsed: true);
    await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
    await tester.pumpAndSettle();
    await goToSnaps(tester);

    final storeBtn = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text('Add from store'),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    expect(storeBtn.onPressed, isNotNull);
    final localBtn = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text('Add local .snap'),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    expect(localBtn.onPressed, isNotNull);
  });

  testWidgets('options page: directory fields have Browse buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: WizardPage(config: stubbedConfig())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();

    // Every directory field (workdir, apparmor features; the output
    // directory lives in step 1) must offer a Browse button.
    for (final label in ['Workdir', 'AppArmor features dir']) {
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      expect(field, findsOneWidget, reason: 'missing field: $label');
      // The Browse button is a sibling of the field within the same Row.
      final row = find.ancestor(of: field, matching: find.byType(Row)).first;
      final browse = find.descendant(of: row, matching: find.text('Browse…'));
      expect(
        browse,
        findsOneWidget,
        reason: 'no Browse button next to: $label',
      );
      final btn = tester.widget<FilledButton>(
        find.ancestor(of: browse, matching: find.byType(FilledButton)).first,
      );
      expect(
        btn.onPressed,
        isNotNull,
        reason: 'Browse button disabled for: $label',
      );
    }
  });
}
