import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';
import 'package:ubuntu_image_gui/views/step2_snaps_step.dart';
import 'package:ubuntu_image_gui/models/model_assertion.dart';

void main() {
  // Adding snaps is only allowed once a model assertion is set.
  BuildConfig dangerousConfig() => BuildConfig()
    ..model = ModelAssertion('/tmp/model.assert', {
      'model': 'test-model',
      'grade': 'dangerous',
    }, parsed: true);

  Widget harness(BuildConfig config) => MaterialApp(
    home: Scaffold(body: Step2SnapsStep(config: config)),
  );

  testWidgets('channel field is store-only: hidden for local .snap files', (
    tester,
  ) async {
    await tester.pumpWidget(harness(dangerousConfig()));
    await tester.pumpAndSettle();

    // From-store mode: the channel field is offered.
    await tester.tap(find.text('Add from store'));
    await tester.pumpAndSettle();
    expect(find.text('Channel (optional)'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Local mode: no channel field (channels are a store concept).
    await tester.tap(find.text('Add local .snap'));
    await tester.pumpAndSettle();
    expect(find.text('.snap file'), findsOneWidget);
    expect(find.text('Channel (optional)'), findsNothing);
  });
}
