import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../models/build_config.dart';
import '../widgets/shared.dart';
import 'step1_model_step.dart';
import 'step2_snaps_step.dart';
import 'step3_assertions_step.dart';
import 'step4_options_step.dart';
import 'step5_build_step.dart';

class _StepDef {
  const _StepDef(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

const _steps = <_StepDef>[
  _StepDef('Model', 'Model assertion', YaruIcons.key_filled),
  _StepDef('Snaps', 'Additional snaps', YaruIcons.package),
  _StepDef('Assertions', 'Validations & assertions', YaruIcons.shield_filled),
  _StepDef('Options', 'Build options', YaruIcons.gear),
  _StepDef('Build', 'Build the image', YaruIcons.terminal_filled),
];

/// Short marker shown in the sidebar header, e.g. "Image builder (v30)".
const kVersionShort = 'v1.0.0';

/// Wizard shell: a collapsible step sidebar (master pane) on the left and
/// the content of the selected step (detail pane) on the right.
class WizardPage extends StatefulWidget {
  const WizardPage({super.key, required this.config});

  final BuildConfig config;

  @override
  State<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends State<WizardPage> {
  int _current = 0;
  bool _sidebarExpanded = true;

  /// True while a build is running in step 5. While set, the other step
  /// tiles are locked (navigating away would unmount the build step and
  /// kill the subprocess), so navigation is disabled until it finishes.
  bool _buildRunning = false;

  /// Startup check of the `ubuntu-image` tool; `null` = not yet run.
  ToolCheck? _toolCheck;

  Future<void> _checkTool() async {
    final check = await widget.config.toolChecker(widget.config.executable);
    if (!mounted) return;
    setState(() => _toolCheck = check);
  }

  @override
  void initState() {
    super.initState();
    // Rebuild the shell (sidebar gating, footer status) whenever the
    // configuration changes, e.g. a model assertion was selected.
    widget.config.addListener(_onConfigChanged);
    // Verify the ubuntu-image tool is available before the user starts
    // clicking through the wizard.
    _checkTool();
  }

  @override
  void didUpdateWidget(covariant WizardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Defensive: if the config instance ever gets swapped out (e.g. a
    // parent re-created it), re-attach the listener so the shell keeps
    // reacting to configuration changes.
    if (!identical(widget.config, oldWidget.config)) {
      oldWidget.config.removeListener(_onConfigChanged);
      widget.config.addListener(_onConfigChanged);
    }
  }

  @override
  void dispose() {
    widget.config.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (mounted) setState(() {});
  }

  bool get _canBuild =>
      widget.config.model != null && widget.config.outputDir.isNotEmpty;

  /// Why the Build step is currently gated, for the disabled tile's
  /// tooltip and the sidebar footer.
  String get _buildGateMessage {
    final missing = <String>[];
    if (widget.config.model == null) missing.add('a model assertion');
    if (widget.config.outputDir.isEmpty) missing.add('an output directory');
    if (missing.isEmpty) return '';
    return 'Select ${missing.join(' and ')}';
  }

  void _goTo(int index) {
    if (_buildRunning) return; // navigation locked while a build runs
    setState(() => _current = index);
  }

  /// Called by the Build step when a build starts/finishes. Drives the
  /// navigation lock and the sidebar footer status.
  void _onBuildRunning(bool running) {
    if (!mounted || _buildRunning == running) return;
    setState(() => _buildRunning = running);
  }

  void _toggleSidebar() => setState(() => _sidebarExpanded = !_sidebarExpanded);

  /// Shown at the top of the detail pane while the `ubuntu-image` tool
  /// cannot be used, so the problem is visible on every step.
  Widget? _toolBanner(BuildContext context) {
    final check = _toolCheck;
    if (check == null) return null;
    if (check.ok) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: InfoBanner(
        kind: BannerKind.error,
        icon: YaruIcons.error_filled,
        message:
            'ubuntu-image is not available: ${check.hint ?? 'unknown error'}',
        trailing: TextButton.icon(
          onPressed: _checkTool,
          icon: const Icon(YaruIcons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const YaruWindowTitleBar(title: Text('Image Builder')),
      ),
      body: Row(
        // Stretch: without this, short pages size to their content and the
        // Row's default center alignment vertically centers the whole block.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: _sidebarExpanded ? 300 : 64,
            // No fill: the sidebar uses the standard app background; only
            // the right-edge divider separates it from the detail pane.
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              children: [
                // Header / collapse toggle
                InkWell(
                  onTap: _toggleSidebar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _sidebarExpanded ? YaruIcons.sidebar : YaruIcons.menu,
                          size: 18,
                        ),
                        if (_sidebarExpanded) ...[
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Image builder ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: '($kVersionShort)'),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            _sidebarExpanded
                                ? YaruIcons.arrow_left
                                : YaruIcons.arrow_right,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    itemCount: _steps.length,
                    itemBuilder: (context, index) => _SidebarTile(
                      def: _steps[index],
                      selected: index == _current,
                      reachable: _canBuild || index != 4,
                      // A build can only be running from the Build
                      // page itself, so while it runs every other tile
                      // is locked.
                      locked: _buildRunning && index != 4,
                      gateMessage: _buildGateMessage,
                      expanded: _sidebarExpanded,
                      onTap:
                          (_canBuild || index != 4) &&
                              !(_buildRunning && index != 4)
                          ? () => _goTo(index)
                          : null,
                    ),
                  ),
                ),
                if (_sidebarExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        if (_buildRunning)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _canBuild
                                ? YaruIcons.checkbox_checked
                                : YaruIcons.question,
                            size: 16,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _buildRunning
                                ? 'Building…'
                                : _canBuild
                                ? 'Ready to build'
                                : _buildGateMessage,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Detail pane
          Expanded(
            child: Builder(
              builder: (context) {
                final banner = _toolBanner(context);
                return Column(
                  children: [
                    if (_toolCheck == null)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ?banner,
                    Expanded(child: _StepBody(index: _current)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.def,
    required this.selected,
    required this.reachable,
    required this.expanded,
    required this.locked,
    required this.gateMessage,
    this.onTap,
  });

  final _StepDef def;
  final bool selected;
  final bool reachable;
  final bool expanded;

  /// Navigation lock while a build runs (the tile is shown, but cannot
  /// be activated).
  final bool locked;

  /// Shown as the tooltip while the Build step is gated.
  final String gateMessage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Selection: a slight accent tint (not a full container color) plus
    // an accent-colored icon — a subtle, unambiguous highlight without
    // the extra visual weight of an outline.
    final highlight = scheme.primary.withValues(alpha: 0.12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? highlight : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          // Match the Material's corner radius: without this the
          // hover/press highlight is a square (ink features ignore the
          // Material's own borderRadius and default to a rectangle).
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Tooltip(
            message: locked
                ? 'Build in progress — wait for it to finish'
                : !reachable
                ? gateMessage
                : (expanded ? '' : def.title),
            waitDuration: const Duration(milliseconds: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    def.icon,
                    size: 20,
                    color: selected
                        ? scheme.primary
                        : (locked
                              ? scheme.outline
                              : (reachable ? null : scheme.outline)),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            def.title,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            def.subtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The content of the currently selected step.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    // The wizard shell owns the config and the build-running lock; pull
    // them from the wizard's state rather than threading them through.
    final wizard = context.findAncestorStateOfType<_WizardPageState>()!;
    final config = wizard.widget.config;
    switch (index) {
      case 0:
        return Step1ModelStep(config: config);
      case 1:
        return Step2SnapsStep(config: config);
      case 2:
        return Step3AssertionsStep(config: config);
      case 3:
        return Step4OptionsStep(config: config);
      case 4:
        return Step5BuildStep(
          config: config,
          canBuild: wizard._canBuild,
          onBuildRunning: wizard._onBuildRunning,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
