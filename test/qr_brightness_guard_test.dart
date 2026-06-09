import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_brightness_guard/qr_brightness_guard.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  void moveToPaused() {
    switch (WidgetsBinding.instance.lifecycleState) {
      case null:
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        continue resumed;
      resumed:
      case AppLifecycleState.resumed:
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        continue inactive;
      inactive:
      case AppLifecycleState.inactive:
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        continue hidden;
      hidden:
      case AppLifecycleState.hidden:
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        return;
    }
  }

  void moveToResumed() {
    switch (WidgetsBinding.instance.lifecycleState) {
      case null:
      case AppLifecycleState.detached:
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      case AppLifecycleState.paused:
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        continue hidden;
      hidden:
      case AppLifecycleState.hidden:
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        continue inactive;
      inactive:
      case AppLifecycleState.inactive:
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      case AppLifecycleState.resumed:
        return;
    }
  }

  setUp(() {
    moveToResumed();
  });

  Future<void> flushSync(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Widget scopeWithGuard(
    _CallLog log, {
    bool scopeEnabled = true,
    bool guardEnabled = true,
    int guardCount = 1,
  }) {
    return QrBrightnessScope(
      enabled: scopeEnabled,
      setMaxBrightness: log.setMaxBrightness,
      resetBrightness: log.resetBrightness,
      enableWakelock: log.enableWakelock,
      disableWakelock: log.disableWakelock,
      onError: log.onError,
      child: Column(
        children: List<Widget>.generate(
          guardCount,
          (index) => QrBrightnessGuard(
            enabled: guardEnabled,
            child: SizedBox(key: ValueKey<int>(index)),
          ),
        ),
      ),
    );
  }

  testWidgets('first active guard applies and last inactive guard releases', (
    tester,
  ) async {
    final log = _CallLog();

    await tester.pumpWidget(scopeWithGuard(log));
    await flushSync(tester);

    expect(log.calls, <String>['enableWakelock', 'setMaxBrightness']);

    await tester.pumpWidget(scopeWithGuard(log, guardEnabled: false));
    await flushSync(tester);

    expect(log.calls, <String>[
      'enableWakelock',
      'setMaxBrightness',
      'resetBrightness',
      'disableWakelock',
    ]);
  });

  testWidgets(
    'multiple active guards do not duplicate apply or early release',
    (tester) async {
      final log = _CallLog();

      await tester.pumpWidget(scopeWithGuard(log, guardCount: 2));
      await flushSync(tester);

      expect(log.calls, <String>['enableWakelock', 'setMaxBrightness']);

      await tester.pumpWidget(scopeWithGuard(log));
      await flushSync(tester);

      expect(log.calls, <String>['enableWakelock', 'setMaxBrightness']);

      await tester.pumpWidget(scopeWithGuard(log, guardCount: 0));
      await flushSync(tester);

      expect(log.calls, <String>[
        'enableWakelock',
        'setMaxBrightness',
        'resetBrightness',
        'disableWakelock',
      ]);
    },
  );

  testWidgets('scope enabled toggles release and apply with active guards', (
    tester,
  ) async {
    final log = _CallLog();

    await tester.pumpWidget(scopeWithGuard(log));
    await flushSync(tester);

    await tester.pumpWidget(scopeWithGuard(log, scopeEnabled: false));
    await flushSync(tester);

    await tester.pumpWidget(scopeWithGuard(log));
    await flushSync(tester);

    expect(log.calls, <String>[
      'enableWakelock',
      'setMaxBrightness',
      'resetBrightness',
      'disableWakelock',
      'enableWakelock',
      'setMaxBrightness',
    ]);
  });

  testWidgets('lifecycle releases and reapplies without dropping guard token', (
    tester,
  ) async {
    final log = _CallLog();

    await tester.pumpWidget(scopeWithGuard(log));
    await flushSync(tester);

    moveToPaused();
    await flushSync(tester);

    moveToResumed();
    await flushSync(tester);

    expect(log.calls, <String>[
      'enableWakelock',
      'setMaxBrightness',
      'resetBrightness',
      'disableWakelock',
      'enableWakelock',
      'setMaxBrightness',
    ]);
  });

  testWidgets('wakelock failure is reported and brightness still applies', (
    tester,
  ) async {
    final log = _CallLog(enableWakelockError: StateError('wakelock failed'));

    await tester.pumpWidget(scopeWithGuard(log));
    await flushSync(tester);

    expect(log.calls, <String>['enableWakelock', 'setMaxBrightness']);
    expect(log.errors, hasLength(1));
    expect(log.stages, <String>['enable wakelock']);

    await tester.pumpWidget(const SizedBox());
    await flushSync(tester);

    expect(log.calls, <String>[
      'enableWakelock',
      'setMaxBrightness',
      'resetBrightness',
    ]);
  });

  testWidgets(
    'brightness apply failure releases resources and does not retry',
    (tester) async {
      final log = _CallLog(
        setMaxBrightnessError: StateError('brightness failed'),
      );

      await tester.pumpWidget(scopeWithGuard(log));
      await flushSync(tester);

      expect(log.calls, <String>[
        'enableWakelock',
        'setMaxBrightness',
        'resetBrightness',
        'disableWakelock',
      ]);
      expect(log.errors, hasLength(1));
      expect(log.stages, <String>['set max brightness']);

      await flushSync(tester);

      expect(log.calls, <String>[
        'enableWakelock',
        'setMaxBrightness',
        'resetBrightness',
        'disableWakelock',
      ]);

      await tester.pumpWidget(scopeWithGuard(log, guardEnabled: false));
      await flushSync(tester);
      await tester.pumpWidget(scopeWithGuard(log));
      await flushSync(tester);

      expect(log.calls, <String>[
        'enableWakelock',
        'setMaxBrightness',
        'resetBrightness',
        'disableWakelock',
        'enableWakelock',
        'setMaxBrightness',
        'resetBrightness',
        'disableWakelock',
      ]);
    },
  );

  testWidgets('release errors are reported but swallowed', (tester) async {
    final log = _CallLog(
      resetBrightnessError: StateError('reset failed'),
      disableWakelockError: StateError('disable failed'),
    );

    await tester.pumpWidget(scopeWithGuard(log));
    await flushSync(tester);

    await tester.pumpWidget(const SizedBox());
    await flushSync(tester);

    expect(log.calls, <String>[
      'enableWakelock',
      'setMaxBrightness',
      'resetBrightness',
      'disableWakelock',
    ]);
    expect(log.errors, hasLength(2));
    expect(log.stages, <String>['reset brightness', 'disable wakelock']);
  });

  testWidgets('error handler failures are swallowed', (tester) async {
    final calls = <String>[];

    await tester.pumpWidget(
      QrBrightnessScope(
        setMaxBrightness: () async {
          calls.add('setMaxBrightness');
          throw StateError('brightness failed');
        },
        resetBrightness: () async {
          calls.add('resetBrightness');
        },
        onError: (error, stackTrace, stage) {
          calls.add('onError');
          calls.add(stage);
          throw StateError('handler failed');
        },
        child: const QrBrightnessGuard(child: SizedBox()),
      ),
    );
    await flushSync(tester);

    expect(tester.takeException(), isNull);
    expect(calls, <String>[
      'setMaxBrightness',
      'onError',
      'set max brightness',
      'resetBrightness',
    ]);
  });

  testWidgets('pending drain releases after guard is removed during apply', (
    tester,
  ) async {
    final setMaxCompleter = Completer<void>();
    final log = _CallLog(setMaxBrightnessCompleter: setMaxCompleter);

    await tester.pumpWidget(scopeWithGuard(log));
    await flushSync(tester);

    expect(log.calls, <String>['enableWakelock', 'setMaxBrightness']);

    await tester.pumpWidget(scopeWithGuard(log, guardCount: 0));
    await tester.pump();

    setMaxCompleter.complete();
    await flushSync(tester);

    expect(log.calls, <String>[
      'enableWakelock',
      'setMaxBrightness',
      'resetBrightness',
      'disableWakelock',
    ]);
  });

  testWidgets('callbacks can update widgets after guard registration', (
    tester,
  ) async {
    await tester.pumpWidget(const _CallbackSetStateHost());
    await flushSync(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('setMaxBrightness'), findsOneWidget);
  });

  testWidgets('guard without scope is a no-op', (tester) async {
    await tester.pumpWidget(const QrBrightnessGuard(child: SizedBox()));

    expect(tester.takeException(), isNull);
  });
}

