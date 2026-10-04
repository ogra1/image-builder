import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'test_tools.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_image_gui/models/build_config.dart';
import 'package:ubuntu_image_gui/models/model_assertion.dart';
import 'package:ubuntu_image_gui/views/wizard_page.dart';

/// A fake `ubuntu-image` process whose lifecycle is driven by the test.
/// Widget tests run in a fake-async zone where real `Process` events are
/// never delivered, so the build's `processStarter` is injected.
class FakeBuildProcess {
  FakeBuildProcess({required this.releaseAt});

  /// Fake time (ms) at which the process should exit.
  final int releaseAt;
  bool _released = false;
  final _exit = StreamController<int>.broadcast();
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();

  Stream<List<int>> get stdout => _stdout.stream;
  Stream<List<int>> get stderr => _stderr.stream;
  Future<int> get exitCode => _exit.stream.first;
  bool kill(ProcessSignal signal) {
    if (_released) return false;
    _released = true;
    _stdout.close();
    _stderr.close();
    _exit.add(-15);
    return true;
  }

  void emit(String line) => _stdout.add(utf8.encode(line));

  /// Test pump loop calls this whenever fake time reaches [releaseAt].
  void tick(int now) {
    if (!_released && now >= releaseAt) {
      _released = true;
      emit('done\n');
      _stdout.close();
      _stderr.close();
      _exit.add(0);
    }
  }
}

class FakeBuildProcessBuild implements BuildProcess {
  FakeBuildProcessBuild(this._fake);
  final FakeBuildProcess _fake;

  @override
  Stream<List<int>> get stdout => _fake.stdout;

  @override
  Stream<List<int>> get stderr => _fake.stderr;

  @override
  Future<int> get exitCode => _fake.exitCode;

  @override
  bool kill(ProcessSignal signal) => _fake.kill(signal);
}

/// While a build is running, the wizard must lock navigation to the other
/// steps (leaving would unmount the build step and kill the subprocess),
/// and release the lock as soon as the build finishes.

/// The page title of a step: headline-small text (the sidebar tile uses
/// body-small for the same label, so text alone is ambiguous).
Finder pageTitle(String title) => find.byWidgetPredicate(
  (w) => w is Text && w.data == title && (w.style?.fontSize ?? 0) >= 18,
);

void main() {
  late BuildConfig config;
  late FakeBuildProcess fake;
  late int clock; // fake ms

  setUp(() {
    clock = 0;
    fake = FakeBuildProcess(releaseAt: 2000);
    config = stubbedConfig()
      ..model = ModelAssertion('/tmp/m.assert', {
        'model': 'test-model',
        'grade': 'dangerous',
      }, parsed: true)
      ..outputDir = '/out'
      ..processStarter = (exe, args) async {
        fake.emit('\$ $exe ${args.join(' ')}\n');
        fake.emit('building...\n');
        return FakeBuildProcessBuild(fake);
      };
  });

  /// Advance the fake clock [step]ms, driving the fake process.
  Future<void> advance(WidgetTester tester, int step) async {
    while (step > 0) {
      final chunk = step > 100 ? 100 : step;
      clock += chunk;
      fake.tick(clock);
      step -= chunk;
      await tester.pump(Duration(milliseconds: chunk));
    }
  }

  testWidgets(
    'navigation is locked while a build runs and released after it finishes',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(home: WizardPage(config: config)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Build'));
      await tester.pumpAndSettle();
      expect(pageTitle('Build'), findsOneWidget);
      expect(find.text('Ready to build'), findsOneWidget);

      // Start the build.
      await tester.tap(find.text('Build image'));
      await tester.pump();
      await advance(tester, 150);

      // Lock is active: footer shows a spinner + "Building…".
      expect(find.text('Building…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The other tiles are untappable and explain why.
      final modelTile = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('Model'), matching: find.byType(InkWell))
            .first,
      );
      expect(modelTile.onTap, isNull, reason: 'other tiles must be locked');
      final tooltip = tester.widget<Tooltip>(
        find
            .ancestor(of: find.text('Model'), matching: find.byType(Tooltip))
            .first,
      );
      expect(tooltip.message, 'Build in progress — wait for it to finish');

      // Tapping a locked tile does not navigate away.
      await tester.tap(find.text('Model'));
      await tester.pump();
      expect(pageTitle('Build'), findsOneWidget);

      // The Build tile itself stays active (it is the current page).
      final buildTile = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('Build'), matching: find.byType(InkWell))
            .first,
      );
      expect(
        buildTile.onTap,
        isNotNull,
        reason: 'the Build tile must stay active while it runs',
      );

      // Run the build to completion.
      await advance(tester, 2500);

      // Lock released: footer back to normal, navigation works again.
      expect(find.text('Building…'), findsNothing);
      expect(find.text('Ready to build'), findsOneWidget);

      // The console kept its output the whole time (it appears both in the
      // status row and, crucially, still inside the console body).
      expect(find.textContaining('building...'), findsOneWidget);
      expect(find.textContaining('Build finished successfully'), findsWidgets);

      await tester.tap(find.text('Model'));
      await tester.pumpAndSettle();
      expect(pageTitle('Model assertion'), findsOneWidget);
    },
  );
}
