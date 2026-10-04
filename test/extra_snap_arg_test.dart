import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';

void main() {
  test('local snap args carry no channel suffix', () {
    final local = ExtraSnap.local(name: 'foo', localPath: '/tmp/foo.snap');
    expect(local.snapArg, '/tmp/foo.snap');
    expect(local.subtitle, 'Local snap file');
    expect(local.channel, isEmpty);
  });

  test('store snap args keep the channel suffix', () {
    expect(ExtraSnap.store(name: 'firefox').snapArg, 'firefox');
    expect(
      ExtraSnap.store(name: 'firefox', channel: 'latest/candidate').snapArg,
      'firefox=latest/candidate',
    );
  });
}
