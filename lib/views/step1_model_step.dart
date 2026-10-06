import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';

import '../models/build_config.dart';
import '../models/model_assertion.dart';
import '../widgets/shared.dart';
import '../widgets/toast.dart';

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
            // Compact single-row placeholder so it is NOT taller than the
            // card with model data in it (and the page doesn't jump when a
            // model assertion gets selected).
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Icon(YaruIcons.key, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No model assertion selected',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Select the .model file for your image to '
                            'continue.',
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
                    const SizedBox(width: 12),
                    // Flexible + Align: the Align fills the whole slice of
                    // free space the Flexible allocates and pins the
                    // button to its right end, so the button hugs the
                    // card's right edge (a bare FittedBox here would sit
                    // right after the text and leave the leftover space
                    // unused on the right). At narrow widths the
                    // FittedBox scales the button down instead of
                    // overflowing the row.
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: FilledButton.icon(
                            onPressed: _pick,
                            icon: const Icon(YaruIcons.folder_open, size: 18),
                            label: const Text('Choose model assertion…'),
                          ),
                        ),
                      ),
                    ),
                  ],
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
          const SizedBox(height: 24),
          _DedicatedStoreCard(config: widget.config),
        ],
      ),
    );
  }
}

/// Card for building against a dedicated snap store instead of the
/// global one.
///
/// The user exports their credentials once with
/// `snapcraft export-login --acls package_access <file>` and points this
/// card at that file. At build time the file's content is passed to the
/// build process as the `UBUNTU_STORE_AUTH` environment variable — the
/// file is read by the shell at launch and never opened, displayed or
/// copied by this app (the token never enters Dart memory).
class _DedicatedStoreCard extends StatefulWidget {
  const _DedicatedStoreCard({required this.config});

  final BuildConfig config;

  @override
  State<_DedicatedStoreCard> createState() => _DedicatedStoreCardState();
}

class _DedicatedStoreCardState extends State<_DedicatedStoreCard> {
  Future<void> _pickAuthFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select the dedicated store credential file',
      type: FileType.any,
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return; // cancelled
    widget.config.storeAuthFile = path;
    setState(() {});
  }

  void _clearAuthFile() {
    widget.config.storeAuthFile = '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final path = config.storeAuthFile.trim();
    final theme = Theme.of(context);
    final onVariant = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(YaruIcons.cloud, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Dedicated store',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'If your snaps live in a dedicated store, select the '
              'credential file that allows to download from there',
              style: theme.textTheme.bodySmall?.copyWith(color: onVariant),
            ),
            const SizedBox(height: 12),
            if (path.isEmpty)
              FilledButton.tonalIcon(
                onPressed: _pickAuthFile,
                icon: const Icon(YaruIcons.folder_open, size: 18),
                label: const Text('Select credential file…'),
              )
            else
              Row(
                children: [
                  const Icon(
                    YaruIcons.checkbox_checked,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          path,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Will be passed to the build as UBUNTU_STORE_AUTH',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearAuthFile,
                    icon: const Icon(YaruIcons.trash, size: 18),
                    label: const Text('Remove'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'How to export credentials for a dedicated store:',
              style: theme.textTheme.bodySmall?.copyWith(color: onVariant),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1B1F),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      YaruIcons.terminal,
                      size: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'snapcraft export-login --acls package_access store.auth',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Color(0xFFE6E1E5),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy command',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(YaruIcons.copy, size: 14, color: Colors.white70),
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(
                          text: 'snapcraft export-login --acls package_access store.auth',
                        ),
                      );
                      showToast(
                        context,
                        'Command copied to clipboard',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
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
