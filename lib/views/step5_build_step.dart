import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';

import '../models/build_config.dart';
import '../widgets/shared.dart';

/// Step 5 — run `ubuntu-image snap` with the selected options and show
/// its live stdout/stderr output.
class Step5BuildStep extends StatefulWidget {
  const Step5BuildStep({
    super.key,
    required this.config,
    required this.canBuild,
    required this.onBuildRunning,
  });

  final BuildConfig config;
  final bool canBuild;

  /// Notified with `true` when a build starts and `false` when it
  /// finishes (or the step is disposed). The wizard shell uses this to
  /// lock navigation for the duration of the build.
  final ValueChanged<bool> onBuildRunning;

  @override
  State<Step5BuildStep> createState() => _Step5BuildStepState();
}

class _Step5BuildStepState extends State<Step5BuildStep> {
  BuildProcess? _proc;
  bool _running = false;
  bool _cancelled = false;
  int? _exitCode;

  final StringBuffer _output = StringBuffer();
  Timer? _uiTimer;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _proc?.kill(ProcessSignal.sigterm);
    _uiTimer?.cancel();
    _scroll.dispose();
    // Defensive: never leave the navigation lock stuck.
    widget.onBuildRunning(false);
    super.dispose();
  }

  /// A build needs both a model assertion and an output directory
  /// (both chosen on the Model page). The wizard already gates the step;
  /// this keeps the button/status defensive and self-explanatory.
  bool get _ready =>
      widget.config.model != null && widget.config.outputDir.isNotEmpty;

  String get _gateMessage {
    final missing = <String>[];
    if (widget.config.model == null) missing.add('a model assertion');
    if (widget.config.outputDir.isEmpty) missing.add('an output directory');
    return 'Select ${missing.join(' and ')} before building.';
  }

  void _append(String data) {
    _output.write(data);
    if (_uiTimer?.isActive ?? false) return;
    _uiTimer = Timer(const Duration(milliseconds: 100), () {
      _uiTimer = null;
      if (!mounted) return;
      setState(() {});
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _appendLine(String line) => _append('$line\n');

  Future<void> _build() async {
    final args = widget.config.buildCommand();
    if (args.isEmpty || _running) return;
    // Defensive re-check: if the tool vanished since startup (e.g. the
    // snap was removed), say so in the console instead of failing to
    // start the process.
    final check = await widget.config.toolChecker(widget.config.executable);
    if (!check.ok) {
      _appendLine(
        'Cannot build: ${check.hint ?? 'ubuntu-image is not available.'}',
      );
      return;
    }
    _exitCode = null;
    _cancelled = false;
    _output.clear();
    setState(() => _running = true);
    widget.onBuildRunning(true);
    final fullArgs = widget.config.snapCommand;
    _appendLine('\$ ${widget.config.executable} ${fullArgs.join(' ')}\n');
    try {
      final proc = await widget.config.processStarter(
        widget.config.executable,
        fullArgs,
      );
      _proc = proc;
      proc.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_append);
      proc.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_append);
      final code = await proc.exitCode;
      _exitCode = code;
      _proc = null;
      if (_cancelled) {
        _appendLine('\n[build cancelled by user]');
      } else if (code == 0) {
        _appendLine('\n✔ Build finished successfully.');
      } else {
        _appendLine('\n✖ Build FAILED with exit code $code.');
      }
    } on ProcessException catch (e) {
      _exitCode = -1;
      _appendLine(
        'Failed to start ${widget.config.executable}: ${e.message}\n'
        'Is the "ubuntu-image" snap installed?\n',
      );
    }
    if (mounted) setState(() => _running = false);
    widget.onBuildRunning(false);
  }

  Future<void> _stop() async {
    _cancelled = true;
    _proc?.kill(ProcessSignal.sigterm);
  }

  void _copyOutput() {
    Clipboard.setData(ClipboardData(text: _output.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return SingleChildScrollView(
      controller: null,
      // Top-aligned and full pane width (a maxWidth ConstrainedBox would
      // be clamped away by the scroll view's tight width).
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeader(
            title: 'Build',
            subtitle:
                'Review the configuration and build the Ubuntu Core image.',
          ),
          const SizedBox(height: 16),
          if (!_ready)
            InfoBanner(
              icon: YaruIcons.key,
              kind: BannerKind.warning,
              message: _gateMessage,
            )
          else if (c.snaps.isNotEmpty && !c.model!.isDangerous)
            InfoBanner(
              icon: YaruIcons.warning_filled,
              kind: BannerKind.warning,
              message:
                  '${c.snaps.length} additional snap(s) selected, but '
                  'the model is of grade "${c.model!.grade}". The build '
                  'is expected to fail — only grade "dangerous" allows '
                  'additional and local snaps.',
            ),
          _Summary(config: c),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_running)
                FilledButton.icon(
                  onPressed: _stop,
                  icon: const Icon(YaruIcons.stop, size: 18),
                  label: const Text('Stop build'),
                )
              else
                FilledButton.icon(
                  onPressed: _ready ? _build : null,
                  icon: const Icon(YaruIcons.media_play, size: 18),
                  label: const Text('Build image'),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatusRow(
                  running: _running,
                  cancelled: _cancelled,
                  exitCode: _exitCode,
                  ready: _ready,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Console(
            output: _output.toString(),
            scroll: _scroll,
            onCopy: _copyOutput,
            onClear: () {
              _output.clear();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

/// Compact summary chips of the current configuration.
class _Summary extends StatelessWidget {
  const _Summary({required this.config});

  final BuildConfig config;

  @override
  Widget build(BuildContext context) {
    final c = config;
    final chips = <String>[
      'Model: ${c.model == null ? '—' : p.basename(c.model!.path)}',
      'Snaps: ${c.snaps.length}',
      'Validation sets: ${c.validationSets.length}',
      'Assertion files: ${c.assertionFiles.length}',
      if (c.outputDir.isNotEmpty) 'Output: ${c.outputDir}',
      if (c.imageSize.isNotEmpty) 'Size: ${c.imageSize}',
      if (c.sectorSize != null) 'Sector: ${c.sectorSize}',
      if (c.defaultChannel.isNotEmpty) 'Channel: ${c.defaultChannel}',
      if (c.preseed) 'Preseed',
      if (c.factoryImage) 'Factory',
      if (c.disableConsoleConf) 'No console-conf',
      if (c.dryRun) 'Dry run',
      if (c.verbosity == Verbosity.verbose) 'Verbose',
      if (c.verbosity == Verbosity.quiet) 'Quiet',
      if (c.verbosity == Verbosity.debug) 'Debug',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          Chip(
            label: Text(chip, style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.running,
    required this.cancelled,
    required this.exitCode,
    required this.ready,
  });

  final bool running;
  final bool cancelled;
  final int? exitCode;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late IconData icon;
    late String text;
    late Color color;
    if (running) {
      icon = YaruIcons.task_important_filled;
      text = 'Building… watch the console below.';
      color = scheme.primary;
    } else if (cancelled) {
      icon = YaruIcons.warning_filled;
      text = 'Build was cancelled.';
      color = scheme.onSurfaceVariant;
    } else if (exitCode == 0) {
      icon = YaruIcons.checkbox_checked;
      text = 'Build finished successfully.';
      color = scheme.primary;
    } else if (exitCode != null) {
      icon = YaruIcons.error_filled;
      text = 'Build failed (exit code $exitCode).';
      color = scheme.error;
    } else if (ready) {
      icon = YaruIcons.question_filled;
      text = 'Ready to build.';
      color = scheme.onSurfaceVariant;
    } else {
      icon = YaruIcons.warning_filled;
      text = 'Select a model assertion and an output directory first.';
      color = scheme.error;
    }
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Console extends StatelessWidget {
  const _Console({
    required this.output,
    required this.scroll,
    required this.onCopy,
    required this.onClear,
  });

  final String output;
  final ScrollController scroll;
  final VoidCallback onCopy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    // The parent page hands this widget the full detail-pane width; the
    // inner rows are stretched so the header bar and the text area both
    // span edge-to-edge, like a real terminal.
    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2930),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                const Icon(YaruIcons.terminal, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Console',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy output',
                  icon: const Icon(YaruIcons.copy, size: 14),
                  color: Colors.white70,
                  visualDensity: VisualDensity.compact,
                  onPressed: onCopy,
                ),
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(YaruIcons.clear_night, size: 14),
                  color: Colors.white70,
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: SelectableText(
                output.isEmpty
                    ? 'Output of the build will appear here\u2026'
                    : output,
                // Always the full width of the console, terminal-style
                // (full-width selection, no content-sized inner box).
                textWidthBasis: TextWidthBasis.parent,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFFE6E1E5),
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
