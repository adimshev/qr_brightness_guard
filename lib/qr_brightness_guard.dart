import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

part 'src/qr_brightness_guard.dart';
part 'src/qr_brightness_scope.dart';

/// A backend action used to apply or release brightness and wakelock state.
typedef QrBrightnessAction = Future<void> Function();

/// Identifies which guard action failed.
enum QrBrightnessFailureStage {
  /// Protected-state synchronization failed outside a specific backend action.
  sync,

  /// Enabling wakelock failed.
  enableWakelock,

  /// Applying maximum brightness failed.
  setMaxBrightness,

  /// Releasing the brightness override failed.
  resetBrightness,

  /// Disabling wakelock failed.
  disableWakelock,
}

/// Receives asynchronous callback failures caught by the guard.
typedef QrBrightnessErrorHandler =
    void Function(
      Object error,
      StackTrace stackTrace,
      QrBrightnessFailureStage stage,
    );
