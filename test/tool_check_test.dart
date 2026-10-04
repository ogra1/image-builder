import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ubuntu_image_gui/models/build_config.dart';
import 'package:ubuntu_image_gui/views/wizard_page.dart';

void main() {
  test('toolChecker reports ok + version for a working executable', () async {
    final dir = Directory.systemTemp.createTempSync('toolchk');
    addTearDown(() => dir.deleteSync(recursive: true));
    final script = File(p.join(dir.path, 'fake-tool'))
      ..writeAsStringSync('#!/bin/sh\necho "fake-tool 9.9.9"\n');
    await Process.run('chmod', ['755', script.path]);

    final check = await BuildConfig().toolChecker(script.path);
    expect(check.ok, isTrue);
    expect(check.version, 'fake-tool 9.9.9');
  });

  test('toolChecker reports a hint when the executable is missing', () async {
    final dir = Directory.systemTemp.createTempSync('toolchk');
    addTearDown(() => dir.deleteSync(recursive: true));

    final check = await BuildConfig().toolChecker('${dir.path}/nope');
    expect(check.ok, isFalse);
    expect(check.hint, contains('sudo snap install ubuntu-image --classic'));
  });

  testWidgets('missing tool shows a banner with a working retry', (
    tester,
  ) async {
    final config = BuildConfig()
      ..toolChecker = (e) async =>
          const ToolCheck(ok: false, hint: 'not installed');

    await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ubuntu-image is not available: not installed'),
      findsOneWidget,
    );

    // Retry re-runs the check; once the tool is present the banner goes
    // away.
    config.toolChecker = (e) async => const ToolCheck(ok: true);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ubuntu-image is not available'), findsNothing);
  });
}
