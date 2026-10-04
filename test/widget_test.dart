import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';

void main() {
  test('buildCommand assembles expected arguments', () {
    final c = BuildConfig()
      ..snaps.add(ExtraSnap.store(name: 'firefox', channel: 'stable'))
      ..snaps.add(
        ExtraSnap.local(name: 'foo', localPath: '/tmp/foo.snap')
          ..components.add(SnapComponent.store(name: 'extra-data')),
      )
      ..validationSets.add(ValidationSet(name: 'core24', sequence: '3'))
      ..assertionFiles.add('/tmp/system-users.assert')
      ..outputDir = '/out'
      ..imageSize = '4G'
      ..sectorSize = 4096
      ..preseed = true
      ..verbosity = Verbosity.verbose;
    final args = c.buildCommand();
    expect(
      args,
      containsAllInOrder([
        '--verbose',
        '--output-dir',
        '/out',
        '--image-size',
        '4G',
        '--sector-size',
        '4096',
        '--preseed',
        '--snap',
        'firefox=stable',
        '--snap',
        '/tmp/foo.snap',
        '--comp',
        'foo+extra-data',
        '--sequence',
        'core24:3',
        '--assertion',
        '/tmp/system-users.assert',
      ]),
    );
  });

  test('snapCommand includes the mandatory snap subcommand', () {
    final c = BuildConfig()..outputDir = '/out';
    final cmd = c.snapCommand;
    expect(
      cmd.first,
      'snap',
      reason: 'first arg must be the "snap" subcommand',
    );
    expect(cmd, containsAllInOrder(['--output-dir', '/out']));
  });
  test('verbosity levels are mutually exclusive (single flag)', () {
    final c = BuildConfig();
    c.verbosity = Verbosity.quiet;
    expect(c.buildCommand(), contains('--quiet'));
    expect(c.buildCommand(), isNot(contains('--verbose')));
    expect(c.buildCommand(), isNot(contains('--debug')));

    c.verbosity = Verbosity.debug;
    final args = c.buildCommand();
    expect(args, contains('--debug'));
    expect(
      args.where(
        (f) =>
            f.startsWith('--quiet') ||
            f.startsWith('--verbose') ||
            f.startsWith('--debug'),
      ),
      ['--debug'],
    );

    c.verbosity = Verbosity.normal;
    final plain = c.buildCommand();
    expect(plain, isNot(contains('--quiet')));
    expect(plain, isNot(contains('--verbose')));
    expect(plain, isNot(contains('--debug')));
  });
}
