part of '../qr_brightness_guard.dart';

/// Owns QR screen protection state for the relevant widget subtree.
class QrBrightnessScope extends StatefulWidget {
  /// Creates a scope that coordinates active [QrBrightnessGuard] descendants.
  const QrBrightnessScope({
    super.key,
    required this.child,
    required this.setMaxBrightness,
    required this.resetBrightness,
    this.enableWakelock,
    this.disableWakelock,
    this.onError,
    this.logger,
    this.enabled = true,
  });

  /// The subtree that may contain QR guards.
  final Widget child;

  /// Applies the maximum screen brightness.
  final QrBrightnessAction setMaxBrightness;

  /// Releases any brightness override.
  final QrBrightnessAction resetBrightness;

  /// Enables wakelock protection, when the app wants to pair it with brightness.
  final QrBrightnessAction? enableWakelock;

  /// Disables wakelock protection, when it was enabled by this scope.
  final QrBrightnessAction? disableWakelock;

  /// Receives callback failures without letting them escape into the UI.
  final QrBrightnessErrorHandler? onError;

  /// Receives short diagnostic messages for callback failures.
  final QrBrightnessLogger? logger;

  /// Whether this scope is allowed to apply protected screen state.
  final bool enabled;

  @override
  State<QrBrightnessScope> createState() => _QrBrightnessScopeState();
}

class _QrBrightnessScopeState extends State<QrBrightnessScope> {
  final Set<Object> _activeTokens = <Object>{};

  late final QrBrightnessAction _setMaxBrightness;
  late final QrBrightnessAction _resetBrightness;
  late final QrBrightnessAction? _enableWakelock;
  late final QrBrightnessAction? _disableWakelock;
  late final QrBrightnessErrorHandler? _onError;
  late final QrBrightnessLogger? _logger;

  AppLifecycleListener? _lifecycleListener;

  var _enabled = true;
  var _ownsBrightness = false;
  var _ownsWakelock = false;
  var _isResumed = true;
  var _syncPending = false;
  var _syncInProgress = false;
  var _isDisposed = false;

  bool get _desiredProtectedState {
    return !kIsWeb &&
        !_isDisposed &&
        _enabled &&
        _isResumed &&
        _activeTokens.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    _setMaxBrightness = widget.setMaxBrightness;
    _resetBrightness = widget.resetBrightness;
    _enableWakelock = widget.enableWakelock;
    _disableWakelock = widget.disableWakelock;
    _onError = widget.onError;
    _logger = widget.logger;
    _enabled = widget.enabled;

    if (kIsWeb) {
      return;
    }

    _isResumed = _readIsResumed();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleLifecycleStateChange,
    );
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant QrBrightnessScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enabled == widget.enabled) {
      return;
    }

    _enabled = widget.enabled;
    _scheduleSync();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _activeTokens.clear();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;

    if (!kIsWeb) {
      _scheduleSync();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return widget.child;
    }

    return _QrBrightnessScopeHost(scope: this, child: widget.child);
  }

  bool _registerToken(Object token) {
    if (kIsWeb || _isDisposed) {
      return false;
    }

    final added = _activeTokens.add(token);

    if (added) {
      _scheduleSync();
    }

    return true;
  }

  void _unregisterToken(Object token) {
    if (kIsWeb) {
      return;
    }

    final removed = _activeTokens.remove(token);

    if (removed && !_isDisposed) {
      _scheduleSync();
    }
  }

  bool _readIsResumed() {
    final state = WidgetsBinding.instance.lifecycleState;

    return state == null || state == AppLifecycleState.resumed;
  }

  void _handleLifecycleStateChange(AppLifecycleState state) {
    if (_isDisposed) {
      return;
    }

    _isResumed = state == AppLifecycleState.resumed;

    if (_isResumed) {
      _isResumed = _readIsResumed();
    }

    _scheduleSync();
  }

  void _scheduleSync() {
    if (kIsWeb) {
      return;
    }

    _syncPending = true;

    if (_syncInProgress) {
      return;
    }

    _syncInProgress = true;
    unawaited(Future<void>.microtask(_drainSync));
  }

  Future<void> _drainSync() async {
    try {
      while (_syncPending) {
        _syncPending = false;
        await _syncOnce();
      }
    } catch (error, stackTrace) {
      _reportFailure('sync', error, stackTrace);
    } finally {
      _syncInProgress = false;

      if (_syncPending) {
        _scheduleSync();
      }
    }
  }

  Future<void> _syncOnce() async {
    if (kIsWeb) {
      return;
    }

    if (!_isDisposed) {
      _isResumed = _readIsResumed();
    }

    if (!_desiredProtectedState) {
      await _releaseProtectedState();

      return;
    }

    await _applyProtectedState();
  }

  Future<void> _applyProtectedState() async {
    final enableWakelock = _enableWakelock;

    if (!_ownsWakelock && enableWakelock != null) {
      try {
        await enableWakelock();
        _ownsWakelock = true;
      } catch (error, stackTrace) {
        _reportFailure('enable wakelock', error, stackTrace);
      }

      if (!_desiredProtectedState) {
        await _releaseProtectedState();

        return;
      }
    }

    if (_ownsBrightness) {
      return;
    }

    try {
      await _setMaxBrightness();
      _ownsBrightness = true;
    } catch (error, stackTrace) {
      _reportFailure('set max brightness', error, stackTrace);
      await _releaseProtectedState(forceBrightnessReset: true);

      return;
    }

    if (!_desiredProtectedState) {
      await _releaseProtectedState();
    }
  }

  Future<void> _releaseProtectedState({
    bool forceBrightnessReset = false,
  }) async {
    final shouldResetBrightness = _ownsBrightness || forceBrightnessReset;

    if (shouldResetBrightness) {
      try {
        await _resetBrightness();
      } catch (error, stackTrace) {
        _reportFailure('reset brightness', error, stackTrace);
      } finally {
        _ownsBrightness = false;
      }
    }

    if (_ownsWakelock) {
      try {
        await _disableWakelock?.call();
      } catch (error, stackTrace) {
        _reportFailure('disable wakelock', error, stackTrace);
      } finally {
        _ownsWakelock = false;
      }
    }
  }

  void _reportFailure(String action, Object error, StackTrace stackTrace) {
    try {
      _onError?.call(error, stackTrace);
    } catch (_) {
      // Error handlers must not break protected-state synchronization.
    }

    try {
      _logger?.call('QrBrightnessScope: $action failed: $error');
    } catch (_) {
      // Loggers are diagnostics only.
    }
  }
}

class _QrBrightnessScopeHost extends InheritedWidget {
  const _QrBrightnessScopeHost({required this.scope, required super.child});

  final _QrBrightnessScopeState scope;

  static _QrBrightnessScopeState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_QrBrightnessScopeHost>()
        ?.scope;
  }

  @override
  bool updateShouldNotify(_QrBrightnessScopeHost oldWidget) {
    return !identical(scope, oldWidget.scope);
  }
}
