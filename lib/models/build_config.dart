import 'dart:io';

import 'package:flutter/foundation.dart';

import 'model_assertion.dart';

/// A component of a snap to include in the image (`--comp`).
class SnapComponent {
  SnapComponent.store({required this.name, this.channel = ''})
    : snapName = '',
      localPath = null;
  SnapComponent.local({required this.snapName, required this.localPath})
    : name = localPath!,
      channel = '';

  /// Component name (store) or local file path (local).
  final String name;

  /// Store channel (empty = default).
  final String channel;

  /// Name of the parent snap this component belongs to.
  final String snapName;

  /// Local file path for local components, if any.
  final String? localPath;

  bool get isLocal => localPath != null;

  String get label => isLocal ? localPath! : name;

  /// The `--comp` argument in the form `<snap>+<comp>[=channel]`.
  ///
  /// [parentName] is used when the component was created without an
  /// explicit parent snap name (store components added in the UI).
  String compArg(String parentName) {
    final s = snapName.isEmpty ? parentName : snapName;
    final base = isLocal ? '$s+$localPath' : '$s+$name';
    return channel.isEmpty ? base : '$base=$channel';
  }
}

/// A snap to include in the image (`--snap`).
class ExtraSnap {
  ExtraSnap.store({required this.name, this.channel = ''}) : localPath = null;

  /// Local .snap files carry no channel — that is a store concept, the
  /// file is installed as-is.
  ExtraSnap.local({required this.name, required this.localPath}) : channel = '';

  /// Snap name (store) or file basename (local).
  final String name;

  /// Store channel (empty = default). Always empty for local snaps.
  final String channel;

  /// Local .snap file path, if this is a local snap.
  final String? localPath;

  /// Additional components of this snap.
  final List<SnapComponent> components = [];

  bool get isLocal => localPath != null;

  String get displayName => isLocal ? localPath! : name;

  String get subtitle => isLocal
      ? 'Local snap file'
      : channel.isEmpty
      ? 'Store · default channel'
      : 'Store · $channel';

  /// The `--snap` argument: `<snap>[=channel]` (snap may be a local path,
  /// which never carries a channel).
  String get snapArg {
    if (isLocal) return localPath!;
    return channel.isEmpty ? name : '$name=$channel';
  }
}

/// A validation set pinned to a sequence (`--sequence`).
class ValidationSet {
  ValidationSet({this.name = '', this.sequence = ''});

  String name;
  String sequence;

  bool get isEmpty => name.trim().isEmpty;

  /// The `--sequence` argument: `<name>[:<sequence>]`.
  String get sequenceArg {
    final n = name.trim();
    final s = sequence.trim();
    return s.isEmpty ? n : '$n:$s';
  }
}

/// All user-selected options for an `ubuntu-image snap` build.
///
/// A [ChangeNotifier]: UI that depends on the configuration (e.g. the
/// wizard's sidebar gating) listens to it via `notifyListeners()` so it
/// refreshes immediately when a value changes.
/// The build subprocess, as consumed by the Build step. A real
/// [Process] satisfies this via [BuildProcessImpl]; tests provide a
/// lightweight fake without re-implementing the full `Process` API.
abstract class BuildProcess {
  Stream<List<int>> get stdout;

  Stream<List<int>> get stderr;

  Future<int> get exitCode;

  bool kill(ProcessSignal signal);
}

/// Adapts a real [Process] to [BuildProcess].
class BuildProcessImpl implements BuildProcess {
  BuildProcessImpl(this._p);
  final Process _p;

  @override
  Stream<List<int>> get stdout => _p.stdout;

  @override
  Stream<List<int>> get stderr => _p.stderr;

  @override
  Future<int> get exitCode => _p.exitCode;

  @override
  bool kill(ProcessSignal signal) => _p.kill(signal);
}

/// Starts a build process by executable name and argument list.
typedef ProcessStarter = Future<BuildProcess> Function(
  String executable,
  List<String> arguments,
);

/// Result of verifying the `ubuntu-image` tool on startup.
class ToolCheck {
  const ToolCheck({required this.ok, this.version, this.hint});

  final bool ok;

  /// Version string, when the tool reported one.
  final String? version;

  /// Human-readable hint when the tool is missing or unusable.
  final String? hint;
}

class BuildConfig extends ChangeNotifier {
  /// Executable to run for the build (defaults to the `ubuntu-image`
  /// snap). Overridable for tests.
  String executable = 'ubuntu-image';

  /// Verifies that the tool is available and usable. Called once at app
  /// startup (see [WizardPage]) and right before a build is launched.
  ///
  /// Tests override this to avoid shelling out.
  Future<ToolCheck> Function(String) toolChecker = (String executable) async {
    try {
      final result = await Process.run(executable, ['--version']);
      if (result.exitCode == 0) {
        final lines = result.stdout
            .toString()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        final version = lines.isNotEmpty ? lines.first.trim() : null;
        return ToolCheck(ok: true, version: version);
      }
      return ToolCheck(
        ok: false,
        hint:
            "'$executable --version' exited with code ${result.exitCode}: "
            "${result.stderr.toString().trim()}",
      );
    } on ProcessException {
      return ToolCheck(
        ok: false,
        hint:
            'The ubuntu-image tool is not installed (or not on your '
            'PATH). It is a classic snap, so install it with:\n  sudo '
            'snap install ubuntu-image --classic',
      );
    }
  };

