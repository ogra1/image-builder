import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../models/build_config.dart';
import '../models/model_assertion.dart';
import '../widgets/shared.dart';

/// Step 1 — pick the signed model assertion file.
class Step1ModelStep extends StatefulWidget {
  const Step1ModelStep({super.key, required this.config});

  final BuildConfig config;

  @override
  State<Step1ModelStep> createState() => _Step1ModelStepState();
}

class _Step1ModelStepState extends State<Step1ModelStep> {
  String? _error;
  late final TextEditingController _outCtrl;

  @override
  void initState() {
    super.initState();
    _outCtrl = TextEditingController(text: widget.config.outputDir);
  }

  @override
  void dispose() {
    _outCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDir() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select the output directory',
    );
    if (path == null || path.isEmpty) return; // cancelled
    _outCtrl.text = path;
    widget.config.outputDir = path;
    setState(() {});
  }

  Future<void> _pick() async {
    _error = null;
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select the signed model assertion',
      type: FileType.any,
      allowedExtensions: ['assert', 'txt', 'am', 'yaml', 'yml', 'model'],
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return; // cancelled
    final parsed = ModelAssertion.load(path);
    if (parsed.isClassic) {
      // Refuse: a classic model cannot be built with `ubuntu-image snap`.
      setState(() {
        _error =
            'This model assertion declares "classic: true". Classic models '
            'produce a non-snap image, which cannot be built with the '
            '`ubuntu-image snap` command this app drives. Choose a model '
            'without the classic flag.';
      });
      return;
    }
    widget.config.setModel(parsed);
    setState(() {
      if (!parsed.parsed) {
        _error =
            'Could not parse the model assertion. The file should contain '
            'assertion headers in "key: value" form.';
      }
    });
  }

  void _clear() {
    widget.config.setModel(null);
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.config.model;
    return StepBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeader(
            title: 'Model assertion',
            subtitle:
                'Start from the signed model assertion that describes the '
                'image: its owner, base, kernel and gadget snaps — and '
                'choose where the finished image is written.',
          ),
          const SizedBox(height: 24),
          if (model == null)
            // Full width so the card doesn't resize (and the page doesn't
            // jump) when a model assertion gets selected.
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(YaruIcons.key, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'No model assertion selected',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select the .model file for your image to '
                        'continue.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _pick,
                        icon: const Icon(YaruIcons.folder_open),
                        label: const Text('Choose model assertion…'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          model.parsed
                              ? YaruIcons.checkbox_checked
                              : YaruIcons.error_filled,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.path,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (model.parsed)
                                Text(
                                  'Model assertion · brand '
                                  '${model.brandId ?? "?"} · model '
                                  '${model.model ?? "?"}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _clear,
                          icon: const Icon(YaruIcons.trash),
                          label: const Text('Remove'),
                        ),
                      ],
                    ),
                    if (model.parsed) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _HeaderGrid(model: model),
                    ],
                  ],
                ),
              ),
            ),
            if (!model.parsed)
              const InfoBanner(
                icon: YaruIcons.error_filled,
                kind: BannerKind.error,
                message:
                    'Could not parse the selected file as a model '
                    'assertion. Double-check that it is a signed assertion '
                    'file (not a plain YAML model).',
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _pick,
              icon: const Icon(YaruIcons.refresh),
              label: const Text('Choose a different file…'),
            ),
          ],
          if (_error != null)
            InfoBanner(
              icon: YaruIcons.error_filled,
              kind: BannerKind.error,
              message: _error!,
            ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Output directory',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick where the final .img files are written, this '
                    'is mandatory',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _outCtrl,
                          onChanged: (v) => widget.config.outputDir = v.trim(),
                          decoration: const InputDecoration(
                            labelText: 'Directory',
                            hintText: 'e.g. /home/me/ubuntucore-images',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: _pickDir,
                        icon: const Icon(YaruIcons.folder_open, size: 18),
                        label: const Text('Browse…'),
                      ),
                    ],
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

class _HeaderGrid extends StatelessWidget {
  const _HeaderGrid({required this.model});

  final ModelAssertion model;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, String?>>[
      MapEntry('grade', model.grade),
      MapEntry('serial', model.serial),
      MapEntry('brand-id', model.brandId),
      MapEntry('model', model.model),
      MapEntry('base', model.base),
      MapEntry('kernel', model.kernel),
    ];
    return Wrap(
      spacing: 24,
      runSpacing: 10,
      children: [
        for (final e in entries)
          if (e.value != null && e.value!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.key,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  e.value!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
      ],
    );
  }
}
