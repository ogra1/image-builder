import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';
import 'package:ubuntu_image_gui/views/step1_model_step.dart';

class _FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
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
  }) async => path == null
      ? null
      : FilePickerResult([PlatformFile(name: 'm.assert', path: path, size: 0)]);

  String? path;
}

Finder chooseButton() => find.text('Choose model assertion…');

void main() {
  late BuildConfig config;
  late _FakeFilePicker picker;
  late Directory tmp;

  setUp(() {
    config = BuildConfig();
    picker = _FakeFilePicker();
    FilePicker.platform = picker;
    tmp = Directory.systemTemp.createTempSync('model-import');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> pick(String content) async {
    final f = File('${tmp.path}/m.assert')..writeAsStringSync(content);
    picker.path = f.path;
  }

  testWidgets('classic: true model is refused at import', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Step1ModelStep(config: config)),
      ),
    );
    await tester.pumpAndSettle();

    await pick('model: my-model\ngrade: signed\nclassic: true\n');
    await tester.tap(chooseButton());
    await tester.pumpAndSettle();

    // The import is refused: the model is NOT set, the empty state
    // remains, and an error explains why.
    expect(config.model, isNull);
    expect(find.textContaining('No model assertion selected'), findsOneWidget);
    expect(
      find.textContaining('classic: true'),
      findsOneWidget,
      reason: 'error banner should mention the classic flag',
    );
  });

  testWidgets('non-classic model imports fine', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Step1ModelStep(config: config)),
      ),
    );
    await tester.pumpAndSettle();

    await pick('model: my-model\ngrade: signed\n');
    await tester.tap(chooseButton());
    await tester.pumpAndSettle();

    expect(config.model, isNotNull);
    expect(config.model!.model, 'my-model');
    expect(find.textContaining('classic: true'), findsNothing);
  });
}
