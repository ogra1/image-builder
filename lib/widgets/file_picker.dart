import 'package:file_selector/file_selector.dart';

/// Thin wrappers around the first-party [file_selector] package, matching
/// the call shape the views used with `file_picker`.
///
/// file_selector (unlike file_picker) renders the dialog with a *native
/// GTK file chooser inside this process* (XDG Desktop Portals on
/// GNOME). The dialog is therefore a transient child window of the main
/// window and shares the app's identity — GNOME does NOT spawn a second
/// panel icon for it. (file_picker shell-executed `zenity`, a separate
/// process with its own identity, which is why it showed a second icon.)
///
/// Trade-off: the file_selector APIs have no "dialog title" parameter, so
/// the titles the previous calls passed are dropped here.
Future<XFile?> pickFile({
  List<String> extensions = const [],
}) async =>
    openFile(
      acceptedTypeGroups: extensions.isEmpty
          ? const []
          : [XTypeGroup(label: 'Supported files', extensions: extensions)],
    );

Future<List<XFile>> pickFiles({
  List<String> extensions = const [],
}) async =>
    openFiles(
      acceptedTypeGroups: extensions.isEmpty
          ? const []
          : [XTypeGroup(label: 'Supported files', extensions: extensions)],
    );

/// Pick a directory. Returns null when the user cancels.
Future<String?> pickDirectory() => getDirectoryPath();
