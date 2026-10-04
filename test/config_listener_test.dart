import 'package:flutter/material.dart';

import 'test_tools.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/model_assertion.dart';
import 'package:ubuntu_image_gui/views/wizard_page.dart';

/// Regression: on a real Linux desktop, YaruTheme resolves system theme
/// settings asynchronously and re-runs its builder once they settle. If
/// the BuildConfig is created inside that builder (as the old main.dart
/// did), the persistent WizardPage receives a NEW config instance on the
/// rebuild — and a listener registered in initState stays attached to the
/// first, now-dead instance. Result: the sidebar's Build step only
/// refreshed on a manual step switch.
///
/// These tests simulate that instance swap by re-pumping a fresh config.
void main() {
  testWidgets('sidebar Build step reacts to model set on the NEW config '
      'instance after a config swap', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Initial pump: WizardPage gets config #1.
    await tester.pumpWidget(
      MaterialApp(home: WizardPage(config: stubbedConfig())),
    );
    await tester.pumpAndSettle();

    final buildTile = find
        .ancestor(of: find.text('Build'), matching: find.byType(InkWell))
        .first;
    expect(tester.widget<InkWell>(buildTile).onTap, isNull);

    // YaruTheme's async theme resolution settles -> builder re-runs ->
    // a brand-new BuildConfig is handed to the same WizardPage state.
    final swappedIn = stubbedConfig();
    await tester.pumpWidget(MaterialApp(home: WizardPage(config: swappedIn)));
    await tester.pumpAndSettle();

    // The user now selects a model assertion AND an output directory on
    // the live (new) config — both gate the Build step.
    swappedIn.setModel(
      ModelAssertion('/tmp/model.assert', {
        'model': 'test-model',
        'grade': 'dangerous',
      }, parsed: true),
    );
    swappedIn.outputDir = '/out';
    await tester.pumpAndSettle();

    // The Build step must be enabled immediately — no step switch.
    expect(
      tester.widget<InkWell>(buildTile).onTap,
      isNotNull,
      reason: 'sidebar must track the config instance it currently uses',
    );
  });

  testWidgets('sidebar tile hover/press highlight is rounded like the '
      'selection', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WizardPage(config: stubbedConfig())),
    );
    await tester.pumpAndSettle();

    // The tile's Material paints the selection background with
    // borderRadius 10; the InkWell (hover/press ink) must carry the
    // same radius — otherwise the ink highlight renders as a square.
    final tile = tester.element(
      find
          .ancestor(of: find.text('Model'), matching: find.byType(InkWell))
          .first,
    );
    final material = tile.findAncestorWidgetOfExactType<Material>() as Material;
    final ink = tile.widget as InkWell;
    expect(ink.borderRadius, BorderRadius.circular(10));
    expect(material.borderRadius, BorderRadius.circular(10));
    expect(ink.borderRadius, material.borderRadius);
  });

  testWidgets('no leaked listeners across repeated config swaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: WizardPage(config: stubbedConfig())),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pumpWidget(
        MaterialApp(home: WizardPage(config: stubbedConfig())),
      );
    }
    await tester.pumpWidget(const SizedBox());
    // Reaching this point without a "disposed with listeners" error is the
    // pass condition: every swap detaches the old listener.
  });

  testWidgets('sidebar styling: no fill, selected tile uses accent tint', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: WizardPage(config: stubbedConfig())),
    );
    await tester.pumpAndSettle();

    // The sidebar column itself must not have an explicit background
    // color (it should inherit the standard app surface).
    final sidebar = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();
    for (final c in sidebar) {
      final deco = c.decoration;
      if (deco is BoxDecoration) {
        expect(
          deco.color,
          isNull,
          reason: 'sidebar must not set its own fill color',
        );
      }
    }

    // The selected (default: Model) tile carries the accent tint.
    final scheme = Theme.of(tester.element(find.text('Model'))).colorScheme;
    final expectedTint = scheme.primary.withValues(alpha: 0.12);
    final selectedTile = find
        .ancestor(of: find.text('Model'), matching: find.byType(Material))
        .first;
    expect(tester.widget<Material>(selectedTile).color, expectedTint);

    // And its icon is accent-colored. The Icon is a sibling of the
    // title Column, both children of the tile's Row.
    final tileRow = find
        .ancestor(of: find.text('Model'), matching: find.byType(Row))
        .first;
    final icon = find
        .descendant(of: tileRow, matching: find.byType(Icon))
        .first;
    expect(tester.widget<Icon>(icon).color, scheme.primary);
  });
}
