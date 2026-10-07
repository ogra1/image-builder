import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';
import 'package:ubuntu_image_gui/views/step1_model_step.dart';

class _FakeFileSelector extends FileSelectorPlatform {
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => null;
}

void main() {
  testWidgets(
    'copying the export-login command shows a snackbar and puts the '
    'exact command on the clipboard',
    (tester) async {
      FileSelectorPlatform.instance = _FakeFileSelector();

      // The clipboard platform channel is not backed by a real OS clipboard
      // in the widget-test sandbox (getData would hang forever). Mock it to
      // capture whatever the app writes and hand it back on read.
      // Clipboard traffic goes over the platform channel as
      // Clipboard.setData / Clipboard.getData (see the Clipboard service).
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              clipboardText = (call.arguments as Map)['text'] as String?;
              return null;
            case 'Clipboard.getData':
              return (call.arguments as String) == 'text/plain'
                  ? (clipboardText != null ? {'text': clipboardText} : null)
                  : null;
            default:
              return null;
          }
        },
      );

      final config = BuildConfig();

      // Tall viewport so the whole page (including the command field at the
      // bottom) is visible without any scrolling.
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Step1ModelStep(config: config))),
      );
      await tester.pumpAndSettle();

      final copyButton = find.byIcon(YaruIcons.copy);
      expect(copyButton, findsOneWidget);

      await tester.tap(copyButton);
      await tester.pump(); // start the snackbar entrance animation

      // The snackbar confirms the copy.
      expect(find.text('Command copied to clipboard'), findsOneWidget);

      // The exact command was written to the clipboard, ready to paste.
      expect(
        clipboardText,
        'snapcraft export-login --acls package_access store.auth',
      );

      await tester.pumpAndSettle();
    },
  );
}
