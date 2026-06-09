import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

part 'src/qr_brightness_guard.dart';
part 'src/qr_brightness_scope.dart';

/// A backend action used to apply or release brightness and wakelock state.
typedef QrBrightnessAction = Future<void> Function();

/// Receives asynchronous callback failures caught by the guard.
///
/// The [stage] identifies which guard action failed.
typedef QrBrightnessErrorHandler =
    void Function(Object error, StackTrace stackTrace, String stage);
