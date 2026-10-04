import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'test_tools.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';
import 'package:ubuntu_image_gui/models/model_assertion.dart';
import 'package:ubuntu_image_gui/views/wizard_page.dart';

/// Fake file_picker platform: answers [directory] for every
/// `getDirectoryPath` call.
class _FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async => directory;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => null;

  String? directory;
}

/// Regression: picking a directory via the Browse buttons used to only
/// update the text field (setting `TextEditingController.text` never fires
/// `TextField.onChanged`), so output-dir / workdir / apparmor-features-dir
/// never reached the generated `ubuntu-image snap` command line.

/// The page title of a step: headline-small text (the sidebar tile uses
/// body-small for the same label, so text alone is ambiguous).
Finder pageTitle(String title) => find.byWidgetPredicate(
  (w) => w is Text && w.data == title && (w.style?.fontSize ?? 0) >= 18,
);

void main() {
  late BuildConfig config;
  late _FakeFilePicker picker;

  setUp(() {
    config = stubbedConfig()
      ..model = ModelAssertion('/tmp/m.assert', {
        'model': 'test-model',
        'grade': 'dangerous',
      }, parsed: true);
    picker = _FakeFilePicker();
    FilePicker.platform = picker;
  });

  Future<void> browse(WidgetTester tester, Finder button) async {
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('directories picked via Browse end up in the generated command', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    expect(pageTitle('Build options'), findsOneWidget);

    // Workdir (first Browse on step 4 — the output directory moved to step 1)
    picker.directory = '/build/work';
    await browse(tester, find.text('Browse…').first);
    expect(config.workdir, '/build/work');

    // AppArmor features dir (3rd Browse button; the 2nd is disk info)
    picker.directory = '/build/aa';
    await browse(tester, find.text('Browse…').at(2));
    expect(config.apparmorFeaturesDir, '/build/aa');

    // The fields show the picked paths…
    expect(find.text('/build/work'), findsOneWidget);
    expect(find.text('/build/aa'), findsOneWidget);

    // …and they are all part of the command that will be run.
    final cmd = config.buildCommand();
    expect(
      cmd,
      containsAllInOrder([
        '--workdir',
        '/build/work',
        '--apparmor-features-dir',
        '/build/aa',
      ]),
    );
  });
}
