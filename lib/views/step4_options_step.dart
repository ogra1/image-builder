import '../widgets/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../models/build_config.dart';
import '../widgets/shared.dart';

/// Step 4 — general image build options.
class Step4OptionsStep extends StatefulWidget {
  const Step4OptionsStep({super.key, required this.config});

  final BuildConfig config;

  @override
  State<Step4OptionsStep> createState() => _Step4OptionsStepState();
}

class _Step4OptionsStepState extends State<Step4OptionsStep> {
  late final TextEditingController _workCtrl;
  late final TextEditingController _sizeCtrl;
  late final TextEditingController _channelCtrl;
  late final TextEditingController _diskInfoCtrl;
  late final TextEditingController _aaDirCtrl;
  late final TextEditingController _preseedKeyCtrl;
  late final TextEditingController _sysfsCtrl;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _workCtrl = TextEditingController(text: c.workdir);
    _sizeCtrl = TextEditingController(text: c.imageSize);
    _channelCtrl = TextEditingController(text: c.defaultChannel);
    _diskInfoCtrl = TextEditingController(text: c.diskInfoFile);
    _aaDirCtrl = TextEditingController(text: c.apparmorFeaturesDir);
    _preseedKeyCtrl = TextEditingController(text: c.preseedSignKey);
    _sysfsCtrl = TextEditingController(text: c.sysfsOverlay);
  }

  @override
  void dispose() {
    _workCtrl.dispose();
    _sizeCtrl.dispose();
    _channelCtrl.dispose();
    _diskInfoCtrl.dispose();
    _aaDirCtrl.dispose();
    _preseedKeyCtrl.dispose();
    _sysfsCtrl.dispose();
    super.dispose();
  }

  Future<String?> _pickFile({
    List<String> extensions = const ['assert', 'txt', 'yaml', 'yml', 'info'],
  }) async =>
      (await pickFile(extensions: extensions))?.path;

  /// Picks a directory via the native dialog. Sets [ctrl] and, crucially,
  /// the bound config field via [onPicked] — assigning [TextEditingController.text]
  /// does NOT fire the field's [TextField.onChanged], so the config must be
  /// updated here explicitly.
  Future<void> _pickDir(
    TextEditingController ctrl,
    ValueChanged<String> onPicked,
  ) async {
    final path = await pickDirectory();
    if (path != null) {
      ctrl.text = path;
      onPicked(path);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return StepBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeader(
            title: 'Build options',
            subtitle:
                'Fine-tune where and how the image is built. Everything here '
                'is optional — sensible defaults apply.',
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(text: 'Workdir & image size'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _workCtrl,
                          onChanged: (v) => c.workdir = v.trim(),
                          decoration: const InputDecoration(
                            labelText: 'Workdir',
                            hintText:
                                'Keep sources for resuming partial runs '
                                '(max 80 chars path)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => _pickDir(
                          _workCtrl,
                          (p) => c.workdir = p,
                        ),
                        icon: const Icon(YaruIcons.folder_open, size: 18),
                        label: const Text('Browse…'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sizeCtrl,
                          onChanged: (v) => c.imageSize = v.trim(),
                          decoration: const InputDecoration(
                            labelText: 'Suggested image size',
                            hintText: 'e.g. 4G or 600M',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<int?>(
                          initialValue: c.sectorSize,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sector size',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Default (512)'),
                            ),
                            const DropdownMenuItem(
                              value: 512,
                              child: Text('512 bytes'),
                            ),
                            const DropdownMenuItem(
                              value: 4096,
                              child: Text('4096 bytes (4K)'),
                            ),
                          ],
                          onChanged: (v) => setState(() => c.sectorSize = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _diskInfoCtrl,
                          onChanged: (v) => c.diskInfoFile = v.trim(),
                          decoration: const InputDecoration(
                            labelText: 'Disk info file',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final p =
                              await _pickFile(extensions: const ['info', 'txt']);
                          if (p != null) {
                            _diskInfoCtrl.text = p;
                            c.diskInfoFile = p;
                            setState(() {});
                          }
                        },
                        icon: const Icon(YaruIcons.folder_open, size: 18),
                        label: const Text('Browse…'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(text: 'Snap selection'),
                  TextField(
                    controller: _channelCtrl,
                    onChanged: (v) => c.defaultChannel = v.trim(),
                    decoration: const InputDecoration(
                      labelText: 'Default snap channel',
                      hintText: 'Applied to snaps without explicit channel',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(text: 'Preseeding & special images'),
                  _SwitchRow(
                    value: c.preseed,
                    // Turning preseed off also drops the key/overlay
                    // values: they are ignored by the builder unless the
                    // toggle is on, so keep the UI in sync with what
                    // will actually be built.
                    onChanged: (v) => setState(() {
                      c.preseed = v;
                      if (!v) {
                        _preseedKeyCtrl.clear();
                        c.preseedSignKey = '';
                        _sysfsCtrl.clear();
                        c.sysfsOverlay = '';
                      }
                    }),
                    title: 'Preseed the image',
                    subtitle: 'Ubuntu Core 20 only.',
                  ),
                  if (c.preseed) ...[
                    TextField(
                      controller: _preseedKeyCtrl,
                      onChanged: (v) => c.preseedSignKey = v.trim(),
                      decoration: const InputDecoration(
                        labelText: 'Preseed sign key',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _sysfsCtrl,
                      onChanged: (v) => c.sysfsOverlay = v.trim(),
                      decoration: const InputDecoration(
                        labelText: 'Sysfs overlay',
                        hintText: 'Directory bind-mounted into the chroot',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _aaDirCtrl,
                          onChanged: (v) => c.apparmorFeaturesDir = v.trim(),
                          decoration: const InputDecoration(
                            labelText: 'AppArmor features dir',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => _pickDir(
                          _aaDirCtrl,
                          (p) => c.apparmorFeaturesDir = p,
                        ),
                        icon: const Icon(YaruIcons.folder_open, size: 18),
                        label: const Text('Browse…'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    value: c.factoryImage,
                    onChanged: (v) => setState(() => c.factoryImage = v),
                    title: 'Factory image',
                    subtitle:
                        'Hint that the image is meant to boot in a device '
                        'factory.',
                  ),
                  _SwitchRow(
                    value: c.disableConsoleConf,
                    onChanged: (v) => setState(() => c.disableConsoleConf = v),
                    title: 'Disable console-conf',
                  ),
                  _SwitchRow(
                    value: c.allowSnapdKernelMismatch,
                    onChanged: (v) =>
                        setState(() => c.allowSnapdKernelMismatch = v),
                    title: 'Allow snapd/kernel mismatch',
                    subtitle:
                        'Allow a mismatch between snap-bootstrap in the '
                        'kernel and the snapd snap.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(text: 'Output & debugging'),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<Verbosity>(
                      initialValue: c.verbosity,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Output verbosity',
                      ),
                      items: Verbosity.values
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => c.verbosity = v ?? Verbosity.normal),
                    ),
                  ),
                  _SwitchRow(
                    value: c.dryRun,
                    onChanged: (v) => setState(() => c.dryRun = v),
                    title: 'Dry run',
                    subtitle:
                        'Only print the states that would be executed — '
                        'nothing is built.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
