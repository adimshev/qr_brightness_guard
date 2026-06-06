import 'package:flutter_test/flutter_test.dart';
import 'package:qr_brightness_guard_example/main.dart';

void main() {
  testWidgets('shows QR guard demo and console log', (tester) async {
    await tester.pumpWidget(const BrightnessGuardExampleApp());
    await tester.pump();

    expect(find.text('QR brightness guard'), findsOneWidget);
    expect(find.text('QR 1 unmounted'), findsOneWidget);
    expect(find.text('QR 2 unmounted'), findsOneWidget);
    expect(find.text('Console'), findsOneWidget);
    expect(find.byTooltip('Clear logs'), findsOneWidget);
    expect(find.textContaining('['), findsWidgets);

    await tester.tap(find.byTooltip('Clear logs'));
    await tester.pump();

    expect(find.textContaining('['), findsNothing);
    expect(find.text('Get'), findsNothing);
    expect(find.text('Set'), findsNothing);
    expect(find.text('Max'), findsNothing);
    expect(find.text('Reset'), findsNothing);
  });
}
