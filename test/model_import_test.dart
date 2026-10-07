import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';
import 'package:ubuntu_image_gui/views/step1_model_step.dart';

class _FakeFileSelector extends FileSelectorPlatform {
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    final p = path;
    return p == null ? null : XFile(p, name: 'm.assert');
  }

  String? path;
}

Finder chooseButton() => find.text('Choose model assertion…');

void main() {
  late BuildConfig config;
  late _FakeFileSelector picker;
  late Directory tmp;

  setUp(() {
    config = BuildConfig();
    picker = _FakeFileSelector();
    FileSelectorPlatform.instance = picker;
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