  /// Starts the build process. Defaults to `Process.start`; overridable
  /// for tests (widget tests run in a fake-async zone where real process
  /// events are never delivered).
  ProcessStarter processStarter = (executable, arguments) async =>
      BuildProcessImpl(await Process.start(executable, arguments));

  // -- Step 1: model assertion -------------------------------------------
  ModelAssertion? model;

  /// Sets the model assertion and notifies listeners (the wizard shell
  /// uses this to enable the Build step immediately).
  void setModel(ModelAssertion? m) {
    model = m;
    notifyListeners();
  }

  // -- Step 2: additional snaps ------------------------------------------
  final List<ExtraSnap> snaps = [];

  // -- Step 3: validation sets & assertions --------------------------------
  final List<ValidationSet> validationSets = [];
  final List<String> assertionFiles = [];

  // -- Step 4: general build options ---------------------------------------
  String _outputDir = '';

  /// Directory where the .img files are written. Chosen in step 1;
  /// mandatory for building. Notifies listeners when the field
  /// transitions between empty and non-empty — that transition is what
  /// gates the Build step. Editing a non-empty path (or clearing an
  /// empty one) doesn't change the gate, so no notification is needed.
  String get outputDir => _outputDir;
  set outputDir(String v) {
    final wasEmpty = _outputDir.isEmpty;
    _outputDir = v;
    if (wasEmpty != v.isEmpty) notifyListeners();
  }

  String workdir = '';
  String imageSize = '';
  String defaultChannel = '';
  int? sectorSize; // null = default (512)
  String? validation; // null = default, 'ignore' or 'enforce'
  bool preseed = false;
  bool factoryImage = false;
  bool disableConsoleConf = false;
  bool allowSnapdKernelMismatch = false;

  /// Output verbosity. The three levels are mutually exclusive in
  /// `ubuntu-image snap`, so a single selection is enforced here.
  Verbosity verbosity = Verbosity.normal;
  bool dryRun = false;
  String diskInfoFile = '';
  String apparmorFeaturesDir = '';
  String preseedSignKey = '';
  String sysfsOverlay = '';

  /// Builds the full argument list for `ubuntu-image snap`.
  List<String> buildCommand() {
    final a = <String>[];
    if (dryRun) a.add('--dry-run');
    if (verbosity == Verbosity.verbose) a.add('--verbose');
    if (verbosity == Verbosity.debug) a.add('--debug');
    if (verbosity == Verbosity.quiet) a.add('--quiet');
    if (outputDir.isNotEmpty) a.addAll(['--output-dir', outputDir]);
    if (workdir.isNotEmpty) a.addAll(['--workdir', workdir]);
    if (imageSize.isNotEmpty) a.addAll(['--image-size', imageSize]);
    if (defaultChannel.isNotEmpty) a.addAll(['-c', defaultChannel]);
    if (sectorSize != null) a.addAll(['--sector-size', '$sectorSize']);
    if (validation != null) a.addAll(['--validation', validation!]);
    if (diskInfoFile.isNotEmpty) a.addAll(['--disk-info', diskInfoFile]);
    if (preseed) a.add('--preseed');
    // The preseed-only options are ignored (and their values must not
    // leak) unless the preseed toggle itself is on.
    if (preseed && preseedSignKey.isNotEmpty) {
      a.addAll(['--preseed-sign-key', preseedSignKey]);
    }
    if (preseed && sysfsOverlay.isNotEmpty) {
      a.addAll(['--sysfs-overlay', sysfsOverlay]);
    }
    if (factoryImage) a.add('--factory-image');
    if (disableConsoleConf) a.add('--disable-console-conf');
    if (apparmorFeaturesDir.isNotEmpty) {
      a.addAll(['--apparmor-features-dir', apparmorFeaturesDir]);
    }
    if (allowSnapdKernelMismatch) a.add('--allow-snapd-kernel-mismatch');
    for (final snap in snaps) {
      a.addAll(['--snap', snap.snapArg]);
      for (final comp in snap.components) {
        a.addAll(['--comp', comp.compArg(snap.name)]);
      }
    }
    for (final vs in validationSets) {
      if (vs.isEmpty) continue;
      a.addAll(['--sequence', vs.sequenceArg]);
    }
    for (final f in assertionFiles) {
      a.addAll(['--assertion', f]);
    }
    if (model != null) a.add(model!.path);
    return a;
  }

  /// Human-readable command line for display.
  /// The executable and full argument vector to run, i.e.
  /// `ubuntu-image snap <options>`. The `snap` subcommand is mandatory —
  /// calling `ubuntu-image` without it fails.
  List<String> get snapCommand => ['snap', ...buildCommand()];
}

/// Output verbosity for `ubuntu-image snap`. The tool accepts exactly one
/// of `--verbose` / `--debug` / `--quiet`, so these are modeled as
/// mutually exclusive.
enum Verbosity {
  normal('Normal'),
  verbose('Verbose'),
  debug('Debug'),
  quiet('Quiet');

  const Verbosity(this.label);

  final String label;
}
