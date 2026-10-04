import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'test_tools.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';
import 'package:ubuntu_image_gui/models/model_assertion.dart';
import 'package:ubuntu_image_gui/views/wizard_page.dart';

class _FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async => directory;

  String? directory;
}

Finder buildTile() =>
    find.ancestor(of: find.text('Build'), matching: find.byType(InkWell)).first;

/// The Build step is gated on BOTH a model assertion and an output
/// directory — each chosen in step 1 — and the tile explains what is
/// missing.
void main() {
  late BuildConfig config;

  setUp(() {
    config = stubbedConfig();
    FilePicker.platform = _FakeFilePicker();
  });

  testWidgets('gate requires model AND output dir; tooltip names the '
      'missing part', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
    await tester.pumpAndSettle();

    // Neither chosen: gated, tooltip names both.
    expect(tester.widget<InkWell>(buildTile()).onTap, isNull);
    Tooltip tooltip() => tester.widget<Tooltip>(
      find
          .ancestor(of: find.text('Build'), matching: find.byType(Tooltip))
          .first,
    );
    expect(
      tooltip().message,
      'Select a model assertion and an output directory',
    );
    expect(
      find.text('Select a model assertion and an output directory'),
      findsOneWidget,
    ); // sidebar footer

    // Step 1 offers the output directory with a Browse button.
    expect(find.text('Output directory'), findsOneWidget);
    final outRow = find
        .ancestor(of: find.text('Output directory'), matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: outRow, matching: find.text('Browse…')),
      findsOneWidget,
    );

    // Model alone is not enough.
    config.setModel(
      ModelAssertion('/tmp/m.assert', {
        'model': 'test-model',
        'grade': 'dangerous',
      }, parsed: true),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(buildTile()).onTap, isNull);
    expect(tooltip().message, 'Select an output directory');

    // The output directory alone is not enough either (fresh config).
    final c2 = BuildConfig()..outputDir = '/out';
    await tester.pumpWidget(MaterialApp(home: WizardPage(config: c2)));
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(buildTile()).onTap, isNull);
    expect(find.text('Select a model assertion'), findsOneWidget);

    // Back to the main config: now pick the output dir via the step 1
    // field — the setter's notification must flip the gate immediately.
    await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Directory',
      ),
      '/home/me/images',
    );
    await tester.pumpAndSettle();
    expect(config.outputDir, '/home/me/images');
    expect(tester.widget<InkWell>(buildTile()).onTap, isNotNull);
    expect(find.text('Ready to build'), findsOneWidget);

    // Clearing the output dir gates the step again.
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Directory',
      ),
      '',
    );
    await tester.pumpAndSettle();
    expect(config.outputDir, isEmpty);
    expect(tester.widget<InkWell>(buildTile()).onTap, isNull);
    expect(tooltip().message, 'Select an output directory');
  });

  testWidgets('output dir picked via step 1 Browse unlocks the Build '
      'step', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final picker = _FakeFilePicker()..directory = '/srv/images';
    FilePicker.platform = picker;
    config.setModel(
      ModelAssertion('/tmp/m.assert', {
        'model': 'test-model',
        'grade': 'dangerous',
      }, parsed: true),
    );

    await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Browse…').first);
    await tester.pumpAndSettle();

    expect(config.outputDir, '/srv/images');
    expect(tester.widget<InkWell>(buildTile()).onTap, isNotNull);
    final cmd = config.buildCommand();
    expect(cmd, containsAllInOrder(['--output-dir', '/srv/images']));
  });
}
