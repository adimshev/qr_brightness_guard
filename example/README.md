# qr_brightness_guard example

Demo app for testing `qr_brightness_guard` on real Android and iOS devices.

The example wires:

* `qr_brightness_guard` from `../`
* `qr_screen_brightness` from `../../qr_screen_brightness`
* `wakelock_plus` from pub.dev

Run it from this directory with:

```sh
flutter run
```

Tap either QR tile to mount a `QrBrightnessGuard`. The first active QR should
enable wakelock and max brightness; removing the last active QR should reset
brightness and disable wakelock.
