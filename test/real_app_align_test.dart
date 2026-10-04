import 'package:flutter/material.dart';

import 'test_tools.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/model_assertion.dart';
import 'package:ubuntu_image_gui/views/wizard_page.dart';

/// Measures the real WizardPage (the exact widget that wraps the steps in
/// the app) to prove or disprove vertical centering of step content.

/// The page title of a step: headline-small text (the sidebar tile uses
/// body-small for the same label, so text alone is ambiguous).
Finder pageTitle(String title) => find.byWidgetPredicate(
  (w) => w is Text && w.data == title && (w.style?.fontSize ?? 0) >= 18,
);

void main() {
  testWidgets('real WizardPage: step caption is top-aligned', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final config = stubbedConfig()
      ..model = ModelAssertion('/tmp/model.assert', {
        'model': 'test-model',
        'grade': 'dangerous',
      }, parsed: true);

    await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
    await tester.pumpAndSettle();

    // Default is step 1 (Model).
    final caption1 = tester.getTopLeft(pageTitle('Model assertion'));
    debugPrint('PAGE1 caption1=($caption1)');

    // Navigate to the Snaps step via the sidebar.
    await tester.tap(find.text('Additional snaps'));
    await tester.pumpAndSettle();
    final caption2 = tester.getTopLeft(pageTitle('Additional snaps'));
    debugPrint('PAGE2 caption2=($caption2)');

    final vh = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    debugPrint('viewport height=$vh middle=${vh / 2}');

    // If top-aligned, both captions sit just below the AppBar+padding.
    // If vertically centered, they'd sit far lower (near the middle).
    expect(caption1.dy, lessThan(200), reason: 'page1 not top-aligned');
    expect(caption2.dy, lessThan(200), reason: 'page2 not top-aligned');
  });

  testWidgets('step 1: empty-state card width matches selected card width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final config = stubbedConfig(); // no model selected
    await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
    await tester.pumpAndSettle();

    // Empty-state card width (spans the full content width of the pane).
    final emptyWidth = tester
        .getSize(
          find
              .ancestor(
                of: find.text('No model assertion selected'),
                matching: find.byType(Card),
              )
              .first,
        )
        .width;

    // Select a model assertion (sets it directly to avoid the file dialog)
    // and measure the selected-model card.
    config.model = ModelAssertion('/tmp/model.assert', {
      'model': 'test-model',
      'grade': 'dangerous',
    }, parsed: true);
    // Trigger a rebuild of the step (wizard holds the config; a sidebar
    // round-trip is the natural way to force it, but the step itself
    // rebuilds on any setState of the wizard).
    await tester.tap(find.text('Snaps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Model'));
    await tester.pumpAndSettle();

    final selectedWidth = tester
        .getSize(
          find
              .ancestor(
                of: find.text('/tmp/model.assert'),
                matching: find.byType(Card),
              )
              .first,
        )
        .width;

    expect(
      selectedWidth,
      closeTo(emptyWidth, 1),
      reason: 'card must not resize when a model assertion is selected',
    );
  });

  testWidgets('sidebar Build step activates immediately when a model is '
      'selected (no step switch)', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final config = stubbedConfig(); // no model
    await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
    await tester.pumpAndSettle();

    // The sidebar's "Build" tile: with no model it must be disabled.
    final buildTile = find
        .ancestor(of: find.text('Build'), matching: find.byType(InkWell))
        .first;
    expect(
      tester.widget<InkWell>(buildTile).onTap,
      isNull,
      reason: 'Build step must be disabled without a model assertion',
    );

    // Select a model — the shell must rebuild immediately via the
    // ChangeNotifier, no step switch involved.
    config.setModel(
      ModelAssertion('/tmp/model.assert', {
        'model': 'test-model',
        'grade': 'dangerous',
      }, parsed: true),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<InkWell>(buildTile).onTap,
      isNull,
      reason: 'Build step stays disabled until an output dir is chosen too',
    );

    // The output directory is the second half of the gate — and it is
    // notified by the config setter (the whole point of the
    // empty <-> non-empty notification in BuildConfig).
    config.outputDir = '/out';
    await tester.pumpAndSettle();

    expect(
      tester.widget<InkWell>(buildTile).onTap,
      isNotNull,
      reason:
          'Build step must be enabled as soon as model AND output dir '
          'are set',
    );
  });
}