class _CallLog {
  _CallLog({
    this.enableWakelockError,
    this.setMaxBrightnessError,
    this.resetBrightnessError,
    this.disableWakelockError,
    this.setMaxBrightnessCompleter,
  });

  final Object? enableWakelockError;
  final Object? setMaxBrightnessError;
  final Object? resetBrightnessError;
  final Object? disableWakelockError;
  final Completer<void>? setMaxBrightnessCompleter;

  final List<String> calls = <String>[];
  final List<Object> errors = <Object>[];
  final List<String> stages = <String>[];

  Future<void> enableWakelock() async {
    calls.add('enableWakelock');
    _throwIfPresent(enableWakelockError);
  }

  Future<void> disableWakelock() async {
    calls.add('disableWakelock');
    _throwIfPresent(disableWakelockError);
  }

  Future<void> setMaxBrightness() async {
    calls.add('setMaxBrightness');

    if (setMaxBrightnessCompleter != null) {
      await setMaxBrightnessCompleter!.future;
    }

    _throwIfPresent(setMaxBrightnessError);
  }

  Future<void> resetBrightness() async {
    calls.add('resetBrightness');
    _throwIfPresent(resetBrightnessError);
  }

  void onError(Object error, StackTrace stackTrace, String stage) {
    errors.add(error);
    stages.add(stage);
  }

  void _throwIfPresent(Object? error) {
    if (error != null) {
      throw error;
    }
  }
}

class _CallbackSetStateHost extends StatefulWidget {
  const _CallbackSetStateHost();

  @override
  State<_CallbackSetStateHost> createState() => _CallbackSetStateHostState();
}

class _CallbackSetStateHostState extends State<_CallbackSetStateHost> {
  var _lastAction = 'idle';

  Future<void> _setMaxBrightness() async {
    setState(() {
      _lastAction = 'setMaxBrightness';
    });
  }

  Future<void> _resetBrightness() async {
    setState(() {
      _lastAction = 'resetBrightness';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: QrBrightnessScope(
        setMaxBrightness: _setMaxBrightness,
        resetBrightness: _resetBrightness,
        child: Column(
          children: <Widget>[
            Text(_lastAction),
            const QrBrightnessGuard(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}
