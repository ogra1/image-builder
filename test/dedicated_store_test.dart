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
  }) async =>
      path == null
          ? null
          : FilePickerResult([
              PlatformFile(name: 'store.auth', path: path, size: 0),
            ]);

  String? path;
}

void main() {
  group('BuildConfig.buildLaunch', () {
    test('default store: launches ubuntu-image directly', () {
      final c = BuildConfig();
      final launch = c.buildLaunch();
      expect(launch.command, 'ubuntu-image');
      expect(launch.arguments, ['snap']);
      expect(c.hasStoreAuth, isFalse);
      expect(c.storeAuthPrefix, isEmpty);
    });

    test(
      'dedicated store: wraps in /bin/sh and injects UBUNTU_STORE_AUTH '
      'via cat',
      () {
        final c = BuildConfig()..storeAuthFile = '/home/me/store.auth';
        final launch = c.buildLaunch();
        expect(launch.command, '/bin/sh');
        expect(launch.arguments.length, 2);
        expect(launch.arguments.first, '-c');
        final cmd = launch.arguments.last;
        expect(
          cmd,
          startsWith("UBUNTU_STORE_AUTH=\$(cat '/home/me/store.auth') "),
        );
        expect(cmd, endsWith("exec ubuntu-image 'snap'"));
        // The token is never read: the file content must not appear.
        expect(cmd, isNot(contains('SECRET')));
      },
    );

    test('path with spaces and a single quote is shell-quoted', () {
      final c = BuildConfig()..storeAuthFile = "/home/o'brien/my store auth";
      final cmd = c.buildLaunch().arguments.last;
      expect(cmd, startsWith("UBUNTU_STORE_AUTH=\$(cat '/home/o'"));
      expect(cmd, contains(r"'\''brien/my store auth')"));
      expect(cmd, endsWith("exec ubuntu-image 'snap'"));
    });
  });

  group('BuildConfig.shellQuote', () {
    test('quotes a plain path', () {
      expect(BuildConfig.shellQuote('/a/b'), "'/a/b'");
    });

    test('escapes embedded single quotes', () {
      expect(BuildConfig.shellQuote("o'brien"), r"'o'\''brien'");
    });
  });

  testWidgets(
    'step 1: dedicated store card picks the credential file, shows it, '
    'and the launch follows; removing it reverts to the global store',
    (tester) async {
      final picker = _FakeFilePicker();
      FilePicker.platform = picker;
      final config = BuildConfig();

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Step1ModelStep(config: config))),
      );
      await tester.pumpAndSettle();

      // The card and its how-to are present.
      expect(find.text('Dedicated store'), findsOneWidget);
      expect(
        find.text('snapcraft export-login --acls package_access store.auth'),
        findsOneWidget,
      );

      // Pick a credential file.
      picker.path = '/home/me/store.auth';
      await tester.tap(find.text('Select credential file…'));
      await tester.pumpAndSettle();

      expect(config.storeAuthFile, '/home/me/store.auth');
      expect(find.text('/home/me/store.auth'), findsOneWidget);
      expect(
        find.text('Will be passed to the build as UBUNTU_STORE_AUTH'),
        findsOneWidget,
      );
      // The launch is now wrapped in the shell.
      expect(config.buildLaunch().command, '/bin/sh');

      // Remove it: back to the global store.
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(config.storeAuthFile, '');
      expect(config.buildLaunch().command, 'ubuntu-image');
      expect(find.text('Select credential file…'), findsOneWidget);
    },
  );
}
