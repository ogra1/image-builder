import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../models/build_config.dart';
import '../widgets/shared.dart';

/// Step 3 — validation sets and additional assertion files.
class Step3AssertionsStep extends StatefulWidget {
  const Step3AssertionsStep({super.key, required this.config});

  final BuildConfig config;

  @override
  State<Step3AssertionsStep> createState() => _Step3AssertionsStepState();
}

class _Step3AssertionsStepState extends State<Step3AssertionsStep> {
  final _nameCtrl = TextEditingController();
  final _seqCtrl = TextEditingController();
  @override
  void dispose() {
    _nameCtrl.dispose();
    _seqCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAssertionFiles() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select assertion files',
      type: FileType.any,
      allowedExtensions: ['assert', 'txt', 'am', 'yaml', 'yml'],
      allowMultiple: true,
    );
    final paths =
        result?.files.map((f) => f.path).whereType<String>().toList() ??
        <String>[];
    if (paths.isEmpty) return;
    final config = widget.config;
    setState(() {
      for (final p in paths) {
        if (!config.assertionFiles.contains(p)) config.assertionFiles.add(p);
      }
    });
  }

  void _addValidationSet() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.config.validationSets.add(
      ValidationSet(name: name, sequence: _seqCtrl.text.trim()),
    );
    _nameCtrl.clear();
    _seqCtrl.clear();
    setState(() {});
  }

  void _editValidationSet(ValidationSet vs) {
    final nameCtrl = TextEditingController(text: vs.name);
    final seqCtrl = TextEditingController(text: vs.sequence);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit validation set'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: seqCtrl,
              decoration: const InputDecoration(
                labelText: 'Sequence (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              vs.name = nameCtrl.text.trim();
              vs.sequence = seqCtrl.text.trim();
              Navigator.of(dialogContext).pop();
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return StepBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeader(
            title: 'Validations & assertions',
            subtitle:
                'Optionally pin validation sets to a specific sequence and '
                'include additional assertion files.',
          ),
          const SizedBox(height: 24),

          // -- Validation sets -------------------------------------------
          SectionTitle(text: 'Validation sets'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  // Rebuild on every keystroke so the Add button's
                  // enabled state (keyed off the name) tracks the
                  // input live.
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'short or account-id/name form',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _seqCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Sequence (optional)',
                    hintText: 'e.g. 42',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                // Only the name is mandatory: a validation set is a
                // valid `--sequence` value on its own (short name or
                // account-id/name); the sequence number is optional.
                onPressed: _nameCtrl.text.trim().isEmpty
                    ? null
                    : _addValidationSet,
                icon: const Icon(YaruIcons.plus, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              initialValue: config.validation,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Validations'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Default (enforce)'),
                ),
                const DropdownMenuItem(
                  value: 'enforce',
                  child: Text('Enforce'),
                ),
                const DropdownMenuItem(value: 'ignore', child: Text('Ignore')),
              ],
              onChanged: (v) => setState(() => config.validation = v),
            ),
          ),
          const SizedBox(height: 12),
          if (config.validationSets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'No validation sets pinned.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final vs in config.validationSets)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: const Icon(YaruIcons.shield_filled, size: 20),
                    title: Text(
                      vs.sequence.isEmpty
                          ? vs.name
                          : '${vs.name}:${vs.sequence}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(YaruIcons.text_editor, size: 18),
                          onPressed: () => _editValidationSet(vs),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(YaruIcons.trash, size: 18),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () =>
                              setState(() => config.validationSets.remove(vs)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

          const SizedBox(height: 16),

          // -- Extra assertions ------------------------------------------
          SectionTitle(
            text: 'Additional assertion files',
            trailing: FilledButton.tonalIcon(
              onPressed: _pickAssertionFiles,
              icon: const Icon(YaruIcons.plus, size: 18),
              label: const Text('Add assertion file…'),
            ),
          ),
          if (config.assertionFiles.isEmpty)
            Text(
              'No extra assertion files selected (e.g. system-user '
              'assertions).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final f in config.assertionFiles)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: const Icon(YaruIcons.document, size: 20),
                    title: Text(
                      f,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(YaruIcons.trash, size: 18),
                      color: Theme.of(context).colorScheme.error,
                      onPressed: () =>
                          setState(() => config.assertionFiles.remove(f)),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
