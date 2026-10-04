import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../models/build_config.dart';
import '../widgets/shared.dart';

/// Step 2 — additional snaps (store or local) incl. their components.
class Step2SnapsStep extends StatefulWidget {
  const Step2SnapsStep({super.key, required this.config});

  final BuildConfig config;

  @override
  State<Step2SnapsStep> createState() => _Step2SnapsStepState();
}

class _Step2SnapsStepState extends State<Step2SnapsStep> {
  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final model = config.model;
    final dangerous = model?.isDangerous ?? false;
    // Adding snaps only makes sense once a model is chosen AND that
    // model is of "dangerous" grade, so the buttons are inactive until
    // both hold.
    final addingAllowed = model != null && dangerous;
    final noAddsReason = model == null
        ? 'Select a model assertion first — it determines which '
              'additional snaps are allowed.'
        : 'Only models of grade "dangerous" allow additional snaps — the '
              'current model is of grade "${model.grade}".';

    return StepBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeader(
            title: 'Additional snaps',
            subtitle:
                'Include extra snaps in the image — either local .snap files '
                'or snaps (and their components) from the store.',
          ),
          const SizedBox(height: 16),
          if (model == null)
            const InfoBanner(
              icon: YaruIcons.key,
              kind: BannerKind.info,
              message:
                  'Select a model assertion first — it determines '
                  'if extra snaps are allowed.',
            )
          else if (!dangerous)
            InfoBanner(
              icon: YaruIcons.warning_filled,
              kind: BannerKind.warning,
              message:
                  'The model is of grade "${model.grade}". Only models of '
                  'grade "dangerous" allow additional and local snaps.',
            )
          else
            const InfoBanner(
              icon: YaruIcons.checkbox_checked,
              kind: BannerKind.info,
              message:
                  'Model grade is "dangerous" — additional and local snaps '
                  'are allowed.',
            ),
          SectionTitle(
            text: 'Snaps',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: addingAllowed ? '' : noAddsReason,
                  waitDuration: const Duration(milliseconds: 400),
                  child: FilledButton.tonalIcon(
                    onPressed: addingAllowed
                        ? () async {
                            await _AddSnapDialog.show(
                              context,
                              config,
                              storeFirst: true,
                            );
                            if (mounted) setState(() {});
                          }
                        : null,
                    icon: const Icon(YaruIcons.download, size: 18),
                    label: const Text('Add from store'),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: addingAllowed ? '' : noAddsReason,
                  waitDuration: const Duration(milliseconds: 400),
                  child: FilledButton.icon(
                    onPressed: addingAllowed
                        ? () async {
                            await _AddSnapDialog.show(
                              context,
                              config,
                              storeFirst: false,
                            );
                            if (mounted) setState(() {});
                          }
                        : null,
                    icon: const Icon(YaruIcons.folder_open, size: 18),
                    label: const Text('Add local .snap'),
                  ),
                ),
              ],
            ),
          ),
          if (config.snaps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'No additional snaps selected.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            for (final snap in config.snaps)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SnapCard(
                  snap: snap,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => config.snaps.remove(snap)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One card per snap, with its channel, components and actions.
class _SnapCard extends StatelessWidget {
  const _SnapCard({
    required this.snap,
    required this.onChanged,
    required this.onRemove,
  });

  final ExtraSnap snap;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  snap.isLocal ? YaruIcons.disk : YaruIcons.package,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snap.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        snap.subtitle,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      _AddComponentDialog.show(context, snap, onChanged),
                  icon: const Icon(YaruIcons.plus, size: 16),
                  label: const Text('Component'),
                ),
                IconButton(
                  tooltip: 'Remove snap',
                  icon: const Icon(YaruIcons.trash, size: 18),
                  color: scheme.error,
                  onPressed: onRemove,
                ),
              ],
            ),
            if (snap.components.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final comp in snap.components)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4),
                  child: Row(
                    children: [
                      Icon(
                        YaruIcons.puzzle_piece,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          comp.label +
                              (comp.channel.isEmpty
                                  ? ''
                                  : '  (${comp.channel})'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove component',
                        icon: const Icon(YaruIcons.minus, size: 14),
                        iconSize: 14,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          snap.components.remove(comp);
                          onChanged();
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog to add a snap from the store or from a local .snap file.
class _AddSnapDialog extends StatefulWidget {
  const _AddSnapDialog({required this.config, required this.storeFirst});

  final BuildConfig config;
  final bool storeFirst;

  static Future<void> show(
    BuildContext context,
    BuildConfig config, {
    required bool storeFirst,
  }) => showDialog<void>(
    context: context,
    builder: (_) => _AddSnapDialog(config: config, storeFirst: storeFirst),
  );

  @override
  State<_AddSnapDialog> createState() => _AddSnapDialogState();
}

class _AddSnapDialogState extends State<_AddSnapDialog> {
  late bool _fromStore;
  final _nameCtrl = TextEditingController();
  final _channelCtrl = TextEditingController();
  final _localCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fromStore = widget.storeFirst;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _channelCtrl.dispose();
    _localCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _fromStore
      ? _nameCtrl.text.trim().isNotEmpty
      : _localCtrl.text.trim().isNotEmpty;

  void _accept() {
    if (!_valid) return;
    if (_fromStore) {
      widget.config.snaps.add(
        ExtraSnap.store(
          name: _nameCtrl.text.trim(),
          channel: _channelCtrl.text.trim(),
        ),
      );
    } else {
      final path = _localCtrl.text.trim();
      widget.config.snaps.add(
        ExtraSnap.local(name: path.split('/').last, localPath: path),
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickLocal() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select a local .snap file',
      type: FileType.any,
      allowedExtensions: ['snap'],
    );
    final path = result?.files.single.path;
    if (path != null && path.isNotEmpty) {
      setState(() => _localCtrl.text = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add snap'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('From store'),
                  icon: Icon(YaruIcons.download),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Local .snap file'),
                  icon: Icon(YaruIcons.disk),
                ),
              ],
              selected: {_fromStore},
              onSelectionChanged: (sel) =>
                  setState(() => _fromStore = sel.first),
            ),
            const SizedBox(height: 16),
            if (_fromStore)
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _accept(),
                decoration: const InputDecoration(
                  labelText: 'Snap name',
                  hintText: 'e.g. firefox',
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _localCtrl,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _accept(),
                      decoration: const InputDecoration(
                        labelText: '.snap file',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _pickLocal,
                    icon: const Icon(YaruIcons.folder_open),
                    label: const Text('Browse…'),
                  ),
                ],
              ),
            if (_fromStore) ...[
              const SizedBox(height: 8),
              // Channels are a store concept: local .snap files are
              // installed as-is, so the field is hidden in that mode.
              TextField(
                controller: _channelCtrl,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _accept(),
                decoration: const InputDecoration(
                  labelText: 'Channel (optional)',
                  hintText: 'e.g. latest/stable, 2/candidate',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _accept : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Dialog to add a component to an existing snap.
class _AddComponentDialog extends StatefulWidget {
  const _AddComponentDialog({required this.parent, required this.onChanged});

  final ExtraSnap parent;
  final VoidCallback onChanged;

  static Future<void> show(
    BuildContext context,
    ExtraSnap parent,
    VoidCallback onChanged,
  ) => showDialog<void>(
    context: context,
    builder: (_) => _AddComponentDialog(parent: parent, onChanged: onChanged),
  );

  @override
  State<_AddComponentDialog> createState() => _AddComponentDialogState();
}

class _AddComponentDialogState extends State<_AddComponentDialog> {
  bool _fromStore = true;
  final _nameCtrl = TextEditingController();
  final _channelCtrl = TextEditingController();
  final _localCtrl = TextEditingController();

  bool get _valid => _fromStore
      ? _nameCtrl.text.trim().isNotEmpty
      : _localCtrl.text.trim().isNotEmpty;

  void _accept() {
    if (!_valid) return;
    if (_fromStore) {
      widget.parent.components.add(
        SnapComponent.store(
          name: _nameCtrl.text.trim(),
          channel: _channelCtrl.text.trim(),
        ),
      );
    } else {
      widget.parent.components.add(
        SnapComponent.local(
          snapName: widget.parent.name,
          localPath: _localCtrl.text.trim(),
        ),
      );
    }
    widget.onChanged();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _channelCtrl.dispose();
    _localCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocal() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select a local component file',
      type: FileType.any,
    );
    final path = result?.files.single.path;
    if (path != null && path.isNotEmpty) {
      setState(() => _localCtrl.text = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Add component — ${widget.parent.displayName}',
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Store component'),
                  icon: Icon(YaruIcons.download),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Local component file'),
                  icon: Icon(YaruIcons.disk),
                ),
              ],
              selected: {_fromStore},
              onSelectionChanged: (sel) =>
                  setState(() => _fromStore = sel.first),
            ),
            const SizedBox(height: 16),
            if (_fromStore)
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _accept(),
                decoration: const InputDecoration(
                  labelText: 'Component name',
                  hintText: 'e.g. extra-data',
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _localCtrl,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _accept(),
                      decoration: const InputDecoration(
                        labelText: 'Component file',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _pickLocal,
                    icon: const Icon(YaruIcons.folder_open),
                    label: const Text('Browse…'),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _channelCtrl,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _accept(),
              decoration: const InputDecoration(
                labelText: 'Channel (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _accept : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
