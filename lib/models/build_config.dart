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

/// A fully specified process launch (command + argument vector).
class BuildProcess {
  BuildProcess({
    required this.command,
    required this.arguments,
    this.starter,
  });

  /// The executable to run (e.g. `/bin/sh`).
  final String command;

  /// Its argument vector.
  final List<String> arguments;

  /// The injected starter, if any (widget tests provide a fake; real
  /// builds use `Process.start`).
  Future<BuildProcessHandle> Function(String, List<String>)? starter;

  Future<BuildProcessHandle> start() =>
      (starter ??
              (command, arguments) async => RealBuildProcessHandle(
                await Process.start(command, arguments),
              ))(command, arguments);
}

/// A running build process as consumed by the Build step. A real
/// [Process] satisfies this via [RealBuildProcessHandle]; tests provide a
/// lightweight fake without re-implementing the full `Process` API.
abstract class BuildProcessHandle {
  Stream<List<int>> get stdout;

  Stream<List<int>> get stderr;

  Future<int> get exitCode;

  bool kill(ProcessSignal signal);
}

/// Adapts a real [Process] to [BuildProcessHandle].
class RealBuildProcessHandle implements BuildProcessHandle {
  RealBuildProcessHandle(this._p);
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

  // -- Step 1: model assertion -------------------------------------------
  ModelAssertion? model;

  /// Sets the model assertion and notifies listeners (the wizard shell
  /// uses this to enable the Build step immediately).
  void setModel(ModelAssertion? m) {
    model = m;
    notifyListeners();
  }

  /// Path of the dedicated-store credential file (output of
  /// `snapcraft export-login --acls package_access`).
  ///
  /// Empty string = use the default (global) snap store. When set, the
  /// file's content is injected into the build process environment as
  /// `UBUNTU_STORE_AUTH` — which `ubuntu-image` reads to authenticate
  /// against the dedicated store.
  ///
  /// NOTE: the file is intentionally never read into Dart memory. At
  /// launch the content is passed via the shell as
  /// `UBUNTU_STORE_AUTH="$(cat <path>)"`, so the token only ever exists
  /// in the environment of the `ubuntu-image` subprocess. See
  /// [buildLaunch].
  String storeAuthFile = '';

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

  // -- Launching the build -------------------------------------------------

  /// Test hook: when set, every [BuildProcess] created by [buildLaunch]
  /// uses this function to start the process instead of the real
  /// `Process.start`. (Widget tests run in a fake-async zone where real
  /// process events are never delivered.)
  Future<BuildProcessHandle> Function(String, List<String>)?
      launchStarterOverride;


  /// Single-quotes [s] for safe inclusion in a POSIX shell command line.
  /// Embedded single quotes are escaped as `'\''`.
  static String shellQuote(String s) =>
      "'${s.replaceAll("'", r"'\''")}'";

  /// Whether a dedicated-store credential file is configured.
  bool get hasStoreAuth => storeAuthFile.trim().isNotEmpty;

  /// The `UBUNTU_STORE_AUTH="$(cat '<path>')"` prefix shown in the Build
  /// step's command-line preview and printed above the console output.
  /// The token itself is never displayed or read into Dart — only the
  /// path is.
  String get storeAuthPrefix {
    final path = storeAuthFile.trim();
    if (path.isEmpty) return '';
    return 'UBUNTU_STORE_AUTH=\$(cat ${shellQuote(path)}) ';
  }

  /// Describes how the build is launched.
  ///
  /// Without a dedicated-store credential file this is a plain
  /// `Process.start(executable, snapCommand)`.
  ///
  /// With one, the build is wrapped in a POSIX shell so the credential
  /// file's content is injected into the process environment at launch
  /// time:
  ///
  /// ```sh
  /// UBUNTU_STORE_AUTH="$(cat '<path>')" exec <executable> snap <options>
  /// ```
  ///
  /// The file is read by the shell (and never by Dart), so the token
  /// never enters this application's memory. `exec` replaces the shell
  /// with the `ubuntu-image` process, so its exit code and signals
  /// (e.g. "Stop build") propagate directly.
  BuildProcess buildLaunch() {
    final command = snapCommand;
    final starter = launchStarterOverride;
    if (!hasStoreAuth) {
      return BuildProcess(
        command: executable,
        arguments: command,
        starter: starter,
      );
    }
    final shCmd =
        '${storeAuthPrefix}exec $executable ${command.map(shellQuote).join(' ')}';
    return BuildProcess(
      command: '/bin/sh',
      arguments: ['-c', shCmd],
      starter: starter,
    );
  }
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
