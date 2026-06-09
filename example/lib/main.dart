import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_brightness_guard/qr_brightness_guard.dart';
import 'package:qr_screen_brightness/qr_screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  runApp(const BrightnessGuardExampleApp());
}

class BrightnessGuardExampleApp extends StatelessWidget {
  const BrightnessGuardExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR brightness guard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const BrightnessGuardDemoPage(),
    );
  }
}

class BrightnessGuardDemoPage extends StatefulWidget {
  const BrightnessGuardDemoPage({super.key});

  @override
  State<BrightnessGuardDemoPage> createState() =>
      _BrightnessGuardDemoPageState();
}

class _BrightnessGuardDemoPageState extends State<BrightnessGuardDemoPage> {
  final bool _isSupported = QrScreenBrightness.isSupported;
  final ScrollController _logScrollController = ScrollController();
  final List<String> _logs = <String>[];

  var _scopeEnabled = true;
  var _showFirstQr = false;
  var _showSecondQr = false;
  var _brightnessState = 'unknown';

  @override
  void initState() {
    super.initState();
    _writeLog(_isSupported ? 'ready' : 'backend unsupported');
    if (kIsWeb) {
      _writeLog('web no-op');
    }
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _guardSetMaxBrightness() async {
    _writeLog('brightness.setMax -> start');
    await QrScreenBrightness.setMaxBrightness();
    _setBrightnessState('max');
    _writeLog('brightness.setMax -> done');
  }

  Future<void> _guardResetBrightness() async {
    _writeLog('brightness.reset -> start');
    await QrScreenBrightness.resetBrightness();
    _setBrightnessState('system/default');
    _writeLog('brightness.reset -> done');
  }

  Future<void> _guardEnableWakelock() async {
    _writeLog('wakelock.enable -> start');
    await WakelockPlus.enable();
    _writeLog('wakelock.enable -> done');
  }

  Future<void> _guardDisableWakelock() async {
    _writeLog('wakelock.disable -> start');
    await WakelockPlus.disable();
    _writeLog('wakelock.disable -> done');
  }

  void _handleGuardError(Object error, StackTrace stackTrace, String stage) {
    _writeLog('$stage failed: $error');
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'qr_brightness_guard_example',
      ),
    );
  }

  void _setBrightnessState(String value) {
    if (!mounted) {
      return;
    }

    setState(() {
      _brightnessState = value;
    });
  }

  void _toggleScope(bool value) {
    setState(() {
      _scopeEnabled = value;
    });
    _writeLog('scope ${value ? 'enabled' : 'disabled'}');
  }

  void _toggleFirstQr() {
    final next = !_showFirstQr;
    setState(() {
      _showFirstQr = next;
    });
    _writeLog('QR 1 ${next ? 'mounted' : 'unmounted'}');
  }

  void _toggleSecondQr() {
    final next = !_showSecondQr;
    setState(() {
      _showSecondQr = next;
    });
    _writeLog('QR 2 ${next ? 'mounted' : 'unmounted'}');
  }

  void _writeLog(String message) {
    if (!mounted) {
      return;
    }

    final now = DateTime.now();
    final time =
        '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}';

    setState(() {
      _logs.add('[$time] $message');
      if (_logs.length > 120) {
        _logs.removeAt(0);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_logScrollController.hasClients) {
        return;
      }

      _logScrollController.jumpTo(
        _logScrollController.position.maxScrollExtent,
      );
    });
  }

  void _clearLogs() {
    setState(_logs.clear);
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    return QrBrightnessScope(
      enabled: _scopeEnabled,
      setMaxBrightness: _guardSetMaxBrightness,
      resetBrightness: _guardResetBrightness,
      enableWakelock: _guardEnableWakelock,
      disableWakelock: _guardDisableWakelock,
      onError: _handleGuardError,
      child: Scaffold(
        appBar: AppBar(title: const Text('QR brightness guard')),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _StatusPanel(
                      isSupported: _isSupported,
                      brightnessState: _brightnessState,
                      activeQrCount:
                          (_showFirstQr ? 1 : 0) + (_showSecondQr ? 1 : 0),
                      scopeEnabled: _scopeEnabled,
                      isWeb: kIsWeb,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Scope enabled'),
                      value: _scopeEnabled,
                      onChanged: _toggleScope,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: <Widget>[
                        _buildQrToggle(
                          label: 'QR 1',
                          isMounted: _showFirstQr,
                          patternSeed: 3,
                          onTap: _toggleFirstQr,
                        ),
                        _buildQrToggle(
                          label: 'QR 2',
                          isMounted: _showSecondQr,
                          patternSeed: 7,
                          onTap: _toggleSecondQr,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _ConsoleLog(
                controller: _logScrollController,
                logs: _logs,
                onClear: _clearLogs,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrToggle({
    required String label,
    required bool isMounted,
    required int patternSeed,
    required VoidCallback onTap,
  }) {
    final tile = SizedBox(
      width: 156,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: Material(
              color: isMounted ? Colors.green.shade50 : Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isMounted ? Colors.green.shade700 : Colors.black26,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: CustomPaint(
                    painter: _FakeQrPainter(
                      seed: patternSeed,
                      enabled: isMounted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$label ${isMounted ? 'mounted' : 'unmounted'}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    if (!isMounted) {
      return tile;
    }

    return QrBrightnessGuard(child: tile);
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.isSupported,
    required this.brightnessState,
    required this.activeQrCount,
    required this.scopeEnabled,
    required this.isWeb,
  });

  final bool isSupported;
  final String brightnessState;
  final int activeQrCount;
  final bool scopeEnabled;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyMedium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('backend: ${isSupported ? 'supported' : 'unsupported'}'),
              const SizedBox(height: 6),
              Text('brightness: $brightnessState'),
              const SizedBox(height: 6),
              Text('active QR: $activeQrCount'),
              const SizedBox(height: 6),
              Text('scope: ${scopeEnabled ? 'enabled' : 'disabled'}'),
              if (isWeb) ...<Widget>[
                const SizedBox(height: 6),
                const Text('web: no-op'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsoleLog extends StatelessWidget {
  const _ConsoleLog({
    required this.controller,
    required this.logs,
    required this.onClear,
  });

  final ScrollController controller;
  final List<String> logs;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF101418),
        border: Border(top: BorderSide(color: Color(0xFF2D333B))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 2),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Console',
                    style: TextStyle(
                      color: Color(0xFFCDD9E5),
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear logs',
                  onPressed: logs.isEmpty ? null : onClear,
                  color: const Color(0xFFCDD9E5),
                  disabledColor: const Color(0xFF59636E),
                  icon: const Icon(Icons.delete_sweep, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                return Text(
                  logs[index],
                  style: const TextStyle(
                    color: Color(0xFF7EE787),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeQrPainter extends CustomPainter {
  const _FakeQrPainter({required this.seed, required this.enabled});

  final int seed;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.shortestSide / 21;
    final origin = Offset(
      (size.width - cell * 21) / 2,
      (size.height - cell * 21) / 2,
    );
    final darkPaint = Paint()
      ..color = enabled ? Colors.black : Colors.grey.shade600;
    final lightPaint = Paint()..color = Colors.white;

    canvas.drawRect(origin & Size.square(cell * 21), lightPaint);

    void drawCell(int x, int y, Paint paint) {
      canvas.drawRect(
        Rect.fromLTWH(origin.dx + x * cell, origin.dy + y * cell, cell, cell),
        paint,
      );
    }

    void drawFinder(int startX, int startY) {
      for (var y = 0; y < 7; y += 1) {
        for (var x = 0; x < 7; x += 1) {
          final edge = x == 0 || y == 0 || x == 6 || y == 6;
          final center = x >= 2 && x <= 4 && y >= 2 && y <= 4;
          if (edge || center) {
            drawCell(startX + x, startY + y, darkPaint);
          }
        }
      }
    }

    drawFinder(0, 0);
    drawFinder(14, 0);
    drawFinder(0, 14);

    for (var y = 0; y < 21; y += 1) {
      for (var x = 0; x < 21; x += 1) {
        final inTopLeft = x < 8 && y < 8;
        final inTopRight = x > 12 && y < 8;
        final inBottomLeft = x < 8 && y > 12;
        if (inTopLeft || inTopRight || inBottomLeft) {
          continue;
        }

        final value = (x * 31 + y * 17 + seed * 13 + (x * y)) % 9;
        if (value == 0 || value == 2 || value == 5) {
          drawCell(x, y, darkPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FakeQrPainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.enabled != enabled;
  }
}
