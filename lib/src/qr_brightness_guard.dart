part of '../qr_brightness_guard.dart';

/// Declaratively marks a subtree as showing an active QR code.
class QrBrightnessGuard extends StatefulWidget {
  /// Creates a guard that registers with the nearest [QrBrightnessScope].
  const QrBrightnessGuard({
    super.key,
    required this.child,
    this.enabled = true,
  });

  /// The subtree that displays an active QR code.
  final Widget child;

  /// Whether this guard should count as an active QR code.
  final bool enabled;

  @override
  State<QrBrightnessGuard> createState() => _QrBrightnessGuardState();
}

class _QrBrightnessGuardState extends State<QrBrightnessGuard> {
  final Object _token = Object();

  _QrBrightnessScopeState? _scope;
  var _isRegistered = false;
  var _didWarnMissingScope = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  @override
  void didUpdateWidget(covariant QrBrightnessGuard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enabled != widget.enabled) {
      _syncRegistration();
    }
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _syncRegistration() {
    if (kIsWeb) {
      return;
    }

    final scope = _QrBrightnessScopeHost.maybeOf(context);

    if (!identical(scope, _scope)) {
      _unregister();
      _scope = scope;
    }

    if (scope == null) {
      if (widget.enabled) {
        _debugWarnMissingScope();
      }

      return;
    }

    if (widget.enabled) {
      _register(scope);
    } else {
      _unregister();
    }
  }

  void _register(_QrBrightnessScopeState scope) {
    if (_isRegistered) {
      return;
    }

    if (scope._registerToken(_token)) {
      _scope = scope;
      _isRegistered = true;
    }
  }

  void _unregister() {
    if (!_isRegistered) {
      return;
    }

    _scope?._unregisterToken(_token);
    _isRegistered = false;
  }

  void _debugWarnMissingScope() {
    assert(() {
      if (!_didWarnMissingScope) {
        _didWarnMissingScope = true;
        debugPrint('QrBrightnessGuard was used without a QrBrightnessScope.');
      }

      return true;
    }());
  }
}
