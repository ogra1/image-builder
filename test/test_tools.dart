import 'package:ubuntu_image_gui/models/build_config.dart';

/// Tool check that reports success immediately, so widget tests never
/// shell out (a real Process.run would never deliver in fake-async
/// zones, leaving the wizard stuck on its startup progress bar).
const stubToolCheckValue = ToolCheck(ok: true, version: 'stub 1.0');

/// A [BuildConfig] whose [BuildConfig.toolChecker] is stubbed.
BuildConfig stubbedConfig() =>
    BuildConfig()..toolChecker = (executable) async => stubToolCheckValue;

/// Marks an existing [config] as tool-checked-ok.
BuildConfig stubToolCheck(BuildConfig config) =>
    config..toolChecker = (executable) async => stubToolCheckValue;
