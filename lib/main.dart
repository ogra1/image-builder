import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import 'models/build_config.dart';
import 'views/wizard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Note: no YaruWindowTitleBar.ensureInitialized() on purpose. The native
  // GTK title bar stays intact and the window manager (mutter) draws the
  // frame — this keeps the app visually consistent with the other tools in
  // the group (model builder, gadget editor) and with the desktop.
  runApp(const UbuntuImageApp());
}

/// Application root.
///
/// Wraps the app in [YaruTheme] using its builder so the app seamlessly
/// mirrors the system's light/dark mode and native accent colors.
///
/// The [BuildConfig] is owned by the [State] and NOT created inside the
/// YaruTheme builder: YaruTheme resolves system theme settings
/// asynchronously and re-runs the builder when they settle. Creating the
/// config there would hand the (persistent) WizardPage a brand-new
/// instance on that rebuild, orphaning any listeners attached to the
/// first one.
class UbuntuImageApp extends StatefulWidget {
  const UbuntuImageApp({super.key});

  @override
  State<UbuntuImageApp> createState() => _UbuntuImageAppState();
}

class _UbuntuImageAppState extends State<UbuntuImageApp> {
  final BuildConfig _config = BuildConfig();

  @override
  Widget build(BuildContext context) {
    return YaruTheme(
      builder: (context, yaruThemeData, child) {
        return MaterialApp(
          title: 'Image Builder',
          debugShowCheckedModeBanner: false,
          theme: yaruThemeData.theme,
          darkTheme: yaruThemeData.darkTheme,
          themeMode: yaruThemeData.themeMode,
          home: WizardPage(config: _config),
        );
      },
    );
  }
}
