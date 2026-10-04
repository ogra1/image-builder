import 'dart:io';

/// A parsed model assertion file (assertion header format: `key: value`
/// lines, a subset of YAML-like syntax).
class ModelAssertion {
  ModelAssertion(this.path, this.headers, {required this.parsed});

  /// Absolute path to the assertion file on disk.
  final String path;

  /// Parsed headers (first occurrence of each key wins).
  final Map<String, String> headers;

  /// Whether at least one header line could be parsed.
  final bool parsed;

  /// Reads and parses the file at [path]. Never throws — parse failures
  /// result in [parsed] being `false` and empty [headers].
  static ModelAssertion load(String path) {
    final headers = <String, String>{};
    try {
      final lines = File(path).readAsLinesSync();
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final i = line.indexOf(':');
        if (i <= 0) continue;
        final key = line.substring(0, i).trim();
        var value = line.substring(i + 1).trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1);
        }
        headers.putIfAbsent(key, () => value);
      }
    } catch (_) {
      // Unreadable file — surfaced via [parsed] == false.
    }
    return ModelAssertion(path, headers, parsed: headers.isNotEmpty);
  }

  String? get grade => headers['grade'];
  String? get serial => headers['serial'];
  String? get brandId => headers['brand-id'];
  String? get model => headers['model'];
  String? get base => headers['base'];
  String? get kernel => headers['kernel'];
  String? get classic => headers['classic'];

  /// Only models of grade `dangerous` may include additional or local
  /// snaps.
  bool get isDangerous => (grade ?? '').trim() == 'dangerous';

  /// `classic: true` models build a classic (non-snap) image, which the
  /// `ubuntu-image snap` command cannot produce. The app builds via
  /// `ubuntu-image snap`, so such models are refused at import time.
  bool get isClassic => (classic ?? '').trim().toLowerCase() == 'true';
}
