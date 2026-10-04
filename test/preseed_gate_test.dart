import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';

void main() {
  test('preseed options are ignored unless the preseed toggle is on', () {
    final c = BuildConfig()
      ..preseedSignKey = '/root/key'
      ..sysfsOverlay = '/opt/sysfs';

    // Toggle off: the values must not leak into the command.
    final off = c.buildCommand();
    expect(off, isNot(contains('--preseed')));
    expect(off, isNot(contains('--preseed-sign-key')));
    expect(off, isNot(contains('--sysfs-overlay')));

    // Toggle on: everything is passed through.
    c.preseed = true;
    final on = c.buildCommand();
    expect(
      on,
      containsAllInOrder([
        '--preseed',
        '--preseed-sign-key',
        '/root/key',
        '--sysfs-overlay',
        '/opt/sysfs',
      ]),
    );
  });
}
