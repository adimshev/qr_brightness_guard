# qr_brightness_guard

Backend-independent Flutter widgets for QR display flows that need temporary
maximum screen brightness and optional wakelock.

This package is a pure Flutter package. It does not include native code,
platform channels, a brightness backend, or a wakelock dependency. Applications
provide the backend actions through callbacks.

## Usage

Wrap the relevant subtree in `QrBrightnessScope`, then wrap each visible QR
surface in `QrBrightnessGuard`.

```dart
QrBrightnessScope(
  setMaxBrightness: brightnessBackend.setMaxBrightness,
  resetBrightness: brightnessBackend.resetBrightness,
  enableWakelock: wakelockBackend.enable,
  disableWakelock: wakelockBackend.disable,
  onError: (error, stackTrace) {
    // Report callback failures without crashing the UI.
  },
  logger: debugPrint,
  child: QrBrightnessGuard(
    child: YourQrWidget(),
  ),
)
```

For multiple QR widgets, place one `QrBrightnessScope` above them. The scope
keeps brightness applied while at least one enabled guard is active, releases it
after the last guard disappears, and reapplies after app resume if the guards are
still present.

On web, both widgets are no-ops and callbacks are not invoked.
